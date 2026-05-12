function roiAnalysis(datasets, activeIdx, mainAx, options)
%ROIANALYSIS  Interactive region-of-interest analysis gadget.
%
%   Syntax:
%       bosonPlotter.roiAnalysis(datasets, activeIdx, mainAx)
%       bosonPlotter.roiAnalysis(datasets, activeIdx, mainAx, 'StatusFcn', fcn)
%
%   Opens a control panel and enables click-to-define ROI on the main
%   axes.  Within the ROI, computes: integral, mean, std, min, max,
%   N points, and FWHM (if peak-like).  Results update live as the
%   ROI bounds change.
%
%   Workflow:
%     1. Drag the blue (left) or red (right) dashed cursor on the
%        main axes, or click "Set Region" to define the x-range by
%        clicking two points, or type bounds directly in the X min /
%        X max fields
%     2. Statistics appear in the panel and are overlaid on the plot
%     3. "Copy Stats" copies the results to clipboard
%     4. "Export Region" extracts the ROI data as a new dataset
%
%   Inputs:
%       datasets    — cell array of dataset structs
%       activeIdx   — index of active dataset
%       mainAx      — handle to main BosonPlotter axes
%
%   Options:
%       StatusFcn    — function_handle for status messages
%       ButtonColors — struct with .primary, .tool, .fg
%       ExportCallback — function_handle called with (dataStruct) to load
%                        extracted region as a new dataset

arguments
    datasets   cell
    activeIdx  double
    mainAx
    options.StatusFcn      function_handle = @(~) []
    options.ButtonColors   struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
    options.ExportCallback function_handle = function_handle.empty
    options.Appearance     struct          = bosonPlotter.resolveStyle(styles.template('screen'))
end

% ════════════════════════════════════════════════════════════════════════
% Resolve active dataset
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('bosonPlotter:roiAnalysis:noDataset', 'No valid dataset.');
end

ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end

xData  = plotD.time;
labels = plotD.labels;

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% ════════════════════════════════════════════════════════════════════════
% Build control panel (small floating window)
% ════════════════════════════════════════════════════════════════════════

roiFig = uifigure('Name', 'ROI Analysis', ...
    'Position', [300 200 380 420], 'Resize', 'on');

rootGL = uigridlayout(roiFig, [5 1], ...
    'RowHeight', {56, 30, '1x', 36, 28}, ...
    'Padding', [10 8 10 8], 'RowSpacing', 6);

