function aOut = applyDsOverride(aBase, ds, channelIdx)
%APPLYDSOVERRIDE  Layer a dataset's per-dataset / per-channel overrides.
%
%   aDs = bosonPlotter.applyDsOverride(a, ds)
%   aDs = bosonPlotter.applyDsOverride(a, ds, channelIdx)
%
%   Returns a NEW appearance struct with ds.styleOverride and
%   optionally ds.channelStyles{channelIdx} merged on top of the input
%   struct.  This is the per-iteration complement to the upstream
%   resolveStyle call — resolveStyle already merged template + global
%   into `aBase`, and this helper adds the lower (higher-priority)
%   layers of the cascade for a specific dataset/channel.
%
%   The cascade documented in resolveStyle.m:
%     template < globalOverrides < ds.styleOverride < ds.channelStyles{k}
%
%   `aBase` is assumed to already include the first two layers.  We
%   apply the last two here.  Sparse semantics: empty fields in the
%   override are ignored (they pass through to the base value).
%
%   INPUTS:
%       aBase       — struct (typically the pre-merged global appearance)
%       ds          — dataset struct, may have .styleOverride and/or
%                     .channelStyles{k}
%       channelIdx  — optional 1-based Y channel index
%
%   OUTPUT:
%       aOut — a new struct (aBase is not modified — MATLAB value
%              semantics)

    arguments
        aBase       (1,1) struct
        ds
        channelIdx        = []
    end

    aOut = aBase;
    if isempty(ds) || ~isstruct(ds), return; end

    % Layer 3: per-dataset overrides
    if isfield(ds, 'styleOverride') && isstruct(ds.styleOverride)
        aOut = mergeSparse(aOut, ds.styleOverride);
    end

    % Layer 4: per-channel overrides
    if ~isempty(channelIdx) && isfield(ds, 'channelStyles') && ...
       iscell(ds.channelStyles) && channelIdx >= 1 && ...
       channelIdx <= numel(ds.channelStyles)
        chStyle = ds.channelStyles{channelIdx};
        if ~isempty(chStyle) && isstruct(chStyle)
            aOut = mergeSparse(aOut, chStyle);
        end
    end
end


function base = mergeSparse(base, overlay)
%MERGESPARSE  Copy every non-empty field from overlay onto base.
%   Same semantics as the helper inside resolveStyle.m — kept as a
%   private copy here so applyDsOverride stays self-contained.
    if isempty(overlay) || ~isstruct(overlay), return; end
    fn = fieldnames(overlay);
    for k = 1:numel(fn)
        v = overlay.(fn{k});
        if isempty(v), continue; end
        base.(fn{k}) = v;
    end
end
