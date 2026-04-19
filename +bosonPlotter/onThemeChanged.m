function onThemeChanged(appData, fig, ax, callbacks)
%ONTHEMECHANGED  Apply light or dark theme to the entire GUI.
%
% Syntax
%   bosonPlotter.onThemeChanged(appData, fig, ax, callbacks)
%
% Behaviour
%   Reads `appData.theme` ("Dark" or anything else → Light) and picks
%   one of the pre-defined palettes from `+styles`.  Applies background
%   and foreground colours to:
%     * the main figure (`fig.Color`)
%     * the main axes (Color / XColor / YColor / GridColor)
%     * every panel, grid layout, button, list box, edit field,
%       numeric field, label, dropdown and checkbox recursively (via
%       the local `applyThemeToChildren` helper)
%   Buttons with custom background colours (anything not matching the
%   default light/dark grey) are preserved — e.g. the coloured action
%   buttons keep their identity across themes.  Finally, the active
%   plot is re-rendered so its default line/axis colours reflect the
%   new palette.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads theme, datasets, activeIdx)
%   fig       - Main figure handle (background recipient)
%   ax        - Main axes handle
%   callbacks - Struct of function handles:
%                 .onPlot()  - re-render after theme swap

    isDark = strcmp(appData.theme, 'Dark');
    if isDark
        th = styles.dark();
    else
        th = styles.default();
    end

    if isDark
        bgC  = th.bgColor;
        fgC  = th.fgColor;
        panC = th.panelBgColor;
        btnC = th.buttonBgColor;
        btnF = th.buttonFgColor;
        lstC = th.listBgColor;
        lstF = th.listFgColor;
        edtC = th.editBgColor;
        edtF = th.editFgColor;
        axBg = th.axesBgColor;
        axFg = th.axesFgColor;
    else
        bgC  = [0.94 0.94 0.94];
        fgC  = [0 0 0];
        panC = [0.94 0.94 0.94];
        btnC = [0.94 0.94 0.94];
        btnF = [0 0 0];
        lstC = [1 1 1];
        lstF = [0 0 0];
        edtC = [1 1 1];
        edtF = [0 0 0];
        axBg = [1 1 1];
        axFg = [0.15 0.15 0.15];
    end

    fig.Color = bgC;

    ax.Color  = axBg;
    ax.XColor = axFg;
    ax.YColor = axFg;
    if isDark && isfield(th, 'gridColor')
        ax.GridColor = th.gridColor;
    else
        ax.GridColor = [0.15 0.15 0.15];
    end

    applyThemeToChildren(fig, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);

    if appData.activeIdx > 0 && ~isempty(appData.datasets)
        callbacks.onPlot();
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Recursive child-walker
% ════════════════════════════════════════════════════════════════════════

function applyThemeToChildren(parent, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF)
%APPLYTHEMETOCHILDREN  Recursively set theme colours on UI components.
    children = parent.Children;
    for ci = 1:numel(children)
        c = children(ci);
        cType = class(c);
        try
            switch cType
                case {'matlab.ui.container.Panel', 'matlab.ui.container.GridLayout'}
                    if isprop(c, 'BackgroundColor')
                        c.BackgroundColor = panC;
                    end
                case 'matlab.ui.control.Button'
                    % Don't override buttons with custom colors (colored buttons)
                    if all(abs(c.BackgroundColor - [0.94 0.94 0.94]) < 0.05) || ...
                       all(abs(c.BackgroundColor - [0.25 0.25 0.28]) < 0.05)
                        c.BackgroundColor = btnC;
                        c.FontColor = btnF;
                    end
                case 'matlab.ui.control.ListBox'
                    c.BackgroundColor = lstC;
                    c.FontColor       = lstF;
                case {'matlab.ui.control.EditField', 'matlab.ui.control.NumericEditField'}
                    c.BackgroundColor = edtC;
                    c.FontColor       = edtF;
                case 'matlab.ui.control.Label'
                    c.FontColor = fgC;
                case 'matlab.ui.control.DropDown'
                    c.BackgroundColor = edtC;
                    c.FontColor       = edtF;
                case 'matlab.ui.control.CheckBox'
                    c.FontColor = fgC;
            end
        catch
            % Skip unsupported property assignments
        end
        if isprop(c, 'Children') && ~isempty(c.Children)
            applyThemeToChildren(c, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);
        end
    end
end
