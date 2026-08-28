function [ripplePct, info] = calcRipple(logsoutData, signalName, tStart, tEnd, varargin)
%CALCRIPPLE Compute the normalized ripple (in percent) of any periodic
%(or quasi-periodic) signal logged in a Simulink
%Simulink.SimulationData.Dataset ("logsout"). Works for torque, DC-link
%current/voltage, speed, or any other logged quantity with a repeating
%oscillation around a (locally) stable mean.
%
%   ripplePct = calcRipple(out.logsout, 'Te', tStart, tEnd)
%   ripplePct = calcRipple(out.logsout, 'Idc', tStart, tEnd, 'Plot', true)
%   ripplePct = calcRipple(out.logsout, 'Idc', tStart, tEnd, 'NormalizeBy', 10)
%   [ripplePct, info] = calcRipple(...)
%
%   INPUTS
%     logsoutData  - Simulink.SimulationData.Dataset (out.logsout)
%     signalName   - char/string, name of the logged signal to analyze
%     tStart, tEnd - APPROXIMATE time window (seconds). You do not need
%                    to hit exact ripple-period boundaries: by default
%                    the function detrends the signal, finds the nearest
%                    true zero-crossings of the ripple, and analyzes an
%                    exact integer number of ripple periods between them
%                    (see 'AutoAlign').
%
%   OPTIONAL NAME-VALUE PAIRS
%     'AutoAlign'    - true (default) | false
%                      If true, tStart/tEnd are snapped to the nearest
%                      detected ripple zero-crossings (on the detrended
%                      signal) so the analysis window spans an exact
%                      integer number of ripple periods.
%     'Definition'   - 'ptp' (default) | 'rms'
%                      Which ripple definition is returned as the
%                      primary output ripplePct:
%                        'ptp' -> 100 * (max-min) / (2*reference)
%                        'rms' -> 100 * RMS(signal-mean) / reference
%                      Both values are always available in info.
%     'NormalizeBy'  - 'mean' (default) | numeric scalar
%                      Reference value used for normalization. 'mean'
%                      uses the signal's own mean over the aligned
%                      window (standard for torque/current ripple specs
%                      with a clear nonzero DC value). Pass a numeric
%                      value (e.g. rated current) instead if the mean is
%                      near zero or you want ripple relative to a fixed
%                      nominal value.
%     'Plot'         - true/false, plot the signal, aligned window, mean,
%                      and ripple bounds.
%
%   OUTPUTS
%     ripplePct - ripple in percent, per the chosen 'Definition'
%     info      - struct with fields:
%                   .numPeriods      number of ripple periods used
%                   .ripplePeriod    estimated ripple period (s)
%                   .rippleFreq      estimated ripple frequency (Hz)
%                   .tStartAligned   aligned start time used (s)
%                   .tEndAligned     aligned end time used (s)
%                   .mean            mean value over the aligned window
%                   .reference       actual reference value used for
%                                    normalization
%                   .ptpAbs          absolute peak-to-peak value
%                   .rmsAbs          absolute RMS of (signal - mean)
%                   .ripplePctPTP    peak-to-peak ripple, percent
%                   .ripplePctRMS    RMS ripple, percent
%
%   EXAMPLES
%     % Torque ripple, peak-to-peak, normalized by mean torque:
%     rippleT = calcRipple(out.logsout, 'Te', 1.4763, 1.4989, 'Plot', true);
%
%     % DC-link current ripple, RMS definition, normalized by rated current:
%     rippleIdc = calcRipple(out.logsout, 'Idc', 2.0, 2.05, ...
%                             'Definition', 'rms', 'NormalizeBy', 15);

    % ---------------- Parse inputs ----------------
    p = inputParser;
    addRequired(p, 'logsoutData');
    addRequired(p, 'signalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'tStart', @isnumeric);
    addRequired(p, 'tEnd', @isnumeric);
    addParameter(p, 'AutoAlign', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'Definition', 'ptp', @(x) any(strcmpi(x, {'ptp','rms'})));
    addParameter(p, 'NormalizeBy', 'mean', @(x) (ischar(x) || isstring(x)) || isnumeric(x));
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, logsoutData, signalName, tStart, tEnd, varargin{:});

    signalName  = char(p.Results.signalName);
    autoAlign   = logical(p.Results.AutoAlign);
    definition  = lower(char(p.Results.Definition));
    normOpt     = p.Results.NormalizeBy;
    doPlot      = logical(p.Results.Plot);

    if tEnd <= tStart
        error('calcRipple:BadWindow', 'tEnd must be greater than tStart.');
    end

    % ---------------- Locate the signal in logsout ----------------
    sigElement = findSignalRecursive(logsoutData, signalName);
    if isempty(sigElement)
        error('calcRipple:SignalNotFound', ...
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
        error('calcRipple:UnsupportedType', ...
            'Unsupported data type for signal "%s". Expected a timeseries.', signalName);
    end

    if ~isvector(yRaw)
        error('calcRipple:NotScalarSignal', ...
            'calcRipple currently supports single-channel (scalar) signals only.');
    end

    % ---------------- Crop with padding for zero-crossing search --------
    span = tEnd - tStart;
    marginFrac = 0.20;
    padStart = max(tRaw(1), tStart - marginFrac * span);
    padEnd   = min(tRaw(end), tEnd + marginFrac * span);

    maskPad = tRaw >= padStart & tRaw <= padEnd;
    if nnz(maskPad) < 8
        error('calcRipple:InsufficientSamples', ...
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
            warning('calcRipple:NoZeroCrossings', ...
                ['AutoAlign requested but fewer than 2 ripple zero-crossings were found. ', ...
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
                warning('calcRipple:BadAlignment', ...
                    'Could not find at least one full ripple period between tStart and tEnd. Falling back to raw window.');
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
        error('calcRipple:InsufficientSamples', ...
            'Fewer than 2 samples found in the aligned window. Check the time window/units.');
    end
    tWin = tRaw(mask);
    yWin = yRaw(mask);
    [tWin, iu2] = unique(tWin, 'stable');
    yWin = yWin(iu2);
    [tWin, isort2] = sort(tWin);
    yWin = yWin(isort2);

    % ---------------- Time-weighted mean + ripple metrics -----------------
    duration = tEndAligned - tStartAligned;
    meanValue = trapz(tWin, yWin) / duration;

    ripple = yWin - meanValue;
    ptpAbs = max(yWin) - min(yWin);
    rmsAbs = sqrt(trapz(tWin, ripple.^2) / duration);

    % ---------------- Resolve normalization reference ----------------------
    if (ischar(normOpt) || isstring(normOpt)) && strcmpi(normOpt, 'mean')
        reference = abs(meanValue);
        if reference <= eps
            error('calcRipple:ZeroMean', ...
                ['Mean value is ~0, cannot normalize by mean. Pass a numeric ', ...
                 '''NormalizeBy'' value (e.g. rated current/torque) instead.']);
        end
    else
        reference = abs(double(normOpt));
        if reference <= eps
            error('calcRipple:ZeroReference', '''NormalizeBy'' value must be nonzero.');
        end
    end

    ripplePctPTP = 100 * ptpAbs / (2 * reference);
    ripplePctRMS = 100 * rmsAbs / reference;

    switch definition
        case 'ptp'
            ripplePct = ripplePctPTP;
        case 'rms'
            ripplePct = ripplePctRMS;
    end

    info.numPeriods    = numPeriods;
    info.ripplePeriod  = ripplePeriod;
    if ~isnan(ripplePeriod)
        info.rippleFreq = 1 / ripplePeriod;
    else
        info.rippleFreq = NaN;
    end
    info.tStartAligned = tStartAligned;
    info.tEndAligned   = tEndAligned;
    info.mean          = meanValue;
    info.reference     = reference;
    info.ptpAbs        = ptpAbs;
    info.rmsAbs        = rmsAbs;
    info.ripplePctPTP  = ripplePctPTP;
    info.ripplePctRMS  = ripplePctRMS;

    % ---------------- Optional plotting --------------------------------------
    if doPlot
        figure('Name', sprintf('Ripple analysis: %s', signalName));
        plot(tPad, yPad, 'Color', [0.6 0.6 0.6]); hold on;
        plot(tWin, yWin, 'b-', 'LineWidth', 1.2);
        yline(meanValue, 'r--', sprintf('Mean = %.4f', meanValue), 'LineWidth', 1.2);
        yline(max(yWin), 'g:', 'Max');
        yline(min(yWin), 'g:', 'Min');
        xline(tStartAligned, 'k:', 'Aligned start');
        xline(tEndAligned, 'k:', 'Aligned end');
        xlabel('Time (s)'); ylabel(signalName);
        if ~isnan(numPeriods)
            title(sprintf('%s - %d period(s) - PTP ripple=%.3f%%, RMS ripple=%.3f%%', ...
                signalName, numPeriods, ripplePctPTP, ripplePctRMS));
        else
            title(sprintf('%s - PTP ripple=%.3f%%, RMS ripple=%.3f%%', ...
                signalName, ripplePctPTP, ripplePctRMS));
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
