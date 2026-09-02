%% Low- or High-Speed Reference Tracking Performance Evaluation
% Calculates and compares the performance indicators of a mechanical-speed
% reference step from standstill to a single operating point (low-speed or
% high-speed), across all three control strategies:
%   1. Six-step control
%   2. Sinusoidal control
%   3. Field-oriented control (FOC)
%
% Required input:
%   out.logsout
%
% Expected signals:
%   wm*             - mechanical-speed reference (commanded), a single
%                      shared signal (NOT prefixed per control strategy)  [rad/s]
%   6SC_wm, 6SC_Te, 6SC_Pel
%   Sin_wm, Sin_Te, Sin_Pel
%   FOC_wm, FOC_Te, FOC_Pel
%
% Required functions:
%   calcMean              (assumed already available, as in your existing
%                           evaluation framework)
%   calcStdDev            (assumed already available)
%   calcSteadyStateError   (implemented locally below)
%   calcRiseTime           (implemented locally below)
%   calcSettlingTime       (implemented locally below)
%   calcOvershoot          (implemented locally below)
%   calcEfficiency         (implemented locally below)
%
% Definitions implemented (paragraph "Evaluation intervals and
% steady-state indicators" / "Reference-tracking indicators"):
%   e_omega,rel = |wm* - mean(wm_ss)| / |wm*| * 100                  (eq. CL_relative_speed_error)
%   sigma_omega,rel = normalized std-dev of wm over W_ss             (eq. relative_speed_standard_deviation)
%   P_mech(t) = Te(t) * wm(t)                                        (eq. mechanical_power)
%   eta_bar = mean(P_mech_ss) / mean(Pel_ss) * 100                   (eq. CL_mean_drive_efficiency)
%   Delta wm* = wm* - wm,0                                           (eq. CL_commanded_speed_change)
%   t_r = t_{omega,90%} - t_{omega,10%}                              (eq. CL_rise_time)
%   t_s = inf{ t-t0 | |wm(tau)-wm*| <= 0.02|Delta wm*| for all tau in [t,t_end] }  (eq. CL_settling_time)
%   M_p = max(0, (max|wm(t)-wm,0| - |Delta wm*|) / |Delta wm*|) * 100 (eq. CL_relative_overshoot)
%
% CHANGE (2026-09-02, #1): The steady-state window W_ss is no longer
% auto-determined from the mechanical period of the reference speed.
% There is no more mechanical-period computation, no clamping logic, and
% no "numPeriods" concept. Instead, each controller now has its own
% explicit ssStart / ssEnd fields (Section 3) that you set directly,
% based on your own inspection of the simulation results.
%
% CHANGE (2026-09-02, #2): calcSettlingTime now also receives ssStart.
% As soon as the signal reaches the start of the steady-state window
% (t = ssStart) while still outside the tolerance band, the settling
% time is immediately set to NaN (with a warning), instead of letting
% the search continue and potentially reporting a "settled" instant that
% contradicts the fact that the response is not actually settled at the
% boundary of the window you declared as steady state.
%% 1. General Configuration
cfg.logs                    = out.logsout;
cfg.enablePlots             = true;
% Percentage values smaller than this threshold are displayed as zero.
cfg.percentageZeroThreshold = 0.001;
% Name of the reference-speed signal. This signal is shared across all
% control strategies (i.e., it is NOT prefixed), since it represents the
% commanded speed profile applied identically to every controller.
cfg.referenceSpeedSignal    = "wm*";
% Settling-time tolerance, as a fraction of the commanded speed change
% |Delta wm*| (per eq. CL_settling_time).
cfg.settlingTolerance       = 0.02;
% Rise-time thresholds, as fractions of the commanded speed change.
cfg.riseTimeLowThreshold    = 0.10;
cfg.riseTimeHighThreshold   = 0.90;
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
% "stepTime"  : time t0 at which the reference step from standstill occurs.
% "windowEnd" : end t_end of the considered simulation interval, used for
%               the reference-tracking indicators (rise time, settling
%               time, overshoot), evaluated over [t0, windowEnd].
% "ssStart"   : start of the closed-loop steady-state evaluation window
%               W_ss = [ssStart, ssEnd]. Set this yourself by inspecting
%               the simulation (e.g. where the speed/torque ripple has
%               visibly settled into its repetitive pattern). Also used
%               as the checkpoint for the settling-time NaN rule: if the
%               response is not within the tolerance band by ssStart, the
%               settling time is reported as NaN.
% "ssEnd"     : end of the closed-loop steady-state evaluation window
%               W_ss. Typically equal to windowEnd, but kept as a
%               separate field in case you want the steady-state window
%               to end before the simulation stop time.
%
% NOTE: Placeholder numeric values below must be updated to match your
% simulation setup and your own visual/analytical determination of where
% steady state begins for each controller.
controller(1).stepTime  = 0.1;
controller(1).windowEnd = 0.5;
controller(1).ssStart   = 0.3;
controller(1).ssEnd     = 0.5;
controller(2).stepTime  = 0.1;
controller(2).windowEnd = 0.5;
controller(2).ssStart   = 0.3;
controller(2).ssEnd     = 0.5;
controller(3).stepTime  = 0.1;
controller(3).windowEnd = 0.5;
controller(3).ssStart   = 0.3;
controller(3).ssEnd     = 0.5;
%% 4. Initialize Output Structures
results = struct();
details = struct();
%% 5. Calculate Performance Indicators
for k = 1:numel(controller)
    caseName  = char(controller(k).name);
    fieldName = char(controller(k).fieldName);
    prefix    = char(controller(k).signalPrefix);
    fprintf('\nCalculating indicators for %s control...\n', caseName);
    % Construct signal names
    sig.rotorSpeed       = [prefix, '_wm'];
    sig.referenceSpeed   = char(cfg.referenceSpeedSignal);
    sig.electromagTorque = [prefix, '_Te'];
    sig.electricalPower  = [prefix, '_Pel'];
    t0   = controller(k).stepTime;
    tEnd = controller(k).windowEnd;
    ssStart = controller(k).ssStart;
    ssEnd   = controller(k).ssEnd;
    if ssStart < t0
        error('EvaluationIntervals:ssStartBeforeStep', ...
            '[%s] ssStart (%.6f s) must not be before stepTime t0 (%.6f s).', ...
            caseName, ssStart, t0);
    end
    if ssEnd <= ssStart
        error('EvaluationIntervals:invalidSSWindow', ...
            '[%s] ssEnd (%.6f s) must be greater than ssStart (%.6f s).', ...
            caseName, ssEnd, ssStart);
    end
    if ssEnd > tEnd
        error('EvaluationIntervals:ssEndAfterWindowEnd', ...
            '[%s] ssEnd (%.6f s) must not exceed windowEnd (%.6f s).', ...
            caseName, ssEnd, tEnd);
    end
    %% 5.1 Reference and Pre-Step Speed (omega_m^*, omega_m,0)
    % omega_m^* is taken as the mean of the (shared, unprefixed) reference
    % signal over the user-specified W_ss, since the reference is
    % constant there for a settled step response. omega_m,0 is the last
    % sample of the measured speed strictly before the step at t0
    % (standstill in these test cases).
    wmStar = calcMean( ...
        cfg.logs, sig.referenceSpeed, ssStart, ssEnd, 'Plot', false);
    wm0 = calcPreStepValue(cfg.logs, sig.rotorSpeed, t0);
    deltaOmegaStar = wmStar - wm0;
    %% 5.2 Relative Steady-State Speed Error
    results.(fieldName).speedError_pct = calcSteadyStateError( ...
        cfg.logs, ...
        sig.rotorSpeed, ...
        wmStar, ...
        ssStart, ssEnd, ...
        'Plot', cfg.enablePlots);
    %% 5.3 Relative Mechanical-Speed Standard Deviation
    results.(fieldName).speedStdDev_pct = calcStdDev( ...
        cfg.logs, ...
        sig.rotorSpeed, ...
        ssStart, ssEnd, ...
        'Normalized', true, ...
        'Plot', cfg.enablePlots);
    %% 5.4 Rise Time
    [results.(fieldName).riseTime_s, details.(fieldName).riseTime] = ...
        calcRiseTime( ...
            cfg.logs, ...
            sig.rotorSpeed, ...
            t0, tEnd, ...
            wm0, deltaOmegaStar, ...
            'LowThreshold', cfg.riseTimeLowThreshold, ...
            'HighThreshold', cfg.riseTimeHighThreshold, ...
            'Plot', cfg.enablePlots);
    %% 5.5 Settling Time
    [results.(fieldName).settlingTime_s, details.(fieldName).settlingTime] = ...
        calcSettlingTime( ...
            cfg.logs, ...
            sig.rotorSpeed, ...
            t0, tEnd, ...
            wmStar, deltaOmegaStar, ...
            ssStart, ...
            'Tolerance', cfg.settlingTolerance, ...
            'Plot', cfg.enablePlots);
    %% 5.6 Relative Speed Overshoot
    [results.(fieldName).overshoot_pct, details.(fieldName).overshoot] = ...
        calcOvershoot( ...
            cfg.logs, ...
            sig.rotorSpeed, ...
            t0, tEnd, ...
            wm0, deltaOmegaStar, ...
            'Plot', cfg.enablePlots);
    %% 5.7 Mean Steady-State Electrical Input Power
    results.(fieldName).meanElectricalPower_W = calcMean( ...
        cfg.logs, ...
        sig.electricalPower, ...
        ssStart, ssEnd, ...
        'Plot', cfg.enablePlots);
    %% 5.8 Mean Steady-State Drive Efficiency
    [results.(fieldName).meanEfficiency_pct, details.(fieldName).efficiency] = ...
        calcEfficiency( ...
            cfg.logs, ...
            sig.electromagTorque, ...
            sig.rotorSpeed, ...
            sig.electricalPower, ...
            ssStart, ssEnd, ...
            'Plot', cfg.enablePlots);
    % Store the resolved evaluation quantities for traceability
    details.(fieldName).evaluation = struct( ...
        'stepTime_s', t0, ...
        'windowEnd_s', tEnd, ...
        'ssStart_s', ssStart, ...
        'ssEnd_s', ssEnd, ...
        'referenceSpeed_radps', wmStar, ...
        'preStepSpeed_radps', wm0, ...
        'commandedSpeedChange_radps', deltaOmegaStar);
end
%% 6. Define Performance Indicators and Units
performanceIndicator = [
    "Relative steady-state speed error"
    "Relative speed standard deviation"
    "Rise time"
    "Settling time"
    "Relative speed overshoot"
    "Mean steady-state electrical input power"
    "Mean steady-state drive efficiency"
];
unit = [
    "%"
    "%"
    "s"
    "s"
    "%"
    "W"
    "%"
];
%% 7. Create Results Vectors
SixStep = [
    results.SixStep.speedError_pct
    results.SixStep.speedStdDev_pct
    results.SixStep.riseTime_s
    results.SixStep.settlingTime_s
    results.SixStep.overshoot_pct
    results.SixStep.meanElectricalPower_W
    results.SixStep.meanEfficiency_pct
];
Sinusoidal = [
    results.Sin.speedError_pct
    results.Sin.speedStdDev_pct
    results.Sin.riseTime_s
    results.Sin.settlingTime_s
    results.Sin.overshoot_pct
    results.Sin.meanElectricalPower_W
    results.Sin.meanEfficiency_pct
];
FOC = [
    results.FOC.speedError_pct
    results.FOC.speedStdDev_pct
    results.FOC.riseTime_s
    results.FOC.settlingTime_s
    results.FOC.overshoot_pct
    results.FOC.meanElectricalPower_W
    results.FOC.meanEfficiency_pct
];
%% 8. Set Very Small Percentage Values to Zero
% Percentage-valued rows:
%   1. Relative steady-state speed error
%   2. Relative speed standard deviation
%   5. Relative speed overshoot
percentageRows = [1, 2, 5];
SixStep(percentageRows) = setSmallPercentagesToZero( ...
    SixStep(percentageRows), cfg.percentageZeroThreshold);
Sinusoidal(percentageRows) = setSmallPercentagesToZero( ...
    Sinusoidal(percentageRows), cfg.percentageZeroThreshold);
FOC(percentageRows) = setSmallPercentagesToZero( ...
    FOC(percentageRows), cfg.percentageZeroThreshold);
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
fprintf('\nSpeed-tracking performance indicators\n');
fprintf('======================================\n\n');
disp(resultsTable);
%% 10. Display Evaluation Intervals
fprintf('\nEvaluation intervals\n');
fprintf('====================\n');
for k = 1:numel(controller)
    name = char(controller(k).name);
    ev   = details.(char(controller(k).fieldName)).evaluation;
    fprintf('\n%s control:\n', name);
    fprintf('  Step time t0:                    %.4f s\n', ev.stepTime_s);
    fprintf('  Simulation interval end t_end:    %.4f s\n', ev.windowEnd_s);
    fprintf('  Steady-state window W_ss:         %.4f s to %.4f s\n', ...
        ev.ssStart_s, ev.ssEnd_s);
    fprintf('  Reference speed omega_m*:         %.4f rad/s\n', ...
        ev.referenceSpeed_radps);
    fprintf('  Pre-step speed omega_m,0:         %.4f rad/s\n', ...
        ev.preStepSpeed_radps);
    fprintf('  Commanded speed change Delta*:    %.4f rad/s\n', ...
        ev.commandedSpeedChange_radps);
end
fprintf('\n');
%% 11. Optional Detailed Outputs
% disp(results.SixStep);
% disp(results.Sin);
% disp(results.FOC);
% disp(details.SixStep.riseTime);
% disp(details.Sin.riseTime);
% disp(details.FOC.riseTime);
% disp(details.SixStep.settlingTime);
% disp(details.Sin.settlingTime);
% disp(details.FOC.settlingTime);
% disp(details.SixStep.overshoot);
% disp(details.Sin.overshoot);
% disp(details.FOC.overshoot);
% disp(details.SixStep.efficiency);
% disp(details.Sin.efficiency);
% disp(details.FOC.efficiency);
% disp(details.SixStep.evaluation);
% disp(details.Sin.evaluation);
% disp(details.FOC.evaluation);
%% ==================== Local Functions ====================
function values = setSmallPercentagesToZero(values, threshold)
%SETSMALLPERCENTAGESTOZERO Replaces very small percentage values with zero.
    values(abs(values) < threshold) = 0;
end
function [t, y] = getSignalData(logs, signalName, tStart, tEnd)
%GETSIGNALDATA Extracts a [tStart, tEnd] excerpt of a logged signal.
    element = logs.getElement(signalName);
    ts      = element.Values;
    t       = ts.Time;
    y       = ts.Data;
    mask    = (t >= tStart) & (t <= tEnd);
    t       = t(mask);
    y       = y(mask);
    if isempty(t)
        error('getSignalData:emptyWindow', ...
            'No samples of "%s" found in [%.6f, %.6f] s.', ...
            signalName, tStart, tEnd);
    end
end
function wm0 = calcPreStepValue(logs, signalName, t0)
%CALCPRESTEPVALUE Returns the last sampled value of a signal strictly
% before the step time t0 (i.e., omega_m,0).
    element = logs.getElement(signalName);
    ts      = element.Values;
    t       = ts.Time;
    y       = ts.Data;
    idx     = find(t < t0, 1, 'last');
    if isempty(idx)
        warning('calcPreStepValue:noSamplesBeforeStep', ...
            'No samples of "%s" found before t0 = %.6f s; using first sample.', ...
            signalName, t0);
        idx = 1;
    end
    wm0 = y(idx);
end
function errPct = calcSteadyStateError(logs, signalName, wmStar, ...
    ssStart, ssEnd, varargin)
%CALCSTEADYSTATEERROR Relative steady-state speed error (eq. CL_relative_speed_error):
%   e_omega,rel = |wmStar - mean(wm_ss)| / |wmStar| * 100
    p = inputParser;
    addParameter(p, 'Plot', false);
    parse(p, varargin{:});
    [t, y] = getSignalData(logs, signalName, ssStart, ssEnd);
    wmMean = mean(y);
    errPct = abs(wmStar - wmMean) / abs(wmStar) * 100;
    if p.Results.Plot
        figure('Name', ['Steady-state error - ', signalName]);
        plot(t, y, 'b'); hold on;
        yline(wmStar, 'r--', 'Reference \omega_m^*');
        yline(wmMean, 'g--', 'Steady-state mean');
        xlabel('Time (s)'); ylabel(signalName);
        title(sprintf('Steady-state error = %.3f %%', errPct));
        grid on;
    end
end
function [tr, info] = calcRiseTime(logs, signalName, t0, tEnd, ...
    wm0, deltaOmegaStar, varargin)
%CALCRISETIME Rise time per eq. CL_rise_time:
%   t_r = t_{omega,90%} - t_{omega,10%}
% where t_{omega,x%} is the first instant the response reaches x% of the
% commanded speed change Delta wm* = wm* - wm,0 (signed, direction-aware).
    p = inputParser;
    addParameter(p, 'LowThreshold', 0.10);
    addParameter(p, 'HighThreshold', 0.90);
    addParameter(p, 'Plot', false);
    parse(p, varargin{:});
    [t, y] = getSignalData(logs, signalName, t0, tEnd);
    lowVal  = wm0 + p.Results.LowThreshold  * deltaOmegaStar;
    highVal = wm0 + p.Results.HighThreshold * deltaOmegaStar;
    if deltaOmegaStar >= 0
        idxLow  = find(y >= lowVal, 1, 'first');
        idxHigh = find(y >= highVal, 1, 'first');
    else
        idxLow  = find(y <= lowVal, 1, 'first');
        idxHigh = find(y <= highVal, 1, 'first');
    end
    if isempty(idxLow) || isempty(idxHigh)
        warning('calcRiseTime:thresholdNotReached', ...
            'Signal "%s" did not reach the rise-time thresholds.', ...
            signalName);
        tr = NaN;
        info = struct('tLow', NaN, 'tHigh', NaN, ...
            'lowValue', lowVal, 'highValue', highVal);
        return;
    end
    tLow  = t(idxLow);
    tHigh = t(idxHigh);
    tr    = tHigh - tLow;
    info  = struct('tLow', tLow, 'tHigh', tHigh, ...
        'lowValue', lowVal, 'highValue', highVal);
    if p.Results.Plot
        figure('Name', ['Rise time - ', signalName]);
        plot(t, y, 'b'); hold on;
        yline(lowVal, 'k--'); yline(highVal, 'k--');
        xline(tLow, 'g--'); xline(tHigh, 'g--');
        xlabel('Time (s)'); ylabel(signalName);
        title(sprintf('Rise time = %.4f s', tr));
        grid on;
    end
end
function [ts_, info] = calcSettlingTime(logs, signalName, t0, tEnd, ...
    wmStar, deltaOmegaStar, ssStart, varargin)
%CALCSETTLINGTIME Settling time per eq. CL_settling_time:
%   t_s = inf{ t-t0 | |wm(tau)-wm*| <= tolerance*|Delta wm*|, for all tau in [t,t_end] }
%
% Additional rule: ssStart marks the start of the declared closed-loop
% steady-state window W_ss. If the response has NOT entered the
% tolerance band by t = ssStart, the settling time is immediately set to
% NaN (with a warning) instead of continuing to search for a later
% settling instant. This flags cases where the steady-state window would
% otherwise start on data that is not actually settled.
    p = inputParser;
    addParameter(p, 'Tolerance', 0.02);
    addParameter(p, 'Plot', false);
    parse(p, varargin{:});
    [t, y] = getSignalData(logs, signalName, t0, tEnd);
    band   = p.Results.Tolerance * abs(deltaOmegaStar);
    withinBand = abs(y - wmStar) <= band;
    idxSS = find(t >= ssStart, 1, 'first');
    if isempty(idxSS) || ~withinBand(idxSS)
        warning('calcSettlingTime:notSettledAtWindowStart', ...
            ['Signal "%s" is not within the tolerance band at the ', ...
             'start of the steady-state window (ssStart = %.6f s); ', ...
             'settling time set to NaN.'], signalName, ssStart);
        ts_ = NaN;
        info = struct('tSettle', NaN, 'band', band, ...
            'ssStart', ssStart, 'withinBandAtSSStart', false);
        return;
    end
    idxSettle = [];
    n = numel(withinBand);
    for i = 1:n
        if all(withinBand(i:end))
            idxSettle = i;
            break;
        end
    end
    if isempty(idxSettle)
        warning('calcSettlingTime:neverSettles', ...
            'Signal "%s" never settles within the tolerance band.', ...
            signalName);
        ts_ = NaN;
        info = struct('tSettle', NaN, 'band', band, ...
            'ssStart', ssStart, 'withinBandAtSSStart', true);
        return;
    end
    tSettle = t(idxSettle);
    ts_     = tSettle - t0;
    info    = struct('tSettle', tSettle, 'band', band, ...
        'ssStart', ssStart, 'withinBandAtSSStart', true);
    if p.Results.Plot
        figure('Name', ['Settling time - ', signalName]);
        plot(t, y, 'b'); hold on;
        yline(wmStar + band, 'k--');
        yline(wmStar - band, 'k--');
        xline(tSettle, 'g--');
        xline(ssStart, 'm:', 'W_{ss} start');
        xlabel('Time (s)'); ylabel(signalName);
        title(sprintf('Settling time = %.4f s', ts_));
        grid on;
    end
end
function [Mp, info] = calcOvershoot(logs, signalName, t0, tEnd, ...
    wm0, deltaOmegaStar, varargin)
%CALCOVERSHOOT Relative overshoot per eq. CL_relative_overshoot:
%   Mp = max(0, (max|wm(t)-wm0| - |Delta wm*|) / |Delta wm*|) * 100
    p = inputParser;
    addParameter(p, 'Plot', false);
    parse(p, varargin{:});
    [t, y] = getSignalData(logs, signalName, t0, tEnd);
    absDeviation = abs(y - wm0);
    [peakDeviation, idxPeak] = max(absDeviation);
    Mp   = max(0, (peakDeviation - abs(deltaOmegaStar)) / abs(deltaOmegaStar)) * 100;
    info = struct('tPeak', t(idxPeak), 'peakValue', y(idxPeak), ...
        'peakDeviation', peakDeviation);
    if p.Results.Plot
        figure('Name', ['Overshoot - ', signalName]);
        plot(t, y, 'b'); hold on;
        yline(wm0 + deltaOmegaStar, 'r--', 'Reference \omega_m^*');
        plot(t(idxPeak), y(idxPeak), 'go', 'MarkerFaceColor', 'g');
        xlabel('Time (s)'); ylabel(signalName);
        title(sprintf('Overshoot = %.3f %%', Mp));
        grid on;
    end
end
function [etaPct, info] = calcEfficiency(logs, torqueSignal, ...
    speedSignal, powerSignal, ssStart, ssEnd, varargin)
%CALCEFFICIENCY Mean steady-state drive efficiency per
% eq. mechanical_power and eq. CL_mean_drive_efficiency:
%   P_mech(t) = Te(t) * wm(t)
%   eta_bar   = mean(P_mech_ss) / mean(Pel_ss) * 100
% Valid for motoring operation, where mean(Pel_ss) > 0.
    p = inputParser;
    addParameter(p, 'Plot', false);
    parse(p, varargin{:});
    [tTe, Te] = getSignalData(logs, torqueSignal, ssStart, ssEnd);
    [~, wm]   = getSignalData(logs, speedSignal, ssStart, ssEnd);
    [~, Pel]  = getSignalData(logs, powerSignal, ssStart, ssEnd);
    n = min([numel(Te), numel(wm), numel(Pel)]);
    Pmech = Te(1:n) .* wm(1:n);
    PelSS = Pel(1:n);
    meanPmech = mean(Pmech);
    meanPel   = mean(PelSS);
    if meanPel <= 0
        warning('calcEfficiency:notMotoring', ...
            ['Mean electrical input power is not positive (%.4f W); ', ...
             'the efficiency definition assumes motoring operation.'], meanPel);
    end
    etaPct = (meanPmech / meanPel) * 100;
    info = struct('meanMechPower_W', meanPmech, ...
        'meanElectricalPower_W', meanPel);
    if p.Results.Plot
        figure('Name', 'Steady-state efficiency');
        plot(tTe(1:n), Pmech, 'b', tTe(1:n), PelSS, 'r'); hold on;
        legend('Mechanical power P_{mech}', 'Electrical power P_{el}');
        xlabel('Time (s)'); ylabel('Power (W)');
        title(sprintf('Efficiency = %.3f %%', etaPct));
        grid on;
    end
end
