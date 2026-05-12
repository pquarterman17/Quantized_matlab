function removeDataset(appData, fig, ax, ui, headless, callbacks)
%REMOVEDATASET  Remove selected dataset(s) from the list.
%
% Syntax
%   bosonPlotter.removeDataset(appData, fig, ax, ui, headless, callbacks)
%
% Behaviour
%   Uses ui.lbDatasets.Value (numeric ItemsData) to identify indices.
%   Prompts a uiconfirm when removing >1 dataset (skipped in headless).
%   Sorts descending so removal order doesn't invalidate later indices.
%   Keeps appData.datasets and appData.model in 1:1 correspondence; warns
%   loudly (does not skip removal) if they drift out of sync.
%   When the last dataset is removed, resets all control widgets and axes.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, activeIdx, model)
%   fig       - Main BosonPlotter figure handle
%   ax        - Main plot axes (cleared when all datasets gone)
%   ui        - Struct with widget handles: lbDatasets, ctrlPanel, ddX, lbY,
%               efXOffset, efYOffset, efBGSlope, efBGIntercept, efSavePath,
%               analysisPanel, ddDatasetColor, efLegendName
%   headless  - Logical scalar; skip uiconfirm when true
%   callbacks - Struct of function handles:
%                 .cancelInteractions()
%                 .rebuildDatasetList(keepActive)
%                 .updateControlsForActiveDataset()
%                 .onPlot()

    if isempty(appData.datasets) || isempty(ui.lbDatasets.Value), return; end

    callbacks.cancelInteractions();

    % lbDatasets.ItemsData contains numeric indices, so Value returns
    % the selected indices directly (not display strings).
    sel = ui.lbDatasets.Value;
    if iscell(sel)
        indicesToRemove = [sel{:}];
    else
        indicesToRemove = sel;
    end

    % Filter out invalid indices (e.g. the placeholder 0)
    indicesToRemove(indicesToRemove < 1 | indicesToRemove > numel(appData.datasets)) = [];
    if isempty(indicesToRemove), return; end

    % Confirm when removing multiple datasets, or when a single dataset
    % has corrections/peaks/smoothing that would be lost.
    needConfirm = numel(indicesToRemove) > 1;
    if ~needConfirm && numel(indicesToRemove) == 1
        ds = appData.datasets{indicesToRemove};
        hasPeaks = isfield(ds, 'peaks') && ~isempty(ds.peaks);
        hasCorr  = (isfield(ds,'bgSlope') && ds.bgSlope ~= 0) || ...
                   (isfield(ds,'bgInt')   && ds.bgInt   ~= 0) || ...
                   (isfield(ds,'bgPoly')  && ~isempty(ds.bgPoly)) || ...
                   (isfield(ds,'xOff')    && ds.xOff    ~= 0) || ...
                   (isfield(ds,'smoothEnabled') && ds.smoothEnabled) || ...
                   (isfield(ds,'normMethod') && ~strcmp(ds.normMethod, 'None'));
        needConfirm = hasPeaks || hasCorr;
    end
    if needConfirm && ~headless
        if numel(indicesToRemove) > 1
            msg = sprintf('Remove %d selected datasets?', numel(indicesToRemove));
        else
            msg = 'This dataset has corrections or peaks applied. Remove anyway?';
        end
        answer = uiconfirm(fig, msg, 'Confirm Remove', ...
            'Options', {'Remove', 'Cancel'}, ...
            'DefaultOption', 'Remove', 'CancelOption', 'Cancel');
        if strcmp(answer, 'Cancel'), return; end
    end

    % Sort indices in descending order so removal doesn't affect remaining indices
    indicesToRemove = sort(indicesToRemove, 'descend');

    % Remove selected datasets (also from shared model). appData.model
    % and appData.datasets must stay in 1:1 correspondence — if an
    % earlier silent-catch model.updateDataset failure left them out
    % of sync we would permanently corrupt the index mapping by
    % skipping model removals. Warn loudly instead so the divergence
    % is visible, then remove unconditionally.
    if appData.model.count() ~= numel(appData.datasets)
        warning('BosonPlotter:modelDesync', ...
            ['WorkspaceModel has %d datasets but appData.datasets has %d — ' ...
             'they drifted out of sync (silent updateDataset catch?). ' ...
             'Removing unconditionally and hoping for the best.'], ...
            appData.model.count(), numel(appData.datasets));
    end
    for ri = 1:numel(indicesToRemove)
        idx = indicesToRemove(ri);
        if idx <= appData.model.count()
            appData.model.removeDataset(idx);
        end
    end
    appData.datasets(indicesToRemove) = [];

    % Sweep stale overlay graphics + state (fringe markers, peak
    % annotations, masks, cursors, etc).  cla() on the empty-datasets
    % branch below does not touch HandleVisibility='off' overlays, so
    % fringe labels would otherwise linger after the last dataset is
    % removed.  Partial removes also scrub overlays that may reference
    % data points belonging to the removed dataset.
    bosonPlotter.clearOverlays(appData, ax);

    if isempty(appData.datasets)
        appData.activeIdx = 0;
        ui.lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
        ui.lbDatasets.ItemsData = {0};
        ui.lbDatasets.Value     = {0};
        % Reset all controls to blank state
        ui.ctrlPanel.Title = 'Controls';
        ui.ddX.Items = {'(load file first)'};  ui.ddX.Value = ui.ddX.Items{1};
        ui.lbY.Items = {'(load file first)'};  ui.lbY.Value = ui.lbY.Items(1);
        ui.efXOffset.Value = 0;  ui.efYOffset.Value = 0;
        ui.efBGSlope.Value = 0;  ui.efBGIntercept.Value = 0;
        ui.efSavePath.Value = '';
        ui.analysisPanel.Title = 'Analysis & Corrections';
        ui.ddDatasetColor.Enable = 'off';
        ui.ddDatasetColor.Value  = [];
        ui.efLegendName.Enable   = 'off';
        ui.efLegendName.Value    = '';
        cla(ax);
        ax.XLim = [0 1];  ax.YLim = [0 1];
        ax.XLimMode = 'auto';  ax.YLimMode = 'auto';
        title(ax,'Load a file to preview data','Interpreter','none');
    else
        appData.activeIdx = min(appData.activeIdx, numel(appData.datasets));
        callbacks.rebuildDatasetList(true);
        callbacks.updateControlsForActiveDataset();
        callbacks.onPlot();
    end
end
