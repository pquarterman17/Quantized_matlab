function applyDialogTheme(dlgFig, theme)
%APPLYDIALOGTHEME  Apply dark/light theme colours to a popup dialog figure.
%
%   Syntax
%   ------
%   bosonPlotter.applyDialogTheme(dlgFig, theme)
%
%   Inputs
%   ------
%   dlgFig  — uifigure handle for the popup dialog
%   theme   — theme name string: 'Dark' or 'Light'
%             (accepts case-insensitive variants; any non-Dark value → Light)
%
%   Description
%   -----------
%   Sets the figure background and recursively walks all child widgets,
%   applying dark or light colours that match the parent BosonPlotter
%   window.  Uses the same colour values as onThemeChanged / applyThemeToChildren
%   in BosonPlotter.m so dialogs stay visually consistent.
%
%   Buttons with custom accent colours (non-neutral BackgroundColor) are
%   preserved unchanged, following the same convention used in the main GUI.
%
%   Examples
%   --------
%   % Inside a BosonPlotter nested dialog:
%   bosonPlotter.applyDialogTheme(myFig, appData.theme);
%
%   See also bosonPlotter.plotStyleDialog, styles.dark

% ════════════════════════════════════════════════════════════════════════════

    % ── Resolve colour set from theme string ─────────────────────────────
    isDark = strcmpi(theme, 'Dark');
    if isDark
        th = styles.dark();
        panC = th.panelBgColor;
        fgC  = th.fgColor;
        btnC = th.buttonBgColor;
        btnF = th.buttonFgColor;
        lstC = th.listBgColor;
        lstF = th.listFgColor;
        edtC = th.editBgColor;
        edtF = th.editFgColor;
    else
        panC = [0.94 0.94 0.94];
        fgC  = [0    0    0   ];
        btnC = [0.94 0.94 0.94];
        btnF = [0    0    0   ];
        lstC = [1    1    1   ];
        lstF = [0    0    0   ];
        edtC = [1    1    1   ];
        edtF = [0    0    0   ];
    end

    % ── Figure background ─────────────────────────────────────────────────
    dlgFig.Color = panC;

    % ── Recursively colour all children ───────────────────────────────────
    applyToChildren(dlgFig, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);
end

% ════════════════════════════════════════════════════════════════════════════
%  LOCAL HELPER
% ════════════════════════════════════════════════════════════════════════════

function applyToChildren(parent, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF)
%APPLYTOCHILDREN  Recurse into parent and theme each known widget type.
    children = parent.Children;
    for ci = 1:numel(children)
        c     = children(ci);
        cType = class(c);
        try
            switch cType
                case {'matlab.ui.container.Panel', 'matlab.ui.container.GridLayout'}
                    if isprop(c, 'BackgroundColor')
                        c.BackgroundColor = panC;
                    end
                case 'matlab.ui.control.Button'
                    % Preserve custom accent colours — only retheme neutral buttons.
                    % "Neutral" in light mode: ~[0.94 0.94 0.94]
                    % "Neutral" in dark mode:  ~[0.25 0.25 0.28]
                    isNeutral = all(abs(c.BackgroundColor - [0.94 0.94 0.94]) < 0.05) || ...
                                all(abs(c.BackgroundColor - [0.25 0.25 0.28]) < 0.05);
                    if isNeutral
                        c.BackgroundColor = btnC;
                        c.FontColor       = btnF;
                    end
                case 'matlab.ui.control.Label'
                    % Preserve muted grey info labels (FontColor near [0.4 0.4 0.4])
                    isMuted = all(abs(c.FontColor - [0.4 0.4 0.4]) < 0.08) || ...
                              all(abs(c.FontColor - [0.5 0.5 0.5]) < 0.08);
                    if ~isMuted
                        c.FontColor = fgC;
                    end
                case 'matlab.ui.control.ListBox'
                    c.BackgroundColor = lstC;
                    c.FontColor       = lstF;
                case {'matlab.ui.control.EditField', 'matlab.ui.control.NumericEditField', ...
                      'matlab.ui.control.TextArea'}
                    c.BackgroundColor = edtC;
                    c.FontColor       = edtF;
                case {'matlab.ui.control.DropDown', 'matlab.ui.control.Spinner'}
                    c.BackgroundColor = edtC;
                    c.FontColor       = edtF;
                case {'matlab.ui.control.CheckBox', 'matlab.ui.control.RadioButton'}
                    c.FontColor = fgC;
                case 'matlab.ui.control.Table'
                    if isprop(c, 'BackgroundColor')
                        c.BackgroundColor = edtC;
                    end
                    if isprop(c, 'FontColor')
                        c.FontColor = edtF;
                    end
            end
        catch
            % Skip properties not supported on this widget version
        end
        % Recurse into any container
        if isprop(c, 'Children') && ~isempty(c.Children)
            applyToChildren(c, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);
        end
    end
end
