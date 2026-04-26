function dir = detectResizeBorder(fig, panels)
%DETECTRESIZEBORDER  Identify which panel border (if any) the mouse is near.
%
% Syntax
%   dir = bosonPlotter.detectResizeBorder(fig, panels)
%
% Behaviour
%   Pure geometry check: consults `fig.CurrentPoint` and the pixel
%   bounds of the six resizable panels, returning a direction tag when
%   the cursor is within SNAP_PX of a draggable border.
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
    dir = '';
    try
        mp   = fig.CurrentPoint;                                  % [x y] from figure bottom-left
        aPos = getpixelposition(panels.analysisPanel, true);      % [l b w h] relative to figure

        % h_row12: top edge of the analysis panel (border between rows 1 & 2)
        borderY = aPos(2) + aPos(4);
        if abs(mp(2) - borderY) <= SNAP_PX && ...
           mp(1) >= aPos(1) && mp(1) <= aPos(1) + aPos(3)
            dir = 'h_row12'; return;
        end

        % Borders inside the analysis panel's y-band
        if mp(2) >= aPos(2) && mp(2) <= aPos(2) + aPos(4)

            % v_col12: right edge of corrections panel
            cPos    = getpixelposition(panels.corrPanel, true);
            borderX = cPos(1) + cPos(3);
            if abs(mp(1) - borderX) <= SNAP_PX
                dir = 'v_col12'; return;
            end

            % v_col23: left edge of savePanel (col 4 — always rightmost)
            spPos    = getpixelposition(panels.savePanel, true);
            borderX2 = spPos(1);
            if abs(mp(1) - borderX2) <= SNAP_PX
                dir = 'v_col23'; return;
            end
        end

        % Borders inside the content row (top half of figure)
        flPos = getpixelposition(panels.fileListPanel, true);
        cpPos = getpixelposition(panels.ctrlPanel, true);
        if mp(2) >= flPos(2) && mp(2) <= flPos(2) + flPos(4)

            % v_content12: right edge of file list panel
            borderX3 = flPos(1) + flPos(3);
            if abs(mp(1) - borderX3) <= SNAP_PX
                dir = 'v_content12'; return;
            end

            % v_content23: right edge of controls panel
            borderX4 = cpPos(1) + cpPos(3);
            if abs(mp(1) - borderX4) <= SNAP_PX
                dir = 'v_content23'; return;
            end
        end
    catch
        % getpixelposition may throw on some MATLAB versions — silently skip
    end
end
