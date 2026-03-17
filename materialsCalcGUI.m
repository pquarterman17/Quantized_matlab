function varargout = materialsCalcGUI()
% ════════════════════════════════════════════════════════════════════════
% Standalone GUI for materials property calculations.
% ════════════════════════════════════════════════════════════════════════
%
% Syntax:
%   materialsCalcGUI()
%   api = materialsCalcGUI()
%
% Description:
%   Opens a tabbed uifigure calculator covering: unit conversions, crystal
%   structure (d-spacing, mismatch, cell volume), electrical properties,
%   semiconductor device parameters, thin film calculations, and an
%   interactive periodic table. All tabs call the +calc module namespace.
%   Returns an api struct when called with nargout > 0 (for headless tests).
%
% ════════════════════════════════════════════════════════════════════════

% ════════════════════════════════════════════════════════════════════════
% BUTTON COLOR PALETTE
% ════════════════════════════════════════════════════════════════════════
BTN_PRIMARY = [0.20 0.60 0.20];   % green — primary action
BTN_TOOL    = [0.94 0.94 0.94];   % light gray — secondary / tool
BTN_EXPORT  = [0.15 0.45 0.75];   % blue — copy / export
BTN_FG      = [1.00 1.00 1.00];   % white foreground text

% ════════════════════════════════════════════════════════════════════════
% MAIN FIGURE
% ════════════════════════════════════════════════════════════════════════
fig = uifigure('Name', 'Materials Calculator — Thin Film Toolkit', ...
    'Position', [80 80 720 560], ...
    'Resize', 'on');
fig.CloseRequestFcn = @onFigureClose;

% Root grid: tab group row + status bar row
rootGL = uigridlayout(fig);
rootGL.RowHeight    = {'1x', 22};
rootGL.ColumnWidth  = {'1x'};
rootGL.Padding      = [0 0 0 0];
rootGL.RowSpacing   = 0;

% Tab group
tabGroup = uitabgroup(rootGL);
tabGroup.Layout.Row    = 1;
tabGroup.Layout.Column = 1;

% Status bar
lblStatus = uilabel(rootGL, ...
    'Text', 'Ready', ...
    'FontSize', 11, ...
    'HorizontalAlignment', 'left');
lblStatus.Layout.Row    = 2;
lblStatus.Layout.Column = 1;

% ════════════════════════════════════════════════════════════════════════
% APP STATE
% ════════════════════════════════════════════════════════════════════════
appData.history    = {};
appData.historyMax = 100;
appData.api        = struct();  % tab builders store callable hooks here

% ════════════════════════════════════════════════════════════════════════
% BUILD TABS
% ════════════════════════════════════════════════════════════════════════
tabs = struct();
tabs.unitConverter = uitab(tabGroup, 'Title', 'Unit Converter');
tabs.crystal       = uitab(tabGroup, 'Title', 'Crystal');
tabs.electrical    = uitab(tabGroup, 'Title', 'Electrical');
tabs.semiconductor = uitab(tabGroup, 'Title', 'Semiconductor');
tabs.thinFilm      = uitab(tabGroup, 'Title', 'Thin Film');
tabs.periodicTable = uitab(tabGroup, 'Title', 'Periodic Table');

buildUnitConverterTab(tabs.unitConverter);
buildCrystalTab(tabs.crystal);
buildElectricalTab(tabs.electrical);
buildSemiconductorTab(tabs.semiconductor);
buildThinFilmTab(tabs.thinFilm);
buildPeriodicTableTab(tabs.periodicTable);

% ════════════════════════════════════════════════════════════════════════
% API (headless testing)
% ════════════════════════════════════════════════════════════════════════
if nargout > 0
    api.fig            = fig;
    api.getHistory     = @getHistoryFcn;
    api.selectTab      = @(name) set(tabGroup, 'SelectedTab', tabs.(name));
    api.getStatus      = @() lblStatus.Text;
    api.close          = @() delete(fig);
    % Tab-specific API methods (populated by tab builders via appData.api)
    api.convert        = appData.api.convert;
    api.calcDSpacing   = appData.api.calcDSpacing;
    api.getDResult     = appData.api.getDResult;
    api.calcIntrinsic  = appData.api.calcIntrinsic;
    api.getNiResult    = appData.api.getNiResult;
    api.selectElement      = appData.api.selectElement;
    api.getElementDetail   = appData.api.getElementDetail;
    api.calcPlaneSpacings  = appData.api.calcPlaneSpacings;
    api.getMismatchResult   = appData.api.getMismatchResult;
    varargout{1}       = api;
end

