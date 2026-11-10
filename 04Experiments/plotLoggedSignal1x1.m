function fig = plotLoggedSignal1x1(logsout, signalNames, varargin)
%PLOTLOGGEDSIGNAL1X1 Plot logged Simulink signals in a single-axes
%layout, thesis-style. Fully self-contained (no other files required).
%
%   plotLoggedSignal1x1(out.logsout, 'Sin_wm')
%   plotLoggedSignal1x1(out.logsout, {'Sin_wm','Sin_wm_ref'})
%
%   signalNames can be a single char/string signal name, or a cell array
%   of char/string names to overlay multiple signals on the single axes.
%
%   Optional name-value pairs:
%     'XLabel'         - LaTeX x-axis label (default: no label)
%     'YLabel'         - LaTeX y-axis label (default: no label)
%     'Title'          - LaTeX title (default: no title)
%     'Legend'         - cell array of LaTeX legend labels
%     'XLim'           - [xmin xmax] (default: [] = auto, from data)
%     'YLim'           - [ymin ymax] (default: [] = auto, from data)
%     'ShowXTickLabels'- logical; false hides numeric tick labels on the
%                        x-axis. The axis label text (via 'XLabel') is
%                        unaffected (default: true)
%     'ShowYTickLabels'- logical; false hides numeric tick labels on the
%                        y-axis. The axis label text (via 'YLabel') is
%                        unaffected (default: true)
%     'ExportName'     - filename (without extension) for PDF export.
%                        If empty, no export is performed. (default: '')
    signalNames = normalizeTileSignals(signalNames);
    p = inputParser;
    addParameter(p, 'XLabel', [], @(x) ischar(x) || isstring(x) || isempty(x));
    addParameter(p, 'YLabel', [], @(x) ischar(x) || isstring(x) || isempty(x));
    addParameter(p, 'Title',  [], @(x) ischar(x) || isstring(x) || isempty(x));
    addParameter(p, 'Legend', {}, @iscell);
    addParameter(p, 'XLim',   [], @(x) isnumeric(x) && (isempty(x) || numel(x)==2));
    addParameter(p, 'YLim',   [], @(x) isnumeric(x) && (isempty(x) || numel(x)==2));
    addParameter(p, 'ShowXTickLabels', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'ShowYTickLabels', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'ExportName', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    style = defaultPlotStyle();
    fig = figure('Color','w','Units','centimeters','Position',[1 -1 60 22]);
    ax = axes(fig);
    plotSignalsOnAxes(ax, logsout, signalNames, style, ...
        p.Results.XLabel, ...
        p.Results.YLabel, ...
        p.Results.Title, ...
        p.Results.Legend, ...
        p.Results.XLim, ...
        p.Results.YLim, ...
        p.Results.ShowXTickLabels, ...
        p.Results.ShowYTickLabels);
    set(findall(fig,'Type','axes'),'TickLabelInterpreter','latex');
    set(findall(fig,'Type','axes'),'LineWidth',2.0);
    legends = findall(fig,'Type','Legend');
    set(legends,'LineWidth',1.5);
    set(fig,'PaperUnits','centimeters');
    set(fig,'PaperSize',[30 22]);
    set(fig,'PaperPosition',[0 0 30 22]);
    if ~isempty(p.Results.ExportName)
        exportgraphics(fig, [char(p.Results.ExportName) '_1x1.pdf'], 'ContentType','vector');
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
function names = normalizeTileSignals(signalNames)
%NORMALIZETILESIGNALS Ensure the signal spec is a cell array of char
%names, even if the user passed a single char/string.
    if ischar(signalNames) || isstring(signalNames)
        names = {char(signalNames)};
    elseif iscell(signalNames)
        names = signalNames;
    else
        error('signalNames must be a char, string, or cell array of names.');
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