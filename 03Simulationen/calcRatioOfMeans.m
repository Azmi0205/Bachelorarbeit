function [ratio, info] = calcRatioOfMeans(logsoutData, numeratorSignalName, denominatorSignalName, tStart, tEnd, varargin)
%CALCRATIOOFMEANS Compute the ratio of the mean values of two signals
%logged in a Simulink Simulink.SimulationData.Dataset ("logsout"):
%
%       ratio = mean(numeratorSignal) / mean(denominatorSignal)
%
%   both means computed over the SAME aligned time window, so the ratio
%   is a fair comparison rather than mixing two independently-averaged
%   intervals. Useful for e.g. torque-per-ampere (Te / i_mag),
%   power-per-speed, or any other ratio-of-means metric.
%
%   ratio = calcRatioOfMeans(out.logsout, 'Te', 'i_mag', tStart, tEnd)
%   ratio = calcRatioOfMeans(out.logsout, 'Te', 'i_mag', tStart, tEnd, 'Plot', true)
%   [ratio, info] = calcRatioOfMeans(...)
%
%   INPUTS
%     logsoutData             - Simulink.SimulationData.Dataset (out.logsout)
%     numeratorSignalName     - char/string, name of the numerator signal
%     denominatorSignalName   - char/string, name of the denominator signal
%     tStart, tEnd             - APPROXIMATE time window (seconds). You do
%                                not need to hit exact period boundaries:
%                                by default the window is snapped to the
%                                nearest true zero-crossings of the
%                                ripple on the 'AlignOn' reference signal,
%                                spanning an exact integer number of
%                                periods.
%
%   OPTIONAL NAME-VALUE PAIRS
%     'AutoAlign'    - true (default) | false
%                      If true, the window is snapped/aligned using the
%                      signal named in 'AlignOn'. If false, the raw
%                      [tStart, tEnd] window is used as-is for both
%                      signals.
%     'AlignOn'      - 'denominator' (default) | 'numerator'
%                      Which signal's ripple zero-crossings are used to
%                      determine the aligned window. Pick whichever
%                      signal has the cleaner, more regular ripple.
%     'Plot'         - true/false, plot both signals with their means and
%                      the aligned window.
%
%   OUTPUTS
%     ratio - mean(numerator) / mean(denominator)
%     info  - struct with fields:
%               .meanNumerator    mean of the numerator signal
%               .meanDenominator  mean of the denominator signal
%               .numPeriods       number of periods used for alignment
%               .period           estimated period (s) of the align signal
%               .freq             estimated frequency (Hz) of the align signal
%               .tStartAligned    aligned start time used (s)
%               .tEndAligned      aligned end time used (s)
%               .ratio            same as ratio output
%
%   EXAMPLE (torque per ampere)
%     [TPA, info] = calcRatioOfMeans(out.logsout, 'Te', 'i_mag', ...
%                                     1.4763, 1.4989, 'Plot', true);
%     fprintf('TPA = %.4f Nm/A\n', TPA);

    % ---------------- Parse inputs ----------------
    p = inputParser;
    addRequired(p, 'logsoutData');
    addRequired(p, 'numeratorSignalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'denominatorSignalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'tStart', @isnumeric);
    addRequired(p, 'tEnd', @isnumeric);
    addParameter(p, 'AutoAlign', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'AlignOn', 'denominator', @(x) any(strcmpi(x, {'numerator','denominator'})));
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, logsoutData, numeratorSignalName, denominatorSignalName, tStart, tEnd, varargin{:});

    numSignalName = char(p.Results.numeratorSignalName);
    denSignalName = char(p.Results.denominatorSignalName);
    autoAlign     = logical(p.Results.AutoAlign);
    alignOn       = lower(char(p.Results.AlignOn));
    doPlot        = logical(p.Results.Plot);

    if tEnd <= tStart
        error('calcRatioOfMeans:BadWindow', 'tEnd must be greater than tStart.');
    end

    % ---------------- Load both signals ----------------
    [tNumRaw, yNumRaw] = getSignalData(logsoutData, numSignalName);
    [tDenRaw, yDenRaw] = getSignalData(logsoutData, denSignalName);

    % ---------------- Determine which signal drives alignment -------------
    switch alignOn
        case 'numerator'
            tRef = tNumRaw; yRef = yNumRaw;
        case 'denominator'
            tRef = tDenRaw; yRef = yDenRaw;
    end

    span = tEnd - tStart;
    marginFrac = 0.20;
    padStart = max(tRef(1), tStart - marginFrac * span);
    padEnd   = min(tRef(end), tEnd + marginFrac * span);

    maskPad = tRef >= padStart & tRef <= padEnd;
    if nnz(maskPad) < 8
        error('calcRatioOfMeans:InsufficientSamples', ...
            'Fewer than 8 samples found around [tStart, tEnd] in the "%s" alignment signal.', alignOn);
    end
    tPad = tRef(maskPad);
    yPad = yRef(maskPad);
    [tPad, iu] = unique(tPad, 'stable');
    yPad = yPad(iu);
    [tPad, isort] = sort(tPad);
    yPad = yPad(isort);

    % ---------------- Auto-align to zero-crossings of the ref signal -------
    tStartAligned = tStart;
    tEndAligned   = tEnd;
    numPeriods    = NaN;
    period        = NaN;

    if autoAlign
        yDetrend = yPad - mean(yPad);
        s = sign(yDetrend);
        s(s == 0) = 1;
        risingIdx = find(diff(s) > 0);

        if numel(risingIdx) < 2
            warning('calcRatioOfMeans:NoZeroCrossings', ...
                ['AutoAlign requested but fewer than 2 zero-crossings were found on the ', ...
                 '"%s" signal. Falling back to the raw [tStart, tEnd] window.'], alignOn);
            autoAlign = false;
        else
            i1 = risingIdx;
            i2 = risingIdx + 1;
            frac = -yDetrend(i1) ./ (yDetrend(i2) - yDetrend(i1));
            crossTimes = tPad(i1) + frac .* (tPad(i2) - tPad(i1));

            [~, kStart] = min(abs(crossTimes - tStart));
            [~, kEnd]   = min(abs(crossTimes - tEnd));

            if kEnd <= kStart
                warning('calcRatioOfMeans:BadAlignment', ...
                    'Could not find at least one full period between tStart and tEnd. Falling back to raw window.');
                autoAlign = false;
            else
                tStartAligned = crossTimes(kStart);
                tEndAligned   = crossTimes(kEnd);
                numPeriods    = kEnd - kStart;
                period        = (tEndAligned - tStartAligned) / numPeriods;
            end
        end
    end

    if ~autoAlign
        tStartAligned = tStart;
        tEndAligned   = tEnd;
    end

    % ---------------- Compute both means over the SAME aligned window ------
    meanNumerator   = timeWeightedMean(tNumRaw, yNumRaw, tStartAligned, tEndAligned, 'numerator');
    meanDenominator = timeWeightedMean(tDenRaw, yDenRaw, tStartAligned, tEndAligned, 'denominator');

    if abs(meanDenominator) <= eps
        error('calcRatioOfMeans:ZeroDenominator', ...
            'Mean denominator value is ~0 over the aligned window; cannot compute ratio.');
    end

    ratio = meanNumerator / meanDenominator;

    info.meanNumerator   = meanNumerator;
    info.meanDenominator = meanDenominator;
    info.numPeriods      = numPeriods;
    info.period          = period;
    if ~isnan(period)
        info.freq = 1 / period;
    else
        info.freq = NaN;
    end
    info.tStartAligned = tStartAligned;
    info.tEndAligned   = tEndAligned;
    info.ratio         = ratio;

    % ---------------- Optional plotting --------------------------------------
    if doPlot
        figure('Name', 'Ratio-of-means analysis');

        subplot(2,1,1);
        maskN = tNumRaw >= padStart & tNumRaw <= padEnd;
        plot(tNumRaw(maskN), yNumRaw(maskN), 'Color', [0.6 0.6 0.6]); hold on;
        maskNw = tNumRaw >= tStartAligned & tNumRaw <= tEndAligned;
        plot(tNumRaw(maskNw), yNumRaw(maskNw), 'b-', 'LineWidth', 1.2);
        yline(meanNumerator, 'r--', sprintf('Mean = %.4f', meanNumerator));
        xline(tStartAligned, 'k:'); xline(tEndAligned, 'k:');
        ylabel(numSignalName); title('Numerator'); grid on;

        subplot(2,1,2);
        maskD = tDenRaw >= padStart & tDenRaw <= padEnd;
        plot(tDenRaw(maskD), yDenRaw(maskD), 'Color', [0.6 0.6 0.6]); hold on;
        maskDw = tDenRaw >= tStartAligned & tDenRaw <= tEndAligned;
        plot(tDenRaw(maskDw), yDenRaw(maskDw), 'b-', 'LineWidth', 1.2);
        yline(meanDenominator, 'r--', sprintf('Mean = %.4f', meanDenominator));
        xline(tStartAligned, 'k:'); xline(tEndAligned, 'k:');
        xlabel('Time (s)'); ylabel(denSignalName);
        title(sprintf('Denominator - ratio = %.4f (%s / %s)', ratio, numSignalName, denSignalName));
        grid on;
    end
