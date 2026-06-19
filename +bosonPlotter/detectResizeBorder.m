function dir = detectResizeBorder(fig, panels, appData)
%DETECTRESIZEBORDER  Identify which panel border (if any) the mouse is near.
%
% Syntax
%   dir = bosonPlotter.detectResizeBorder(fig, panels)
%   dir = bosonPlotter.detectResizeBorder(fig, panels, appData)
%
% Behaviour
%   Geometry check: consults `fig.CurrentPoint` and the pixel bounds of
%   the resizable panels, returning a direction tag when the cursor is
%   within SNAP_PX of a draggable border.
%
%   Performance: each `getpixelposition(panel, true)` call walks the
%   container hierarchy, which is comparatively expensive in uifigure.
%   Because this runs on every mouse-move (via onMouseHover), the panel
%   pixel bounds are cached on the AppState handle and only recomputed
%   when stale (older than TTL) or explicitly invalidated (figure resize,
%   panel-drag start, 1D/2D mode switch).  Pass `appData` to enable the
%   cache; omit it for a one-off uncached query.
%
%   Returned direction tags:
%     'h_row12'      — horizontal border between content row (1) and
%                      analysis row (2)
%     'v_col12'      — vertical border between corrections col (1) and
%                      data table col (2)
%     'v_col23'      — vertical border between data table col (2) and
%                      save/export col (3)
%     'v_content12'  — vertical border between file list and controls
%                      (top row)
%     'v_content23'  — vertical border between controls and preview
%                      (top row)
%     ''             — not near any known border
%
%   Silent-catch: `getpixelposition` throws on some MATLAB versions, so
%   the body is wrapped in try/catch with an empty fallback (arrow
%   cursor, no resize).
%
% Inputs
%   fig     - Main BosonPlotter figure handle
%   panels  - Struct of panel handles:
%               .fileListPanel, .ctrlPanel, .corrPanel,
%               .savePanel, .analysisPanel, .dataTablePanel

    SNAP_PX = 5;
    PANEL_BOUNDS_TTL = 0.5;   % seconds before cached bounds are recomputed
    dir = '';

    useCache = nargin >= 3 && ~isempty(appData) && isa(appData, 'handle');
    try
        mp = fig.CurrentPoint;                                    % [x y] from figure bottom-left

        % ── Resolve the four panel bounds (cached when appData given) ──
        % b.analysis/.corr/.save/.fileList/.ctrl are [l b w h] relative
        % to the figure.  Recompute only when the cache is empty, stale,
        % or has been explicitly invalidated by a layout change.
        b = [];
        if useCache
            stale = appData.panelBoundsCacheTic == 0 || ...
                    isempty(fieldnames(appData.panelBoundsCache)) || ...
                    toc(appData.panelBoundsCacheTic) > PANEL_BOUNDS_TTL;
            if ~stale
                b = appData.panelBoundsCache;
            end
        end
        if isempty(b)
            b.analysis = getpixelposition(panels.analysisPanel, true);
            b.corr     = getpixelposition(panels.corrPanel,     true);
            b.save     = getpixelposition(panels.savePanel,     true);
            b.fileList = getpixelposition(panels.fileListPanel, true);
            b.ctrl     = getpixelposition(panels.ctrlPanel,     true);
            if useCache
                appData.panelBoundsCache    = b;
                appData.panelBoundsCacheTic = tic;
            end
        end

        aPos = b.analysis;
        % h_row12: top edge of the analysis panel (border between rows 1 & 2)
        borderY = aPos(2) + aPos(4);
        if abs(mp(2) - borderY) <= SNAP_PX && ...
           mp(1) >= aPos(1) && mp(1) <= aPos(1) + aPos(3)
            dir = 'h_row12'; return;
        end

        % Borders inside the analysis panel's y-band
        if mp(2) >= aPos(2) && mp(2) <= aPos(2) + aPos(4)
            % v_col12: right edge of corrections panel
            borderX = b.corr(1) + b.corr(3);
            if abs(mp(1) - borderX) <= SNAP_PX
                dir = 'v_col12'; return;
            end
            % v_col23: left edge of savePanel (col 4 — always rightmost)
            if abs(mp(1) - b.save(1)) <= SNAP_PX
                dir = 'v_col23'; return;
            end
        end

        % Borders inside the content row (top half of figure)
        flPos = b.fileList;
        if mp(2) >= flPos(2) && mp(2) <= flPos(2) + flPos(4)
            % v_content12: right edge of file list panel
            if abs(mp(1) - (flPos(1) + flPos(3))) <= SNAP_PX
                dir = 'v_content12'; return;
            end
            % v_content23: right edge of controls panel
            if abs(mp(1) - (b.ctrl(1) + b.ctrl(3))) <= SNAP_PX
                dir = 'v_content23'; return;
            end
        end
    catch
        % getpixelposition may throw on some MATLAB versions — silently skip
    end
end
