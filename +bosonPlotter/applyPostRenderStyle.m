function applyPostRenderStyle(targetAx, appearance)
%APPLYPOSTRENDERSTYLE  Post-draw axes-level style pass for BosonPlotter.
%
%   bosonPlotter.applyPostRenderStyle(ax, appearance)
%
%   Applied after all plot/errorbar/line calls have finished drawing.
%   Handles axes-wide / legend-wide style fields that apply to the
%   whole axes, not per-dataset:
%
%       • legendFontWeight — 'normal' or 'bold' on the Legend object
%
%   Line-level fields (alpha, markerFaceMode) are NOT handled here —
%   they must be applied per-dataset inside renderPlot's loop so that
%   ds.styleOverride / channelStyles{k} can specify different values
%   for different datasets.  See bosonPlotter.applyAlphaToLine and
%   bosonPlotter.applyFaceModeToLine.
%
%   INPUTS:
%       targetAx    — axes handle
%       appearance  — resolved style struct (the GLOBAL one, since
%                     legend font weight is an axes-wide property)

    arguments
        targetAx     matlab.graphics.axis.Axes
        appearance   struct
    end

    if ~isvalid(targetAx), return; end

    legendWeight = '';
    if isfield(appearance, 'legendFontWeight') && ~isempty(appearance.legendFontWeight)
        legendWeight = char(appearance.legendFontWeight);
    end

    if ~isempty(legendWeight)
        try
            lgd = targetAx.Legend;
            if ~isempty(lgd) && isvalid(lgd)
                lgd.FontWeight = legendWeight;
            end
        catch
        end
    end
end
