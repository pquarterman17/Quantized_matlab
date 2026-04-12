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
bp_ = styles.buttonPalette();
BTN_PRIMARY = bp_.primary;   % green — primary action
BTN_TOOL    = bp_.tool;      % dark gray — secondary / tool
BTN_TOOL_FG = [0.95 0.95 0.95];   % light text on tool buttons
BTN_EXPORT  = bp_.export;    % slate — copy / export
BTN_FG      = bp_.fg;        % white foreground text
INPUT_BG    = [0.18 0.18 0.18];   % dark input background
INPUT_FG    = [0.90 0.90 0.90];   % light input text

% ════════════════════════════════════════════════════════════════════════
% DARK THEME COLORS
% ════════════════════════════════════════════════════════════════════════
FIG_BG      = [0.13 0.13 0.13];   % figure / panel background
SIDEBAR_BG  = [0.10 0.10 0.10];   % slightly darker sidebar
LABEL_FG    = [0.85 0.85 0.85];   % label text on dark backgrounds
STATUSBAR_BG = [0.10 0.10 0.10];  % status bar background

% ════════════════════════════════════════════════════════════════════════
% MAIN FIGURE
% ════════════════════════════════════════════════════════════════════════
fig = uifigure('Name', 'Materials Calculator — Thin Film Toolkit', ...
    'Position', [80 60 780 640], ...
    'Resize', 'on', ...
    'Color', FIG_BG);
fig.CloseRequestFcn = @onFigureClose;

% Root grid: nav sidebar | content area, plus status bar
rootGL = uigridlayout(fig);
rootGL.RowHeight    = {'1x', 22};
rootGL.ColumnWidth  = {160, '1x'};
rootGL.Padding      = [0 0 0 0];
rootGL.RowSpacing   = 0;
rootGL.ColumnSpacing = 0;
rootGL.BackgroundColor = FIG_BG;

% Navigation tree (categorised sidebar)
% Each category holds leaf nodes whose NodeData is the navKey string.
navTree = uitree(rootGL, ...
    'SelectionChangedFcn', @onNavChanged, ...
    'FontSize', 11, ...
    'BackgroundColor', SIDEBAR_BG);
navTree.Layout.Row    = 1;
navTree.Layout.Column = 1;
% FontColor was added after R2021b — set defensively
try; navTree.FontColor = LABEL_FG; catch; end

% ── tree category definitions ──────────────────────────────────────────
navCategories = { ...
    'Reference',         {'Unit Converter',  'unitConverter'; ...
                          [char(9660) ' History'],   'history'; ...
                          [char(9733) ' Favorites'], 'favorites'}; ...
    'Materials',         {'Crystal',          'crystal'; ...
                          'Thin Film',         'thinFilm'; ...
                          'Substrates',        'substrates'; ...
                          'Periodic Table',    'periodicTable'}; ...
    'Electronic',        {'Electrical',        'electrical'; ...
                          'Semiconductor',     'semiconductor'; ...
                          'Electrochem',       'electrochemistry'}; ...
    'Optics & Scattering', {'Optics',          'optics'; ...
                          'X-ray/Neutron',     'xrayNeutron'; ...
                          'Reflectivity',      'reflectivity'}; ...
    'Thermal-Magnetic',  {'Superconductor',    'superconductor'; ...
                          'Magnetic',          'magnetic'; ...
                          'Thermal',           'thermal'; ...
                          'Diffusion',         'diffusion'; ...
                          'Vacuum',            'vacuum'}; ...
};

% Build the tree and collect a navKey → node map for selectPanel
navNodeMap = containers.Map('KeyType','char','ValueType','any');
for ci = 1:size(navCategories, 1)
    catName   = navCategories{ci, 1};
    leaves    = navCategories{ci, 2};   % Nx2 cell: {displayName, key}
    catNode   = uitreenode(navTree, 'Text', catName);
    for li = 1:size(leaves, 1)
        leafNode = uitreenode(catNode, ...
            'Text',     leaves{li, 1}, ...
            'NodeData', leaves{li, 2});
        navNodeMap(leaves{li, 2}) = leafNode;
    end
    expand(catNode);
end

% Also build flat navKeys list for panels loop (order must match navNames order)
navKeys  = {'unitConverter', 'crystal', 'electrical', 'semiconductor', ...
            'thinFilm', 'xrayNeutron', 'superconductor', 'magnetic', ...
            'optics', 'vacuum', 'electrochemistry', 'thermal', 'diffusion', ...
            'reflectivity', 'substrates', 'periodicTable', 'favorites', 'history'};

% Select the first node (activeNavKey is set in APP STATE block below)
navTree.SelectedNodes = navNodeMap('unitConverter');

% Content area — grid layout so each panel gets proper sizing
contentGL = uigridlayout(rootGL);
contentGL.Layout.Row    = 1;
contentGL.Layout.Column = 2;
contentGL.RowHeight     = {'1x'};
contentGL.ColumnWidth   = {'1x'};
contentGL.Padding       = [0 0 0 0];
contentGL.BackgroundColor = FIG_BG;

% Status bar with copy + favorites buttons
statusGL = uigridlayout(rootGL);
statusGL.Layout.Row = 2; statusGL.Layout.Column = [1 2];
statusGL.RowHeight = {'1x'}; statusGL.ColumnWidth = {'1x', 90, 90, 90};
statusGL.Padding = [4 0 4 0]; statusGL.ColumnSpacing = 4;
statusGL.BackgroundColor = STATUSBAR_BG;

lblStatus = uilabel(statusGL, ...
    'Text', 'Ready', ...
    'FontSize', 11, ...
    'FontColor', LABEL_FG, ...
    'HorizontalAlignment', 'left');
lblStatus.Layout.Row = 1; lblStatus.Layout.Column = 1;

btnCopyResult = uibutton(statusGL, 'push', 'Text', 'Copy Result', ...
    'FontSize', 10, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) onCopyLastResult());
btnCopyResult.Layout.Row = 1; btnCopyResult.Layout.Column = 2;

btnCopyLatex = uibutton(statusGL, 'push', 'Text', 'Copy LaTeX', ...
    'FontSize', 10, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) onCopyLastLatex());
btnCopyLatex.Layout.Row = 1; btnCopyLatex.Layout.Column = 3;

btnSaveFav = uibutton(statusGL, 'push', 'Text', [char(9733) ' Save'], ...
    'FontSize', 10, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) onSaveToFavorites());
btnSaveFav.Layout.Row = 1; btnSaveFav.Layout.Column = 4;

% ════════════════════════════════════════════════════════════════════════
% APP STATE
% ════════════════════════════════════════════════════════════════════════
appData.history      = {};
appData.historyMax   = 100;
appData.api          = struct();  % tab builders store callable hooks here
appData.favorites    = {};        % cell array of favorite structs: .name, .tab, .lastResult, .lastLatex
appData.activeNavKey = 'unitConverter';  % mirrors current tree selection

% ════════════════════════════════════════════════════════════════════════
% BUILD PANELS (one per nav entry, all in same grid cell [1,1])
% ════════════════════════════════════════════════════════════════════════
tabs = struct();
for nki = 1:numel(navKeys)
    p = uipanel(contentGL, 'BorderType', 'none', 'Visible', 'off');
    p.Layout.Row = 1;
    p.Layout.Column = 1;
    tabs.(navKeys{nki}) = p;
end
tabs.unitConverter.Visible = 'on';  % show first panel

buildUnitConverterTab(tabs.unitConverter);
buildCrystalTab(tabs.crystal);
buildElectricalTab(tabs.electrical);
buildSemiconductorTab(tabs.semiconductor);
buildThinFilmTab(tabs.thinFilm);
buildXrayNeutronTab(tabs.xrayNeutron);
buildSuperconductorTab(tabs.superconductor);
buildMagneticTab(tabs.magnetic);
buildOpticsTab(tabs.optics);
buildVacuumTab(tabs.vacuum);
buildElectrochemistryTab(tabs.electrochemistry);
buildThermalTab(tabs.thermal);
buildDiffusionTab(tabs.diffusion);
buildReflectivityTab(tabs.reflectivity);
buildSubstratesTab(tabs.substrates);
buildPeriodicTableTab(tabs.periodicTable);
buildFavoritesTab(tabs.favorites);
buildHistoryTab(tabs.history);
appData.api.exportReport = @(fp) exportReportToFile(fp);

% Apply consistent dark theme to all widgets
applyDarkInputTheme(fig, INPUT_BG, INPUT_FG);
applyDarkPanelTheme(fig, FIG_BG, LABEL_FG);

% ════════════════════════════════════════════════════════════════════════
% API (headless testing)
% ════════════════════════════════════════════════════════════════════════
if nargout > 0
    api.fig            = fig;
    api.getHistory     = @getHistoryFcn;
    api.selectTab      = @(name) selectPanel(name);
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
    % X-ray/Neutron tab API
    api.calcNeutronSLD     = appData.api.calcNeutronSLD;
    api.calcXraySLD        = appData.api.calcXraySLD;
    api.calcQToTwoTheta    = appData.api.calcQToTwoTheta;
    % Superconductor tab API
    api.calcLondonDepth    = appData.api.calcLondonDepth;
    api.calcCriticalFields = appData.api.calcCriticalFields;
    % Optics/Vacuum/Electrochem API
    api.calcFresnel      = appData.api.calcFresnel;
    api.calcMeanFreePath = appData.api.calcMeanFreePath;
    api.calcNernst       = appData.api.calcNernst;
    % Reflectivity API
    api.getMultilayerStack = appData.api.getMultilayerStack;
    api.getDensityMode     = appData.api.getDensityMode;
    api.addLayer           = appData.api.addLayer;
    % Favorites API
    api.addFavorite    = appData.api.addFavorite;
    api.getFavorites   = appData.api.getFavorites;
    % History table API
    api.copyHistoryRowAsMatlabCode = appData.api.copyHistoryRowAsMatlabCode;
    api.getHistoryMatlabCall       = appData.api.getHistoryMatlabCall;
    % History export
    api.exportReport   = appData.api.exportReport;
    varargout{1}       = api;
end

% ════════════════════════════════════════════════════════════════════════
% HISTORY HELPER
% ════════════════════════════════════════════════════════════════════════

    function addHistory(description, latexStr, matlabCall)
        if nargin < 3, matlabCall = ''; end
        entry = {char(datetime('now','Format','HH:mm:ss')), appData.activeNavKey, description, latexStr, matlabCall};
        appData.history{end+1} = entry;
        if numel(appData.history) > appData.historyMax
            appData.history(1) = [];
        end
        appData.lastResult    = description;
        appData.lastLatex     = latexStr;
        appData.lastMatlabCall = matlabCall;
        appData.lastTab       = appData.activeNavKey;
        setStatus(description);
        % Enable copy/save buttons
        btnCopyResult.Enable = 'on';
        if ~isempty(latexStr)
            btnCopyLatex.Enable = 'on';
        end
        btnSaveFav.Enable = 'on';
        % Refresh history table if it exists
        if isfield(appData.api, 'refreshHistoryTable')
            appData.api.refreshHistoryTable();
        end
    end

    function h = getHistoryFcn()
        h = appData.history;
    end

    function setStatus(msg)
        if isvalid(lblStatus)
            lblStatus.Text = msg;
        end
    end

    function onCopyLastResult()
        if isfield(appData, 'lastResult') && ~isempty(appData.lastResult)
            % Strip HTML tags for clipboard
            txt = regexprep(appData.lastResult, '<[^>]+>', '');
            clipboard('copy', txt);
            setStatus('Result copied to clipboard');
        end
    end

    function onCopyLastLatex()
        if isfield(appData, 'lastLatex') && ~isempty(appData.lastLatex)
            clipboard('copy', appData.lastLatex);
            setStatus('LaTeX copied to clipboard');
        end
    end

    function onSaveToFavorites()
        if ~isfield(appData, 'lastResult'), return; end
        name = appData.lastResult;
        % Strip HTML for display name
        name = regexprep(name, '<[^>]+>', '');
        if numel(name) > 60, name = [name(1:57) '...']; end
        tabName = '';
        if isfield(appData, 'lastTab'), tabName = appData.lastTab; end
        result = appData.lastResult;
        latex  = '';
        if isfield(appData, 'lastLatex'), latex = appData.lastLatex; end
        % Use the Favorites tab API if available
        if isfield(appData.api, 'addFavoriteInternal')
            appData.api.addFavoriteInternal(name, tabName, result, latex);
        else
            % Fallback: store directly
            fav.name = name; fav.tab = tabName;
            fav.lastResult = result; fav.lastLatex = latex;
            appData.favorites{end+1} = fav;
        end
        setStatus(['Saved to favorites: ' name]);
    end

% ════════════════════════════════════════════════════════════════════════
% NAVIGATION: Switch visible panel
% ════════════════════════════════════════════════════════════════════════

    function onNavChanged(~, evt)
        % Only respond to leaf nodes (those with a NodeData key string)
        if isempty(evt.SelectedNodes), return; end
        node = evt.SelectedNodes(1);
        if isempty(node.NodeData), return; end   % category header clicked
        selectPanel(node.NodeData);
    end

    function selectPanel(key)
        if ~isfield(tabs, key), return; end
        fnames = fieldnames(tabs);
        for ni = 1:numel(fnames)
            tabs.(fnames{ni}).Visible = 'off';
        end
        tabs.(key).Visible = 'on';
        appData.activeNavKey = key;
        % Sync tree selection
        if navNodeMap.isKey(key)
            navTree.SelectedNodes = navNodeMap(key);
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ENTER KEY: trigger primary Calculate button on active panel
% ════════════════════════════════════════════════════════════════════════
primaryBtnMap = containers.Map('KeyType','char','ValueType','any');

    function registerPrimaryBtn(key, btn)
        primaryBtnMap(key) = btn;
    end