% ════════════════════════════════════════════════════════════════════════
% HISTORY HELPER
% ════════════════════════════════════════════════════════════════════════

    function addHistory(description, latexStr)
        entry = {datestr(now, 'HH:MM:SS'), description, latexStr};
        appData.history{end+1} = entry;
        if numel(appData.history) > appData.historyMax
            appData.history(1) = [];
        end
        setStatus(description);
    end

    function h = getHistoryFcn()
        h = appData.history;
    end

    function setStatus(msg)
        if isvalid(lblStatus)
            lblStatus.Text = msg;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 1: UNIT CONVERTER
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildUnitConverterTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight   = {28, 28, 28, 28, 22, 28, 28};
        gl.ColumnWidth = {60, '1x', 60, '1x'};
        gl.Padding     = [10 10 10 6];
        gl.RowSpacing  = 6;

        % Row 1: Value + From
        uilabel(gl, 'Text', 'Value:', 'HorizontalAlignment', 'right');
        efValue = uieditfield(gl, 'numeric', 'Value', 1);
        efValue.Layout.Row = 1; efValue.Layout.Column = 2;
        uilabel(gl, 'Text', 'From:', 'HorizontalAlignment', 'right');
        efFrom = uieditfield(gl, 'text', 'Value', 'Oe');
        efFrom.Layout.Row = 1; efFrom.Layout.Column = 4;

        % Row 2: Result + To
        uilabel(gl, 'Text', 'Result:', 'HorizontalAlignment', 'right');
        efResult = uieditfield(gl, 'text', 'Editable', 'off', 'Value', '');
        efResult.Layout.Row = 2; efResult.Layout.Column = 2;
        uilabel(gl, 'Text', 'To:', 'HorizontalAlignment', 'right');
        efTo = uieditfield(gl, 'text', 'Value', 'T');
        efTo.Layout.Row = 2; efTo.Layout.Column = 4;

        % Row 3: Buttons
        btnConvert = uibutton(gl, 'push', 'Text', 'Convert', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doUnitConvert());
        btnConvert.Layout.Row = 3; btnConvert.Layout.Column = 1;

        btnSwap = uibutton(gl, 'push', 'Text', 'Swap', ...
            'BackgroundColor', BTN_TOOL, ...
            'ButtonPushedFcn', @(~,~) doSwap());
        btnSwap.Layout.Row = 3; btnSwap.Layout.Column = 2;

        btnCopyResult = uibutton(gl, 'push', 'Text', 'Copy Result', ...
            'BackgroundColor', BTN_EXPORT, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doCopyResult());
        btnCopyResult.Layout.Row = 3; btnCopyResult.Layout.Column = 3;

        btnCopyLatex = uibutton(gl, 'push', 'Text', 'Copy LaTeX', ...
            'BackgroundColor', BTN_EXPORT, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doCopyLatex());
        btnCopyLatex.Layout.Row = 3; btnCopyLatex.Layout.Column = 4;

        % Row 4: Conversion detail label
        lblDetail = uilabel(gl, 'Text', '', 'FontSize', 11, ...
            'Interpreter', 'html');
        lblDetail.Layout.Row = 4; lblDetail.Layout.Column = [1 4];

        % Row 5: Separator
        lblSep = uilabel(gl, 'Text', '── Quick Presets ──', ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontColor', [0.5 0.5 0.5]);
        lblSep.Layout.Row = 5; lblSep.Layout.Column = [1 4];

        % Rows 6-7: Preset buttons
        presetGL = uigridlayout(gl);
        presetGL.Layout.Row = [6 7]; presetGL.Layout.Column = [1 4];
        presetGL.RowHeight   = {28, 28};
        presetGL.ColumnWidth = {'1x','1x','1x','1x'};
        presetGL.Padding     = [0 0 0 0];
        presetGL.RowSpacing  = 4;

        presets = {
            'Oe', 'T';
            'emu', 'A*m^2';
            'eV', 'nm';
            'Ang', 'nm';
            'Pa', 'Torr';
            'K', 'C';
            'GPa', 'Pa';
            'deg', 'rad';
        };
        for pi = 1:size(presets, 1)
            fr = presets{pi,1};
            to = presets{pi,2};
            lbl = sprintf('%s \x2192 %s', fr, to);
            btn = uibutton(presetGL, 'push', 'Text', lbl, ...
                'BackgroundColor', BTN_TOOL, 'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) applyPreset(fr, to));
            btn.Layout.Row    = ceil(pi/4);
            btn.Layout.Column = mod(pi-1,4)+1;
        end

        % State for copy
        lastLatex = '';

        function doUnitConvert()
            val  = efValue.Value;
            from = strtrim(efFrom.Value);
            to   = strtrim(efTo.Value);
            try
                [res, info] = calc.unitConvert(val, from, to);
                efResult.Value = num2str(res, 6);
                lblDetail.Text = info.description;
                lastLatex = info.latex;
                addHistory(info.description, info.latex);
            catch ME
                efResult.Value = '';
                lblDetail.Text = '';
                lastLatex = '';
                setStatus(['Error: ' ME.message]);
            end
        end

        function doSwap()
            tmp = efFrom.Value;
            efFrom.Value = efTo.Value;
            efTo.Value   = tmp;
            doUnitConvert();
        end

        function doCopyResult()
            if ~isempty(efResult.Value)
                clipboard('copy', efResult.Value);
                setStatus('Result copied to clipboard.');
            end
        end

        function doCopyLatex()
            if ~isempty(lastLatex)
                clipboard('copy', lastLatex);
                setStatus('LaTeX copied to clipboard.');
            end
        end

        function applyPreset(from, to)
            efFrom.Value = from;
            efTo.Value   = to;
            doUnitConvert();
        end

        % API hooks
        appData.api.convert = @(val, from, to) apiConvert(val, from, to);
        function result = apiConvert(val, from, to)
            efValue.Value = val;
            efFrom.Value  = from;
            efTo.Value    = to;
            doUnitConvert();
            result = efResult.Value;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 2: CRYSTAL
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildCrystalTab(tab)
        % Scrollable panel wrapper
        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {'1x'};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        scroll = uipanel(outerGL, 'BorderType', 'none', 'Scrollable', 'on');
        scroll.Layout.Row = 1; scroll.Layout.Column = 1;

        gl = uigridlayout(scroll);
        gl.RowHeight   = {110, 90, 100, 110, 260};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [4 4 4 4];
        gl.RowSpacing  = 8;

        % ── Card 1: d-spacing ──────────────────────────────────────────
        pD = uipanel(gl, 'Title', 'd-Spacing', 'FontWeight', 'bold');
        pD.Layout.Row = 1; pD.Layout.Column = 1;

        gD = uigridlayout(pD);
        gD.RowHeight   = {24, 24, 24};
        gD.ColumnWidth = {40,'1x',40,'1x',40,'1x',40,'1x',80};
        gD.Padding     = [6 4 6 4];
        gD.RowSpacing  = 4;

        % Row 1: a, h, k, l, substrate dropdown
        uilabel(gD,'Text','a (Å):','HorizontalAlignment','right');
        efDa = uieditfield(gD,'numeric','Value',3.905);
        efDa.Layout.Row=1; efDa.Layout.Column=2;
        uilabel(gD,'Text','h:','HorizontalAlignment','right');
        efDh = uieditfield(gD,'numeric','Value',0);
        efDh.Layout.Row=1; efDh.Layout.Column=4;
        uilabel(gD,'Text','k:','HorizontalAlignment','right');
        efDk = uieditfield(gD,'numeric','Value',0);
        efDk.Layout.Row=1; efDk.Layout.Column=6;
        uilabel(gD,'Text','l:','HorizontalAlignment','right');
        efDl = uieditfield(gD,'numeric','Value',1);
        efDl.Layout.Row=1; efDl.Layout.Column=8;

        % Substrate auto-fill
        subNames = calc.substrates.listSubstrates();
        ddDSub = uidropdown(gD, 'Items', ['(none)', subNames], 'Value', '(none)', ...
            'ValueChangedFcn', @(~,~) fillDSpacingFromSubstrate());
        ddDSub.Layout.Row = 1; ddDSub.Layout.Column = 9;

        % Row 2: b, c, alpha, beta, gamma
        uilabel(gD,'Text','b (Å):','HorizontalAlignment','right');
        efDb = uieditfield(gD,'numeric','Value',3.905);
        efDb.Layout.Row=2; efDb.Layout.Column=2;
        uilabel(gD,'Text','c (Å):','HorizontalAlignment','right');
        efDc = uieditfield(gD,'numeric','Value',3.905);
        efDc.Layout.Row=2; efDc.Layout.Column=4;
        uilabel(gD,'Text','\alpha:','HorizontalAlignment','right');
        efDal = uieditfield(gD,'numeric','Value',90);
        efDal.Layout.Row=2; efDal.Layout.Column=6;
        uilabel(gD,'Text','\beta:','HorizontalAlignment','right');
        efDbe = uieditfield(gD,'numeric','Value',90);
        efDbe.Layout.Row=2; efDbe.Layout.Column=8;

        % Row 3: gamma, result, calculate button
        uilabel(gD,'Text','\gamma:','HorizontalAlignment','right');
        efDga = uieditfield(gD,'numeric','Value',90);
        efDga.Layout.Row=3; efDga.Layout.Column=2;
        lblDResult = uilabel(gD,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDResult.Layout.Row=3; lblDResult.Layout.Column=[3 8];
        btnDCalc = uibutton(gD,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDSpacing());
        btnDCalc.Layout.Row=3; btnDCalc.Layout.Column=9;

        function fillDSpacingFromSubstrate()
            sel = ddDSub.Value;
            if strcmp(sel,'(none)'), return; end
            try
                s = calc.substrates.getSubstrate(sel);
                efDa.Value  = s.a;
                efDb.Value  = s.b;
                efDc.Value  = s.c;
                efDal.Value = s.alpha;
                efDbe.Value = s.beta;
                efDga.Value = s.gamma;
            catch; end
        end

        function doDSpacing()
            try
                r = calc.crystal.dSpacing(efDa.Value, efDh.Value, efDk.Value, efDl.Value, ...
                    b=efDb.Value, c=efDc.Value, ...
                    alpha=efDal.Value, beta=efDbe.Value, gamma=efDga.Value);
                desc = sprintf('d<sub>%d%d%d</sub> = %.5g %s  [%s]', ...
                    efDh.Value, efDk.Value, efDl.Value, r.d, char(197), r.system);
                lblDResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblDResult.Text = ['Error: ' ME.message];
                setStatus(['d-spacing error: ' ME.message]);
            end
        end

        % ── Card 2: 2θ ↔ d ────────────────────────────────────────────
        p2T = uipanel(gl, 'Title', '2\theta \leftrightarrow d', 'FontWeight', 'bold');
        p2T.Layout.Row = 2; p2T.Layout.Column = 1;

        g2T = uigridlayout(p2T);
        g2T.RowHeight   = {24, 24};
        g2T.ColumnWidth = {70,'1x',70,'1x',90,90};
        g2T.Padding     = [6 4 6 4];
        g2T.RowSpacing  = 4;

        uilabel(g2T,'Text','Value:','HorizontalAlignment','right');
        ef2TVal = uieditfield(g2T,'numeric','Value',20);
        ef2TVal.Layout.Row=1; ef2TVal.Layout.Column=2;
        uilabel(g2T,'Text','\lambda (Å):','HorizontalAlignment','right');
        ef2TLam = uieditfield(g2T,'numeric','Value',1.5406);
        ef2TLam.Layout.Row=1; ef2TLam.Layout.Column=4;
        btn2TtoD = uibutton(g2T,'push','Text','2\theta \rightarrow d', ...
            'BackgroundColor',BTN_TOOL, ...
            'ButtonPushedFcn',@(~,~) do2ThetaToD());
        btn2TtoD.Layout.Row=1; btn2TtoD.Layout.Column=5;
        btnDTo2T = uibutton(g2T,'push','Text','d \rightarrow 2\theta', ...
            'BackgroundColor',BTN_TOOL, ...
            'ButtonPushedFcn',@(~,~) doDTo2Theta());
        btnDTo2T.Layout.Row=1; btnDTo2T.Layout.Column=6;

        lbl2TResult = uilabel(g2T,'Text','','FontSize',11, ...
            'Interpreter','html');
        lbl2TResult.Layout.Row=2; lbl2TResult.Layout.Column=[1 6];

        function do2ThetaToD()
            try
                r = calc.crystal.dFromTwoTheta(ef2TVal.Value, ef2TLam.Value);
                desc = sprintf('2%s = %.4g%s %s d = %.5g %s  (%s = %.4f %s)', ...
                    char(952), ef2TVal.Value, char(176), char(8594), ...
                    r.d, char(197), char(955), ef2TLam.Value, char(197));
                lbl2TResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lbl2TResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        function doDTo2Theta()
            try
                r = calc.crystal.twoThetaFromD(ef2TVal.Value, ef2TLam.Value);
                desc = sprintf('d = %.4g %s %s 2%s = %.5g%s  (%s = %.4f %s)', ...
                    ef2TVal.Value, char(197), char(8594), ...
                    char(952), r.twoTheta, char(176), char(955), ef2TLam.Value, char(197));
                lbl2TResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lbl2TResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 3: Lattice Mismatch & Strain ─────────────────────────
        pMM = uipanel(gl, 'Title', 'Lattice Mismatch & Critical Thickness', 'FontWeight', 'bold');
        pMM.Layout.Row = 3; pMM.Layout.Column = 1;

        gMM = uigridlayout(pMM);
        gMM.RowHeight   = {24, 24, 24};
        gMM.ColumnWidth = {70,'1x',70,'1x',80,80};
        gMM.Padding     = [6 4 6 4];
        gMM.RowSpacing  = 4;

        uilabel(gMM,'Text','a Film (Å):','HorizontalAlignment','right');
        efMMFilm = uieditfield(gMM,'numeric','Value',3.876);
        efMMFilm.Layout.Row=1; efMMFilm.Layout.Column=2;
        uilabel(gMM,'Text','a Sub (Å):','HorizontalAlignment','right');
        efMMSub = uieditfield(gMM,'numeric','Value',3.905);
        efMMSub.Layout.Row=1; efMMSub.Layout.Column=4;

        % Substrate fill for aSub
        ddMMSub = uidropdown(gMM,'Items',['(none)',subNames],'Value','(none)', ...
            'ValueChangedFcn',@(~,~) fillMMSubstrate());
        ddMMSub.Layout.Row=1; ddMMSub.Layout.Column=[5 6];

        lblMMResult = uilabel(gMM,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblMMResult.Layout.Row=2; lblMMResult.Layout.Column=[1 4];
        lblMMCtResult = uilabel(gMM,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblMMCtResult.Layout.Row=3; lblMMCtResult.Layout.Column=[1 4];

        btnMMCalc = uibutton(gMM,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doMismatch());
        btnMMCalc.Layout.Row=2; btnMMCalc.Layout.Column=[5 6];

        function fillMMSubstrate()
            sel = ddMMSub.Value;
            if strcmp(sel,'(none)'), return; end
            try
                s = calc.substrates.getSubstrate(sel);
                efMMSub.Value = s.a;
            catch; end
        end

        function doMismatch()
            try
                rMM = calc.crystal.latticeMismatch(efMMFilm.Value, efMMSub.Value);
                desc = sprintf('<i>f</i> = %.4g%%  (%s)', rMM.mismatchPct, rMM.description);
                lblMMResult.Text = desc;
                addHistory(desc, rMM.latex);

                rCT = calc.crystal.criticalThickness(efMMFilm.Value, efMMSub.Value);
                if isinf(rCT.hc)
                    descCT = ['h<sub>c</sub> = ' char(8734) ' (lattice matched)'];
                else
                    descCT = sprintf('h<sub>c</sub> = %.4g %s = %.4g nm', rCT.hc, char(197), rCT.hcNm);
                end
                lblMMCtResult.Text = descCT;
            catch ME
                lblMMResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Unit Cell Volume & Density ────────────────────────
        pVC = uipanel(gl, 'Title', 'Unit Cell Volume & Density', 'FontWeight', 'bold');
        pVC.Layout.Row = 4; pVC.Layout.Column = 1;

        gVC = uigridlayout(pVC);
        gVC.RowHeight   = {24, 24, 24, 24};
        gVC.ColumnWidth = {60,'1x',60,'1x',60,'1x',80};
        gVC.Padding     = [6 4 6 4];
        gVC.RowSpacing  = 4;

        uilabel(gVC,'Text','a (Å):','HorizontalAlignment','right');
        efVCa = uieditfield(gVC,'numeric','Value',3.905);
        efVCa.Layout.Row=1; efVCa.Layout.Column=2;
        uilabel(gVC,'Text','b (Å):','HorizontalAlignment','right');
        efVCb = uieditfield(gVC,'numeric','Value',3.905);
        efVCb.Layout.Row=1; efVCb.Layout.Column=4;
        uilabel(gVC,'Text','c (Å):','HorizontalAlignment','right');
        efVCc = uieditfield(gVC,'numeric','Value',3.905);
        efVCc.Layout.Row=1; efVCc.Layout.Column=6;

        uilabel(gVC,'Text','Z:','HorizontalAlignment','right');
        efVCZ = uieditfield(gVC,'numeric','Value',1);
        efVCZ.Layout.Row=2; efVCZ.Layout.Column=2;
        uilabel(gVC,'Text','M (g/mol):','HorizontalAlignment','right');
        efVCM = uieditfield(gVC,'numeric','Value',183.84);
        efVCM.Layout.Row=2; efVCM.Layout.Column=4;

        lblVCResult = uilabel(gVC,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblVCResult.Layout.Row=3; lblVCResult.Layout.Column=[1 6];
        lblVCDens = uilabel(gVC,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblVCDens.Layout.Row=4; lblVCDens.Layout.Column=[1 6];

        btnVCCalc = uibutton(gVC,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doUnitCellVolume());
        btnVCCalc.Layout.Row=2; btnVCCalc.Layout.Column=7;

        function doUnitCellVolume()
            try
                rV = calc.crystal.unitCellVolume(efVCa.Value, ...
                    b=efVCb.Value, c=efVCc.Value);
                lblVCResult.Text = sprintf('V = %.5g %s<sup>3</sup>  [%s]', rV.volume, char(197), rV.system);
                rD = calc.crystal.densityFromMolar(efVCM.Value, efVCa.Value, efVCZ.Value, ...
                    b=efVCb.Value, c=efVCc.Value);
                lblVCDens.Text = sprintf('%s = %.4g g/cm<sup>3</sup>', char(961), rD.density);
                desc = sprintf('V=%.4g Å³, ρ=%.4g g/cm³', rV.volume, rD.density);
                addHistory(desc, rV.latex);
            catch ME
                lblVCResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 5: Plane Spacing Table ──────────────────────────────
        pPS = uipanel(gl, 'Title', 'Plane Spacing Table', 'FontWeight', 'bold');
        pPS.Layout.Row = 5; pPS.Layout.Column = 1;

        gPS = uigridlayout(pPS);
        gPS.RowHeight   = {24, '1x', 24};
        gPS.ColumnWidth = {70, '1x', 70, 60, 70, '1x', 80, 80};
        gPS.Padding     = [6 4 6 4];
        gPS.RowSpacing  = 4;

        uilabel(gPS, 'Text', 'Centering:', 'HorizontalAlignment', 'right');
        ddPSCent = uidropdown(gPS, 'Items', {'P','F','I','A','B','C','R'}, ...
            'Value', 'P');
        ddPSCent.Layout.Row = 1; ddPSCent.Layout.Column = 2;

        uilabel(gPS, 'Text', 'Max hkl:', 'HorizontalAlignment', 'right');
        efPSMax = uieditfield(gPS, 'numeric', 'Value', 5, ...
            'Limits', [1 10], 'RoundFractionalValues', 'on');
        efPSMax.Layout.Row = 1; efPSMax.Layout.Column = 4;

        uilabel(gPS, 'Text', [char(955) ' (' char(197) '):'], ...
            'HorizontalAlignment', 'right');
        efPSLam = uieditfield(gPS, 'numeric', 'Value', 1.5406);
        efPSLam.Layout.Row = 1; efPSLam.Layout.Column = 6;

        btnPSCalc = uibutton(gPS, 'push', 'Text', 'Generate', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doPlaneSpacings());
        btnPSCalc.Layout.Row = 1; btnPSCalc.Layout.Column = 7;

        btnPSCopy = uibutton(gPS, 'push', 'Text', 'Copy Table', ...
            'BackgroundColor', BTN_EXPORT, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doCopyPlaneTable());
        btnPSCopy.Layout.Row = 1; btnPSCopy.Layout.Column = 8;

        % Results table
        tblPS = uitable(gPS, 'ColumnName', {'h','k','l', ...
            ['d (' char(197) ')'], ['2' char(952) ' (' char(176) ')'], 'Mult'}, ...
            'ColumnWidth', {35, 35, 35, 80, 80, 45}, ...
            'RowName', 'numbered', 'FontSize', 10);
        tblPS.Layout.Row = 2; tblPS.Layout.Column = [1 8];

        lblPSStatus = uilabel(gPS, 'Text', '', 'FontSize', 10, ...
            'FontColor', [0.4 0.4 0.4]);
        lblPSStatus.Layout.Row = 3; lblPSStatus.Layout.Column = [1 8];

        psTableData = {};  % stored for clipboard copy

        function doPlaneSpacings()
            try
                r = calc.crystal.planeSpacings(efDa.Value, ...
                    b=efDb.Value, c=efDc.Value, ...
                    alpha=efDal.Value, beta=efDbe.Value, gamma=efDga.Value, ...
                    MaxHKL=efPSMax.Value, Lambda=efPSLam.Value, ...
                    Centering=ddPSCent.Value);

                n = r.nReflections;
                tableData = cell(n, 6);
                for ri = 1:n
                    tableData{ri,1} = r.hkl(ri,1);
                    tableData{ri,2} = r.hkl(ri,2);
                    tableData{ri,3} = r.hkl(ri,3);
                    tableData{ri,4} = round(r.d(ri), 4);
                    if isnan(r.twoTheta(ri))
                        tableData{ri,5} = '-';
                    else
                        tableData{ri,5} = round(r.twoTheta(ri), 3);
                    end
                    tableData{ri,6} = r.multiplicity(ri);
                end
                tblPS.Data = tableData;
                psTableData = tableData;
                lblPSStatus.Text = sprintf('%d reflections  [%s, %s centering]', ...
                    n, r.system, r.centering);
                addHistory(sprintf('Plane spacings: %d reflections (%s)', n, r.system), '');
            catch ME
                lblPSStatus.Text = ['Error: ' ME.message];
                setStatus(['Plane spacings error: ' ME.message]);
            end
        end

        function doCopyPlaneTable()
            if isempty(psTableData), return; end
            lines = {sprintf('h\tk\tl\td(Å)\t2θ(°)\tMult')};
            for ri = 1:size(psTableData, 1)
                if isnumeric(psTableData{ri,5})
                    ttStr = sprintf('%.3f', psTableData{ri,5});
                else
                    ttStr = '-';
                end
                lines{end+1} = sprintf('%d\t%d\t%d\t%.4f\t%s\t%d', ...
                    psTableData{ri,1}, psTableData{ri,2}, psTableData{ri,3}, ...
                    psTableData{ri,4}, ttStr, psTableData{ri,6}); %#ok<AGROW>
            end
            clipboard('copy', strjoin(lines, newline));
            setStatus('Plane spacing table copied to clipboard.');
        end

        % API hooks
        appData.api.calcDSpacing = @(a,h,k,l) apiDSpacing(a,h,k,l);
        function txt = apiDSpacing(a,h,k,l)
            efDa.Value = a; efDb.Value = a; efDc.Value = a;
            efDal.Value = 90; efDbe.Value = 90; efDga.Value = 90;
            efDh.Value = h; efDk.Value = k; efDl.Value = l;
            ddDSub.Value = '(none)';
            doDSpacing();
            txt = lblDResult.Text;
        end
        appData.api.getDResult = @() lblDResult.Text;
        appData.api.getMismatchResult = @() lblMMResult.Text;
        appData.api.calcPlaneSpacings = @(aVal, cent) apiPlaneSpacings(aVal, cent);
        function tbl = apiPlaneSpacings(aVal, cent)
            efDa.Value = aVal; efDb.Value = aVal; efDc.Value = aVal;
            efDal.Value = 90; efDbe.Value = 90; efDga.Value = 90;
            ddPSCent.Value = cent;
            doPlaneSpacings();
            tbl = psTableData;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 3: ELECTRICAL
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildElectricalTab(tab)
        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {'1x'};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        scroll = uipanel(outerGL,'BorderType','none','Scrollable','on');
        scroll.Layout.Row = 1; scroll.Layout.Column = 1;

        gl = uigridlayout(scroll);
        gl.RowHeight   = {90, 72, 72, 72};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [4 4 4 4];
        gl.RowSpacing  = 8;

        % ── Card 1: Resistivity / Sheet Resistance ─────────────────────
        pRS = uipanel(gl,'Title','Resistivity / Sheet Resistance','FontWeight','bold');
        pRS.Layout.Row = 1; pRS.Layout.Column = 1;

        gRS = uigridlayout(pRS);
        gRS.RowHeight   = {24, 24, 24};
        gRS.ColumnWidth = {70,'1x',70,'1x',90,90};
        gRS.Padding     = [6 4 6 4];
        gRS.RowSpacing  = 4;

        uilabel(gRS,'Text','R_s (\Omega/\sq):','HorizontalAlignment','right');
        efRsVal = uieditfield(gRS,'numeric','Value',100);
        efRsVal.Layout.Row=1; efRsVal.Layout.Column=2;
        uilabel(gRS,'Text','t (nm):','HorizontalAlignment','right');
        efRsTh = uieditfield(gRS,'numeric','Value',10);
        efRsTh.Layout.Row=1; efRsTh.Layout.Column=4;

        lblRsResult = uilabel(gRS,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblRsResult.Layout.Row=2; lblRsResult.Layout.Column=[1 4];

        btnRsToRho = uibutton(gRS,'push','Text','R_s \rightarrow \rho', ...
            'BackgroundColor',BTN_TOOL, ...
            'ButtonPushedFcn',@(~,~) doRsToRho());
        btnRsToRho.Layout.Row=2; btnRsToRho.Layout.Column=5;

        uilabel(gRS,'Text','\rho (\Omega\cdotcm):','HorizontalAlignment','right');
        efRhoVal = uieditfield(gRS,'numeric','Value',1e-4);
        efRhoVal.Layout.Row=3; efRhoVal.Layout.Column=2;

        lblRhoResult = uilabel(gRS,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblRhoResult.Layout.Row=3; lblRhoResult.Layout.Column=[3 4];

        btnRhoToRs = uibutton(gRS,'push','Text','\rho \rightarrow R_s', ...
            'BackgroundColor',BTN_TOOL, ...
            'ButtonPushedFcn',@(~,~) doRhoToRs());
        btnRhoToRs.Layout.Row=3; btnRhoToRs.Layout.Column=5;

        function doRsToRho()
            try
                % resistivity(Rs [Ohm/sq], t [cm])
                r = calc.electrical.resistivity(efRsVal.Value, efRsTh.Value*1e-7);
                desc = sprintf('%s = %.4g %s%scm  (R<sub>s</sub> = %.4g %s/sq, t = %.4g nm)', ...
                    char(961), r.rho, char(937), char(183), efRsVal.Value, char(937), efRsTh.Value);
                lblRsResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblRsResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        function doRhoToRs()
            try
                % sheetResistance(rho [Ohm·cm], t [cm])
                r = calc.electrical.sheetResistance(efRhoVal.Value, efRsTh.Value*1e-7);
                desc = sprintf('R<sub>s</sub> = %.4g %s/sq', r.Rs, char(937));
                lblRhoResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblRhoResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 2: Conductivity ───────────────────────────────────────
        pCond = uipanel(gl,'Title','Conductivity','FontWeight','bold');
        pCond.Layout.Row = 2; pCond.Layout.Column = 1;

        gCond = uigridlayout(pCond);
        gCond.RowHeight   = {24, 24};
        gCond.ColumnWidth = {80,'1x',80};
        gCond.Padding     = [6 4 6 4];
        gCond.RowSpacing  = 4;

        uilabel(gCond,'Text','\rho (\Omega\cdotcm):','HorizontalAlignment','right');
        efCondRho = uieditfield(gCond,'numeric','Value',1e-4);
        efCondRho.Layout.Row=1; efCondRho.Layout.Column=2;
        btnCondCalc = uibutton(gCond,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doConductivity());
        btnCondCalc.Layout.Row=1; btnCondCalc.Layout.Column=3;
        lblCondResult = uilabel(gCond,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblCondResult.Layout.Row=2; lblCondResult.Layout.Column=[1 3];

        function doConductivity()
            try
                % conductivity(rho [Ohm·cm]) → sigma [S/cm]
                r = calc.electrical.conductivity(efCondRho.Value);
                desc = sprintf('%s = %.4g S/cm  (%s = %.4g %s%scm)', ...
                    char(963), r.sigma, char(961), efCondRho.Value, char(937), char(183));
                lblCondResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblCondResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 3: Mobility ──────────────────────────────────────────
        pMob = uipanel(gl,'Title','Mobility','FontWeight','bold');
        pMob.Layout.Row = 3; pMob.Layout.Column = 1;

        gMob = uigridlayout(pMob);
        gMob.RowHeight   = {24, 24};
        gMob.ColumnWidth = {80,'1x',80,'1x',90};
        gMob.Padding     = [6 4 6 4];
        gMob.RowSpacing  = 4;

        uilabel(gMob,'Text','\rho (\Omega\cdotcm):','HorizontalAlignment','right');
        efMobRho = uieditfield(gMob,'numeric','Value',1e-2);
        efMobRho.Layout.Row=1; efMobRho.Layout.Column=2;
        uilabel(gMob,'Text','n (cm\^-3):','HorizontalAlignment','right');
        efMobN = uieditfield(gMob,'numeric','Value',1e17);
        efMobN.Layout.Row=1; efMobN.Layout.Column=4;
        btnMobCalc = uibutton(gMob,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doMobility());
        btnMobCalc.Layout.Row=1; btnMobCalc.Layout.Column=5;
        lblMobResult = uilabel(gMob,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblMobResult.Layout.Row=2; lblMobResult.Layout.Column=[1 5];

        function doMobility()
            try
                % mobility(rho [Ohm·cm], n [cm^-3]) → mu [cm²/V·s]
                r = calc.electrical.mobility(efMobRho.Value, efMobN.Value);
                desc = sprintf('%s = %.4g cm<sup>2</sup>/(V%ss)', char(956), r.mu, char(183));
                lblMobResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblMobResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Current Density ───────────────────────────────────
        pJD = uipanel(gl,'Title','Current Density','FontWeight','bold');
        pJD.Layout.Row = 4; pJD.Layout.Column = 1;

        gJD = uigridlayout(pJD);
        gJD.RowHeight   = {24, 24};
        gJD.ColumnWidth = {80,'1x',80,'1x',90};
        gJD.Padding     = [6 4 6 4];
        gJD.RowSpacing  = 4;

        uilabel(gJD,'Text','I (A):','HorizontalAlignment','right');
        efJDI = uieditfield(gJD,'numeric','Value',1e-3);
        efJDI.Layout.Row=1; efJDI.Layout.Column=2;
        uilabel(gJD,'Text','Area (cm\xb2):','HorizontalAlignment','right');
        efJDA = uieditfield(gJD,'numeric','Value',1);
        efJDA.Layout.Row=1; efJDA.Layout.Column=4;
        btnJDCalc = uibutton(gJD,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doCurrentDensity());
        btnJDCalc.Layout.Row=1; btnJDCalc.Layout.Column=5;
        lblJDResult = uilabel(gJD,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblJDResult.Layout.Row=2; lblJDResult.Layout.Column=[1 5];

        function doCurrentDensity()
            try
                % currentDensity(I [A], area [cm²]) → J [A/cm²]
                r = calc.electrical.currentDensity(efJDI.Value, efJDA.Value);
                desc = sprintf('J = %.4g A/cm<sup>2</sup> = %.4g mA/cm<sup>2</sup>', r.J, r.J*1e3);
                lblJDResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblJDResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 4: SEMICONDUCTOR
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildSemiconductorTab(tab)
        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {'1x'};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        scroll = uipanel(outerGL,'BorderType','none','Scrollable','on');
        scroll.Layout.Row = 1; scroll.Layout.Column = 1;

        gl = uigridlayout(scroll);
        gl.RowHeight   = {110, 90, 100, 80};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [4 4 4 4];
        gl.RowSpacing  = 8;

        % Material presets available for dropdowns
        matNames = {'Si','Ge','GaAs','InP','GaN','SiC'};

        % ── Card 1: Intrinsic Properties ──────────────────────────────
        pNi = uipanel(gl,'Title','Intrinsic Properties','FontWeight','bold');
        pNi.Layout.Row = 1; pNi.Layout.Column = 1;

        gNi = uigridlayout(pNi);
        gNi.RowHeight   = {24, 24, 24, 24};
        gNi.ColumnWidth = {65,'1x',65,'1x',65,'1x',80};
        gNi.Padding     = [6 4 6 4];
        gNi.RowSpacing  = 4;

        uilabel(gNi,'Text','Material:','HorizontalAlignment','right');
        ddNiMat = uidropdown(gNi,'Items',['(manual)',matNames],'Value','Si', ...
            'ValueChangedFcn',@(~,~) fillNiFromMaterial());
        ddNiMat.Layout.Row=1; ddNiMat.Layout.Column=2;
        uilabel(gNi,'Text','T (K):','HorizontalAlignment','right');
        efNiT = uieditfield(gNi,'numeric','Value',300);
        efNiT.Layout.Row=1; efNiT.Layout.Column=4;

        uilabel(gNi,'Text','Eg (eV):','HorizontalAlignment','right');
        efNiEg = uieditfield(gNi,'numeric','Value',1.12);
        efNiEg.Layout.Row=2; efNiEg.Layout.Column=2;
        uilabel(gNi,'Text','me*:','HorizontalAlignment','right');
        efNiMe = uieditfield(gNi,'numeric','Value',1.08);
        efNiMe.Layout.Row=2; efNiMe.Layout.Column=4;
        uilabel(gNi,'Text','mh*:','HorizontalAlignment','right');
        efNiMh = uieditfield(gNi,'numeric','Value',0.81);
        efNiMh.Layout.Row=2; efNiMh.Layout.Column=6;

        lblNiResult = uilabel(gNi,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblNiResult.Layout.Row=3; lblNiResult.Layout.Column=[1 6];
        lblNiNcNv = uilabel(gNi,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblNiNcNv.Layout.Row=4; lblNiNcNv.Layout.Column=[1 6];

        btnNiCalc = uibutton(gNi,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doIntrinsic());
        btnNiCalc.Layout.Row=3; btnNiCalc.Layout.Column=7;

        function fillNiFromMaterial()
            sel = ddNiMat.Value;
            if strcmp(sel,'(manual)'), return; end
            try
                m = calc.semiconductor.materialPresets();
                mat = m.(sel);
                efNiEg.Value = mat.Eg;
                efNiMe.Value = mat.me;
                efNiMh.Value = mat.mh;
            catch; end
        end
        fillNiFromMaterial();

        function doIntrinsic()
            try
                r = calc.semiconductor.intrinsicCarrierConc( ...
                    Eg=efNiEg.Value, meStar=efNiMe.Value, mhStar=efNiMh.Value, ...
                    T=efNiT.Value);
                desc = sprintf('n<sub>i</sub> = %.4g cm<sup>-3</sup>  (T = %g K)', r.ni, r.T);
                lblNiResult.Text = desc;
                lblNiNcNv.Text = sprintf('N<sub>c</sub> = %.3g cm<sup>-3</sup>,  N<sub>v</sub> = %.3g cm<sup>-3</sup>', r.Nc, r.Nv);
                addHistory(desc, r.latex);
            catch ME
                lblNiResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 2: Doping & Fermi Level ──────────────────────────────
        pDop = uipanel(gl,'Title','Doping & Carrier Concentrations','FontWeight','bold');
        pDop.Layout.Row = 2; pDop.Layout.Column = 1;

        gDop = uigridlayout(pDop);
        gDop.RowHeight   = {24, 24, 24};
        gDop.ColumnWidth = {65,'1x',65,'1x',65,'1x',80};
        gDop.Padding     = [6 4 6 4];
        gDop.RowSpacing  = 4;

        uilabel(gDop,'Text','Nd (cm\x207b\xb3):','HorizontalAlignment','right');
        efDopNd = uieditfield(gDop,'numeric','Value',1e16);
        efDopNd.Layout.Row=1; efDopNd.Layout.Column=2;
        uilabel(gDop,'Text','Na (cm\x207b\xb3):','HorizontalAlignment','right');
        efDopNa = uieditfield(gDop,'numeric','Value',0);
        efDopNa.Layout.Row=1; efDopNa.Layout.Column=4;
        uilabel(gDop,'Text','ni (cm\x207b\xb3):','HorizontalAlignment','right');
        efDopNi = uieditfield(gDop,'numeric','Value',1.5e10);
        efDopNi.Layout.Row=1; efDopNi.Layout.Column=6;

        lblDopResult = uilabel(gDop,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDopResult.Layout.Row=2; lblDopResult.Layout.Column=[1 6];
        lblDopType = uilabel(gDop,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDopType.Layout.Row=3; lblDopType.Layout.Column=[1 6];

        btnDopCalc = uibutton(gDop,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDoping());
        btnDopCalc.Layout.Row=2; btnDopCalc.Layout.Column=7;

        function doDoping()
            try
                niVal = efDopNi.Value;
                if niVal <= 0, niVal = 1e-10; end
                r = calc.semiconductor.carrierConcentration( ...
                    efDopNd.Value, max(efDopNa.Value,0), niVal);
                desc = sprintf('n = %.3g cm<sup>-3</sup>,  p = %.3g cm<sup>-3</sup>  [%s-type]', ...
                    r.n, r.p, r.type);
                lblDopResult.Text = desc;
                lblDopType.Text = sprintf('Type: %s', r.type);
                addHistory(desc, r.latex);
            catch ME
                lblDopResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 3: Depletion & Junction ──────────────────────────────
        pDep = uipanel(gl,'Title','Depletion Width (p-n Junction)','FontWeight','bold');
        pDep.Layout.Row = 3; pDep.Layout.Column = 1;

        gDep = uigridlayout(pDep);
        gDep.RowHeight   = {24, 24, 24, 24};
        gDep.ColumnWidth = {65,'1x',65,'1x',65,'1x',80};
        gDep.Padding     = [6 4 6 4];
        gDep.RowSpacing  = 4;

        uilabel(gDep,'Text','Material:','HorizontalAlignment','right');
        ddDepMat = uidropdown(gDep,'Items',['(manual)',matNames],'Value','Si');
        ddDepMat.Layout.Row=1; ddDepMat.Layout.Column=2;
        uilabel(gDep,'Text','\epsilon_r:','HorizontalAlignment','right');
        efDepEps = uieditfield(gDep,'numeric','Value',11.7);
        efDepEps.Layout.Row=1; efDepEps.Layout.Column=4;

        uilabel(gDep,'Text','Vbi (V):','HorizontalAlignment','right');
        efDepVbi = uieditfield(gDep,'numeric','Value',0.7);
        efDepVbi.Layout.Row=2; efDepVbi.Layout.Column=2;
        uilabel(gDep,'Text','Na (cm\x207b\xb3):','HorizontalAlignment','right');
        efDepNa = uieditfield(gDep,'numeric','Value',1e16);
        efDepNa.Layout.Row=2; efDepNa.Layout.Column=4;
        uilabel(gDep,'Text','Nd (cm\x207b\xb3):','HorizontalAlignment','right');
        efDepNd = uieditfield(gDep,'numeric','Value',1e17);
        efDepNd.Layout.Row=2; efDepNd.Layout.Column=6;

        lblDepResult = uilabel(gDep,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDepResult.Layout.Row=3; lblDepResult.Layout.Column=[1 6];
        lblDepXnXp = uilabel(gDep,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDepXnXp.Layout.Row=4; lblDepXnXp.Layout.Column=[1 6];

        btnDepCalc = uibutton(gDep,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDepletion());
        btnDepCalc.Layout.Row=3; btnDepCalc.Layout.Column=7;

        ddDepMat.ValueChangedFcn = @(~,~) fillDepMaterial();

        function fillDepMaterial()
            sel = ddDepMat.Value;
            if strcmp(sel,'(manual)'), return; end
            try
                m = calc.semiconductor.materialPresets();
                mat = m.(sel);
                efDepEps.Value = mat.eps_r;
            catch; end
        end

        function doDepletion()
            try
                r = calc.semiconductor.depletionWidth( ...
                    epsilon_r=efDepEps.Value, ...
                    Vbi=efDepVbi.Value, ...
                    Na=efDepNa.Value, ...
                    Nd=efDepNd.Value);
                desc = sprintf('W = %.4g nm  (V<sub>bi</sub> = %.3g V)', r.W, efDepVbi.Value);
                lblDepResult.Text = desc;
                lblDepXnXp.Text = sprintf('x<sub>n</sub> = %.4g nm,  x<sub>p</sub> = %.4g nm', r.xn, r.xp);
                addHistory(desc, r.latex);
            catch ME
                lblDepResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Transport ─────────────────────────────────────────
        pTrans = uipanel(gl,'Title','Transport (Diffusion Coefficient & Length)','FontWeight','bold');
        pTrans.Layout.Row = 4; pTrans.Layout.Column = 1;

        gTrans = uigridlayout(pTrans);
        gTrans.RowHeight   = {24, 24, 24};
        gTrans.ColumnWidth = {80,'1x',80,'1x',80};
        gTrans.Padding     = [6 4 6 4];
        gTrans.RowSpacing  = 4;

        uilabel(gTrans,'Text','\mu (cm\xb2/V\xb7s):','HorizontalAlignment','right');
        efTransMu = uieditfield(gTrans,'numeric','Value',1400);
        efTransMu.Layout.Row=1; efTransMu.Layout.Column=2;
        uilabel(gTrans,'Text','\tau (s):','HorizontalAlignment','right');
        efTransTau = uieditfield(gTrans,'numeric','Value',1e-6);
        efTransTau.Layout.Row=1; efTransTau.Layout.Column=4;

        btnTransCalc = uibutton(gTrans,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doTransport());
        btnTransCalc.Layout.Row=1; btnTransCalc.Layout.Column=5;

        lblTransD = uilabel(gTrans,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblTransD.Layout.Row=2; lblTransD.Layout.Column=[1 5];
        lblTransL = uilabel(gTrans,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblTransL.Layout.Row=3; lblTransL.Layout.Column=[1 5];

        function doTransport()
            try
                rD = calc.semiconductor.diffusionCoeff(efTransMu.Value);
                rL = calc.semiconductor.diffusionLength(rD.D, efTransTau.Value);
                lblTransD.Text = sprintf('D = %.4g cm<sup>2</sup>/s', rD.D);
                desc = sprintf('L = %.4g %sm  (D = %.4g cm<sup>2</sup>/s, %s = %.3g s)', ...
                    rL.Lum, char(956), rD.D, char(964), efTransTau.Value);
                lblTransL.Text = desc;
                addHistory(desc, rL.latex);
            catch ME
                lblTransD.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % API hooks
        appData.api.calcIntrinsic = @(mat) apiIntrinsic(mat);
        function txt = apiIntrinsic(mat)
            ddNiMat.Value = mat;
            fillNiFromMaterial();
            doIntrinsic();
            txt = lblNiResult.Text;
        end
        appData.api.getNiResult = @() lblNiResult.Text;
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 5: THIN FILM
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildThinFilmTab(tab)
        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {'1x'};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        scroll = uipanel(outerGL,'BorderType','none','Scrollable','on');
        scroll.Layout.Row = 1; scroll.Layout.Column = 1;

        gl = uigridlayout(scroll);
        gl.RowHeight   = {72, 72, 90, 110, 72};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [4 4 4 4];
        gl.RowSpacing  = 8;

        subNames = calc.substrates.listSubstrates();

        % ── Card 1: Deposition Rate ────────────────────────────────────
        pDep = uipanel(gl,'Title','Deposition Rate','FontWeight','bold');
        pDep.Layout.Row = 1; pDep.Layout.Column = 1;

        gDR = uigridlayout(pDep);
        gDR.RowHeight   = {24, 24};
        gDR.ColumnWidth = {80,'1x',60,'1x',90};
        gDR.Padding     = [6 4 6 4];
        gDR.RowSpacing  = 4;

        uilabel(gDR,'Text','Thickness (Å):','HorizontalAlignment','right');
        efDRThick = uieditfield(gDR,'numeric','Value',1000);
        efDRThick.Layout.Row=1; efDRThick.Layout.Column=2;
        uilabel(gDR,'Text','Time (s):','HorizontalAlignment','right');
        efDRTime = uieditfield(gDR,'numeric','Value',60);
        efDRTime.Layout.Row=1; efDRTime.Layout.Column=4;
        btnDRCalc = uibutton(gDR,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDepositionRate());
        btnDRCalc.Layout.Row=1; btnDRCalc.Layout.Column=5;
        lblDRResult = uilabel(gDR,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDRResult.Layout.Row=2; lblDRResult.Layout.Column=[1 5];

        function doDepositionRate()
            try
                r = calc.thinFilm.depositionRate(efDRThick.Value, efDRTime.Value);
                desc = sprintf('Rate = %.4g %s/s = %.4g nm/min', r.rate, char(197), r.rateNmPerMin);
                lblDRResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblDRResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 2: Kiessig Thickness ─────────────────────────────────
        pKT = uipanel(gl,'Title','Kiessig Fringe Thickness','FontWeight','bold');
        pKT.Layout.Row = 2; pKT.Layout.Column = 1;

        gKT = uigridlayout(pKT);
        gKT.RowHeight   = {24, 24};
        gKT.ColumnWidth = {80,'1x',90};
        gKT.Padding     = [6 4 6 4];
        gKT.RowSpacing  = 4;

        uilabel(gKT,'Text','\DeltaQ (Å\^{-1}):','HorizontalAlignment','right');
        efKTdQ = uieditfield(gKT,'numeric','Value',0.1);
        efKTdQ.Layout.Row=1; efKTdQ.Layout.Column=2;
        btnKTCalc = uibutton(gKT,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doKiessig());
        btnKTCalc.Layout.Row=1; btnKTCalc.Layout.Column=3;
        lblKTResult = uilabel(gKT,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblKTResult.Layout.Row=2; lblKTResult.Layout.Column=[1 3];

        function doKiessig()
            try
                r = calc.thinFilm.kiessigThickness(efKTdQ.Value);
                % .thicknessNm confirmed from module
                tNm = r.thicknessNm;
                desc = sprintf('t = %.4g nm  (%sQ = %.4g %s<sup>-1</sup>)', tNm, char(916), efKTdQ.Value, char(197));
                lblKTResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblKTResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 3: Stoney Stress ─────────────────────────────────────
        pSS = uipanel(gl,'Title','Stoney Film Stress','FontWeight','bold');
        pSS.Layout.Row = 3; pSS.Layout.Column = 1;

        gSS = uigridlayout(pSS);
        gSS.RowHeight   = {24, 24, 24};
        gSS.ColumnWidth = {70,'1x',70,'1x',70,'1x',80};
        gSS.Padding     = [6 4 6 4];
        gSS.RowSpacing  = 4;

        uilabel(gSS,'Text','Es (GPa):','HorizontalAlignment','right');
        efSSEs = uieditfield(gSS,'numeric','Value',130);
        efSSEs.Layout.Row=1; efSSEs.Layout.Column=2;
        uilabel(gSS,'Text','\nus:','HorizontalAlignment','right');
        efSSNus = uieditfield(gSS,'numeric','Value',0.28);
        efSSNus.Layout.Row=1; efSSNus.Layout.Column=4;
        uilabel(gSS,'Text','ts (\mum):','HorizontalAlignment','right');
        efSSts = uieditfield(gSS,'numeric','Value',500);
        efSSts.Layout.Row=1; efSSts.Layout.Column=6;

        uilabel(gSS,'Text','tf (nm):','HorizontalAlignment','right');
        efSStf = uieditfield(gSS,'numeric','Value',100);
        efSStf.Layout.Row=2; efSStf.Layout.Column=2;
        uilabel(gSS,'Text','R (m):','HorizontalAlignment','right');
        efSSR = uieditfield(gSS,'numeric','Value',10);
        efSSR.Layout.Row=2; efSSR.Layout.Column=4;

        lblSSResult = uilabel(gSS,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblSSResult.Layout.Row=3; lblSSResult.Layout.Column=[1 6];
        btnSSCalc = uibutton(gSS,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doStoney());
        btnSSCalc.Layout.Row=2; btnSSCalc.Layout.Column=7;

        function doStoney()
            try
                r = calc.thinFilm.stoneyStress(efSSEs.Value*1e9, efSSNus.Value, ...
                    efSSts.Value*1e-6, efSStf.Value*1e-9, efSSR.Value);
                if r.stressMPa > 0
                    stype = 'tensile';
                else
                    stype = 'compressive';
                end
                desc = sprintf('%s = %.4g MPa  (%s)', char(963), r.stressMPa, stype);
                lblSSResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblSSResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Thermal Mismatch ──────────────────────────────────
        pTM = uipanel(gl,'Title','Thermal Mismatch Strain & Stress','FontWeight','bold');
        pTM.Layout.Row = 4; pTM.Layout.Column = 1;

        gTM = uigridlayout(pTM);
        gTM.RowHeight   = {24, 24, 24, 24};
        gTM.ColumnWidth = {80,'1x',80,'1x',80,'1x'};
        gTM.Padding     = [6 4 6 4];
        gTM.RowSpacing  = 4;

        uilabel(gTM,'Text','\alpha film (1/K):','HorizontalAlignment','right');
        efTMAlF = uieditfield(gTM,'numeric','Value',17e-6);
        efTMAlF.Layout.Row=1; efTMAlF.Layout.Column=2;
        uilabel(gTM,'Text','\alpha sub (1/K):','HorizontalAlignment','right');
        efTMAlS = uieditfield(gTM,'numeric','Value',3e-6);
        efTMAlS.Layout.Row=1; efTMAlS.Layout.Column=4;

        ddTMSub = uidropdown(gTM,'Items',['(manual)',subNames],'Value','(manual)', ...
            'ValueChangedFcn',@(~,~) fillTMSubstrate());
        ddTMSub.Layout.Row=1; ddTMSub.Layout.Column=6;

        uilabel(gTM,'Text','\DeltaT (K):','HorizontalAlignment','right');
        efTMdT = uieditfield(gTM,'numeric','Value',-500);
        efTMdT.Layout.Row=2; efTMdT.Layout.Column=2;
        uilabel(gTM,'Text','E (GPa):','HorizontalAlignment','right');
        efTME = uieditfield(gTM,'numeric','Value',200);
        efTME.Layout.Row=2; efTME.Layout.Column=4;
        uilabel(gTM,'Text','\nu:','HorizontalAlignment','right');
        efTMNu = uieditfield(gTM,'numeric','Value',0.28);
        efTMNu.Layout.Row=2; efTMNu.Layout.Column=6;

        lblTMStrain = uilabel(gTM,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblTMStrain.Layout.Row=3; lblTMStrain.Layout.Column=[1 4];
        lblTMStress = uilabel(gTM,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblTMStress.Layout.Row=4; lblTMStress.Layout.Column=[1 4];

        btnTMCalc = uibutton(gTM,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doThermalMismatch());
        btnTMCalc.Layout.Row=3; btnTMCalc.Layout.Column=[5 6];

        function fillTMSubstrate()
            sel = ddTMSub.Value;
            if strcmp(sel,'(manual)'), return; end
            try
                s = calc.substrates.getSubstrate(sel);
                efTMAlS.Value = s.thermalExpansion * 1e-6;
            catch; end
        end

        function doThermalMismatch()
            try
                r = calc.thinFilm.thermalMismatchStrain(efTMAlF.Value, efTMAlS.Value, ...
                    efTMdT.Value, E=efTME.Value*1e9, nu=efTMNu.Value);
                lblTMStrain.Text = sprintf('%s = %.4g  (%s)', char(949), r.strain, r.description);
                if ~isnan(r.stressMPa)
                    lblTMStress.Text = sprintf('%s = %.4g MPa', char(963), r.stressMPa);
                else
                    lblTMStress.Text = '';
                end
                addHistory(lblTMStrain.Text, r.latex);
            catch ME
                lblTMStrain.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 5: Ion Dose ──────────────────────────────────────────
        pID = uipanel(gl,'Title','Ion Dose','FontWeight','bold');
        pID.Layout.Row = 5; pID.Layout.Column = 1;

        gID = uigridlayout(pID);
        gID.RowHeight   = {24, 24};
        gID.ColumnWidth = {80,'1x',80,'1x',80,'1x',90};
        gID.Padding     = [6 4 6 4];
        gID.RowSpacing  = 4;

        uilabel(gID,'Text','Current (A):','HorizontalAlignment','right');
        efIDCurr = uieditfield(gID,'numeric','Value',1e-6);
        efIDCurr.Layout.Row=1; efIDCurr.Layout.Column=2;
        uilabel(gID,'Text','Time (s):','HorizontalAlignment','right');
        efIDTime = uieditfield(gID,'numeric','Value',60);
        efIDTime.Layout.Row=1; efIDTime.Layout.Column=4;
        uilabel(gID,'Text','Area (cm\xb2):','HorizontalAlignment','right');
        efIDArea = uieditfield(gID,'numeric','Value',1);
        efIDArea.Layout.Row=1; efIDArea.Layout.Column=6;
        btnIDCalc = uibutton(gID,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doIonDose());
        btnIDCalc.Layout.Row=1; btnIDCalc.Layout.Column=7;
        lblIDResult = uilabel(gID,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblIDResult.Layout.Row=2; lblIDResult.Layout.Column=[1 7];

        function doIonDose()
            try
                % doseFromCurrent(current [A], time [s], area [cm²])
                r = calc.thinFilm.doseFromCurrent(efIDCurr.Value, efIDTime.Value, ...
                    efIDArea.Value);
                desc = sprintf('Dose = %.4g ions/cm<sup>2</sup>', r.dose);
                lblIDResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblIDResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 6: PERIODIC TABLE
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildPeriodicTableTab(tab)
        % Main layout: toolbar row + table area + detail panel
        gl = uigridlayout(tab);
        gl.RowHeight   = {28, '1x', 110};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 4 6 4];
        gl.RowSpacing  = 4;

        % ── Toolbar ───────────────────────────────────────────────────
        tbGL = uigridlayout(gl);
        tbGL.Layout.Row = 1; tbGL.Layout.Column = 1;
        tbGL.RowHeight   = {22};
        tbGL.ColumnWidth = {70, '1x', 80, '1x'};
        tbGL.Padding     = [0 0 0 0];
        tbGL.RowSpacing  = 0;

        uilabel(tbGL,'Text','Property:','HorizontalAlignment','right');
        ddProp = uidropdown(tbGL, 'Items', { ...
            'Atomic Mass','Density','Electronegativity', ...
            'Atomic Radius (pm)','Ionization Energy (eV)', ...
            'Melting Point (K)','Electron Affinity (eV)' ...
            }, 'Value', 'Atomic Mass', ...
            'ValueChangedFcn', @(~,~) refreshPTColors());
        ddProp.Layout.Row = 1; ddProp.Layout.Column = 2;
        uilabel(tbGL,'Text','Search:','HorizontalAlignment','right');
        efSearch = uieditfield(tbGL,'text','Value','', ...
            'ValueChangedFcn',@(~,~) doSearch());
        efSearch.Layout.Row = 1; efSearch.Layout.Column = 4;

        % ── Periodic Table Grid ───────────────────────────────────────
        tablePanel = uipanel(gl,'BorderType','none');
        tablePanel.Layout.Row = 2; tablePanel.Layout.Column = 1;

        ptGL = uigridlayout(tablePanel);
        ptGL.RowHeight   = repmat({'1x'}, 1, 10);
        ptGL.ColumnWidth = repmat({'1x'}, 1, 18);
        ptGL.Padding     = [2 2 2 2];
        ptGL.RowSpacing  = 1;
        ptGL.ColumnSpacing = 1;

        % ── Detail Panel ──────────────────────────────────────────────
        taDetail = uitextarea(gl,'Editable','off','FontSize',10, ...
            'FontName','Courier New');
        taDetail.Layout.Row = 3; taDetail.Layout.Column = 1;
        taDetail.Value = {'Click an element to see properties.'};

        % ── Element Color Map ─────────────────────────────────────────
        catColors = containers.Map({ ...
            'alkali metal','alkaline earth metal','transition metal', ...
            'post-transition metal','metalloid','nonmetal','noble gas', ...
            'lanthanide','actinide','unknown','polyatomic nonmetal', ...
            'diatomic nonmetal','reactive nonmetal'}, { ...
            [0.85 0.55 0.55], [0.90 0.75 0.50], [0.70 0.80 0.90], ...
            [0.65 0.75 0.65], [0.75 0.85 0.65], [0.65 0.85 0.65], ...
            [0.75 0.70 0.90], [0.85 0.75 0.85], [0.90 0.80 0.75], ...
            [0.85 0.85 0.85], [0.65 0.85 0.65], [0.65 0.85 0.65], ...
            [0.65 0.85 0.65]});

        % ── Periodic Table Layout ─────────────────────────────────────
        % [symbol, Z, row, col]  (1-indexed grid)
        ptLayout = buildPTLayout();

        % Load element data once
        allEls = calc.elementData();

        % Build buttons
        ptBtns = containers.Map('KeyType','char','ValueType','any');

        for ei = 1:numel(ptLayout)
            entry = ptLayout(ei);
            sym   = entry.symbol;
            elIdx = find(strcmp({allEls.symbol}, sym), 1);
            if isempty(elIdx), continue; end
            el    = allEls(elIdx);

            % Category color
            cat = lower(el.category);
            if catColors.isKey(cat)
                bgCol = catColors(cat);
            else
                bgCol = [0.85 0.85 0.85];
            end

            btnText = sprintf('%d\n%s', el.Z, el.symbol);
            btn = uibutton(ptGL, 'push', 'Text', btnText, ...
                'FontSize', 8, 'FontWeight', 'normal', ...
                'BackgroundColor', bgCol, ...
                'ButtonPushedFcn', @(~,~) doSelectElement(sym));
            btn.Layout.Row    = entry.row;
            btn.Layout.Column = entry.col;
            ptBtns(sym) = btn;
        end

        % ── CALLBACKS ─────────────────────────────────────────────────

        function doSelectElement(sym)
            try
                el = calc.elementData('bySymbol', sym);
                lines = formatElementDetail(el);
                taDetail.Value = lines;
                setStatus(sprintf('%s (%s) — Z=%d', el.name, el.symbol, el.Z));
            catch ME
                taDetail.Value = {['Error: ' ME.message]};
            end
        end

        function refreshPTColors()
            % Called when property dropdown changes — no color re-mapping needed
            % (category colors are fixed; property selection only affects detail)
            setStatus(sprintf('Property: %s', ddProp.Value));
        end

        function doSearch()
            query = lower(strtrim(efSearch.Value));
            if isempty(query)
                % Reset all to normal weight
                k = ptBtns.keys;
                for ki = 1:numel(k)
                    b = ptBtns(k{ki});
                    if isvalid(b)
                        b.FontWeight = 'normal';
                        b.FontSize   = 8;
                    end
                end
                return
            end
            k = ptBtns.keys;
            for ki = 1:numel(k)
                sym = k{ki};
                b = ptBtns(sym);
                if ~isvalid(b), continue; end
                try
                    el = calc.elementData('bySymbol', sym);
                    match = contains(lower(el.name), query) || ...
                            contains(lower(el.symbol), query);
                    if match
                        b.FontWeight = 'bold';
                        b.FontSize   = 9;
                    else
                        b.FontWeight = 'normal';
                        b.FontSize   = 8;
                    end
                catch; end
            end
        end

        function lines = formatElementDetail(el)
            propName = ddProp.Value;
            switch propName
                case 'Atomic Mass',             propVal = el.mass;             propUnit = 'u';
                case 'Density',                 propVal = el.density;          propUnit = 'g/cm³';
                case 'Electronegativity',       propVal = el.electronegativity; propUnit = '(Pauling)';
                case 'Atomic Radius (pm)',      propVal = el.atomicRadius;     propUnit = 'pm';
                case 'Ionization Energy (eV)',  propVal = el.ionizationEnergy; propUnit = 'eV';
                case 'Melting Point (K)',        propVal = el.meltingPoint;     propUnit = 'K';
                case 'Electron Affinity (eV)',  propVal = el.electronAffinity; propUnit = 'eV';
                otherwise,                      propVal = NaN;                 propUnit = '';
            end

            if isnan(propVal)
                propStr = sprintf('%s: N/A', propName);
            else
                propStr = sprintf('%s: %.4g %s', propName, propVal, propUnit);
            end

            lines = { ...
                sprintf('%-4s  %s  (Z = %d)', el.symbol, el.name, el.Z), ...
                sprintf('Category: %s  |  Period %d, Group %d', el.category, el.period, el.group), ...
                sprintf('Atomic Mass: %.4f u', el.mass), ...
                propStr, ...
                sprintf('Config: %s', el.electronConfig), ...
                sprintf('Melting: %s K    Boiling: %s K', ...
                    numOrNA(el.meltingPoint), numOrNA(el.boilingPoint)), ...
                sprintf('Density: %s g/cm³    Elect.: %s (Pauling)', ...
                    numOrNA(el.density), numOrNA(el.electronegativity)), ...
                sprintf('Ioniz. E: %s eV    Electron Affinity: %s eV', ...
                    numOrNA(el.ionizationEnergy), numOrNA(el.electronAffinity)), ...
            };
        end

        function s = numOrNA(v)
            if isnan(v)
                s = 'N/A';
            else
                s = sprintf('%.4g', v);
            end
        end

        % API hooks
        appData.api.selectElement = @(sym) doSelectElement(sym);
        appData.api.getElementDetail = @() taDetail.Value;
    end

% ════════════════════════════════════════════════════════════════════════
% FIGURE CLOSE CALLBACK
% ════════════════════════════════════════════════════════════════════════

    function onFigureClose(~, ~)
        delete(fig);
    end

end  % materialsCalcGUI

% ════════════════════════════════════════════════════════════════════════
% PERIODIC TABLE LAYOUT DATA
% Returns struct array with .symbol, .row, .col for the 18x10 grid.
% Rows 1-7: main table; Row 8: gap; Rows 9-10: lanthanides/actinides
% ════════════════════════════════════════════════════════════════════════

function entries = buildPTLayout()
% Standard periodic table positions [symbol, row, col]
raw = { ...
    'H',  1,  1;  'He', 1, 18; ...
    'Li', 2,  1;  'Be', 2,  2;  'B',  2, 13;  'C',  2, 14;  'N',  2, 15;  'O',  2, 16;  'F',  2, 17;  'Ne', 2, 18; ...
    'Na', 3,  1;  'Mg', 3,  2;  'Al', 3, 13;  'Si', 3, 14;  'P',  3, 15;  'S',  3, 16;  'Cl', 3, 17;  'Ar', 3, 18; ...
    'K',  4,  1;  'Ca', 4,  2;  'Sc', 4,  3;  'Ti', 4,  4;  'V',  4,  5;  'Cr', 4,  6;  'Mn', 4,  7;  'Fe', 4,  8;  'Co', 4,  9;  'Ni', 4, 10;  'Cu', 4, 11;  'Zn', 4, 12;  'Ga', 4, 13;  'Ge', 4, 14;  'As', 4, 15;  'Se', 4, 16;  'Br', 4, 17;  'Kr', 4, 18; ...
    'Rb', 5,  1;  'Sr', 5,  2;  'Y',  5,  3;  'Zr', 5,  4;  'Nb', 5,  5;  'Mo', 5,  6;  'Tc', 5,  7;  'Ru', 5,  8;  'Rh', 5,  9;  'Pd', 5, 10;  'Ag', 5, 11;  'Cd', 5, 12;  'In', 5, 13;  'Sn', 5, 14;  'Sb', 5, 15;  'Te', 5, 16;  'I',  5, 17;  'Xe', 5, 18; ...
    'Cs', 6,  1;  'Ba', 6,  2;  'La', 6,  3;  'Hf', 6,  4;  'Ta', 6,  5;  'W',  6,  6;  'Re', 6,  7;  'Os', 6,  8;  'Ir', 6,  9;  'Pt', 6, 10;  'Au', 6, 11;  'Hg', 6, 12;  'Tl', 6, 13;  'Pb', 6, 14;  'Bi', 6, 15;  'Po', 6, 16;  'At', 6, 17;  'Rn', 6, 18; ...
    'Fr', 7,  1;  'Ra', 7,  2;  'Ac', 7,  3;  'Rf', 7,  4;  'Db', 7,  5;  'Sg', 7,  6;  'Bh', 7,  7;  'Hs', 7,  8;  'Mt', 7,  9;  'Ds', 7, 10;  'Rg', 7, 11;  'Cn', 7, 12;  'Nh', 7, 13;  'Fl', 7, 14;  'Mc', 7, 15;  'Lv', 7, 16;  'Ts', 7, 17;  'Og', 7, 18; ...
    'Ce', 9,  4;  'Pr', 9,  5;  'Nd', 9,  6;  'Pm', 9,  7;  'Sm', 9,  8;  'Eu', 9,  9;  'Gd', 9, 10;  'Tb', 9, 11;  'Dy', 9, 12;  'Ho', 9, 13;  'Er', 9, 14;  'Tm', 9, 15;  'Yb', 9, 16;  'Lu', 9, 17; ...
    'Th',10,  4;  'Pa',10,  5;  'U', 10,  6;  'Np',10,  7;  'Pu',10,  8;  'Am',10,  9;  'Cm',10, 10;  'Bk',10, 11;  'Cf',10, 12;  'Es',10, 13;  'Fm',10, 14;  'Md',10, 15;  'No',10, 16;  'Lr',10, 17; ...
};

n = size(raw, 1);
entries(n) = struct('symbol', '', 'row', 0, 'col', 0);
for k = 1:n
    entries(k).symbol = raw{k,1};
    entries(k).row    = raw{k,2};
    entries(k).col    = raw{k,3};
end
end
