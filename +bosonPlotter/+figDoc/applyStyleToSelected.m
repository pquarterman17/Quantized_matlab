function applyStyleToSelected(datasets, sourceIdx, targetIndices)
%APPLYSTYLETOSELECTED  Copy style from source figDoc to selected datasets.
%
%   bosonPlotter.figDoc.applyStyleToSelected(datasets, sourceIdx, targetIndices)
%
%   Like applyStyleToAll but only targets the specified indices.

    if sourceIdx < 1 || sourceIdx > numel(datasets), return; end
    src = datasets{sourceIdx};
    if ~isfield(src, 'figDoc') || isempty(src.figDoc), return; end
    srcModel = src.figDoc;

    styleFields = {'xScale','yScale','fontSize','fontName','gridOn', ...
        'minorTicks','tickDir','boxOn','legendVisible','legendLocation', ...
        'legendOrientation','legendFontSize','legendColumns','margins', ...
        'labelFontWeight'};

    for k = targetIndices(:)'
        if k == sourceIdx || k < 1 || k > numel(datasets), continue; end
        if ~isfield(datasets{k}, 'figDoc') || isempty(datasets{k}.figDoc)
            datasets{k}.figDoc = bosonPlotter.figDoc.FigDocModel();
        end
        tgt = datasets{k}.figDoc;
        for f = 1:numel(styleFields)
            fn = styleFields{f};
            if isprop(tgt, fn)
                tgt.(fn) = srcModel.(fn);
            end
        end
        tgt.markDirty();
    end
end
