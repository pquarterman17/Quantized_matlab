function dmask = buildDisplayMask(ds)
%BUILDDISPLAYMASK  Return logical mask mapped to corrected/displayed data.
%   Translates ds.mask through X-trim so it aligns with the displayed data
%   length. Returns an all-true mask if ds has no mask field or it's all-true.
    if ~isfield(ds, 'mask') || isempty(ds.mask) || all(ds.mask)
        if ~isempty(ds.corrData)
            d = ds.corrData;
        else
            d = ds.data;
        end
        dmask = true(size(d.time));
        return;
    end
    if ~isempty(ds.corrData)
        nRaw  = numel(ds.data.time);
        keepM = true(nRaw, 1);
        if ~isdatetime(ds.data.time)
            tVM = double(ds.data.time);
            if isfield(ds, 'xTrimMin'), trimMin = ds.xTrimMin; else, trimMin = NaN; end
            if isfield(ds, 'xTrimMax'), trimMax = ds.xTrimMax; else, trimMax = NaN; end
            if ~isnan(trimMin), keepM = keepM & tVM >= trimMin; end
            if ~isnan(trimMax), keepM = keepM & tVM <= trimMax; end
        end
        dmask = ds.mask(keepM);
    else
        dmask = ds.mask;
    end
end
