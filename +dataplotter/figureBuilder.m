function figureBuilder(datasets, activeIdx, options)
%FIGUREBUILDER  Open the Advanced Figure Builder dialog.
%   dataplotter.figureBuilder(datasets, activeIdx)
%
%   Extracted from DataPlotter.m — creates a standalone uifigure for
%   building multi-panel, waterfall, contour, and other publication figures.
%
%   Inputs:
%       datasets    Cell array of dataset structs
%       activeIdx   Index of the active dataset
%
%   Name-Value Options:
%       ButtonColors  Struct with .primary, .tool, .fg color arrays

arguments
    datasets   cell
    activeIdx  double
    options.ButtonColors struct = struct('primary', [0.15 0.45 0.75], 'tool', [0.22 0.22 0.28], 'fg', [0.95 0.95 0.95])
end

BTN_PRIMARY  = options.ButtonColors.primary;
BTN_TOOL     = options.ButtonColors.tool;
BTN_FG       = options.ButtonColors.fg;
BTN_EXPORT   = [0.18 0.32 0.52];   % slate-blue — export/save actions

        nDS = numel(datasets);

        % Build display names for all loaded datasets
        dsNames = cell(1, nDS);
        for ii = 1:nDS
            dsTmp = datasets{ii};
            [~, fn, fx] = fileparts(dsTmp.filepath);
            dsNames{ii} = [fn, fx];
        end

        % Collect all Y labels from all datasets
        allYLabels = {};
        for ii = 1:nDS
            allYLabels = [allYLabels, datasets{ii}.data.labels]; %#ok<AGROW>
        end
        allYLabels = unique(allYLabels, 'stable');

        % ── Builder uifigure ────────────────────────────────────────────
        bFig = uifigure('Name','Advanced Figure Builder', ...
            'Position',[250 120 700 600], 'Resize','off');

        bRootGL = uigridlayout(bFig, [4 1], ...
            'RowHeight', {28, '1x', 70, 36}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 6);

        % ════════════════════════════════════════════════════════════════
        %  Row 1: Figure type selector
        % ════════════════════════════════════════════════════════════════
        typeGL = uigridlayout(bRootGL, [1 3], ...
            'ColumnWidth', {90, 200, '1x'}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 6);
        typeGL.Layout.Row = 1;

        uilabel(typeGL,'Text','Figure type:','FontSize',11, ...
            'FontWeight','bold','HorizontalAlignment','right');
        ddFigType = uidropdown(typeGL, ...
            'Items', {'Multi-Panel','Quick Grid','Waterfall','Overlay + Residual','Normalized Overlay','Before / After','Parameter Evolution','Broken Axis','Confidence Band','Contour / Heatmap','Color Scatter (Z)','Marginal Histogram','Grouped Plot','FFT / Spectral'}, ...
            'Value', 'Multi-Panel', ...
            'ValueChangedFcn', @onTypeChanged);
        uilabel(typeGL,'Text','');  % spacer

        % ════════════════════════════════════════════════════════════════
        %  Row 2: Dynamic config area (swapped per type)
        % ════════════════════════════════════════════════════════════════
        configPanel = uipanel(bRootGL,'Title','Configuration', ...
            'Scrollable','on','FontSize',10);
        configPanel.Layout.Row = 2;

        % ════════════════════════════════════════════════════════════════
        %  Row 3: Global options
        % ════════════════════════════════════════════════════════════════
        globalPanel = uipanel(bRootGL,'Title','Global Options','FontSize',9);
        globalPanel.Layout.Row = 3;

        gGL = uigridlayout(globalPanel, [2 8], ...
            'RowHeight', {22, 22}, ...
            'ColumnWidth', {70, 120, 60, 50, 60, 50, 80, '1x'}, ...
            'Padding', [4 2 4 2], 'RowSpacing', 2, 'ColumnSpacing', 6);

        % Row 1: template, error style, line style
        uilabel(gGL,'Text','Template:','HorizontalAlignment','right','FontSize',9);
        savedTmplNames = plotting.plotTemplate('list');
        builtinItems   = {'None','APS (Phys Rev)','Nature','ACS','Custom'};
        if ~isempty(savedTmplNames)
            userItems = cellfun(@(n) ['User: ' n], savedTmplNames, ...
                'UniformOutput', false);
        else
            userItems = {};
        end
        ddTemplate = uidropdown(gGL, ...
            'Items', [builtinItems, userItems(:)'], ...
            'Value', 'None', ...
            'ValueChangedFcn', @onTemplateChanged, ...
            'FontSize', 9);

        uilabel(gGL,'Text','Errors:','HorizontalAlignment','right','FontSize',9);
        ddErrorStyle = uidropdown(gGL, ...
            'Items', {'None','Error Bars','Error Band'}, ...
            'Value', 'None', 'FontSize', 9);

        uilabel(gGL,'Text','Style:','HorizontalAlignment','right','FontSize',9);
        ddBStyle = uidropdown(gGL, ...
            'Items', {'Line','Scatter','Line+Pts'}, ...
            'Value', 'Line', 'FontSize', 9);

        cbGrayscale = uicheckbox(gGL,'Text','Grayscale','Value',false,'FontSize',9);
        uilabel(gGL,'Text','');

        % Row 2: dimensions, font
        uilabel(gGL,'Text','Width (in):','HorizontalAlignment','right','FontSize',9);
        spBFigW = uispinner(gGL,'Value',7,'Limits',[2 20],'Step',0.5,'FontSize',9);

        uilabel(gGL,'Text','Height:','HorizontalAlignment','right','FontSize',9);
        spBFigH = uispinner(gGL,'Value',5,'Limits',[2 24],'Step',0.5,'FontSize',9);

        uilabel(gGL,'Text','Font (pt):','HorizontalAlignment','right','FontSize',9);
        spFont = uispinner(gGL,'Value',10,'Limits',[6 24],'Step',1,'FontSize',9);

        uilabel(gGL,'Text','Font:','HorizontalAlignment','right','FontSize',9);
        ddFontName = uidropdown(gGL, ...
            'Items', {'Helvetica','Arial','Times New Roman','CMU Serif','Courier'}, ...
            'Value', 'Helvetica', 'FontSize', 9);

        % ════════════════════════════════════════════════════════════════
        %  Row 4: Buttons
        % ════════════════════════════════════════════════════════════════
        botGL = uigridlayout(bRootGL, [1 3], ...
            'ColumnWidth', {'1x', 110, 90}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 8);
        botGL.Layout.Row = 4;

        uilabel(botGL,'Text','');
        uibutton(botGL,'Text','Generate', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'FontWeight','bold', ...
            'ButtonPushedFcn', @onBuildGenerate);
        uibutton(botGL,'Text','Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(bFig));

        % ════════════════════════════════════════════════════════════════
        %  Per-type widget storage
        % ════════════════════════════════════════════════════════════════
        mpWidgets = struct();   % multi-panel
        qgWidgets = struct();   % quick grid
        wfWidgets = struct();   % waterfall
        orWidgets = struct();   % overlay+residual
        baWidgets = struct();   % before/after
        noWidgets = struct();   % normalized overlay
        peWidgets = struct();   % parameter evolution
        brWidgets = struct();   % broken axis
        csWidgets = struct();   % color scatter (Z)
        mhWidgets = struct();   % marginal histogram
        gpWidgets = struct();   % grouped plot
        fsWidgets = struct();   % FFT / spectral

        % Initial population
        onTypeChanged([], []);

        % ────────────────────────────────────────────────────────────────
        %  Template presets
        % ────────────────────────────────────────────────────────────────
        function onTemplateChanged(~,~)
            tmpl = ddTemplate.Value;
            switch tmpl
                case 'APS (Phys Rev)'
                    spBFigW.Value = 3.375; spBFigH.Value = 2.8;
                    spFont.Value = 8; ddFontName.Value = 'Times New Roman';
                case 'Nature'
                    spBFigW.Value = 3.5; spBFigH.Value = 2.8;
                    spFont.Value = 7; ddFontName.Value = 'Helvetica';
                case 'ACS'
                    spBFigW.Value = 3.25; spBFigH.Value = 2.5;
                    spFont.Value = 8; ddFontName.Value = 'Helvetica';
                otherwise
                    % User-saved template: "User: <name>"
                    if startsWith(tmpl, 'User: ')
                        nm = tmpl(7:end);   % strip "User: " prefix
                        try
                            ut = plotting.plotTemplate('load', Name=nm);
                            ap = ut.axesProps;
                            spBFigW.Value = ut.figureProps.Width  / 96;
                            spBFigH.Value = ut.figureProps.Height / 96;
                            spFont.Value  = ap.FontSize;
                        catch
                            % template file missing or corrupt — ignore
                        end
                    end
                    % None / Custom — leave as-is
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  Type switching — rebuild config area
        % ────────────────────────────────────────────────────────────────
        function onTypeChanged(~,~)
            delete(configPanel.Children);
            figType = ddFigType.Value;
            switch figType
                case 'Multi-Panel'
                    buildMultiPanelConfig();
                case 'Quick Grid'
                    buildQuickGridConfig();
                case 'Waterfall'
                    buildWaterfallConfig();
                case 'Overlay + Residual'
                    buildOverlayResidualConfig();
                case 'Normalized Overlay'
                    buildNormOverlayConfig();
                case 'Before / After'
                    buildBeforeAfterConfig();
                case 'Parameter Evolution'
                    buildParamEvolConfig();
                case 'Broken Axis'
                    buildBrokenAxisConfig();
                case 'Confidence Band'
                    buildConfidenceBandConfig();
                case 'Contour / Heatmap'
                    buildContourConfig();
                case 'Color Scatter (Z)'
                    buildColorScatterZConfig();
                case 'Marginal Histogram'
                    buildMarginalHistogramConfig();
                case 'Grouped Plot'
                    buildGroupedPlotConfig();
                case 'FFT / Spectral'
                    buildFFTSpectralConfig();
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Multi-Panel
        % ────────────────────────────────────────────────────────────────
        function buildMultiPanelConfig()
            gl = uigridlayout(configPanel, [2 1], ...
                'RowHeight', {28, '1x'}, ...
                'Padding', [4 4 4 4], 'RowSpacing', 4);

            % Top row: grid size + sharing
            topG = uigridlayout(gl, [1 6], ...
                'ColumnWidth', {55, 45, 65, 45, 100, 100}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 4);
            topG.Layout.Row = 1;

            uilabel(topG,'Text','Rows:','HorizontalAlignment','right','FontSize',9);
            mpWidgets.spRows = uispinner(topG,'Value',2,'Limits',[1 8],'Step',1, ...
                'FontSize',9,'ValueChangedFcn',@(~,~) mpRebuild());
            uilabel(topG,'Text','Columns:','HorizontalAlignment','right','FontSize',9);
            mpWidgets.spCols = uispinner(topG,'Value',1,'Limits',[1 4],'Step',1, ...
                'FontSize',9,'ValueChangedFcn',@(~,~) mpRebuild());
            mpWidgets.cbShareX = uicheckbox(topG,'Text','Share X axis','Value',true,'FontSize',9);
            mpWidgets.cbShareY = uicheckbox(topG,'Text','Share Y scale','Value',false,'FontSize',9);

            % Panel cards container
            mpWidgets.scrollGL = uigridlayout(gl, [1 1], ...
                'Padding', [0 0 0 0]);
            mpWidgets.scrollGL.Layout.Row = 2;
            mpWidgets.panelCards = {};
            mpRebuild();
        end

        function mpRebuild()
            nR = mpWidgets.spRows.Value;
            nC = mpWidgets.spCols.Value;
            nPanels = nR * nC;
            delete(mpWidgets.scrollGL.Children);

            container = uigridlayout(mpWidgets.scrollGL, [nPanels 1], ...
                'RowHeight', repmat({120}, 1, nPanels), ...
                'Padding', [2 2 2 2], 'RowSpacing', 4);

            mpWidgets.panelCards = cell(1, nPanels);
            for pi = 1:nPanels
                [r, c] = ind2sub([nR, nC], pi);
                pp = uipanel(container, 'Title', ...
                    sprintf('Panel %d  (R%d C%d)', pi, r, c), 'FontSize', 9);
                pp.Layout.Row = pi;

                pGL = uigridlayout(pp, [5 6], ...
                    'RowHeight', {22, 22, 22, 22, 22}, ...
                    'ColumnWidth', {'1x','1x','1x','1x','1x','1x'}, ...
                    'Padding', [4 2 4 2], 'RowSpacing', 2, 'ColumnSpacing', 3);

                % Datasets (col 1-2, rows 1-3)
                lb = uilistbox(pGL,'Items', dsNames, 'ItemsData', 1:nDS, ...
                    'Multiselect','on','Value', min(1, nDS), 'FontSize', 9);
                lb.Layout.Row = [1 3]; lb.Layout.Column = [1 2];

                % Y left (col 3-4, rows 1-2)
                uilabel(pGL,'Text','Y (left):','FontSize',7,'FontAngle','italic');
                lbY = uilistbox(pGL,'Items', allYLabels, 'Multiselect','on', ...
                    'Value', allYLabels(1:min(1,numel(allYLabels))), 'FontSize', 9);
                lbY.Layout.Row = [1 2]; lbY.Layout.Column = [3 4];

                % Y2 right (col 5-6, rows 1-2)
                uilabel(pGL,'Text','Y2 (right):','FontSize',7,'FontAngle','italic');
                y2Items = [{'(none)'}, allYLabels];
                lbY2 = uilistbox(pGL,'Items', y2Items, 'Multiselect','on', ...
                    'Value', {'(none)'}, 'FontSize', 9);
                lbY2.Layout.Row = [1 2]; lbY2.Layout.Column = [5 6];

                % Row 3: options
                cbL = uicheckbox(pGL,'Text','Log Y','Value',false,'FontSize',9);
                cbL.Layout.Row = 3; cbL.Layout.Column = 3;

                efT = uieditfield(pGL,'Value','','Placeholder','Panel title','FontSize',9);
                efT.Layout.Row = 3; efT.Layout.Column = [4 6];

                % Row 4: row/column span
                uilabel(pGL,'Text','Row span:','FontSize',8,'HorizontalAlignment','right');
                spRS = uispinner(pGL,'Value',1,'Limits',[1 nR],'Step',1,'FontSize',8);
                spRS.Layout.Row = 4; spRS.Layout.Column = 2;

                uilabel(pGL,'Text','Col span:','FontSize',8,'HorizontalAlignment','right');
                spCS = uispinner(pGL,'Value',1,'Limits',[1 nC],'Step',1,'FontSize',8);
                spCS.Layout.Row = 4; spCS.Layout.Column = 4;

                mpWidgets.panelCards{pi} = struct('lbDS',lb,'lbY',lbY,'lbY2',lbY2, ...
                    'cbLog',cbL,'efTitle',efT,'spRowSpan',spRS,'spColSpan',spCS);
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Waterfall
        % ────────────────────────────────────────────────────────────────
        function buildWaterfallConfig()
            gl = uigridlayout(configPanel, [6 4], ...
                'RowHeight', {22, '1x', 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Datasets:','FontSize',9,'FontWeight','bold');
            uilabel(gl,'Text','');
            uilabel(gl,'Text','Y Channel:','FontSize',9,'FontWeight','bold');
            uilabel(gl,'Text','');

            wfWidgets.lbDS = uilistbox(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Multiselect','on','Value', 1:nDS, 'FontSize', 9);
            wfWidgets.lbDS.Layout.Row = 2; wfWidgets.lbDS.Layout.Column = [1 2];

            wfWidgets.lbY = uilistbox(gl,'Items', allYLabels, 'Multiselect','off', ...
                'Value', allYLabels{1}, 'FontSize', 9);
            wfWidgets.lbY.Layout.Row = 2; wfWidgets.lbY.Layout.Column = [3 4];

            % Spacing
            uilabel(gl,'Text','Spacing:','HorizontalAlignment','right','FontSize',9);
            wfWidgets.efSpacing = uieditfield(gl,'Value','auto', ...
                'Placeholder','auto or number','FontSize',9, ...
                'Tooltip','Vertical offset between traces (auto = 0.8 × median range)');

            uilabel(gl,'Text','Direction:','HorizontalAlignment','right','FontSize',9);
            wfWidgets.ddDir = uidropdown(gl, ...
                'Items', {'Bottom to Top','Top to Bottom'}, ...
                'Value', 'Bottom to Top', 'FontSize', 9);

            % Options
            wfWidgets.cbLogMode = uicheckbox(gl,'Text','Log-mode (multiplicative offset)', ...
                'Value', false, 'FontSize', 9);
            wfWidgets.cbLogMode.Layout.Row = 4; wfWidgets.cbLogMode.Layout.Column = [1 2];

            wfWidgets.cbEdgeLabels = uicheckbox(gl,'Text','Right-edge trace labels', ...
                'Value', true, 'FontSize', 9);
            wfWidgets.cbEdgeLabels.Layout.Row = 4; wfWidgets.cbEdgeLabels.Layout.Column = [3 4];

            wfWidgets.cbLogY = uicheckbox(gl,'Text','Log Y axis','Value',false,'FontSize',9);
            wfWidgets.cbLogY.Layout.Row = 5; wfWidgets.cbLogY.Layout.Column = [1 2];

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            wfWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);

            % Row 6: Z-coloring
            wfZItems = [{'(none)'}, allYLabels];
            wfWidgets.cbColorZ = uicheckbox(gl,'Text','Color by Z:', ...
                'Value', false, 'FontSize', 9, ...
                'Tooltip','Color each trace from a colormap based on a Z channel value');
            wfWidgets.cbColorZ.Layout.Row = 6; wfWidgets.cbColorZ.Layout.Column = 1;

            wfWidgets.ddColorZChan = uidropdown(gl,'Items', wfZItems, ...
                'Value', wfZItems{1}, 'FontSize', 9, ...
                'Tooltip','Channel whose value determines line color');
            wfWidgets.ddColorZChan.Layout.Row = 6; wfWidgets.ddColorZChan.Layout.Column = 2;

            uilabel(gl,'Text','Colormap:','HorizontalAlignment','right','FontSize',9);
            wfWidgets.ddColorZCmap = uidropdown(gl, ...
                'Items', {'parula','viridis','plasma','inferno','hot','jet','turbo','cool','gray'}, ...
                'Value', 'viridis', 'FontSize', 9);
            wfWidgets.ddColorZCmap.Layout.Row = 6; wfWidgets.ddColorZCmap.Layout.Column = [3 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Overlay + Residual
        % ────────────────────────────────────────────────────────────────
        function buildOverlayResidualConfig()
            gl = uigridlayout(configPanel, [6 4], ...
                'RowHeight', {22, 22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset A:','HorizontalAlignment','right','FontSize',9);
            orWidgets.ddA = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', 1, 'FontSize', 9);

            uilabel(gl,'Text','Dataset B:','HorizontalAlignment','right','FontSize',9);
            orWidgets.ddB = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', min(2, nDS), 'FontSize', 9);

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            orWidgets.ddY = uidropdown(gl,'Items', allYLabels, ...
                'Value', allYLabels{1}, 'FontSize', 9);

            uilabel(gl,'Text','Residual:','HorizontalAlignment','right','FontSize',9);
            orWidgets.ddResidMode = uidropdown(gl, ...
                'Items', {'A - B (absolute)','(A - B) / A  (%)'}, ...
                'Value', 'A - B (absolute)', 'FontSize', 9);

            orWidgets.cbLogOverlay = uicheckbox(gl,'Text','Log Y (overlay panel)', ...
                'Value', false, 'FontSize', 9);
            orWidgets.cbLogOverlay.Layout.Row = 4; orWidgets.cbLogOverlay.Layout.Column = [1 2];

            uilabel(gl,'Text','Height ratio:','HorizontalAlignment','right','FontSize',9);
            orWidgets.ddRatio = uidropdown(gl, ...
                'Items', {'3:1','2:1','1:1'}, ...
                'Value', '3:1', 'FontSize', 9);

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            orWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            orWidgets.efTitle.Layout.Column = [2 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Normalized Overlay
        % ────────────────────────────────────────────────────────────────
        function buildNormOverlayConfig()
            gl = uigridlayout(configPanel, [5 4], ...
                'RowHeight', {22, '1x', 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Datasets:','FontSize',9,'FontWeight','bold');
            uilabel(gl,'Text','');
            uilabel(gl,'Text','Y Channel:','FontSize',9,'FontWeight','bold');
            uilabel(gl,'Text','');

            noWidgets.lbDS = uilistbox(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Multiselect','on','Value', 1:min(nDS,4), 'FontSize', 9);
            noWidgets.lbDS.Layout.Row = 2; noWidgets.lbDS.Layout.Column = [1 2];

            noWidgets.lbY = uilistbox(gl,'Items', allYLabels, 'Multiselect','off', ...
                'Value', allYLabels{1}, 'FontSize', 9);
            noWidgets.lbY.Layout.Row = 2; noWidgets.lbY.Layout.Column = [3 4];

            uilabel(gl,'Text','Normalize:','HorizontalAlignment','right','FontSize',9);
            noWidgets.ddNormMethod = uidropdown(gl, ...
                'Items', {'Peak (0-1)','Range (0-1)','Z-score','Area'}, ...
                'Value', 'Peak (0-1)', 'FontSize', 9);

            uilabel(gl,'Text','X align:','HorizontalAlignment','right','FontSize',9);
            noWidgets.ddAlign = uidropdown(gl, ...
                'Items', {'None','Peak center','X offset'}, ...
                'Value', 'None', 'FontSize', 9);

            noWidgets.cbLogY = uicheckbox(gl,'Text','Log Y','Value',false,'FontSize',9);
            noWidgets.cbLogY.Layout.Row = 4; noWidgets.cbLogY.Layout.Column = 1;

            noWidgets.cbLegend = uicheckbox(gl,'Text','Show legend','Value',true,'FontSize',9);
            noWidgets.cbLegend.Layout.Row = 4; noWidgets.cbLegend.Layout.Column = [3 4];

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            noWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            noWidgets.efTitle.Layout.Column = [2 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Normalized Overlay
        % ────────────────────────────────────────────────────────────────
        function generateNormOverlay()
            dsIdx = ensureCellNum(noWidgets.lbDS.Value);
            yName = noWidgets.lbY.Value;
            normMethod = noWidgets.ddNormMethod.Value;
            alignMode  = noWidgets.ddAlign.Value;

            if isempty(dsIdx)
                uialert(bFig,'Select at least one dataset.','No data'); return;
            end

            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);

            outFig = figure('Name','Normalized Overlay','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            tAx = axes(outFig);
            hold(tAx, 'on'); box(tAx, 'on'); grid(tAx, 'on');
            tAx.FontSize = fmtOpts.fontSize;
            tAx.FontName = fmtOpts.fontName;
            tAx.TickDir  = 'in';

            nTraces = numel(dsIdx);
            if fmtOpts.grayscale
                clrs = repmat(linspace(0, 0.7, nTraces)', 1, 3);
            else
                clrs = getColorsFromMap('lines (MATLAB default)', nTraces);
            end

            GS_STYLES  = {'-', '--', ':', '-.'};
            GS_MARKERS = {'o', 's', '^', 'd', 'v', '>', '<', 'p'};

            xLbl = ''; yLbl = 'Normalised';

            for si = 1:nTraces
                di = dsIdx(si);
                if di < 1 || di > nDS, continue; end
                d = getPlotData(di);
                idx = find(strcmp(d.labels, yName), 1);
                if isempty(idx), continue; end

                xVec = d.time;
                yVec = d.values(:, idx);
                good = ~isnan(xVec) & ~isnan(yVec);
                if isdatetime(xVec), good = ~isnat(xVec) & ~isnan(yVec); end
                xVec = xVec(good); yVec = yVec(good);

                if isempty(xLbl)
                    xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
                end

                % Normalize
                switch normMethod
                    case 'Peak (0-1)'
                        yVec = yVec / max(abs(yVec));
                    case 'Range (0-1)'
                        mn = min(yVec); mx = max(yVec);
                        if mx > mn, yVec = (yVec - mn) / (mx - mn); end
                    case 'Z-score'
                        m = mean(yVec); s = std(yVec);
                        if s > 0, yVec = (yVec - m) / s; end
                        yLbl = 'Z-score';
                    case 'Area'
                        a = trapz(double(xVec), yVec);
                        if a ~= 0, yVec = yVec / a; end
                        yLbl = 'Area-normalised';
                end

                % Alignment
                switch alignMode
                    case 'Peak center'
                        [~, pkIdx] = max(yVec);
                        xVec = xVec - xVec(pkIdx);
                        xLbl = [xLbl, ' (aligned)'];  %#ok — only first pass appends
                    case 'X offset'
                        xVec = xVec - xVec(1);
                end

                baseColor = clrs(si, :);
                plotLS = ls;
                if fmtOpts.grayscale
                    gsStyle  = GS_STYLES{mod(si-1, numel(GS_STYLES)) + 1};
                    gsMarker = GS_MARKERS{mod(si-1, numel(GS_MARKERS)) + 1};
                    plotLS = {'LineStyle', gsStyle, 'Marker', gsMarker, 'MarkerSize', 4};
                end

                plot(tAx, xVec, yVec, plotLS{:}, ...
                    'Color', baseColor, ...
                    'LineWidth', fmtOpts.lineWidth, ...
                    'DisplayName', dsNames{di});
            end

            if noWidgets.cbLogY.Value, tAx.YScale = 'log'; end
            xlabel(tAx, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(tAx, yLbl, 'FontSize', fmtOpts.fontSize);

            if noWidgets.cbLegend.Value && nTraces > 1
                legend(tAx, 'Interpreter','none','FontSize', max(fmtOpts.fontSize-2,6), 'Location','best');
            end

            ttl = noWidgets.efTitle.Value;
            if ~isempty(ttl)
                title(tAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Before / After
        % ────────────────────────────────────────────────────────────────
        function buildBeforeAfterConfig()
            gl = uigridlayout(configPanel, [4 4], ...
                'RowHeight', {22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            baWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9);
            baWidgets.ddDS.Layout.Column = [2 4];

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            baWidgets.lbY = uilistbox(gl,'Items', allYLabels, 'Multiselect','on', ...
                'Value', allYLabels(1:min(1,numel(allYLabels))), 'FontSize', 9);
            baWidgets.lbY.Layout.Row = [2 3]; baWidgets.lbY.Layout.Column = [2 4];

            baWidgets.cbLogY = uicheckbox(gl,'Text','Log Y','Value',false,'FontSize',9);
            baWidgets.cbLogY.Layout.Row = 4; baWidgets.cbLogY.Layout.Column = 2;

            baWidgets.cbLinkY = uicheckbox(gl,'Text','Link Y scale','Value',true,'FontSize',9);
            baWidgets.cbLinkY.Layout.Row = 4; baWidgets.cbLinkY.Layout.Column = 3;
        end

        % ════════════════════════════════════════════════════════════════
        %  GENERATE — dispatch to per-type builder
        % ════════════════════════════════════════════════════════════════
        function onBuildGenerate(~,~)
            figType = ddFigType.Value;
            switch figType
                case 'Multi-Panel',         generateMultiPanel();
                case 'Quick Grid',          generateQuickGrid();
                case 'Waterfall',           generateWaterfall();
                case 'Overlay + Residual',  generateOverlayResidual();
                case 'Normalized Overlay',  generateNormOverlay();
                case 'Before / After',      generateBeforeAfter();
                case 'Parameter Evolution', generateParamEvol();
                case 'Broken Axis',         generateBrokenAxis();
                case 'Confidence Band',     generateConfidenceBand();
                case 'Contour / Heatmap',  generateContour();
                case 'Color Scatter (Z)',   generateColorScatterZ();
                case 'Marginal Histogram',  generateMarginalHistogram();
                case 'Grouped Plot',        generateGroupedPlot();
                case 'FFT / Spectral',      generateFFTSpectral();
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Multi-Panel
        % ────────────────────────────────────────────────────────────────
        function generateMultiPanel()
            nR = mpWidgets.spRows.Value;
            nC = mpWidgets.spCols.Value;
            nPanels = nR * nC;
            shareX = mpWidgets.cbShareX.Value;
            shareY = mpWidgets.cbShareY.Value;
            [outFig, tlo] = makeOutFig(nR, nC, shareX);

            ls = localLineSpec(ddBStyle.Value);
            fmtOpts = getFormatOpts();

            % Track which tiles are occupied (for span support)
            occupied = false(nR, nC);
            axList = gobjects(0);

            for pi = 1:nPanels
                pw = mpWidgets.panelCards{pi};
                [r, c] = ind2sub([nR, nC], pi);

                % Skip tiles already occupied by a previous span
                if occupied(r, c), continue; end

                rSpan = min(pw.spRowSpan.Value, nR - r + 1);
                cSpan = min(pw.spColSpan.Value, nC - c + 1);

                % Mark spanned tiles as occupied
                occupied(r:r+rSpan-1, c:c+cSpan-1) = true;

                dsIdx = ensureCellNum(pw.lbDS.Value);
                selY  = ensureCellStr(pw.lbY.Value);

                % Y2 (right axis) channels
                selY2Raw = ensureCellStr(pw.lbY2.Value);
                selY2 = selY2Raw(~strcmp(selY2Raw, '(none)'));
                hasY2 = ~isempty(selY2);

                tAx = nexttile(tlo, pi, [rSpan cSpan]);
                setupAx(tAx);
                axList(end+1) = tAx; %#ok<AGROW>

                [ci, xLbl, yLbl] = plotTraces(tAx, dsIdx, selY, ls, fmtOpts);

                % Right Y-axis
                if hasY2
                    yyaxis(tAx, 'right');
                    hold(tAx, 'on');
                    [~, ~, y2Lbl] = plotTraces(tAx, dsIdx, selY2, ls, fmtOpts);
                    ylabel(tAx, y2Lbl, 'FontSize', fmtOpts.fontSize);
                    yyaxis(tAx, 'left');
                end

                if pw.cbLog.Value, tAx.YScale = 'log'; end

                % Only show X label on bottom-most row of this panel's span
                if shareX && (r + rSpan - 1) < nR
                    xlabel(tAx, '');
                else
                    xlabel(tAx, xLbl, 'FontSize', fmtOpts.fontSize);
                end
                ylabel(tAx, yLbl, 'FontSize', fmtOpts.fontSize);

                ttl = pw.efTitle.Value;
                if ~isempty(ttl)
                    title(tAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
                end
                if ci > 1 || hasY2
                    legend(tAx, 'Interpreter','none','FontSize', max(fmtOpts.fontSize-2,6), 'Location','best');
                end
            end

            linkIfNeeded(axList, shareX, shareY);
            addRefLineTools(outFig);
            addLinkedCursor(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Waterfall
        % ────────────────────────────────────────────────────────────────
        function generateWaterfall()
            dsIdx = ensureCellNum(wfWidgets.lbDS.Value);
            yName = wfWidgets.lbY.Value;
            if isempty(dsIdx), uialert(bFig,'Select at least one dataset.','No data'); return; end

            [outFig, tlo] = makeOutFig(1, 1, false);
            tAx = nexttile(tlo);
            setupAx(tAx);
            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);

            logMode   = wfWidgets.cbLogMode.Value;
            edgeLabel = wfWidgets.cbEdgeLabels.Value;
            reverse   = strcmp(wfWidgets.ddDir.Value, 'Top to Bottom');

            % Compute auto spacing
            spStr = strtrim(wfWidgets.efSpacing.Value);
            manualSp = str2double(spStr);

            % Gather Y ranges for auto-spacing
            yRanges = [];
            for si = 1:numel(dsIdx)
                di = dsIdx(si);
                if di < 1 || di > nDS, continue; end
                d = getPlotData(di);
                idx = find(strcmp(d.labels, yName), 1);
                if isempty(idx), continue; end
                col = d.values(:, idx);
                col = col(~isnan(col));
                if ~isempty(col)
                    yRanges(end+1) = max(col) - min(col); %#ok<AGROW>
                end
            end
            if isnan(manualSp) || strcmpi(spStr, 'auto')
                if isempty(yRanges)
                    spacing = 1;
                else
                    spacing = 0.8 * median(yRanges);
                end
            else
                spacing = manualSp;
            end

            nColors = max(numel(dsIdx), 1);

            % ── Z-coloring: compute per-trace Z value and map to colormap ──
            useColorZ = wfWidgets.cbColorZ.Value && ...
                        ~strcmp(wfWidgets.ddColorZChan.Value, '(none)');
            if useColorZ
                zChanName = wfWidgets.ddColorZChan.Value;
                zVals = NaN(1, numel(dsIdx));
                for zsi = 1:numel(dsIdx)
                    zdi = dsIdx(zsi);
                    if zdi < 1 || zdi > nDS, continue; end
                    zd = getPlotData(zdi);
                    zci = find(strcmp(zd.labels, zChanName), 1);
                    if isempty(zci), continue; end
                    col_z = zd.values(:, zci);
                    col_z = col_z(~isnan(col_z));
                    if ~isempty(col_z)
                        zVals(zsi) = mean(col_z);
                    end
                end
                zMin = min(zVals(~isnan(zVals)));
                zMax = max(zVals(~isnan(zVals)));
                if isempty(zMin) || zMin == zMax
                    % Fallback: uniform coloring
                    useColorZ = false;
                else
                    cmapFcnWF = str2func(wfWidgets.ddColorZCmap.Value);
                    cmapRGB   = cmapFcnWF(256);
                    % Map each zVal to a row in the colormap
                    zNorm = (zVals - zMin) / (zMax - zMin);
                    colors = zeros(numel(dsIdx), 3);
                    for zsi = 1:numel(dsIdx)
                        if isnan(zNorm(zsi))
                            colors(zsi, :) = [0.5 0.5 0.5];
                        else
                            rowIdx = max(1, round(zNorm(zsi) * 255) + 1);
                            colors(zsi, :) = cmapRGB(rowIdx, :);
                        end
                    end
                end
            end

            if ~useColorZ
                if cbGrayscale.Value
                    colors = repmat(linspace(0, 0.7, nColors)', 1, 3);
                else
                    colors = getColorsFromMap('lines (MATLAB default)', nColors);
                end
            end

            traceOrder = 1:numel(dsIdx);
            if reverse, traceOrder = flip(traceOrder); end

            xLbl = ''; yLbl = '';
            xMax = -inf;

            for ti = 1:numel(traceOrder)
                si = traceOrder(ti);
                di = dsIdx(si);
                if di < 1 || di > nDS, continue; end
                d = getPlotData(di);
                idx = find(strcmp(d.labels, yName), 1);
                if isempty(idx), continue; end

                xVec = d.time;
                yVec = d.values(:, idx);

                if isempty(xLbl)
                    xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
                end
                if isempty(yLbl) && idx <= numel(d.units)
                    yLbl = guiLabel(yName, d.units{idx});
                end

                % Apply offset
                wfOffset = si - 1;
                if logMode
                    yVec = yVec * spacing^wfOffset;
                else
                    yVec = yVec + wfOffset * spacing;
                end

                good = ~isnan(xVec) & ~isnan(yVec);
                if isdatetime(xVec), good = ~isnat(xVec) & ~isnan(yVec); end

                plot(tAx, xVec(good), yVec(good), ls{:}, ...
                    'Color', colors(si, :), ...
                    'LineWidth', fmtOpts.lineWidth, ...
                    'DisplayName', dsNames{di});

                % Edge label
                if edgeLabel
                    xGood = xVec(good);
                    yGood = yVec(good);
                    if ~isempty(xGood)
                        xEnd = xGood(end);
                        yEnd = yGood(end);
                        if xEnd > xMax, xMax = xEnd; end
                        text(tAx, double(xEnd), double(yEnd), ['  ' dsNames{di}], ...
                            'FontSize', max(fmtOpts.fontSize-2, 6), ...
                            'Color', colors(si,:), ...
                            'Interpreter', 'none', ...
                            'VerticalAlignment', 'middle', ...
                            'Clipping', 'on');
                    end
                end
            end

            if wfWidgets.cbLogY.Value, tAx.YScale = 'log'; end
            xlabel(tAx, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(tAx, yLbl, 'FontSize', fmtOpts.fontSize);
            ttl = wfWidgets.efTitle.Value;
            if ~isempty(ttl)
                title(tAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            end

            % Expand X limits for edge labels
            if edgeLabel && xMax > -inf
                xl = tAx.XLim;
                tAx.XLim(2) = xl(2) + 0.15 * (xl(2) - xl(1));
            end

            % Colorbar for Z-coloring
            if useColorZ
                cmapFcnWF2 = str2func(wfWidgets.ddColorZCmap.Value);
                colormap(tAx, cmapFcnWF2(256));
                cb = colorbar(tAx);
                cb.Label.String = wfWidgets.ddColorZChan.Value;
                cb.Label.FontSize = fmtOpts.fontSize;
                tAx.CLim = [zMin, zMax];
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Overlay + Residual
        % ────────────────────────────────────────────────────────────────
        function generateOverlayResidual()
            idxA = orWidgets.ddA.Value;
            idxB = orWidgets.ddB.Value;
            yName = orWidgets.ddY.Value;

            if idxA == idxB
                uialert(bFig,'Select two different datasets.','Same dataset'); return;
            end

            dA = getPlotData(idxA);
            dB = getPlotData(idxB);
            ciA = find(strcmp(dA.labels, yName), 1);
            ciB = find(strcmp(dB.labels, yName), 1);
            if isempty(ciA) || isempty(ciB)
                uialert(bFig, sprintf('Channel "%s" not found in both datasets.', yName), 'Missing channel');
                return;
            end

            xA = dA.time; yA = dA.values(:, ciA);
            xB = dB.time; yB = dB.values(:, ciB);

            % Interpolate B onto A's X grid
            goodA = ~isnan(xA) & ~isnan(yA);
            goodB = ~isnan(xB) & ~isnan(yB);
            xCommon = xA(goodA);
            yAc = yA(goodA);
            yBi = interp1(double(xB(goodB)), yB(goodB), double(xCommon), 'linear', NaN);

            % Residual
            residMode = orWidgets.ddResidMode.Value;
            if contains(residMode, '%')
                resid = (yAc - yBi) ./ yAc * 100;
                residLabel = 'Residual (%)';
            else
                resid = yAc - yBi;
                residLabel = 'A - B';
            end

            % Height ratio
            ratioStr = orWidgets.ddRatio.Value;
            switch ratioStr
                case '3:1', heights = [3 1];
                case '2:1', heights = [2 1];
                otherwise,  heights = [1 1];
            end

            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);

            outFig = figure('Name','Overlay + Residual','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            tlo = tiledlayout(outFig, 2, 1, ...
                'TileSpacing','compact','Padding','compact');
            tlo.TileIndexing = 'columnmajor';

            % — Top panel: overlay
            ax1 = nexttile(tlo); setupAx(ax1);
            plot(ax1, xCommon, yAc, ls{:}, 'Color', [0.12 0.47 0.71], ...
                'LineWidth', fmtOpts.lineWidth, 'DisplayName', dsNames{idxA});
            plot(ax1, xCommon, yBi, ls{:}, 'Color', [0.84 0.15 0.16], ...
                'LineWidth', fmtOpts.lineWidth, 'DisplayName', dsNames{idxB});

            if orWidgets.cbLogOverlay.Value, ax1.YScale = 'log'; end
            yLbl = guiLabel(yName, dA.units{ciA});
            ylabel(ax1, yLbl, 'FontSize', fmtOpts.fontSize);
            legend(ax1, 'Interpreter','none','FontSize', max(fmtOpts.fontSize-2,6), 'Location','best');

            ttl = orWidgets.efTitle.Value;
            if ~isempty(ttl)
                title(ax1, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            end

            % — Bottom panel: residual
            ax2 = nexttile(tlo); setupAx(ax2);
            plot(ax2, xCommon, resid, ls{:}, 'Color', [0.3 0.3 0.3], ...
                'LineWidth', fmtOpts.lineWidth);
            yline(ax2, 0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.75);

            xLbl = guiLabel(guiXName(dA.metadata), guiXUnit(dA.metadata));
            xlabel(ax2, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(ax2, residLabel, 'FontSize', fmtOpts.fontSize);

            linkaxes([ax1, ax2], 'x');

            % Adjust height ratio via TileSpan workaround — set InnerPosition
            try
                totalH = heights(1) + heights(2);
                ax1.InnerPosition(4) = ax1.InnerPosition(4) * heights(1) / totalH * 1.6;
            catch
                % tiledlayout manages sizing — skip if InnerPosition not settable
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Before / After
        % ────────────────────────────────────────────────────────────────
        function generateBeforeAfter()
            dsIdx = baWidgets.ddDS.Value;
            ds = datasets{dsIdx};
            if isempty(ds.corrData)
                uialert(bFig, 'No corrections applied to this dataset. Apply corrections first.', ...
                    'No corrected data');
                return;
            end

            selY = ensureCellStr(baWidgets.lbY.Value);
            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);

            outFig = figure('Name','Before / After Corrections','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            tlo = tiledlayout(outFig, 1, 2, ...
                'TileSpacing','compact','Padding','compact');

            dRaw  = ds.data;
            dCorr = ds.corrData;
            nColors = max(numel(selY), 1);
            colors = getColorsFromMap('lines (MATLAB default)', nColors);

            panelAxes = gobjects(1, 2);

            for side = 1:2
                tAx = nexttile(tlo, side);
                setupAx(tAx);
                panelAxes(side) = tAx;

                d = dRaw;
                panelTitle = 'Raw';
                if side == 2
                    d = dCorr;
                    panelTitle = 'Corrected';
                end

                for ki = 1:numel(selY)
                    idx = find(strcmp(d.labels, selY{ki}), 1);
                    if isempty(idx), continue; end

                    xVec = d.time;
                    yVec = d.values(:, idx);
                    good = ~isnan(xVec) & ~isnan(yVec);
                    if isdatetime(xVec), good = ~isnat(xVec) & ~isnan(yVec); end

                    dName = selY{ki};
                    if numel(selY) > 1
                        dName = guiLabel(selY{ki}, d.units{min(idx, numel(d.units))});
                    end

                    plot(tAx, xVec(good), yVec(good), ls{:}, ...
                        'Color', colors(ki,:), ...
                        'LineWidth', fmtOpts.lineWidth, ...
                        'DisplayName', dName);
                end

                if baWidgets.cbLogY.Value, tAx.YScale = 'log'; end

                xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
                yLbl = '';
                if ~isempty(selY)
                    ci1 = find(strcmp(d.labels, selY{1}), 1);
                    if ~isempty(ci1) && ci1 <= numel(d.units)
                        yLbl = guiLabel(selY{1}, d.units{ci1});
                    end
                end

                xlabel(tAx, xLbl, 'FontSize', fmtOpts.fontSize);
                if side == 1
                    ylabel(tAx, yLbl, 'FontSize', fmtOpts.fontSize);
                end
                title(tAx, panelTitle, 'FontSize', fmtOpts.fontSize+1);

                if numel(selY) > 1
                    legend(tAx,'Interpreter','none','FontSize',max(fmtOpts.fontSize-2,6),'Location','best');
                end
            end

            % Link axes
            linkaxes(panelAxes, 'x');
            if baWidgets.cbLinkY.Value
                linkaxes(panelAxes, 'xy');
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Parameter Evolution
        % ────────────────────────────────────────────────────────────────
        function buildParamEvolConfig()
            gl = uigridlayout(configPanel, [5 4], ...
                'RowHeight', {22, '1x', 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Datasets:','FontSize',9,'FontWeight','bold');
            uilabel(gl,'Text','');
            uilabel(gl,'Text','(multi-select)','FontSize',8,'FontAngle','italic');
            uilabel(gl,'Text','');

            peWidgets.lbDS = uilistbox(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Multiselect','on','Value', 1:nDS, 'FontSize', 9);
            peWidgets.lbDS.Layout.Row = 2; peWidgets.lbDS.Layout.Column = [1 2];

            % Info label
            uilabel(gl,'Text', ...
                sprintf('Peaks detected on %d/%d datasets.', ...
                    sum(cellfun(@(d) ~isempty(d.peaks), datasets)), nDS), ...
                'FontSize', 8, 'FontAngle', 'italic');

            uilabel(gl,'Text','');

            % X axis mode
            uilabel(gl,'Text','X axis:','HorizontalAlignment','right','FontSize',9);
            peWidgets.ddXMode = uidropdown(gl, ...
                'Items', {'File index','Temperature (K)','Field (Oe)'}, ...
                'Value', 'File index', 'FontSize', 9);

            % Y metric
            uilabel(gl,'Text','Y metric:','HorizontalAlignment','right','FontSize',9);
            peWidgets.ddYMetric = uidropdown(gl, ...
                'Items', {'Peak center','Peak FWHM','Peak area','Peak height','Integrated Y'}, ...
                'Value', 'Peak center', 'FontSize', 9);

            % Options
            peWidgets.cbConnect = uicheckbox(gl,'Text','Connect points','Value',true,'FontSize',9);
            peWidgets.cbConnect.Layout.Row = 4; peWidgets.cbConnect.Layout.Column = [1 2];

            uilabel(gl,'Text','Peak #:','HorizontalAlignment','right','FontSize',9);
            peWidgets.spPeakIdx = uispinner(gl,'Value',1,'Limits',[1 20],'Step',1,'FontSize',9, ...
                'Tooltip','Which peak to track (by index in peak list, sorted by center position)');

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            peWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            peWidgets.efTitle.Layout.Column = [2 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Broken Axis
        % ────────────────────────────────────────────────────────────────
        function buildBrokenAxisConfig()
            gl = uigridlayout(configPanel, [6 4], ...
                'RowHeight', {22, 22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            brWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9);
            brWidgets.ddDS.Layout.Column = [2 4];

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            brWidgets.ddY = uidropdown(gl,'Items', allYLabels, ...
                'Value', allYLabels{1}, 'FontSize', 9);

            % Break axis selector
            uilabel(gl,'Text','Break axis:','HorizontalAlignment','right','FontSize',9);
            brWidgets.ddBreakAxis = uidropdown(gl, ...
                'Items', {'X axis','Y axis'}, ...
                'Value', 'X axis', 'FontSize', 9, ...
                'Tooltip', 'Which axis to split with a gap');

            % Gap range
            uilabel(gl,'Text','Gap min:','HorizontalAlignment','right','FontSize',9);
            brWidgets.efGapLo = uieditfield(gl,'Value','','Placeholder','e.g. 30','FontSize',9);

            uilabel(gl,'Text','Gap max:','HorizontalAlignment','right','FontSize',9);
            brWidgets.efGapHi = uieditfield(gl,'Value','','Placeholder','e.g. 50','FontSize',9);

            % Options
            brWidgets.cbLogY = uicheckbox(gl,'Text','Log Y','Value',false,'FontSize',9);
            brWidgets.cbLogY.Layout.Row = 4; brWidgets.cbLogY.Layout.Column = 1;

            uilabel(gl,'Text','Width ratio:','HorizontalAlignment','right','FontSize',9);
            brWidgets.ddRatio = uidropdown(gl, ...
                'Items', {'Proportional','1:1','2:1','1:2'}, ...
                'Value', 'Proportional', 'FontSize', 9);

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            brWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            brWidgets.efTitle.Layout.Column = [2 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Parameter Evolution
        % ────────────────────────────────────────────────────────────────
        function generateParamEvol()
            dsIdx   = ensureCellNum(peWidgets.lbDS.Value);
            xMode   = peWidgets.ddXMode.Value;
            yMetric = peWidgets.ddYMetric.Value;
            peakIdx = peWidgets.spPeakIdx.Value;
            connect = peWidgets.cbConnect.Value;

            if isempty(dsIdx)
                uialert(bFig,'Select at least one dataset.','No data'); return;
            end

            fmtOpts = getFormatOpts();

            xVals = NaN(1, numel(dsIdx));
            yVals = NaN(1, numel(dsIdx));
            labels = cell(1, numel(dsIdx));

            for si = 1:numel(dsIdx)
                di = dsIdx(si);
                ds = datasets{di};
                d  = getPlotData(di);
                labels{si} = dsNames{di};

                % X value
                switch xMode
                    case 'File index'
                        xVals(si) = si;
                    case 'Temperature (K)'
                        xVals(si) = extractMetaField(d.metadata, {'temperature','temp','Temperature'});
                    case 'Field (Oe)'
                        xVals(si) = extractMetaField(d.metadata, {'field','magneticField','Field'});
                end

                % Y value
                switch yMetric
                    case 'Integrated Y'
                        % Sum of first Y channel
                        if ~isempty(d.values)
                            col = d.values(:, 1);
                            yVals(si) = trapz(d.time(~isnan(col)), col(~isnan(col)));
                        end
                    otherwise
                        % Peak-based metrics
                        if isempty(ds.peaks) || numel(ds.peaks) < peakIdx
                            continue;
                        end
                        % Sort peaks by center
                        centers = [ds.peaks.center];
                        [~, sortIdx] = sort(centers);
                        pk = ds.peaks(sortIdx(peakIdx));

                        switch yMetric
                            case 'Peak center', yVals(si) = pk.center;
                            case 'Peak FWHM',   yVals(si) = pk.fwhm;
                            case 'Peak area',   yVals(si) = pk.area;
                            case 'Peak height', yVals(si) = pk.height;
                        end
                end
            end

            % Plot
            outFig = figure('Name','Parameter Evolution','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            tAx = axes(outFig);
            hold(tAx, 'on'); box(tAx, 'on'); grid(tAx, 'on');
            tAx.FontSize = fmtOpts.fontSize;
            tAx.FontName = fmtOpts.fontName;
            tAx.TickDir  = 'in';

            valid = ~isnan(xVals) & ~isnan(yVals);
            if connect
                plot(tAx, xVals(valid), yVals(valid), '-o', ...
                    'Color', [0.12 0.47 0.71], ...
                    'MarkerFaceColor', [0.12 0.47 0.71], ...
                    'MarkerSize', 6, 'LineWidth', 1.5);
            else
                scatter(tAx, xVals(valid), yVals(valid), 50, ...
                    [0.12 0.47 0.71], 'filled');
            end

            % Label points with filenames if few enough
            if sum(valid) <= 15 && strcmp(xMode, 'File index')
                validIdx = find(valid);
                for vi = 1:numel(validIdx)
                    text(tAx, xVals(validIdx(vi)), yVals(validIdx(vi)), ...
                        ['  ' labels{validIdx(vi)}], ...
                        'FontSize', max(fmtOpts.fontSize-3, 6), ...
                        'Interpreter', 'none', 'Rotation', 20);
                end
            end

            % Axis labels
            xlabel(tAx, xMode, 'FontSize', fmtOpts.fontSize);
            ylabel(tAx, yMetric, 'FontSize', fmtOpts.fontSize);

            ttl = peWidgets.efTitle.Value;
            if ~isempty(ttl)
                title(tAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Broken Axis
        % ────────────────────────────────────────────────────────────────
        function generateBrokenAxis()
            di    = brWidgets.ddDS.Value;
            yName = brWidgets.ddY.Value;
            gapLo = str2double(brWidgets.efGapLo.Value);
            gapHi = str2double(brWidgets.efGapHi.Value);
            logY  = brWidgets.cbLogY.Value;
            breakAxis = brWidgets.ddBreakAxis.Value;

            if isnan(gapLo) || isnan(gapHi) || gapLo >= gapHi
                uialert(bFig, 'Enter valid Gap min < Gap max.', 'Invalid gap'); return;
            end

            d = getPlotData(di);
            idx = find(strcmp(d.labels, yName), 1);
            if isempty(idx)
                uialert(bFig, sprintf('Channel "%s" not found.', yName), 'Missing channel'); return;
            end

            xAll = d.time;
            yAll = d.values(:, idx);
            good = ~isnan(xAll) & ~isnan(yAll);
            xAll = xAll(good); yAll = yAll(good);

            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);
            xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
            yLbl = guiLabel(yName, d.units{min(idx, numel(d.units))});

            if strcmp(breakAxis, 'Y axis')
                % ── Y-axis break ────────────────────────────────────────
                bottomMask = yAll < gapLo;
                topMask    = yAll > gapHi;

                if ~any(bottomMask) || ~any(topMask)
                    uialert(bFig, 'Gap range leaves no data on one side.', 'Empty segment'); return;
                end

                % Height ratio
                ratioStr = brWidgets.ddRatio.Value;
                switch ratioStr
                    case 'Proportional'
                        rangeB = gapLo - min(yAll(bottomMask));
                        rangeT = max(yAll(topMask)) - gapHi;
                        hRatio = [rangeB rangeT];
                    case '1:1', hRatio = [1 1];
                    case '2:1', hRatio = [2 1];
                    case '1:2', hRatio = [1 2];
                    otherwise,  hRatio = [1 1];
                end
                hFrac = hRatio / sum(hRatio);

                outFig = figure('Name','Broken Y-Axis','NumberTitle','off', ...
                    'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);

                gap = 0.03;
                bot_h  = (1 - gap) * hFrac(1) * 0.72;
                top_h  = (1 - gap) * hFrac(2) * 0.72;
                bot_y  = 0.14;
                top_y  = bot_y + bot_h + gap;

                ax1 = axes(outFig, 'Position', [0.14 bot_y 0.78 bot_h]);
                ax2 = axes(outFig, 'Position', [0.14 top_y 0.78 top_h]);

                % Plot full data in both axes
                hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
                plot(ax1, xAll, yAll, ls{:}, 'Color', [0.12 0.47 0.71], ...
                    'LineWidth', fmtOpts.lineWidth);
                ax1.FontSize = fmtOpts.fontSize; ax1.FontName = fmtOpts.fontName;
                ax1.TickDir = 'in';
                ax1.YLim = [min(yAll(bottomMask))*0.95, gapLo];

                hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
                plot(ax2, xAll, yAll, ls{:}, 'Color', [0.12 0.47 0.71], ...
                    'LineWidth', fmtOpts.lineWidth);
                ax2.FontSize = fmtOpts.fontSize; ax2.FontName = fmtOpts.fontName;
                ax2.TickDir = 'in';
                ax2.YLim = [gapHi, max(yAll(topMask))*1.05];
                ax2.XTickLabel = {};

                linkaxes([ax1, ax2], 'x');

                if logY
                    ax1.YScale = 'log'; ax2.YScale = 'log';
                end

                xlabel(ax1, xLbl, 'FontSize', fmtOpts.fontSize);
                ylabel(ax1, yLbl, 'FontSize', fmtOpts.fontSize);

                ttl = brWidgets.efTitle.Value;
                if ~isempty(ttl)
                    title(ax2, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
                end

                % Draw break marks on top of bottom axes and bottom of top axes
                drawBreakMarks(ax1, 'top');
                drawBreakMarks(ax2, 'bottom');

            else
                % ── X-axis break (original behavior) ───────────────────
                leftMask  = xAll < gapLo;
                rightMask = xAll > gapHi;

                if ~any(leftMask) || ~any(rightMask)
                    uialert(bFig, 'Gap range leaves no data on one side.', 'Empty segment'); return;
                end

                xLeft = xAll(leftMask);  yLeft = yAll(leftMask);
                xRight = xAll(rightMask); yRight = yAll(rightMask);

                ratioStr = brWidgets.ddRatio.Value;
                switch ratioStr
                    case 'Proportional'
                        rangeL = max(xLeft) - min(xLeft);
                        rangeR = max(xRight) - min(xRight);
                        wRatio = [rangeL rangeR];
                    case '1:1', wRatio = [1 1];
                    case '2:1', wRatio = [2 1];
                    case '1:2', wRatio = [1 2];
                    otherwise,  wRatio = [1 1];
                end
                wFrac = wRatio / sum(wRatio);

                outFig = figure('Name','Broken Axis','NumberTitle','off', ...
                    'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);

                gap  = 0.03;
                left_w  = (1 - gap) * wFrac(1) * 0.75;
                right_w = (1 - gap) * wFrac(2) * 0.75;
                left_x  = 0.12;
                right_x = left_x + left_w + gap;

                ax1 = axes(outFig, 'Position', [left_x  0.15 left_w  0.75]);
                ax2 = axes(outFig, 'Position', [right_x 0.15 right_w 0.75]);

                hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
                plot(ax1, xLeft, yLeft, ls{:}, 'Color', [0.12 0.47 0.71], ...
                    'LineWidth', fmtOpts.lineWidth);
                ax1.FontSize = fmtOpts.fontSize; ax1.FontName = fmtOpts.fontName;
                ax1.TickDir  = 'in';
                ax1.XLim = [min(xLeft) max(xLeft)];

                hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
                plot(ax2, xRight, yRight, ls{:}, 'Color', [0.12 0.47 0.71], ...
                    'LineWidth', fmtOpts.lineWidth);
                ax2.FontSize = fmtOpts.fontSize; ax2.FontName = fmtOpts.fontName;
                ax2.TickDir  = 'in';
                ax2.XLim = [min(xRight) max(xRight)];
                ax2.YTickLabel = {};

                linkaxes([ax1, ax2], 'y');

                if logY
                    ax1.YScale = 'log'; ax2.YScale = 'log';
                end

                xlabel(ax1, xLbl, 'FontSize', fmtOpts.fontSize);
                xlabel(ax2, xLbl, 'FontSize', fmtOpts.fontSize);
                ylabel(ax1, yLbl, 'FontSize', fmtOpts.fontSize);

                ttl = brWidgets.efTitle.Value;
                if ~isempty(ttl)
                    title(ax1, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
                end

                drawBreakMarks(ax1, 'right');
                drawBreakMarks(ax2, 'left');
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        function val = extractMetaField(meta, fieldNames)
        %EXTRACTMETAFIELD  Try to extract a numeric value from metadata by field name.
            val = NaN;
            for fi = 1:numel(fieldNames)
                if isfield(meta, fieldNames{fi})
                    v = meta.(fieldNames{fi});
                    if isnumeric(v) && isscalar(v)
                        val = v; return;
                    elseif ischar(v) || isstring(v)
                        val = str2double(v);
                        if ~isnan(val), return; end
                    end
                end
            end
            % Also check parserSpecific
            if isfield(meta, 'parserSpecific')
                ps = meta.parserSpecific;
                for fi = 1:numel(fieldNames)
                    if isfield(ps, fieldNames{fi})
                        v = ps.(fieldNames{fi});
                        if isnumeric(v) && isscalar(v)
                            val = v; return;
                        end
                    end
                end
            end
        end

        function drawBreakMarks(targetAx, side)
        %DRAWBREAKMARKS  Draw diagonal break marks on the specified side of axes.
        %  side: 'left', 'right' (X-axis break), 'top', 'bottom' (Y-axis break)
            xl = targetAx.XLim;
            yl = targetAx.YLim;

            switch side
                case 'right'
                    xPos = xl(2);
                    dx = diff(xl) * 0.015;
                    yMid = mean(yl); ySpan = diff(yl) * 0.02;
                    line(targetAx, [xPos-dx xPos+dx], [yMid-ySpan*2 yMid-ySpan*0.5], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                    line(targetAx, [xPos-dx xPos+dx], [yMid+ySpan*0.5 yMid+ySpan*2], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                case 'left'
                    xPos = xl(1);
                    dx = diff(xl) * 0.015;
                    yMid = mean(yl); ySpan = diff(yl) * 0.02;
                    line(targetAx, [xPos-dx xPos+dx], [yMid-ySpan*2 yMid-ySpan*0.5], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                    line(targetAx, [xPos-dx xPos+dx], [yMid+ySpan*0.5 yMid+ySpan*2], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                case 'top'
                    yPos = yl(2);
                    dy = diff(yl) * 0.015;
                    xMid = mean(xl); xSpan = diff(xl) * 0.02;
                    line(targetAx, [xMid-xSpan*2 xMid-xSpan*0.5], [yPos-dy yPos+dy], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                    line(targetAx, [xMid+xSpan*0.5 xMid+xSpan*2], [yPos-dy yPos+dy], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                case 'bottom'
                    yPos = yl(1);
                    dy = diff(yl) * 0.015;
                    xMid = mean(xl); xSpan = diff(xl) * 0.02;
                    line(targetAx, [xMid-xSpan*2 xMid-xSpan*0.5], [yPos-dy yPos+dy], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
                    line(targetAx, [xMid+xSpan*0.5 xMid+xSpan*2], [yPos-dy yPos+dy], ...
                        'Color','k','LineWidth',1.5,'Clipping','off','HandleVisibility','off');
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Quick Grid
        % ────────────────────────────────────────────────────────────────
        function buildQuickGridConfig()
            gl = uigridlayout(configPanel, [5 4], ...
                'RowHeight', {22, '1x', 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

            % Row 1: instructions
            uilabel(gl,'Text','Select datasets — each gets its own panel:', ...
                'FontSize',9,'FontAngle','italic');
            uilabel(gl,'Text',''); uilabel(gl,'Text','');
            uilabel(gl,'Text','Y Channel:','FontSize',9,'FontWeight','bold');

            % Row 2: dataset multi-select + Y channel
            qgWidgets.lbDS = uilistbox(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Multiselect','on','Value', 1:min(nDS,4), 'FontSize', 9);
            qgWidgets.lbDS.Layout.Row = 2; qgWidgets.lbDS.Layout.Column = [1 2];

            qgWidgets.lbY = uilistbox(gl,'Items', allYLabels, 'Multiselect','on', ...
                'Value', allYLabels(1:min(1,numel(allYLabels))), 'FontSize', 9);
            qgWidgets.lbY.Layout.Row = 2; qgWidgets.lbY.Layout.Column = [3 4];

            % Row 3: rows/cols
            uilabel(gl,'Text','Rows:','HorizontalAlignment','right','FontSize',9);
            qgWidgets.spRows = uispinner(gl,'Value',2,'Limits',[1 8],'Step',1,'FontSize',9);

            uilabel(gl,'Text','Columns:','HorizontalAlignment','right','FontSize',9);
            qgWidgets.spCols = uispinner(gl,'Value',2,'Limits',[1 8],'Step',1,'FontSize',9);

            % Row 4: share options
            qgWidgets.cbShareX = uicheckbox(gl,'Text','Share X axis','Value',true,'FontSize',9);
            qgWidgets.cbShareX.Layout.Row = 4; qgWidgets.cbShareX.Layout.Column = [1 2];

            qgWidgets.cbShareY = uicheckbox(gl,'Text','Share Y scale','Value',false,'FontSize',9);
            qgWidgets.cbShareY.Layout.Row = 4; qgWidgets.cbShareY.Layout.Column = [3 4];

            % Row 5: log Y, auto-fill mode
            qgWidgets.cbLogY = uicheckbox(gl,'Text','Log Y','Value',false,'FontSize',9);
            qgWidgets.cbLogY.Layout.Row = 5; qgWidgets.cbLogY.Layout.Column = 1;

            uilabel(gl,'Text','Titles:','HorizontalAlignment','right','FontSize',9);
            qgWidgets.ddTitleMode = uidropdown(gl, ...
                'Items', {'Filename','None','Channel name'}, ...
                'Value', 'Filename', 'FontSize', 9);

            uilabel(gl,'Text','Empty cells:','HorizontalAlignment','right','FontSize',9);
            qgWidgets.ddEmpty = uidropdown(gl, ...
                'Items', {'Leave blank','Hide axes'}, ...
                'Value', 'Leave blank', 'FontSize', 9);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Quick Grid
        % ────────────────────────────────────────────────────────────────
        function generateQuickGrid()
            dsIdx = ensureCellNum(qgWidgets.lbDS.Value);
            selY  = ensureCellStr(qgWidgets.lbY.Value);
            nR    = qgWidgets.spRows.Value;
            nC    = qgWidgets.spCols.Value;
            shareX = qgWidgets.cbShareX.Value;
            shareY = qgWidgets.cbShareY.Value;
            logY   = qgWidgets.cbLogY.Value;
            titleMode = qgWidgets.ddTitleMode.Value;
            emptyMode = qgWidgets.ddEmpty.Value;

            nPanels = nR * nC;
            nSel    = numel(dsIdx);

            if nSel == 0
                uialert(bFig,'Select at least one dataset.','No data'); return;
            end

            [outFig, tlo] = makeOutFig(nR, nC, shareX);
            fmtOpts = getFormatOpts();
            ls = localLineSpec(ddBStyle.Value);

            allAxes = gobjects(1, nPanels);

            for pi = 1:nPanels
                tAx = nexttile(tlo, pi);

                % If more panels than datasets, handle empty cells
                if pi > nSel
                    if strcmp(emptyMode, 'Hide axes')
                        tAx.Visible = 'off';
                    end
                    allAxes(pi) = tAx;
                    continue;
                end

                setupAx(tAx);
                allAxes(pi) = tAx;

                di = dsIdx(pi);
                d  = getPlotData(di);
                xVec = d.time;
                xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));

                nTraces = max(numel(selY), 1);
                if fmtOpts.grayscale
                    clrs = repmat(linspace(0, 0.7, nTraces)', 1, 3);
                else
                    clrs = getColorsFromMap('lines (MATLAB default)', nTraces);
                end

                yLbl = '';
                for ki = 1:numel(selY)
                    yName = selY{ki};
                    idx = find(strcmp(d.labels, yName), 1);
                    if isempty(idx), continue; end

                    yVec = d.values(:, idx);
                    good = ~isnan(xVec) & ~isnan(yVec);
                    if isdatetime(xVec), good = ~isnat(xVec) & ~isnan(yVec); end

                    if isempty(yLbl) && idx <= numel(d.units)
                        yLbl = guiLabel(yName, d.units{idx});
                    end

                    dName = yName;

                    % Error handling
                    errIdx = findErrorColumn(d.labels, yName);
                    if ~isempty(errIdx) && ~strcmp(fmtOpts.errorStyle, 'None')
                        yErr = d.values(:, errIdx);
                        yErrG = yErr(good);
                        xG = xVec(good); yG = yVec(good);

                        if strcmp(fmtOpts.errorStyle, 'Error Band')
                            fill(tAx, [xG; flipud(xG)], ...
                                [yG + yErrG; flipud(yG - yErrG)], ...
                                clrs(ki,:), 'FaceAlpha', 0.2, ...
                                'EdgeColor', 'none', 'HandleVisibility', 'off');
                            plot(tAx, xG, yG, ls{:}, ...
                                'Color', clrs(ki,:), ...
                                'LineWidth', fmtOpts.lineWidth, ...
                                'DisplayName', dName);
                        else
                            errorbar(tAx, xG, yG, yErrG, ...
                                'Color', clrs(ki,:), ...
                                'LineWidth', max(fmtOpts.lineWidth-0.5, 0.75), ...
                                'CapSize', 3, 'DisplayName', dName);
                        end
                    else
                        plot(tAx, xVec(good), yVec(good), ls{:}, ...
                            'Color', clrs(ki,:), ...
                            'LineWidth', fmtOpts.lineWidth, ...
                            'DisplayName', dName);
                    end
                end

                if logY, tAx.YScale = 'log'; end

                % Labels — suppress X on non-bottom rows when sharing
                [panelRow, ~] = ind2sub([nR, nC], pi);
                if shareX && panelRow < nR
                    xlabel(tAx, '');
                else
                    xlabel(tAx, xLbl, 'FontSize', fmtOpts.fontSize);
                end

                % Suppress Y on non-left columns when sharing
                [~, panelCol] = ind2sub([nR, nC], pi);
                if shareY && panelCol > 1
                    ylabel(tAx, '');
                else
                    ylabel(tAx, yLbl, 'FontSize', fmtOpts.fontSize);
                end

                % Title
                switch titleMode
                    case 'Filename'
                        title(tAx, dsNames{di}, 'FontSize', fmtOpts.fontSize, 'Interpreter', 'none');
                    case 'Channel name'
                        if ~isempty(selY)
                            title(tAx, strjoin(selY, ', '), 'FontSize', fmtOpts.fontSize, 'Interpreter', 'none');
                        end
                    % 'None' — no title
                end

                % Legend only if multiple Y channels
                if numel(selY) > 1
                    legend(tAx,'Interpreter','none','FontSize',max(fmtOpts.fontSize-2,6),'Location','best');
                end
            end

            linkIfNeeded(allAxes(1:min(nSel,nPanels)), shareX, shareY);
            addRefLineTools(outFig);
            addLinkedCursor(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ════════════════════════════════════════════════════════════════
        %  Shared helpers (nested inside the builder)
        % ════════════════════════════════════════════════════════════════

        function d = getPlotData(dsIdx)
        %GETPLOTDATA  Return corrected data if available, else raw.
            ds = datasets{dsIdx};
            if ~isempty(ds.corrData)
                d = ds.corrData;
            else
                d = ds.data;
            end
        end

        function fmtOpts = getFormatOpts()
        %GETFORMATOPTS  Gather global formatting options into a struct.
            fmtOpts.fontSize  = spFont.Value;
            fmtOpts.fontName  = ddFontName.Value;
            fmtOpts.lineWidth = 1.5;
            fmtOpts.grayscale = cbGrayscale.Value;
            fmtOpts.errorStyle = ddErrorStyle.Value;
        end

        function [outFig, tlo] = makeOutFig(nR, nC, shareX)
        %MAKEOUTFIG  Create a figure + tiledlayout with the global dimensions.
            outFig = figure('Name','Figure','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            spacing = 'loose';
            if shareX, spacing = 'compact'; end
            tlo = tiledlayout(outFig, nR, nC, ...
                'TileSpacing', spacing, 'Padding', 'compact');
        end

        function setupAx(tAx)
        %SETUPAX  Apply consistent base styling to an axes.
            hold(tAx, 'on'); box(tAx, 'on'); grid(tAx, 'on');
            fmtOpts = getFormatOpts();
            tAx.FontSize = fmtOpts.fontSize;
            tAx.FontName = fmtOpts.fontName;
            tAx.TickDir  = 'in';
        end

        function [ci, xLbl, yLbl] = plotTraces(tAx, dsIdx, selY, ls, fmtOpts)
        %PLOTTRACES  Plot dataset/channel pairs into an axes. Returns trace count + labels.
            nTraces = max(numel(dsIdx) * numel(selY), 1);
            if fmtOpts.grayscale
                clrs = repmat(linspace(0, 0.7, nTraces)', 1, 3);
            else
                clrs = getColorsFromMap('lines (MATLAB default)', nTraces);
            end

            % Grayscale: cycle line styles and marker shapes for distinguishability
            GS_STYLES  = {'-', '--', ':', '-.'};
            GS_MARKERS = {'o', 's', '^', 'd', 'v', '>', '<', 'p'};

            ci = 0; xLbl = ''; yLbl = '';

            for si = 1:numel(dsIdx)
                di = dsIdx(si);
                if di < 1 || di > nDS, continue; end
                d = getPlotData(di);
                xVec = d.time;
                if isempty(xLbl)
                    xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
                end

                fileSuffix = '';
                if numel(dsIdx) > 1
                    fileSuffix = sprintf('  (%s)', dsNames{di});
                end

                for ki = 1:numel(selY)
                    yName = selY{ki};
                    idx = find(strcmp(d.labels, yName), 1);
                    if isempty(idx), continue; end

                    ci = ci + 1;
                    yVec = d.values(:, idx);
                    dName = [yName, fileSuffix];

                    if isempty(yLbl) && idx <= numel(d.units)
                        yLbl = guiLabel(yName, d.units{idx});
                    end

                    good = ~isnan(xVec) & ~isnan(yVec);
                    if isdatetime(xVec), good = ~isnat(xVec) & ~isnan(yVec); end

                    baseColor = clrs(min(ci, size(clrs,1)), :);

                    % Build line spec — override with grayscale variation
                    plotLS = ls;
                    if fmtOpts.grayscale
                        gsStyle  = GS_STYLES{mod(ci-1, numel(GS_STYLES)) + 1};
                        gsMarker = GS_MARKERS{mod(ci-1, numel(GS_MARKERS)) + 1};
                        plotLS = {'LineStyle', gsStyle, 'Marker', gsMarker, 'MarkerSize', 4};
                    end

                    % Error handling — check asymmetric first, then symmetric
                    [errLoIdx, errHiIdx] = findAsymmetricErrorColumns(d.labels, yName);
                    errIdx = findErrorColumn(d.labels, yName);
                    hasAsymErr = ~isempty(errLoIdx) && ~isempty(errHiIdx);
                    hasSymErr  = ~isempty(errIdx);

                    if (hasAsymErr || hasSymErr) && ~strcmp(fmtOpts.errorStyle, 'None')
                        xG = xVec(good); yG = yVec(good);

                        if hasAsymErr
                            errLo = abs(d.values(good, errLoIdx));
                            errHi = abs(d.values(good, errHiIdx));
                        else
                            yErr = d.values(good, errIdx);
                            errLo = abs(yErr);
                            errHi = abs(yErr);
                        end

                        if strcmp(fmtOpts.errorStyle, 'Error Band')
                            fill(tAx, [xG; flipud(xG)], ...
                                [yG + errHi; flipud(yG - errLo)], ...
                                baseColor, 'FaceAlpha', 0.2, ...
                                'EdgeColor', 'none', ...
                                'HandleVisibility', 'off');
                            plot(tAx, xG, yG, plotLS{:}, ...
                                'Color', baseColor, ...
                                'LineWidth', fmtOpts.lineWidth, ...
                                'DisplayName', dName);
                        else  % Error Bars (supports asymmetric via errorbar neg/pos args)
                            errorbar(tAx, xG, yG, errLo, errHi, ...
                                'Color', baseColor, ...
                                'LineWidth', max(fmtOpts.lineWidth - 0.5, 0.75), ...
                                'CapSize', 3, ...
                                'DisplayName', dName);
                        end
                    else
                        plot(tAx, xVec(good), yVec(good), plotLS{:}, ...
                            'Color', baseColor, ...
                            'LineWidth', fmtOpts.lineWidth, ...
                            'DisplayName', dName);
                    end
                end
            end
        end

        function linkIfNeeded(allAxes, shareX, shareY)
        %LINKIFNEEDED  Link axes array for shared X/Y.
            validAx = allAxes(isvalid(allAxes));
            if numel(validAx) < 2, return; end
            if shareX && shareY
                linkaxes(validAx, 'xy');
            elseif shareX
                linkaxes(validAx, 'x');
            elseif shareY
                linkaxes(validAx, 'y');
            end
        end

        function v = ensureCellNum(val)
        %ENSURECELLNUM  Normalise listbox value to numeric vector.
            if ~iscell(val), val = {val}; end
            v = cell2mat(val);
        end

        function v = ensureCellStr(val)
        %ENSURECELLSTR  Normalise listbox value to cell array of char.
            if ischar(val), v = {val};
            elseif isstring(val), v = cellstr(val);
            elseif iscell(val), v = val;
            else, v = {char(val)};
            end
        end

        function addRefLineTools(outFig)
        %ADDREFLINETOOLS  Add reference-line, region, annotation, and peak-label buttons.
            tb = findall(outFig, 'Type', 'uitoolbar');
            if isempty(tb)
                tb = uitoolbar(outFig);
            else
                tb = tb(1);
            end

            uipushtool(tb, 'Tooltip', 'Add H reference line', ...
                'ClickedCallback', @(~,~) addHRefLine(outFig));
            uipushtool(tb, 'Tooltip', 'Add V reference line', ...
                'ClickedCallback', @(~,~) addVRefLine(outFig));
            uipushtool(tb, 'Tooltip', 'Add shaded region', ...
                'ClickedCallback', @(~,~) addShadedRegion(outFig));
            uipushtool(tb, 'Tooltip', 'Add text annotation', ...
                'ClickedCallback', @(~,~) addTextAnnotation(outFig));
            uipushtool(tb, 'Tooltip', 'Add arrow annotation', ...
                'ClickedCallback', @(~,~) addArrowAnnotation(outFig));
            uipushtool(tb, 'Tooltip', 'Add peak labels from active dataset', ...
                'ClickedCallback', @(~,~) addPeakLabels(outFig));
            uipushtool(tb, 'Tooltip', 'Add inset zoom', ...
                'ClickedCallback', @(~,~) addInsetZoom(outFig));
            % ── Template tools ──
            uipushtool(tb, 'Tooltip', 'Save as Template', ...
                'ClickedCallback', @(~,~) onSaveTemplate(outFig));
            uipushtool(tb, 'Tooltip', 'Apply Template', ...
                'ClickedCallback', @(~,~) onApplyTemplate(outFig));
        end

        function onSaveTemplate(outFig)
        %ONSAVETEMPLATE  Save current figure style as a reusable template.
            axList = findobj(outFig, 'Type', 'axes');
            if isempty(axList), return; end
            plotting.templateDialog(axList(1), 'save');
        end

        function onApplyTemplate(outFig)
        %ONAPPLYTEMPLATE  Open Apply Template dialog for the first axes of outFig.
            axList = findobj(outFig, 'Type', 'axes');
            if isempty(axList), return; end
            plotting.templateDialog(axList(1), 'apply');
        end

        function addHRefLine(outFig)
        %ADDHREFLINE  Prompt for Y value and add horizontal reference line.
            answer = inputdlg({'Y value:', 'Label (optional):'}, 'H Reference Line', [1 40], {'0',''});
            if isempty(answer), return; end
            yVal = str2double(answer{1});
            if isnan(yVal), return; end
            lbl = strtrim(answer{2});
            tAx = gca(outFig);
            if isempty(lbl)
                yline(tAx, yVal, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
                    'HandleVisibility', 'off');
            else
                yline(tAx, yVal, '--', lbl, 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
                    'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
            end
        end

        function addVRefLine(outFig)
        %ADDVREFLINE  Prompt for X value and add vertical reference line.
            answer = inputdlg({'X value:', 'Label (optional):'}, 'V Reference Line', [1 40], {'0',''});
            if isempty(answer), return; end
            xVal = str2double(answer{1});
            if isnan(xVal), return; end
            lbl = strtrim(answer{2});
            tAx = gca(outFig);
            if isempty(lbl)
                xline(tAx, xVal, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
                    'HandleVisibility', 'off');
            else
                xline(tAx, xVal, '--', lbl, 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
                    'LabelHorizontalAlignment', 'right', 'HandleVisibility', 'off');
            end
        end

        function addShadedRegion(outFig)
        %ADDSHADEDREGION  Prompt for X range and shade that region.
            answer = inputdlg({'X min:', 'X max:', 'Label (optional):', 'Color (r/g/b/y/c):'}, ...
                'Shaded Region', [1 40], {'','','','b'});
            if isempty(answer), return; end
            x1 = str2double(answer{1}); x2 = str2double(answer{2});
            if isnan(x1) || isnan(x2), return; end
            lbl = strtrim(answer{3});
            colorChar = lower(strtrim(answer{4}));

            colorMap = struct('r',[1 0.2 0.2],'g',[0.2 0.8 0.2],'b',[0.2 0.4 0.9], ...
                'y',[0.9 0.8 0.2],'c',[0.2 0.7 0.8]);
            if isfield(colorMap, colorChar)
                c = colorMap.(colorChar);
            else
                c = [0.2 0.4 0.9];
            end

            tAx = gca(outFig);
            yl = tAx.YLim;
            patch(tAx, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], c, ...
                'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
            if ~isempty(lbl)
                text(tAx, (x1+x2)/2, yl(2), lbl, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'top', ...
                    'FontSize', 8, 'Color', c * 0.7);
            end
        end

        function addTextAnnotation(outFig)
        %ADDTEXTANNOTATION  Prompt for text and position, place on active axes.
            answer = inputdlg({'Text:', 'X position:', 'Y position:', 'Font size:'}, ...
                'Text Annotation', [1 40], {'Label', '', '', '10'});
            if isempty(answer), return; end
            txt = answer{1};
            xPos = str2double(answer{2});
            yPos = str2double(answer{3});
            fSz  = str2double(answer{4});
            if isnan(fSz), fSz = 10; end

            tAx = gca(outFig);
            if isnan(xPos) || isnan(yPos)
                % Place at center of axes if no position given
                xl = tAx.XLim; yl = tAx.YLim;
                xPos = mean(xl); yPos = mean(yl);
            end
            text(tAx, xPos, yPos, txt, ...
                'FontSize', fSz, 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'w', 'EdgeColor', [0.5 0.5 0.5], ...
                'Margin', 2, 'HandleVisibility', 'off');
        end

        function addArrowAnnotation(outFig)
        %ADDARROWANNOTATION  Prompt for arrow endpoints and label, then draw.
            answer = inputdlg({'Label:', 'Arrow X start:', 'Arrow Y start:', ...
                'Arrow X end (tip):', 'Arrow Y end (tip):'}, ...
                'Arrow Annotation', [1 40], {'', '', '', '', ''});
            if isempty(answer), return; end
            lbl = answer{1};
            x1 = str2double(answer{2}); y1 = str2double(answer{3});
            x2 = str2double(answer{4}); y2 = str2double(answer{5});
            if any(isnan([x1 y1 x2 y2])), return; end

            % Convert data coords to normalized figure coords
            tAx = gca(outFig);
            % Get axes position in normalized figure units
            axPos = getpixelposition(tAx, true);
            figPos = getpixelposition(outFig);
            % Map data → pixels → normalized
            xPix1 = axPos(1) + (x1 - tAx.XLim(1)) / diff(tAx.XLim) * axPos(3);
            yPix1 = axPos(2) + (y1 - tAx.YLim(1)) / diff(tAx.YLim) * axPos(4);
            xPix2 = axPos(1) + (x2 - tAx.XLim(1)) / diff(tAx.XLim) * axPos(3);
            yPix2 = axPos(2) + (y2 - tAx.YLim(1)) / diff(tAx.YLim) * axPos(4);

            xNorm = [xPix1 xPix2] / figPos(3);
            yNorm = [yPix1 yPix2] / figPos(4);

            if isempty(lbl)
                annotation(outFig, 'arrow', xNorm, yNorm, 'Color', [0.3 0.3 0.3]);
            else
                annotation(outFig, 'textarrow', xNorm, yNorm, ...
                    'String', lbl, 'FontSize', 9, 'Color', [0.3 0.3 0.3]);
            end
        end

        function addPeakLabels(~)
        %ADDPEAKLABELS  Read peaks from the active dataset and label them on the plot.
            if isempty(datasets) || activeIdx < 1, return; end
            ds = datasets{activeIdx};
            if isempty(ds.peaks)
                msgbox('No peaks detected on the active dataset. Run peak detection first.', ...
                    'No Peaks', 'warn');
                return;
            end

            % Choose label mode
            answer = inputdlg({'Label mode (center / fwhm / hkl):'}, ...
                'Peak Labels', [1 40], {'center'});
            if isempty(answer), return; end
            mode = lower(strtrim(answer{1}));

            tAx = gca;
            yl = tAx.YLim;
            yRange = diff(yl);
            peaks = ds.peaks;

            for pk = 1:numel(peaks)
                xc = peaks(pk).center;
                yc = peaks(pk).height;

                switch mode
                    case 'fwhm'
                        lbl = sprintf('%.2f\n(%.3f)', xc, peaks(pk).fwhm);
                    case 'hkl'
                        if isfield(peaks(pk), 'hkl') && ~isempty(peaks(pk).hkl)
                            lbl = peaks(pk).hkl;
                        else
                            lbl = sprintf('%.2f', xc);
                        end
                    otherwise  % 'center'
                        lbl = sprintf('%.2f', xc);
                end

                % Smart vertical offset: stagger odd/even peaks
                if mod(pk, 2) == 0
                    yOff = yRange * 0.06;
                else
                    yOff = yRange * 0.03;
                end

                % Marker
                plot(tAx, xc, yc, 'v', 'MarkerSize', 6, ...
                    'MarkerFaceColor', [0.8 0.2 0.2], ...
                    'MarkerEdgeColor', 'none', ...
                    'HandleVisibility', 'off', ...
                    'Tag', 'FigBuilderPeakMarker');

                % Label
                text(tAx, xc, yc + yOff, lbl, ...
                    'FontSize', 7, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', ...
                    'Color', [0.6 0.1 0.1], ...
                    'HandleVisibility', 'off', ...
                    'Tag', 'FigBuilderPeakLabel');
            end
        end

        function addInsetZoom(outFig)
        %ADDINSETZOOM  Create an inset axes showing a zoomed region of the active panel.
            tAx = gca(outFig);
            xl = tAx.XLim; yl = tAx.YLim;
            answer = inputdlg( ...
                {'X min:', 'X max:', 'Y min:', 'Y max:', 'Inset position (tl/tr/bl/br):'}, ...
                'Inset Zoom', [1 40], ...
                {num2str(xl(1)), num2str(xl(2)), num2str(yl(1)), num2str(yl(2)), 'tr'});
            if isempty(answer), return; end
            xLo = str2double(answer{1}); xHi = str2double(answer{2});
            yLo = str2double(answer{3}); yHi = str2double(answer{4});
            posStr = lower(strtrim(answer{5}));
            if any(isnan([xLo xHi yLo yHi])), return; end

            % Determine inset position (normalized within axes)
            axPos = tAx.Position;  % [x y w h] in normalized figure units
            inW = axPos(3) * 0.35;
            inH = axPos(4) * 0.35;
            pad = 0.02;
            switch posStr
                case 'tl'
                    inPos = [axPos(1)+pad, axPos(2)+axPos(4)-inH-pad, inW, inH];
                case 'bl'
                    inPos = [axPos(1)+pad, axPos(2)+pad, inW, inH];
                case 'br'
                    inPos = [axPos(1)+axPos(3)-inW-pad, axPos(2)+pad, inW, inH];
                otherwise  % 'tr'
                    inPos = [axPos(1)+axPos(3)-inW-pad, axPos(2)+axPos(4)-inH-pad, inW, inH];
            end

            % Create inset axes and copy data from main axes
            inAx = axes(outFig, 'Position', inPos);
            box(inAx, 'on'); grid(inAx, 'on');
            inAx.FontSize = max(tAx.FontSize - 2, 6);
            hold(inAx, 'on');

            % Copy line objects from the main axes
            lineObjs = findobj(tAx, 'Type', 'line');
            for li = 1:numel(lineObjs)
                lo = lineObjs(li);
                plot(inAx, lo.XData, lo.YData, ...
                    'Color', lo.Color, ...
                    'LineStyle', lo.LineStyle, ...
                    'LineWidth', lo.LineWidth, ...
                    'Marker', lo.Marker, ...
                    'MarkerSize', lo.MarkerSize, ...
                    'HandleVisibility', 'off');
            end

            inAx.XLim = [xLo xHi];
            inAx.YLim = [yLo yHi];
            inAx.YScale = tAx.YScale;
            legend(inAx, 'off');

            % Draw a rectangle on the main axes indicating the zoomed region
            patch(tAx, [xLo xHi xHi xLo], [yLo yLo yHi yHi], 'k', ...
                'FaceAlpha', 0, 'EdgeColor', [0.5 0.5 0.5], ...
                'LineStyle', '--', 'LineWidth', 0.75, ...
                'HandleVisibility', 'off');
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Confidence Band
        % ────────────────────────────────────────────────────────────────
        function buildConfidenceBandConfig()
            gl = uigridlayout(configPanel, [4 4], ...
                'RowHeight', {22, '1x', 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Select 2+ datasets:','FontSize',9, ...
                'FontAngle','italic','FontWeight','bold');
            uilabel(gl,'Text',''); uilabel(gl,'Text','');
            uilabel(gl,'Text','Y Channel:','FontSize',9,'FontWeight','bold');

            cbWidgets.lbDS = uilistbox(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Multiselect', 'on', 'FontSize', 9);
            cbWidgets.lbDS.Layout.Row = 2; cbWidgets.lbDS.Layout.Column = [1 2];

            cbWidgets.ddY = uidropdown(gl,'Items', allYLabels, ...
                'Value', allYLabels{1}, 'FontSize', 9);
            cbWidgets.ddY.Layout.Row = 2; cbWidgets.ddY.Layout.Column = [3 4];

            % Options row
            uilabel(gl,'Text','Method:','HorizontalAlignment','right','FontSize',9);
            cbWidgets.ddMethod = uidropdown(gl, ...
                'Items', {'Mean ± Std','Median ± IQR'}, ...
                'Value', 'Mean ± Std', 'FontSize', 9);

            cbWidgets.cbLogY = uicheckbox(gl,'Text','Log Y','Value',false,'FontSize',9);
            uilabel(gl,'Text','');

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            cbWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            cbWidgets.efTitle.Layout.Column = [2 4];

            uilabel(gl,'Text','Band color:','HorizontalAlignment','right','FontSize',9);
            cbWidgets.ddColor = uidropdown(gl, ...
                'Items', {'Blue','Red','Green','Orange','Purple','Gray'}, ...
                'Value', 'Blue', 'FontSize', 9);
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Confidence Band
        % ────────────────────────────────────────────────────────────────
        function generateConfidenceBand()
            dsIdx = ensureCellNum(cbWidgets.lbDS.Value);
            if numel(dsIdx) < 2
                uialert(bFig, 'Select at least 2 datasets.', 'Too few'); return;
            end

            yName  = cbWidgets.ddY.Value;
            method = cbWidgets.ddMethod.Value;
            logY   = cbWidgets.cbLogY.Value;

            % Gather datasets and find the right channel
            cellDS = cell(1, numel(dsIdx));
            for si = 1:numel(dsIdx)
                d = getPlotData(dsIdx(si));
                chIdx = find(strcmp(d.labels, yName), 1);
                if isempty(chIdx), chIdx = 1; end
                cellDS{si} = d;
            end

            % Compute band
            switch method
                case 'Mean ± Std',   mStr = 'mean';
                case 'Median ± IQR', mStr = 'median';
                otherwise,           mStr = 'mean';
            end

            chIdx = find(strcmp(cellDS{1}.labels, yName), 1);
            if isempty(chIdx), chIdx = 1; end

            band = utilities.confidenceBand(cellDS, 'Method', mStr, 'Channel', chIdx);

            % Color map
            colorMap = struct('Blue',[0.12 0.47 0.71], 'Red',[0.84 0.15 0.16], ...
                'Green',[0.17 0.63 0.17], 'Orange',[1.0 0.5 0.05], ...
                'Purple',[0.58 0.40 0.74], 'Gray',[0.5 0.5 0.5]);
            cName = cbWidgets.ddColor.Value;
            if isfield(colorMap, cName)
                col = colorMap.(cName);
            else
                col = [0.12 0.47 0.71];
            end

            fmtOpts = getFormatOpts();

            outFig = figure('Name','Confidence Band','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            oAx = axes(outFig);
            hold(oAx, 'on'); box(oAx, 'on'); grid(oAx, 'on');

            % Shaded band
            xFill = [band.x; flipud(band.x)];
            yFill = [band.upper; flipud(band.lower)];
            fill(oAx, xFill, yFill, col, 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');

            % Center line
            plot(oAx, band.x, band.center, '-', 'Color', col, ...
                'LineWidth', fmtOpts.lineWidth, ...
                'DisplayName', sprintf('%s (n=%d)', method, band.nSets));

            if logY, oAx.YScale = 'log'; end
            oAx.FontSize = fmtOpts.fontSize;
            oAx.FontName = fmtOpts.fontName;
            oAx.TickDir = 'in';

            % Labels
            d1 = getPlotData(dsIdx(1));
            xLbl = guiLabel(guiXName(d1.metadata), guiXUnit(d1.metadata));
            yLbl = guiLabel(yName, d1.units{min(chIdx, numel(d1.units))});
            xlabel(oAx, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(oAx, yLbl, 'FontSize', fmtOpts.fontSize);
            legend(oAx, 'Location', 'best', 'FontSize', max(6, fmtOpts.fontSize-2));

            ttl = cbWidgets.efTitle.Value;
            if ~isempty(ttl)
                title(oAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            end

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Contour / Heatmap
        % ────────────────────────────────────────────────────────────────
        ctWidgets = struct();

        function buildContourConfig()
            gl = uigridlayout(configPanel, [7 2], ...
                'RowHeight', {24, 24, 24, 24, 24, 24, 24}, ...
                'ColumnWidth', {110, '1x'}, ...
                'Padding', [8 6 8 6], 'RowSpacing', 4);

            nDS = numel(datasets);
            dsNames2 = cell(1, nDS);
            for ki = 1:nDS
                [~, fn3, fx3] = fileparts(datasets{ki}.filepath);
                dsNames2{ki} = [fn3, fx3];
            end

            uilabel(gl, 'Text', 'Dataset:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
            ctWidgets.ddDS = uidropdown(gl, 'Items', dsNames2, 'ItemsData', 1:nDS, ...
                'Value', min(activeIdx, nDS), ...
                'ValueChangedFcn', @(~,~) updateContourCols());

            uilabel(gl, 'Text', 'X column:', 'HorizontalAlignment', 'right');
            ctWidgets.ddXCol = uidropdown(gl, 'Items', {'--'}, 'ItemsData', 0);

            uilabel(gl, 'Text', 'Y column:', 'HorizontalAlignment', 'right');
            ctWidgets.ddYCol = uidropdown(gl, 'Items', {'--'}, 'ItemsData', 0);

            uilabel(gl, 'Text', 'Z column:', 'HorizontalAlignment', 'right');
            ctWidgets.ddZCol = uidropdown(gl, 'Items', {'--'}, 'ItemsData', 0);

            uilabel(gl, 'Text', 'Plot style:', 'HorizontalAlignment', 'right');
            ctWidgets.ddStyle = uidropdown(gl, ...
                'Items', {'Filled contour', 'Contour lines', 'Pseudocolor (pcolor)', 'Surface (3D)'}, ...
                'Value', 'Filled contour');

            uilabel(gl, 'Text', 'Colormap:', 'HorizontalAlignment', 'right');
            ctWidgets.ddCmap = uidropdown(gl, ...
                'Items', {'parula','viridis','plasma','inferno','hot','jet','turbo','gray','bone','copper'}, ...
                'Value', 'parula');

            uilabel(gl, 'Text', '');  % spacer
            btnExportGrid = uibutton(gl, 'Text', 'Export Grid CSV...', ...
                'BackgroundColor', BTN_EXPORT, 'FontColor', [1 1 1], ...
                'FontSize', 9, ...
                'ButtonPushedFcn', @(~,~) exportContourGrid(), ...
                'Tooltip', 'Export the interpolated grid as XYZ CSV');
            btnExportGrid.Layout.Row = 7; btnExportGrid.Layout.Column = 2;

            updateContourCols();
        end

        function updateContourCols()
            dsIdx2 = ctWidgets.ddDS.Value;
            d2 = getPlotData(dsIdx2);
            allCols = [{'X (time/index)'}, d2.labels];
            idxData = 0:numel(d2.labels);
            ctWidgets.ddXCol.Items = allCols;  ctWidgets.ddXCol.ItemsData = idxData;
            ctWidgets.ddYCol.Items = allCols;  ctWidgets.ddYCol.ItemsData = idxData;
            ctWidgets.ddZCol.Items = allCols;  ctWidgets.ddZCol.ItemsData = idxData;
            if numel(d2.labels) >= 2
                ctWidgets.ddXCol.Value = 0;
                ctWidgets.ddYCol.Value = 1;
                ctWidgets.ddZCol.Value = min(2, numel(d2.labels));
            end
        end

        function exportContourGrid()
        %EXPORTCONTOURGRID  Interpolate and export XYZ grid as CSV.
            dsIdx2 = ctWidgets.ddDS.Value;
            d2 = getPlotData(dsIdx2);
            xIdx = ctWidgets.ddXCol.Value; yIdx = ctWidgets.ddYCol.Value; zIdx = ctWidgets.ddZCol.Value;
            if xIdx == 0, xV = d2.time(:); else, xV = d2.values(:,xIdx); end
            if yIdx == 0, yV = d2.time(:); else, yV = d2.values(:,yIdx); end
            if zIdx == 0, zV = d2.time(:); else, zV = d2.values(:,zIdx); end
            ok = ~isnan(xV) & ~isnan(yV) & ~isnan(zV);
            xV = xV(ok); yV = yV(ok); zV = zV(ok);
            if numel(xV) < 4, uialert(bFig, 'Not enough data.', 'Export'); return; end
            nG = 100;
            xL = linspace(min(xV),max(xV),nG); yL = linspace(min(yV),max(yV),nG);
            [Xg2, Yg2] = meshgrid(xL, yL);
            try F3 = scatteredInterpolant(xV,yV,zV,'linear','none'); Zg2 = F3(Xg2,Yg2);
            catch, Zg2 = griddata(xV,yV,zV,Xg2,Yg2,'linear'); end %#ok<GRIDD>
            [fn2,fp2] = uiputfile({'*.csv','CSV'},'Export Grid');
            if isequal(fn2,0), return; end
            fid = fopen(fullfile(fp2,fn2),'w');
            fprintf(fid, 'X,Y,Z\n');
            for ri = 1:nG
                for ci = 1:nG
                    if ~isnan(Zg2(ri,ci))
                        fprintf(fid, '%.6g,%.6g,%.6g\n', Xg2(ri,ci), Yg2(ri,ci), Zg2(ri,ci));
                    end
                end
            end
            fclose(fid);
        end

        function generateContour()
            dsIdx2 = ctWidgets.ddDS.Value;
            d2 = getPlotData(dsIdx2);
            fmtOpts = getFormatOpts();

            xIdx = ctWidgets.ddXCol.Value;
            yIdx = ctWidgets.ddYCol.Value;
            zIdx = ctWidgets.ddZCol.Value;

            if xIdx == 0, xVec = d2.time(:); else, xVec = d2.values(:, xIdx); end
            if yIdx == 0, yVec = d2.time(:); else, yVec = d2.values(:, yIdx); end
            if zIdx == 0, zVec = d2.time(:); else, zVec = d2.values(:, zIdx); end

            valid2 = ~isnan(xVec) & ~isnan(yVec) & ~isnan(zVec);
            xVec = xVec(valid2); yVec = yVec(valid2); zVec = zVec(valid2);

            if numel(xVec) < 4
                uialert(bFig, 'Not enough valid data points.', 'Contour Error');
                return;
            end

            % Grid scattered data
            nGrid = min(200, round(sqrt(numel(xVec)) * 2));
            xLin = linspace(min(xVec), max(xVec), nGrid);
            yLin = linspace(min(yVec), max(yVec), nGrid);
            [Xg, Yg] = meshgrid(xLin, yLin);
            try
                F2 = scatteredInterpolant(xVec, yVec, zVec, 'linear', 'none');
                Zg = F2(Xg, Yg);
            catch
                Zg = griddata(xVec, yVec, zVec, Xg, Yg, 'linear'); %#ok<GRIDD>
            end

            outFig = figure('Name', 'Contour / Heatmap', 'NumberTitle', 'off', ...
                'Units', 'inches', 'Position', [2 2 spBFigW.Value spBFigH.Value]);
            oAx = axes(outFig);

            cmapFcn = str2func(ctWidgets.ddCmap.Value);
            switch ctWidgets.ddStyle.Value
                case 'Filled contour'
                    contourf(oAx, Xg, Yg, Zg, 20, 'LineStyle', 'none');
                    colorbar(oAx);
                case 'Contour lines'
                    [C2, h2] = contour(oAx, Xg, Yg, Zg, 15);
                    clabel(C2, h2, 'FontSize', max(6, fmtOpts.fontSize-2));
                    colorbar(oAx);
                case 'Pseudocolor (pcolor)'
                    pcolor(oAx, Xg, Yg, Zg); shading(oAx, 'flat'); colorbar(oAx);
                case 'Surface (3D)'
                    surf(oAx, Xg, Yg, Zg, 'EdgeColor', 'none'); colorbar(oAx);
                    view(oAx, -37.5, 30); rotate3d(outFig, 'on');
            end
            colormap(oAx, cmapFcn(256));

            allCols = [{'X'}, d2.labels];
            xlabel(oAx, allCols{xIdx+1}, 'FontSize', fmtOpts.fontSize, 'Interpreter', 'none');
            ylabel(oAx, allCols{yIdx+1}, 'FontSize', fmtOpts.fontSize, 'Interpreter', 'none');
            title(oAx, allCols{zIdx+1}, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');
            oAx.FontSize = fmtOpts.fontSize; oAx.FontName = fmtOpts.fontName; oAx.Box = 'on';

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  Asymmetric error bar helper (for plotTraces)
        % ────────────────────────────────────────────────────────────────
        function plotAsymmetricErrors(tAx, xVec, yVec, errLo, errHi, col, style, lw)
        %PLOTASYMMETRICERRORS  Render asymmetric error bars or error band.
        %  errLo/errHi are absolute lower/upper error magnitudes.
            switch style
                case 'Error Bars'
                    errorbar(tAx, xVec, yVec, errLo, errHi, 'o', ...
                        'Color', col, 'LineWidth', lw * 0.6, ...
                        'MarkerSize', 3, 'CapSize', 3, ...
                        'HandleVisibility', 'off');
                case 'Error Band'
                    xFill = [xVec(:); flipud(xVec(:))];
                    yFill = [(yVec(:) + errHi(:)); flipud(yVec(:) - errLo(:))];
                    fill(tAx, xFill, yFill, col, 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                        'HandleVisibility', 'off');
            end
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Color Scatter (Z)
        % ────────────────────────────────────────────────────────────────
        function buildColorScatterZConfig()
            gl = uigridlayout(configPanel, [6 4], ...
                'RowHeight', {22, 22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            csWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9, ...
                'ValueChangedFcn', @(~,~) csUpdateChannels());
            csWidgets.ddDS.Layout.Column = [2 4];

            % Build column list for initial dataset
            csColItems = [{'X (time/index)'}, allYLabels];

            uilabel(gl,'Text','X Channel:','HorizontalAlignment','right','FontSize',9);
            csWidgets.ddX = uidropdown(gl,'Items', csColItems, ...
                'Value', csColItems{1}, 'FontSize', 9);
            csWidgets.ddX.Layout.Column = [2 4];

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            csWidgets.ddY = uidropdown(gl,'Items', csColItems, ...
                'Value', csColItems{min(2, numel(csColItems))}, 'FontSize', 9);
            csWidgets.ddY.Layout.Column = [2 4];

            uilabel(gl,'Text','Z (color):','HorizontalAlignment','right','FontSize',9);
            csWidgets.ddZ = uidropdown(gl,'Items', csColItems, ...
                'Value', csColItems{min(3, numel(csColItems))}, 'FontSize', 9);
            csWidgets.ddZ.Layout.Column = [2 4];

            uilabel(gl,'Text','Colormap:','HorizontalAlignment','right','FontSize',9);
            csWidgets.ddCmap = uidropdown(gl, ...
                'Items', {'viridis','plasma','inferno','parula','hot','jet','turbo','cool','gray'}, ...
                'Value', 'viridis', 'FontSize', 9);

            uilabel(gl,'Text','Marker size:','HorizontalAlignment','right','FontSize',9);
            csWidgets.spMkSize = uispinner(gl,'Value',20,'Limits',[1 200],'Step',5,'FontSize',9);
        end

        function csUpdateChannels()
            di = csWidgets.ddDS.Value;
            if di < 1 || di > nDS, return; end
            d = getPlotData(di);
            newItems = [{'X (time/index)'}, d.labels];
            csWidgets.ddX.Items = newItems; csWidgets.ddX.Value = newItems{1};
            csWidgets.ddY.Items = newItems;
            csWidgets.ddY.Value = newItems{min(2, numel(newItems))};
            csWidgets.ddZ.Items = newItems;
            csWidgets.ddZ.Value = newItems{min(3, numel(newItems))};
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Color Scatter (Z)
        % ────────────────────────────────────────────────────────────────
        function generateColorScatterZ()
            di   = csWidgets.ddDS.Value;
            xSel = csWidgets.ddX.Value;
            ySel = csWidgets.ddY.Value;
            zSel = csWidgets.ddZ.Value;
            cmap = csWidgets.ddCmap.Value;
            mkSz = csWidgets.spMkSize.Value;

            if di < 1 || di > nDS
                uialert(bFig,'No valid dataset selected.','No data'); return;
            end

            d = getPlotData(di);
            fmtOpts = getFormatOpts();

            % Resolve X
            if strcmp(xSel, 'X (time/index)')
                xVec = double(d.time(:));
                xLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
            else
                xi = find(strcmp(d.labels, xSel), 1);
                if isempty(xi), uialert(bFig,'X channel not found.','Missing'); return; end
                xVec = d.values(:, xi);
                xLbl = guiLabel(xSel, d.units{min(xi, numel(d.units))});
            end

            % Resolve Y
            yi = find(strcmp(d.labels, ySel), 1);
            if isempty(yi), uialert(bFig,'Y channel not found.','Missing'); return; end
            yVec = d.values(:, yi);
            yLbl = guiLabel(ySel, d.units{min(yi, numel(d.units))});

            % Resolve Z
            if strcmp(zSel, 'X (time/index)')
                zVec = double(d.time(:));
                zLbl = guiLabel(guiXName(d.metadata), guiXUnit(d.metadata));
            else
                zi = find(strcmp(d.labels, zSel), 1);
                if isempty(zi), uialert(bFig,'Z channel not found.','Missing'); return; end
                zVec = d.values(:, zi);
                zLbl = guiLabel(zSel, d.units{min(zi, numel(d.units))});
            end

            good = ~isnan(xVec) & ~isnan(yVec) & ~isnan(zVec);
            xVec = xVec(good); yVec = yVec(good); zVec = zVec(good);

            if numel(xVec) < 2
                uialert(bFig,'Not enough valid data points.','Insufficient data'); return;
            end

            outFig = figure('Name','Color Scatter (Z)','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            oAx = axes(outFig);
            hold(oAx,'on'); box(oAx,'on'); grid(oAx,'on');
            oAx.FontSize = fmtOpts.fontSize;
            oAx.FontName = fmtOpts.fontName;
            oAx.TickDir  = 'in';

            plotting.colorScatterZ(oAx, xVec, yVec, zVec, ...
                Colormap=cmap, MarkerSize=mkSz, ...
                ShowColorbar=true, ColorbarLabel=zLbl);

            xlabel(oAx, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(oAx, yLbl, 'FontSize', fmtOpts.fontSize);

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Marginal Histogram
        % ────────────────────────────────────────────────────────────────
        function buildMarginalHistogramConfig()
            gl = uigridlayout(configPanel, [5 4], ...
                'RowHeight', {22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            mhWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9, ...
                'ValueChangedFcn', @(~,~) mhUpdateChannels());
            mhWidgets.ddDS.Layout.Column = [2 4];

            mhColItems = allYLabels;

            uilabel(gl,'Text','X Channel:','HorizontalAlignment','right','FontSize',9);
            mhWidgets.ddX = uidropdown(gl,'Items', mhColItems, ...
                'Value', mhColItems{1}, 'FontSize', 9);
            mhWidgets.ddX.Layout.Column = [2 4];

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            mhWidgets.ddY = uidropdown(gl,'Items', mhColItems, ...
                'Value', mhColItems{min(2, numel(mhColItems))}, 'FontSize', 9);
            mhWidgets.ddY.Layout.Column = [2 4];

            uilabel(gl,'Text','Bins:','HorizontalAlignment','right','FontSize',9);
            mhWidgets.spNBins = uispinner(gl,'Value',30,'Limits',[5 200],'Step',5,'FontSize',9);

            mhWidgets.cbKDE = uicheckbox(gl,'Text','Show KDE curve','Value',false,'FontSize',9);
            mhWidgets.cbKDE.Layout.Row = 5; mhWidgets.cbKDE.Layout.Column = [1 2];
        end

        function mhUpdateChannels()
            di = mhWidgets.ddDS.Value;
            if di < 1 || di > nDS, return; end
            d = getPlotData(di);
            newItems = d.labels;
            if isempty(newItems), return; end
            mhWidgets.ddX.Items = newItems; mhWidgets.ddX.Value = newItems{1};
            mhWidgets.ddY.Items = newItems;
            mhWidgets.ddY.Value = newItems{min(2, numel(newItems))};
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Marginal Histogram
        % ────────────────────────────────────────────────────────────────
        function generateMarginalHistogram()
            di    = mhWidgets.ddDS.Value;
            xSel  = mhWidgets.ddX.Value;
            ySel  = mhWidgets.ddY.Value;
            nBins = mhWidgets.spNBins.Value;
            showKDE = mhWidgets.cbKDE.Value;

            if di < 1 || di > nDS
                uialert(bFig,'No valid dataset selected.','No data'); return;
            end

            d = getPlotData(di);
            fmtOpts = getFormatOpts();

            xi = find(strcmp(d.labels, xSel), 1);
            yi = find(strcmp(d.labels, ySel), 1);
            if isempty(xi) || isempty(yi)
                uialert(bFig,'Channel not found in dataset.','Missing channel'); return;
            end

            xVec = d.values(:, xi);
            yVec = d.values(:, yi);
            good = ~isnan(xVec) & ~isnan(yVec);
            xVec = xVec(good); yVec = yVec(good);

            if numel(xVec) < 2
                uialert(bFig,'Not enough valid data points.','Insufficient data'); return;
            end

            outFig = figure('Name','Marginal Histogram','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            tmpAx = axes(outFig);

            handles = plotting.marginalHistogram(tmpAx, xVec, yVec, ...
                NBins=nBins, ShowKDE=showKDE);

            xLbl = guiLabel(xSel, d.units{min(xi, numel(d.units))});
            yLbl = guiLabel(ySel, d.units{min(yi, numel(d.units))});
            xlabel(handles.axMain, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(handles.axMain, yLbl, 'FontSize', fmtOpts.fontSize);
            handles.axMain.FontSize = fmtOpts.fontSize;
            handles.axMain.FontName = fmtOpts.fontName;

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: Grouped Plot
        % ────────────────────────────────────────────────────────────────
        function buildGroupedPlotConfig()
            gl = uigridlayout(configPanel, [6 4], ...
                'RowHeight', {22, 22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            gpWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9, ...
                'ValueChangedFcn', @(~,~) gpUpdateChannels());
            gpWidgets.ddDS.Layout.Column = [2 4];

            gpColItems = allYLabels;

            uilabel(gl,'Text','X Channel:','HorizontalAlignment','right','FontSize',9);
            gpWidgets.ddX = uidropdown(gl,'Items', gpColItems, ...
                'Value', gpColItems{1}, 'FontSize', 9);
            gpWidgets.ddX.Layout.Column = [2 4];

            uilabel(gl,'Text','Y Channel:','HorizontalAlignment','right','FontSize',9);
            gpWidgets.ddY = uidropdown(gl,'Items', gpColItems, ...
                'Value', gpColItems{min(2, numel(gpColItems))}, 'FontSize', 9);
            gpWidgets.ddY.Layout.Column = [2 4];

            uilabel(gl,'Text','Group by:','HorizontalAlignment','right','FontSize',9);
            gpWidgets.ddGroup = uidropdown(gl,'Items', gpColItems, ...
                'Value', gpColItems{min(3, numel(gpColItems))}, 'FontSize', 9);
            gpWidgets.ddGroup.Layout.Column = [2 4];

            uilabel(gl,'Text','Plot type:','HorizontalAlignment','right','FontSize',9);
            gpWidgets.ddPlotType = uidropdown(gl, ...
                'Items', {'line','scatter','bar','box'}, ...
                'Value', 'scatter', 'FontSize', 9);

            gpWidgets.cbLegend = uicheckbox(gl,'Text','Show legend','Value',true,'FontSize',9);
            gpWidgets.cbLegend.Layout.Row = 6; gpWidgets.cbLegend.Layout.Column = [1 2];
        end

        function gpUpdateChannels()
            di = gpWidgets.ddDS.Value;
            if di < 1 || di > nDS, return; end
            d = getPlotData(di);
            newItems = d.labels;
            if isempty(newItems), return; end
            gpWidgets.ddX.Items = newItems; gpWidgets.ddX.Value = newItems{1};
            gpWidgets.ddY.Items = newItems;
            gpWidgets.ddY.Value = newItems{min(2, numel(newItems))};
            gpWidgets.ddGroup.Items = newItems;
            gpWidgets.ddGroup.Value = newItems{min(3, numel(newItems))};
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: Grouped Plot
        % ────────────────────────────────────────────────────────────────
        function generateGroupedPlot()
            di       = gpWidgets.ddDS.Value;
            xSel     = gpWidgets.ddX.Value;
            ySel     = gpWidgets.ddY.Value;
            grpSel   = gpWidgets.ddGroup.Value;
            plotType = gpWidgets.ddPlotType.Value;
            showLeg  = gpWidgets.cbLegend.Value;

            if di < 1 || di > nDS
                uialert(bFig,'No valid dataset selected.','No data'); return;
            end

            d = getPlotData(di);
            fmtOpts = getFormatOpts();

            xi   = find(strcmp(d.labels, xSel), 1);
            yi   = find(strcmp(d.labels, ySel), 1);
            grpi = find(strcmp(d.labels, grpSel), 1);

            if isempty(xi) || isempty(yi) || isempty(grpi)
                uialert(bFig,'One or more channels not found.','Missing channel'); return;
            end

            xVec = d.values(:, xi);
            yVec = d.values(:, yi);
            gVec = d.values(:, grpi);
            good = ~isnan(xVec) & ~isnan(yVec) & ~isnan(gVec);
            xVec = xVec(good); yVec = yVec(good); gVec = gVec(good);

            if numel(xVec) < 2
                uialert(bFig,'Not enough valid data points.','Insufficient data'); return;
            end

            outFig = figure('Name','Grouped Plot','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            oAx = axes(outFig);
            hold(oAx,'on'); box(oAx,'on'); grid(oAx,'on');
            oAx.FontSize = fmtOpts.fontSize;
            oAx.FontName = fmtOpts.fontName;
            oAx.TickDir  = 'in';

            plotting.groupedPlot(oAx, xVec, yVec, gVec, ...
                PlotType=plotType, Legend=showLeg);

            xLbl = guiLabel(xSel, d.units{min(xi, numel(d.units))});
            yLbl = guiLabel(ySel, d.units{min(yi, numel(d.units))});
            xlabel(oAx, xLbl, 'FontSize', fmtOpts.fontSize);
            ylabel(oAx, yLbl, 'FontSize', fmtOpts.fontSize);

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  CONFIG: FFT / Spectral
        % ────────────────────────────────────────────────────────────────
        function buildFFTSpectralConfig()
            gl = uigridlayout(configPanel, [7 4], ...
                'RowHeight', {22, 22, 22, 22, 22, 22, 22}, ...
                'ColumnWidth', {90, '1x', 90, '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 6, 'ColumnSpacing', 6);

            uilabel(gl,'Text','Dataset:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.ddDS = uidropdown(gl,'Items', dsNames, 'ItemsData', 1:nDS, ...
                'Value', activeIdx, 'FontSize', 9);
            fsWidgets.ddDS.Layout.Column = [2 4];

            uilabel(gl,'Text','Channel:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.ddY = uidropdown(gl,'Items', allYLabels, ...
                'Value', allYLabels{1}, 'FontSize', 9);
            fsWidgets.ddY.Layout.Column = [2 4];

            uilabel(gl,'Text','Window:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.ddWindow = uidropdown(gl, ...
                'Items', {'hanning','hamming','blackman','flattop','kaiser','none'}, ...
                'Value', 'hanning', 'FontSize', 9);

            uilabel(gl,'Text','Output:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.ddOutput = uidropdown(gl, ...
                'Items', {'psd','magnitude','phase'}, ...
                'Value', 'psd', 'FontSize', 9);

            uilabel(gl,'Text','Detrend:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.ddDetrend = uidropdown(gl, ...
                'Items', {'mean','linear','none'}, ...
                'Value', 'mean', 'FontSize', 9);

            fsWidgets.cbLogY = uicheckbox(gl,'Text','Log Y axis','Value',true,'FontSize',9);
            fsWidgets.cbLogY.Layout.Row = 6; fsWidgets.cbLogY.Layout.Column = [1 2];

            fsWidgets.cbLogX = uicheckbox(gl,'Text','Log X (freq) axis','Value',false,'FontSize',9);
            fsWidgets.cbLogX.Layout.Row = 6; fsWidgets.cbLogX.Layout.Column = [3 4];

            uilabel(gl,'Text','Title:','HorizontalAlignment','right','FontSize',9);
            fsWidgets.efTitle = uieditfield(gl,'Value','','Placeholder','Figure title','FontSize',9);
            fsWidgets.efTitle.Layout.Row = 7; fsWidgets.efTitle.Layout.Column = [2 4];
        end

        % ────────────────────────────────────────────────────────────────
        %  GENERATE: FFT / Spectral
        % ────────────────────────────────────────────────────────────────
        function generateFFTSpectral()
            di         = fsWidgets.ddDS.Value;
            ySel       = fsWidgets.ddY.Value;
            winType    = fsWidgets.ddWindow.Value;
            outType    = fsWidgets.ddOutput.Value;
            detrendMode = fsWidgets.ddDetrend.Value;
            logY       = fsWidgets.cbLogY.Value;
            logX       = fsWidgets.cbLogX.Value;

            if di < 1 || di > nDS
                uialert(bFig,'No valid dataset selected.','No data'); return;
            end

            d = getPlotData(di);
            fmtOpts = getFormatOpts();

            ci = find(strcmp(d.labels, ySel), 1);
            if isempty(ci)
                uialert(bFig,sprintf('Channel "%s" not found.', ySel),'Missing'); return;
            end

            xVec = double(d.time(:));
            yVec = d.values(:, ci);
            good = ~isnan(xVec) & ~isnan(yVec);
            xVec = xVec(good); yVec = yVec(good);

            if numel(xVec) < 8
                uialert(bFig,'Need at least 8 valid data points for FFT.','Insufficient data'); return;
            end

            % Call fftSpectral
            result = utilities.fftSpectral(xVec, yVec, ...
                Window=winType, OutputType=outType, Detrend=detrendMode);

            % Extract output vector
            switch outType
                case 'psd',       ySpec = result.psd;
                case 'magnitude', ySpec = result.magnitude;
                case 'phase',     ySpec = result.phase;
                otherwise,        ySpec = result.psd;
            end

            outFig = figure('Name','FFT / Spectral Analysis','NumberTitle','off', ...
                'Units','inches','Position',[1 1 spBFigW.Value spBFigH.Value]);
            oAx = axes(outFig);
            hold(oAx,'on'); box(oAx,'on'); grid(oAx,'on');
            oAx.FontSize = fmtOpts.fontSize;
            oAx.FontName = fmtOpts.fontName;
            oAx.TickDir  = 'in';

            plot(oAx, result.freq, ySpec, '-', ...
                'Color', [0.12 0.47 0.71], 'LineWidth', fmtOpts.lineWidth);

            if logY, oAx.YScale = 'log'; end
            if logX, oAx.XScale = 'log'; end

            xUnits = guiXUnit(d.metadata);
            if isempty(xUnits)
                freqLbl = 'Frequency';
            else
                freqLbl = ['Frequency (1/' xUnits ')'];
            end
            xlabel(oAx, freqLbl, 'FontSize', fmtOpts.fontSize);

            switch outType
                case 'psd',       yLbl = [guiLabel(ySel, d.units{min(ci,numel(d.units))}) '^2 / Hz'];
                case 'magnitude', yLbl = ['|FFT| of ' ySel];
                case 'phase',     yLbl = 'Phase (deg)';
                otherwise,        yLbl = outType;
            end
            ylabel(oAx, yLbl, 'FontSize', fmtOpts.fontSize);

            ttl = fsWidgets.efTitle.Value;
            if isempty(ttl)
                ttl = ['Spectral Analysis — ' ySel ' (' winType ' window, ' outType ')'];
            end
            title(oAx, ttl, 'FontSize', fmtOpts.fontSize+1, 'Interpreter', 'none');

            addRefLineTools(outFig);
            figure(outFig);
            delete(bFig);
        end

        % ────────────────────────────────────────────────────────────────
        %  Linked Cursor for Multi-Panel / Quick Grid figures
        % ────────────────────────────────────────────────────────────────
        function addLinkedCursor(outFig)
        %ADDLINKEDCURSOR  Add a vertical cursor line that tracks across all
        %  child axes when hovering.  Click to pin, click again to clear.
            allAxes = findall(outFig, 'Type', 'axes');
            if numel(allAxes) < 2, return; end

            cursorLines = gobjects(numel(allAxes), 1);
            for ai = 1:numel(allAxes)
                cursorLines(ai) = xline(allAxes(ai), mean(allAxes(ai).XLim), ...
                    'Color', [0.7 0 0 0.5], 'LineWidth', 0.75, ...
                    'HandleVisibility', 'off', 'Visible', 'off');
            end

            pinned = false;
            outFig.WindowButtonMotionFcn = @(~,~) onCursorMove();
            outFig.WindowButtonDownFcn   = @(~,~) onCursorPin();

            function onCursorMove()
                if pinned, return; end
                cp = outFig.CurrentPoint;  % [x, y] in figure normalized coords
                % Find which axes the cursor is over
                for ci = 1:numel(allAxes)
                    axPos = getpixelposition(allAxes(ci), true);
                    figPos = getpixelposition(outFig);
                    % Convert figure normalized to pixel
                    px = cp(1) * figPos(3);
                    py = cp(2) * figPos(4);
                    if px >= axPos(1) && px <= axPos(1)+axPos(3) && ...
                       py >= axPos(2) && py <= axPos(2)+axPos(4)
                        % Convert pixel to data coordinates
                        xFrac = (px - axPos(1)) / axPos(3);
                        xData = allAxes(ci).XLim(1) + xFrac * diff(allAxes(ci).XLim);
                        % Update all cursor lines
                        for li = 1:numel(cursorLines)
                            if isvalid(cursorLines(li))
                                cursorLines(li).Value = xData;
                                cursorLines(li).Visible = 'on';
                            end
                        end
                        return;
                    end
                end
                % Not over any axes — hide cursors
                for li = 1:numel(cursorLines)
                    if isvalid(cursorLines(li))
                        cursorLines(li).Visible = 'off';
                    end
                end
            end

            function onCursorPin()
                pinned = ~pinned;
                if ~pinned
                    for li = 1:numel(cursorLines)
                        if isvalid(cursorLines(li))
                            cursorLines(li).Visible = 'off';
                        end
                    end
                end
            end
        end


        % ════════════════════════════════════════════════════════════════
        %  Stand-alone helpers (copied from DataPlotter local-function scope)
        % ════════════════════════════════════════════════════════════════

        function ls = localLineSpec(style)
        %LOCALLINESPEC  Return line-spec cell for the chosen plot style.
            switch style
                case 'Scatter'
                    ls = {'LineStyle','none','Marker','o','MarkerSize',5};
                case 'Line+Pts'
                    ls = {'LineStyle','-','Marker','o','MarkerSize',4};
                otherwise
                    ls = {'LineStyle','-'};
            end
        end

        function colors = getColorsFromMap(colormapName, nColors)
        %GETCOLORSFROMMPA  Generate nColors colors from a named colormap.
            colors = dataplotter.colorMaps(colormapName, nColors);
        end

        function name = guiXName(meta)
        %GUIXNAME  Return X-axis column name from metadata.
            if isfield(meta,'xColumnName') && ~isempty(meta.xColumnName)
                name = meta.xColumnName;
            else
                name = 'X';
            end
        end

        function u = guiXUnit(meta)
        %GUIXUNIT  Return X-axis unit string from metadata.
            if isfield(meta,'xColumnUnit') && ~isempty(meta.xColumnUnit)
                u = meta.xColumnUnit;
            else
                u = '';
            end
        end

        function s = guiLabel(name, unit)
        %GUILABEL  Format an axis label: "Name (unit)" or just "Name".
            name = greekify(name);
            if isempty(unit)
                s = name;
            else
                s = [name, ' (', greekify(unit), ')'];
            end
        end

        function s = greekify(s)
        %GREEKIFY  Replace spelled-out Greek letter names with Unicode characters.
            pairs = {
                'degrees', '°';
                'epsilon', 'ε';
                'degree',  '°';
                'lambda',  'λ';
                'omega',   'ω';
                'theta',   'θ';
                'sigma',   'σ';
                'alpha',   'α';
                'gamma',   'γ';
                'delta',   'δ';
                'kappa',   'κ';
                'beta',    'β';
                'zeta',    'ζ';
                'phi',     'φ';
                'chi',     'χ';
                'psi',     'ψ';
                'tau',     'τ';
                'rho',     'ρ';
                'deg',     '°';
                'eta',     'η';
                'mu',      'μ';
                'nu',      'ν';
                'xi',      'ξ';
                'pi',      'π';
            };
            for k = 1:size(pairs, 1)
                pat = ['(?i)(?<![a-zA-Z])', pairs{k,1}, '(?![a-zA-Z])'];
                s   = regexprep(s, pat, pairs{k,2});
            end
        end

        function idx = findErrorColumn(labels, yLabel)
        %FINDERRORCOLUMN  Find a symmetric error column matching yLabel.
            idx = [];
            candidates = { ...
                ['d' yLabel], [yLabel ' err'], [yLabel ' Err'], ...
                'M. Std. Err.', [yLabel ' std'], [yLabel ' sigma'] };
            for ci = 1:numel(candidates)
                ii = find(strcmpi(labels, candidates{ci}), 1);
                if ~isempty(ii), idx = ii; return; end
            end
            for li = 1:numel(labels)
                lbl = lower(labels{li});
                if (contains(lbl, 'err') || contains(lbl, 'std')) && ~strcmpi(labels{li}, yLabel)
                    idx = li; return;
                end
            end
        end

        function [idxLo, idxHi] = findAsymmetricErrorColumns(labels, yLabel)
        %FINDASYMMETRICERRORCOLUMNS  Find separate lower/upper error columns.
            idxLo = []; idxHi = [];
            hiCands = {[yLabel '+'], ['d' yLabel '+'], [yLabel ' err+'], [yLabel '_err_hi'], [yLabel ' hi']};
            loCands = {[yLabel '-'], ['d' yLabel '-'], [yLabel ' err-'], [yLabel '_err_lo'], [yLabel ' lo']};
            for ci = 1:numel(hiCands)
                hi = find(strcmpi(labels, hiCands{ci}), 1);
                lo = find(strcmpi(labels, loCands{ci}), 1);
                if ~isempty(hi) && ~isempty(lo)
                    idxHi = hi; idxLo = lo; return;
                end
            end
        end

end  % figureBuilder
