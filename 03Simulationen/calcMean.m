function [meanValue, info] = calcMean(logsoutData, signalName, tStart, tEnd, varargin)
%CALCMEANVALUE Compute the ripple-free mean value of any periodic (or
%quasi-periodic) signal logged in a Simulink Simulink.SimulationData.
%Dataset ("logsout"). Works for torque, current, speed, power, or any
%other logged quantity that has a repeating ripple/oscillation around a
%(locally) stable mean.
%
%   meanValue = calcMeanValue(out.logsout, 'Te', tStart, tEnd)
%   meanValue = calcMeanValue(out.logsout, 'FOC_ia', tStart, tEnd, 'Plot', true)
%   [meanValue, info] = calcMeanValue(...)
%
%   INPUTS
%     logsoutData  - Simulink.SimulationData.Dataset (out.logsout)
%     signalName   - char/string, name of the logged signal to analyze
%     tStart, tEnd - APPROXIMATE time window (seconds). You do not need
%                    to hit exact ripple-period boundaries: by default
%                    the function detrends the signal, finds the nearest
%                    true zero-crossings of the ripple, and averages over
%                    an exact integer number of ripple periods between
%                    them (see 'AutoAlign').
%
%   OPTIONAL NAME-VALUE PAIRS
%     'AutoAlign'    - true (default) | false
%                      If true, tStart/tEnd are snapped to the nearest
%                      detected ripple zero-crossings (on the detrended
%                      signal) so the averaging window spans an exact
%                      integer number of ripple periods.
%                      If false, the raw [tStart, tEnd] window is used
%                      as-is (legacy plain average, e.g. useful for
%                      non-periodic or transient signals).
%     'Plot'         - true/false, plot the signal, aligned window, and
%                      the computed mean.
%
%   OUTPUTS
%     meanValue - mean of the signal over the aligned window
%     info      - struct with fields:
%                   .numPeriods    number of ripple periods detected/used
%                   .ripplePeriod  estimated ripple period (s)
%                   .rippleFreq    estimated ripple frequency (Hz)
%                   .tStartAligned aligned start time actually used (s)
%                   .tEndAligned   aligned end time actually used (s)
%                   .mean          same as meanValue output
%                   .ptpRipple     peak-to-peak ripple over the window
%                   .rmsRipple     RMS of the ripple (signal - mean)
%
%   EXAMPLES
%     % Mean electromagnetic torque, approximate window:
%     Tavg = calcMeanValue(out.logsout, 'Te', 1.4763, 1.4989, 'Plot', true);
%
%     % Mean DC-link current, approximate window:
%     Idc_avg = calcMeanValue(out.logsout, 'Idc', 2.001, 2.050);
%
%     % Mean speed, no auto-alignment (e.g. during a transient):
%     wAvg = calcMeanValue(out.logsout, 'w_mech', 0.5, 0.6, 'AutoAlign', false);

    % ---------------- Parse inputs ----------------
    p = inputParser;
    addRequired(p, 'logsoutData');
    addRequired(p, 'signalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'tStart', @isnumeric);
    addRequired(p, 'tEnd', @isnumeric);
    addParameter(p, 'AutoAlign', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, logsoutData, signalName, tStart, tEnd, varargin{:});

    signalName = char(p.Results.signalName);
    autoAlign  = logical(p.Results.AutoAlign);
    doPlot     = logical(p.Results.Plot);

    if tEnd <= tStart
        error('calcMeanValue:BadWindow', 'tEnd must be greater than tStart.');
    end

    % ---------------- Locate the signal in logsout ----------------
    sigElement = findSignalRecursive(logsoutData, signalName);
    if isempty(sigElement)
        error('calcMeanValue:SignalNotFound', ...
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
        error('calcMeanValue:UnsupportedType', ...
            'Unsupported data type for signal "%s". Expected a timeseries.', signalName);
    end

    if ~isvector(yRaw)
        error('calcMeanValue:NotScalarSignal', ...
            'calcMeanValue currently supports single-channel (scalar) signals only.');
    end

    % ---------------- Crop with padding for zero-crossing search --------
    span = tEnd - tStart;
    marginFrac = 0.20;
    padStart = max(tRaw(1), tStart - marginFrac * span);
    padEnd   = min(tRaw(end), tEnd + marginFrac * span);

    maskPad = tRaw >= padStart & tRaw <= padEnd;
    if nnz(maskPad) < 8
        error('calcMeanValue:InsufficientSamples', ...
            'Fewer than 8 samples found around [tStart, tEnd]. Check the time window/units.');
    end
    tPad = tRaw(maskPad);
    yPad = yRaw(maskPad);
    [tPad, iu] = unique(tPad, 'stable');
    yPad = yPad(iu);
    [tPad, isort] = sort(tPad);
    yPad = yPad(isort);

    % ---------------- Auto-align to ripple zero-crossings -----------------
    tStartAligned = tStart;
    tEndAligned   = tEnd;
    numPeriods    = NaN;
    ripplePeriod  = NaN;

    if autoAlign
        yDetrend = yPad - mean(yPad); % expose ripple around zero
        s = sign(yDetrend);
        s(s == 0) = 1;
        risingIdx = find(diff(s) > 0);

        if numel(risingIdx) < 2
            warning('calcMeanValue:NoZeroCrossings', ...
                ['AutoAlign requested but fewer than 2 ripple zero-crossings were found. ', ...
                 'Falling back to the raw [tStart, tEnd] window (plain average, no alignment).']);
            autoAlign = false;
        else
            i1 = risingIdx;
            i2 = risingIdx + 1;
            frac = -yDetrend(i1) ./ (yDetrend(i2) - yDetrend(i1));
            crossTimes = tPad(i1) + frac .* (tPad(i2) - tPad(i1));

            [~, kStart] = min(abs(crossTimes - tStart));
            [~, kEnd]   = min(abs(crossTimes - tEnd));

            if kEnd <= kStart
                warning('calcMeanValue:BadAlignment', ...
                    'Could not find at least one full ripple period between tStart and tEnd. Falling back to plain average.');
                autoAlign = false;
            else
                tStartAligned = crossTimes(kStart);
                tEndAligned   = crossTimes(kEnd);
                numPeriods    = kEnd - kStart;
                ripplePeriod  = (tEndAligned - tStartAligned) / numPeriods;
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
        error('calcMeanValue:InsufficientSamples', ...
            'Fewer than 2 samples found in the aligned window. Check the time window/units.');
    end
    tWin = tRaw(mask);
    yWin = yRaw(mask);
    [tWin, iu2] = unique(tWin, 'stable');
    yWin = yWin(iu2);
    [tWin, isort2] = sort(tWin);
    yWin = yWin(isort2);

    % ---------------- Time-weighted mean (robust to non-uniform steps) ---
    duration = tEndAligned - tStartAligned;
    meanValue = trapz(tWin, yWin) / duration;

    ripple = yWin - meanValue;
    ptpRipple = max(yWin) - min(yWin);
    rmsRipple = sqrt(trapz(tWin, ripple.^2) / duration);

    info.numPeriods    = numPeriods;
    info.ripplePeriod  = ripplePeriod;
    info.rippleFreq    = 1 / ripplePeriod;
    info.tStartAligned = tStartAligned;
    info.tEndAligned   = tEndAligned;
    info.mean          = meanValue;
    info.ptpRipple     = ptpRipple;
    info.rmsRipple     = rmsRipple;

    % ---------------- Optional plotting --------------------------------------
    if doPlot
        figure('Name', sprintf('Mean value analysis: %s', signalName));
        plot(tPad, yPad, 'Color', [0.6 0.6 0.6]); hold on;
        plot(tWin, yWin, 'b-', 'LineWidth', 1.2);
        yline(meanValue, 'r--', sprintf('Mean = %.4f', meanValue), 'LineWidth', 1.2);
        xline(tStartAligned, 'k:', 'Aligned start');
        xline(tEndAligned, 'k:', 'Aligned end');
        xlabel('Time (s)'); ylabel(signalName);
        if ~isnan(numPeriods)
            title(sprintf('%s - aligned window [%.6f, %.6f] s, %d ripple period(s), ripple f=%.2f Hz', ...
                signalName, tStartAligned, tEndAligned, numPeriods, info.rippleFreq));
        else
            title(sprintf('%s - window [%.6f, %.6f] s (no auto-alignment)', ...
                signalName, tStartAligned, tEndAligned));
        end
        legend('Padded region', 'Averaging window', 'Mean', 'Location', 'best');
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
