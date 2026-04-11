function appearance = resolveStyle(template, globalOverrides, ds, channelIdx)
%RESOLVESTYLE  Merge a template and sparse overrides into an effective style.
%
%   appearance = bosonPlotter.resolveStyle(template)
%   appearance = bosonPlotter.resolveStyle(template, globalOverrides)
%   appearance = bosonPlotter.resolveStyle(template, globalOverrides, ds)
%   appearance = bosonPlotter.resolveStyle(template, globalOverrides, ds, channelIdx)
%
%   Single choke point for the visual-style precedence chain used by every
%   BosonPlotter rendering path.  Lower layers supply defaults; higher
%   layers override individual fields.  Missing / empty fields at the
%   higher layers pass the lower value through unchanged, which is what
%   makes "tweak one thing about this dataset" possible without pinning
%   everything else.
%
%   PRECEDENCE (lowest → highest, last writer wins):
%
%       1. template           — from styles.template(name)
%       2. globalOverrides    — sparse struct from Plot Style dialog
%       3. ds.styleOverride   — sparse struct per-dataset
%       4. ds.channelStyles{channelIdx} — sparse struct per-Y-channel
%
%   The colormap palette is NOT handled here — callers that want a
%   colormap to override template.colors should do so after this call.
%
%   INPUTS:
%       template        — struct returned by styles.template() (required)
%       globalOverrides — sparse struct (optional, default: empty struct)
%       ds              — dataset struct (optional); if present and has
%                         .styleOverride field, its contents are applied
%       channelIdx      — 1-based Y channel index (optional); if present
%                         and ds.channelStyles{channelIdx} is a non-empty
%                         struct, its contents are applied last
%
%   OUTPUT:
%       appearance — fully-populated style struct with every field from
%                    the template, overlayed with any overrides present
%
%   EXAMPLES:
%       t = styles.template('screen');
%       a = bosonPlotter.resolveStyle(t);                    % template only
%       a = bosonPlotter.resolveStyle(t, struct('lineWidth', 2.0));
%       a = bosonPlotter.resolveStyle(t, [], ds, 2);         % per-channel
%
%   See also styles.template, bosonPlotter.userTemplates, bosonPlotter.renderPlot

    arguments
        template         (1,1) struct
        globalOverrides        = struct()
        ds                     = []
        channelIdx             = []
    end

    % ── Start from the template ──────────────────────────────────────────
    appearance = template;

    % ── Layer 2: global overrides (Plot Style dialog) ────────────────────
    if ~isempty(globalOverrides) && isstruct(globalOverrides)
        appearance = mergeSparse(appearance, globalOverrides);
    end

    % ── Layer 3: per-dataset overrides ───────────────────────────────────
    if ~isempty(ds) && isstruct(ds) && isfield(ds, 'styleOverride') && ...
       isstruct(ds.styleOverride)
        appearance = mergeSparse(appearance, ds.styleOverride);
    end

    % Migration shim: also honour legacy ds.color / ds.colorR if the new
    % styleOverride path didn't already set a colour.  This lets Phase A
    % ship without breaking existing sessions that only store ds.color.
    if ~isempty(ds) && isstruct(ds)
        if ~isfield(appearance, 'datasetColor') || isempty(appearance.datasetColor)
            if isfield(ds, 'color') && ~isempty(ds.color)
                appearance.datasetColor = ds.color;
            end
        end
        if ~isfield(appearance, 'datasetColorR') || isempty(appearance.datasetColorR)
            if isfield(ds, 'colorR') && ~isempty(ds.colorR)
                appearance.datasetColorR = ds.colorR;
            end
        end
    end

    % ── Layer 4: per-channel overrides ───────────────────────────────────
    if ~isempty(channelIdx) && ~isempty(ds) && isstruct(ds) && ...
       isfield(ds, 'channelStyles') && iscell(ds.channelStyles) && ...
       channelIdx >= 1 && channelIdx <= numel(ds.channelStyles)
        chStyle = ds.channelStyles{channelIdx};
        if ~isempty(chStyle) && isstruct(chStyle)
            appearance = mergeSparse(appearance, chStyle);
        end
    end

    % ── Normalise: ensure every required field exists ───────────────────
    % A template may omit some fields (older style structs); back-fill with
    % sensible defaults so the renderer never has to isfield() check.
    appearance = backfillDefaults(appearance);
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function base = mergeSparse(base, overlay)
%MERGESPARSE  Copy every non-empty field from overlay onto base.
%   Empty fields in the overlay are IGNORED (they don't clobber base).
%   This is what "sparse override" means — the overlay only mentions
%   fields it actually wants to change, and leaves the rest alone.
    if isempty(overlay) || ~isstruct(overlay), return; end
    fn = fieldnames(overlay);
    for k = 1:numel(fn)
        v = overlay.(fn{k});
        if isempty(v), continue; end     % sparse: skip empty entries
        base.(fn{k}) = v;
    end
end


function s = backfillDefaults(s)
%BACKFILLDEFAULTS  Ensure every visual field has a value.
%   Older style structs (from styles.default() or earlier saved sessions)
%   may not have every field the Phase A renderer expects.  Fill in
%   sensible defaults so renderPlot can read without isfield() guards.
    defaults = struct( ...
        'fontName',         'Helvetica', ...
        'fontSize',         13, ...
        'titleFontSize',    14, ...
        'legendFontSize',   11, ...
        'lineWidth',        1.0, ...
        'lineWidthThin',    0.8, ...
        'markerSize',       4.5, ...
        'markerShape',      'o', ...       % 'auto' cycles per-dataset
        'markerFaceMode',   'none', ...    % 'none' | 'auto' (match line)
        'lineStyle',        '-', ...       % 'auto' cycles per-dataset
        'alpha',            1.0, ...
        'tickDir',          'in', ...
        'tickLength',       [0.01 0.005], ...
        'boxOn',            true, ...
        'gridAlpha',        0.0, ...
        'minorTicks',       false, ...
        'legendBox',        false, ...
        'legendLocation',   'best', ...
        'legendFontWeight', 'normal' ...   % 'normal' | 'bold'
    );
    fn = fieldnames(defaults);
    for k = 1:numel(fn)
        if ~isfield(s, fn{k}) || isempty(s.(fn{k}))
            s.(fn{k}) = defaults.(fn{k});
        end
    end
    % Colors and datasetColor fields are allowed to stay empty — callers
    % handle them explicitly.  paletteOverride is distinct from colors:
    %   • colors          — template's built-in colour cycle (always set
    %                       by styles.template*)
    %   • paletteOverride — user-selected palette from the Plot Style
    %                       dialog; empty unless the user picked a
    %                       non-default palette (Phase G)
    if ~isfield(s, 'colors'),          s.colors          = []; end
    if ~isfield(s, 'paletteOverride'), s.paletteOverride = []; end
    if ~isfield(s, 'datasetColor'),    s.datasetColor    = []; end
    if ~isfield(s, 'datasetColorR'),   s.datasetColorR   = []; end
end
