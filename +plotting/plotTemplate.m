function varargout = plotTemplate(action, options)
%PLOTTEMPLATE  Save, load, apply, list, and delete plot style templates.
%
%   Syntax:
%       plotting.plotTemplate('save',   Name="MyStyle", Axes=ax)
%       tmpl  = plotting.plotTemplate('load',   Name="MyStyle")
%       plotting.plotTemplate('apply',  Name="MyStyle", Axes=ax)
%       names = plotting.plotTemplate('list')
%       plotting.plotTemplate('delete', Name="MyStyle")
%
%   Inputs:
%       action  — 'save' | 'load' | 'apply' | 'list' | 'delete'
%
%   Name-Value Options:
%       Name    (string)  Template name (required for save/load/apply/delete)
%       Axes    (axes handle)  Source axes for 'save'; target for 'apply'
%
%   Outputs:
%       'load'  returns the template struct
%       'list'  returns a cell array of template name strings
%
%   Examples:
%       fig = figure; plot(rand(5,1));
%       gca.FontSize = 14; gca.Box = 'on';
%       plotting.plotTemplate('save', Name='PubStyle', Axes=gca)
%       plotting.plotTemplate('apply', Name='PubStyle', Axes=gca)
%       names = plotting.plotTemplate('list')
%       plotting.plotTemplate('delete', Name='PubStyle')
%
%   See also plotting.templateDialog, plotting.formatAxes

arguments
    action  (1,1) string {mustBeMember(action, ["save","load","apply","list","delete"])}
    options.Name  (1,1) string = ""
    options.Axes  = []
end

templateDir = fullfile(prefdir(), 'dataplotter_templates');

switch action

    % ════════════════════════════════════════════════════════════════════
    %  SAVE
    % ════════════════════════════════════════════════════════════════════
    case 'save'
        mustHaveName(options.Name);
        ax = validateAxes(options.Axes);

        tmpl = captureAxes(ax, options.Name);
        ensureDir(templateDir);
        filepath = templatePath(templateDir, options.Name);
        save(filepath, 'tmpl');

    % ════════════════════════════════════════════════════════════════════
    %  LOAD
    % ════════════════════════════════════════════════════════════════════
    case 'load'
        mustHaveName(options.Name);
        filepath = templatePath(templateDir, options.Name);
        if ~isfile(filepath)
            error('plotTemplate:notFound', ...
                'Template "%s" not found.', options.Name);
        end
        s = load(filepath, 'tmpl');
        varargout{1} = s.tmpl;

    % ════════════════════════════════════════════════════════════════════
    %  APPLY
    % ════════════════════════════════════════════════════════════════════
    case 'apply'
        mustHaveName(options.Name);
        ax = validateAxes(options.Axes);
        filepath = templatePath(templateDir, options.Name);
        if ~isfile(filepath)
            error('plotTemplate:notFound', ...
                'Template "%s" not found.', options.Name);
        end
        s = load(filepath, 'tmpl');
        applyTemplate(s.tmpl, ax);

    % ════════════════════════════════════════════════════════════════════
    %  LIST
    % ════════════════════════════════════════════════════════════════════
    case 'list'
        if ~isfolder(templateDir)
            varargout{1} = {};
            return;
        end
        files = dir(fullfile(templateDir, '*.mat'));
        names = cell(numel(files), 1);
        for k = 1:numel(files)
            [~, nm] = fileparts(files(k).name);
            names{k} = nm;
        end
        varargout{1} = names;

    % ════════════════════════════════════════════════════════════════════
    %  DELETE
    % ════════════════════════════════════════════════════════════════════
    case 'delete'
        mustHaveName(options.Name);
        filepath = templatePath(templateDir, options.Name);
        if isfile(filepath)
            delete(filepath);
        else
            error('plotTemplate:notFound', ...
                'Template "%s" not found.', options.Name);
        end

end
end % plotTemplate


% ════════════════════════════════════════════════════════════════════════
%  Local: capture axes styling into a template struct
% ════════════════════════════════════════════════════════════════════════
function tmpl = captureAxes(ax, name)

tmpl.name    = char(name);
tmpl.created = datetime('now');

% ── Axes properties ──────────────────────────────────────────────────
ap.FontName      = ax.FontName;
ap.FontSize      = ax.FontSize;
ap.FontWeight    = ax.FontWeight;
ap.XColor        = ax.XColor;
ap.YColor        = ax.YColor;
ap.LineWidth     = ax.LineWidth;
ap.Box           = ax.Box;
ap.XGrid         = ax.XGrid;
ap.YGrid         = ax.YGrid;
ap.XScale        = ax.XScale;
ap.YScale        = ax.YScale;
ap.XMinorGrid    = ax.XMinorGrid;
ap.YMinorGrid    = ax.YMinorGrid;
ap.TickDir       = ax.TickDir;
ap.TickLength    = ax.TickLength;
ap.Color         = ax.Color;
ap.XLabelString  = ax.XLabel.String;
ap.XLabelFontSize = ax.XLabel.FontSize;
ap.YLabelString  = ax.YLabel.String;
ap.YLabelFontSize = ax.YLabel.FontSize;
ap.TitleString   = ax.Title.String;
ap.TitleFontSize = ax.Title.FontSize;
tmpl.axesProps   = ap;

