clear; clc; close all;

%% ---- Configuration ----
Kv = 210;                         % Speed constant in RPM/V
minPeakDistanceSeconds = 0.01;   % Minimum spacing between extrema, in seconds
tailFraction = 0.2;              % Discard envelope below 20% of maximum
smoothSpan = 5;                  % Moving-average smoothing window, in samples
J = 1.29 * 10^-4;                 % Rotor inertia

plotSingleFileOnly = true;       % true: plot one file, false: plot all files
plotFileIndex = 3;                % Index of the file to plot

%% ---- Locate data folder ----
scriptDir = fileparts(matlab.desktop.editor.getActiveFilename);

if isempty(scriptDir)
    scriptDir = pwd;
end

dataDir = fullfile(scriptDir, 'PicoSpeedDecay');

if ~isfolder(dataDir)
    error('Data folder not found: %s', dataDir);
end

matFiles = dir(fullfile(dataDir, '*.mat'));

if isempty(matFiles)
    error('No .mat files found in %s', dataDir);
end

nFiles = numel(matFiles);

%% ---- Validate configuration ----
if ~isscalar(minPeakDistanceSeconds) || ...
        ~isfinite(minPeakDistanceSeconds) || ...
        minPeakDistanceSeconds <= 0

    error('minPeakDistanceSeconds must be a positive finite scalar.');
end

if ~isscalar(plotSingleFileOnly) || ...
        ~(islogical(plotSingleFileOnly) || ...
        (isnumeric(plotSingleFileOnly) && ...
        isfinite(plotSingleFileOnly)))

    error('plotSingleFileOnly must be true or false.');
end

plotSingleFileOnly = logical(plotSingleFileOnly);

if plotSingleFileOnly

    if ~isscalar(plotFileIndex) || ...
            ~isfinite(plotFileIndex) || ...
            plotFileIndex ~= round(plotFileIndex) || ...
            plotFileIndex < 1 || ...
            plotFileIndex > nFiles

        error('plotFileIndex must be an integer between 1 and %d.', ...
            nFiles);
    end

    plotFileIndex = round(plotFileIndex);
end

%% ---- Determine which files to plot ----
if plotSingleFileOnly
    filesToPlot = plotFileIndex;
else
    filesToPlot = 1:nFiles;
end

nPlotFiles = numel(filesToPlot);

%% ---- Results ----
fileNames = strings(nFiles, 1);
slopes = nan(nFiles, 1);
omega0 = nan(nFiles, 1);
rSquared = nan(nFiles, 1);

