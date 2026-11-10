function metrics = computeRampMetrics(t, meas, ref, tRampStart, varargin)
%COMPUTERAMPMETRICS Compute standard ramp/step response performance
%metrics for a measured (possibly noisy/oscillating) speed signal.
%
%   METRICS = COMPUTERAMPMETRICS(T, MEAS, REF, TRAMPSTART) computes, for
%   the measured signal MEAS and reference signal REF sampled at times T:
%
%       riseTime               - t_r [s], time from 10% to 90% of the
%                                 total commanded change
%       settlingTime            - t_s [s], time after t_d until the
%                                 signal enters and stays within the
%                                 settling band
%       overshootPct            - M_p [%], relative speed overshoot
%       avgErrorDuringRise       - mean(ref - meas) over the rise-time
%                                 interval [t10, t90] [rad/s], signed
%       avgAbsErrorDuringRise    - mean(|ref - meas|) over the same
%                                 interval [rad/s]
%       avgAbsErrorDuringRisePct - avgAbsErrorDuringRise as a percentage
%                                 of the total commanded change |deltaOmega|
%
%   Because real measurements oscillate/carry noise, all metrics are
%   evaluated on a lightly low-pass filtered copy of MEAS (a centered
%   moving average). This suppresses spurious single-sample spikes/dips
%   while still tracking genuine ripple whose timescale is longer than
%   the smoothing window.
%
%   Optional name-value pairs:
%     'EndTime'       - end of the analysis window t_end (default: t(end))
%     'PreWindow'     - duration [s] before TRAMPSTART used to average
%                        the pre-ramp baseline (default 0.02)
%     'PreGap'        - gap [s] before TRAMPSTART excluded from the
%                        pre-ramp average, to avoid edge transients
%                        (default 0.005)
%     'PostWindow'    - duration [s] at the end of the analysis window
%                        used to average the settled/final value
%                        (default 0.05)
%     'SettleTol'     - settling-band tolerance as a fraction of the
%                        total commanded change (default 0.02 = 2%)
%     'SmoothWindow'  - duration [s] of the moving-average filter applied
%                        before evaluating all metrics. Set to 0 to
%                        disable smoothing (default 0.005 = 5 ms)
%     'SettleDwell'   - minimum duration [s] the (smoothed) signal must
%                        remain continuously inside the settling band,
%                        counted backward from t_end, for that instant
%                        to count as "settled" (default 0.03 = 30 ms)
%
%   METRICS is a struct with the metrics above plus the supporting
%   values omegaPre, omegaFinal, deltaOmega, peakValue, tRampStart,
%   tEnd, t10, t90, measSmooth (the filtered signal used for the
%   calculations).

    p = inputParser;
    addParameter(p, 'EndTime',      t(end), @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'PreWindow',    0.02,   @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'PreGap',       0.005,  @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'PostWindow',   0.05,   @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'SettleTol',    0.02,   @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'SmoothWindow', 0.005,  @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'SettleDwell',  0.03,   @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, varargin{:});
    opt = p.Results;

    t    = t(:);
    meas = meas(:);
    ref  = ref(:);
    tEnd = opt.EndTime;
    dt   = median(diff(t));

    %% Smooth the measured signal to suppress measurement noise
    if opt.SmoothWindow > 0
        smoothWin = max(1, round(opt.SmoothWindow / dt));
        measSmooth = movmean(meas, smoothWin);
    else
        measSmooth = meas;
    end

    %% Pre-ramp baseline (on the smoothed signal)
    preMask = t >= (tRampStart - opt.PreWindow - opt.PreGap) & ...
              t <= (tRampStart - opt.PreGap);
    if ~any(preMask)
        error('computeRampMetrics:noPreData', ...
            'No samples found in the pre-ramp averaging window.');
    end
    omegaPre = mean(measSmooth(preMask));

    %% Settled final value (on the smoothed signal)
    postMask = t >= (tEnd - opt.PostWindow) & t <= tEnd;
    if ~any(postMask)
        error('computeRampMetrics:noPostData', ...
            'No samples found in the post-ramp averaging window.');
    end
    omegaFinal = mean(measSmooth(postMask));

    deltaOmega = omegaFinal - omegaPre;
    if abs(deltaOmega) < eps
        error('computeRampMetrics:noChange', ...
            'Pre-ramp and final values are identical; cannot normalize.');
    end

    %% Analysis window [t_d, t_end]
    winMask = t >= tRampStart & t <= tEnd;
    tW = t(winMask);
    mW = measSmooth(winMask);
    rW = ref(winMask);

    %% Rise time (10% - 90% of total change, on the smoothed signal)
    thresh10 = omegaPre + 0.10 * deltaOmega;
    thresh90 = omegaPre + 0.90 * deltaOmega;
    if deltaOmega >= 0
        t10 = interpCrossing(tW, mW, thresh10, 'rising');
        t90 = interpCrossing(tW, mW, thresh90, 'rising');
    else
        t10 = interpCrossing(tW, mW, thresh10, 'falling');
        t90 = interpCrossing(tW, mW, thresh90, 'falling');
    end
    riseTime = t90 - t10;

    %% Average tracking error during the rise-time interval [t10, t90]
    if isnan(t10) || isnan(t90)
        avgErrorDuringRise       = NaN;
        avgAbsErrorDuringRise    = NaN;
        avgAbsErrorDuringRisePct = NaN;
        warning('computeRampMetrics:noRiseWindow', ...
            'Rise-time crossings not found; cannot compute rise-window error.');
    else
        riseMask = tW >= t10 & tW <= t90;
        if ~any(riseMask)
            avgErrorDuringRise       = NaN;
            avgAbsErrorDuringRise    = NaN;
            avgAbsErrorDuringRisePct = NaN;
        else
            errRise = rW(riseMask) - mW(riseMask);
            avgErrorDuringRise       = mean(errRise);
            avgAbsErrorDuringRise    = mean(abs(errRise));
            avgAbsErrorDuringRisePct = avgAbsErrorDuringRise / abs(deltaOmega) * 100;
        end
    end

    %% Overshoot (peak of the smoothed signal)
    if deltaOmega >= 0
        peakValue = max(mW);
    else
        peakValue = min(mW);
    end
    overshootPct = max(0, sign(deltaOmega) * (peakValue - omegaFinal)) / ...
        abs(deltaOmega) * 100;

    %% Settling time - robust to isolated noise excursions
    band = opt.SettleTol * abs(deltaOmega);
    withinBand = abs(mW - omegaFinal) <= band;

    dwellSamples = max(1, round(opt.SettleDwell / dt));
    nW = numel(tW);
    tSettleAbs = NaN;
    for i = 1:nW
        runEnd = min(nW, i + dwellSamples - 1);
        if all(withinBand(i:runEnd)) && (runEnd - i + 1) >= dwellSamples
            tSettleAbs = tW(i);
            break;
        end
    end
    if isnan(tSettleAbs)
        warning('computeRampMetrics:notSettled', ...
            ['Signal does not stay within the settling band for the ' ...
             'required %.3f s dwell time before t_end.'], opt.SettleDwell);
        settlingTime = NaN;
    else
        settlingTime = tSettleAbs - tRampStart;
    end

    %% Package results
    metrics.riseTime                = riseTime;
    metrics.settlingTime            = settlingTime;
    metrics.overshootPct            = overshootPct;
    metrics.avgErrorDuringRise      = avgErrorDuringRise;
    metrics.avgAbsErrorDuringRise   = avgAbsErrorDuringRise;
    metrics.avgAbsErrorDuringRisePct = avgAbsErrorDuringRisePct;
    metrics.omegaPre                = omegaPre;
    metrics.omegaFinal               = omegaFinal;
    metrics.deltaOmega               = deltaOmega;
    metrics.peakValue                = peakValue;
    metrics.tRampStart               = tRampStart;
    metrics.tEnd                     = tEnd;
    metrics.t10                      = t10;
    metrics.t90                      = t90;
    metrics.measSmooth                = measSmooth;
end

function tc = interpCrossing(t, y, level, direction)
%INTERPCROSSING Linearly interpolated first-crossing time of LEVEL.
    if strcmp(direction, 'rising')
        idx = find(y >= level, 1, 'first');
    else
        idx = find(y <= level, 1, 'first');
    end
    if isempty(idx)
        tc = NaN;
        warning('computeRampMetrics:noCrossing', ...
            'Signal never crosses the requested level (%.4f).', level);
        return;
    end
    if idx == 1
        tc = t(1);
        return;
    end
    t1 = t(idx-1); t2 = t(idx);
    y1 = y(idx-1); y2 = y(idx);
    if y2 == y1
        tc = t2;
    else
        tc = t1 + (level - y1) * (t2 - t1) / (y2 - y1);
    end
end