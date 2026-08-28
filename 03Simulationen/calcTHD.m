function [THD, harmInfo] = calcTHD(logsoutData, signalName, tStart, tEnd, varargin)
%CALCTHD Compute Total Harmonic Distortion (THD) of a signal logged in a
%Simulink Simulink.SimulationData.Dataset ("logsout").
%
%   THD = calcTHD(out.logsout, 'FOC_ia', tStart, tEnd)
%   THD = calcTHD(out.logsout, 'FOC_ia', tStart, tEnd, 'Plot', true)
%   [THD, harmInfo] = calcTHD(...)
%
%   INPUTS
%     logsoutData  - Simulink.SimulationData.Dataset (out.logsout)
%     signalName   - char/string, name of the logged signal to analyze
%     tStart, tEnd - APPROXIMATE time window (seconds). You no longer
%                    need to hit the period boundaries precisely: by
%                    default the function auto-detects the nearest true
%                    zero-crossings and the exact number of fundamental
%                    periods contained between them (see 'AutoAlign').
%
%   OPTIONAL NAME-VALUE PAIRS
%     'AutoAlign'    - true (default) | false
%                      If true, tStart/tEnd are treated as approximate
%                      and snapped to the nearest detected rising
%                      zero-crossings; the number of periods and the
%                      fundamental frequency are derived from the data.
%                      If false, legacy behavior is used: tEnd-tStart is
%                      assumed to span exactly 'NumPeriods' periods.
%     'NumPeriods'   - (only used if AutoAlign=false) number of
%                      fundamental periods spanned by [tStart,tEnd].
%                      Default = 1.
%     'NumHarmonics' - number of harmonics (including fundamental) to
%                      consider, default = 25
%     'Fs'           - resampling frequency (Hz) for the uniform grid.
%                      Default: max(200*f0, 20*native sample rate).
%     'Window'       - 'hann' (default) or 'none'
%     'Plot'         - true/false, plot time-domain window + spectrum
%
%   OUTPUTS
%     THD      - Total Harmonic Distortion in percent (%)
%     harmInfo - struct with fields:
%                  .f0            fundamental frequency (Hz), auto-derived
%                  .numPeriods    number of periods detected/used
%                  .tStartAligned aligned start time actually used (s)
%                  .tEndAligned   aligned end time actually used (s)
%                  .freqs         frequency vector of harmonics analyzed
%                  .mags          magnitude of each harmonic (0-pk)
%                  .fundMag       magnitude of the fundamental
%                  .THD           same as THD output
%
%   EXAMPLE
%     % Approximate window is fine now -- no need to hand-pick exact
%     % zero-crossings:
%     THD = calcTHD(out.logsout, 'FOC_ia', 1.4763, 1.4989, ...
%                    'Fs', 1e6, 'NumHarmonics', 15, 'Plot', true);

    % ---------------- Parse inputs ----------------
    p = inputParser;
    addRequired(p, 'logsoutData');
    addRequired(p, 'signalName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'tStart', @isnumeric);
    addRequired(p, 'tEnd', @isnumeric);
    addParameter(p, 'AutoAlign', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'NumPeriods', 1, @(x) isnumeric(x) && x >= 1);
    addParameter(p, 'NumHarmonics', 25, @(x) isnumeric(x) && x >= 2);
    addParameter(p, 'Fs', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'Window', 'hann', @(x) any(strcmpi(x, {'hann','none'})));
    addParameter(p, 'Plot', false, @(x) islogical(x) || isnumeric(x));
    parse(p, logsoutData, signalName, tStart, tEnd, varargin{:});

    signalName    = char(p.Results.signalName);
    autoAlign     = logical(p.Results.AutoAlign);
    numPeriodsIn  = p.Results.NumPeriods;
    numHarmonics  = round(p.Results.NumHarmonics);
    winChoice     = lower(p.Results.Window);
    doPlot        = logical(p.Results.Plot);
    FsRequested   = p.Results.Fs;

    if tEnd <= tStart
        error('calcTHD:BadWindow', 'tEnd must be greater than tStart.');
    end

    % ---------------- Locate the signal in logsout ----------------
    sigElement = findSignalRecursive(logsoutData, signalName);
    if isempty(sigElement)
        error('calcTHD:SignalNotFound', ...
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
        error('calcTHD:UnsupportedType', ...
            'Unsupported data type for signal "%s". Expected a timeseries.', signalName);
    end

    if ~isvector(yRaw)
        error('calcTHD:NotScalarSignal', ...
            'calcTHD currently supports single-channel (scalar) signals only.');
    end

    % ---------------- Crop with padding for zero-crossing search --------
    span = tEnd - tStart;
    marginFrac = 0.20;
    padStart = max(tRaw(1), tStart - marginFrac * span);
    padEnd   = min(tRaw(end), tEnd + marginFrac * span);

    maskPad = tRaw >= padStart & tRaw <= padEnd;
    if nnz(maskPad) < 8
        error('calcTHD:InsufficientSamples', ...
            'Fewer than 8 samples found around [tStart, tEnd]. Check the time window/units.');
    end
    tPad = tRaw(maskPad);
    yPad = yRaw(maskPad);
    [tPad, iu] = unique(tPad, 'stable');
    yPad = yPad(iu);
    [tPad, isort] = sort(tPad);
    yPad = yPad(isort);

    nativeDt = median(diff(tPad));
    nativeFs = 1 / nativeDt;

    % ---------------- Auto-align to true zero-crossings -----------------
    tStartAligned = tStart;
    tEndAligned   = tEnd;
    numPeriods    = numPeriodsIn;

    if autoAlign
        yDetrend = yPad - mean(yPad);
        s = sign(yDetrend);
        s(s == 0) = 1;
        risingIdx = find(diff(s) > 0); % index i means crossing between i and i+1

        if numel(risingIdx) < 2
            warning('calcTHD:NoZeroCrossings', ...
                ['AutoAlign requested but fewer than 2 rising zero-crossings were found. ', ...
                 'Falling back to the raw [tStart, tEnd] window with NumPeriods=%d.'], numPeriodsIn);
            autoAlign = false;
        else
            % Sub-sample accurate crossing times via linear interpolation
            i1 = risingIdx;
            i2 = risingIdx + 1;
            frac = -yDetrend(i1) ./ (yDetrend(i2) - yDetrend(i1));
            crossTimes = tPad(i1) + frac .* (tPad(i2) - tPad(i1));

            % Snap to nearest crossing to the user's tStart / tEnd
            [~, kStart] = min(abs(crossTimes - tStart));
            [~, kEnd]   = min(abs(crossTimes - tEnd));

            if kEnd <= kStart
                warning('calcTHD:BadAlignment', ...
                    'Could not find at least one full period between tStart and tEnd. Falling back to legacy mode.');
                autoAlign = false;
            else
                tStartAligned = crossTimes(kStart);
                tEndAligned   = crossTimes(kEnd);
                numPeriods    = kEnd - kStart; % number of full periods between crossings
            end
        end
    end

    if ~autoAlign
        tStartAligned = tStart;
        tEndAligned   = tEnd;
        numPeriods    = numPeriodsIn;
    end

    f0 = numPeriods / (tEndAligned - tStartAligned);

    % ---------------- Crop to final aligned window -----------------------
    mask = tRaw >= tStartAligned & tRaw <= tEndAligned;
    if nnz(mask) < 4
        error('calcTHD:InsufficientSamples', ...
            'Fewer than 4 samples found in the aligned window. Check the time window/units.');
    end
    tWin = tRaw(mask);
    yWin = yRaw(mask);
    [tWin, iu2] = unique(tWin, 'stable');
    yWin = yWin(iu2);
    [tWin, isort2] = sort(tWin);
    yWin = yWin(isort2);

    % ---------------- Resample onto a uniform grid ------------------------
    if isempty(FsRequested)
        Fs = max(200 * f0, 20 * nativeFs);
    else
        Fs = FsRequested;
    end

    tUniform = (tStartAligned:1/Fs:tEndAligned)';
    if numel(tUniform) < 8
        error('calcTHD:GridTooCoarse', 'Resampled grid too coarse; increase Fs.');
    end
    yUniform = interp1(tWin, yWin, tUniform, 'pchip');

    % Drop the last point to avoid double-counting the periodic boundary
    yUniform(end) = [];
    tUniform(end) = [];
    N = numel(yUniform);

    % ---------------- Windowing + FFT --------------------------------------
    yDetrended = yUniform - mean(yUniform);

    switch winChoice
        case 'hann'
            w = hann(N, 'periodic');
            cg = sum(w) / N;
        otherwise
            w = ones(N, 1);
            cg = 1;
    end

    yWindowed = yDetrended .* w;

    Y = fft(yWindowed);
    Y = Y(1:floor(N/2)+1);
    magSpec = (abs(Y) / N) / cg;
    magSpec(2:end-1) = 2 * magSpec(2:end-1);

    freqAxis = (0:floor(N/2))' * (Fs / N);

    % ---------------- Extract fundamental + harmonics -----------------------
    freqRes = Fs / N;
    searchBand = max(3, round(0.5 * f0 / freqRes));

    harmFreqs = zeros(numHarmonics, 1);
    harmMags  = zeros(numHarmonics, 1);

    for k = 1:numHarmonics
        targetFreq = k * f0;
        [~, idxCenter] = min(abs(freqAxis - targetFreq));
        idxLo = max(1, idxCenter - searchBand);
        idxHi = min(numel(freqAxis), idxCenter + searchBand);
        [pk, relIdx] = max(magSpec(idxLo:idxHi));
        harmFreqs(k) = freqAxis(idxLo + relIdx - 1);
        harmMags(k)  = pk;
    end

    fundMag = harmMags(1);
    if fundMag <= eps
        error('calcTHD:NoFundamental', ...
            'Fundamental magnitude is ~0; check the signal and time window.');
    end

    THD = 100 * sqrt(sum(harmMags(2:end).^2)) / fundMag;

    harmInfo.f0            = f0;
    harmInfo.numPeriods    = numPeriods;
    harmInfo.tStartAligned = tStartAligned;
    harmInfo.tEndAligned   = tEndAligned;
    harmInfo.freqs         = harmFreqs;
    harmInfo.mags          = harmMags;
    harmInfo.fundMag       = fundMag;
    harmInfo.THD           = THD;

    % ---------------- Optional plotting --------------------------------------
    if doPlot
        figure('Name', sprintf('THD analysis: %s', signalName));
        subplot(2,1,1);
        plot(tWin, yWin, 'b-'); hold on;
        plot(tUniform, yUniform, 'r--');
        xline(tStartAligned, 'k:', 'Aligned start');
        xline(tEndAligned, 'k:', 'Aligned end');
        legend('Original samples', 'Resampled', 'Location', 'best');
        xlabel('Time (s)'); ylabel('Amplitude');
        title(sprintf('%s - aligned window [%.6f, %.6f] s, %d period(s), f0=%.3f Hz', ...
            signalName, tStartAligned, tEndAligned, numPeriods, f0));
        grid on;

        subplot(2,1,2);
        stem(harmFreqs, harmMags, 'filled');
        xlabel('Frequency (Hz)'); ylabel('Amplitude');
        title(sprintf('Harmonic spectrum - THD = %.3f %%', THD));
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
