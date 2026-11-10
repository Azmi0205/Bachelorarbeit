function [logsout, T] = alignRampData(source)
%ALIGNRAMPDATA Align two USER_SPEED_REF ramp measurements to a common
%time base and package the result as a logsout-style
%Simulink.SimulationData.Dataset, ready for PLOTLOGGEDSIGNAL1X1.
%
%   LOGSOUT = ALIGNRAMPDATA(SOURCE) processes exactly two CSV log files
%   (identified by containing 'Ramp' in their file name) using
%   READUSERSPEEDCSVLOG, detects the start of the 300 ms USER_SPEED_REF
%   ramp in each file, shifts each file's time vector so that its ramp
%   begins at t = 0.1 s, resamples both files onto a common time vector,
%   and returns a Simulink dataset containing:
%
%       USER_SPEED_MEAS_1   - measured speed from the first Ramp file
%       USER_SPEED_MEAS_2   - measured speed from the second Ramp file
%       USER_SPEED_REF       - common (aligned) reference speed
%
%   [LOGSOUT, T] = ALIGNRAMPDATA(SOURCE) additionally returns a table T
%   with columns time, USER_SPEED_MEAS_1, USER_SPEED_MEAS_2,
%   USER_SPEED_REF.
%
%   SOURCE may be a folder path (all *.csv files in it are scanned) or a
%   cell array of full file paths.
%
%   Requires READUSERSPEEDCSVLOG on the MATLAB path.

    if nargin < 1 || isempty(source)
        source = pwd;
    end

    rampDuration    = 0.300; % [s] known ramp length
    targetRampStart = 0.100; % [s] desired aligned ramp-start time

    %% Resolve the two "Ramp" files
    if isfolder(source)
        d = dir(fullfile(source, '*.csv'));
        allNames = {d.name};
        fullPaths = fullfile(source, allNames);
    else
        fullPaths = cellstr(source);
        [~, allNames, ext] = cellfun(@fileparts, fullPaths, ...
            'UniformOutput', false);
        allNames = strcat(allNames, ext);
    end

    isRamp = contains(allNames, 'Ramp', 'IgnoreCase', true);
    rampFiles = fullPaths(isRamp);

    if numel(rampFiles) ~= 2
        error('alignRampData:unexpectedFileCount', ...
            'Expected exactly 2 files containing ''Ramp'' in their name, found %d.', ...
            numel(rampFiles));
    end

    %% Read and time-align each ramp file
    Tdata   = cell(1, 2);
    tStarts = zeros(1, 2);
    for k = 1:2
        [~, Tk] = readUserSpeedCSVlog(rampFiles{k});

        tRampStart = detectRampStart(Tk.time, Tk.USER_SPEED_REF, rampDuration);
        tStarts(k) = tRampStart;

        % Shift so the detected ramp start lands on targetRampStart.
        Tk.time = Tk.time - tRampStart + targetRampStart;

        Tdata{k} = Tk;
    end

    %% Build a common time vector (overlap of both files, finest step)
    tMin = max(cellfun(@(Tt) Tt.time(1),   Tdata));
    tMax = min(cellfun(@(Tt) Tt.time(end), Tdata));
    if tMax <= tMin
        error('alignRampData:noOverlap', ...
            'The two files do not overlap in time after ramp alignment.');
    end
    dt = min(cellfun(@(Tt) median(diff(Tt.time)), Tdata));
    timeCommon = (tMin:dt:tMax)';

    %% Resample both files onto the common time vector
    speedMeas = zeros(numel(timeCommon), 2);
    speedRef  = zeros(numel(timeCommon), 2);
    for k = 1:2
        speedMeas(:, k) = interp1(Tdata{k}.time, Tdata{k}.USER_SPEED_MEAS, ...
            timeCommon, 'linear', 'extrap');
        speedRef(:, k) = interp1(Tdata{k}.time, Tdata{k}.USER_SPEED_REF, ...
            timeCommon, 'linear', 'extrap');
    end

    %% Combine REF into a single common signal (sanity-checked)
    refCommon = mean(speedRef, 2);
    refDiff = abs(speedRef(:, 1) - speedRef(:, 2));
    [maxRefDiff, idxWorst] = max(refDiff);
    if maxRefDiff > 1e-2 * max(abs(refCommon))
        warning('alignRampData:refMismatch', ...
            ['USER_SPEED_REF profiles differ by up to %.4f rad/s after ' ...
             'alignment (at t = %.4f s of the common time vector). ' ...
             'Detected raw ramp-start times: file 1 = %.4f s, file 2 = ' ...
             '%.4f s. If this seems wrong, plot Tdata{1}.time vs. ' ...
             'Tdata{1}.USER_SPEED_REF and Tdata{2}.time vs. ' ...
             'Tdata{2}.USER_SPEED_REF (before the shift) to verify the ' ...
             'detector found the true 300 ms ramp in each file.'], ...
             maxRefDiff, timeCommon(idxWorst), tStarts(1), tStarts(2));
    end

    %% Assemble output table
    T = table( ...
        timeCommon, speedMeas(:,1), speedMeas(:,2), refCommon, ...
        'VariableNames', ...
        {'time','USER_SPEED_MEAS_1','USER_SPEED_MEAS_2','USER_SPEED_REF'});

    %% Build logsout dataset for plotLoggedSignal1x1
    logsout = Simulink.SimulationData.Dataset;

    signalDefs = { ...
        'USER_SPEED_MEAS_1', speedMeas(:,1); ...
        'USER_SPEED_MEAS_2', speedMeas(:,2); ...
        'USER_SPEED_REF',    refCommon};

    for k = 1:size(signalDefs, 1)
        sigName = signalDefs{k, 1};
        sigData = signalDefs{k, 2};

        ts = timeseries(sigData, timeCommon, 'Name', sigName);

        sigElement = Simulink.SimulationData.Signal;
        sigElement.Name = sigName;
        sigElement.Values = ts;

        logsout = logsout.addElement(sigElement, sigName);
    end
