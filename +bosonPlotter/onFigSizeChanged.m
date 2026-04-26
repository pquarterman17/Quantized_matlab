function onFigSizeChanged(appData, fig, widgets, constants, callbacks)
%ONFIGSIZECHANGED  Enforce minimum figure size and adapt layout to window width.
%
% Syntax
%   bosonPlotter.onFigSizeChanged(appData, fig, widgets, constants, callbacks)
%
% Behaviour
%   Called from the figure's `SizeChangedFcn` nested-delegate (which
%   is responsible for disabling/re-installing the callback around
%   this call to avoid recursion from the `fig.Position` write below):
%     * Clamps width to >=600 px and height to >=MIN_FIG_H.
%     * Allocates row heights in the root grid: short windows pin the
%       preview (ratio '3x':'2x' for analysis:preview), taller windows
%       let analysis flex ('1x':'1x').
%     * Adapts the content-grid column widths (file list + controls)
%       on narrow windows so the preview is not crushed.
%     * Adapts the analysis-grid column widths (corrections + 2D map
%       + save/export) the same way, collapsing the 2D map column to
%       0 when the active dataset is 1D.
%     * Keeps the data-table hidden and collapses col 2 while in 2D mode
%       (regardless of resize) so the heatmap takes the freed space.
%   Finally, re-installs itself as the SizeChangedFcn so the next
%   resize fires again.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig        - Main figure handle (reads/writes Position; callback owner)
%   widgets    - Widget struct with fields:
%                   .rootGL, .contentGL, .analysisGL, .dataTablePanel
%   constants  - Struct with fields:
%                   .MIN_FIG_H, .LAYOUT_DEFAULTS (struct with fileListW,
%                   ctrlPanelW, corrPanelW)
%   callbacks  - Struct of function handles:
%                   .is2DDataset(ds) -> logical

    pos = fig.Position;
    changed = false;
    if pos(4) < constants.MIN_FIG_H
        pos(4) = constants.MIN_FIG_H;
        changed = true;
    end
    if pos(3) < 600
        pos(3) = 600;
        changed = true;
    end
    if changed
        fig.Position = pos;
    end
    if pos(4) < 700
        widgets.rootGL.RowHeight = {'3x', '2x', 16};
    else
        widgets.rootGL.RowHeight = {'1x', '1x', 16};
    end

    figW = pos(3);
    defFileW = constants.LAYOUT_DEFAULTS.fileListW;
    defCtrlW = constants.LAYOUT_DEFAULTS.ctrlPanelW;
    if figW < 800
        widgets.contentGL.ColumnWidth = {min(140, defFileW), min(160, defCtrlW), '1x'};
    elseif figW < 1000
        widgets.contentGL.ColumnWidth = {min(160, defFileW), min(175, defCtrlW), '1x'};
    end

    is2D_now = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
               callbacks.is2DDataset(appData.datasets{appData.activeIdx});
    % In 2D mode, col 2 (data table) collapses so col 3 (heatmap) gets the
    % horizontal space; in 1D mode, col 2 expands ('1x') and col 3 hides.
    if is2D_now
        col2W = 0;     col3W = '1x';
    else
        col2W = '1x';  col3W = 0;
    end
    defCorrW = constants.LAYOUT_DEFAULTS.corrPanelW;
    if figW < 900
        if is2D_now, col4W = 140; else, col4W = 0; end
        widgets.analysisGL.ColumnWidth = {min(260, defCorrW), col2W, col3W, col4W};
    elseif figW < 1100
        widgets.analysisGL.ColumnWidth = {min(280, defCorrW), col2W, col3W, 180};
    end

    if is2D_now
        widgets.dataTablePanel.Visible = 'off';
    else
        widgets.dataTablePanel.Visible = 'on';
    end

end
