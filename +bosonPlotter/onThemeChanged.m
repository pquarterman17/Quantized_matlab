function onThemeChanged(appData, fig, ax, callbacks)
%ONTHEMECHANGED  Apply light or dark theme by repainting from uxTokens.
%
% Syntax
%   bosonPlotter.onThemeChanged(appData, fig, ax, callbacks)
%
% Behaviour
%   Reads `appData.theme` ("Dark" or anything else → Light) and obtains
%   the corresponding palette from `bosonPlotter.uxTokens(theme)` — the
%   single source of truth for both construction-time colours and
%   runtime theme swaps. The previous design used `+styles/dark.m` here
%   while construction read from `+bosonPlotter/uxTokens.m`, leading to
%   subtly different shades when toggling themes.
%
%   Recursively walks every figure descendant and repaints widget
%   surfaces. The walker handles:
%     uipanel / uigridlayout         BackgroundColor → bgPanel
%     uibutton (default-coloured)    BackgroundColor → btn.tool
%     uilistbox                      Bg → bgInput, Fg → text
%     uieditfield / uinumericeditfield  Bg → bgInput, Fg → text
%     uidropdown                     Bg → bgInput, Fg → text
%     uitable                        Bg → bgInput, Fg → text
%     uilabel / uicheckbox           Fg → text
%
%   Buttons whose BackgroundColor sits outside the dark/light "tool"
%   palette (i.e. the coloured semantic accents — primary, danger,
%   export, etc.) are left alone so action buttons keep their identity.
%
%   Finally re-renders the active plot so its axis/grid/line colours
%   reflect the new palette.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads theme, datasets, activeIdx)
%   fig       - Main figure handle
%   ax        - Main axes handle
%   callbacks - Struct of function handles:
%                 .onPlot()  - re-render after theme swap

    isDark = strcmpi(appData.theme, 'Dark');
    if isDark
        themeName = 'dark';
    else
        themeName = 'light';
    end

    tk = bosonPlotter.uxTokens(themeName);

    % ── Figure-level MATLAB theme (R2024b+) ────────────────────────────
    % This is what makes uitable's empty-data viewport, scrollbars, and
    % other built-in widget chrome respect the active mode. Without it,
    % widgets render with the IDE's default light chrome regardless of
    % how we paint individual BackgroundColors. The lower-level theme()
    % API is available since R2024b; gracefully no-op on older releases.
    try
        theme(fig, themeName);
    catch
        % Older MATLAB without theme() — manual colour writes still apply
    end

    % ── Figure & axes ──────────────────────────────────────────────────
    fig.Color = tk.color.bgFigure;

    ax.Color  = tk.color.bgInput;
    ax.XColor = tk.color.text;
    ax.YColor = tk.color.text;
    if isDark
        ax.GridColor = [0.35 0.35 0.38];
    else
        ax.GridColor = [0.55 0.55 0.55];
    end

    % ── Walk and repaint widgets ───────────────────────────────────────
    applyThemeToChildren(fig, tk);

    % ── Re-render active plot so line/axis colours pick up the palette ─
    if appData.activeIdx > 0 && ~isempty(appData.datasets)
        callbacks.onPlot();
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Recursive child-walker
% ════════════════════════════════════════════════════════════════════════