% ── Line children ─────────────────────────────────────────────────────
lineKids = findobj(ax, 'Type', 'line', '-depth', 1);
tmpl.lineProps = struct('Color', {}, 'LineWidth', {}, ...
    'LineStyle', {}, 'Marker', {}, 'MarkerSize', {});
for k = 1:numel(lineKids)
    lp.Color      = lineKids(k).Color;
    lp.LineWidth  = lineKids(k).LineWidth;
    lp.LineStyle  = lineKids(k).LineStyle;
    lp.Marker     = lineKids(k).Marker;
    lp.MarkerSize = lineKids(k).MarkerSize;
    tmpl.lineProps(end+1) = lp;
end

% ── Color order ───────────────────────────────────────────────────────
tmpl.colorOrder = ax.ColorOrder;

% ── Legend ────────────────────────────────────────────────────────────
lgd = ax.Legend;
if ~isempty(lgd) && isvalid(lgd)
    lp.Location   = lgd.Location;
    lp.FontSize   = lgd.FontSize;
    lp.Box        = lgd.Box;
    lp.Interpreter = lgd.Interpreter;
else
    lp.Location   = 'northeast';
    lp.FontSize   = 9;
    lp.Box        = 'on';
    lp.Interpreter = 'none';
end
tmpl.legendProps = lp;

% ── Figure background and size ────────────────────────────────────────
fig = ancestor(ax, 'figure');
fp.Color = fig.Color;
pos = fig.Position;             % [x y w h] in pixels
fp.Width  = pos(3);
fp.Height = pos(4);
tmpl.figureProps = fp;

end


% ════════════════════════════════════════════════════════════════════════
%  Local: apply a template struct to an axes handle
% ════════════════════════════════════════════════════════════════════════
function applyTemplate(tmpl, ax)

% ── Axes properties ──────────────────────────────────────────────────
ap = tmpl.axesProps;
ax.FontName    = ap.FontName;
ax.FontSize    = ap.FontSize;
ax.FontWeight  = ap.FontWeight;
ax.XColor      = ap.XColor;
ax.YColor      = ap.YColor;
ax.LineWidth   = ap.LineWidth;
ax.Box         = ap.Box;
ax.XGrid       = ap.XGrid;
ax.YGrid       = ap.YGrid;
ax.XScale      = ap.XScale;
ax.YScale      = ap.YScale;
ax.XMinorGrid  = ap.XMinorGrid;
ax.YMinorGrid  = ap.YMinorGrid;
ax.TickDir     = ap.TickDir;
ax.TickLength  = ap.TickLength;
ax.Color       = ap.Color;

if ~isempty(ap.XLabelString)
    ax.XLabel.String   = ap.XLabelString;
    ax.XLabel.FontSize = ap.XLabelFontSize;
end
if ~isempty(ap.YLabelString)
    ax.YLabel.String   = ap.YLabelString;
    ax.YLabel.FontSize = ap.YLabelFontSize;
end
if ~isempty(ap.TitleString)
    ax.Title.String   = ap.TitleString;
    ax.Title.FontSize = ap.TitleFontSize;
end

% ── Color order ───────────────────────────────────────────────────────
ax.ColorOrder = tmpl.colorOrder;

% ── Line children (match by index) ───────────────────────────────────
lineKids = findobj(ax, 'Type', 'line', '-depth', 1);
nLines   = min(numel(lineKids), numel(tmpl.lineProps));
for k = 1:nLines
    lp = tmpl.lineProps(k);
    lineKids(k).Color      = lp.Color;
    lineKids(k).LineWidth  = lp.LineWidth;
    lineKids(k).LineStyle  = lp.LineStyle;
    lineKids(k).Marker     = lp.Marker;
    lineKids(k).MarkerSize = lp.MarkerSize;
end

% ── Legend ────────────────────────────────────────────────────────────
lgd = ax.Legend;
if ~isempty(lgd) && isvalid(lgd)
    lp = tmpl.legendProps;
    lgd.Location    = lp.Location;
    lgd.FontSize    = lp.FontSize;
    lgd.Box         = lp.Box;
    lgd.Interpreter = lp.Interpreter;
end

% ── Figure background and size ────────────────────────────────────────
fig = ancestor(ax, 'figure');
fp  = tmpl.figureProps;
fig.Color = fp.Color;
pos = fig.Position;
fig.Position = [pos(1) pos(2) fp.Width fp.Height];

end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════
function mustHaveName(name)
    if strtrim(name) == ""
        error('plotTemplate:missingName', 'Name option is required.');
    end
end

function ax = validateAxes(ax)
    if isempty(ax) || ~isvalid(ax) || ~isa(ax, 'matlab.graphics.axis.Axes')
        error('plotTemplate:badAxes', ...
            'Axes option must be a valid axes handle.');
    end
end

function ensureDir(d)
    if ~isfolder(d)
        mkdir(d);
    end
end

function p = templatePath(dir, name)
    p = fullfile(dir, [matlab.lang.makeValidName(char(name)), '.mat']);
end