end

function meanVal = timeWeightedMean(tRaw, yRaw, tStartAligned, tEndAligned, label)
    mask = tRaw >= tStartAligned & tRaw <= tEndAligned;
    if nnz(mask) < 2
        error('calcRatioOfMeans:InsufficientSamples', ...
            'Fewer than 2 samples of the "%s" signal found in the aligned window.', label);
    end
    tWin = tRaw(mask);
    yWin = yRaw(mask);
    [tWin, iu] = unique(tWin, 'stable');
    yWin = yWin(iu);
    [tWin, isort] = sort(tWin);
    yWin = yWin(isort);
    duration = tEndAligned - tStartAligned;
    meanVal = trapz(tWin, yWin) / duration;
end

function [tRaw, yRaw] = getSignalData(logsoutData, signalName)
    sigElement = findSignalRecursive(logsoutData, signalName);
    if isempty(sigElement)
        error('calcRatioOfMeans:SignalNotFound', ...
            'Signal "%s" was not found in the provided logsout dataset.', signalName);
    end

    ts = sigElement.Values;
    if isa(ts, 'timeseries')
        tRaw = ts.Time(:);
        yRaw = ts.Data(:);
    elseif isstruct(ts) && isfield(ts, 'Time') && isfield(ts, 'Data')
        tRaw = ts.Time(:);
        yRaw = ts.Data(:);
    else
        error('calcRatioOfMeans:UnsupportedType', ...
            'Unsupported data type for signal "%s". Expected a timeseries.', signalName);
    end

    if ~isvector(yRaw)
        error('calcRatioOfMeans:NotScalarSignal', ...
            'calcRatioOfMeans currently supports single-channel (scalar) signals only. Signal "%s" is not scalar.', signalName);
    end
end

function element = findSignalRecursive(dataset, name)
%FINDSIGNALRECURSIVE Search a Dataset (and any nested Datasets, e.g. bus
%signals) for a signal element matching "name". Returns [] if not found.
    element = [];
    if isempty(dataset)
        return;
    end
    try
        found = dataset.getElement(name);
        if ~isempty(found)
            element = found;
            return;
        end
    catch
        % getElement throws if not present by that exact name; ignore and
        % fall back to manual iteration (handles partial/bus name matches).
    end

    for i = 1:dataset.numElements
        el = dataset.getElement(i);
        if strcmp(el.Name, name)
            element = el;
            return;
        end
        if isa(el.Values, 'Simulink.SimulationData.Dataset')
            sub = findSignalRecursive(el.Values, name);
            if ~isempty(sub)
                element = sub;
                return;
            end
        end
    end
end