function applyThemeToChildren(parent, tk)
%APPLYTHEMETOCHILDREN  Recursively repaint UI components from tokens.
    children = parent.Children;
    for ci = 1:numel(children)
        c = children(ci);
        cType = class(c);
        try
            switch cType
                case {'matlab.ui.container.Panel', 'matlab.ui.container.GridLayout'}
                    if isprop(c, 'BackgroundColor')
                        c.BackgroundColor = tk.color.bgPanel;
                    end
                case 'matlab.ui.control.Button'
                    % Re-theme only "neutral" buttons. Coloured semantic
                    % buttons (primary/danger/export/...) keep their
                    % identity across themes — we identify those by
                    % checking whether the current BG matches the
                    % previous theme's "tool" colour.
                    if isNeutralButtonColor(c.BackgroundColor)
                        c.BackgroundColor = tk.color.btn.tool;
                        c.FontColor       = tk.color.text;
                    end
                case 'matlab.ui.control.ListBox'
                    c.BackgroundColor = tk.color.bgInput;
                    c.FontColor       = tk.color.text;
                case {'matlab.ui.control.EditField', 'matlab.ui.control.NumericEditField'}
                    c.BackgroundColor = tk.color.bgInput;
                    c.FontColor       = tk.color.text;
                case 'matlab.ui.control.DropDown'
                    c.BackgroundColor = tk.color.bgInput;
                    c.FontColor       = tk.color.text;
                case 'matlab.ui.control.Table'
                    c.BackgroundColor = tk.color.bgInput;
                    c.ForegroundColor = tk.color.text;
                case 'matlab.ui.control.Label'
                    c.FontColor = tk.color.text;
                    % Repaint label BG only when it was previously set
                    % to a known surface colour from the *other* theme.
                    % Labels with intentional accent BGs (section
                    % headers, status bars) keep their colour.
                    if isprop(c, 'BackgroundColor') && ...
                       isThemeSurface(c.BackgroundColor)
                        c.BackgroundColor = tk.color.bgPanel;
                    end
                case 'matlab.ui.control.CheckBox'
                    c.FontColor = tk.color.text;
            end
        catch
            % Skip unsupported property assignments
        end
        if isprop(c, 'Children') && ~isempty(c.Children)
            applyThemeToChildren(c, tk);
        end
    end
end

function tf = isThemeSurface(rgb)
%ISTHEMESURFACE  True if rgb is one of the known panel/figure/input
%   surface colours from either the dark or light palette. Used to
%   identify widgets whose BackgroundColor is "the panel surface" (and
%   should follow the theme) vs widgets with intentional accent BGs.
    if numel(rgb) ~= 3, tf = false; return; end
    refs = [
        % Dark surfaces
        0.13 0.13 0.13;
        0.18 0.18 0.18;
        0.17 0.17 0.17;
        0.28 0.28 0.28;
        % Light surfaces
        0.94 0.94 0.94;
        0.97 0.97 0.97;
        1.00 1.00 1.00;
        0.88 0.88 0.88;
        % Legacy / system defaults that should still get repainted
        0.16 0.16 0.16;
        0.96 0.96 0.96];
    tol = 0.03;
    tf = any(all(abs(refs - rgb) < tol, 2));
end

function tf = isNeutralButtonColor(rgb)
%ISNEUTRALBUTTONCOLOR  True if rgb is one of the "tool" / default greys.
%  We re-theme buttons whose BackgroundColor matches either the dark or
%  the light "tool" colour from uxTokens, plus the legacy neutral greys
%  and the surface colours that other GUIs (FermiViewer / DiraCulator)
%  may have leaked as the global widget default in this MATLAB session.
%  Without the latter, buttons constructed AFTER a sibling GUI was opened
%  end up with that GUI's figure colour and never repaint on theme swap.
    if numel(rgb) ~= 3, tf = false; return; end
    refs = [
        0.28 0.28 0.28;   % uxTokens dark btn.tool
        0.85 0.85 0.85;   % uxTokens light btn.tool
        0.94 0.94 0.94;   % MATLAB default light grey
        0.25 0.25 0.28;   % legacy dark grey
        0.18 0.18 0.18;   % uxTokens dark bgPanel (section-header buttons)
        0.97 0.97 0.97;   % uxTokens light bgPanel
        0.13 0.13 0.13;   % uxTokens dark bgFigure (FermiViewer leak)
        0.16 0.16 0.16];  % older dark bg used in some legacy spots
    tol = 0.05;
    tf = any(all(abs(refs - rgb) < tol, 2));
end
