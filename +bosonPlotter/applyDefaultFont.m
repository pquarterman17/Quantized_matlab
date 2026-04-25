function applyDefaultFont(parent, fs)
%APPLYDEFAULTFONT  Set FontSize on parent's button children that haven't
%   already been customised away from the MATLAB default (~12 pt).
%
% Syntax
%   bosonPlotter.applyDefaultFont(parent, fs)
%
% Inputs
%   parent — uigridlayout / uipanel / uifigure
%   fs     — target FontSize (e.g. tk.font.body = 9)
%
% Notes
%   Only touches uibuttons (state and push) whose current FontSize is
%   the MATLAB default (12). Buttons that have already been explicitly
%   sized — e.g. section-headers via bosonPlotter.sectionHeader, which
%   set FontSize = tk.font.body — are left alone.
%
%   Use this once after a panel of buttons has been built to bring any
%   un-sized buttons into the surrounding panel's typography. Saves
%   sprinkling 'FontSize', tk.font.body across every uibutton(...) call.

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
        if isa(ch, 'matlab.ui.control.Button') || isa(ch, 'matlab.ui.control.StateButton')
            if isprop(ch, 'FontSize') && ch.FontSize == 12
                ch.FontSize = fs;
            end
        end
        % Recurse into containers (uigridlayout, uipanel) — buttons may
        % live inside nested sub-grids.
        if isa(ch, 'matlab.ui.container.GridLayout') || isa(ch, 'matlab.ui.container.Panel')
            walk(ch, fs);
        end
    end
end
