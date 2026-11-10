function fig = plotLoggedSignal1x2(logsout, signalNamesGrid, varargin)
%PLOTLOGGEDSIGNAL1X2 Plot logged signals in a 1x2 tiled layout.
%
%   FIG = PLOTLOGGEDSIGNAL1X2(LOGSOUT, SIGNALNAMESGRID) creates a
%   thesis-style figure with two side-by-side tiles.
%
%   LOGSOUT may be:
%
%       1. A single Simulink.SimulationData.Dataset used for both tiles.
%
%       2. A two-element cell array containing one dataset per tile:
%
%              {logsoutLeft, logsoutRight}
%
%   SIGNALNAMESGRID must contain exactly two cells:
%
%       {signalsLeft, signalsRight}
%
%   Each tile entry may be:
%
%       - A single character vector or string
%       - A cell array of signal names to overlay
%
%   Examples
%   --------
%
%   One dataset for both tiles:
%
%       plotLoggedSignal1x2( ...
%           out.logsout, ...
%           {'Sin_wm', 'Sin_Te'});
%
%   Different datasets for the left and right tiles:
%
%       plotLoggedSignal1x2( ...
%           {results(1).data, results(2).data}, ...
%           { ...
%               {'USER_SPEED_MEAS', 'USER_SPEED_REF'}, ...
%               {'USER_SPEED_MEAS', 'USER_SPEED_REF'} ...
%           });
%
%   Optional name-value pairs
%   -------------------------
%
%   'XLabel'
%       1x2 cell array of LaTeX x-axis labels.
%
%   'YLabel'
%       1x2 cell array of LaTeX y-axis labels.
%
%   'Title'
%       1x2 cell array of LaTeX tile titles.
%
%   'Legend'
%       1x2 cell array. Each entry contains the legend labels for the
%       corresponding tile.
%
%   'XLim'
%       Common [xmin xmax] limit applied to both tiles. If empty, the
%       common range is calculated from both datasets.
%
%   'YLim'
%       Two-element cell array:
%
%           {yLimLeft, yLimRight}
%
%       Each entry may be [ymin ymax] or [] for automatic limits.
%
%   'ShowXTickLabels'
%       Two-element logical vector controlling the numeric x-axis tick
%       labels. Default: [true true].
%
%   'ShowYTickLabels'
%       Two-element logical vector controlling the numeric y-axis tick
%       labels. Default: [true true].
%
%   'ExportName'
%       PDF export filename without the extension. If empty, no PDF is
%       exported.
%
%   Output
%   ------
%
%   FIG
%       Handle to the generated figure.

    %% Basic configuration

    nTiles = 2;

    if nargin < 2
        error( ...
            'plotLoggedSignal1x2:missingInput', ...
            ['Both logsout and signalNamesGrid must be provided.']);
    end

    %% Assign one dataset to each tile

    if iscell(logsout)
        if numel(logsout) ~= nTiles
            error( ...
                'plotLoggedSignal1x2:invalidDatasetCell', ...
                ['When logsout is a cell array, it must contain ' ...
                 'exactly %d datasets, one per tile.'], ...
                nTiles);
        end

        logsoutPerTile = reshape(logsout, 1, nTiles);
    else
        % Use the same dataset for both tiles.
        logsoutPerTile = repmat({logsout}, 1, nTiles);
    end

    %% Normalize signal definitions

    if ~iscell(signalNamesGrid) || numel(signalNamesGrid) ~= nTiles
        error( ...
            'plotLoggedSignal1x2:invalidSignalGrid', ...
            ['signalNamesGrid must be a cell array containing exactly ' ...
             '%d entries.'], ...
            nTiles);
    end

    signalNamesGrid = normalizeTileSignals(signalNamesGrid);

    %% Parse optional inputs

    p = inputParser;

    addParameter( ...
        p, ...
        'XLabel', ...
        cell(1, nTiles), ...
        @(x) iscell(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'YLabel', ...
        cell(1, nTiles), ...
        @(x) iscell(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'Title', ...
        cell(1, nTiles), ...
        @(x) iscell(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'Legend', ...
        cell(1, nTiles), ...
        @(x) iscell(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'XLim', ...
        [], ...
        @(x) isnumeric(x) && ...
             (isempty(x) || (isvector(x) && numel(x) == 2)));

    addParameter( ...
        p, ...
        'YLim', ...
        {[], []}, ...
        @(x) iscell(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'ShowXTickLabels', ...
        true(1, nTiles), ...
        @(x) islogical(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'ShowYTickLabels', ...
        true(1, nTiles), ...
        @(x) islogical(x) && numel(x) == nTiles);

    addParameter( ...
        p, ...
        'ExportName', ...
        '', ...
        @(x) ischar(x) || isstring(x));

    parse(p, varargin{:});

    %% Validate axis limits

    validateLimit(p.Results.XLim, 'XLim');

    for k = 1:nTiles
        validateLimit(p.Results.YLim{k}, sprintf('YLim{%d}', k));
    end

    %% Plot style

    style = defaultPlotStyle();

    %% Create figure and tiled layout

    fig = figure( ...
        'Color', 'w', ...
        'Units', 'centimeters', ...
        'Position', [1 -1 60 20]);

    tileLayout = tiledlayout( ...
        fig, ...
        1, ...
        2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    axesArr = gobjects(1, nTiles);

    %% Plot each tile

    for k = 1:nTiles
        ax = nexttile(tileLayout);
        axesArr(k) = ax;

        plotSignalsOnAxes( ...
            ax, ...
            logsoutPerTile{k}, ...
            signalNamesGrid{k}, ...
            style, ...
            getTileOpt(p.Results.XLabel, k), ...
            getTileOpt(p.Results.YLabel, k), ...
            getTileOpt(p.Results.Title, k), ...
            getTileOpt(p.Results.Legend, k), ...
            p.Results.XLim, ...
            p.Results.YLim{k}, ...
            p.Results.ShowXTickLabels(k), ...
            p.Results.ShowYTickLabels(k));
    end

    %% Apply one common x-axis range

    if isempty(p.Results.XLim)
        xLimits = zeros(nTiles, 2);

        for k = 1:nTiles
            xLimits(k, :) = xlim(axesArr(k));
        end

        commonXLim = [ ...
            min(xLimits(:, 1)), ...
            max(xLimits(:, 2))];

        if commonXLim(1) == commonXLim(2)
            commonXLim = expandConstantLimit(commonXLim);
        end
    else
        commonXLim = p.Results.XLim;
    end

    set(axesArr, 'XLim', commonXLim);

    %% Apply individual y-axis ranges

    for k = 1:nTiles
        if ~isempty(p.Results.YLim{k})
            ylim(axesArr(k), p.Results.YLim{k});
        end
    end

    %% Final formatting

    set( ...
        findall(fig, 'Type', 'axes'), ...
        'TickLabelInterpreter', 'latex');

    set( ...
        findall(fig, 'Type', 'axes'), ...
        'LineWidth', 2.0);

    legends = findall(fig, 'Type', 'Legend');

    if ~isempty(legends)
        set(legends, 'LineWidth', 1.5);
    end

    %% Configure PDF export

    set(fig, 'PaperUnits', 'centimeters');
    set(fig, 'PaperSize', [40 18]);
    set(fig, 'PaperPosition', [0 0 40 18]);

    if ~isempty(p.Results.ExportName)
        exportFilename = ...
            [char(p.Results.ExportName), '_1x2.pdf'];

        exportgraphics( ...
            fig, ...
            exportFilename, ...
            'ContentType', 'vector');
    end
end


function style = defaultPlotStyle()
%DEFAULTPLOTSTYLE Define thesis-style plotting parameters.

    style.colors = [ ...
        0.85 0.10 0.10;   % Red
        0.10 0.30 0.85;   % Blue
        0.10 0.65 0.20;   % Green
        0.90 0.55 0.10;   % Orange
        0.55 0.10 0.75];  % Purple

    style.lw       = 3;
    style.fs_axis  = 25;
    style.fs_leg   = 25;
    style.fs_label = 30;
    style.fs_title = 30;
end


function tiles = normalizeTileSignals(signalNamesGrid)
%NORMALIZETILESIGNALS Convert each tile definition to a cell array of
%character vectors.

    nTiles = numel(signalNamesGrid);
    tiles = cell(1, nTiles);

    for k = 1:nTiles
        entry = signalNamesGrid{k};

        if ischar(entry)
            tiles{k} = {entry};

        elseif isstring(entry)
            tiles{k} = cellstr(entry(:).');

        elseif iscell(entry)
            validEntries = cellfun( ...
                @(x) ischar(x) || (isstring(x) && isscalar(x)), ...
                entry);

            if ~all(validEntries)
                error( ...
                    'plotLoggedSignal1x2:invalidSignalName', ...
                    ['Every signal name in tile %d must be a character ' ...
                     'vector or scalar string.'], ...
                    k);
            end

            tiles{k} = cellfun( ...
                @char, ...
                entry, ...
                'UniformOutput', false);

        else
            error( ...
                'plotLoggedSignal1x2:invalidTileEntry', ...
                ['Tile %d must contain a character vector, string, or ' ...
                 'cell array of signal names.'], ...
                k);
        end

        if isempty(tiles{k})
            error( ...
                'plotLoggedSignal1x2:emptyTile', ...
                'No signals were specified for tile %d.', ...
                k);
        end
    end
end


function val = getTileOpt(optCellArray, idx)
%GETTILEOPT Return the option corresponding to the requested tile.

    if numel(optCellArray) >= idx
        val = optCellArray{idx};
    else
        val = [];
    end
end


function plotSignalsOnAxes( ...
    ax, logsout, signalNames, style, ...
    xLabelOpt, yLabelOpt, titleOpt, legendOpt, ...
    xLimOpt, yLimOpt, showXTickLabels, showYTickLabels)
%PLOTSIGNALSONAXES Plot signals from one dataset on a specified axes.

    nSignals = numel(signalNames);

    %% Prepare legend labels

    if isempty(legendOpt)
        legendLabels = cellfun( ...
            @escapeLatexUnderscore, ...
            signalNames, ...
            'UniformOutput', false);

    elseif ischar(legendOpt)
        legendLabels = {legendOpt};

    elseif isstring(legendOpt)
        legendLabels = cellstr(legendOpt(:).');

    elseif iscell(legendOpt)
        legendLabels = cellfun( ...
            @char, ...
            legendOpt, ...
            'UniformOutput', false);

    else
        error( ...
            'plotLoggedSignal1x2:invalidLegend', ...
            ['Legend entries must be provided as a character vector, ' ...
             'string, or cell array.']);
    end

    if numel(legendLabels) ~= nSignals
        error( ...
            'plotLoggedSignal1x2:legendSizeMismatch', ...
            ['The number of legend entries must equal the number of ' ...
             'signals in the corresponding tile.']);
    end

    %% Plot signals

    hold(ax, 'on');

    for i = 1:nSignals
        signalName = signalNames{i};

        sigElement = getDatasetElement(logsout, signalName);

        if isempty(sigElement)
            error( ...
                'plotLoggedSignal1x2:signalNotFound', ...
                'Signal "%s" was not found in the supplied dataset.', ...
                signalName);
        end

        if ~isprop(sigElement, 'Values')
            error( ...
                'plotLoggedSignal1x2:missingValues', ...
                ['Signal "%s" does not contain the expected Values ' ...
                 'property.'], ...
                signalName);
        end

        signalValues = sigElement.Values;

        [time, data] = extractTimeAndData( ...
            signalValues, signalName);

        colorIndex = mod(i - 1, size(style.colors, 1)) + 1;
        lineColor = style.colors(colorIndex, :);

        plot( ...
            ax, ...
            time, ...
            data, ...
            'Color', lineColor, ...
            'LineWidth', style.lw, ...
            'DisplayName', legendLabels{i});
    end

    hold(ax, 'off');

    %% Configure axes

    grid(ax, 'on');
    ax.FontSize = style.fs_axis;
    ax.Box = 'on';

    if ~isempty(xLimOpt)
        xlim(ax, xLimOpt);
    end

    if ~isempty(yLimOpt)
        ylim(ax, yLimOpt);
    end

    if ~showXTickLabels
        ax.XTickLabel = {};
    end

    if ~showYTickLabels
        ax.YTickLabel = {};
    end

    %% Add legend and labels

    legend( ...
        ax, ...
        legendLabels, ...
        'Interpreter', 'latex', ...
        'FontSize', style.fs_leg, ...
        'Location', 'northeast', ...
        'Box', 'on');

    if ~isempty(xLabelOpt)
        xlabel( ...
            ax, ...
            char(xLabelOpt), ...
            'Interpreter', 'latex', ...
            'FontSize', style.fs_label);
    end

    if ~isempty(yLabelOpt)
        ylabel( ...
            ax, ...
            char(yLabelOpt), ...
            'Interpreter', 'latex', ...
            'FontSize', style.fs_label);
    end

    if ~isempty(titleOpt)
        title( ...
            ax, ...
            char(titleOpt), ...
            'Interpreter', 'latex', ...
            'FontSize', style.fs_title);
    end
end


function sigElement = getDatasetElement(logsout, signalName)
%GETDATASETELEMENT Retrieve a named signal from a dataset-like object.

    try
        sigElement = logsout.get(signalName);
    catch ME
        error( ...
            'plotLoggedSignal1x2:invalidDataset', ...
            ['Unable to access signal "%s". The supplied input must ' ...
             'support the syntax logsout.get(signalName).\n\n%s'], ...
            signalName, ME.message);
    end
end


function [time, data] = extractTimeAndData(signalValues, signalName)
%EXTRACTTIMEANDDATA Extract time and data vectors from a timeseries or
%timetable.

    if isa(signalValues, 'timetable')
        time = signalValues.Properties.RowTimes;

        if isduration(time)
            time = seconds(time);
        elseif isdatetime(time)
            time = seconds(time - time(1));
        else
            time = double(time);
        end

        if width(signalValues) ~= 1
            error( ...
                'plotLoggedSignal1x2:multiColumnTimetable', ...
                ['The timetable for signal "%s" must contain exactly ' ...
                 'one data variable.'], ...
                signalName);
        end

        data = signalValues{:, 1};

    elseif isa(signalValues, 'timeseries')
        time = signalValues.Time;
        data = signalValues.Data;

    else
        error( ...
            'plotLoggedSignal1x2:unsupportedSignalType', ...
            ['Signal "%s" has an unsupported Values type: %s. ' ...
             'Expected a timeseries or timetable.'], ...
            signalName, class(signalValues));
    end

    time = squeeze(time);
    data = squeeze(data);

    if ~isvector(time) || ~isvector(data)
        error( ...
            'plotLoggedSignal1x2:nonVectorSignal', ...
            'Signal "%s" must contain one-dimensional data.', ...
            signalName);
    end

    time = time(:);
    data = data(:);

    if numel(time) ~= numel(data)
        error( ...
            'plotLoggedSignal1x2:lengthMismatch', ...
            ['The time and data vectors of signal "%s" have different ' ...
             'lengths.'], ...
            signalName);
    end
end


function validateLimit(limitValue, optionName)
%VALIDATELIMIT Verify that an axis limit is empty or [min max].

    if isempty(limitValue)
        return;
    end

    if ~isnumeric(limitValue) || ...
            ~isvector(limitValue) || ...
            numel(limitValue) ~= 2 || ...
            any(~isfinite(limitValue)) || ...
            limitValue(1) >= limitValue(2)

        error( ...
            'plotLoggedSignal1x2:invalidLimit', ...
            '%s must be empty or a finite ascending [min max] vector.', ...
            optionName);
    end
end


function expandedLimit = expandConstantLimit(limitValue)
%EXPANDCONSTANTLIMIT Create a valid range if both limits are identical.

    centerValue = limitValue(1);

    if centerValue == 0
        margin = 1;
    else
        margin = 0.05 * abs(centerValue);
    end

    expandedLimit = [ ...
        centerValue - margin, ...
        centerValue + margin];
end


function out = escapeLatexUnderscore(s)
%ESCAPELATEXUNDERSCORE Escape bare underscores for the LaTeX interpreter.

    s = char(s);

    if contains(s, '\')
        out = s;
    else
        out = strrep(s, '_', '\_');
    end
end