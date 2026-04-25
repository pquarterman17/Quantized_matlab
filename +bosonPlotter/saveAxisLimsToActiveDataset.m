function saveAxisLimsToActiveDataset(appData, ui, ax)
%SAVEAXISLIMSTOACTIVEDATASET  Persist axis limits + plot-view state.
%
% Syntax
%   bosonPlotter.saveAxisLimsToActiveDataset(appData, ui, ax)
%
% Called before switching datasets so each one remembers its own zoom,
% axis scale (linear/log), grid/direction, and 2D map state. Reads from
% live axes so user changes made via context menu (grid/invert) — which
% don't update a dropdown — are still captured.
%
% Inputs
%   appData - bosonPlotter.AppState handle (mutates datasets{idx}.axLims
%             and .plotState)
%   ui      - widget struct, must include the X/Y/Y2 limit edit fields
%             (efXMin/efXMax/efXStep, efYMin/efYMax/efYStep, efY2Min/
%             efY2Max/efY2Step), scale dropdowns (ddScaleX/Y/Y2), and
%             2D map widgets (ddMap2DCmap, ddMap2DScale, efMap2DCMin,
%             efMap2DCMax)
%   ax      - main axes handle (XGrid/YGrid/XDir/YDir read for plotState)

    if appData.activeIdx < 1 || isempty(appData.datasets), return; end

    lims.xMin   = ui.efXMin.Value;
    lims.xMax   = ui.efXMax.Value;
    lims.xStep  = ui.efXStep.Value;
    lims.yMin   = ui.efYMin.Value;
    lims.yMax   = ui.efYMax.Value;
    lims.yStep  = ui.efYStep.Value;
    lims.y2Min  = ui.efY2Min.Value;
    lims.y2Max  = ui.efY2Max.Value;
    lims.y2Step = ui.efY2Step.Value;
    appData.datasets{appData.activeIdx}.axLims = lims;

    ps = struct();
    ps.xScale  = ui.ddScaleX.Value;
    ps.yScale  = ui.ddScaleY.Value;
    ps.y2Scale = ui.ddScaleY2.Value;
    if ~isempty(ax) && isvalid(ax)
        ps.gridX = ax.XGrid;
        ps.gridY = ax.YGrid;
        ps.xDir  = ax.XDir;
        ps.yDir  = ax.YDir;
    end
    if ~isempty(ui.ddMap2DCmap) && isvalid(ui.ddMap2DCmap)
        ps.map2DCmap  = ui.ddMap2DCmap.Value;
        ps.map2DScale = ui.ddMap2DScale.Value;
        ps.map2DCMin  = ui.efMap2DCMin.Value;
        ps.map2DCMax  = ui.efMap2DCMax.Value;
    end
    appData.datasets{appData.activeIdx}.plotState = ps;
end