end

function tStart = detectRampStart(t, ref, rampDuration)
%DETECTRAMPSTART Find the time at which REF departs from a steady value
%and begins the characteristic ramp of approximately RAMPDURATION
%seconds. Robust to isolated noise spikes and unrelated short
%transients by requiring the elevated-slope run to actually last close
%to RAMPDURATION.

    t   = t(:);
    ref = ref(:);
    dt  = median(diff(t));

    % Light smoothing to suppress measurement noise before differentiating.
    smoothWinSec = 0.01; % 10 ms
    smoothWin = max(3, round(smoothWinSec / dt));
    refSmooth = movmean(ref, smoothWin);

    d = gradient(refSmooth, t);

    % Adaptive threshold: well above the typical "flat section" slope,
    % but well below the peak ramp slope.
    noiseFloor = median(abs(d));
    slopeThreshold = max(5 * noiseFloor, 0.10 * max(abs(d)));

    isRamping = abs(d) > slopeThreshold;

    % Find contiguous "ramping" runs.
    edgesUp   = find(diff([false; isRamping]) == 1);
    edgesDown = find(diff([isRamping; false]) == -1);

    if isempty(edgesUp)
        error('detectRampStart:noRamp', ...
            'No ramp-like slope could be detected in USER_SPEED_REF.');
    end

    runDurations = t(edgesDown) - t(edgesUp);

    % Pick the run whose duration is closest to the expected ramp length.
    [~, bestRun] = min(abs(runDurations - rampDuration));
    idxRampStart = edgesUp(bestRun);

    % Warn if even the best match is far off the expected duration -
    % this usually means the wrong feature was picked up.
    if abs(runDurations(bestRun) - rampDuration) > 0.5 * rampDuration
        warning('detectRampStart:durationMismatch', ...
            ['Best matching ramp-like segment lasts %.3f s, which is ' ...
             'far from the expected %.3f s. Detection may be picking ' ...
             'up the wrong feature; inspect the USER_SPEED_REF signal ' ...
             'manually.'], runDurations(bestRun), rampDuration);
    end

    tStart = t(idxRampStart);
end
