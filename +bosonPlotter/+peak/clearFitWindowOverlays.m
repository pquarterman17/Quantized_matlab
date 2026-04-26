function clearFitWindowOverlays(ax)
%CLEARFITWINDOWOVERLAYS  Delete all rectangles tagged 'peakFitWindow' on ax.
    if ~isvalid(ax), return; end
    overlays = findobj(ax, 'Tag', 'peakFitWindow');
    if ~isempty(overlays), delete(overlays); end
end
