function onArcIntButton(appData, fig, callbacks)
%ONARCINTBUTTON  Open arc-integration dialog and extract an I(|Q|) profile.
%
% Syntax
%   bosonPlotter.onArcIntButton(appData, fig, callbacks)
%
% Behaviour
%   Guards on an active 2D dataset with Q-space coordinates
%   (`parserSpecific.map2D.Qx`), then pops a modal `uifigure` dialog
%   with six parameter controls:
%     Q min / Q max   — radial integration bounds (auto-filled from data)
%     Num bins        — number of radial bins (default: ~half of the
%                        larger map dimension, clipped to 20-100)
%     Sector min/max  — azimuthal angular range in degrees (0-360,
%                        CCW from +Qx axis)
%     Integration     — 'Sum' (total counts) or 'Mean' (per-pixel average)
%   Pressing `Integrate` closes the dialog and calls
%   `callbacks.extract2DArcIntegral(params)` with the gathered settings.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig       - Main figure handle (uialert parent)
%   callbacks - Struct of function handles:
%                 .is2DDataset(ds) -> logical
%                 .extract2DArcIntegral(params)

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end
    ds = appData.datasets{appData.activeIdx};
    if ~callbacks.is2DDataset(ds), return; end
    map = ds.data.metadata.parserSpecific.map2D;
    if ~isfield(map, 'Qx')
        bosonPlotter.quietAlert(fig, 'Arc integration requires Q-space coordinates (wavelength must be in the file metadata).', ...
            'No Q-space Data');
        return;
    end

    % Compute Q-radius range for defaults
    Qrad = hypot(map.Qx, map.Qz);
    qMin = min(Qrad(:));  qMax = max(Qrad(:));
    nDefault = min(100, max(20, round(max(size(map.intensity)) / 2)));

    % Build dialog
    dlgFig = uifigure('Name', 'Arc Integration', ...
        'Position', [100 100 320 280], 'Resize', 'off');
    dlgFig.CloseRequestFcn = @(~,~) delete(dlgFig);
    scr = get(0, 'ScreenSize');
    dlgFig.Position(1) = round((scr(3) - dlgFig.Position(3)) / 2);
    dlgFig.Position(2) = round((scr(4) - dlgFig.Position(4)) / 2);
    dlgGL = uigridlayout(dlgFig, [7 2], ...
        'RowHeight',    {22, 22, 22, 22, 22, 22, 30}, ...
        'ColumnWidth',  {120, '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    uilabel(dlgGL, 'Text', 'Q min:', 'HorizontalAlignment', 'right');
    efQMin = uieditfield(dlgGL, 'numeric', 'Value', qMin, ...
        'Limits', [0 Inf], 'ValueDisplayFormat', '%.4f', ...
        'Tooltip', sprintf('Minimum |Q| (%s^{-1})', char(197)));

    uilabel(dlgGL, 'Text', 'Q max:', 'HorizontalAlignment', 'right');
    efQMax = uieditfield(dlgGL, 'numeric', 'Value', qMax, ...
        'Limits', [0 Inf], 'ValueDisplayFormat', '%.4f', ...
        'Tooltip', sprintf('Maximum |Q| (%s^{-1})', char(197)));

    uilabel(dlgGL, 'Text', 'Num bins:', 'HorizontalAlignment', 'right');
    efNBins = uieditfield(dlgGL, 'numeric', 'Value', nDefault, ...
        'Limits', [5 2000], 'Tooltip', 'Number of radial Q bins');

    uilabel(dlgGL, 'Text', 'Sector min (deg):', 'HorizontalAlignment', 'right');
    efSectorMin = uieditfield(dlgGL, 'numeric', 'Value', 0, ...
        'Limits', [-180 360], 'Tooltip', 'Azimuthal start angle (0 = +Qx axis, CCW)');

    uilabel(dlgGL, 'Text', 'Sector max (deg):', 'HorizontalAlignment', 'right');
    efSectorMax = uieditfield(dlgGL, 'numeric', 'Value', 360, ...
        'Limits', [-180 360], 'Tooltip', 'Azimuthal end angle (360 = full circle)');

    uilabel(dlgGL, 'Text', 'Integration:', 'HorizontalAlignment', 'right');
    ddMode = uidropdown(dlgGL, 'Items', {'Sum', 'Mean'}, 'Value', 'Sum', ...
        'Tooltip', 'Sum: total counts per bin. Mean: average per contributing pixel.');

    btnGo = uibutton(dlgGL, 'Text', 'Integrate', ...
        'BackgroundColor', [0.40 0.25 0.55], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doArcInt(dlgFig, ...
            efQMin, efQMax, efNBins, efSectorMin, efSectorMax, ddMode, ...
            callbacks.extract2DArcIntegral));
    btnGo.Layout.Row = 7; btnGo.Layout.Column = [1 2];
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Integrate button handler
% ════════════════════════════════════════════════════════════════════════

function doArcInt(dlgFig, efQMin, efQMax, efNBins, efSectorMin, efSectorMax, ddMode, extractFn)
    params.qMin      = efQMin.Value;
    params.qMax      = efQMax.Value;
    params.nBins     = round(efNBins.Value);
    params.sectorMin = efSectorMin.Value;
    params.sectorMax = efSectorMax.Value;
    params.mode      = ddMode.Value;
    delete(dlgFig);
    extractFn(params);
end
