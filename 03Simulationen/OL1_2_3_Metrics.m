%% Motor Control Performance Evaluation
% Calculates and compares the performance indicators of:
%   1. Six-step control
%   2. Sinusoidal control
%   3. Field-oriented control
%
% Required input:
%   out.logsout
%
% Expected signals:
%   6SC_ia, 6SC_Te, 6SC_wm, 6SC_Pel, 6SC_iq, 6SC_imag
%   Sin_ia, Sin_Te, Sin_wm, Sin_Pel, Sin_iq, Sin_imag
%   FOC_ia, FOC_Te, FOC_wm, FOC_Pel, FOC_iq, FOC_imag
%
% Required functions:
%   calcTHD
%   calcMean
%   calcRipple
%   calcStdDev
%   calcRatioOfMeans

%% 1. General Configuration

cfg.logs         = out.logsout;
cfg.Fs           = 1e6;
cfg.numHarmonics = 20;
cfg.enablePlots  = true;

% Percentage values smaller than this threshold are displayed as zero.
cfg.percentageZeroThreshold = 0.001;


%% 2. Controller Configuration

% Controller order:
%   1. Six-step
%   2. Sinusoidal
%   3. FOC

controller(1).name         = "Six-step";
controller(1).fieldName    = "SixStep";
controller(1).signalPrefix = "6SC";

controller(2).name         = "Sinusoidal";
controller(2).fieldName    = "Sin";
controller(2).signalPrefix = "Sin";

controller(3).name         = "FOC";
controller(3).fieldName    = "FOC";
controller(3).signalPrefix = "FOC";


%% 3. Evaluation Intervals

% Six-step control
controller(1).time.thd             = [1.44, 1.45];
controller(1).time.torque          = [1.44, 1.45];
controller(1).time.speed           = [1.44, 1.45];
controller(1).time.power           = [1.44, 1.45];
controller(1).time.currentRatio    = [1.44, 1.45];
controller(1).time.torquePerAmpere = [1.44, 1.45];

% Sinusoidal control
controller(2).time.thd             = [1.49, 1.5000];
controller(2).time.torque          = [1.490, 1.5000];
controller(2).time.speed           = [1.490, 1.5000];
controller(2).time.power           = [1.490, 1.5000];
controller(2).time.currentRatio    = [1.490, 1.5000];
controller(2).time.torquePerAmpere = [1.490, 1.5000];

% FOC
controller(3).time.thd             = [1.4900, 1.5000];
controller(3).time.torque          = [1.4900, 1.5000];
controller(3).time.speed           = [1.4900, 1.5000];
controller(3).time.power           = [1.4900, 1.5000];
controller(3).time.currentRatio    = [1.4900, 1.5000];
controller(3).time.torquePerAmpere = [1.4900, 1.5000];


%% 4. Initialize Output Structures

results = struct();
details = struct();


%% 5. Calculate Performance Indicators

for k = 1:numel(controller)

    controllerName = char(controller(k).name);
    fieldName      = char(controller(k).fieldName);
    prefix         = char(controller(k).signalPrefix);

    fprintf('\nCalculating indicators for %s control...\n', ...
        controllerName);

    % Construct signal names
    sig.phaseCurrent     = [prefix, '_ia'];
    sig.electromagTorque = [prefix, '_Te'];
    sig.rotorSpeed       = [prefix, '_wm'];
    sig.electricalPower  = [prefix, '_Pel'];
    sig.qAxisCurrent     = [prefix, '_iq'];
    sig.currentMagnitude = [prefix, '_imag'];

    time = controller(k).time;

    %% 5.1 q-Axis Current Utilization

    [qAxisRatio, details.(fieldName).qAxisCurrentRatio] = ...
        calcRatioOfMeans( ...
            cfg.logs, ...
            sig.qAxisCurrent, ...
            sig.currentMagnitude, ...
            time.currentRatio(1), ...
            time.currentRatio(2), ...
            'AlignOn', 'Numerator', ...
            'Plot', cfg.enablePlots);

    results.(fieldName).qAxisCurrentUtilization_pct = ...
        100 * qAxisRatio;


    %% 5.2 Phase-Current THD

    [results.(fieldName).currentTHD_pct, ...
     details.(fieldName).harmonics] = calcTHD( ...
        cfg.logs, ...
        sig.phaseCurrent, ...
        time.thd(1), ...
        time.thd(2), ...
        'Fs', cfg.Fs, ...
        'NumHarmonics', cfg.numHarmonics, ...
        'Plot', cfg.enablePlots);


    %% 5.3 Mean Electromagnetic Torque

    results.(fieldName).meanTorque_Nm = calcMean( ...
        cfg.logs, ...
        sig.electromagTorque, ...
        time.torque(1), ...
        time.torque(2), ...
        'Plot', cfg.enablePlots);


    %% 5.4 Electromagnetic Torque Ripple

    results.(fieldName).torqueRipple_pct = calcRipple( ...
        cfg.logs, ...
        sig.electromagTorque, ...
        time.torque(1), ...
        time.torque(2), ...
        'Plot', cfg.enablePlots);


    %% 5.5 Torque per Ampere

    [results.(fieldName).torquePerAmpere_NmPerA, ...
     details.(fieldName).torquePerAmpere] = calcRatioOfMeans( ...
        cfg.logs, ...
        sig.electromagTorque, ...
        sig.currentMagnitude, ...
        time.torquePerAmpere(1), ...
        time.torquePerAmpere(2), ...
        'AlignOn', 'Numerator', ...
        'Plot', cfg.enablePlots);


    %% 5.6 Mean Rotor Speed

    results.(fieldName).meanSpeed_radps = calcMean( ...
        cfg.logs, ...
        sig.rotorSpeed, ...
        time.speed(1), ...
        time.speed(2), ...
        'Plot', cfg.enablePlots);


    %% 5.7 Normalized Rotor-Speed Standard Deviation

    results.(fieldName).speedStdDev_pct = calcStdDev( ...
        cfg.logs, ...
        sig.rotorSpeed, ...
        time.speed(1), ...
        time.speed(2), ...
        'Normalized', true, ...
        'Plot', cfg.enablePlots);


    %% 5.8 Mean Electrical Input Power

    results.(fieldName).meanElectricalPower_W = calcMean( ...
        cfg.logs, ...
        sig.electricalPower, ...
        time.power(1), ...
        time.power(2), ...
        'Plot', cfg.enablePlots);