% ── Row 1: Region controls ───────────────────────────────────────────
topGL = uigridlayout(rootGL, [2 4], ...
    'RowHeight', {24, 24}, ...
    'ColumnWidth', {55, '1x', 55, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
topGL.Layout.Row = 1;

uilabel(topGL, 'Text', 'X min:', 'HorizontalAlignment', 'right');
efXmin = uieditfield(topGL, 'numeric', 'Value', min(xData), ...
    'ValueChangedFcn', @(~,~) updateROI());

uilabel(topGL, 'Text', 'X max:', 'HorizontalAlignment', 'right');
efXmax = uieditfield(topGL, 'numeric', 'Value', max(xData), ...
    'ValueChangedFcn', @(~,~) updateROI());

uilabel(topGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right');
ddCh = uidropdown(topGL, 'Items', labels, ...
    'ItemsData', 1:numel(labels), 'Value', 1, ...
    'ValueChangedFcn', @(~,~) updateROI());
ddCh.Layout.Row = 2; ddCh.Layout.Column = 2;

uibutton(topGL, 'Text', 'Set Region', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontSize', 10, ...
    'Tooltip', 'Click two points on the plot to set region (or drag the dashed cursors)', ...
    'ButtonPushedFcn', @(~,~) startRegionPick());
% Position in row 2, columns 3-4
topGL.Children(end).Layout.Row = 2;
topGL.Children(end).Layout.Column = [3 4];

% ── Row 2: Title ─────────────────────────────────────────────────────
lblTitle = uilabel(rootGL, 'Text', 'Select a region to analyze', ...
    'FontWeight', 'bold', 'FontSize', 11);
lblTitle.Layout.Row = 2;

% ── Row 3: Stats display ────────────────────────────────────────────
statsArea = uitextarea(rootGL, 'Editable', 'off', ...
    'FontName', 'Consolas', 'FontSize', 10, ...
    'Value', {'Click "Set Region" or enter X bounds above.'});
statsArea.Layout.Row = 3;

% ── Row 4: Action buttons ───────────────────────────────────────────
btnGL = uigridlayout(rootGL, [1 3], ...
    'ColumnWidth', {'1x', '1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
btnGL.Layout.Row = 4;

uibutton(btnGL, 'Text', 'Copy Stats', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'ButtonPushedFcn', @(~,~) copyStats());
uibutton(btnGL, 'Text', 'Export Region', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'Tooltip', 'Export region data as a new dataset', ...
    'ButtonPushedFcn', @(~,~) exportRegion());
uibutton(btnGL, 'Text', 'Close', ...
    'FontSize', 10, ...
    'ButtonPushedFcn', @(~,~) cleanup());

% ── Row 5: Status ────────────────────────────────────────────────────
lblStatus = uilabel(rootGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);
lblStatus.Layout.Row = 5;

% State
roiPatch  = [];    % patch handle on main axes
roiLines  = [];    % boundary line handles (unused when draggable cursors active)
cursors   = [];    % draggable cursor bundle from bosonPlotter.fitCursors
suppressCursorCb = false;   % guard against setRange-induced callback loops
roiStats  = struct();  % last computed stats
clickMode = false;
clickCount = 0;
oldBDF = [];

% Ensure figure cleans up draggable cursors too
roiFig.CloseRequestFcn = @(~,~) cleanup();

% Initial computation if bounds are valid
updateROI();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function startRegionPick()
    %STARTREGIONPICK  Enter click-to-define mode on the main axes.
        roiFig.Visible = 'off';
        clickMode = true;
        clickCount = 0;
        parentFig = mainAx.Parent;
        while ~isa(parentFig, 'matlab.ui.Figure')
            parentFig = parentFig.Parent;
        end
        parentFig.Pointer = 'crosshair';
        oldBDF = parentFig.WindowButtonDownFcn;
        parentFig.WindowButtonDownFcn = @(~,~) onAxesClick(parentFig);
        options.StatusFcn('Click the LEFT edge of the region...');
    end

    function onAxesClick(parentFig)
        cp = mainAx.CurrentPoint;
        xClick = cp(1,1);
        xl = mainAx.XLim;
        if xClick < xl(1) || xClick > xl(2), return; end
        clickCount = clickCount + 1;

        if clickCount == 1
            efXmin.Value = xClick;
            options.StatusFcn('Click the RIGHT edge of the region...');
        elseif clickCount >= 2
            efXmax.Value = xClick;
            if efXmin.Value > efXmax.Value
                tmp = efXmin.Value;
                efXmin.Value = efXmax.Value;
                efXmax.Value = tmp;
            end
            parentFig.WindowButtonDownFcn = oldBDF;
            parentFig.Pointer = 'arrow';
            clickMode = false;
            roiFig.Visible = 'on';
            figure(roiFig);
            updateROI();
            options.StatusFcn(sprintf('Region set: [%.4g, %.4g]', efXmin.Value, efXmax.Value));
        end
    end

    function updateROI()
    %UPDATEROI  Recompute stats and update display for current bounds.
        ch = ddCh.Value;
        xAll = plotD.time;
        yAll = plotD.values(:, ch);

        xMin = efXmin.Value;
        xMax = efXmax.Value;

        mask = xAll >= xMin & xAll <= xMax;
        xSeg = xAll(mask);
        ySeg = yAll(mask);

        if numel(xSeg) < 2
            statsArea.Value = {'Not enough points in region.'};
            lblTitle.Text = sprintf('Region: [%.4g, %.4g] — %d points', xMin, xMax, numel(xSeg));
            return;
        end

        % Compute statistics
        s = computeROIStats(xSeg, ySeg);
        roiStats = s;

        % Update display
        lblTitle.Text = sprintf('Region: [%.4g, %.4g] — %d points', xMin, xMax, s.N);

        lines = {
            sprintf('  N points    = %d', s.N)
            sprintf('  Integral    = %.6g', s.integral)
            sprintf('  Mean        = %.6g', s.mean)
            sprintf('  Std Dev     = %.6g', s.std)
            sprintf('  Min         = %.6g  (at x = %.4g)', s.min, s.minX)
            sprintf('  Max         = %.6g  (at x = %.4g)', s.max, s.maxX)
            sprintf('  Range       = %.6g', s.range)
            sprintf('  Median      = %.6g', s.median)
        };
        if isfinite(s.fwhm)
            lines{end+1} = sprintf('  FWHM        = %.6g  (center = %.4g)', s.fwhm, s.fwhmCenter);
        end
        statsArea.Value = lines;

        % Draw overlay on main axes
        drawOverlay(xMin, xMax, ySeg);
    end

    function s = computeROIStats(xSeg, ySeg)
    %COMPUTEROISTATS  Compute region statistics.
        s.N = numel(xSeg);
        s.integral = trapz(xSeg, ySeg);
        s.mean = mean(ySeg);
        s.std = std(ySeg);
        s.median = median(ySeg);
        [s.min, minI] = min(ySeg);
        s.minX = xSeg(minI);
        [s.max, maxI] = max(ySeg);
        s.maxX = xSeg(maxI);
        s.range = s.max - s.min;

        % FWHM estimate (if peak-like)
        s.fwhm = NaN;
        s.fwhmCenter = NaN;
        halfMax = (s.max + s.min) / 2;  % half-max above baseline
        aboveHM = ySeg >= halfMax;
        transitions = find(diff(aboveHM));
        if numel(transitions) >= 2
            % Interpolate for more precise edge positions
            xLeft  = interp1(ySeg(transitions(1):transitions(1)+1), ...
                xSeg(transitions(1):transitions(1)+1), halfMax, 'linear');
            xRight = interp1(ySeg(transitions(end):transitions(end)+1), ...
                xSeg(transitions(end):transitions(end)+1), halfMax, 'linear');
            if isfinite(xLeft) && isfinite(xRight)
                s.fwhm = abs(xRight - xLeft);
                s.fwhmCenter = (xLeft + xRight) / 2;
            end
        end
    end

    function drawOverlay(xMin, xMax, ~)
    %DRAWOVERLAY  Draw/update the shaded ROI region and draggable cursors.
        yLims = mainAx.YLim;

        % Translucent patch — create or update
        if ~isempty(roiPatch) && isvalid(roiPatch)
            roiPatch.XData = [xMin xMax xMax xMin];
            roiPatch.YData = [yLims(1) yLims(1) yLims(2) yLims(2)];
        else
            roiPatch = patch(mainAx, ...
                [xMin xMax xMax xMin], ...
                [yLims(1) yLims(1) yLims(2) yLims(2)], ...
                [0.3 0.6 1.0], ...
                'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'Tag', 'roiPatch');
            % Keep the patch behind data so cursor lines sit on top
            uistack(roiPatch, 'bottom');
        end

        % Draggable cursor pair — create once, reuse across updates
        if isempty(cursors) || ~isstruct(cursors) || ...
                ~isfield(cursors, 'lineL') || ~isvalid(cursors.lineL)
            cursors = bosonPlotter.fitCursors(mainAx, xMin, xMax, @onCursorDragged);
        else
            suppressCursorCb = true;
            cursors.setRange(xMin, xMax);
            suppressCursorCb = false;
        end
    end

    function onCursorDragged(xL, xR)
    %ONCURSORDRAGGED  Push new cursor range into edit fields + stats.
        if suppressCursorCb, return; end
        efXmin.Value = xL;
        efXmax.Value = xR;
        updateROI();
    end

    function clearOverlay()
    %CLEAROVERLAY  Remove ROI overlay graphics and draggable cursors.
        if ~isempty(roiPatch) && isvalid(roiPatch)
            delete(roiPatch);
        end
        for li = 1:numel(roiLines)
            if isvalid(roiLines(li))
                delete(roiLines(li));
            end
        end
        if ~isempty(cursors) && isstruct(cursors) && isfield(cursors, 'remove')
            try
                cursors.remove();
            catch
            end
        end
        roiPatch = [];
        roiLines = [];
        cursors  = [];
    end

    function copyStats()
    %COPYSTATS  Copy region statistics to clipboard.
        if ~isfield(roiStats, 'N'), return; end
        txt = statsArea.Value;
        clipboard('copy', strjoin(txt, newline));
        lblStatus.Text = 'Stats copied to clipboard';
        options.StatusFcn('ROI stats copied to clipboard');
    end

    function exportRegion()
    %EXPORTREGION  Extract region data as a new dataset.
        ch = ddCh.Value;
        xAll = plotD.time;
        yAll = plotD.values(:, ch);
        mask = xAll >= efXmin.Value & xAll <= efXmax.Value;

        if sum(mask) < 2
            uialert(roiFig, 'Not enough points in region.', 'Export');
            return;
        end

        if ~isempty(options.ExportCallback)
            newData = plotD;
            newData.time = xAll(mask);
            newData.values = yAll(mask);
            newData.labels = labels(ch);
            newData.metadata.roiExport = true;
            newData.metadata.roiRange = [efXmin.Value, efXmax.Value];
            options.ExportCallback(newData);
            lblStatus.Text = 'Region exported as new dataset';
            options.StatusFcn('ROI region exported');
        else
            % No callback — save to workspace variable
            roiData.x = xAll(mask);
            roiData.y = yAll(mask);
            roiData.stats = roiStats;
            assignin('base', 'roiExportedData', roiData);
            lblStatus.Text = 'Saved to workspace: roiExportedData';
            options.StatusFcn('ROI data saved to workspace variable "roiExportedData"');
        end
    end

    function cleanup()
    %CLEANUP  Close the panel and remove overlay.
        clearOverlay();
        if clickMode && ~isempty(oldBDF)
            parentFig = mainAx.Parent;
            while ~isa(parentFig, 'matlab.ui.Figure')
                parentFig = parentFig.Parent;
            end
            parentFig.WindowButtonDownFcn = oldBDF;
            parentFig.Pointer = 'arrow';
        end
        delete(roiFig);
    end

end
