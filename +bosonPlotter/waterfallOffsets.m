function levels = waterfallOffsets(datasets, idxOrder)
%WATERFALLOFFSETS  0-based waterfall level for each dataset in idxOrder.
%
% Syntax
%   levels = bosonPlotter.waterfallOffsets(datasets, idxOrder)
%
% Returns the waterfall stacking level (0, 1, 2, ...) for each entry of
% idxOrder, matching renderPlot's wfGroupIdx logic: levels are sequential
% in plot order, EXCEPT neutron cross-sections from the same measurement
% (identical neutronBaseName) which share one level so they stack together.
%
% Inputs
%   datasets - cell array of dataset structs (appData.datasets)
%   idxOrder - vector of dataset indices in the order they are plotted/exported
%
% Output
%   levels - column vector, one 0-based level per idxOrder element.  Combine
%            with the spacing: additive offset = level*spacing, or
%            multiplicative (log Y) factor = spacing^level.

    n = numel(idxOrder);
    levels = (0:n-1).';
    if n < 2, return; end

    anyNeutron = false;
    baseNames  = cell(n, 1);
    for i = 1:n
        ds = datasets{idxOrder(i)};
        if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
            anyNeutron   = true;
            baseNames{i} = neutronBaseName(ds.filepath);
        else
            baseNames{i} = sprintf('__unique_%d__', i);
        end
    end
    if anyNeutron
        [~, ~, g] = unique(baseNames, 'stable');
        levels = g - 1;   % 0-based, grouped
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers (mirror the definitions in saveConsolidatedNeutronCSV.m)
% ════════════════════════════════════════════════════════════════════════

function tf = isNeutronParser(pName)
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end

function baseName = neutronBaseName(filepath)
    [~, fn, ~] = fileparts(filepath);
    fn = regexprep(fn, '[_-](refl|pnr)$', '', 'ignorecase');
    fn = regexprep(fn, '[_-](NSF|SF)$',   '', 'ignorecase');
    fn = regexprep(fn, '[_-][a-z]$',       '', 'ignorecase');
    baseName = fn;
end