end


%% 6. Define Performance Indicators and Units

% The order matches the corresponding LaTeX results table:
%   1. Current excitation and quality
%   2. Torque generation
%   3. Mechanical response
%   4. Electrical input power

performanceIndicator = [
    "Mean current-vector utilization"
    "Current total harmonic distortion"
    "Mean torque"
    "Torque ripple"
    "Mean torque per ampere"
    "Mean mechanical speed"
    "Speed standard deviation"
    "Mean electrical input power"
];

unit = [
    "%"
    "%"
    "N m"
    "%"
    "N m/A"
    "rad/s"
    "%"
    "W"
];


%% 7. Create Results Vectors

SixStep = [
    results.SixStep.qAxisCurrentUtilization_pct
    results.SixStep.currentTHD_pct
    results.SixStep.meanTorque_Nm
    results.SixStep.torqueRipple_pct
    results.SixStep.torquePerAmpere_NmPerA
    results.SixStep.meanSpeed_radps
    results.SixStep.speedStdDev_pct
    results.SixStep.meanElectricalPower_W
];

Sinusoidal = [
    results.Sin.qAxisCurrentUtilization_pct
    results.Sin.currentTHD_pct
    results.Sin.meanTorque_Nm
    results.Sin.torqueRipple_pct
    results.Sin.torquePerAmpere_NmPerA
    results.Sin.meanSpeed_radps
    results.Sin.speedStdDev_pct
    results.Sin.meanElectricalPower_W
];

FOC = [
    results.FOC.qAxisCurrentUtilization_pct
    results.FOC.currentTHD_pct
    results.FOC.meanTorque_Nm
    results.FOC.torqueRipple_pct
    results.FOC.torquePerAmpere_NmPerA
    results.FOC.meanSpeed_radps
    results.FOC.speedStdDev_pct
    results.FOC.meanElectricalPower_W
];


%% 8. Set Very Small Percentage Values to Zero

% Percentage-valued rows:
%   1. Mean current-vector utilization
%   2. Current total harmonic distortion
%   4. Torque ripple
%   7. Speed standard deviation

percentageRows = [1, 2, 4, 7];

SixStep(percentageRows) = setSmallPercentagesToZero( ...
    SixStep(percentageRows), ...
    cfg.percentageZeroThreshold);

Sinusoidal(percentageRows) = setSmallPercentagesToZero( ...
    Sinusoidal(percentageRows), ...
    cfg.percentageZeroThreshold);

FOC(percentageRows) = setSmallPercentagesToZero( ...
    FOC(percentageRows), ...
    cfg.percentageZeroThreshold);


%% 9. Create and Display Comparison Table

resultsTable = table( ...
    performanceIndicator, ...
    SixStep, ...
    Sinusoidal, ...
    FOC, ...
    unit, ...
    'VariableNames', { ...
        'PerformanceIndicator', ...
        'SixStep', ...
        'Sinusoidal', ...
        'FOC', ...
        'Unit'});

fprintf('\nMotor control performance indicators\n');
fprintf('====================================\n\n');

disp(resultsTable);


%% 10. Display Evaluation Intervals

fprintf('\nEvaluation intervals\n');
fprintf('====================\n');

for k = 1:numel(controller)

    name = char(controller(k).name);
    time = controller(k).time;

    fprintf('\n%s control:\n', name);

    fprintf('  Current THD:             %.4f s to %.4f s\n', ...
        time.thd(1), time.thd(2));

    fprintf('  Torque and ripple:       %.4f s to %.4f s\n', ...
        time.torque(1), time.torque(2));

    fprintf('  Mechanical speed:        %.4f s to %.4f s\n', ...
        time.speed(1), time.speed(2));

    fprintf('  Electrical input power:  %.4f s to %.4f s\n', ...
        time.power(1), time.power(2));

    fprintf('  Current utilization:     %.4f s to %.4f s\n', ...
        time.currentRatio(1), time.currentRatio(2));

    fprintf('  Torque per ampere:       %.4f s to %.4f s\n', ...
        time.torquePerAmpere(1), ...
        time.torquePerAmpere(2));

end

fprintf('\n');


%% 11. Optional Detailed Outputs

% disp(results.SixStep);
% disp(results.Sin);
% disp(results.FOC);

% disp(details.SixStep.harmonics);
% disp(details.Sin.harmonics);
% disp(details.FOC.harmonics);

% disp(details.SixStep.qAxisCurrentRatio);
% disp(details.Sin.qAxisCurrentRatio);
% disp(details.FOC.qAxisCurrentRatio);

% disp(details.SixStep.torquePerAmpere);
% disp(details.Sin.torquePerAmpere);
% disp(details.FOC.torquePerAmpere);


%% Local Functions

function values = setSmallPercentagesToZero(values, threshold)
%SETSMALLPERCENTAGESTOZERO Replaces very small percentage values with zero.
%
% Values satisfying
%
%   abs(value) < threshold
%
% are replaced with zero. The absolute value is used so that small negative
% values caused by numerical noise are also handled correctly.

    values(abs(values) < threshold) = 0;
end