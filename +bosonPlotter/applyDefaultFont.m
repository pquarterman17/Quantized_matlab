function applyDefaultFont(parent, fs)
%APPLYDEFAULTFONT  Set FontSize on widgets that still carry MATLAB's
%   default 12 pt to bring them in line with the surrounding panel.
%
% Syntax
%   bosonPlotter.applyDefaultFont(parent, fs)
%
% Inputs
%   parent — uigridlayout / uipanel / uifigure
%   fs     — target FontSize (e.g. tk.font.body = 9)
%
% Notes
%   Walks the whole subtree rooted at `parent`. For every uibutton,
%   uieditfield, uidropdown, uispinner, uicheckbox, or StateButton whose
%   current FontSize equals the MATLAB default (12), the FontSize is
%   reset to `fs`. Widgets whose FontSize was explicitly set during
%   construction (e.g. tk.font.label = 10, tk.font.title = 11) are
%   detected and left alone. uilabels are left alone too — they often
%   carry intentional sizing (titles, captions).
%
%   Saves sprinkling 'FontSize', tk.font.body across every uibutton(...)
%   call in panels that mix many control types.

    if isempty(parent) || ~isvalid(parent)
        return;
    end

    walk(parent, fs);
end

function walk(node, fs)
    if ~isvalid(node) || ~isprop(node, 'Children')
        return;
    end
    kids = node.Children;
    for k = 1:numel(kids)
        ch = kids(k);
        if ~isvalid(ch); continue; end
        if isFontTarget(ch) && isprop(ch, 'FontSize') && ch.FontSize == 12
            ch.FontSize = fs;
        end
        % Recurse into containers (uigridlayout, uipanel) — controls may
        % live inside nested sub-grids.
        if isa(ch, 'matlab.ui.container.GridLayout') || isa(ch, 'matlab.ui.container.Panel')
            walk(ch, fs);
        end
    end
end

function tf = isFontTarget(ch)
%ISFONTTARGET  True for control types whose default 12 pt looks too big
%   in compact panels. uilabel is intentionally excluded — labels often
%   carry deliberate sizing (titles, captions, hero text).
    tf = isa(ch, 'matlab.ui.control.Button')      || ...
         isa(ch, 'matlab.ui.control.StateButton') || ...
         isa(ch, 'matlab.ui.control.EditField')   || ...
         isa(ch, 'matlab.ui.control.NumericEditField') || ...
         isa(ch, 'matlab.ui.control.DropDown')    || ...
         isa(ch, 'matlab.ui.control.Spinner')     || ...
         isa(ch, 'matlab.ui.control.CheckBox');
end
