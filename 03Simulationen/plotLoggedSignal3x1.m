function fig = plotLoggedSignal3x1(logsout, signalNamesGrid, varargin)
%PLOTLOGGEDSIGNAL3X1 Plot logged Simulink signals in a 3x1 tiled layout,
%thesis-style. Fully self-contained (no other files required).
%
%   plotLoggedSignal3x1(out.logsout, {'Sin_wm','Sin_Te','Sin_ia'})
%   plotLoggedSignal3x1(out.logsout, {{'Sin_wm','Sin_wm_ref'}, 'Sin_Te', ...
%                                      {'Sin_ia','Sin_ib','Sin_ic'}})
%
%   signalNamesGrid must have exactly 3 cells, filled row-major into the
%   grid: {row1, row2, row3}. Each cell can be a single char/string
%   signal name, or a cell array of char/string names to overlay
%   multiple signals in that tile.
%
%   All three tiles share ONE common x-axis range. Each tile has its own
%   y-axis range (one tile per row, so no y-axis sharing across tiles).
%   If 'XLim'/'YLim' are left empty, the ranges are computed
%   automatically from the tiles' auto-scaled data ranges; if given
%   explicitly, they are applied directly.
%
%   Optional name-value pairs:
%     'XLabel'         - 1x3 cell array of LaTeX x-axis labels (per tile).
%                        Use [] or '' entries to leave a tile without an
%                        x-axis label text (default: no labels)
%     'YLabel'         - 1x3 cell array of LaTeX y-axis labels (per tile).
%                        Use [] or '' entries to leave a tile without a
%                        y-axis label text (default: no labels)
%     'Title'          - 1x3 cell array of LaTeX tile titles (per tile).
%                        Use [] or '' entries to leave a tile untitled
%                        (default: no titles)
%     'Legend'         - 1x3 cell array of cell arrays of LaTeX legend
%                        labels (per tile)
%     'XLim'           - single [xmin xmax] applied to all three tiles
%                        (default: [] = auto, computed from the data)
%     'YLim'           - 1x3 cell array {yLimTile1, yLimTile2, yLimTile3},
%                        each either [ymin ymax] or [] for auto
%                        (default: {[],[],[]})
%     'ShowXTickLabels'- 1x3 logical array; false hides only the numeric
%                        tick labels on that tile's x-axis. The axis
%                        label text (set via 'XLabel') is unaffected
%                        (default: all true)
%     'ShowYTickLabels'- 1x3 logical array; false hides only the numeric
%                        tick labels on that tile's y-axis. The axis
%                        label text (set via 'YLabel') is unaffected
%                        (default: all true)
%     'ExportName'     - filename (without extension) for PDF export.
%                        If empty, no export is performed. (default: '')
    nTiles = 3;
    if numel(signalNamesGrid) ~= nTiles
        error('signalNamesGrid must contain exactly %d cells (3x1, row-major).', nTiles);
    end
    signalNamesGrid = normalizeTileSignals(signalNamesGrid);
    p = inputParser;
    addParameter(p, 'XLabel', cell(1,nTiles), @iscell);
    addParameter(p, 'YLabel', cell(1,nTiles), @iscell);
    addParameter(p, 'Title',  cell(1,nTiles), @iscell);
    addParameter(p, 'Legend', cell(1,nTiles), @iscell);
    addParameter(p, 'XLim',   [], @(x) isnumeric(x) && (isempty(x) || numel(x)==2));
    addParameter(p, 'YLim',   {[], [], []}, @(x) iscell(x) && numel(x)==3);
    addParameter(p, 'ShowXTickLabels', true(1,nTiles), @(x) islogical(x) && numel(x)==nTiles);
    addParameter(p, 'ShowYTickLabels', true(1,nTiles), @(x) islogical(x) && numel(x)==nTiles);
    addParameter(p, 'ExportName', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    style = defaultPlotStyle();
    fig = figure('Color','w','Units','centimeters','Position',[1 -1 30 44]);
    t_layout = tiledlayout(fig, 3, 1, 'TileSpacing','compact','Padding','compact');
    rows = {1, 2, 3};
    axesArr = gobjects(1, nTiles);
    for k = 1:nTiles
        ax = nexttile(t_layout);
        axesArr(k) = ax;
        rowIdx = k;
        plotSignalsOnAxes(ax, logsout, signalNamesGrid{k}, style, ...
            getTileOpt(p.Results.XLabel, k), ...
            getTileOpt(p.Results.YLabel, k), ...
            getTileOpt(p.Results.Title, k), ...
            getTileOpt(p.Results.Legend, k), ...
            p.Results.XLim, ...
            p.Results.YLim{rowIdx}, ...
            p.Results.ShowXTickLabels(k), ...
            p.Results.ShowYTickLabels(k));
    end
    % --- Ensure a single common x limit across all three tiles ---
    if isempty(p.Results.XLim)
        xlAll = zeros(nTiles, 2);
        for k = 1:nTiles
            xlAll(k,:) = xlim(axesArr(k));
        end
        commonXLim = [min(xlAll(:,1)), max(xlAll(:,2))];
    else
        commonXLim = p.Results.XLim;
    end
    set(axesArr, 'XLim', commonXLim);
    % --- Ensure each tile's y limit (one tile per row, so per-tile only) ---
    for r = 1:numel(rows)
        idx = rows{r};
        if isempty(p.Results.YLim{r})
            ylRow = zeros(numel(idx), 2);
            for j = 1:numel(idx)
                ylRow(j,:) = ylim(axesArr(idx(j)));
            end
            commonYLim = [min(ylRow(:,1)), max(ylRow(:,2))];
        else
            commonYLim = p.Results.YLim{r};
        end
        set(axesArr(idx), 'YLim', commonYLim);
    end
    set(findall(fig,'Type','axes'),'TickLabelInterpreter','latex');
    set(findall(fig,'Type','axes'),'LineWidth',2.0);
    legends = findall(fig,'Type','Legend');
    set(legends,'LineWidth',1.5);
    set(fig,'PaperUnits','centimeters');
    set(fig,'PaperSize',[30 44]);
    set(fig,'PaperPosition',[0 0 30 44]);
    if ~isempty(p.Results.ExportName)
        exportgraphics(fig, [char(p.Results.ExportName) '_3x1.pdf'], 'ContentType','vector');
    end
end
function style = defaultPlotStyle()
%DEFAULTPLOTSTYLE Shared thesis-style plotting parameters.
    style.colors = [0.85 0.10 0.10;   % red
                    0.10 0.30 0.85;   % blue
                    0.10 0.65 0.20;   % green
                    0.90 0.55 0.10;   % orange
                    0.55 0.10 0.75];  % purple
    style.lw       = 2.70;
    style.fs_axis  = 25;
    style.fs_leg   = 25;
    style.fs_label = 30;
    style.fs_title = 30;
end
function tiles = normalizeTileSignals(signalNamesGrid)
%NORMALIZETILESIGNALS Ensure each tile's signal spec is a cell array of
%char names, even if the user passed a single char/string per tile.
    n = numel(signalNamesGrid);
    tiles = cell(1, n);
    for k = 1:n
        entry = signalNamesGrid{k};
        if ischar(entry) || isstring(entry)
            tiles{k} = {char(entry)};
        elseif iscell(entry)
            tiles{k} = entry;
        else
            error('Each tile entry must be a char, string, or cell array of names.');
        end
    end
end
function val = getTileOpt(optCellArray, idx)
%GETTILEOPT Safely fetch the idx-th entry of a per-tile option cell
%array, returning [] if the array is too short or the entry is empty.
    if numel(optCellArray) >= idx
        val = optCellArray{idx};
    else
        val = [];
    end
end
function plotSignalsOnAxes(ax, logsout, signalNames, style, xLabelOpt, yLabelOpt, titleOpt, legendOpt, xLimOpt, yLimOpt, showXTickLabels, showYTickLabels)
%PLOTSIGNALSONAXES Plot one or more logsout signals into a given axes
%using the shared thesis-style formatting.
    nSig = numel(signalNames);
    if isempty(legendOpt)
        legendOpt = cellfun(@escapeLatexUnderscore, signalNames, 'UniformOutput', false);
    elseif ischar(legendOpt) || isstring(legendOpt)
        legendOpt = {char(legendOpt)};
    end
    hold(ax, 'on');
    for i = 1:nSig
        sigElement = logsout.get(signalNames{i});
        if isempty(sigElement)
            error('Signal "%s" not found in logsout.', signalNames{i});
        end
        ts = sigElement.Values;
        if isa(ts, 'timetable')
            t = seconds(ts.Time);
            y = ts.(1);
        else
            t = ts.Time;
            y = ts.Data;
        end
        col = style.colors(mod(i-1, size(style.colors,1)) + 1, :);
        plot(ax, t, y, 'Color', col, 'LineWidth', style.lw);
    end
    hold(ax, 'off');
    grid(ax, 'on');
    ax.FontSize = style.fs_axis;
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
    legend(ax, legendOpt, ...
        'Interpreter','latex','FontSize',style.fs_leg, ...
        'Location','northeast','Box','on');
    if ~isempty(xLabelOpt)
        xlabel(ax, char(xLabelOpt), 'Interpreter','latex','FontSize',style.fs_label);
    end
    if ~isempty(yLabelOpt)
        ylabel(ax, char(yLabelOpt), 'Interpreter','latex','FontSize',style.fs_label);
    end
    if ~isempty(titleOpt)
        title(ax, char(titleOpt), 'Interpreter','latex','FontSize',style.fs_title);
    end
end
function out = escapeLatexUnderscore(s)
%ESCAPELATEXUNDERSCORE Escape bare underscores so LaTeX interpreter
%doesn't choke on raw variable names like 'Sin_ia'.
    s = char(s);
    if any(s == '\')
        out = s;
    else
        out = strrep(s, '_', '\_');
    end
end