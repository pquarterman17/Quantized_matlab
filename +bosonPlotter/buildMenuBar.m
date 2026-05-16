function buildMenuBar(fig, cb)
%BUILDMENUBAR  Construct the BosonPlotter top-level menu bar.
%
% Syntax
%   bosonPlotter.buildMenuBar(fig, cb)
%
% Inputs
%   fig — uifigure that should host the menu bar
%   cb  — struct of nested-function handles from BosonPlotter.m. Every
%         field used here must be a valid callable handle. Missing
%         optional fields are tolerated (the corresponding menu item is
%         omitted) so the same builder works against future BosonPlotter
%         versions that may rename a callback.
%
% Notes
%   This builder is a pure function — no closures, no appData reads. All
%   state lives behind the `cb` handles. Adding a menu item is one line:
%       addItem(menu, 'Label...', cb.onFoo);                   % plain
%       addItem(menu, 'Label...', cb.onFoo, 'Accelerator','O'); % Ctrl+O
%       addItem(menu, 'Label...', cb.onFoo, 'Separator',true);  % horizontal rule above
%   Items are skipped silently if the corresponding cb field is missing
%   or not a function handle so the same builder can target a stripped-
%   down BosonPlotter (e.g. a future plugin) without throwing.
%
%   Mirrors the existing context menus on the dataset list (cmDatasets)
%   and the preview axes (cmAxes). The menu bar is the discoverability
%   layer — power users keep using right-click for the same actions.

    % ── &File ──────────────────────────────────────────────────────────
    fileMenu = uimenu(fig, 'Text', '&File');
    addItem(fileMenu, 'Add File(s)...',          cb.onAddFiles,            'Accelerator','O');
    addItem(fileMenu, 'Batch Import...',         cb.onBatchImportDir);
    addItem(fileMenu, 'Batch Convert XRD...',    cb.onBatchConvertXRD);
    addItem(fileMenu, 'Save Session...',         cb.onSaveSession,         'Accelerator','S', 'Separator',true);
    addItem(fileMenu, 'Load Session...',         cb.onLoadSession);
    addItem(fileMenu, 'Settings...',             cb.onOpenSettings,        'Separator',true);
    addItem(fileMenu, 'Layout Settings...',      cb.onOpenLayoutSettings);
    addItem(fileMenu, 'Close',                   @(~,~) close(fig),        'Accelerator','W', 'Separator',true);

    % ── &Edit ──────────────────────────────────────────────────────────
    editMenu = uimenu(fig, 'Text', '&Edit');
    addItem(editMenu, 'Undo Corrections',         cb.onUndoCorrections,    'Accelerator','Z');
    addItem(editMenu, 'Reset Corrections',        cb.onResetCorrections);
    addItem(editMenu, 'Apply to All',             cb.onApplyCorrectionsAll);
    addItem(editMenu, 'Mask Selection',           cb.onArmMaskSelection,   'Separator',true);
    addItem(editMenu, 'Unmask All',               cb.onUnmaskAll);
    addItem(editMenu, 'Edit Axis Labels...',      cb.onEditAxisLabelsMenu, 'Separator',true);
    addItem(editMenu, 'Edit Legend...',           cb.onOpenLegendEditor);
    addItem(editMenu, 'Edit Column Mapping...',   cb.onEditColumnMapping);

    % ── &View ──────────────────────────────────────────────────────────
    viewMenu = uimenu(fig, 'Text', '&View');
    addItem(viewMenu, 'Auto-Scale Axes',          cb.onSmartScale);
    addItem(viewMenu, 'Reset Axis Limits',        cb.onAutoLimits);
    addItem(viewMenu, 'Toggle Data Cursor',       cb.onToggleDataCursor);
    addItem(viewMenu, 'Toggle Waterfall',         cb.onWaterfallToggled);
    addItem(viewMenu, 'Add Horizontal Reference Line', cb.onAddHRefLine,   'Separator',true);
    addItem(viewMenu, 'Add Vertical Reference Line',   cb.onAddVRefLine);
    addItem(viewMenu, 'Clear Reference Lines',    cb.onClearRefLines);
    addItem(viewMenu, 'Clear Fit Overlays',       cb.onClearFitOverlays);
    addItem(viewMenu, 'Add Inset...',             cb.onCreateInsetFromMenu, 'Separator',true);
    addItem(viewMenu, 'Remove Inset',             cb.onRemoveInset);
    addItem(viewMenu, 'Customise Toolbar...',     cb.onCustomiseToolbar,   'Separator',true);
    addItem(viewMenu, 'Refresh / Re-plot',        cb.onPlot);

    % ── &Data ──────────────────────────────────────────────────────────
    dataMenu = uimenu(fig, 'Text', '&Data');
    addItem(dataMenu, 'Save CSV',                 cb.onSaveCSV,            'Accelerator','E');
    addItem(dataMenu, 'Batch Export CSVs...',     cb.onBatchExportCSV);
    addItem(dataMenu, 'Export to HDF5...',        cb.onExportHDF5);
    addItem(dataMenu, 'Copy Data to Clipboard',   cb.onCopyDataToClipboard);
    addItem(dataMenu, 'Send to Origin',           cb.onSendToOrigin,       'Separator',true);
    addItem(dataMenu, 'Export Origin Script',     cb.onExportOriginScript);
    addItem(dataMenu, 'Convert Units...',         cb.onConvertUnits,       'Separator',true);
    addItem(dataMenu, 'Resample Dataset...',      cb.onResampleDataset);
    addItem(dataMenu, 'Column Calculator...',     cb.onColumnCalculator);
    addItem(dataMenu, 'Dataset Math...',          cb.onDatasetMath);
    addItem(dataMenu, 'Dataset Algebra...',       cb.onDatasetAlgebra);
    addItem(dataMenu, 'Merge Selected',           cb.onMergeDatasets);

    % ── &Analysis ──────────────────────────────────────────────────────
    analysisMenu = uimenu(fig, 'Text', '&Analysis');
    addItem(analysisMenu, 'Peak Analysis...',     cb.showPeakWindow);
    addItem(analysisMenu, 'Estimate Baseline',    cb.onEstimateBaseline);
    addItem(analysisMenu, 'Fit BG from Box',      cb.onFitBGRegion);
    addItem(analysisMenu, 'Apply Corrections',    cb.onApplyCorrections);
    addItem(analysisMenu, 'Williamson-Hall Plot', cb.onWilliamsonHallPlot, 'Separator',true);
    addItem(analysisMenu, 'Reflectivity FFT',     cb.onReflectivityFFT);
    addItem(analysisMenu, 'FFT Thickness',        cb.onFFTThickness);
    addItem(analysisMenu, 'Refine Lattice',       cb.onRefineLattice);
    addItem(analysisMenu, 'Match Phases',         cb.onMatchPhases);
    addItem(analysisMenu, 'Pole Figure',          cb.onPoleFigure,         'Separator',true);
    addItem(analysisMenu, 'Decompose RSM',        cb.onDecomposeRSM);
    addItem(analysisMenu, 'Asymmetry...',         cb.onAdvAsymmetry);
    addItem(analysisMenu, 'Advanced Tools...',    cb.onShowAdvancedMenu,   'Separator',true);

    % ── &Tools ─────────────────────────────────────────────────────────
    toolsMenu = uimenu(fig, 'Text', '&Tools');
    addItem(toolsMenu, 'Figure Properties...',    cb.onFigureProperties);
    addItem(toolsMenu, 'Quick Export...',         cb.onQuickExport);
    addItem(toolsMenu, 'Copy for Slides',         cb.onCopyForSlides,       'Accelerator','P');
    addItem(toolsMenu, 'Plot Templates...',       cb.onPlotTemplates,       'Separator',true);
    addItem(toolsMenu, 'Plot Style...',           cb.onOpenPlotStyleDialog);
    addItem(toolsMenu, 'Advanced Figure Builder...', cb.onAdvancedFigureBuilder);
    addItem(toolsMenu, 'Compose Figure...',       cb.onComposeFigure);
    addItem(toolsMenu, 'Batch Figure Export...',  cb.onBatchFigureExport);
    addItem(toolsMenu, 'Polar Plot...',           cb.onPolarPlot);
    addItem(toolsMenu, 'Macro Record (toggle)',   cb.onToggleMacroRecord,  'Separator',true);
    addItem(toolsMenu, 'Export Macro Script',     cb.onExportMacro);
    addItem(toolsMenu, 'Watch File (toggle)',     cb.onToggleWatchFile,    'Separator',true);
    addItem(toolsMenu, 'Toggle Single-Precision', cb.onToggleSinglePrecision);

    % ── &Help ──────────────────────────────────────────────────────────
    helpMenu = uimenu(fig, 'Text', '&Help');
    addItem(helpMenu, 'Keyboard Shortcuts',       cb.onShowShortcuts);
    addItem(helpMenu, 'Report a Bug...',          cb.onReportBug);
