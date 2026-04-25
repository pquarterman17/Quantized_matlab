function tk = uxTokens()
%UXTOKENS  Centralised UI design tokens for BosonPlotter and dialogs.
%
% Returns a struct of typography, colour, padding, and spacing values
% that act as the single source of truth for the toolbox's GUI look-and-
% feel. Use these tokens instead of literal numbers in every panel/
% control construction so global rescaling is one edit.
%
% Usage
%   tk = bosonPlotter.uxTokens();
%   uilabel(g, 'Text', 'X:', 'FontSize', tk.font.label);
%   pnl.BackgroundColor = tk.color.bgPanel;
%   gl.Padding = tk.pad.normal;
%
% ── Typography ──────────────────────────────────────────────────────────
%
% A 4-tier scale carries every recurring text role. The hero size is for
% one-off splash text only.
%
%   tk.font.title    = 11   panel titles
%   tk.font.label    = 10   form labels (right-aligned, ":" terminator)
%   tk.font.body     =  9   default control text + button labels
%   tk.font.caption  =  8   dense tables, footnotes, "fmt" tick labels
%   tk.font.hero     = 22   figure-builder splash only
%
% ── Colour ─────────────────────────────────────────────────────────────
%
% Foreground / text greys (semantic):
%   tk.color.text          [0.92 0.92 0.92]   primary text on dark widgets
%   tk.color.textMuted     [0.75 0.75 0.75]   secondary labels, captions
%   tk.color.textDim       [0.55 0.55 0.55]   section headers, hints
%   tk.color.textDisabled  [0.40 0.40 0.40]   greyed-out / inactive
%   tk.color.textHighlight [0.85 0.85 0.85]   header-button text on dark BG
%   tk.color.textAccent    [0.30 0.30 0.60]   stats / region info
%   tk.color.textOk        [0.50 0.70 0.50]   units row, success hints
%   tk.color.textWarn      [0.90 0.55 0.00]
%   tk.color.textError     [0.80 0.20 0.20]
%
% Backgrounds:
%   tk.color.bgDark        [0.17 0.17 0.17]   edit fields
%   tk.color.bgPanel       [0.18 0.18 0.18]   section header bars
%   tk.color.bgSubtle      [0.28 0.28 0.28]   secondary buttons
%
% Button background palette (mirrors the BTN_* constants in BosonPlotter.m
% so package-level dialogs can use the same palette without re-declaring):
%   tk.color.btn.primary   green  — primary actions (Add Files, Apply)
%   tk.color.btn.accent    blue   — analysis/fit actions
%   tk.color.btn.danger    red    — destructive (Remove, Clear)
%   tk.color.btn.export    slate  — save/export operations
%   tk.color.btn.external  teal   — external integrations (Origin, HDF5)
%   tk.color.btn.session   steel  — session save/load
%   tk.color.btn.tool      gray   — secondary tools & utilities
%   tk.color.btn.secondary charcoal — figure export, copy
%   tk.color.btn.interact  amber  — interactive plot-click tools
%   tk.color.btn.animate   warm   — animation / playback
%   tk.color.btn.fg        white  — text on dark buttons
%
% ── Padding & spacing ──────────────────────────────────────────────────
%
%   tk.pad.flush       = [0 0 0 0]   nested sub-grids
%   tk.pad.tight       = [2 2 2 2]   small inner panels
%   tk.pad.normal      = [4 4 4 4]   standard panel inset
%   tk.pad.comfortable = [6 6 6 6]   root grid only
%   tk.pad.barH        = [2 0 2 0]   horizontal toolbars
%
%   tk.gap.row      = 2;  tk.gap.rowTight = 1;  tk.gap.rowComfy = 4;
%   tk.gap.col      = 3;  tk.gap.colTight = 2;  tk.gap.colComfy = 6;

    % Typography
    tk.font.title    = 11;
    tk.font.label    = 10;
    tk.font.body     =  9;
    tk.font.caption  =  8;
    tk.font.hero     = 22;

    % Foreground / text greys
    tk.color.text          = [0.92 0.92 0.92];
    tk.color.textMuted     = [0.75 0.75 0.75];
    tk.color.textDim       = [0.55 0.55 0.55];
    tk.color.textDisabled  = [0.40 0.40 0.40];
    tk.color.textHighlight = [0.85 0.85 0.85];
    tk.color.textAccent    = [0.30 0.30 0.60];
    tk.color.textOk        = [0.50 0.70 0.50];
    tk.color.textWarn      = [0.90 0.55 0.00];
    tk.color.textError     = [0.80 0.20 0.20];

    % Backgrounds
    tk.color.bgDark        = [0.17 0.17 0.17];
    tk.color.bgPanel       = [0.18 0.18 0.18];
    tk.color.bgSubtle      = [0.28 0.28 0.28];

    % Button BG palette (mirrors BosonPlotter.m BTN_* constants)
    tk.color.btn.primary   = [0.18 0.52 0.18];
    tk.color.btn.accent    = [0.15 0.37 0.63];
    tk.color.btn.danger    = [0.55 0.15 0.15];
    tk.color.btn.export    = [0.18 0.32 0.52];
    tk.color.btn.external  = [0.12 0.38 0.38];
    tk.color.btn.session   = [0.22 0.32 0.42];
    tk.color.btn.tool      = [0.28 0.28 0.28];
    tk.color.btn.secondary = [0.25 0.28 0.35];
    tk.color.btn.interact  = [0.50 0.28 0.05];
    tk.color.btn.animate   = [0.50 0.35 0.15];
    tk.color.btn.fg        = [1 1 1];

    % Padding
    tk.pad.flush       = [0 0 0 0];
    tk.pad.tight       = [2 2 2 2];
    tk.pad.normal      = [4 4 4 4];
    tk.pad.comfortable = [6 6 6 6];
    tk.pad.barH        = [2 0 2 0];

    % Spacing
    tk.gap.row      = 2;  tk.gap.rowTight = 1;  tk.gap.rowComfy = 4;
    tk.gap.col      = 3;  tk.gap.colTight = 2;  tk.gap.colComfy = 6;
end