%% ---- Figures ----
figRaw = figure( ...
    'Name', 'Raw Back-EMF and Detected Peaks', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

figEnvelope = figure( ...
    'Name', 'Back-EMF Envelope and Deceleration Region', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

figLog = figure( ...
    'Name', 'Log-Speed Linear Fits', ...
    'NumberTitle', 'off', ...
    'Color', 'w');

%% ---- Process files ----
for k = 1:nFiles

    %% ---- Load file ----
    fPath = fullfile(dataDir, matFiles(k).name);
    S = load(fPath);

    fileNames(k) = string(matFiles(k).name);

    if ~isfield(S, 'A')
        warning('File "%s" has no variable A. Skipping.', ...
            matFiles(k).name);
        continue;
    end

    if ~isfield(S, 'Tinterval')
        error('File "%s" has no Tinterval variable.', ...
            matFiles(k).name);
    end

    v = double(S.A(:));
    dt = double(S.Tinterval);

    if ~isscalar(dt) || ~isfinite(dt) || dt <= 0
        error('File "%s" has an invalid Tinterval value.', ...
            matFiles(k).name);
    end

    t = (0:numel(v)-1)' * dt;

    %% ---- Convert configured spacing from seconds to samples ----
    minPeakDistance = max(1, ...
        round(minPeakDistanceSeconds / dt));

    %% ---- Remove DC offset ----
    v = v - median(v);

    %% ---- Smooth only for peak detection ----
    % The raw waveform is retained for plotting.
    smoothWindow = max(3, round(smoothSpan));
    vSmooth = movmean(v, smoothWindow);

    %% ---- Detect positive and negative local extrema ----
    signalScale = max(abs(vSmooth));

    if signalScale == 0
        warning('File "%s" contains no measurable signal.', ...
            matFiles(k).name);
        continue;
    end

    prominence = 0.01 * signalScale;

    [positivePeaks, positiveLocations] = findpeaks( ...
        vSmooth, ...
        'MinPeakDistance', minPeakDistance, ...
        'MinPeakProminence', prominence);

    [negativePeaksReversed, negativeLocations] = findpeaks( ...
        -vSmooth, ...
        'MinPeakDistance', minPeakDistance, ...
        'MinPeakProminence', prominence);

    negativePeaks = -negativePeaksReversed;

    %% ---- Keep physically valid extrema ----
    % Keep only physically positive maxima.
    positiveKeep = positivePeaks > 0;

    positivePeaks = positivePeaks(positiveKeep);
    positiveLocations = positiveLocations(positiveKeep);

    % Keep only physically negative minima.
    negativeKeep = negativePeaks < 0;

    negativePeaks = negativePeaks(negativeKeep);
    negativeLocations = negativeLocations(negativeKeep);

    %% ---- Choose clearer extrema set ----
    % Select the extrema set with the more consistent peak amplitude.
    positiveScore = peakQuality(positivePeaks);
    negativeScore = peakQuality(abs(negativePeaks));

    if positiveScore >= negativeScore
        peakValues = positivePeaks;
        peakLocations = positiveLocations;
        selectedPeakType = 'positive maxima';
    else
        peakValues = negativePeaks;
        peakLocations = negativeLocations;
        selectedPeakType = 'negative minima';
    end

    if numel(peakValues) < 3
        warning('Too few extrema detected in "%s". Skipping.', ...
            matFiles(k).name);
        continue;
    end

    peakTimes = t(peakLocations);
    peakEnvelope = abs(peakValues);

    %% ---- Sort extrema by time ----
    [peakTimes, sortIndex] = sort(peakTimes);

    peakEnvelope = peakEnvelope(sortIndex);
    peakValues = peakValues(sortIndex);

    %% ---- Determine deceleration start ----
    % The largest detected envelope peak marks the transition from
    % acceleration to deceleration.
    [maximumEnvelope, maximumIndex] = max(peakEnvelope);

    decelTimes = peakTimes(maximumIndex:end);
    decelEnvelope = peakEnvelope(maximumIndex:end);

    %% ---- Trim low-voltage tail ----
    % Avoid taking the logarithm of values close to zero/noise.
    envelopeThreshold = tailFraction * maximumEnvelope;

    keepTail = decelEnvelope >= envelopeThreshold;

    decelTimes = decelTimes(keepTail);
    decelEnvelope = decelEnvelope(keepTail);

    if numel(decelEnvelope) < 3
        warning('Too few deceleration points remain in "%s". Skipping.', ...
            matFiles(k).name);
        continue;
    end

    %% ---- Convert envelope voltage to rotor speed ----
    % Kv is assumed to be RPM/V for the measured line-to-line envelope.
    omegaDecel = (2*pi/60) * Kv * decelEnvelope;

    %% ---- Take logarithm ----
    logOmega = log(omegaDecel);

    %% ---- Linear fit ----
    fitCoefficients = polyfit(decelTimes, logOmega, 1);

    slope = fitCoefficients(1);
    intercept = fitCoefficients(2);

    logOmegaFit = polyval(fitCoefficients, decelTimes);

    %% ---- Goodness of fit ----
    residuals = logOmega - logOmegaFit;

    ssResidual = sum(residuals.^2);
    ssTotal = sum((logOmega - mean(logOmega)).^2);

    if ssTotal > 0
        rSquared(k) = 1 - ssResidual / ssTotal;
    end

    slopes(k) = slope;
    omega0(k) = exp(intercept);

    %% ---- Skip plots for unselected files ----
    if ~ismember(k, filesToPlot)
        continue;
    end

    plotIndex = find(filesToPlot == k, 1);

    %% ---- Plot raw waveform and selected extrema ----
    figure(figRaw);

    subplot(nPlotFiles, 1, plotIndex);

    plot(t, v, 'Color', [0.65 0.65 0.65]);
    hold on;

    plot(peakTimes, peakValues, 'bo', ...
        'MarkerFaceColor', 'b', ...
        'MarkerSize', 4);

    xline(peakTimes(maximumIndex), 'r--');

    xlim([min(peakTimes), max(peakTimes)]);
    ylim([-2.5 2.5]);

    grid on;
    ylabel('U_{LL} (V)');

    title(sprintf('selected %s, minimum spacing = %.6g s', ...
        selectedPeakType, ...
        minPeakDistanceSeconds), ...
        'Interpreter', 'none');

    if plotIndex == nPlotFiles
        xlabel('Time (s)');
    end

    %% ---- Plot envelope and retained deceleration data ----
    figure(figEnvelope);

    subplot(nPlotFiles, 1, plotIndex);

    plot(peakTimes, peakEnvelope, 'ko-', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 4);

    hold on;

    plot(decelTimes, decelEnvelope, 'ro', ...
        'MarkerFaceColor', 'r', ...
        'MarkerSize', 5);

    yline(envelopeThreshold, 'b--', 'Tail threshold');

    xline(peakTimes(maximumIndex), 'r--', ...
        'Deceleration begins');

    grid on;
    ylabel('|V_{LL,pk}|');

    title(matFiles(k).name, 'Interpreter', 'none');

    if plotIndex == nPlotFiles
        xlabel('Time (s)');
    end

    %% ---- Plot log-speed fit ----
    figure(figLog);

    subplot(nPlotFiles, 1, plotIndex);

    plot(decelTimes, logOmega, 'ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 4);

    hold on;

    plot(decelTimes, logOmegaFit, 'r-', ...
        'LineWidth', 1.5);

    grid on;
    ylabel('ln(\omega)');

    title(sprintf('%s: slope = %.5g 1/s, R^2 = %.4f', ...
        matFiles(k).name, ...
        slope, ...
        rSquared(k)), ...
        'Interpreter', 'none');

    legend('Data', 'Linear fit', 'Location', 'best');

    if plotIndex == nPlotFiles
        xlabel('Time (s)');
    end

end

%% ---- Figure titles ----
if plotSingleFileOnly
    plotModeText = sprintf( ...
        'Single file: %s', matFiles(plotFileIndex).name);
else
    plotModeText = 'All files';
end

sgtitle(figRaw, ...
    sprintf('Line-to-Line Back-EMF with Detected Extrema (%s)', ...
    plotModeText), ...
    'Interpreter', 'none');

sgtitle(figEnvelope, ...
    sprintf('Extracted Back-EMF Envelope (%s)', plotModeText), ...
    'Interpreter', 'none');

sgtitle(figLog, ...
    sprintf('Log-Speed Decay and Linear Fits (%s)', plotModeText), ...
    'Interpreter', 'none');

%% ---- Display results ----
resultsTable = table( ...
    fileNames, ...
    slopes, ...
    -slopes, ...
    omega0, ...
    rSquared, ...
    'VariableNames', { ...
        'File', ...
        'Slope_1_per_s', ...
        'B_over_J_1_per_s', ...
        'Omega0_rad_per_s', ...
        'R_squared'});

disp(resultsTable);

validSlopes = slopes(~isnan(slopes));

if ~isempty(validSlopes)

    meanSlope = mean(validSlopes);
    meanBoverJ = -meanSlope;
    B = meanBoverJ * J;

    fprintf('\nMean slope: %.6g 1/s\n', meanSlope);
    fprintf('Estimated B/J: %.6g 1/s\n', meanBoverJ);
    fprintf('B = (B/J)*J = %.6g\n', B);

end

%% ---- Local function ----
function score = peakQuality(peakValues)

    if numel(peakValues) < 3
        score = -Inf;
        return;
    end

    peakValues = peakValues(peakValues > 0);

    if numel(peakValues) < 3
        score = -Inf;
        return;
    end

    % A good extrema set has a relatively consistent amplitude ratio.
    amplitudeVariation = std(peakValues) / mean(peakValues);

    % Prefer more points, but strongly penalize inconsistent amplitudes.
    score = numel(peakValues) / (1 + amplitudeVariation);

end