fig.WindowKeyPressFcn = @onGlobalKeyPress;
    function onGlobalKeyPress(~, evt)
        if strcmp(evt.Key, 'return')
            activeKey = appData.activeNavKey;
            if primaryBtnMap.isKey(activeKey)
                btn = primaryBtnMap(activeKey);
                if isvalid(btn) && strcmp(btn.Enable, 'on')
                    btn.ButtonPushedFcn(btn, []);
                end
            end
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
        efValue = uieditfield(gl, 'numeric', 'Value', 1, ...
            'BackgroundColor', INPUT_BG, 'FontColor', INPUT_FG, ...
            'Tooltip','Numeric value to convert — in the units of the From field');
        efValue.Layout.Row = 1; efValue.Layout.Column = 2;
        uilabel(gl, 'Text', 'From:', 'HorizontalAlignment', 'right');
        efFrom = uieditfield(gl, 'text', 'Value', 'Oe', ...
            'BackgroundColor', INPUT_BG, 'FontColor', INPUT_FG, ...
            'Tooltip','Source unit symbol — e.g. Oe, emu, eV, Ang, Pa, K, GPa, deg');
        efFrom.Layout.Row = 1; efFrom.Layout.Column = 4;

        % Row 2: Result + To
        uilabel(gl, 'Text', 'Result:', 'HorizontalAlignment', 'right');
        efResult = uieditfield(gl, 'text', 'Editable', 'off', 'Value', '', ...
            'BackgroundColor', INPUT_BG, 'FontColor', INPUT_FG);
        efResult.Layout.Row = 2; efResult.Layout.Column = 2;
        uilabel(gl, 'Text', 'To:', 'HorizontalAlignment', 'right');
        efTo = uieditfield(gl, 'text', 'Value', 'T', ...
            'BackgroundColor', INPUT_BG, 'FontColor', INPUT_FG, ...
            'Tooltip','Target unit symbol — e.g. T, A*m^2, nm, Torr, C, rad');
        efTo.Layout.Row = 2; efTo.Layout.Column = 4;

        % Row 3: Buttons
        btnConvert = uibutton(gl, 'push', 'Text', 'Convert', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'ButtonPushedFcn', @(~,~) doUnitConvert());
        btnConvert.Layout.Row = 3; btnConvert.Layout.Column = 1;

        btnSwap = uibutton(gl, 'push', 'Text', 'Swap', ...
            'BackgroundColor', BTN_TOOL, 'FontColor', BTN_TOOL_FG, ...
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
                'BackgroundColor', BTN_TOOL, 'FontColor', BTN_TOOL_FG, 'FontSize', 10, ...
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
                mcall = sprintf('[result, info] = calc.unitConvert(%s, ''%s'', ''%s'');', ...
                    num2str(val, '%g'), from, to);
                addHistory(info.description, info.latex, mcall);
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
        registerPrimaryBtn('unitConverter', btnConvert);
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
        gD.RowHeight   = {24, 24, 24, 24};
        gD.ColumnWidth = {50,'1x',30,'1x',30,'1x',30,'1x',80};
        gD.Padding     = [6 4 6 4];
        gD.RowSpacing  = 4;

        % Row 1: Crystal system, (hkl) preset, substrate
        uilabel(gD,'Text','System:','HorizontalAlignment','right','FontSize',9);
        crystalSystems = {'Cubic','Tetragonal','Orthorhombic','Hexagonal', ...
                          'Trigonal','Monoclinic','Triclinic'};
        ddDSystem = uidropdown(gD, 'Items', crystalSystems, 'Value', 'Cubic', ...
            'ValueChangedFcn', @(~,~) onCrystalSystemChanged(), 'FontSize', 9, ...
            'Tooltip', 'Crystal system — constrains lattice parameters (a=b=c, angles, etc.)');
        ddDSystem.Layout.Row=1; ddDSystem.Layout.Column=2;
        uilabel(gD,'Text','(hkl):','HorizontalAlignment','right','FontSize',9);
        hklPresets = {'Custom','(001)','(100)','(010)','(110)','(111)', ...
                      '(200)','(211)','(220)','(311)','(222)','(002)'};
        ddDHkl = uidropdown(gD, 'Items', hklPresets, 'Value', '(001)', ...
            'ValueChangedFcn', @(~,~) onHklPresetChanged(), 'FontSize', 9, ...
            'Tooltip', 'Miller index (hkl) preset — pick a common plane or Custom to enter h,k,l manually');
        ddDHkl.Layout.Row=1; ddDHkl.Layout.Column=[4 6];
        subNames = calc.substrates.listSubstrates();
        ddDSub = uidropdown(gD, 'Items', ['(none)', subNames], 'Value', '(none)', ...
            'ValueChangedFcn', @(~,~) fillDSpacingFromSubstrate(), 'FontSize', 9, ...
            'Tooltip', 'Substrate preset — auto-fills lattice parameters from the built-in substrate database');
        ddDSub.Layout.Row=1; ddDSub.Layout.Column=[7 9];

        % Row 2: a, b, c, h, k, l
        uilabel(gD,'Text',['a(' char(197) '):'],'HorizontalAlignment','right','FontSize',9);
        efDa = uieditfield(gD,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter a (Å) — typical 2–15 for inorganic crystals');
        efDa.Layout.Row=2; efDa.Layout.Column=2;
        uilabel(gD,'Text','h:','HorizontalAlignment','right');
        efDh = uieditfield(gD,'numeric','Value',0, ...
            'Tooltip','Miller index h — integer');
        efDh.Layout.Row=2; efDh.Layout.Column=4;
        uilabel(gD,'Text','k:','HorizontalAlignment','right');
        efDk = uieditfield(gD,'numeric','Value',0, ...
            'Tooltip','Miller index k — integer');
        efDk.Layout.Row=2; efDk.Layout.Column=6;
        uilabel(gD,'Text','l:','HorizontalAlignment','right');
        efDl = uieditfield(gD,'numeric','Value',1, ...
            'Tooltip','Miller index l — integer');
        efDl.Layout.Row=2; efDl.Layout.Column=8;
        btnDCalc = uibutton(gD,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDSpacing());
        btnDCalc.Layout.Row=2; btnDCalc.Layout.Column=9;

        % Row 3: b, c, alpha, beta
        uilabel(gD,'Text',['b(' char(197) '):'],'HorizontalAlignment','right','FontSize',9);
        efDb = uieditfield(gD,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter b (Å) — disabled for Cubic/Tetragonal/Hexagonal');
        efDb.Layout.Row=3; efDb.Layout.Column=2;
        uilabel(gD,'Text',['c(' char(197) '):'],'HorizontalAlignment','right','FontSize',9);
        efDc = uieditfield(gD,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter c (Å) — disabled for Cubic');
        efDc.Layout.Row=3; efDc.Layout.Column=4;
        uilabel(gD,'Text',[char(945) ':'],'HorizontalAlignment','right');
        efDal = uieditfield(gD,'numeric','Value',90, ...
            'Tooltip','Lattice angle α (deg) between b and c — 90 for orthogonal systems');
        efDal.Layout.Row=3; efDal.Layout.Column=6;
        uilabel(gD,'Text',[char(946) ':'],'HorizontalAlignment','right');
        efDbe = uieditfield(gD,'numeric','Value',90, ...
            'Tooltip','Lattice angle β (deg) between a and c — 90 for orthogonal systems');
        efDbe.Layout.Row=3; efDbe.Layout.Column=8;

        % Row 4: gamma, result
        uilabel(gD,'Text',[char(947) ':'],'HorizontalAlignment','right');
        efDga = uieditfield(gD,'numeric','Value',90, ...
            'Tooltip','Lattice angle γ (deg) between a and b — 90 for orthogonal, 120 for hexagonal');
        efDga.Layout.Row=4; efDga.Layout.Column=2;
        lblDResult = uilabel(gD,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblDResult.Layout.Row=4; lblDResult.Layout.Column=[3 9];

        % Apply default constraints for Cubic
        onCrystalSystemChanged();

        function onCrystalSystemChanged()
        %ONCRYSTALSYSTEMCHANGED  Constrain lattice parameters for selected system.
            sys = ddDSystem.Value;
            % Reset enables
            efDb.Enable = 'on'; efDc.Enable = 'on';
            efDal.Enable = 'on'; efDbe.Enable = 'on'; efDga.Enable = 'on';
            switch sys
                case 'Cubic'
                    efDb.Value = efDa.Value; efDc.Value = efDa.Value;
                    efDal.Value = 90; efDbe.Value = 90; efDga.Value = 90;
                    efDb.Enable = 'off'; efDc.Enable = 'off';
                    efDal.Enable = 'off'; efDbe.Enable = 'off'; efDga.Enable = 'off';
                case 'Tetragonal'
                    efDb.Value = efDa.Value;
                    efDal.Value = 90; efDbe.Value = 90; efDga.Value = 90;
                    efDb.Enable = 'off';
                    efDal.Enable = 'off'; efDbe.Enable = 'off'; efDga.Enable = 'off';
                case 'Orthorhombic'
                    efDal.Value = 90; efDbe.Value = 90; efDga.Value = 90;
                    efDal.Enable = 'off'; efDbe.Enable = 'off'; efDga.Enable = 'off';
                case 'Hexagonal'
                    efDb.Value = efDa.Value;
                    efDal.Value = 90; efDbe.Value = 90; efDga.Value = 120;
                    efDb.Enable = 'off';
                    efDal.Enable = 'off'; efDbe.Enable = 'off'; efDga.Enable = 'off';
                case 'Trigonal'
                    efDb.Value = efDa.Value; efDc.Value = efDa.Value;
                    efDbe.Value = efDal.Value; efDga.Value = efDal.Value;
                    efDb.Enable = 'off'; efDc.Enable = 'off';
                    efDbe.Enable = 'off'; efDga.Enable = 'off';
                case 'Monoclinic'
                    efDal.Value = 90; efDga.Value = 90;
                    efDal.Enable = 'off'; efDga.Enable = 'off';
                case 'Triclinic'
                    % All parameters free
            end
        end

        function onHklPresetChanged()
        %ONHKLPRESETCHANGED  Fill h, k, l from the selected preset.
            sel = ddDHkl.Value;
            if strcmp(sel, 'Custom'), return; end
            % Parse (hkl) string: "(110)" → h=1, k=1, l=0
            digits = sel(sel >= '0' & sel <= '9');
            if numel(digits) >= 3
                efDh.Value = str2double(digits(1));
                efDk.Value = str2double(digits(2));
                efDl.Value = str2double(digits(3));
            end
        end

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
                % Auto-detect crystal system from loaded parameters
                sys = inferCrystalSystem(s.a, s.b, s.c, s.alpha, s.beta, s.gamma);
                ddDSystem.Value = sys;
                onCrystalSystemChanged();
            catch
            end
        end

        function doDSpacing()
            try
                r = calc.crystal.dSpacing(efDa.Value, efDh.Value, efDk.Value, efDl.Value, ...
                    b=efDb.Value, c=efDc.Value, ...
                    alpha=efDal.Value, beta=efDbe.Value, gamma=efDga.Value);
                desc = sprintf('d<sub>%d%d%d</sub> = %.5g %s  [%s]', ...
                    efDh.Value, efDk.Value, efDl.Value, r.d, char(197), r.system);
                lblDResult.Text = desc;
                mcall = sprintf('result = calc.crystal.dSpacing(%g, %g, %g, %g, ''b'', %g, ''c'', %g, ''alpha'', %g, ''beta'', %g, ''gamma'', %g);', ...
                    efDa.Value, efDh.Value, efDk.Value, efDl.Value, ...
                    efDb.Value, efDc.Value, efDal.Value, efDbe.Value, efDga.Value);
                addHistory(desc, r.latex, mcall);
            catch ME
                lblDResult.Text = ['Error: ' ME.message];
                setStatus(['d-spacing error: ' ME.message]);
            end
        end

        % ── Card 2: 2θ ↔ d ────────────────────────────────────────────
        p2T = uipanel(gl, 'Title', ['2' char(952) ' ' char(8596) ' d'], 'FontWeight', 'bold');
        p2T.Layout.Row = 2; p2T.Layout.Column = 1;

        g2T = uigridlayout(p2T);
        g2T.RowHeight   = {24, 24};
        g2T.ColumnWidth = {70,'1x',70,'1x',90,90};
        g2T.Padding     = [6 4 6 4];
        g2T.RowSpacing  = 4;

        uilabel(g2T,'Text','Value:','HorizontalAlignment','right');
        ef2TVal = uieditfield(g2T,'numeric','Value',20, ...
            'Tooltip','Value to convert — 2θ in degrees or d in Å depending on direction');
        ef2TVal.Layout.Row=1; ef2TVal.Layout.Column=2;
        uilabel(g2T,'Text',[char(955) ' (' char(197) '):'],'HorizontalAlignment','right');
        ef2TLam = uieditfield(g2T,'numeric','Value',1.5406, ...
            'Tooltip','X-ray wavelength λ (Å) — Cu Kα₁ = 1.5406, Mo Kα = 0.7107');
        ef2TLam.Layout.Row=1; ef2TLam.Layout.Column=4;
        btn2TtoD = uibutton(g2T,'push','Text',['2' char(952) ' ' char(8594) ' d'], ...
            'BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG, ...
            'ButtonPushedFcn',@(~,~) do2ThetaToD());
        btn2TtoD.Layout.Row=1; btn2TtoD.Layout.Column=5;
        btnDTo2T = uibutton(g2T,'push','Text',['d ' char(8594) ' 2' char(952)], ...
            'BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG, ...
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
        efMMFilm = uieditfield(gMM,'numeric','Value',3.876, ...
            'Tooltip','Film lattice parameter (Å) — in-plane value that mismatches the substrate');
        efMMFilm.Layout.Row=1; efMMFilm.Layout.Column=2;
        uilabel(gMM,'Text','a Sub (Å):','HorizontalAlignment','right');
        efMMSub = uieditfield(gMM,'numeric','Value',3.905, ...
            'Tooltip','Substrate lattice parameter (Å) — reference for mismatch f=(a_f−a_s)/a_s');
        efMMSub.Layout.Row=1; efMMSub.Layout.Column=4;

        % Substrate fill for aSub
        ddMMSub = uidropdown(gMM,'Items',['(none)',subNames],'Value','(none)', ...
            'ValueChangedFcn',@(~,~) fillMMSubstrate(), ...
            'Tooltip','Substrate preset — auto-fills a_sub from the built-in database');
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
            catch
            end
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
        efVCa = uieditfield(gVC,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter a (Å)');
        efVCa.Layout.Row=1; efVCa.Layout.Column=2;
        uilabel(gVC,'Text','b (Å):','HorizontalAlignment','right');
        efVCb = uieditfield(gVC,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter b (Å)');
        efVCb.Layout.Row=1; efVCb.Layout.Column=4;
        uilabel(gVC,'Text','c (Å):','HorizontalAlignment','right');
        efVCc = uieditfield(gVC,'numeric','Value',3.905, ...
            'Tooltip','Lattice parameter c (Å)');
        efVCc.Layout.Row=1; efVCc.Layout.Column=6;

        uilabel(gVC,'Text','Z:','HorizontalAlignment','right');
        efVCZ = uieditfield(gVC,'numeric','Value',1, ...
            'Tooltip','Formula units per unit cell — e.g. Z=4 for NaCl, Z=2 for BCC');
        efVCZ.Layout.Row=2; efVCZ.Layout.Column=2;
        uilabel(gVC,'Text','M (g/mol):','HorizontalAlignment','right');
        efVCM = uieditfield(gVC,'numeric','Value',183.84, ...
            'Tooltip','Molar mass of the formula unit (g/mol)');
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
            'Value', 'P', ...
            'Tooltip','Bravais centering — P primitive, F face-centered, I body-centered, R rhombohedral');
        ddPSCent.Layout.Row = 1; ddPSCent.Layout.Column = 2;

        uilabel(gPS, 'Text', 'Max hkl:', 'HorizontalAlignment', 'right');
        efPSMax = uieditfield(gPS, 'numeric', 'Value', 5, ...
            'Limits', [1 10], 'RoundFractionalValues', 'on', ...
            'Tooltip','Maximum |h|, |k|, |l| to enumerate — integer 1–10');
        efPSMax.Layout.Row = 1; efPSMax.Layout.Column = 4;

        uilabel(gPS, 'Text', [char(955) ' (' char(197) '):'], ...
            'HorizontalAlignment', 'right');
        efPSLam = uieditfield(gPS, 'numeric', 'Value', 1.5406, ...
            'Tooltip','X-ray wavelength λ (Å) — used to compute 2θ via Bragg''s law');
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
        registerPrimaryBtn('crystal', btnDCalc);
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
        gl = uigridlayout(tab);
        gl.RowHeight   = {'3x', '2x', '2x', '2x', '2x'};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 6 6 6];
        gl.RowSpacing  = 8;

        % ── Card 1: Resistivity / Sheet Resistance ─────────────────────
        pRS = uipanel(gl,'Title','Resistivity / Sheet Resistance','FontWeight','bold');
        pRS.Layout.Row = 1; pRS.Layout.Column = 1;

        gRS = uigridlayout(pRS);
        gRS.RowHeight   = {24, 24, 24};
        gRS.ColumnWidth = {70,'1x',70,'1x',90,90};
        gRS.Padding     = [6 4 6 4];
        gRS.RowSpacing  = 4;

        uilabel(gRS,'Text',['Rs (' char(937) '/sq):'],'HorizontalAlignment','right');
        efRsVal = uieditfield(gRS,'numeric','Value',100, ...
            'Tooltip','Sheet resistance Rs (Ω/sq) — typical 1–10⁴ for thin metal/TCO films');
        efRsVal.Layout.Row=1; efRsVal.Layout.Column=2;
        uilabel(gRS,'Text','t (nm):','HorizontalAlignment','right');
        efRsTh = uieditfield(gRS,'numeric','Value',10, ...
            'Tooltip','Film thickness t (nm) — used in ρ = Rs·t');
        efRsTh.Layout.Row=1; efRsTh.Layout.Column=4;

        lblRsResult = uilabel(gRS,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblRsResult.Layout.Row=2; lblRsResult.Layout.Column=[1 4];

        btnRsToRho = uibutton(gRS,'push','Text',['Rs ' char(8594) ' ' char(961)], ...
            'BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG, ...
            'ButtonPushedFcn',@(~,~) doRsToRho());
        btnRsToRho.Layout.Row=2; btnRsToRho.Layout.Column=5;

        uilabel(gRS,'Text',[char(961) ' (' char(937) char(183) 'cm):'],'HorizontalAlignment','right');
        efRhoVal = uieditfield(gRS,'numeric','Value',1e-4, ...
            'Tooltip','Bulk resistivity ρ (Ω·cm) — metals ~10⁻⁶, semiconductors 10⁻³–10⁶');
        efRhoVal.Layout.Row=3; efRhoVal.Layout.Column=2;

        lblRhoResult = uilabel(gRS,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblRhoResult.Layout.Row=3; lblRhoResult.Layout.Column=[3 4];

        btnRhoToRs = uibutton(gRS,'push','Text',[char(961) ' ' char(8594) ' Rs'], ...
            'BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG, ...
            'ButtonPushedFcn',@(~,~) doRhoToRs());
        btnRhoToRs.Layout.Row=3; btnRhoToRs.Layout.Column=5;

        function doRsToRho()
            try
                % resistivity(Rs [Ohm/sq], t [cm])
                r = calc.electrical.resistivity(efRsVal.Value, efRsTh.Value*1e-7);
                desc = sprintf('%s = %.4g %s%scm  (R<sub>s</sub> = %.4g %s/sq, t = %.4g nm)', ...
                    char(961), r.rho, char(937), char(183), efRsVal.Value, char(937), efRsTh.Value);
                lblRsResult.Text = desc;
                mcall = sprintf('result = calc.electrical.resistivity(%g, %g);  %% Rs (Ohm/sq), t (cm)', ...
                    efRsVal.Value, efRsTh.Value*1e-7);
                addHistory(desc, r.latex, mcall);
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

        uilabel(gCond,'Text',[char(961) ' (' char(937) char(183) 'cm):'],'HorizontalAlignment','right');
        efCondRho = uieditfield(gCond,'numeric','Value',1e-4, ...
            'Tooltip','Resistivity ρ (Ω·cm) — conductivity σ = 1/ρ in S/cm');
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

        uilabel(gMob,'Text',[char(961) ' (' char(937) char(183) 'cm):'],'HorizontalAlignment','right');
        efMobRho = uieditfield(gMob,'numeric','Value',1e-2, ...
            'Tooltip','Resistivity ρ (Ω·cm) — used with n in μ = 1/(nqρ)');
        efMobRho.Layout.Row=1; efMobRho.Layout.Column=2;
        uilabel(gMob,'Text','n (cm\^-3):','HorizontalAlignment','right');
        efMobN = uieditfield(gMob,'numeric','Value',1e17, ...
            'Tooltip','Carrier concentration n (cm⁻³) — typical 10¹⁵–10²⁰ for doped semiconductors');
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
        efJDI = uieditfield(gJD,'numeric','Value',1e-3, ...
            'Tooltip','Current I (A) — e.g. 1 mA = 1e-3');
        efJDI.Layout.Row=1; efJDI.Layout.Column=2;
        uilabel(gJD,'Text',['Area (cm' char(178) '):'],'HorizontalAlignment','right');
        efJDA = uieditfield(gJD,'numeric','Value',1, ...
            'Tooltip','Cross-sectional area (cm²) — J = I/A in A/cm²');
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
        % ── Card 5: Hall Effect ──────────────────────────────────────────
        pHall = uipanel(gl,'Title','Hall Effect','FontWeight','bold');
        pHall.Layout.Row = 5; pHall.Layout.Column = 1;
        gHall = uigridlayout(pHall);
        gHall.RowHeight = {24,24,24}; gHall.ColumnWidth = {80,'1x',80,'1x',90};
        gHall.Padding = [6 4 6 4]; gHall.RowSpacing = 4;

        uilabel(gHall,'Text','V<sub>H</sub> (V):','HorizontalAlignment','right','Interpreter','html');
        efHallVH = uieditfield(gHall,'numeric','Value',1e-3, ...
            'Tooltip','Hall voltage V_H (V) — transverse voltage from V_H = R_H·I·B/t');
        efHallVH.Layout.Row=1; efHallVH.Layout.Column=2;
        uilabel(gHall,'Text','I (A):','HorizontalAlignment','right');
        efHallI = uieditfield(gHall,'numeric','Value',1e-3, ...
            'Tooltip','Longitudinal current I (A) through the Hall bar');
        efHallI.Layout.Row=1; efHallI.Layout.Column=4;
        btnHallCalc = uibutton(gHall,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doHallEffect());
        btnHallCalc.Layout.Row=1; btnHallCalc.Layout.Column=5;

        uilabel(gHall,'Text','B (T):','HorizontalAlignment','right');
        efHallB = uieditfield(gHall,'numeric','Value',1, ...
            'Tooltip','Magnetic field B (T) — applied perpendicular to current and voltage');
        efHallB.Layout.Row=2; efHallB.Layout.Column=2;
        uilabel(gHall,'Text','t (nm):','HorizontalAlignment','right');
        efHallT = uieditfield(gHall,'numeric','Value',100, ...
            'Tooltip','Sample thickness t (nm) along the field direction');
        efHallT.Layout.Row=2; efHallT.Layout.Column=4;

        lblHallResult = uilabel(gHall,'Text','','FontSize',11,'Interpreter','html');
        lblHallResult.Layout.Row=3; lblHallResult.Layout.Column=[1 5];

        function doHallEffect()
            try
                VH = efHallVH.Value;
                I  = efHallI.Value;
                B  = efHallB.Value;
                t  = efHallT.Value * 1e-7;   % nm to cm
                q  = 1.602176634e-19;
                RH = VH * t / (I * B);        % cm³/C
                n  = 1 / (RH * q);            % cm⁻³
                if RH > 0
                    carrier = 'p-type (holes)';
                else
                    carrier = 'n-type (electrons)';
                end
                desc = sprintf('R<sub>H</sub> = %.3g cm%s/C, n = %.3g cm%s &mdash; %s', ...
                    RH, char(179), abs(n), [char(8315) char(179)], carrier);
                lblHallResult.Text = desc;
                latex = sprintf('R_H = %.3g~\\text{cm}^3/\\text{C},\\ n = %.3g~\\text{cm}^{-3}', RH, abs(n));
                addHistory(desc, latex);
            catch ME
                lblHallResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        registerPrimaryBtn('electrical', btnCondCalc);
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 4: SEMICONDUCTOR
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildSemiconductorTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight   = {'3x', '2x', '3x', '2x'};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 6 6 6];
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
            'ValueChangedFcn',@(~,~) fillNiFromMaterial(), ...
            'Tooltip','Material preset — auto-fills Eg, m_e*, m_h* from the +calc.semiconductor database');
        ddNiMat.Layout.Row=1; ddNiMat.Layout.Column=2;
        uilabel(gNi,'Text','T (K):','HorizontalAlignment','right');
        efNiT = uieditfield(gNi,'numeric','Value',300, ...
            'Tooltip','Temperature (K) — always Kelvin, never Celsius');
        efNiT.Layout.Row=1; efNiT.Layout.Column=4;

        uilabel(gNi,'Text','Eg (eV):','HorizontalAlignment','right');
        efNiEg = uieditfield(gNi,'numeric','Value',1.12, ...
            'Tooltip','Band gap E_g (eV) — 1.12 Si, 0.66 Ge, 1.42 GaAs, 3.4 GaN');
        efNiEg.Layout.Row=2; efNiEg.Layout.Column=2;
        uilabel(gNi,'Text','me*:','HorizontalAlignment','right');
        efNiMe = uieditfield(gNi,'numeric','Value',1.08, ...
            'Tooltip','Electron DOS effective mass m_e*/m_0 (dimensionless) — Si 1.08, GaAs 0.067');
        efNiMe.Layout.Row=2; efNiMe.Layout.Column=4;
        uilabel(gNi,'Text','mh*:','HorizontalAlignment','right');
        efNiMh = uieditfield(gNi,'numeric','Value',0.81, ...
            'Tooltip','Hole DOS effective mass m_h*/m_0 (dimensionless) — Si 0.81, GaAs 0.47');
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
            catch
            end
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
                mcall = sprintf('result = calc.semiconductor.intrinsicCarrierConc(''Eg'', %g, ''meStar'', %g, ''mhStar'', %g, ''T'', %g);', ...
                    efNiEg.Value, efNiMe.Value, efNiMh.Value, efNiT.Value);
                addHistory(desc, r.latex, mcall);
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

        uilabel(gDop,'Text',['Nd (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efDopNd = uieditfield(gDop,'numeric','Value',1e16, ...
            'Tooltip','Donor concentration N_d (cm⁻³) — typical 10¹⁴–10²⁰');
        efDopNd.Layout.Row=1; efDopNd.Layout.Column=2;
        uilabel(gDop,'Text',['Na (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efDopNa = uieditfield(gDop,'numeric','Value',0, ...
            'Tooltip','Acceptor concentration N_a (cm⁻³) — 0 for purely n-type');
        efDopNa.Layout.Row=1; efDopNa.Layout.Column=4;
        uilabel(gDop,'Text',['ni (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efDopNi = uieditfield(gDop,'numeric','Value',1.5e10, ...
            'Tooltip','Intrinsic carrier concentration n_i (cm⁻³) — Si 1.5e10 at 300 K');
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
        ddDepMat = uidropdown(gDep,'Items',['(manual)',matNames],'Value','Si', ...
            'Tooltip','Material preset — auto-fills ε_r for the semiconductor');
        ddDepMat.Layout.Row=1; ddDepMat.Layout.Column=2;
        uilabel(gDep,'Text',[char(949) char(8339) ':'],'HorizontalAlignment','right');
        efDepEps = uieditfield(gDep,'numeric','Value',11.7, ...
            'Tooltip','Relative permittivity ε_r (dimensionless) — Si 11.7, GaAs 12.9');
        efDepEps.Layout.Row=1; efDepEps.Layout.Column=4;

        uilabel(gDep,'Text','Vbi (V):','HorizontalAlignment','right');
        efDepVbi = uieditfield(gDep,'numeric','Value',0.7, ...
            'Tooltip','Built-in potential V_bi (V) — typically 0.6–1.0 for Si junctions');
        efDepVbi.Layout.Row=2; efDepVbi.Layout.Column=2;
        uilabel(gDep,'Text',['Na (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efDepNa = uieditfield(gDep,'numeric','Value',1e16, ...
            'Tooltip','Acceptor doping on p-side N_a (cm⁻³)');
        efDepNa.Layout.Row=2; efDepNa.Layout.Column=4;
        uilabel(gDep,'Text',['Nd (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efDepNd = uieditfield(gDep,'numeric','Value',1e17, ...
            'Tooltip','Donor doping on n-side N_d (cm⁻³)');
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
            catch
            end
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

        uilabel(gTrans,'Text',[char(956) ' (cm' char(178) '/V' char(183) 's):'],'HorizontalAlignment','right');
        efTransMu = uieditfield(gTrans,'numeric','Value',1400, ...
            'Tooltip','Carrier mobility μ (cm²/V·s) — Si electrons 1400, holes 450 at 300 K');
        efTransMu.Layout.Row=1; efTransMu.Layout.Column=2;
        uilabel(gTrans,'Text','\tau (s):','HorizontalAlignment','right');
        efTransTau = uieditfield(gTrans,'numeric','Value',1e-6, ...
            'Tooltip','Minority-carrier lifetime τ (s) — typical 1 ns–1 ms');
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
        registerPrimaryBtn('semiconductor', btnNiCalc);
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
        gl.RowHeight   = {72, 72, 90, 110, 72, 72};
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
        efDRThick = uieditfield(gDR,'numeric','Value',1000, ...
            'Tooltip','Deposited film thickness (Å) — target film amount');
        efDRThick.Layout.Row=1; efDRThick.Layout.Column=2;
        uilabel(gDR,'Text','Time (s):','HorizontalAlignment','right');
        efDRTime = uieditfield(gDR,'numeric','Value',60, ...
            'Tooltip','Deposition time (s) — rate = thickness/time');
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

        uilabel(gKT,'Text',[char(916) 'Q (' char(197) char(8315) char(185) '):'],'HorizontalAlignment','right');
        efKTdQ = uieditfield(gKT,'numeric','Value',0.1, ...
            'Tooltip','Fringe spacing ΔQ (Å⁻¹) from adjacent Kiessig fringes — t = 2π/ΔQ');
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
        efSSEs = uieditfield(gSS,'numeric','Value',130, ...
            'Tooltip','Substrate Young''s modulus E_s (GPa) — Si 130, sapphire 345');
        efSSEs.Layout.Row=1; efSSEs.Layout.Column=2;
        uilabel(gSS,'Text',[char(957) 's:'],'HorizontalAlignment','right');
        efSSNus = uieditfield(gSS,'numeric','Value',0.28, ...
            'Tooltip','Substrate Poisson ratio ν_s (dimensionless) — typically 0.2–0.35');
        efSSNus.Layout.Row=1; efSSNus.Layout.Column=4;
        uilabel(gSS,'Text',['ts (' char(956) 'm):'],'HorizontalAlignment','right');
        efSSts = uieditfield(gSS,'numeric','Value',500, ...
            'Tooltip','Substrate thickness t_s (μm) — typical Si wafer 300–700');
        efSSts.Layout.Row=1; efSSts.Layout.Column=6;

        uilabel(gSS,'Text','tf (nm):','HorizontalAlignment','right');
        efSStf = uieditfield(gSS,'numeric','Value',100, ...
            'Tooltip','Film thickness t_f (nm) — Stoney assumes t_f ≪ t_s');
        efSStf.Layout.Row=2; efSStf.Layout.Column=2;
        uilabel(gSS,'Text','R (m):','HorizontalAlignment','right');
        efSSR = uieditfield(gSS,'numeric','Value',10, ...
            'Tooltip','Wafer radius of curvature R (m) — positive = tensile, negative = compressive');
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

        uilabel(gTM,'Text',[char(945) ' film (1/K):'],'HorizontalAlignment','right');
        efTMAlF = uieditfield(gTM,'numeric','Value',17e-6, ...
            'Tooltip','Film CTE α_f (1/K) — metals ~10–20e-6, oxides ~5–15e-6');
        efTMAlF.Layout.Row=1; efTMAlF.Layout.Column=2;
        uilabel(gTM,'Text',[char(945) ' sub (1/K):'],'HorizontalAlignment','right');
        efTMAlS = uieditfield(gTM,'numeric','Value',3e-6, ...
            'Tooltip','Substrate CTE α_s (1/K) — Si 2.6e-6, Al₂O₃ 7.5e-6');
        efTMAlS.Layout.Row=1; efTMAlS.Layout.Column=4;

        ddTMSub = uidropdown(gTM,'Items',['(manual)',subNames],'Value','(manual)', ...
            'ValueChangedFcn',@(~,~) fillTMSubstrate(), ...
            'Tooltip','Substrate preset — auto-fills α_s from the substrate database');
        ddTMSub.Layout.Row=1; ddTMSub.Layout.Column=6;

        uilabel(gTM,'Text',[char(916) 'T (K):'],'HorizontalAlignment','right');
        efTMdT = uieditfield(gTM,'numeric','Value',-500, ...
            'Tooltip','Temperature change ΔT (K) — negative = cooling from deposition');
        efTMdT.Layout.Row=2; efTMdT.Layout.Column=2;
        uilabel(gTM,'Text','E (GPa):','HorizontalAlignment','right');
        efTME = uieditfield(gTM,'numeric','Value',200, ...
            'Tooltip','Film Young''s modulus E_f (GPa) — metals 50–400');
        efTME.Layout.Row=2; efTME.Layout.Column=4;
        uilabel(gTM,'Text',[char(957) ':'],'HorizontalAlignment','right');
        efTMNu = uieditfield(gTM,'numeric','Value',0.28, ...
            'Tooltip','Film Poisson ratio ν_f (dimensionless) — typically 0.2–0.35');
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
            catch
            end
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
        efIDCurr = uieditfield(gID,'numeric','Value',1e-6, ...
            'Tooltip','Ion beam current I (A) — assumes singly-charged ions');
        efIDCurr.Layout.Row=1; efIDCurr.Layout.Column=2;
        uilabel(gID,'Text','Time (s):','HorizontalAlignment','right');
        efIDTime = uieditfield(gID,'numeric','Value',60, ...
            'Tooltip','Exposure time t (s)');
        efIDTime.Layout.Row=1; efIDTime.Layout.Column=4;
        uilabel(gID,'Text',['Area (cm' char(178) '):'],'HorizontalAlignment','right');
        efIDArea = uieditfield(gID,'numeric','Value',1, ...
            'Tooltip','Implant area (cm²) — dose = I·t/(q·A) in ions/cm²');
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
        % ── Card 6: Scherrer Grain Size ─────────────────────────────────────
        pScherrer = uipanel(gl,'Title','Scherrer Grain Size','FontWeight','bold');
        pScherrer.Layout.Row = 6; pScherrer.Layout.Column = 1;
        gSch = uigridlayout(pScherrer);
        gSch.RowHeight = {24,24}; gSch.ColumnWidth = {60,'1x',40,'1x',40,'1x',90};
        gSch.Padding = [6 4 6 4]; gSch.RowSpacing = 4;

        uilabel(gSch,'Text','FWHM:','HorizontalAlignment','right');
        efSchFWHM = uieditfield(gSch,'numeric','Value',0.5, ...
            'Tooltip','Peak FWHM β (deg, 2θ) — instrument-corrected integral breadth');
        efSchFWHM.Layout.Row=1; efSchFWHM.Layout.Column=2;
        uilabel(gSch,'Text',[char(955) ':'],'HorizontalAlignment','right');
        efSchLam = uieditfield(gSch,'numeric','Value',1.5406, ...
            'Tooltip','X-ray wavelength λ (Å) — Cu Kα₁ = 1.5406');
        efSchLam.Layout.Row=1; efSchLam.Layout.Column=4;
        uilabel(gSch,'Text',['2' char(952) ':'],'HorizontalAlignment','right');
        efSch2T = uieditfield(gSch,'numeric','Value',33, ...
            'Tooltip','Bragg peak position 2θ (deg)');
        efSch2T.Layout.Row=1; efSch2T.Layout.Column=6;
        btnSchCalc = uibutton(gSch,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doScherrer());
        btnSchCalc.Layout.Row=1; btnSchCalc.Layout.Column=7;

        lblSchResult = uilabel(gSch,'Text','','FontSize',11,'Interpreter','html');
        lblSchResult.Layout.Row=2; lblSchResult.Layout.Column=[1 7];

        function doScherrer()
            try
                B = efSchFWHM.Value * pi / 180;
                lam = efSchLam.Value;
                theta = efSch2T.Value / 2 * pi / 180;
                K = 0.9;
                D = K * lam / (B * cos(theta));
                desc = sprintf('D = %.1f %s (%.1f nm)', D, char(197), D/10);
                lblSchResult.Text = desc;
                latex = sprintf('D = \\frac{K\\lambda}{\\beta\\cos\\theta} = %.1f~\\text{\\AA}', D);
                addHistory(desc, latex);
            catch ME
                lblSchResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        registerPrimaryBtn('thinFilm', btnDRCalc);
    end

% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════
%  TAB 6: PERIODIC TABLE
% ════════════════════════════════════════════════════════════════════════
% ════════════════════════════════════════════════════════════════════════

    function buildPeriodicTableTab(tab)
        % Main layout: toolbar + display options + table + detail panel
        gl = uigridlayout(tab);
        gl.RowHeight   = {28, 24, '1x', 140};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 4 6 4];
        gl.RowSpacing  = 4;

        % ── Row 1: Toolbar ────────────────────────────────────────────
        tbGL = uigridlayout(gl);
        tbGL.Layout.Row = 1; tbGL.Layout.Column = 1;
        tbGL.RowHeight   = {22};
        tbGL.ColumnWidth = {60, '1x', 60, '1x'};
        tbGL.Padding     = [0 0 0 0];
        tbGL.RowSpacing  = 0;

        uilabel(tbGL,'Text','Color by:','HorizontalAlignment','right');
        ddProp = uidropdown(tbGL, 'Items', { ...
            'Category','Atomic Mass','Density','Electronegativity', ...
            'Atomic Radius (pm)','Ionization Energy (eV)', ...
            'Melting Point (K)','Electron Affinity (eV)', ...
            'Thermal Cond. (W/mK)','b_coh (fm)' ...
            }, 'Value', 'Category', ...
            'ValueChangedFcn', @(~,~) onPropChanged(), ...
            'Tooltip','Property used to color-code the periodic table — viridis gradient for numeric, group colors for Category');
        ddProp.Layout.Row = 1; ddProp.Layout.Column = 2;
        uilabel(tbGL,'Text','Search:','HorizontalAlignment','right');
        efSearch = uieditfield(tbGL,'text','Value','', ...
            'BackgroundColor', INPUT_BG, 'FontColor', INPUT_FG, ...
            'ValueChangedFcn',@(~,~) doSearch(), ...
            'Tooltip','Filter elements by name, symbol, or category — matches highlighted in bold');
        efSearch.Layout.Row = 1; efSearch.Layout.Column = 4;

        % ── Row 2: Display Options ────────────────────────────────────
        dispGL = uigridlayout(gl);
        dispGL.Layout.Row = 2; dispGL.Layout.Column = 1;
        dispGL.RowHeight   = {20};
        dispGL.ColumnWidth = {55, 40, 55, 100, '1x'};
        dispGL.Padding     = [0 0 0 0];
        dispGL.RowSpacing  = 0;

        uilabel(dispGL,'Text','Show:','HorizontalAlignment','right','FontSize',10);
        cbShowZ = uicheckbox(dispGL,'Text','Z','Value',true,'FontSize',10, ...
            'ValueChangedFcn',@(~,~) refreshPTText());
        cbShowZ.Layout.Row=1; cbShowZ.Layout.Column=2;
        cbShowMass = uicheckbox(dispGL,'Text','Mass','Value',false,'FontSize',10, ...
            'ValueChangedFcn',@(~,~) refreshPTText());
        cbShowMass.Layout.Row=1; cbShowMass.Layout.Column=3;
        cbShowPropVal = uicheckbox(dispGL,'Text','Property Value','Value',false,'FontSize',10, ...
            'ValueChangedFcn',@(~,~) refreshPTText());
        cbShowPropVal.Layout.Row=1; cbShowPropVal.Layout.Column=4;

        % ── Row 3: Periodic Table Grid ────────────────────────────────
        tablePanel = uipanel(gl,'BorderType','none');
        tablePanel.Layout.Row = 3; tablePanel.Layout.Column = 1;

        ptGL = uigridlayout(tablePanel);
        ptGL.RowHeight   = repmat({'1x'}, 1, 10);
        ptGL.ColumnWidth = repmat({'1x'}, 1, 18);
        ptGL.Padding     = [2 2 2 2];
        ptGL.RowSpacing  = 1;
        ptGL.ColumnSpacing = 1;

        % ── Row 4: Detail Panel ───────────────────────────────────────
        taDetail = uitextarea(gl,'Editable','off','FontSize',12, ...
            'FontName','Courier New');
        taDetail.Layout.Row = 4; taDetail.Layout.Column = 1;
        taDetail.Value = {'Click an element to see all properties.'};

        % ── Category Color Map ────────────────────────────────────────
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

        % ── Dropdown name → elementData field mapping ─────────────────
        propFieldMap = containers.Map( ...
            {'Atomic Mass','Density','Electronegativity', ...
             'Atomic Radius (pm)','Ionization Energy (eV)', ...
             'Melting Point (K)','Electron Affinity (eV)', ...
             'Thermal Cond. (W/mK)','b_coh (fm)'}, ...
            {'mass','density','electronegativity', ...
             'atomicRadius','ionizationEnergy', ...
             'meltingPoint','electronAffinity', ...
             'thermalConductivity','bCoherent'});

        % ── Periodic Table Layout ─────────────────────────────────────
        ptLayout = buildPTLayout();

        % Load element data once — shared by all callbacks
        allEls = calc.elementData();
        % Build symbol → index map for fast lookup
        elIdxMap = containers.Map('KeyType','char','ValueType','double');
        for ii = 1:numel(allEls)
            elIdxMap(allEls(ii).symbol) = ii;
        end

        % Build buttons
        ptBtns = containers.Map('KeyType','char','ValueType','any');

        for ei = 1:numel(ptLayout)
            entry = ptLayout(ei);
            sym   = entry.symbol;
            if ~elIdxMap.isKey(sym), continue; end
            el = allEls(elIdxMap(sym));

            btnText = sprintf('%d\n%s', el.Z, el.symbol);
            btn = uibutton(ptGL, 'push', 'Text', btnText, ...
                'FontSize', 10, 'FontWeight', 'normal', ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'ButtonPushedFcn', @(~,~) doSelectElement(sym));
            btn.Layout.Row    = entry.row;
            btn.Layout.Column = entry.col;
            ptBtns(sym) = btn;
        end

        % Apply initial colors and text
        refreshPTColors();

        % ── CALLBACKS ─────────────────────────────────────────────────

        function onPropChanged()
            refreshPTColors();
            refreshPTText();
        end

        function doSelectElement(sym)
            try
                el = allEls(elIdxMap(sym));
                lines = formatElementDetail(el);
                taDetail.Value = lines;
                setStatus(sprintf('%s (%s) — Z=%d', el.name, el.symbol, el.Z));
            catch ME
                taDetail.Value = {['Error: ' ME.message]};
            end
        end

        function refreshPTColors()
            propName = ddProp.Value;
            syms = ptBtns.keys;

            if strcmp(propName, 'Category')
                % Use category color map
                for ki = 1:numel(syms)
                    s = syms{ki};
                    b = ptBtns(s);
                    if ~isvalid(b), continue; end
                    el = allEls(elIdxMap(s));
                    cat = lower(el.category);
                    if catColors.isKey(cat)
                        bgCol = catColors(cat);
                    else
                        bgCol = [0.85 0.85 0.85];
                    end
                    b.BackgroundColor = bgCol;
                    b.FontColor = autoFontColor(bgCol);
                end
            else
                % Property-based gradient coloring
                fieldName = propFieldMap(propName);
                vals = nan(1, numel(syms));
                for ki = 1:numel(syms)
                    el = allEls(elIdxMap(syms{ki}));
                    vals(ki) = el.(fieldName);
                end
                vMin = min(vals(~isnan(vals)));
                vMax = max(vals(~isnan(vals)));
                cmap = viridisMap(256);

                for ki = 1:numel(syms)
                    b = ptBtns(syms{ki});
                    if ~isvalid(b), continue; end
                    v = vals(ki);
                    if isnan(v) || vMin == vMax
                        bgCol = [0.3 0.3 0.3];
                    else
                        t = (v - vMin) / (vMax - vMin);
                        idx = max(1, min(256, round(t * 255) + 1));
                        bgCol = cmap(idx, :);
                    end
                    b.BackgroundColor = bgCol;
                    b.FontColor = autoFontColor(bgCol);
                end
            end
        end

        function refreshPTText()
            showZ    = cbShowZ.Value;
            showMass = cbShowMass.Value;
            showProp = cbShowPropVal.Value;
            propName = ddProp.Value;

            % Resolve property field (if showing property value)
            hasPropField = ~strcmp(propName, 'Category') && propFieldMap.isKey(propName);

            syms = ptBtns.keys;
            for ki = 1:numel(syms)
                s = syms{ki};
                b = ptBtns(s);
                if ~isvalid(b), continue; end
                el = allEls(elIdxMap(s));

                parts = {};
                if showZ
                    parts{end+1} = sprintf('%d', el.Z); %#ok<AGROW>
                end
                parts{end+1} = el.symbol; %#ok<AGROW>
                if showMass
                    parts{end+1} = sprintf('%.1f', el.mass); %#ok<AGROW>
                end
                if showProp && hasPropField
                    pv = el.(propFieldMap(propName));
                    if isnan(pv)
                        parts{end+1} = '-'; %#ok<AGROW>
                    else
                        parts{end+1} = sprintf('%.3g', pv); %#ok<AGROW>
                    end
                end
                b.Text = strjoin(parts, newline);
                % Reduce font size when showing extra info to prevent overflow
                nLines = numel(parts);
                if nLines >= 4
                    b.FontSize = 7;
                elseif nLines >= 3
                    b.FontSize = 8;
                else
                    b.FontSize = 10;
                end
            end
        end

        function doSearch()
            query = lower(strtrim(efSearch.Value));
            k = ptBtns.keys;
            if isempty(query)
                % Restore all buttons to normal
                for ki = 1:numel(k)
                    b = ptBtns(k{ki});
                    if isvalid(b)
                        b.FontWeight = 'normal';
                        b.FontSize   = 10;
                        b.Enable     = 'on';
                    end
                end
                refreshPTColoring();
                return
            end
            for ki = 1:numel(k)
                sym = k{ki};
                b = ptBtns(sym);
                if ~isvalid(b), continue; end
                el = allEls(elIdxMap(sym));
                match = contains(lower(el.name), query) || ...
                        contains(lower(el.symbol), query) || ...
                        contains(lower(el.category), query);
                if match
                    b.FontWeight = 'bold';
                    b.FontSize   = 11;
                    b.Enable     = 'on';
                else
                    b.FontWeight = 'normal';
                    b.FontSize   = 10;
                    b.Enable     = 'off';
                end
            end
        end

        function lines = formatElementDetail(el)
            lines = { ...
                sprintf('%-4s  %s  (Z = %d)', el.symbol, el.name, el.Z), ...
                sprintf('Category: %s  |  Period %d, Group %d', el.category, el.period, el.group), ...
                sprintf('Config: %s', el.electronConfig), ...
                '', ...
                sprintf('Mass:       %-12s  Density:       %s g/cm%s', ...
                    sprintf('%.4f u', el.mass), numOrNA(el.density), char(179)), ...
                sprintf('Radius:     %-12s  Electroneg.:   %s (Pauling)', ...
                    [numOrNA(el.atomicRadius) ' pm'], numOrNA(el.electronegativity)), ...
                sprintf('Ioniz. E:   %-12s  E. Affinity:   %s eV', ...
                    [numOrNA(el.ionizationEnergy) ' eV'], numOrNA(el.electronAffinity)), ...
                sprintf('Melting:    %-12s  Boiling:       %s K', ...
                    [numOrNA(el.meltingPoint) ' K'], numOrNA(el.boilingPoint)), ...
                sprintf('Therm.Cond: %-12s  b_coh:         %s fm', ...
                    [numOrNA(el.thermalConductivity) ' W/(m' char(183) 'K)'], numOrNA(el.bCoherent)), ...
            };
            % X-ray edges (if available)
            if isstruct(el.xrayEdges) && ~isempty(fieldnames(el.xrayEdges))
                xe = el.xrayEdges;
                fn = fieldnames(xe);
                parts = {};
                for fi = 1:numel(fn)
                    v = xe.(fn{fi});
                    if ~isnan(v)
                        parts{end+1} = sprintf('%s=%.0f', fn{fi}, v); %#ok<AGROW>
                    end
                end
                if ~isempty(parts)
                    lines{end+1} = sprintf('X-ray edges (eV): %s', strjoin(parts, '  '));
                end
            end
        end

        function s = numOrNA(v)
            if isnan(v)
                s = 'N/A';
            else
                s = sprintf('%.4g', v);
            end
        end

        function fc = autoFontColor(bgCol)
            lum = 0.299*bgCol(1) + 0.587*bgCol(2) + 0.114*bgCol(3);
            if lum < 0.5
                fc = [1 1 1];
            else
                fc = [0 0 0];
            end
        end

        % API hooks
        appData.api.selectElement = @(sym) doSelectElement(sym);
        appData.api.getElementDetail = @() taDetail.Value;
    end

% ════════════════════════════════════════════════════════════════════════
% X-RAY / NEUTRON TAB
% ════════════════════════════════════════════════════════════════════════

    function buildXrayNeutronTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight   = {'3x', '2x', '3x', '2x'};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 6 6 6];
        gl.RowSpacing  = 8;

        % ── Card 1: Neutron SLD ──────────────────────────────────────
        pNSLD = uipanel(gl,'Title','Neutron Scattering Length Density','FontWeight','bold');
        pNSLD.Layout.Row = 1; pNSLD.Layout.Column = 1;

        gNSLD = uigridlayout(pNSLD);
        gNSLD.RowHeight   = {24, 24, 24};
        gNSLD.ColumnWidth = {90,'1x',90,'1x',90};
        gNSLD.Padding     = [6 4 6 4];
        gNSLD.RowSpacing  = 4;

        uilabel(gNSLD,'Text','Formula:','HorizontalAlignment','right');
        efNSLDFormula = uieditfield(gNSLD,'text','Value','SrTiO3', ...
            'Tooltip','Chemical formula — case-sensitive element symbols, e.g. SrTiO3, Fe2O3, Al2O3');
        efNSLDFormula.Layout.Row=1; efNSLDFormula.Layout.Column=2;
        uilabel(gNSLD,'Text','Density (g/cm³):','HorizontalAlignment','right');
        efNSLDDensity = uieditfield(gNSLD,'numeric','Value',5.12, ...
            'Tooltip','Mass density ρ (g/cm³) — SrTiO₃ 5.12, Si 2.33, Fe₂O₃ 5.24');
        efNSLDDensity.Layout.Row=1; efNSLDDensity.Layout.Column=4;
        btnNSLDCalc = uibutton(gNSLD,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doNeutronSLD());
        btnNSLDCalc.Layout.Row=1; btnNSLDCalc.Layout.Column=5;

        lblNSLDResult = uilabel(gNSLD,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblNSLDResult.Layout.Row=2; lblNSLDResult.Layout.Column=[1 5];

        lblNSLDDetail = uilabel(gNSLD,'Text','','FontSize',10, ...
            'FontColor',[0.5 0.5 0.5],'Interpreter','html');
        lblNSLDDetail.Layout.Row=3; lblNSLDDetail.Layout.Column=[1 5];

        function doNeutronSLD()
            try
                r = calc.xrayNeutron.neutronSLD(efNSLDFormula.Value, efNSLDDensity.Value);
                desc = sprintf('SLD<sub>n</sub> = %.4g %s 10<sup>-6</sup> %s<sup>-2</sup>', ...
                    r.SLDe6, char(215), char(197));
                lblNSLDResult.Text = desc;
                lblNSLDDetail.Text = sprintf('M = %.2f g/mol, formula: %s', r.M, r.formula);
                addHistory(desc, r.latex);
            catch ME
                lblNSLDResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 2: X-ray SLD (shares formula/density from Card 1) ───
        pXSLD = uipanel(gl,'Title','X-ray Scattering Length Density','FontWeight','bold');
        pXSLD.Layout.Row = 2; pXSLD.Layout.Column = 1;

        gXSLD = uigridlayout(pXSLD);
        gXSLD.RowHeight   = {24, 24};
        gXSLD.ColumnWidth = {'1x', 150};
        gXSLD.Padding     = [6 4 6 4];
        gXSLD.RowSpacing  = 4;

        lblXSLDResult = uilabel(gXSLD,'Text','Uses formula & density from above', ...
            'FontSize',11,'FontColor',[0.5 0.5 0.5],'FontAngle','italic', ...
            'Interpreter','html');
        lblXSLDResult.Layout.Row=1; lblXSLDResult.Layout.Column=1;
        btnXSLDCalc = uibutton(gXSLD,'push','Text','Calculate X-ray SLD', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doXraySLD());
        btnXSLDCalc.Layout.Row=1; btnXSLDCalc.Layout.Column=2;

        lblXSLDDetail = uilabel(gXSLD,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblXSLDDetail.Layout.Row=2; lblXSLDDetail.Layout.Column=[1 2];

        function doXraySLD()
            try
                r = calc.xrayNeutron.xraySLD(efNSLDFormula.Value, efNSLDDensity.Value);
                desc = sprintf('SLD<sub>x</sub> = %.4g %s 10<sup>-6</sup> %s<sup>-2</sup>', ...
                    r.SLDe6, char(215), char(197));
                lblXSLDResult.Text = desc;
                lblXSLDResult.FontAngle = 'normal';
                lblXSLDResult.FontColor = [0.9 0.9 0.9];
                lblXSLDDetail.Text = sprintf('%s<sub>e</sub> = %.4g e/%s%s', ...
                    char(961), r.electronDensity, char(197), char(179));
                addHistory(desc, r.latex);
            catch ME
                lblXSLDResult.Text = ['Error: ' ME.message];
                lblXSLDResult.FontAngle = 'normal';
                setStatus(ME.message);
            end
        end

        % ── Card 3: Q ↔ 2θ Converter ────────────────────────────────
        pQ2T = uipanel(gl,'Title',['Q / 2' char(952) ' Converter'],'FontWeight','bold');
        pQ2T.Layout.Row = 3; pQ2T.Layout.Column = 1;

        gQ2T = uigridlayout(pQ2T);
        gQ2T.RowHeight   = {24, 22, 24};
        gQ2T.ColumnWidth = {60,'1x',50,'1x',80,80};
        gQ2T.Padding     = [6 4 6 4];
        gQ2T.RowSpacing  = 4;

        uilabel(gQ2T,'Text','Value:','HorizontalAlignment','right');
        efQ2TVal = uieditfield(gQ2T,'numeric','Value',1.0, ...
            'Tooltip','Value to convert — Q in Å⁻¹ or 2θ in degrees depending on direction');
        efQ2TVal.Layout.Row=1; efQ2TVal.Layout.Column=2;
        uilabel(gQ2T,'Text',[char(955) ' (' char(197) '):'],'HorizontalAlignment','right');
        efQ2TLam = uieditfield(gQ2T,'numeric','Value',1.5406, ...
            'Tooltip','Radiation wavelength λ (Å) — Cu Kα 1.5406, Mo Kα 0.7107, neutrons 1–5');
        efQ2TLam.Layout.Row=1; efQ2TLam.Layout.Column=4;

        % Row 2: wavelength presets
        lamPresets = {'Cu K\alpha', 1.5406; 'Mo K\alpha', 0.7107; 'Co K\alpha', 1.7902; 'Ag K\alpha', 0.5594};
        for lpi = 1:size(lamPresets, 1)
            lamVal = lamPresets{lpi, 2};
            btn = uibutton(gQ2T, 'push', 'Text', lamPresets{lpi, 1}, ...
                'FontSize', 9, 'BackgroundColor', [0.35 0.35 0.35], 'FontColor', [0.95 0.95 0.95], ...
                'ButtonPushedFcn', @(~,~) set(efQ2TLam, 'Value', lamVal));
            btn.Layout.Row = 2; btn.Layout.Column = lpi;
        end

        btnQTo2T = uibutton(gQ2T,'push','Text',['Q' char(8594) '2' char(952)], ...
            'BackgroundColor',BTN_TOOL, 'FontColor',BTN_TOOL_FG, ...
            'ButtonPushedFcn',@(~,~) doQTo2Theta());
        btnQTo2T.Layout.Row=1; btnQTo2T.Layout.Column=5;
        btnTwoTToQ = uibutton(gQ2T,'push','Text',['2' char(952) char(8594) 'Q'], ...
            'BackgroundColor',BTN_TOOL, 'FontColor',BTN_TOOL_FG, ...
            'ButtonPushedFcn',@(~,~) do2ThetaToQ());
        btnTwoTToQ.Layout.Row=1; btnTwoTToQ.Layout.Column=6;

        lblQ2TResult = uilabel(gQ2T,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblQ2TResult.Layout.Row=3; lblQ2TResult.Layout.Column=[1 6];

        function doQTo2Theta()
            try
                r = calc.xrayNeutron.qToTwoTheta(efQ2TVal.Value, Lambda=efQ2TLam.Value);
                desc = sprintf('Q = %.4g %s<sup>-1</sup>  %s  2%s = %.4f%s', ...
                    r.Q, char(197), char(8594), char(952), r.twoTheta, char(176));
                lblQ2TResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblQ2TResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        function do2ThetaToQ()
            try
                r = calc.xrayNeutron.twoThetaToQ(efQ2TVal.Value, Lambda=efQ2TLam.Value);
                desc = sprintf('2%s = %.4f%s  %s  Q = %.4g %s<sup>-1</sup>', ...
                    char(952), r.twoTheta, char(176), char(8594), r.Q, char(197));
                lblQ2TResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblQ2TResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Molecular Weight ─────────────────────────────────
        pMW = uipanel(gl,'Title','Molecular Weight','FontWeight','bold');
        pMW.Layout.Row = 4; pMW.Layout.Column = 1;

        gMW = uigridlayout(pMW);
        gMW.RowHeight   = {24, 24};
        gMW.ColumnWidth = {70,'1x',90};
        gMW.Padding     = [6 4 6 4];
        gMW.RowSpacing  = 4;

        uilabel(gMW,'Text','Formula:','HorizontalAlignment','right');
        efMWFormula = uieditfield(gMW,'text','Value','Fe2O3', ...
            'Tooltip','Chemical formula — returns molar mass in g/mol');
        efMWFormula.Layout.Row=1; efMWFormula.Layout.Column=2;
        btnMWCalc = uibutton(gMW,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doMolWeight());
        btnMWCalc.Layout.Row=1; btnMWCalc.Layout.Column=3;

        lblMWResult = uilabel(gMW,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblMWResult.Layout.Row=2; lblMWResult.Layout.Column=[1 3];

        function doMolWeight()
            try
                r = calc.xrayNeutron.molecularWeight(efMWFormula.Value);
                desc = sprintf('M(%s) = %.4f g/mol', r.formula, r.M);
                lblMWResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblMWResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Register API ─────────────────────────────────────────────
        registerPrimaryBtn('xrayNeutron', btnNSLDCalc);
        appData.api.calcNeutronSLD = @(formula, density) apiNeutronSLD(formula, density);
        appData.api.calcXraySLD    = @(formula, density) apiXraySLD(formula, density);
        appData.api.calcQToTwoTheta = @(Q, lam) apiQTo2T(Q, lam);

        function result = apiNeutronSLD(formula, density)
            efNSLDFormula.Value = formula;
            efNSLDDensity.Value = density;
            doNeutronSLD();
            result = lblNSLDResult.Text;
        end

        function result = apiXraySLD(formula, density)
            efNSLDFormula.Value = formula;
            efNSLDDensity.Value = density;
            doXraySLD();
            result = lblXSLDResult.Text;
        end

        function result = apiQTo2T(Q, lam)
            efQ2TVal.Value = Q;
            efQ2TLam.Value = lam;
            doQTo2Theta();
            result = lblQ2TResult.Text;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% SUPERCONDUCTOR TAB
% ════════════════════════════════════════════════════════════════════════

    function buildSuperconductorTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight   = {'3x', '2x', '2x', '3x'};
        gl.ColumnWidth = {'1x'};
        gl.Padding     = [6 6 6 6];
        gl.RowSpacing  = 8;

        % Material presets
        scMats = {'Nb','NbN','YBCO','MgB2','Al','Pb','In','Sn'};

        % ── Card 1: London Penetration Depth ─────────────────────────
        pLondon = uipanel(gl,'Title','London Penetration Depth','FontWeight','bold');
        pLondon.Layout.Row = 1; pLondon.Layout.Column = 1;

        gLondon = uigridlayout(pLondon);
        gLondon.RowHeight   = {24, 24, 24, 24};
        gLondon.ColumnWidth = {130,'1x',110,'1x',90};
        gLondon.Padding     = [6 4 6 4];
        gLondon.RowSpacing  = 4;

        uilabel(gLondon,'Text','Material:','HorizontalAlignment','right');
        ddLondonMat = uidropdown(gLondon, ...
            'Items',['(custom)',scMats],'Value','Nb', ...
            'ValueChangedFcn',@(~,~) fillLondonFromPreset(), ...
            'Tooltip','Superconductor preset — auto-fills λ₀ and T_c');
        ddLondonMat.Layout.Row=1; ddLondonMat.Layout.Column=2;

        uilabel(gLondon,'Text','<html>&lambda;<sub>0</sub> depth (nm):</html>', ...
            'HorizontalAlignment','right','Interpreter','html');
        efLondonLam0 = uieditfield(gLondon,'numeric','Value',39, ...
            'Tooltip','Zero-temperature London depth λ₀ (nm) — Nb 39, Al 16, YBCO ~150');
        efLondonLam0.Layout.Row=1; efLondonLam0.Layout.Column=4;

        uilabel(gLondon,'Text','Crit. temp T<sub>c</sub> (K):', ...
            'HorizontalAlignment','right','Interpreter','html');
        efLondonTc = uieditfield(gLondon,'numeric','Value',9.25, ...
            'Tooltip','Superconducting critical temperature T_c (K) — Nb 9.25, Al 1.2, YBCO 93');
        efLondonTc.Layout.Row=2; efLondonTc.Layout.Column=2;
        uilabel(gLondon,'Text','Meas. temp (K):','HorizontalAlignment','right');
        efLondonT = uieditfield(gLondon,'numeric','Value',4.2, ...
            'Tooltip','Measurement temperature T (K) — must satisfy T < T_c');
        efLondonT.Layout.Row=2; efLondonT.Layout.Column=4;

        btnLondonCalc = uibutton(gLondon,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doLondonDepth());
        btnLondonCalc.Layout.Row=2; btnLondonCalc.Layout.Column=5;

        lblLondonResult = uilabel(gLondon,'Text','','FontSize',11, ...
            'Interpreter','html');
        lblLondonResult.Layout.Row=3; lblLondonResult.Layout.Column=[1 5];

        lblLondonDetail = uilabel(gLondon,'Text','','FontSize',10, ...
            'FontColor',[0.5 0.5 0.5],'Interpreter','html');
        lblLondonDetail.Layout.Row=4; lblLondonDetail.Layout.Column=[1 5];

        function fillLondonFromPreset()
            mat = ddLondonMat.Value;
            if strcmp(mat,'(custom)'), return; end
            try
                presets = calc.superconductor.materialPresets();
                p = presets.(mat);
                efLondonLam0.Value = p.lambda0;
                efLondonTc.Value   = p.Tc;
            catch
            end
        end

        function doLondonDepth()
            try
                r = calc.superconductor.londonDepth( ...
                    lambda0=efLondonLam0.Value, T=efLondonT.Value, Tc=efLondonTc.Value);
                desc = sprintf('%s(%.1f K) = %.2f nm', char(955), r.T, r.lambda);
                lblLondonResult.Text = desc;
                lblLondonDetail.Text = sprintf('%s<sub>0</sub> = %.1f nm, T<sub>c</sub> = %.2f K', ...
                    char(955), r.lambda0, r.Tc);
                addHistory(desc, r.latex);
            catch ME
                lblLondonResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 2: Coherence Length ─────────────────────────────────
        pXi = uipanel(gl,'Title','Coherence Length','FontWeight','bold');
        pXi.Layout.Row = 2; pXi.Layout.Column = 1;

        gXi = uigridlayout(pXi);
        gXi.RowHeight   = {24, 24, 24};
        gXi.ColumnWidth = {130,'1x',110,'1x',90};
        gXi.Padding     = [6 4 6 4];
        gXi.RowSpacing  = 4;

        uilabel(gXi,'Text','Material:','HorizontalAlignment','right');
        ddXiMat = uidropdown(gXi, ...
            'Items',['(custom)',scMats],'Value','Nb', ...
            'ValueChangedFcn',@(~,~) fillXiFromPreset(), ...
            'Tooltip','Superconductor preset — auto-fills ξ₀ and T_c');
        ddXiMat.Layout.Row=1; ddXiMat.Layout.Column=2;

        uilabel(gXi,'Text','<html>&xi;<sub>0</sub> length (nm):</html>', ...
            'HorizontalAlignment','right','Interpreter','html');
        efXi0 = uieditfield(gXi,'numeric','Value',38, ...
            'Tooltip','Zero-temperature coherence length ξ₀ (nm) — Nb 38, Al 1600, YBCO ~2');
        efXi0.Layout.Row=1; efXi0.Layout.Column=4;

        uilabel(gXi,'Text','Crit. temp T<sub>c</sub> (K):', ...
            'HorizontalAlignment','right','Interpreter','html');
        efXiTc = uieditfield(gXi,'numeric','Value',9.25, ...
            'Tooltip','Critical temperature T_c (K)');
        efXiTc.Layout.Row=2; efXiTc.Layout.Column=2;
        uilabel(gXi,'Text','Meas. temp (K):','HorizontalAlignment','right');
        efXiT = uieditfield(gXi,'numeric','Value',4.2, ...
            'Tooltip','Measurement temperature T (K) — must satisfy T < T_c');
        efXiT.Layout.Row=2; efXiT.Layout.Column=4;
        btnXiCalc = uibutton(gXi,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doCoherenceLength());
        btnXiCalc.Layout.Row=2; btnXiCalc.Layout.Column=5;

        lblXiResult = uilabel(gXi,'Text','','FontSize',11,'Interpreter','html');
        lblXiResult.Layout.Row=3; lblXiResult.Layout.Column=[1 5];

        function fillXiFromPreset()
            mat = ddXiMat.Value;
            if strcmp(mat,'(custom)'), return; end
            try
                presets = calc.superconductor.materialPresets();
                p = presets.(mat);
                efXi0.Value = p.xi0;
                efXiTc.Value = p.Tc;
            catch
            end
        end

        function doCoherenceLength()
            try
                r = calc.superconductor.coherenceLength( ...
                    xi0=efXi0.Value, T=efXiT.Value, Tc=efXiTc.Value);
                desc = sprintf('%s(%.1f K) = %.2f nm', char(958), r.T, r.xi);
                lblXiResult.Text = desc;
                addHistory(desc, r.latex);
            catch ME
                lblXiResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 3: GL Parameter ─────────────────────────────────────
        pGL = uipanel(gl,'Title','Ginzburg-Landau Parameter','FontWeight','bold');
        pGL.Layout.Row = 3; pGL.Layout.Column = 1;

        gGL = uigridlayout(pGL);
        gGL.RowHeight   = {24, 24, 24};
        gGL.ColumnWidth = {130,'1x',110,'1x',90};
        gGL.Padding     = [6 4 6 4];
        gGL.RowSpacing  = 4;

        uilabel(gGL,'Text','<html>Pen. depth &lambda; (nm):</html>', ...
            'HorizontalAlignment','right','Interpreter','html');
        efGLLam = uieditfield(gGL,'numeric','Value',39, ...
            'Tooltip','Penetration depth λ (nm) — at the measurement temperature');
        efGLLam.Layout.Row=1; efGLLam.Layout.Column=2;
        uilabel(gGL,'Text','<html>Coher. &xi; (nm):</html>', ...
            'HorizontalAlignment','right','Interpreter','html');
        efGLXi = uieditfield(gGL,'numeric','Value',38, ...
            'Tooltip','Coherence length ξ (nm) — κ = λ/ξ; >1/√2 is Type II');
        efGLXi.Layout.Row=1; efGLXi.Layout.Column=4;
        btnGLCalc = uibutton(gGL,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doGLParam());
        btnGLCalc.Layout.Row=1; btnGLCalc.Layout.Column=5;

        lblGLResult = uilabel(gGL,'Text','','FontSize',11,'Interpreter','html');
        lblGLResult.Layout.Row=2; lblGLResult.Layout.Column=[1 5];

        lblGLType = uilabel(gGL,'Text','','FontSize',10, ...
            'FontColor',[0.5 0.5 0.5],'Interpreter','html');
        lblGLType.Layout.Row=3; lblGLType.Layout.Column=[1 5];

        function doGLParam()
            try
                r = calc.superconductor.glParameter(lambda=efGLLam.Value, xi=efGLXi.Value);
                desc = sprintf('%s = %.3f', char(954), r.kappa);
                lblGLResult.Text = desc;
                lblGLType.Text = sprintf('Type %s (1/%s2 = %.3f)', ...
                    r.type, char(8730), 1/sqrt(2));
                addHistory(desc, r.latex);
            catch ME
                lblGLResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Card 4: Critical Fields ──────────────────────────────────
        pHc = uipanel(gl,'Title','Critical Fields','FontWeight','bold');
        pHc.Layout.Row = 4; pHc.Layout.Column = 1;

        gHc = uigridlayout(pHc);
        gHc.RowHeight   = {24, 24, 24, 24, 24};
        gHc.ColumnWidth = {130,'1x',110,'1x',90};
        gHc.Padding     = [6 4 6 4];
        gHc.RowSpacing  = 4;

        uilabel(gHc,'Text','Material:','HorizontalAlignment','right');
        ddHcMat = uidropdown(gHc, ...
            'Items',['(custom)',scMats],'Value','Nb', ...
            'ValueChangedFcn',@(~,~) fillHcFromPreset(), ...
            'Tooltip','Superconductor preset — auto-fills H_c0 and T_c');
        ddHcMat.Layout.Row=1; ddHcMat.Layout.Column=2;

        uilabel(gHc,'Text','Crit. field H<sub>c0</sub> (Oe):', ...
            'HorizontalAlignment','right','Interpreter','html');
        efHcHc0 = uieditfield(gHc,'numeric','Value',1980, ...
            'Tooltip','Zero-T thermodynamic critical field H_c0 (Oe) — Nb ~1980, Al ~100');
        efHcHc0.Layout.Row=1; efHcHc0.Layout.Column=4;

        uilabel(gHc,'Text','Crit. temp T<sub>c</sub> (K):', ...
            'HorizontalAlignment','right','Interpreter','html');
        efHcTc = uieditfield(gHc,'numeric','Value',9.25, ...
            'Tooltip','Critical temperature T_c (K)');
        efHcTc.Layout.Row=2; efHcTc.Layout.Column=2;
        uilabel(gHc,'Text','Meas. temp (K):','HorizontalAlignment','right');
        efHcT = uieditfield(gHc,'numeric','Value',4.2, ...
            'Tooltip','Measurement temperature T (K) — H_c(T) = H_c0·[1-(T/T_c)²]');
        efHcT.Layout.Row=2; efHcT.Layout.Column=4;
        btnHcCalc = uibutton(gHc,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doCriticalFields());
        btnHcCalc.Layout.Row=2; btnHcCalc.Layout.Column=5;

        lblHcResult = uilabel(gHc,'Text','','FontSize',11,'Interpreter','html');
        lblHcResult.Layout.Row=3; lblHcResult.Layout.Column=[1 5];

        lblHcResult2 = uilabel(gHc,'Text','','FontSize',11,'Interpreter','html');
        lblHcResult2.Layout.Row=4; lblHcResult2.Layout.Column=[1 5];

        lblHcType = uilabel(gHc,'Text','','FontSize',10, ...
            'FontColor',[0.5 0.5 0.5],'Interpreter','html');
        lblHcType.Layout.Row=5; lblHcType.Layout.Column=[1 5];

        function fillHcFromPreset()
            mat = ddHcMat.Value;
            if strcmp(mat,'(custom)'), return; end
            try
                presets = calc.superconductor.materialPresets();
                p = presets.(mat);
                efHcHc0.Value = p.Hc0;
                efHcTc.Value  = p.Tc;
            catch
            end
        end

        function doCriticalFields()
            try
                r = calc.superconductor.criticalFields( ...
                    Hc0=efHcHc0.Value, Tc=efHcTc.Value, T=efHcT.Value);
                desc = sprintf('H<sub>c</sub>(%.1f K) = %.1f Oe', r.T, r.Hc);
                lblHcResult.Text = desc;
                if isfield(r,'Hc1') && ~isnan(r.Hc1)
                    lblHcResult2.Text = sprintf( ...
                        'H<sub>c1</sub> = %.1f Oe, H<sub>c2</sub> = %.1f Oe', r.Hc1, r.Hc2);
                else
                    lblHcResult2.Text = '';
                end
                lblHcType.Text = sprintf('Type %s superconductor', r.type);
                addHistory(desc, r.latex);
            catch ME
                lblHcResult.Text = ['Error: ' ME.message];
                setStatus(ME.message);
            end
        end

        % ── Register API ─────────────────────────────────────────────
        registerPrimaryBtn('superconductor', btnLondonCalc);
        appData.api.calcLondonDepth = @(mat, T) apiLondon(mat, T);
        appData.api.calcCriticalFields = @(mat, T) apiCritFields(mat, T);

        function result = apiLondon(mat, T)
            ddLondonMat.Value = mat;
            fillLondonFromPreset();
            efLondonT.Value = T;
            doLondonDepth();
            result = lblLondonResult.Text;
        end

        function result = apiCritFields(mat, T)
            ddHcMat.Value = mat;
            fillHcFromPreset();
            efHcT.Value = T;
            doCriticalFields();
            result = lblHcResult.Text;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% MAGNETIC PROPERTIES TAB
% ════════════════════════════════════════════════════════════════════════

    function buildMagneticTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'3x', '2x', '2x', '2x', '2x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % ── Card 1: Moment Conversions ──────────────────────────────────
        pMom = uipanel(gl,'Title','Moment Conversions','FontWeight','bold');
        pMom.Layout.Row = 1;
        gMom = uigridlayout(pMom);
        gMom.RowHeight = {24,24,24,24}; gMom.ColumnWidth = {80,'1x',80,'1x',90};
        gMom.Padding = [6 4 6 4]; gMom.RowSpacing = 4;

        uilabel(gMom,'Text','Moment:','HorizontalAlignment','right');
        efMomVal = uieditfield(gMom,'numeric','Value',1e-3, ...
            'Tooltip','Magnetic moment value — unit selected in the dropdown to the right');
        efMomVal.Layout.Row=1; efMomVal.Layout.Column=2;
        uilabel(gMom,'Text','Unit:','HorizontalAlignment','right');
        ddMomUnit = uidropdown(gMom,'Items',{'emu','A*m^2','memu','uemu'}, ...
            'ItemsData',{1, 1e3, 1e-3, 1e-6},'Value',1, ...
            'Tooltip','Input unit — emu (CGS), A·m² (SI), memu, or μemu');
        ddMomUnit.Layout.Row=1; ddMomUnit.Layout.Column=4;
        btnMomCalc = uibutton(gMom,'push','Text','Convert', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doMomentConvert());
        btnMomCalc.Layout.Row=1; btnMomCalc.Layout.Column=5;

        % Row 2: optional parameters for per-atom
        uilabel(gMom,'Text','Volume (cm³):','HorizontalAlignment','right');
        efMomVol = uieditfield(gMom,'numeric','Value',0, ...
            'Tooltip','Sample volume (cm³) — optional, enables magnetization M = m/V output');
        efMomVol.Layout.Row=2; efMomVol.Layout.Column=2;
        uilabel(gMom,'Text','Atoms:','HorizontalAlignment','right');
        efMomAtoms = uieditfield(gMom,'numeric','Value',0, ...
            'Tooltip','Number of magnetic atoms — optional, enables μ_B/atom output');
        efMomAtoms.Layout.Row=2; efMomAtoms.Layout.Column=4;

        lblMomResult = uilabel(gMom,'Text','','FontSize',11,'Interpreter','html');
        lblMomResult.Layout.Row=3; lblMomResult.Layout.Column=[1 5];
        lblMomDetail = uilabel(gMom,'Text','','FontSize',10,'FontColor',[.5 .5 .5],'Interpreter','html');
        lblMomDetail.Layout.Row=4; lblMomDetail.Layout.Column=[1 5];

        function doMomentConvert()
            val = efMomVal.Value;
            scale = ddMomUnit.Value;  % factor to convert input unit to emu
            emu = val * scale;
            Am2 = emu * 1e-3;
            muB = 9.274010078e-21;  % emu
            desc = sprintf('%.4g emu = %.4g A%sm%s', emu, Am2, char(183), char(178));
            detail = '';
            vol = efMomVol.Value;
            nAtoms = efMomAtoms.Value;
            if vol > 0
                emucc = emu / vol;
                Am = emucc * 1e3;  % emu/cm³ to A/m
                desc = [desc sprintf(' | M = %.4g emu/cm%s = %.4g A/m', emucc, char(179), Am)];
            end
            if nAtoms > 0
                muB_per_atom = emu / (nAtoms * muB);
                detail = sprintf('%.3f %s<sub>B</sub>/atom', muB_per_atom, char(956));
            end
            lblMomResult.Text = desc;
            lblMomDetail.Text = detail;
            addHistory(desc, '');
        end

        % ── Card 2: Demagnetization Factors ─────────────────────────────
        pDemag = uipanel(gl,'Title','Demagnetization Factors','FontWeight','bold');
        pDemag.Layout.Row = 2;
        gDemag = uigridlayout(pDemag);
        gDemag.RowHeight = {24,24}; gDemag.ColumnWidth = {80,'1x',90};
        gDemag.Padding = [6 4 6 4]; gDemag.RowSpacing = 4;

        uilabel(gDemag,'Text','Shape:','HorizontalAlignment','right');
        ddDemagShape = uidropdown(gDemag, ...
            'Items',{'Sphere','Thin film (in-plane)','Thin film (out-of-plane)', ...
                     'Long cylinder (axial)','Long cylinder (transverse)'}, ...
            'Value','Sphere', ...
            'Tooltip','Sample geometry — returns demagnetization factor N along chosen axis');
        ddDemagShape.Layout.Row=1; ddDemagShape.Layout.Column=2;
        btnDemagCalc = uibutton(gDemag,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDemagFactor());
        btnDemagCalc.Layout.Row=1; btnDemagCalc.Layout.Column=3;

        lblDemagResult = uilabel(gDemag,'Text','','FontSize',11,'Interpreter','html');
        lblDemagResult.Layout.Row=2; lblDemagResult.Layout.Column=[1 3];

        function doDemagFactor()
            shape = ddDemagShape.Value;
            switch shape
                case 'Sphere',                          N = 1/3;
                case 'Thin film (in-plane)',             N = 0;
                case 'Thin film (out-of-plane)',         N = 1;
                case 'Long cylinder (axial)',            N = 0;
                case 'Long cylinder (transverse)',       N = 0.5;
                otherwise,                               N = 0;
            end
            Ncgs = 4*pi*N;
            desc = sprintf('N = %.4f (SI) = %.4f (CGS, 4%sN)', N, Ncgs, char(960));
            lblDemagResult.Text = desc;
            addHistory(sprintf('%s: %s', shape, desc), '');
        end

        % ── Card 3: Curie-Weiss Law ────────────────────────────────────
        pCW = uipanel(gl,'Title','Curie-Weiss Law','FontWeight','bold');
        pCW.Layout.Row = 3;
        gCW = uigridlayout(pCW);
        gCW.RowHeight = {24,24}; gCW.ColumnWidth = {80,'1x',80,'1x',90};
        gCW.Padding = [6 4 6 4]; gCW.RowSpacing = 4;

        uilabel(gCW,'Text','C (emu K/mol):','HorizontalAlignment','right');
        efCWC = uieditfield(gCW,'numeric','Value',4.375, ...
            'Tooltip','Curie constant C (emu·K/mol) — from slope of 1/χ vs T');
        efCWC.Layout.Row=1; efCWC.Layout.Column=2;
        uilabel(gCW,'Text',[char(952) ' (K):'],'HorizontalAlignment','right');
        efCWTheta = uieditfield(gCW,'numeric','Value',-50, ...
            'Tooltip','Curie-Weiss temperature θ (K) — positive = FM, negative = AFM');
        efCWTheta.Layout.Row=1; efCWTheta.Layout.Column=4;
        btnCWCalc = uibutton(gCW,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doCurieWeiss());
        btnCWCalc.Layout.Row=1; btnCWCalc.Layout.Column=5;

        lblCWResult = uilabel(gCW,'Text','','FontSize',11,'Interpreter','html');
        lblCWResult.Layout.Row=2; lblCWResult.Layout.Column=[1 5];

        function doCurieWeiss()
            C = efCWC.Value;
            theta = efCWTheta.Value;
            muB = 9.274e-21;
            kB = 1.381e-16;  % erg/K (CGS)
            NA = 6.022e23;
            % C = N*mu_eff^2/(3*kB) → mu_eff = sqrt(3*kB*C/N)
            mu_eff_cgs = sqrt(3 * kB * C / NA);  % in emu units
            mu_eff_muB = mu_eff_cgs / muB;
            % p_eff = g*sqrt(J(J+1)) ≈ mu_eff/muB
            if theta < 0
                magType = 'antiferromagnetic';
            elseif theta > 0
                magType = 'ferromagnetic';
            else
                magType = 'paramagnetic';
            end
            desc = sprintf('%s<sub>eff</sub> = %.3f %s<sub>B</sub> (%s, %s = %.1f K)', ...
                char(956), mu_eff_muB, char(956), magType, char(952), theta);
            lblCWResult.Text = desc;
            latex = sprintf('\\mu_{\\text{eff}} = %.3f~\\mu_B', mu_eff_muB);
            addHistory(desc, latex);
        end

        % ── Card 4: Langevin Function ───────────────────────────────────
        pLang = uipanel(gl,'Title','Langevin / Superparamagnetism','FontWeight','bold');
        pLang.Layout.Row = 4;
        gLang = uigridlayout(pLang);
        gLang.RowHeight = {24,24}; gLang.ColumnWidth = {80,'1x',80,'1x',90};
        gLang.Padding = [6 4 6 4]; gLang.RowSpacing = 4;

        uilabel(gLang,'Text',[char(956) ' (emu):'],'HorizontalAlignment','right');
        efLangMu = uieditfield(gLang,'numeric','Value',1e-16, ...
            'Tooltip','Single-particle magnetic moment μ (emu) — typical nanoparticle 10⁻¹⁶–10⁻¹⁴');
        efLangMu.Layout.Row=1; efLangMu.Layout.Column=2;
        uilabel(gLang,'Text','H (Oe):','HorizontalAlignment','right');
        efLangH = uieditfield(gLang,'numeric','Value',10000, ...
            'Tooltip','Applied field H (Oe) — CGS, 1 T = 10⁴ Oe');
        efLangH.Layout.Row=1; efLangH.Layout.Column=4;
        btnLangCalc = uibutton(gLang,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doLangevin());
        btnLangCalc.Layout.Row=1; btnLangCalc.Layout.Column=5;

        lblLangResult = uilabel(gLang,'Text','','FontSize',11,'Interpreter','html');
        lblLangResult.Layout.Row=2; lblLangResult.Layout.Column=[1 5];

        function doLangevin()
            mu = efLangMu.Value;  % emu
            H = efLangH.Value;    % Oe
            kB = 1.381e-16;       % erg/K (CGS)
            T = 300;              % assume room temperature
            x = mu * H / (kB * T);
            if abs(x) < 1e-10
                L = 0;
            else
                L = coth(x) - 1/x;
            end
            muB = 9.274e-21;
            nMuB = mu / muB;
            desc = sprintf('L(x) = %.6f at x = %.3f (%s = %.1f %s<sub>B</sub>, T = %d K)', ...
                L, x, char(956), nMuB, char(956), T);
            lblLangResult.Text = desc;
            addHistory(desc, '');
        end

        % ── Card 5: Domain Wall Width + Anisotropy ─────────────────────
        pDW = uipanel(gl,'Title','Domain Wall & Anisotropy','FontWeight','bold');
        pDW.Layout.Row = 5;
        gDW = uigridlayout(pDW);
        gDW.RowHeight = {24,24}; gDW.ColumnWidth = {80,'1x',80,'1x',90};
        gDW.Padding = [6 4 6 4]; gDW.RowSpacing = 4;

        uilabel(gDW,'Text','A (erg/cm):','HorizontalAlignment','right');
        efDWA = uieditfield(gDW,'numeric','Value',2e-6, ...
            'Tooltip','Exchange stiffness A (erg/cm, CGS) — Fe 2e-6, Co 3e-6, Ni 0.9e-6');
        efDWA.Layout.Row=1; efDWA.Layout.Column=2;
        uilabel(gDW,'Text',['K (erg/cm' char(179) '):'],'HorizontalAlignment','right');
        efDWK = uieditfield(gDW,'numeric','Value',4.8e6, ...
            'Tooltip','Anisotropy constant K (erg/cm³, CGS) — Co ~4.5e6, Fe ~0.5e6');
        efDWK.Layout.Row=1; efDWK.Layout.Column=4;
        btnDWCalc = uibutton(gDW,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDomainWall());
        btnDWCalc.Layout.Row=1; btnDWCalc.Layout.Column=5;

        lblDWResult = uilabel(gDW,'Text','','FontSize',11,'Interpreter','html');
        lblDWResult.Layout.Row=2; lblDWResult.Layout.Column=[1 5];

        function doDomainWall()
            A = efDWA.Value;  % exchange stiffness (erg/cm)
            K = efDWK.Value;  % anisotropy constant (erg/cm³)
            delta = pi * sqrt(A / K);       % wall width (cm)
            Ewall = 4 * sqrt(A * K);        % wall energy (erg/cm²)
            delta_nm = delta * 1e7;          % to nm
            Ewall_mJ = Ewall * 1e-3 * 1e4;  % erg/cm² to mJ/m²
            desc = sprintf('%s = %.1f nm, E<sub>wall</sub> = %.2f mJ/m%s', ...
                char(948), delta_nm, Ewall_mJ, char(178));
            lblDWResult.Text = desc;
            latex = sprintf('\\delta = \\pi\\sqrt{A/K} = %.1f~\\text{nm}', delta_nm);
            addHistory(desc, latex);
        end

        registerPrimaryBtn('magnetic', btnMomCalc);
    end

% ════════════════════════════════════════════════════════════════════════
% OPTICS TAB
% ════════════════════════════════════════════════════════════════════════

    function buildOpticsTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'3x', '2x', '2x', '2x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % Card 1: Fresnel Coefficients
        pFres = uipanel(gl,'Title','Fresnel Coefficients','FontWeight','bold');
        pFres.Layout.Row = 1; pFres.Layout.Column = 1;
        gFres = uigridlayout(pFres);
        gFres.RowHeight = {24,24,24}; gFres.ColumnWidth = {60,'1x',60,'1x',60,'1x',90};
        gFres.Padding = [6 4 6 4]; gFres.RowSpacing = 4;
        uilabel(gFres,'Text','n1:','HorizontalAlignment','right');
        efFN1 = uieditfield(gFres,'numeric','Value',1.0, ...
            'Tooltip','Incident medium refractive index n₁ — air ≈ 1.00'); efFN1.Layout.Row=1; efFN1.Layout.Column=2;
        uilabel(gFres,'Text','n2:','HorizontalAlignment','right');
        efFN2 = uieditfield(gFres,'numeric','Value',1.5, ...
            'Tooltip','Substrate refractive index n₂ — glass 1.5, Si ~3.9 (visible)'); efFN2.Layout.Row=1; efFN2.Layout.Column=4;
        uilabel(gFres,'Text',[char(952) ' (' char(176) '):'],'HorizontalAlignment','right');
        efFTh = uieditfield(gFres,'numeric','Value',45, ...
            'Tooltip','Angle of incidence θ (deg, from normal) — 0–90'); efFTh.Layout.Row=1; efFTh.Layout.Column=6;
        btnFres = uibutton(gFres,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doFresnel()); btnFres.Layout.Row=1; btnFres.Layout.Column=7;
        lblFresR = uilabel(gFres,'Text','','FontSize',11,'Interpreter','html');
        lblFresR.Layout.Row=2; lblFresR.Layout.Column=[1 7];
        lblFresD = uilabel(gFres,'Text','','FontSize',10,'FontColor',[.5 .5 .5],'Interpreter','html');
        lblFresD.Layout.Row=3; lblFresD.Layout.Column=[1 7];
        function doFresnel()
            try
                r = calc.optics.fresnelCoefficients(efFN1.Value,efFN2.Value,efFTh.Value);
                desc = sprintf('R<sub>s</sub> = %.4f, R<sub>p</sub> = %.4f', r.Rs, r.Rp);
                lblFresR.Text = desc;
                lblFresD.Text = sprintf('T<sub>s</sub> = %.4f, T<sub>p</sub> = %.4f', r.Ts, r.Tp);
                addHistory(desc, r.latex);
            catch ME, lblFresR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 2: Critical / Brewster Angle
        pAng = uipanel(gl,'Title','Critical / Brewster Angle','FontWeight','bold');
        pAng.Layout.Row = 2; pAng.Layout.Column = 1;
        gAng = uigridlayout(pAng);
        gAng.RowHeight = {24,24}; gAng.ColumnWidth = {50,'1x',50,'1x',90};
        gAng.Padding = [6 4 6 4]; gAng.RowSpacing = 4;
        uilabel(gAng,'Text','n1:','HorizontalAlignment','right');
        efAN1 = uieditfield(gAng,'numeric','Value',1.5, ...
            'Tooltip','Incident (denser) medium n₁ — critical angle requires n₁ > n₂'); efAN1.Layout.Row=1; efAN1.Layout.Column=2;
        uilabel(gAng,'Text','n2:','HorizontalAlignment','right');
        efAN2 = uieditfield(gAng,'numeric','Value',1.0, ...
            'Tooltip','Transmitted medium n₂ — e.g. air = 1.0'); efAN2.Layout.Row=1; efAN2.Layout.Column=4;
        btnAng = uibutton(gAng,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doAngles()); btnAng.Layout.Row=1; btnAng.Layout.Column=5;
        lblAngR = uilabel(gAng,'Text','','FontSize',11,'Interpreter','html');
        lblAngR.Layout.Row=2; lblAngR.Layout.Column=[1 5];
        function doAngles()
            try
                rc = calc.optics.criticalAngle(efAN1.Value,efAN2.Value);
                rb = calc.optics.brewsterAngle(efAN1.Value,efAN2.Value);
                desc = sprintf('%s<sub>c</sub> = %.2f%s, %s<sub>B</sub> = %.2f%s', ...
                    char(952),rc.thetaC,char(176),char(952),rb.thetaB,char(176));
                lblAngR.Text = desc;
                addHistory(desc, rc.latex);
            catch ME, lblAngR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 3: Penetration Depth
        pPen = uipanel(gl,'Title','Penetration Depth','FontWeight','bold');
        pPen.Layout.Row = 3; pPen.Layout.Column = 1;
        gPen = uigridlayout(pPen);
        gPen.RowHeight = {24,24}; gPen.ColumnWidth = {30,'1x',30,'1x',50,'1x',90};
        gPen.Padding = [6 4 6 4]; gPen.RowSpacing = 4;
        uilabel(gPen,'Text','n:','HorizontalAlignment','right');
        efPN = uieditfield(gPen,'numeric','Value',1.0, ...
            'Tooltip','Real part of refractive index n — real material > 1'); efPN.Layout.Row=1; efPN.Layout.Column=2;
        uilabel(gPen,'Text','k:','HorizontalAlignment','right');
        efPK = uieditfield(gPen,'numeric','Value',0.001, ...
            'Tooltip','Extinction coefficient k — imaginary part; absorbers 0.1–10, dielectrics ~0'); efPK.Layout.Row=1; efPK.Layout.Column=4;
        uilabel(gPen,'Text',[char(955) ':'],'HorizontalAlignment','right');
        efPLam = uieditfield(gPen,'numeric','Value',1.5406, ...
            'Tooltip','Wavelength λ (same unit as output) — penetration depth = λ/(4πk)'); efPLam.Layout.Row=1; efPLam.Layout.Column=6;
        btnPen = uibutton(gPen,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doPenDepth()); btnPen.Layout.Row=1; btnPen.Layout.Column=7;
        lblPenR = uilabel(gPen,'Text','','FontSize',11,'Interpreter','html');
        lblPenR.Layout.Row=2; lblPenR.Layout.Column=[1 7];
        function doPenDepth()
            try
                r = calc.optics.penetrationDepth(efPN.Value,efPK.Value,efPLam.Value);
                desc = sprintf('Depth = %.4g (same unit as %s)', r.depth, char(955));
                lblPenR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblPenR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 4: Skin Depth
        pSkin = uipanel(gl,'Title','Skin Depth','FontWeight','bold');
        pSkin.Layout.Row = 4; pSkin.Layout.Column = 1;
        gSkin = uigridlayout(pSkin);
        gSkin.RowHeight = {24,24}; gSkin.ColumnWidth = {80,'1x',80,'1x',90};
        gSkin.Padding = [6 4 6 4]; gSkin.RowSpacing = 4;
        uilabel(gSkin,'Text',[char(961) ' (' char(937) char(183) 'm):'],'HorizontalAlignment','right');
        efSRho = uieditfield(gSkin,'numeric','Value',1.7e-8, ...
            'Tooltip','Resistivity ρ (Ω·m, SI) — Cu 1.7e-8, Au 2.4e-8, Al 2.8e-8'); efSRho.Layout.Row=1; efSRho.Layout.Column=2;
        uilabel(gSkin,'Text','f (Hz):','HorizontalAlignment','right');
        efSFreq = uieditfield(gSkin,'numeric','Value',1e9, ...
            'Tooltip','Frequency f (Hz) — typical RF 10⁶–10¹⁰'); efSFreq.Layout.Row=1; efSFreq.Layout.Column=4;
        btnSkin = uibutton(gSkin,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doSkinDepth()); btnSkin.Layout.Row=1; btnSkin.Layout.Column=5;
        lblSkinR = uilabel(gSkin,'Text','','FontSize',11,'Interpreter','html');
        lblSkinR.Layout.Row=2; lblSkinR.Layout.Column=[1 5];
        function doSkinDepth()
            try
                r = calc.optics.skinDepth(efSRho.Value,efSFreq.Value);
                desc = sprintf('%s = %.4g %sm', char(948), r.deltaUm, char(956));
                lblSkinR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblSkinR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        registerPrimaryBtn('optics', btnFres);
        appData.api.calcFresnel = @(n1,n2,th) apiFresnel(n1,n2,th);
        function result = apiFresnel(n1,n2,th)
            efFN1.Value=n1; efFN2.Value=n2; efFTh.Value=th; doFresnel(); result=lblFresR.Text;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% VACUUM TAB
% ════════════════════════════════════════════════════════════════════════

    function buildVacuumTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'2x', '2x', '3x', '2x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % Card 1: Mean Free Path
        pMFP = uipanel(gl,'Title','Mean Free Path','FontWeight','bold');
        pMFP.Layout.Row = 1; pMFP.Layout.Column = 1;
        gMFP = uigridlayout(pMFP);
        gMFP.RowHeight = {24,24}; gMFP.ColumnWidth = {50,'1x',40,'1x',40,'1x',90};
        gMFP.Padding = [6 4 6 4]; gMFP.RowSpacing = 4;
        uilabel(gMFP,'Text','P (Pa):','HorizontalAlignment','right');
        efMFPP = uieditfield(gMFP,'numeric','Value',1e-4, ...
            'Tooltip','Gas pressure P (Pa, SI) — 1 atm ≈ 10⁵, HV 10⁻⁴, UHV 10⁻⁸'); efMFPP.Layout.Row=1; efMFPP.Layout.Column=2;
        uilabel(gMFP,'Text','T (K):','HorizontalAlignment','right');
        efMFPT = uieditfield(gMFP,'numeric','Value',300, ...
            'Tooltip','Temperature (K) — room temperature = 300'); efMFPT.Layout.Row=1; efMFPT.Layout.Column=4;
        uilabel(gMFP,'Text','Gas:','HorizontalAlignment','right');
        ddMFPGas = uidropdown(gMFP, ...
            'Items', {'N2 (air)', 'He', 'Ar', 'H2', 'O2', 'Xe', 'Kr'}, ...
            'ItemsData', {3.64e-10, 2.60e-10, 3.40e-10, 2.89e-10, 3.46e-10, 4.32e-10, 3.60e-10}, ...
            'Value', 3.64e-10, ...
            'Tooltip','Gas species — sets molecular diameter d used in λ = kT/(√2 π d² P)');
        ddMFPGas.Layout.Row=1; ddMFPGas.Layout.Column=6;
        btnMFP = uibutton(gMFP,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doMFP()); btnMFP.Layout.Row=1; btnMFP.Layout.Column=7;
        lblMFPR = uilabel(gMFP,'Text','','FontSize',11,'Interpreter','html');
        lblMFPR.Layout.Row=2; lblMFPR.Layout.Column=[1 7];
        function doMFP()
            try
                kB = 1.380649e-23;
                d  = ddMFPGas.Value;
                P  = efMFPP.Value;
                T  = efMFPT.Value;
                mfp = kB * T / (sqrt(2) * pi * d^2 * P);
                desc = sprintf('MFP = %.4g m (%.4g mm) [%s]', mfp, mfp*1e3, ddMFPGas.Items{ddMFPGas.ItemsData == d});
                lblMFPR.Text = desc; addHistory(desc, '');
            catch ME, lblMFPR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 2: Monolayer Time
        pMono = uipanel(gl,'Title','Monolayer Formation Time','FontWeight','bold');
        pMono.Layout.Row = 2; pMono.Layout.Column = 1;
        gMono = uigridlayout(pMono);
        gMono.RowHeight = {24,24}; gMono.ColumnWidth = {80,'1x',90};
        gMono.Padding = [6 4 6 4]; gMono.RowSpacing = 4;
        uilabel(gMono,'Text','P (Pa):','HorizontalAlignment','right');
        efMonoP = uieditfield(gMono,'numeric','Value',1.33e-4, ...
            'Tooltip','Residual gas pressure P (Pa) — 1.33e-4 Pa = 1e-6 Torr; 1 Langmuir ≈ 1 s at this P'); efMonoP.Layout.Row=1; efMonoP.Layout.Column=2;
        btnMono = uibutton(gMono,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doMono()); btnMono.Layout.Row=1; btnMono.Layout.Column=3;
        lblMonoR = uilabel(gMono,'Text','','FontSize',11,'Interpreter','html');
        lblMonoR.Layout.Row=2; lblMonoR.Layout.Column=[1 3];
        function doMono()
            try
                r = calc.vacuum.monolayerTime(efMonoP.Value);
                desc = sprintf('t<sub>mono</sub> = %.3g s', r.tMono);
                lblMonoR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblMonoR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 3: Sputter Yield
        pSY = uipanel(gl,'Title','Sputter Yield (Lookup)','FontWeight','bold');
        pSY.Layout.Row = 3; pSY.Layout.Column = 1;
        gSY = uigridlayout(pSY);
        gSY.RowHeight = {24,24,24}; gSY.ColumnWidth = {70,'1x',70,'1x',90};
        gSY.Padding = [6 4 6 4]; gSY.RowSpacing = 4;
        uilabel(gSY,'Text','Target:','HorizontalAlignment','right');
        efSYMat = uieditfield(gSY,'text','Value','Si', ...
            'Tooltip','Target material symbol — e.g. Si, Cu, Al, Au'); efSYMat.Layout.Row=1; efSYMat.Layout.Column=2;
        uilabel(gSY,'Text','Ion:','HorizontalAlignment','right');
        efSYIon = uieditfield(gSY,'text','Value','Ar', ...
            'Tooltip','Incident ion symbol — typically Ar, Xe, or Kr'); efSYIon.Layout.Row=1; efSYIon.Layout.Column=4;
        uilabel(gSY,'Text','E (eV):','HorizontalAlignment','right');
        efSYE = uieditfield(gSY,'numeric','Value',500, ...
            'Tooltip','Ion energy E (eV) — typical sputtering 100–2000'); efSYE.Layout.Row=2; efSYE.Layout.Column=2;
        btnSY = uibutton(gSY,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doSputterYield()); btnSY.Layout.Row=2; btnSY.Layout.Column=5;
        lblSYR = uilabel(gSY,'Text','','FontSize',11,'Interpreter','html');
        lblSYR.Layout.Row=3; lblSYR.Layout.Column=[1 5];
        function doSputterYield()
            try
                r = calc.vacuum.sputterYield(efSYMat.Value, efSYIon.Value, efSYE.Value);
                desc = sprintf('Y(%s/%s, %g eV) = %.2f atoms/ion', efSYMat.Value, efSYIon.Value, efSYE.Value, r.Y);
                lblSYR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblSYR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 4: Pump-Down Time
        pPump = uipanel(gl,'Title','Pump-Down Estimate','FontWeight','bold');
        pPump.Layout.Row = 4; pPump.Layout.Column = 1;
        gPump = uigridlayout(pPump);
        gPump.RowHeight = {24,24}; gPump.ColumnWidth = {60,'1x',60,'1x',60,'1x',60,'1x',90};
        gPump.Padding = [6 4 6 4]; gPump.RowSpacing = 4;
        uilabel(gPump,'Text','V (L):','HorizontalAlignment','right');
        efPV = uieditfield(gPump,'numeric','Value',50, ...
            'Tooltip','Chamber volume V (L)'); efPV.Layout.Row=1; efPV.Layout.Column=2;
        uilabel(gPump,'Text','S (L/s):','HorizontalAlignment','right');
        efPS = uieditfield(gPump,'numeric','Value',100, ...
            'Tooltip','Pump effective pumping speed S (L/s) — turbo ~100–1000'); efPS.Layout.Row=1; efPS.Layout.Column=4;
        uilabel(gPump,'Text','P0 (Pa):','HorizontalAlignment','right');
        efPP0 = uieditfield(gPump,'numeric','Value',1e5, ...
            'Tooltip','Starting pressure P₀ (Pa) — atmospheric ≈ 1e5'); efPP0.Layout.Row=1; efPP0.Layout.Column=6;
        uilabel(gPump,'Text','Pf (Pa):','HorizontalAlignment','right');
        efPPf = uieditfield(gPump,'numeric','Value',1e-4, ...
            'Tooltip','Target final pressure P_f (Pa) — HV 10⁻⁴, UHV 10⁻⁷'); efPPf.Layout.Row=1; efPPf.Layout.Column=8;
        btnPump = uibutton(gPump,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doPump()); btnPump.Layout.Row=1; btnPump.Layout.Column=9;
        lblPumpR = uilabel(gPump,'Text','','FontSize',11,'Interpreter','html');
        lblPumpR.Layout.Row=2; lblPumpR.Layout.Column=[1 9];
        function doPump()
            try
                r = calc.vacuum.pumpDownTime(efPV.Value,efPS.Value,efPP0.Value,efPPf.Value);
                desc = sprintf('t = %.1f s (%.1f min), %s = %.2f s', r.time, r.timeMin, char(964), r.tau);
                lblPumpR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblPumpR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        registerPrimaryBtn('vacuum', btnMFP);
        appData.api.calcMeanFreePath = @(P,T) apiMFP(P,T);
        function result = apiMFP(P,T)
            efMFPP.Value=P; efMFPT.Value=T; doMFP(); result=lblMFPR.Text;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% ELECTROCHEMISTRY TAB
% ════════════════════════════════════════════════════════════════════════

    function buildElectrochemistryTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'3x', '2x', '2x', '2x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % Card 1: Nernst Potential
        pNer = uipanel(gl,'Title','Nernst Potential','FontWeight','bold');
        pNer.Layout.Row = 1; pNer.Layout.Column = 1;
        gNer = uigridlayout(pNer);
        gNer.RowHeight = {24,24,24}; gNer.ColumnWidth = {70,'1x',30,'1x',50,'1x',90};
        gNer.Padding = [6 4 6 4]; gNer.RowSpacing = 4;
        uilabel(gNer,'Text','E0 (V):','HorizontalAlignment','right');
        efNerE0 = uieditfield(gNer,'numeric','Value',0.77, ...
            'Tooltip','Standard electrode potential E⁰ (V vs SHE) — Fe³⁺/Fe²⁺ = 0.77'); efNerE0.Layout.Row=1; efNerE0.Layout.Column=2;
        uilabel(gNer,'Text','n:','HorizontalAlignment','right');
        efNerN = uieditfield(gNer,'numeric','Value',1, ...
            'Tooltip','Number of electrons transferred n — integer, typically 1–4'); efNerN.Layout.Row=1; efNerN.Layout.Column=4;
        uilabel(gNer,'Text','Q:','HorizontalAlignment','right');
        efNerQ = uieditfield(gNer,'numeric','Value',0.01, ...
            'Tooltip','Reaction quotient Q — ratio of product to reactant activities (dimensionless)'); efNerQ.Layout.Row=1; efNerQ.Layout.Column=6;
        btnNer = uibutton(gNer,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doNernst()); btnNer.Layout.Row=1; btnNer.Layout.Column=7;
        lblNerR = uilabel(gNer,'Text','','FontSize',11,'Interpreter','html');
        lblNerR.Layout.Row=2; lblNerR.Layout.Column=[1 7];
        lblNerD = uilabel(gNer,'Text','','FontSize',10,'FontColor',[.5 .5 .5],'Interpreter','html');
        lblNerD.Layout.Row=3; lblNerD.Layout.Column=[1 7];
        function doNernst()
            try
                r = calc.electrochemistry.nernstPotential(efNerE0.Value,efNerN.Value,efNerQ.Value);
                desc = sprintf('E = %.4f V', r.E);
                lblNerR.Text = desc;
                lblNerD.Text = sprintf('E%s = %.3f V, n = %d, Q = %.4g', char(8320), r.E0, r.n, r.Q);
                addHistory(desc, r.latex);
            catch ME, lblNerR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 2: Butler-Volmer
        pBV = uipanel(gl,'Title','Butler-Volmer','FontWeight','bold');
        pBV.Layout.Row = 2; pBV.Layout.Column = 1;
        gBV = uigridlayout(pBV);
        gBV.RowHeight = {24,24}; gBV.ColumnWidth = {60,'1x',60,'1x',60,'1x',90};
        gBV.Padding = [6 4 6 4]; gBV.RowSpacing = 4;
        uilabel(gBV,'Text','j0:','HorizontalAlignment','right');
        efBVJ0 = uieditfield(gBV,'numeric','Value',1e-3, ...
            'Tooltip','Exchange current density j₀ (A/cm²) — typical 10⁻⁶–10⁻³'); efBVJ0.Layout.Row=1; efBVJ0.Layout.Column=2;
        uilabel(gBV,'Text',[char(951) ' (V):'],'HorizontalAlignment','right');
        efBVEta = uieditfield(gBV,'numeric','Value',0.1, ...
            'Tooltip','Overpotential η (V) — deviation from equilibrium potential'); efBVEta.Layout.Row=1; efBVEta.Layout.Column=4;
        uilabel(gBV,'Text',[char(945) ':'],'HorizontalAlignment','right');
        efBVAlpha = uieditfield(gBV,'numeric','Value',0.5, ...
            'Tooltip','Charge-transfer coefficient α (dimensionless) — typically 0.3–0.7'); efBVAlpha.Layout.Row=1; efBVAlpha.Layout.Column=6;
        btnBV = uibutton(gBV,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doBV()); btnBV.Layout.Row=1; btnBV.Layout.Column=7;
        lblBVR = uilabel(gBV,'Text','','FontSize',11,'Interpreter','html');
        lblBVR.Layout.Row=2; lblBVR.Layout.Column=[1 7];
        function doBV()
            try
                r = calc.electrochemistry.butlerVolmer(efBVJ0.Value,efBVEta.Value,alpha=efBVAlpha.Value);
                desc = sprintf('j = %.4g A/cm%s', r.j, char(178));
                lblBVR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblBVR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 3: Tafel Slope
        pTaf = uipanel(gl,'Title','Tafel Slope','FontWeight','bold');
        pTaf.Layout.Row = 3; pTaf.Layout.Column = 1;
        gTaf = uigridlayout(pTaf);
        gTaf.RowHeight = {24,24}; gTaf.ColumnWidth = {60,'1x',60,'1x',90};
        gTaf.Padding = [6 4 6 4]; gTaf.RowSpacing = 4;
        uilabel(gTaf,'Text',[char(945) ':'],'HorizontalAlignment','right');
        efTafA = uieditfield(gTaf,'numeric','Value',0.5, ...
            'Tooltip','Charge-transfer coefficient α (dimensionless)'); efTafA.Layout.Row=1; efTafA.Layout.Column=2;
        uilabel(gTaf,'Text','T (K):','HorizontalAlignment','right');
        efTafT = uieditfield(gTaf,'numeric','Value',298.15, ...
            'Tooltip','Temperature (K) — 298.15 K = 25 °C, standard conditions'); efTafT.Layout.Row=1; efTafT.Layout.Column=4;
        btnTaf = uibutton(gTaf,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doTafel()); btnTaf.Layout.Row=1; btnTaf.Layout.Column=5;
        lblTafR = uilabel(gTaf,'Text','','FontSize',11,'Interpreter','html');
        lblTafR.Layout.Row=2; lblTafR.Layout.Column=[1 5];
        function doTafel()
            try
                r = calc.electrochemistry.tafelSlope(alpha=efTafA.Value,T=efTafT.Value);
                desc = sprintf('b = %.1f mV/decade', r.bMv);
                lblTafR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblTafR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        % Card 4: Double Layer Capacitance
        pDLC = uipanel(gl,'Title','Double Layer Capacitance','FontWeight','bold');
        pDLC.Layout.Row = 4; pDLC.Layout.Column = 1;
        gDLC = uigridlayout(pDLC);
        gDLC.RowHeight = {24,24}; gDLC.ColumnWidth = {60,'1x',60,'1x',60,'1x',90};
        gDLC.Padding = [6 4 6 4]; gDLC.RowSpacing = 4;
        uilabel(gDLC,'Text',[char(949) '_r:'],'HorizontalAlignment','right');
        efDLCE = uieditfield(gDLC,'numeric','Value',78, ...
            'Tooltip','Electrolyte dielectric constant ε_r — water ~78, organic ~10–40'); efDLCE.Layout.Row=1; efDLCE.Layout.Column=2;
        uilabel(gDLC,'Text','d (nm):','HorizontalAlignment','right');
        efDLCD = uieditfield(gDLC,'numeric','Value',0.5, ...
            'Tooltip','Helmholtz layer thickness d (nm) — typical 0.3–1 nm'); efDLCD.Layout.Row=1; efDLCD.Layout.Column=4;
        uilabel(gDLC,'Text','A (cm2):','HorizontalAlignment','right');
        efDLCA = uieditfield(gDLC,'numeric','Value',1.0, ...
            'Tooltip','Electrode surface area (cm²)'); efDLCA.Layout.Row=1; efDLCA.Layout.Column=6;
        btnDLC = uibutton(gDLC,'push','Text','Calculate','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doDLC()); btnDLC.Layout.Row=1; btnDLC.Layout.Column=7;
        lblDLCR = uilabel(gDLC,'Text','','FontSize',11,'Interpreter','html');
        lblDLCR.Layout.Row=2; lblDLCR.Layout.Column=[1 7];
        function doDLC()
            try
                r = calc.electrochemistry.doubleLayerCapacitance(efDLCE.Value,efDLCD.Value,efDLCA.Value);
                desc = sprintf('C = %.4g %sF (%.1f %sF/cm%s)', r.CuF, char(956), r.Cspec*1e6, char(956), char(178));
                lblDLCR.Text = desc; addHistory(desc, r.latex);
            catch ME, lblDLCR.Text = ['Error: ' ME.message]; setStatus(ME.message);
            end
        end

        registerPrimaryBtn('electrochemistry', btnNer);
        appData.api.calcNernst = @(E0,n,Q) apiNernst(E0,n,Q);
        function result = apiNernst(E0,n,Q)
            efNerE0.Value=E0; efNerN.Value=n; efNerQ.Value=Q; doNernst(); result=lblNerR.Text;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% THERMAL PROPERTIES TAB
% ════════════════════════════════════════════════════════════════════════

    function buildThermalTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'1x', '1x', '1x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % ── Card 1: Wiedemann-Franz Law ─────────────────────────────────
        pWF = uipanel(gl,'Title','Wiedemann-Franz Law','FontWeight','bold');
        pWF.Layout.Row = 1;
        gWF = uigridlayout(pWF);
        gWF.RowHeight = {24,24}; gWF.ColumnWidth = {100,'1x',60,'1x',90};
        gWF.Padding = [6 4 6 4]; gWF.RowSpacing = 4;

        uilabel(gWF,'Text',[char(963) ' (S/cm):'],'HorizontalAlignment','right');
        efWFSigma = uieditfield(gWF,'numeric','Value',6e5, ...
            'Tooltip','Electrical conductivity σ (S/cm) — Cu 6e5, Au 4.5e5, Al 3.8e5');
        efWFSigma.Layout.Row=1; efWFSigma.Layout.Column=2;
        uilabel(gWF,'Text','T (K):','HorizontalAlignment','right');
        efWFT = uieditfield(gWF,'numeric','Value',300, ...
            'Tooltip','Temperature (K) — Wiedemann-Franz κ = L₀σT');
        efWFT.Layout.Row=1; efWFT.Layout.Column=4;
        btnWFCalc = uibutton(gWF,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doWiedemannFranz());
        btnWFCalc.Layout.Row=1; btnWFCalc.Layout.Column=5;

        lblWFResult = uilabel(gWF,'Text','','FontSize',11,'Interpreter','html');
        lblWFResult.Layout.Row=2; lblWFResult.Layout.Column=[1 5];

        function doWiedemannFranz()
            sigma = efWFSigma.Value * 100;  % S/cm → S/m
            T = efWFT.Value;
            L0 = 2.44e-8;  % Lorenz number (W·Ω/K²)
            kappa = L0 * sigma * T;  % thermal cond (W/m·K)
            desc = sprintf('%s = %.2f W/(m%sK)  [L%s = 2.44%s10<sup>-8</sup> W%s/K%s]', ...
                char(954), kappa, char(183), char(8320), char(215), char(8486), char(178));
            lblWFResult.Text = desc;
            latex = sprintf('\\kappa = L_0 \\sigma T = %.2f~\\text{W/(m\\cdot K)}', kappa);
            addHistory(desc, latex);
        end

        % ── Card 2: Debye Temperature ──────────────────────────────────
        pDeb = uipanel(gl,'Title','Debye Temperature','FontWeight','bold');
        pDeb.Layout.Row = 2;
        gDeb = uigridlayout(pDeb);
        gDeb.RowHeight = {24,24}; gDeb.ColumnWidth = {80,'1x',80,'1x',90};
        gDeb.Padding = [6 4 6 4]; gDeb.RowSpacing = 4;

        uilabel(gDeb,'Text','v_s (m/s):','HorizontalAlignment','right');
        efDebVs = uieditfield(gDeb,'numeric','Value',5000, ...
            'Tooltip','Average sound velocity v_s (m/s) — typical 2000–8000 in solids');
        efDebVs.Layout.Row=1; efDebVs.Layout.Column=2;
        uilabel(gDeb,'Text','n (atoms/m³):','HorizontalAlignment','right');
        efDebN = uieditfield(gDeb,'numeric','Value',5e28, ...
            'Tooltip','Atom number density (atoms/m³) — typical metals ~5e28');
        efDebN.Layout.Row=1; efDebN.Layout.Column=4;
        btnDebCalc = uibutton(gDeb,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDebye());
        btnDebCalc.Layout.Row=1; btnDebCalc.Layout.Column=5;

        lblDebResult = uilabel(gDeb,'Text','','FontSize',11,'Interpreter','html');
        lblDebResult.Layout.Row=2; lblDebResult.Layout.Column=[1 5];

        function doDebye()
            vs = efDebVs.Value;
            n = efDebN.Value;
            hbar = 1.054571817e-34;
            kB = 1.380649e-23;
            thetaD = (hbar / kB) * vs * (6 * pi^2 * n)^(1/3);
            desc = sprintf('%s<sub>D</sub> = %.0f K', char(920), thetaD);
            lblDebResult.Text = desc;
            latex = sprintf('\\Theta_D = %.0f~\\text{K}', thetaD);
            addHistory(desc, latex);
        end

        % ── Card 3: Thermal Diffusivity ─────────────────────────────────
        pDiff = uipanel(gl,'Title','Thermal Diffusivity','FontWeight','bold');
        pDiff.Layout.Row = 3;
        gDiff = uigridlayout(pDiff);
        gDiff.RowHeight = {24,24}; gDiff.ColumnWidth = {80,'1x',60,'1x',70,'1x',90};
        gDiff.Padding = [6 4 6 4]; gDiff.RowSpacing = 4;

        uilabel(gDiff,'Text',[char(954) ' (W/mK):'],'HorizontalAlignment','right');
        efDiffK = uieditfield(gDiff,'numeric','Value',150, ...
            'Tooltip','Thermal conductivity κ (W/m·K) — Si 150, Cu 400, Al₂O₃ 30');
        efDiffK.Layout.Row=1; efDiffK.Layout.Column=2;
        uilabel(gDiff,'Text',[char(961) ' (kg/m³):'],'HorizontalAlignment','right');
        efDiffRho = uieditfield(gDiff,'numeric','Value',2329, ...
            'Tooltip','Mass density ρ (kg/m³) — Si 2329, Cu 8960');
        efDiffRho.Layout.Row=1; efDiffRho.Layout.Column=4;
        uilabel(gDiff,'Text','c_p (J/kgK):','HorizontalAlignment','right');
        efDiffCp = uieditfield(gDiff,'numeric','Value',700, ...
            'Tooltip','Specific heat c_p (J/kg·K) — Si 700, Cu 385');
        efDiffCp.Layout.Row=1; efDiffCp.Layout.Column=6;
        btnDiffCalc = uibutton(gDiff,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doThermalDiffusivity());
        btnDiffCalc.Layout.Row=1; btnDiffCalc.Layout.Column=7;

        lblDiffResult = uilabel(gDiff,'Text','','FontSize',11,'Interpreter','html');
        lblDiffResult.Layout.Row=2; lblDiffResult.Layout.Column=[1 7];

        function doThermalDiffusivity()
            kappa = efDiffK.Value;
            rho = efDiffRho.Value;
            cp = efDiffCp.Value;
            alpha = kappa / (rho * cp);  % m²/s
            alpha_mm2 = alpha * 1e6;      % mm²/s
            desc = sprintf('%s = %.4g m%s/s = %.3f mm%s/s', ...
                char(945), alpha, char(178), alpha_mm2, char(178));
            lblDiffResult.Text = desc;
            latex = sprintf('\\alpha = \\kappa/(\\rho c_p) = %.4g~\\text{m}^2/\\text{s}', alpha);
            addHistory(desc, latex);
        end

        registerPrimaryBtn('thermal', btnWFCalc);
    end

% ════════════════════════════════════════════════════════════════════════
% DIFFUSION TAB
% ════════════════════════════════════════════════════════════════════════

    function buildDiffusionTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'1x', '1x', '1x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % ── Card 1: Arrhenius Diffusion Coefficient ─────────────────────
        pArr = uipanel(gl,'Title','Arrhenius Diffusion Coefficient','FontWeight','bold');
        pArr.Layout.Row = 1;
        gArr = uigridlayout(pArr);
        gArr.RowHeight = {24,24}; gArr.ColumnWidth = {60,'1x',60,'1x',60,'1x',90};
        gArr.Padding = [6 4 6 4]; gArr.RowSpacing = 4;

        uilabel(gArr,'Text','D0 (cm²/s):','HorizontalAlignment','right');
        efArrD0 = uieditfield(gArr,'numeric','Value',0.1, ...
            'Tooltip','Pre-exponential factor D₀ (cm²/s) — typical 1e-4 to 10');
        efArrD0.Layout.Row=1; efArrD0.Layout.Column=2;
        uilabel(gArr,'Text','Ea (eV):','HorizontalAlignment','right');
        efArrEa = uieditfield(gArr,'numeric','Value',1.0, ...
            'Tooltip','Activation energy E_a (eV) — typical 0.5–5 for diffusion');
        efArrEa.Layout.Row=1; efArrEa.Layout.Column=4;
        uilabel(gArr,'Text','T (K):','HorizontalAlignment','right');
        efArrT = uieditfield(gArr,'numeric','Value',1000, ...
            'Tooltip','Temperature T (K) — e.g. typical Si diffusion 1000–1200');
        efArrT.Layout.Row=1; efArrT.Layout.Column=6;
        btnArrCalc = uibutton(gArr,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doArrhenius());
        btnArrCalc.Layout.Row=1; btnArrCalc.Layout.Column=7;

        lblArrResult = uilabel(gArr,'Text','','FontSize',11,'Interpreter','html');
        lblArrResult.Layout.Row=2; lblArrResult.Layout.Column=[1 7];

        function doArrhenius()
            D0 = efArrD0.Value;
            Ea = efArrEa.Value;
            T = efArrT.Value;
            kB_eV = 8.617333262e-5;  % eV/K
            D = D0 * exp(-Ea / (kB_eV * T));
            desc = sprintf('D = %.4g cm%s/s at %d K', D, char(178), T);
            lblArrResult.Text = desc;
            latex = sprintf('D = D_0 e^{-E_a/k_BT} = %.4g~\\text{cm}^2/\\text{s}', D);
            addHistory(desc, latex);
        end

        % ── Card 2: Diffusion Length ────────────────────────────────────
        pDL = uipanel(gl,'Title','Diffusion Length','FontWeight','bold');
        pDL.Layout.Row = 2;
        gDL = uigridlayout(pDL);
        gDL.RowHeight = {24,24}; gDL.ColumnWidth = {80,'1x',80,'1x',90};
        gDL.Padding = [6 4 6 4]; gDL.RowSpacing = 4;

        uilabel(gDL,'Text','D (cm²/s):','HorizontalAlignment','right');
        efDLD = uieditfield(gDL,'numeric','Value',1e-12, ...
            'Tooltip','Diffusion coefficient D (cm²/s) — L = √(D·t)');
        efDLD.Layout.Row=1; efDLD.Layout.Column=2;
        uilabel(gDL,'Text','t (s):','HorizontalAlignment','right');
        efDLt = uieditfield(gDL,'numeric','Value',3600, ...
            'Tooltip','Diffusion time t (s) — e.g. 3600 s = 1 h');
        efDLt.Layout.Row=1; efDLt.Layout.Column=4;
        btnDLCalc = uibutton(gDL,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doDiffLength());
        btnDLCalc.Layout.Row=1; btnDLCalc.Layout.Column=5;

        lblDLResult = uilabel(gDL,'Text','','FontSize',11,'Interpreter','html');
        lblDLResult.Layout.Row=2; lblDLResult.Layout.Column=[1 5];

        function doDiffLength()
            D = efDLD.Value;    % cm²/s
            t = efDLt.Value;    % s
            Ld = sqrt(D * t);   % cm
            Ld_um = Ld * 1e4;   % μm
            Ld_nm = Ld * 1e7;   % nm
            if Ld_um >= 1
                desc = sprintf('L = %s(Dt) = %.3g cm = %.2f %sm', ...
                    char(8730), Ld, Ld_um, char(956));
            else
                desc = sprintf('L = %s(Dt) = %.3g cm = %.1f nm', ...
                    char(8730), Ld, Ld_nm);
            end
            lblDLResult.Text = desc;
            addHistory(desc, '');
        end

        % ── Card 3: Fick's First Law (Steady-State Flux) ───────────────
        pFick = uipanel(gl,'Title',['Fick' char(39) 's First Law (Flux)'],'FontWeight','bold');
        pFick.Layout.Row = 3;
        gFick = uigridlayout(pFick);
        gFick.RowHeight = {24,24}; gFick.ColumnWidth = {80,'1x',80,'1x',80,'1x',90};
        gFick.Padding = [6 4 6 4]; gFick.RowSpacing = 4;

        uilabel(gFick,'Text','D (cm²/s):','HorizontalAlignment','right');
        efFickD = uieditfield(gFick,'numeric','Value',1e-12, ...
            'Tooltip','Diffusion coefficient D (cm²/s)');
        efFickD.Layout.Row=1; efFickD.Layout.Column=2;
        uilabel(gFick,'Text',[char(916) 'C (cm' char(8315) char(179) '):'],'HorizontalAlignment','right');
        efFickDC = uieditfield(gFick,'numeric','Value',1e18, ...
            'Tooltip','Concentration difference ΔC (cm⁻³)');
        efFickDC.Layout.Row=1; efFickDC.Layout.Column=4;
        uilabel(gFick,'Text',[char(916) 'x (cm):'],'HorizontalAlignment','right');
        efFickDx = uieditfield(gFick,'numeric','Value',1e-5, ...
            'Tooltip','Distance over which ΔC occurs (cm) — J = -D·ΔC/Δx');
        efFickDx.Layout.Row=1; efFickDx.Layout.Column=6;
        btnFickCalc = uibutton(gFick,'push','Text','Calculate', ...
            'BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doFick());
        btnFickCalc.Layout.Row=1; btnFickCalc.Layout.Column=7;

        lblFickResult = uilabel(gFick,'Text','','FontSize',11,'Interpreter','html');
        lblFickResult.Layout.Row=2; lblFickResult.Layout.Column=[1 7];

        function doFick()
            D = efFickD.Value;
            dC = efFickDC.Value;
            dx = efFickDx.Value;
            J = -D * dC / dx;  % atoms/(cm²·s)
            desc = sprintf('J = -D %sC/%sx = %.4g atoms/(cm%s%ss)', ...
                char(8706), char(8706), abs(J), char(178), char(183));
            lblFickResult.Text = desc;
            addHistory(desc, '');
        end

        registerPrimaryBtn('diffusion', btnArrCalc);
    end

% ════════════════════════════════════════════════════════════════════════
% SUBSTRATE DATABASE TAB
% ════════════════════════════════════════════════════════════════════════

    function buildSubstratesTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {28, '1x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 6;

        % Search row
        searchGL = uigridlayout(gl, [1 3]);
        searchGL.ColumnWidth = {80, '1x', 100}; searchGL.Layout.Row = 1;
        searchGL.Padding = [0 0 0 0];
        uilabel(searchGL,'Text','Substrate:','HorizontalAlignment','right');
        ddSubstrate = uidropdown(searchGL, ...
            'ValueChangedFcn', @(~,~) onSubstrateSelected(), ...
            'Tooltip','Substrate preset — pick a single-crystal oxide/semiconductor to view its full property card');
        ddSubstrate.Layout.Row = 1; ddSubstrate.Layout.Column = 2;
        btnCopySub = uibutton(searchGL,'push','Text','Copy All', ...
            'BackgroundColor',BTN_EXPORT,'FontColor',BTN_FG, ...
            'ButtonPushedFcn',@(~,~) doCopySubstrate());
        btnCopySub.Layout.Row = 1; btnCopySub.Layout.Column = 3;

        % Detail table
        tblSub = uitable(gl, 'ColumnName', {'Property','Value','Unit'}, ...
            'ColumnEditable', false, 'RowName', {});
        tblSub.Layout.Row = 2;

        % ── Substrate Database ──────────────────────────────────────────
        subs = struct();

        subs.STO.name = 'SrTiO3'; subs.STO.crystal = 'Cubic (Pm-3m)';
        subs.STO.a = 3.905; subs.STO.b = 3.905; subs.STO.c = 3.905;
        subs.STO.alpha_th = 9.4e-6; subs.STO.density = 5.12;
        subs.STO.eps_r = 300; subs.STO.Tm = 2080; subs.STO.bandgap = 3.2;

        subs.LAO.name = 'LaAlO3'; subs.LAO.crystal = 'Rhombohedral (pseudo-cubic)';
        subs.LAO.a = 3.789; subs.LAO.b = 3.789; subs.LAO.c = 3.789;
        subs.LAO.alpha_th = 10e-6; subs.LAO.density = 6.52;
        subs.LAO.eps_r = 25; subs.LAO.Tm = 2180; subs.LAO.bandgap = 5.6;

        subs.MgO.name = 'MgO'; subs.MgO.crystal = 'Cubic (Fm-3m)';
        subs.MgO.a = 4.212; subs.MgO.b = 4.212; subs.MgO.c = 4.212;
        subs.MgO.alpha_th = 10.8e-6; subs.MgO.density = 3.58;
        subs.MgO.eps_r = 9.7; subs.MgO.Tm = 2852; subs.MgO.bandgap = 7.8;

        subs.Si.name = 'Si'; subs.Si.crystal = 'Diamond cubic (Fd-3m)';
        subs.Si.a = 5.431; subs.Si.b = 5.431; subs.Si.c = 5.431;
        subs.Si.alpha_th = 2.6e-6; subs.Si.density = 2.329;
        subs.Si.eps_r = 11.7; subs.Si.Tm = 1687; subs.Si.bandgap = 1.12;

        subs.Sapphire.name = 'Al2O3 (Sapphire)'; subs.Sapphire.crystal = 'Hexagonal (R-3c)';
        subs.Sapphire.a = 4.758; subs.Sapphire.b = 4.758; subs.Sapphire.c = 12.991;
        subs.Sapphire.alpha_th = 5.0e-6; subs.Sapphire.density = 3.98;
        subs.Sapphire.eps_r = 9.3; subs.Sapphire.Tm = 2050; subs.Sapphire.bandgap = 9.9;

        subs.GaAs.name = 'GaAs'; subs.GaAs.crystal = 'Zincblende (F-43m)';
        subs.GaAs.a = 5.653; subs.GaAs.b = 5.653; subs.GaAs.c = 5.653;
        subs.GaAs.alpha_th = 5.73e-6; subs.GaAs.density = 5.317;
        subs.GaAs.eps_r = 12.9; subs.GaAs.Tm = 1511; subs.GaAs.bandgap = 1.42;

        subs.LSAT.name = '(LaAlO3)0.3(Sr2TaAlO6)0.7'; subs.LSAT.crystal = 'Cubic (Pm-3m)';
        subs.LSAT.a = 3.868; subs.LSAT.b = 3.868; subs.LSAT.c = 3.868;
        subs.LSAT.alpha_th = 10e-6; subs.LSAT.density = 6.74;
        subs.LSAT.eps_r = 22; subs.LSAT.Tm = 2000; subs.LSAT.bandgap = 4.8;

        subs.NGO.name = 'NdGaO3'; subs.NGO.crystal = 'Orthorhombic (Pbnm)';
        subs.NGO.a = 5.426; subs.NGO.b = 5.502; subs.NGO.c = 7.706;
        subs.NGO.alpha_th = 7.0e-6; subs.NGO.density = 7.58;
        subs.NGO.eps_r = 22; subs.NGO.Tm = 1900; subs.NGO.bandgap = 3.8;

        subs.SiO2.name = 'SiO2 (fused quartz)'; subs.SiO2.crystal = 'Amorphous';
        subs.SiO2.a = 0; subs.SiO2.b = 0; subs.SiO2.c = 0;
        subs.SiO2.alpha_th = 0.55e-6; subs.SiO2.density = 2.20;
        subs.SiO2.eps_r = 3.9; subs.SiO2.Tm = 1713; subs.SiO2.bandgap = 9.0;

        subs.YSZ.name = 'Y:ZrO2 (YSZ)'; subs.YSZ.crystal = 'Cubic (Fm-3m)';
        subs.YSZ.a = 5.125; subs.YSZ.b = 5.125; subs.YSZ.c = 5.125;
        subs.YSZ.alpha_th = 10.5e-6; subs.YSZ.density = 6.10;
        subs.YSZ.eps_r = 27; subs.YSZ.Tm = 2715; subs.YSZ.bandgap = 5.8;

        % Populate dropdown
        subKeys = fieldnames(subs);
        subNames = cell(1, numel(subKeys));
        for si = 1:numel(subKeys)
            subNames{si} = sprintf('%s — %s', subKeys{si}, subs.(subKeys{si}).name);
        end
        ddSubstrate.Items = subNames;
        ddSubstrate.ItemsData = subKeys;
        ddSubstrate.Value = subKeys{1};

        onSubstrateSelected();

        function onSubstrateSelected()
            key = ddSubstrate.Value;
            s = subs.(key);
            data = { ...
                'Name',         s.name,                     '';
                'Crystal',      s.crystal,                  '';
                'a',            sprintf('%.4f', s.a),       char(197);
                'b',            sprintf('%.4f', s.b),       char(197);
                'c',            sprintf('%.4f', s.c),       char(197);
                'Density',      sprintf('%.3f', s.density), ['g/cm' char(179)];
                [char(945) '_th'], sprintf('%.2g', s.alpha_th), '1/K';
                [char(949) '_r'], sprintf('%.1f', s.eps_r), '';
                'Melting pt',   sprintf('%d', s.Tm),        'K';
                'Bandgap',      sprintf('%.2f', s.bandgap), 'eV';
            };
            % Remove rows with 0 lattice params (amorphous)
            if s.a == 0
                data(3:5,:) = [];
            end
            tblSub.Data = data;
            setStatus(sprintf('Substrate: %s', s.name));
        end

        function doCopySubstrate()
            key = ddSubstrate.Value;
            s = subs.(key);
            lines = { ...
                sprintf('Substrate: %s (%s)', s.name, key), ...
                sprintf('Crystal: %s', s.crystal), ...
                sprintf('a=%.4f b=%.4f c=%.4f Ang', s.a, s.b, s.c), ...
                sprintf('Density: %.3f g/cm3', s.density), ...
                sprintf('alpha_th: %.2g /K', s.alpha_th), ...
                sprintf('eps_r: %.1f', s.eps_r), ...
                sprintf('Tm: %d K', s.Tm), ...
                sprintf('Bandgap: %.2f eV', s.bandgap)};
            clipboard('copy', strjoin(lines, newline));
            setStatus(sprintf('Copied %s properties to clipboard', key));
        end
    end

% ════════════════════════════════════════════════════════════════════════
% REFLECTIVITY BUILDER TAB
% ════════════════════════════════════════════════════════════════════════

    function buildReflectivityTab(tab)
        gl = uigridlayout(tab);
        gl.RowHeight = {'3x', 55, '2x'}; gl.ColumnWidth = {'1x'};
        gl.Padding = [6 6 6 6]; gl.RowSpacing = 8;

        % Density mode: 'sld' (×10⁻⁶ Å⁻²) or 'density' (g/cm³)
        densityMode = 'sld';

        % Layer state
        mlStack = {};  % cell array of layer structs (.density field = SLD or g/cm³ per mode)

        % Default stack: air / film / substrate  (SLD values, ×10⁻⁶ Å⁻²)
        mlStack{1} = struct('name','Ambient','formula','','thickness',0,'density',0,'roughness',0);
        mlStack{2} = struct('name','Film','formula','Fe','thickness',200,'density',8.024,'roughness',5);
        mlStack{3} = struct('name','Si (substrate)','formula','Si','thickness',0,'density',2.074,'roughness',2);

        % Card 1: Layer Stack Table
        pStack = uipanel(gl,'Title','Layer Stack (top to bottom)','FontWeight','bold');
        pStack.Layout.Row = 1; pStack.Layout.Column = 1;
        gStack = uigridlayout(pStack);
        gStack.RowHeight = {30, '1x', 42}; gStack.ColumnWidth = {'1x'};
        gStack.Padding = [4 4 4 4]; gStack.RowSpacing = 4;

        % Density mode selector row
        modeGL = uigridlayout(gStack, [1 2]);
        modeGL.ColumnWidth = {90, 180}; modeGL.Layout.Row = 1;
        modeGL.Padding = [0 0 0 0];
        uilabel(modeGL,'Text','Density units:','HorizontalAlignment','right');
        ddDensityMode = uidropdown(modeGL, ...
            'Items', {['SLD (' char(215) '10' char(8315) char(8310) ' ' char(197) char(8315) char(178) ')'], ...
                      ['Mass density (g/cm' char(179) ')']}, ...
            'ItemsData', {'sld', 'density'}, ...
            'Value', 'sld', ...
            'ValueChangedFcn', @(~,~) onDensityModeChanged(), ...
            'Tooltip','Density column units — enter layer density directly as SLD (×10⁻⁶ Å⁻²) or mass density (g/cm³)');
        ddDensityMode.Layout.Row = 1; ddDensityMode.Layout.Column = 2;

        tblML = uitable(gStack, ...
            'ColumnName', {'Name','Formula',['t (' char(197) ')'],densityColHeader(),[char(963) ' (' char(197) ')']}, ...
            'ColumnEditable', [true true true true true], ...
            'ColumnFormat', {'char','char','numeric','numeric','numeric'}, ...
            'CellEditCallback', @onMLCellEdit);
        tblML.Layout.Row = 2;

        btnRowGL = uigridlayout(gStack, [1 5]);
        btnRowGL.ColumnWidth = {80, 80, 70, 70, '1x'}; btnRowGL.Layout.Row = 3;
        btnAddLyr = uibutton(btnRowGL,'push','Text','Add Layer','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) onAddLayer()); btnAddLyr.Layout.Column = 1;
        btnRemLyr = uibutton(btnRowGL,'push','Text','Remove','BackgroundColor',[.7 .2 .2],'FontColor',[1 1 1],...
            'ButtonPushedFcn',@(~,~) onRemoveLayer()); btnRemLyr.Layout.Column = 2;
        btnMoveUp = uibutton(btnRowGL,'push','Text','Move Up','BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG,...
            'ButtonPushedFcn',@(~,~) onMoveLayer(-1)); btnMoveUp.Layout.Column = 3;
        btnMoveDn = uibutton(btnRowGL,'push','Text','Move Down','BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG,...
            'ButtonPushedFcn',@(~,~) onMoveLayer(1)); btnMoveDn.Layout.Column = 4;

        % Card 2: Computed Properties
        pProps = uipanel(gl,'Title','Computed Properties','FontWeight','bold');
        pProps.Layout.Row = 2; pProps.Layout.Column = 1;
        gProps = uigridlayout(pProps);
        gProps.RowHeight = {20,20}; gProps.ColumnWidth = {'1x'};
        gProps.Padding = [6 4 6 4];
        lblMLProps = uilabel(gProps,'Text','','FontSize',11,'Interpreter','html');
        lblMLProps.Layout.Row = 1;
        lblMLFringe = uilabel(gProps,'Text','','FontSize',11,'Interpreter','html');
        lblMLFringe.Layout.Row = 2;

        % Card 3: SLD Profile + Export
        pSLD = uipanel(gl,'Title','SLD Profile','FontWeight','bold');
        pSLD.Layout.Row = 3; pSLD.Layout.Column = 1;
        gSLD = uigridlayout(pSLD);
        gSLD.RowHeight = {28, '1x'}; gSLD.ColumnWidth = {90, 90, 80, '1x'};
        gSLD.Padding = [4 4 4 4]; gSLD.RowSpacing = 4;

        btnCalcSLD = uibutton(gSLD,'push','Text','Neutron SLD','BackgroundColor',BTN_PRIMARY,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doCalcSLD('neutron')); btnCalcSLD.Layout.Row=1; btnCalcSLD.Layout.Column=1;
        btnCalcXSLD = uibutton(gSLD,'push','Text','X-ray SLD','BackgroundColor',BTN_TOOL,'FontColor',BTN_TOOL_FG,...
            'ButtonPushedFcn',@(~,~) doCalcSLD('xray')); btnCalcXSLD.Layout.Row=1; btnCalcXSLD.Layout.Column=2;
        btnCalcRQ = uibutton(gSLD,'push','Text','R(Q)','BackgroundColor',[0.6 0.2 0.6],'FontColor',[1 1 1],...
            'ButtonPushedFcn',@(~,~) doCalcReflectivity()); btnCalcRQ.Layout.Row=1; btnCalcRQ.Layout.Column=3;
        btnExportCSV = uibutton(gSLD,'push','Text','Export CSV','BackgroundColor',BTN_EXPORT,'FontColor',BTN_FG,...
            'ButtonPushedFcn',@(~,~) doExportMLCSV()); btnExportCSV.Layout.Row=1; btnExportCSV.Layout.Column=4;

        axSLD = uiaxes(gSLD);
        axSLD.Layout.Row = 2; axSLD.Layout.Column = [1 4];
        axSLD.XLabel.String = ['Depth (' char(197) ')'];
        axSLD.YLabel.String = ['SLD (10^{-6} ' char(197) '^{-2})'];

        refreshMLTable();
        updateMLProperties();

        function hdr = densityColHeader()
            if strcmp(densityMode, 'sld')
                hdr = ['SLD (' char(215) '10' char(8315) char(8310) ' ' char(197) char(8315) char(178) ')'];
            else
                hdr = [char(961) ' (g/cm' char(179) ')'];
            end
        end

        function onDensityModeChanged()
            newMode = ddDensityMode.Value;
            if strcmp(newMode, densityMode), return; end

            % Convert existing density values between modes
            for li = 1:numel(mlStack)
                s = mlStack{li};
                if isempty(s.formula) || s.density == 0
                    continue;
                end
                try
                    if strcmp(newMode, 'sld')
                        % g/cm³ → SLD: compute neutron SLD from mass density
                        sr = calc.xrayNeutron.neutronSLD(s.formula, s.density);
                        mlStack{li}.density = sr.SLDe6;
                    else
                        % SLD → g/cm³: reverse-calculate mass density
                        % SLD = (N_A * density * sum(b_coh)) / M
                        % density = SLD * M / (N_A * sum(b_coh))
                        % Use a reference calc at density=1 to get the conversion factor
                        ref = calc.xrayNeutron.neutronSLD(s.formula, 1.0);
                        if ref.SLDe6 ~= 0
                            mlStack{li}.density = s.density / ref.SLDe6;
                        end
                    end
                catch
                    % leave value as-is if conversion fails
                end
            end

            densityMode = newMode;
            tblML.ColumnName{4} = densityColHeader();
            refreshMLTable();
            updateMLProperties();
            setStatus(sprintf('Density units: %s', newMode));
        end

        function refreshMLTable()
            nLayers = numel(mlStack);
            data = cell(nLayers, 5);
            for li = 1:nLayers
                s = mlStack{li};
                data{li,1} = s.name;
                data{li,2} = s.formula;
                data{li,3} = s.thickness;
                data{li,4} = s.density;
                data{li,5} = s.roughness;
            end
            tblML.Data = data;
        end

        function onMLCellEdit(~, evt)
            r2 = evt.Indices(1); c2 = evt.Indices(2);
            if r2 > numel(mlStack), return; end
            switch c2
                case 1, mlStack{r2}.name = evt.NewData;
                case 2, mlStack{r2}.formula = evt.NewData;
                case 3, mlStack{r2}.thickness = evt.NewData;
                case 4, mlStack{r2}.density = evt.NewData;
                case 5, mlStack{r2}.roughness = evt.NewData;
            end
            updateMLProperties();
        end

        function onAddLayer()
            nL = numel(mlStack);
            if strcmp(densityMode, 'sld')
                newLayer = struct('name','New Layer','formula','','thickness',100,'density',0,'roughness',3);
            else
                newLayer = struct('name','New Layer','formula','','thickness',100,'density',1,'roughness',3);
            end
            if nL >= 2
                mlStack = [mlStack(1:nL-1), {newLayer}, mlStack(nL)];
            else
                mlStack{end+1} = newLayer;
            end
            refreshMLTable(); updateMLProperties();
        end

        function onRemoveLayer()
            if numel(mlStack) <= 2, return; end
            sel = tblML.Selection;
            if isempty(sel), return; end
            idx = sel(1);
            if idx == 1 || idx == numel(mlStack), return; end
            mlStack(idx) = [];
            refreshMLTable(); updateMLProperties();
        end

        function onMoveLayer(dir)
            sel = tblML.Selection;
            if isempty(sel), return; end
            idx = sel(1); nL = numel(mlStack);
            newIdx = idx + dir;
            if newIdx < 2 || newIdx > nL-1, return; end
            if idx < 2 || idx > nL-1, return; end
            tmp = mlStack{idx}; mlStack{idx} = mlStack{newIdx}; mlStack{newIdx} = tmp;
            refreshMLTable(); updateMLProperties();
        end

        function sldVal = layerSLD(s)
        %LAYERSLD  Get SLD value for a layer (compute from density if needed).
            sldVal = 0;
            if strcmp(densityMode, 'sld')
                sldVal = s.density;  % already in SLD units
            else
                % density mode: compute SLD from formula + mass density
                if ~isempty(s.formula) && s.density > 0
                    try
                        sr = calc.xrayNeutron.neutronSLD(s.formula, s.density);
                        sldVal = sr.SLDe6;
                    catch
                    end
                end
            end
        end

        function updateMLProperties()
            nL = numel(mlStack);
            totalT = 0; weightedV = 0;
            for li = 2:nL-1
                totalT = totalT + mlStack{li}.thickness;
                weightedV = weightedV + mlStack{li}.density * mlStack{li}.thickness;
            end
            avgV = 0; if totalT > 0, avgV = weightedV / totalT; end
            deltaQ = 0; if totalT > 0, deltaQ = 2*pi / totalT; end
            if strcmp(densityMode, 'sld')
                lblMLProps.Text = sprintf('Total thickness: %.1f %s, Avg SLD: %.3f %s10<sup>-6</sup> %s<sup>-2</sup>', ...
                    totalT, char(197), avgV, char(215), char(197));
            else
                lblMLProps.Text = sprintf('Total thickness: %.1f %s, Avg density: %.3f g/cm%s', ...
                    totalT, char(197), avgV, char(179));
            end
            lblMLFringe.Text = sprintf('%sQ (Kiessig) = %.5f %s<sup>-1</sup>', ...
                char(916), deltaQ, char(197));
        end

        function doCalcSLD(mode)
            cla(axSLD);
            nL = numel(mlStack);
            depth = 0; depths = []; slds = [];
            for li = 1:nL
                s = mlStack{li};
                if strcmp(densityMode, 'sld')
                    % Direct SLD values
                    sldVal = s.density;
                else
                    % Compute from formula + mass density
                    sldVal = 0;
                    if ~isempty(s.formula) && s.density > 0
                        try
                            if strcmp(mode, 'neutron')
                                sr = calc.xrayNeutron.neutronSLD(s.formula, s.density);
                            else
                                sr = calc.xrayNeutron.xraySLD(s.formula, s.density);
                            end
                            sldVal = sr.SLDe6;
                        catch
                        end
                    end
                end
                t = s.thickness;
                if t == 0, t = 50; end  % draw ambient/substrate as 50 Å
                depths = [depths, depth, depth + t]; %#ok<AGROW>
                slds = [slds, sldVal, sldVal]; %#ok<AGROW>
                depth = depth + t;
            end
            plot(axSLD, depths, slds, 'b-', 'LineWidth', 1.5);
            axSLD.XLabel.String = ['Depth (' char(197) ')'];
            axSLD.YLabel.String = ['SLD (10^{-6} ' char(197) '^{-2})'];
            title(axSLD, [upper(mode(1)) mode(2:end) ' SLD Profile']);
            setStatus(sprintf('SLD profile computed (%s)', mode));
        end

        function doCalcReflectivity()
        %DOCALCREFLECTIVITY  Parratt recursion: compute and plot R(Q).
            nL = numel(mlStack);
            if nL < 2
                setStatus('Need at least 2 layers for reflectivity');
                return;
            end

            % Build SLD array (×10⁻⁶ Å⁻²) for each layer
            sldArr = zeros(1, nL);
            thkArr = zeros(1, nL);   % thickness in Å
            sigArr = zeros(1, nL);   % roughness in Å
            for li = 1:nL
                s = mlStack{li};
                if strcmp(densityMode, 'sld')
                    sldArr(li) = s.density;
                else
                    if ~isempty(s.formula) && s.density > 0
                        try
                            sr = calc.xrayNeutron.neutronSLD(s.formula, s.density);
                            sldArr(li) = sr.SLDe6;
                        catch
                        end
                    end
                end
                thkArr(li) = s.thickness;
                sigArr(li) = s.roughness;
            end

            % Q range
            Q = linspace(0.005, 0.25, 500);

            % Parratt recursion (substrate = last layer, ambient = first)
            % SLD in Å⁻² (convert from ×10⁻⁶)
            sld = sldArr * 1e-6;
            R = parrattRecursion(Q, sld, thkArr, sigArr);

            cla(axSLD);
            semilogy(axSLD, Q, R, 'b-', 'LineWidth', 1.5);
            axSLD.XLabel.String = ['Q (' char(197) '^{-1})'];
            axSLD.YLabel.String = 'R(Q)';
            title(axSLD, 'Neutron Reflectivity');
            setStatus('Reflectivity R(Q) computed (Parratt recursion)');
        end

        function R = parrattRecursion(Q, sld, thk, sig)
        %PARRATTRECURSION  Parratt recursive formula for specular reflectivity.
        %   Layers ordered top-to-bottom: ambient (1), film layers, substrate (N).
            nL = numel(sld);
            R = zeros(size(Q));
            for qi = 1:numel(Q)
                qval = Q(qi);
                if qval <= 0, R(qi) = 1; continue; end

                % Wave vector component kz in each layer
                % kz_j = sqrt((Q/2)^2 - 4*pi*sld_j)  (complex)
                kz = sqrt(complex((qval/2)^2 - 4*pi*sld));

                % Start from substrate: r_{N-1,N} and iterate upward
                % Fresnel coefficient at interface j/j+1:
                %   r_{j,j+1} = (kz_j - kz_{j+1}) / (kz_j + kz_{j+1})
                %   with Nevot-Croce roughness: * exp(-2 * kz_j * kz_{j+1} * sig_{j+1}^2)
                % Parratt recursion:
                %   X_j = (r_{j,j+1} + X_{j+1} * phase) / (1 + r_{j,j+1} * X_{j+1} * phase)
                %   phase = exp(2i * kz_{j+1} * d_{j+1})

                Xj = 0;  % start at substrate (no layer below)
                for j = nL-1:-1:1
                    rj = (kz(j) - kz(j+1)) / (kz(j) + kz(j+1));
                    % Nevot-Croce roughness damping at interface j/j+1
                    rj = rj * exp(-2 * kz(j) * kz(j+1) * sig(j+1)^2);
                    % Phase factor for layer j+1
                    phase = exp(2i * kz(j+1) * thk(j+1));
                    Xj = (rj + Xj * phase) / (1 + rj * Xj * phase);
                end
                R(qi) = abs(Xj)^2;
            end
        end

        function doExportMLCSV()
            [fn, fp] = uiputfile({'*.csv','CSV (*.csv)'}, 'Export Layer Stack');
            if isequal(fn, 0), return; end
            fid = fopen(fullfile(fp, fn), 'w');
            if strcmp(densityMode, 'sld')
                fprintf(fid, 'Name,Formula,Thickness_Ang,SLD_e-6_inv_Ang2,Roughness_Ang\n');
            else
                fprintf(fid, 'Name,Formula,Thickness_Ang,Density_g_cm3,Roughness_Ang\n');
            end
            for li = 1:numel(mlStack)
                s = mlStack{li};
                fprintf(fid, '%s,%s,%.2f,%.4f,%.2f\n', s.name, s.formula, s.thickness, s.density, s.roughness);
            end
            fclose(fid);
            setStatus(sprintf('Exported stack to %s', fn));
        end

        registerPrimaryBtn('reflectivity', btnCalcSLD);
        appData.api.getMultilayerStack = @() mlStack;
        appData.api.getDensityMode = @() densityMode;
        appData.api.addLayer = @(name, formula, t, rho, sigma) apiAddLayer(name, formula, t, rho, sigma);
        function apiAddLayer(name, formula, t, rho, sigma)
            nL = numel(mlStack);
            newLayer = struct('name',name,'formula',formula,'thickness',t,'density',rho,'roughness',sigma);
            if nL >= 2
                mlStack = [mlStack(1:nL-1), {newLayer}, mlStack(nL)];
            else
                mlStack{end+1} = newLayer;
            end
            refreshMLTable(); updateMLProperties();
        end
    end

% ════════════════════════════════════════════════════════════════════════
% EXPORT REPORT & HISTORY ENHANCEMENTS
% ════════════════════════════════════════════════════════════════════════

    function exportReportToFile(outPath)
    %EXPORTREPORTTOFILE  Dump session history to formatted text file.
        fid = fopen(outPath, 'w');
        if fid == -1
            error('calc:exportReport:fileOpen', 'Cannot open %s for writing.', outPath);
        end
        fprintf(fid, '============================================================\n');
        fprintf(fid, 'Materials Calculator — Session Report\n');
        fprintf(fid, 'Date: %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        fprintf(fid, '============================================================\n\n');
        for hi = 1:numel(appData.history)
            entry = appData.history{hi};
            desc = regexprep(entry{3}, '<[^>]+>', '');  % strip HTML
            fprintf(fid, '[%s] [%s] %s\n', entry{1}, entry{2}, desc);
            if numel(entry) >= 5 && ~isempty(entry{5})
                fprintf(fid, '    MATLAB: %s\n', entry{5});
            end
        end
        fprintf(fid, '\n============================================================\n');
        fprintf(fid, 'Total calculations: %d\n', numel(appData.history));
        fclose(fid);
    end

% ════════════════════════════════════════════════════════════════════════
% HISTORY TAB
% ════════════════════════════════════════════════════════════════════════

    function buildHistoryTab(tab)
    %BUILDHISTORYTAB  Session history table with "Copy as MATLAB code" context menu.
    %
    % Columns: Time | Tab | Description | MATLAB Call
    % Right-click a row to copy the MATLAB function call to the clipboard.
    % If no MATLAB call was recorded for that entry, the action is disabled.

        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {28, '1x', 28};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        % Header
        lblHdr = uilabel(outerGL, ...
            'Text', 'Session history — right-click a row to copy it as a MATLAB function call.', ...
            'FontSize', 11, 'FontColor', [0.5 0.5 0.5], ...
            'WordWrap', 'on');
        lblHdr.Layout.Row = 1;

        % History table
        tblHistory = uitable(outerGL, ...
            'ColumnName',  {'Time', 'Tab', 'Description', 'MATLAB Call'}, ...
            'ColumnWidth', {60, 100, '1x', 200}, ...
            'RowName',     {}, ...
            'ColumnSortable', [false false false false], ...
            'Multiselect', 'off');
        tblHistory.Layout.Row = 2;

        % Context menu: "Copy as MATLAB code"
        cm = uicontextmenu(fig);
        miCopyCode = uimenu(cm, ...
            'Text',              'Copy as MATLAB code', ...
            'MenuSelectedFcn',   @onCopyMatlabCode);
        miCopySep  = uimenu(cm, ...
            'Text',              'Copy description', ...
            'MenuSelectedFcn',   @onCopyDescription, ...
            'Separator',         'off');
        tblHistory.ContextMenu = cm;

        % Clear button
        btnClear = uibutton(outerGL, 'push', 'Text', 'Clear History', ...
            'BackgroundColor', [0.7 0.2 0.2], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) onClearHistory());
        btnClear.Layout.Row = 3;

        % ── inner helpers ──────────────────────────────────────────────

        function refreshTable()
            n = numel(appData.history);
            if n == 0
                tblHistory.Data = {'','','',''};
                return;
            end
            d = cell(n, 4);
            for ri = 1:n
                e = appData.history{ri};
                % e = {timestamp, tabKey, description, latexStr, matlabCall}
                d{ri, 1} = e{1};
                d{ri, 2} = e{2};
                descPlain = regexprep(e{3}, '<[^>]+>', '');  % strip HTML
                d{ri, 3} = descPlain;
                if numel(e) >= 5
                    d{ri, 4} = e{5};
                else
                    d{ri, 4} = '';
                end
            end
            tblHistory.Data = d;
            % Scroll to bottom so newest entry is visible
            scroll(tblHistory, 'bottom');
        end

        function onCopyMatlabCode(~, ~)
            % Determine selected row — DisplaySelectionIndicator is not
            % available on all platforms, so fall back to UserData trick.
            row = getSelectedRow();
            if row < 1 || row > numel(appData.history), return; end
            e = appData.history{row};
            if numel(e) >= 5 && ~isempty(e{5})
                clipboard('copy', e{5});
                setStatus(['Copied MATLAB code for row ' num2str(row)]);
            else
                setStatus('No MATLAB call recorded for this entry');
            end
        end

        function onCopyDescription(~, ~)
            row = getSelectedRow();
            if row < 1 || row > numel(appData.history), return; end
            e = appData.history{row};
            desc = regexprep(e{3}, '<[^>]+>', '');
            clipboard('copy', desc);
            setStatus(['Copied description for row ' num2str(row)]);
        end

        function row = getSelectedRow()
            % uitable Selection returns [row, col] indices of selected cells.
            sel = tblHistory.Selection;
            if isempty(sel)
                row = 0;
            else
                row = sel(1, 1);
            end
        end

        function onClearHistory()
            appData.history = {};
            refreshTable();
            setStatus('History cleared');
        end

        % Register API hooks used by addHistory callback and headless tests
        appData.api.refreshHistoryTable = @() refreshTable();

        appData.api.copyHistoryRowAsMatlabCode = @(row) copyRowByIndex(row);
        function result = copyRowByIndex(row)
            result = '';
            if row < 1 || row > numel(appData.history), return; end
            e = appData.history{row};
            if numel(e) >= 5 && ~isempty(e{5})
                result = e{5};
                clipboard('copy', result);
                setStatus(['Copied MATLAB code for row ' num2str(row)]);
            else
                setStatus('No MATLAB call recorded for this entry');
            end
        end

        appData.api.getHistoryMatlabCall = @(row) getMatlabCallByIndex(row);
        function call = getMatlabCallByIndex(row)
            call = '';
            if row < 1 || row > numel(appData.history), return; end
            e = appData.history{row};
            if numel(e) >= 5
                call = e{5};
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% FAVORITES TAB
% ════════════════════════════════════════════════════════════════════════

    function buildFavoritesTab(tab)
        outerGL = uigridlayout(tab);
        outerGL.RowHeight   = {28, '1x'};
        outerGL.ColumnWidth = {'1x'};
        outerGL.Padding     = [6 6 6 6];

        % Header row with instructions
        lblFavHeader = uilabel(outerGL, ...
            'Text', 'Pin calculations from any tab using the history log. Pinned items appear here for quick access.', ...
            'FontSize', 11, 'FontColor', [0.5 0.5 0.5], ...
            'WordWrap', 'on');
        lblFavHeader.Layout.Row = 1;

        % Favorites list + detail panel
        favGL = uigridlayout(outerGL, [1 2]);
        favGL.ColumnWidth = {'1x', '1x'};
        favGL.Layout.Row = 2;

        % Left: pinned favorites list
        leftGL = uigridlayout(favGL, [2 1]);
        leftGL.RowHeight = {'1x', 30};
        leftGL.Layout.Column = 1;

        lbFavorites = uilistbox(leftGL, ...
            'Items', {'(no favorites pinned)'}, ...
            'ItemsData', 0, ...
            'ValueChangedFcn', @(~,~) onFavSelected());
        lbFavorites.Layout.Row = 1;

        btnRemFav = uibutton(leftGL, 'push', 'Text', 'Remove Selected', ...
            'BackgroundColor', [0.7 0.2 0.2], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) removeFavorite());
        btnRemFav.Layout.Row = 2;

        % Right: detail display
        taFavDetail = uitextarea(favGL, ...
            'Value', {'Select a favorite to see details.'}, ...
            'Editable', 'off', ...
            'FontName', 'Courier New', ...
            'FontSize', 11);
        taFavDetail.Layout.Column = 2;

        function onFavSelected()
            idx = lbFavorites.Value;
            if isempty(idx) || idx == 0, return; end
            if idx > numel(appData.favorites), return; end
            fav = appData.favorites{idx};
            taFavDetail.Value = { ...
                sprintf('Name: %s', fav.name), ...
                sprintf('Tab:  %s', fav.tab), ...
                '', ...
                'Last result:', ...
                fav.lastResult, ...
                '', ...
                'LaTeX:', ...
                fav.lastLatex};
        end

        function removeFavorite()
            idx = lbFavorites.Value;
            if isempty(idx) || idx == 0, return; end
            if idx > numel(appData.favorites), return; end
            appData.favorites(idx) = [];
            refreshFavoritesList();
        end

        function refreshFavoritesList()
            if isempty(appData.favorites)
                lbFavorites.Items = {'(no favorites pinned)'};
                lbFavorites.ItemsData = 0;
                return;
            end
            items = cell(1, numel(appData.favorites));
            idata = zeros(1, numel(appData.favorites));
            for fi2 = 1:numel(appData.favorites)
                fav = appData.favorites{fi2};
                items{fi2} = sprintf('[%s] %s', fav.tab, fav.name);
                idata(fi2) = fi2;
            end
            lbFavorites.Items = items;
            lbFavorites.ItemsData = idata;
        end

        % Public refresh hook (called by addFavorite)
        appData.api.refreshFavorites = @() refreshFavoritesList();
        appData.api.addFavorite = @(name, tabName, result, latex) doAddFavorite(name, tabName, result, latex);
        appData.api.addFavoriteInternal = @(name, tabName, result, latex) doAddFavorite(name, tabName, result, latex);
        appData.api.getFavorites = @() appData.favorites;

        function doAddFavorite(name, tabName, result, latex)
            % Check if already pinned (update instead)
            for fi2 = 1:numel(appData.favorites)
                if strcmp(appData.favorites{fi2}.name, name) && ...
                        strcmp(appData.favorites{fi2}.tab, tabName)
                    appData.favorites{fi2}.lastResult = result;
                    appData.favorites{fi2}.lastLatex = latex;
                    refreshFavoritesList();
                    return;
                end
            end
            fav.name       = name;
            fav.tab        = tabName;
            fav.lastResult = result;
            fav.lastLatex  = latex;
            appData.favorites{end+1} = fav;
            refreshFavoritesList();
        end
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


function cmap = viridisMap(n)
%VIRIDISMAP  Perceptually uniform colormap (viridis) without toolbox.
%   Returns an [n x 3] matrix interpolated from anchor colors.
anchors = [ ...
    0.267 0.004 0.329;  % dark purple
    0.283 0.141 0.458;  % purple
    0.254 0.265 0.530;  % blue-purple
    0.164 0.471 0.558;  % teal
    0.128 0.567 0.551;  % green-teal
    0.134 0.658 0.517;  % green
    0.477 0.821 0.318;  % lime
    0.741 0.873 0.150;  % yellow-green
    0.993 0.906 0.144;  % yellow
];
t = linspace(0, 1, size(anchors,1));
ti = linspace(0, 1, n);
cmap = interp1(t, anchors, ti, 'pchip');
cmap = max(0, min(1, cmap));
end


function sys = inferCrystalSystem(a, b, c, alpha, beta, gamma)
%INFERCRYSTALSYSTEM  Determine crystal system from lattice parameters.
    tol = 0.01;  % tolerance for float comparison
    eq = @(x, y) abs(x - y) < tol;
    if eq(a,b) && eq(b,c) && eq(alpha,90) && eq(beta,90) && eq(gamma,90)
        sys = 'Cubic';
    elseif eq(a,b) && eq(alpha,90) && eq(beta,90) && eq(gamma,120)
        sys = 'Hexagonal';
    elseif eq(a,b) && eq(b,c) && eq(alpha,beta) && eq(beta,gamma) && ~eq(alpha,90)
        sys = 'Trigonal';
    elseif eq(a,b) && eq(alpha,90) && eq(beta,90) && eq(gamma,90)
        sys = 'Tetragonal';
    elseif eq(alpha,90) && eq(beta,90) && eq(gamma,90)
        sys = 'Orthorhombic';
    elseif eq(alpha,90) && eq(gamma,90)
        sys = 'Monoclinic';
    else
        sys = 'Triclinic';
    end
end

% ════════════════════════════════════════════════════════════════════════
% UTILITY: Apply dark theme to all input widgets in a container tree
% ════════════════════════════════════════════════════════════════════════

function applyDarkInputTheme(parent, bg, fg)
%APPLYDARKINPUTTHEME  Recursively style edit fields, dropdowns, and textareas.
    children = findall(parent, 'Type', 'uieditfield');
    for i = 1:numel(children)
        children(i).BackgroundColor = bg;
        children(i).FontColor = fg;
    end
    children = findall(parent, 'Type', 'uinumericeditfield');
    for i = 1:numel(children)
        children(i).BackgroundColor = bg;
        children(i).FontColor = fg;
    end
    children = findall(parent, 'Type', 'uidropdown');
    for i = 1:numel(children)
        children(i).BackgroundColor = bg;
        children(i).FontColor = fg;
    end
    children = findall(parent, 'Type', 'uitextarea');
    for i = 1:numel(children)
        children(i).BackgroundColor = bg;
        children(i).FontColor = fg;
    end
    children = findall(parent, 'Type', 'uilistbox');
    for i = 1:numel(children)
        children(i).BackgroundColor = bg;
        children(i).FontColor = fg;
    end
end

% ════════════════════════════════════════════════════════════════════════
% UTILITY: Apply dark background and text colour to panels and labels
% ════════════════════════════════════════════════════════════════════════

function applyDarkPanelTheme(parent, bg, fg)
%APPLYDARKPANELTHEME  Set dark background on uipanels and font colour on labels.
    % uipanel backgrounds
    children = findall(parent, 'Type', 'uipanel');
    for i = 1:numel(children)
        try
            children(i).BackgroundColor = bg;
        catch
        end
    end
    % Label foreground colours
    children = findall(parent, 'Type', 'uilabel');
    for i = 1:numel(children)
        try
            children(i).FontColor = fg;
        catch
        end
    end
    % Checkbox text colour
    children = findall(parent, 'Type', 'uicheckbox');
    for i = 1:numel(children)
        try
            children(i).FontColor = fg;
        catch
        end
    end
    % Radio button text colour
    children = findall(parent, 'Type', 'uiradiobutton');
    for i = 1:numel(children)
        try
            children(i).FontColor = fg;
        catch
        end
    end
end
