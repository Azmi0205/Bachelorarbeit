clear
clc

folder = 'Measurements';
files = dir(fullfile(folder, '*.csv'));
results = struct('filename', {}, 'data', {});
for k = 1:numel(files)
    fullPath = fullfile(files(k).folder, files(k).name);
    results(k).filename = files(k).name;
    results(k).data = readUserSpeedCSV(fullPath);
end

t_settle = 0.0;

metricNames = {'filename','e_omega_rel_pct','sigma_omega_rel_pct','rho_CPU_mean'};
metricTable = table('Size',[0 4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',metricNames);

% Store per-file steady-state data for plotting later
plotData = struct('filename', {}, 'T', {}, 'ssMask', {}, ...
    'omega_star', {}, 'omega_mean', {}, ...
    'sigma_omega', {}, 'sigma_omega_rel', {});

for k = 1:numel(results)
    fname = results(k).filename;
    if ~contains(fname, 'Low', 'IgnoreCase', true) && ...
       ~contains(fname, 'High', 'IgnoreCase', true)
        continue
    end

    T = results(k).data;
    t0 = T.time(1);
    ssMask = (T.time - t0) >= t_settle;
    if ~any(ssMask)
        warning('No steady-state samples found for %s, skipping.', fname);
        continue
    end

    omega_meas_ss = T.USER_SPEED_MEAS(ssMask);   % rad/s
    omega_ref_ss  = T.USER_SPEED_REF(ssMask);    % rad/s
    cpu_ss        = T.USER_CPU_Load(ssMask);

    omega_star = mean(omega_ref_ss);
    omega_mean = mean(omega_meas_ss);

    e_omega_rel = abs(omega_star - omega_mean) / abs(omega_star) * 100;

    N = numel(omega_meas_ss);
    sigma_omega = sqrt(sum((omega_meas_ss - omega_mean).^2) / N);
    sigma_omega_rel = sigma_omega / abs(omega_mean) * 100;

    rho_CPU = mean(cpu_ss);

    metricTable = [metricTable; ...
        {string(fname), e_omega_rel, sigma_omega_rel, rho_CPU}]; %#ok<AGROW>

    idx = numel(plotData) + 1;
    plotData(idx).filename        = fname;
    plotData(idx).T               = T;
    plotData(idx).ssMask          = ssMask;
    plotData(idx).omega_star      = omega_star;
    plotData(idx).omega_mean      = omega_mean;
    plotData(idx).sigma_omega     = sigma_omega;      % absolute, rad/s (for band width)
    plotData(idx).sigma_omega_rel = sigma_omega_rel;  % relative, %
end

disp(metricTable)

%% ---------------- PLOTTING ----------------
nFiles = numel(plotData);

figure('Name','Speed Time Series','Color','w');
tiledlayout(nFiles,1,'TileSpacing','compact','Padding','compact');

for i = 1:nFiles
    T        = plotData(i).T;
    ss       = plotData(i).ssMask;
    t0       = T.time(1);
    trel     = T.time - t0;
    om_star  = plotData(i).omega_star;
    om_mean  = plotData(i).omega_mean;
    om_sigma = plotData(i).sigma_omega;
    om_sigma_rel = plotData(i).sigma_omega_rel;

    nexttile
    hold on

    % Shade steady-state region
    ssStart = trel(find(ss,1,'first'));
    ssEnd   = trel(end);
    yl = [min(T.USER_SPEED_MEAS)-0.5, max(T.USER_SPEED_MEAS)+0.5];
    patch([ssStart ssEnd ssEnd ssStart], [yl(1) yl(1) yl(2) yl(2)], ...
        [0.85 0.93 1], 'EdgeColor','none', 'FaceAlpha',0.6, ...
        'HandleVisibility','off');

    % +-1 std-dev band around the steady-state mean (width uses absolute
    % sigma; label reports the relative sigma as requested)
    patch([ssStart ssEnd ssEnd ssStart], ...
        [om_mean-om_sigma om_mean-om_sigma om_mean+om_sigma om_mean+om_sigma], ...
        [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.5, ...
        'DisplayName', sprintf('\\sigma_{\\omega,rel} = %.3f %%', om_sigma_rel));

    plot(trel, T.USER_SPEED_MEAS, 'b-', 'LineWidth', 1, ...
        'DisplayName', 'Measured speed');
    plot(trel, T.USER_SPEED_REF, 'k--', 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Reference speed (\\omega^* = %.4f rad/s)', om_star));
    yline(om_mean, 'r-', 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Mean speed (\\omega_m = %.4f rad/s)', om_mean));
    yline(om_mean+om_sigma, 'r:', 'LineWidth', 0.8, 'HandleVisibility','off');
    yline(om_mean-om_sigma, 'r:', 'LineWidth', 0.8, 'HandleVisibility','off');

    ylim(yl)
    xlabel('Time [s]')
    ylabel('\omega_m [rad/s]')
    title(strrep(plotData(i).filename, '_', '\_'), 'Interpreter', 'tex')
    legend('Location','best')
    grid on
    hold off
end