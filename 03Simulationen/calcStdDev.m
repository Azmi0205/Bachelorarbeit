function [stdDev, info] = calcStdDev(logsoutData, signalName, tStart, tEnd, varargin)
%CALCSTDDEV Compute the (time-weighted) standard deviation of any
%periodic or quasi-periodic signal logged in a Simulink
%Simulink.SimulationData.Dataset ("logsout"). Works for torque, current,
%speed, power, or any other logged quantity.
%
%   stdDev = calcStdDev(out.logsout, 'Te', tStart, tEnd)
%   stdDev = calcStdDev(out.logsout, 'FOC_ia', tStart, tEnd, 'Plot', true)
%   stdDevPct = calcStdDev(out.logsout, 'Idc', tStart, tEnd, 'Normalized', true)
%   [stdDev, info] = calcStdDev(...)
%
%   INPUTS
%     logsoutData  - Simulink.SimulationData.Dataset (out.logsout)
%     signalName   - char/string, name of the logged signal to analyze
%     tStart, tEnd - APPROXIMATE time window (seconds). You do not need
%                    to hit exact period boundaries: by default the
%                    function detrends the signal, finds the nearest
%                    true zero-crossings of the ripple, and analyzes an
%                    exact integer number of periods between them (see
%                    'AutoAlign').
%
%   OPTIONAL NAME-VALUE PAIRS
%     'AutoAlign'    - true (default) | false
%                      If true, tStart/tEnd are snapped to the nearest
%                      detected zero-crossings (on the detrended signal)
%                      so the analysis window spans an exact integer
%                      number of periods. Set false for non-periodic or
%                      transient signals, where the raw window is used
%                      as-is.
%     'Normalized'   - false (default) | true
%                      If true, stdDev is returned as a percentage of
%                      the reference value (coefficient of variation),
%                      instead of in the signal's native units.
%     'NormalizeBy'  - 'mean' (default) | numeric scalar
%                      Reference value used when 'Normalized' is true.
%                      'mean' uses the signal's own mean over the
%                      aligned window. Pass a numeric value (e.g. rated
%                      current) instead if the mean is near zero.
%     'Plot'         - true/false, plot the signal, aligned window, mean,
%                      and +/-1 std-dev band.
%
%   OUTPUTS
%     stdDev - standard deviation (native units, or percent if
%              'Normalized' is true)
%     info   - struct with fields:
%                .numPeriods    number of periods used
%                .period        estimated period (s)
%                .freq          estimated frequency (Hz)
%                .tStartAligned aligned start time used (s)
%                .tEndAligned   aligned end time used (s)
%                .mean          mean value over the aligned window
%                .std           standard deviation, native units
%                .stdPct        standard deviation, percent of reference
%                .reference     reference value used for stdPct
%
%   EXAMPLES
%     % Torque standard deviation, native units:
%     sTe = calcStdDev(out.logsout, 'Te', 1.4763, 1.4989, 'Plot', true);
%
%     % Current std dev as % of mean:
%     sIa_pct = calcStdDev(out.logsout, 'FOC_ia', 1.4763, 1.4989, ...
%                           'Normalized', true);

    % ---------------- Parse inputs ----------------
    p = inputParser;
    addRequired(p, 'logsoutData');
    addRequired(p, 'signalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'tStart', @isnumeric);
    addRequired(p, 'tEnd', @isnumeric);
    addParameter(p, 'AutoAlign', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'Normalized', false, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'NormalizeBy', 'mean', @(x) (ischar(x) || isstring(x)) || isnumeric(x));
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, logsoutData, signalName, tStart, tEnd, varargin{:});

    signalName = char(p.Results.signalName);
    autoAlign  = logical(p.Results.AutoAlign);
    normalized = logical(p.Results.Normalized);
    normOpt    = p.Results.NormalizeBy;
    doPlot     = logical(p.Results.Plot);

    if tEnd <= tStart
        error('calcStdDev:BadWindow', 'tEnd must be greater than tStart.');
    end

    % ---------------- Locate the signal in logsout ----------------
    sigElement = findSignalRecursive(logsoutData, signalName);
    if isempty(sigElement)
        error('calcStdDev:SignalNotFound', ...
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
        error('calcStdDev:UnsupportedType', ...
            'Unsupported data type for signal "%s". Expected a timeseries.', signalName);
    end

    if ~isvector(yRaw)
        error('calcStdDev:NotScalarSignal', ...
            'calcStdDev currently supports single-channel (scalar) signals only.');
    end

    % ---------------- Crop with padding for zero-crossing search --------
    span = tEnd - tStart;
    marginFrac = 0.20;
    padStart = max(tRaw(1), tStart - marginFrac * span);
    padEnd   = min(tRaw(end), tEnd + marginFrac * span);

    maskPad = tRaw >= padStart & tRaw <= padEnd;
    if nnz(maskPad) < 8
        error('calcStdDev:InsufficientSamples', ...
            'Fewer than 8 samples found around [tStart, tEnd]. Check the time window/units.');
    end
    tPad = tRaw(maskPad);
    yPad = yRaw(maskPad);
    [tPad, iu] = unique(tPad, 'stable');
    yPad = yPad(iu);
    [tPad, isort] = sort(tPad);
    yPad = yPad(isort);

    % ---------------- Auto-align to zero-crossings -------------------------
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
            warning('calcStdDev:NoZeroCrossings', ...
                ['AutoAlign requested but fewer than 2 zero-crossings were found. ', ...
                 'Falling back to the raw [tStart, tEnd] window (no alignment).']);
            autoAlign = false;
        else
            i1 = risingIdx;
            i2 = risingIdx + 1;
            frac = -yDetrend(i1) ./ (yDetrend(i2) - yDetrend(i1));
            crossTimes = tPad(i1) + frac .* (tPad(i2) - tPad(i1));

            [~, kStart] = min(abs(crossTimes - tStart));
            [~, kEnd]   = min(abs(crossTimes - tEnd));

            if kEnd <= kStart
                warning('calcStdDev:BadAlignment', ...
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

    % ---------------- Crop to final aligned window -----------------------
    mask = tRaw >= tStartAligned & tRaw <= tEndAligned;
    if nnz(mask) < 2
        error('calcStdDev:InsufficientSamples', ...
            'Fewer than 2 samples found in the aligned window. Check the time window/units.');
    end
    tWin = tRaw(mask);
    yWin = yRaw(mask);
    [tWin, iu2] = unique(tWin, 'stable');
    yWin = yWin(iu2);
    [tWin, isort2] = sort(tWin);
    yWin = yWin(isort2);

    % ---------------- Time-weighted mean and standard deviation ------------
    duration = tEndAligned - tStartAligned;
    meanValue = trapz(tWin, yWin) / duration;
    devSq = (yWin - meanValue).^2;
    variance = trapz(tWin, devSq) / duration;
    stdAbs = sqrt(variance);

    % ---------------- Resolve normalization reference ----------------------
    if (ischar(normOpt) || isstring(normOpt)) && strcmpi(normOpt, 'mean')
        reference = abs(meanValue);
    else
        reference = abs(double(normOpt));
    end

    if normalized || nargout > 1
        if reference <= eps
            if normalized
                error('calcStdDev:ZeroReference', ...
                    ['Reference value is ~0, cannot normalize. Pass a numeric ', ...
                     '''NormalizeBy'' value (e.g. rated current/torque) instead.']);
            end
            stdPct = NaN;
        else
            stdPct = 100 * stdAbs / reference;
        end
    end

    if normalized
        stdDev = stdPct;
    else
        stdDev = stdAbs;
    end

    info.numPeriods    = numPeriods;
    info.period        = period;
    if ~isnan(period)
        info.freq = 1 / period;
    else
        info.freq = NaN;
    end
    info.tStartAligned = tStartAligned;
    info.tEndAligned   = tEndAligned;
    info.mean          = meanValue;
    info.std           = stdAbs;
    info.stdPct        = stdPct;
    info.reference     = reference;

    % ---------------- Optional plotting --------------------------------------
    if doPlot
        figure('Name', sprintf('Standard deviation analysis: %s', signalName));
        plot(tPad, yPad, 'Color', [0.6 0.6 0.6]); hold on;
        plot(tWin, yWin, 'b-', 'LineWidth', 1.2);
        yline(meanValue, 'r--', sprintf('Mean = %.4f', meanValue), 'LineWidth', 1.2);
        yline(meanValue + stdAbs, 'g:', '+1\sigma');
        yline(meanValue - stdAbs, 'g:', '-1\sigma');
        xline(tStartAligned, 'k:', 'Aligned start');
        xline(tEndAligned, 'k:', 'Aligned end');
        xlabel('Time (s)'); ylabel(signalName);
        if ~isnan(numPeriods)
            title(sprintf('%s - %d period(s) - std = %.4f (%.3f%% of ref)', ...
                signalName, numPeriods, stdAbs, stdPct));
        else
            title(sprintf('%s - std = %.4f (%.3f%% of ref)', signalName, stdAbs, stdPct));
        end
        legend('Padded region', 'Analysis window', 'Mean', 'Location', 'best');
        grid on;
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
