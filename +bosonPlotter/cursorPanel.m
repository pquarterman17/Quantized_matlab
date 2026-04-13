function panel = cursorPanel(parentGL, row, ax, getAppDataFn)
%CURSORPANEL  Create and return a docked cursor-readout panel.
%
%   Syntax
%     panel = bosonPlotter.cursorPanel(parentGL, row, ax, getAppDataFn)
%
%   Inputs
%     parentGL     — uigridlayout that owns the panel row (axGL in BosonPlotter)
%     row          — integer row index inside parentGL to place the panel
%     ax           — uiaxes whose coordinates the panel will display
%     getAppDataFn — @() function handle that returns the live appData struct.
%                    The panel reads appData.datasets, appData.activeIdx,
%                    appData.cursorPt1, and appData.cursorActive from this.
%
%   Outputs
%     panel — struct with fields:
%       .container — uipanel handle (parent is parentGL)
%       .lblLeft   — uilabel showing  "X: <val>  Y: <val>"
%       .lblRight  — uilabel showing  "DX: <val>  DY: <val>  |  Dataset: <name>"
%       .update    — @(x,y) function handle; call from onMouseHover to refresh
%                    the readout.  Accepts empty/NaN xy to show the dash state.
%
%   Notes
%     The panel is 22 px tall, placed in the parentGL row specified by the
%     caller.  Text uses Courier New for column-aligned readout.
%
%     The caller is responsible for passing valid coordinates each hover tick.
%     The panel will not fire its own WindowButtonMotionFcn — it relies on
%     BosonPlotter's existing onMouseHover for update triggers.
%
%     When no dataset is loaded, both labels display "—".
%
%     When appData.cursorPt1 is set (first point of a two-click delta
%     measurement), the right label shows DX/DY from that pinned point.
%
%   Examples
%     panel = bosonPlotter.cursorPanel(axGL, 3, ax, @() appData);
%     % In onMouseHover:
%     panel.update(x, y);

% ════════════════════════════════════════════════════════════════════════════

    % ── Container ────────────────────────────────────────────────────────
    container = uipanel(parentGL, ...
        'BorderType',       'none', ...
        'BackgroundColor',  [0.13 0.13 0.13]);
    container.Layout.Row    = row;
    container.Layout.Column = 1;

    panelGL = uigridlayout(container, [1 2], ...
        'Padding',        [2 1 2 1], ...
        'ColumnSpacing',  4, ...
        'ColumnWidth',    {'1x', '2x'}, ...
        'RowHeight',      {20});

    MONO = 'Courier New';
    FSIZ = 10;
    FCOL = [0.70 0.70 0.70];

    lblLeft = uilabel(panelGL, ...
        'Text',              '--', ...
        'FontName',          MONO, ...
        'FontSize',          FSIZ, ...
        'FontColor',         FCOL, ...
        'HorizontalAlignment','left', ...
        'Interpreter',       'none');
    lblLeft.Layout.Column = 1;

    lblRight = uilabel(panelGL, ...
        'Text',              '', ...
        'FontName',          MONO, ...
        'FontSize',          FSIZ, ...
        'FontColor',         [0.50 0.70 0.50], ...
        'HorizontalAlignment','right', ...
        'Interpreter',       'none');
    lblRight.Layout.Column = 2;

    % ── Public update handle ──────────────────────────────────────────────
    panel = struct();
    panel.container = container;
    panel.lblLeft   = lblLeft;
    panel.lblRight  = lblRight;
    panel.update    = @updateReadout;

    % ── Inner update function ─────────────────────────────────────────────
    function updateReadout(x, y)
    %UPDATEREADOUT  Refresh the cursor panel from the current hover point.
    %   x, y — doubles (axes coordinates); pass [] or NaN to show dash state.
        if ~isgraphics(lblLeft) || ~isgraphics(lblRight), return; end

        hasXY = ~isempty(x) && ~isempty(y) && isfinite(x) && isfinite(y);

        if ~hasXY
            lblLeft.Text  = '--';
            lblRight.Text = '';
            return;
        end

        % Left: live coordinate
        lblLeft.Text = sprintf('X: %-.5g    Y: %-.5g', x, y);

        % Right: delta from pinned pt1 + dataset name
        try
            appData = getAppDataFn();
        catch
            lblRight.Text = '';
            return;
        end

        rightParts = {};

        % Delta from first cursor click (cursorPt1)
        if isfield(appData, 'cursorPt1') && ...
                ~isempty(appData.cursorPt1) && ...
                numel(appData.cursorPt1) == 2 && ...
                all(isfinite(appData.cursorPt1))
            dx = x - appData.cursorPt1(1);
            dy = y - appData.cursorPt1(2);
            rightParts{end+1} = sprintf('DX: %+-.5g    DY: %+-.5g', dx, dy);
        end

        % Dataset name
        if isfield(appData, 'datasets') && isfield(appData, 'activeIdx') && ...
                appData.activeIdx >= 1 && ...
                appData.activeIdx <= numel(appData.datasets)
            ds = appData.datasets{appData.activeIdx};
            dsName = '';
            if isfield(ds, 'name') && ~isempty(ds.name)
                dsName = ds.name;
            elseif isfield(ds, 'data') && isfield(ds.data, 'metadata') && ...
                    isfield(ds.data.metadata, 'filepath') && ...
                    ~isempty(ds.data.metadata.filepath)
                [~, fn, ext] = fileparts(ds.data.metadata.filepath);
                dsName = [fn ext];
            end
            if ~isempty(dsName)
                rightParts{end+1} = dsName;
            end
        end

        if isempty(rightParts)
            lblRight.Text = '';
        else
            lblRight.Text = strjoin(rightParts, '  |  ');
        end
    end
end
