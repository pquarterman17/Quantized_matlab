function fields = datasetMetaFields(ds)
%DATASETMETAFIELDS  Extract groupable metadata values from a dataset.
%
% Syntax
%   fields = bosonPlotter.datasetMetaFields(ds)
%
% Returns a struct mapping a human-readable key (e.g. 'Temperature',
% 'Field') to a short formatted value string (e.g. '300 K', '5000 Oe') for
% metadata that is useful for labelling / grouping "like" datasets.  Only
% fields actually present with a usable scalar value are included; the
% struct is empty when nothing groupable is found.
%
% Used by the Legend Editor's "Fill from metadata" tool.  Intended to be the
% shared source for the (deferred) CSV "Comments / grouping" row too — keep
% the candidate list here so both features stay consistent.
%
% Inputs
%   ds - dataset struct (reads ds.data.metadata and .parserSpecific)
%
% Output
%   fields - scalar struct; fieldnames are display keys, values are char.

    fields = struct();
    if ~isfield(ds, 'data') || ~isstruct(ds.data) || ...
       ~isfield(ds.data, 'metadata') || ~isstruct(ds.data.metadata)
        return;
    end
    meta = ds.data.metadata;

    % Candidate metadata fields: {display key, name-match patterns, unit}.
    % Patterns are matched case-insensitively against metadata field names.
    candidates = {
        'Temperature', {'temperature', 'temp', 'setpointtemp'}, 'K'
        'Field',       {'field', 'magneticfield', 'happlied', 'bfield'}, 'Oe'
        'Angle',       {'angle', 'omega', 'phi', 'chi'}, char(176)
        'Frequency',   {'frequency', 'freq'}, 'Hz'
        'Power',       {'power'}, 'W'
        'Voltage',     {'voltage', 'bias'}, 'V'
        'Current',     {'current'}, 'A'
        'Pressure',    {'pressure'}, 'Torr'
        'Wavelength',  {'wavelength', 'lambda'}, char(197) };

    % Search both the top-level metadata and parserSpecific sub-struct.
    sources = {meta};
    if isfield(meta, 'parserSpecific') && isstruct(meta.parserSpecific)
        sources{end+1} = meta.parserSpecific;
    end

    for ci = 1:size(candidates, 1)
        key      = candidates{ci, 1};
        patterns = candidates{ci, 2};
        unit     = candidates{ci, 3};
        valStr   = findFieldValue(sources, patterns, unit);
        if ~isempty(valStr)
            fields.(key) = valStr;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function valStr = findFieldValue(sources, patterns, unit)
%FINDFIELDVALUE  First metadata field whose name matches a pattern and whose
%   value is a usable scalar number or short string; formatted with unit.
    valStr = '';
    for si = 1:numel(sources)
        s  = sources{si};
        fn = fieldnames(s);
        for fi = 1:numel(fn)
            nameLC = lower(fn{fi});
            if ~anyMatch(nameLC, patterns), continue; end
            v = s.(fn{fi});
            if isnumeric(v) && isscalar(v) && isfinite(v)
                if ~isempty(unit)
                    valStr = sprintf('%g %s', v, unit);
                else
                    valStr = sprintf('%g', v);
                end
                return;
            elseif (ischar(v) || isstring(v)) && strlength(string(v)) > 0 ...
                    && strlength(string(v)) <= 24
                valStr = char(v);
                return;
            end
        end
    end
end

function tf = anyMatch(nameLC, patterns)
%ANYMATCH  True if nameLC contains any of the pattern substrings.
    tf = false;
    for k = 1:numel(patterns)
        if contains(nameLC, patterns{k})
            tf = true; return;
        end
    end
end