end

% ────────────────────────────────────────────────────────────────────────
function addItem(parent, label, callback, varargin)
%ADDITEM  Add a uimenu entry under `parent`.
%   Optional name/value pairs forwarded to uimenu (e.g. 'Accelerator','S'
%   or 'Separator', true). Returns silently if `callback` is missing or
%   not a function handle so the same builder targets stripped builds.
    if isempty(callback) || ~isa(callback, 'function_handle')
        return;
    end
    % MenuSelectedFcn always invokes the callback as f(src, event), but
    % some target nested functions (e.g. onOpenSettings) are declared
    % with zero arguments. Adapt automatically based on nargin so both
    % shapes work without each caller having to wrap with @(~,~) ...
    try
        if nargin(callback) == 0
            wrapped = @(~,~) callback();
        else
            wrapped = callback;
        end
    catch
        wrapped = callback;  % anonymous handles — nargin can throw
    end
    args = {parent, 'Text', label, 'MenuSelectedFcn', wrapped};
    if ~isempty(varargin)
        % MATLAB's Separator wants 'on'/'off' string, not logical
        for k = 1:2:numel(varargin)
            if strcmpi(varargin{k}, 'Separator') && islogical(varargin{k+1})
                varargin{k+1} = ternary(varargin{k+1}, 'on', 'off');
            end
        end
        args = [args, varargin];
    end
    uimenu(args{:});
end

function out = ternary(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
