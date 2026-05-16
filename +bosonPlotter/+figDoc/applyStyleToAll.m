function applyStyleToAll(datasets, sourceIdx)
%APPLYSTYLETOALL  Copy style fields from one dataset's figDoc to all others.
%
%   bosonPlotter.figDoc.applyStyleToAll(datasets, sourceIdx)
%
%   Copies visual styling (fonts, scales, legend, grid, margins) from
%   the source dataset's FigDocModel to all other datasets. Does NOT
%   copy annotations or traceStyles (those are dataset-specific).

    if sourceIdx < 1 || sourceIdx > numel(datasets), return; end
    src = datasets{sourceIdx};
    if ~isfield(src, 'figDoc') || isempty(src.figDoc), return; end
    srcModel = src.figDoc;

    styleFields = {'xScale','yScale','fontSize','fontName','gridOn', ...
        'minorTicks','tickDir','boxOn','legendVisible','legendLocation', ...
        'legendOrientation','legendFontSize','legendColumns','margins'};

    for k = 1:numel(datasets)
        if k == sourceIdx, continue; end
        if ~isfield(datasets{k}, 'figDoc') || isempty(datasets{k}.figDoc)
            continue;
        end
        tgt = datasets{k}.figDoc;
        for f = 1:numel(styleFields)
            fn = styleFields{f};
            tgt.(fn) = srcModel.(fn);
        end
        tgt.markDirty();
    end
end
