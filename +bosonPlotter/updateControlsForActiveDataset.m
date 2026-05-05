function updateControlsForActiveDataset(appData, ui, callbacks)
%UPDATECONTROLSFORACTIVEDATASET  Sync all GUI controls to the active dataset.
%
% Syntax
%   bosonPlotter.updateControlsForActiveDataset(appData, ui, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (read only — may update datasets for 2D)
%   ui        - Widget handle struct built in BosonPlotter initialisation
%   callbacks - Struct of function handles:
%                 .applyParserAnalysisConfig(pName)
%                 .resolvedCorrStyle()
%                 .onPlot()
%                 .onAxisChanged(src,evt)
%                 .guiXName(metadata)
%                 .guiCountingTime(ds)
%                 .guiParserLabel(parserName)
%                 .guiTernary(cond, ifTrue, ifFalse)
%                 .ensureCell(v)
%                 .nan2str(v)
%                 .is2DDataset(ds)
%                 .isNeutronParser(name)
%                 .neutronBaseName(filepath)
%                 .extractWavelength_A(ds)
%                 .refreshPeakTable()
%                 .refreshDataTable()
%                 .toggleY2Appearance(tf)
%                 .computeQSpace(map)

    if appData.activeIdx < 1 || isempty(appData.datasets), return; end
    ds = appData.datasets{appData.activeIdx};
    d  = ds.data;

    % Suppress value-change callbacks during bulk update
    ui.ddX.ValueChangedFcn  = [];
    ui.lbY.ValueChangedFcn  = [];
    ui.lbY2.ValueChangedFcn = [];

    ui.ctrlPanel.Title = sprintf('Controls  —  %s', callbacks.guiParserLabel(ds.parserName));

    % X dropdown: rebuild items; try to preserve the current selection
    xName     = callbacks.guiXName(d.metadata);
    allLabels = [{xName}, d.labels];
    ui.ddX.Items = allLabels;
    if ~ismember(ui.ddX.Value, allLabels)
        ui.ddX.Value = allLabels{1};
    end

    % Y listbox: rebuild; keep any channels that exist in this dataset
    ui.lbY.Items = d.labels;
    if ~isempty(d.labels)
        curSel = callbacks.ensureCell(ui.lbY.Value);
        validSel = curSel(ismember(curSel, d.labels));
        if isempty(validSel)
            ui.lbY.Value = d.labels(1);
        else
            ui.lbY.Value = validSel;
        end
    end

    % Y2 listbox: rebuild; keep valid selections (or reset to "(none)")
    ui.lbY2.Items = [{'(none)'}, d.labels];
    curSel2   = callbacks.ensureCell(ui.lbY2.Value);
    validSel2 = curSel2(ismember(curSel2, [{'(none)'}, d.labels]));
    if isempty(validSel2)
        ui.lbY2.Value = {'(none)'};
    else
        ui.lbY2.Value = validSel2;
    end

    % Enable Counts/s only for Rigaku files with a valid counting time
    ct = callbacks.guiCountingTime(ds);
    ui.cbCountsPerSec.Enable = callbacks.guiTernary(ct > 0, 'on', 'off');
    if ct == 0
        ui.cbCountsPerSec.Value = false;
    end

    % Restore this dataset's per-dataset appearance overrides
    ui.ddDatasetColor.Enable  = 'on';
    ui.ddDatasetColor.Value   = ds.color;
    ui.ddDatasetColorR.Enable = 'on';
    ui.ddDatasetColorR.Value  = callbacks.guiTernary(isfield(ds,'colorR'),     ds.colorR,     []);
    ui.efLegendName.Enable    = 'on';
    ui.efLegendName.Value     = callbacks.guiTernary(isfield(ds,'legendName'),  ds.legendName,  '');
    ui.efLegendNameR.Enable   = 'on';
    ui.efLegendNameR.Value    = callbacks.guiTernary(isfield(ds,'legendNameR'), ds.legendNameR, '');

    % Restore this dataset's correction parameter values
    ui.efXOffset.Value      = ds.xOff;
    ui.efYOffset.Value      = ds.yOff;
    ui.efBGSlope.Value      = ds.bgSlope;
    ui.efBGIntercept.Value  = ds.bgInt;
    % Restore BG polynomial order dropdown
    if isfield(ds,'bgPoly') && numel(ds.bgPoly) > 2
        bgPolyOrd = numel(ds.bgPoly) - 1;   % poly order = nCoeffs - 1
        if bgPolyOrd >= 2 && bgPolyOrd <= 6
            ui.ddBGOrder.Value = sprintf('Poly %d', bgPolyOrd);
        end
    else
        ui.ddBGOrder.Value = 'Linear';
    end
    ui.cbSmooth.Value       = callbacks.guiTernary(isfield(ds,'smoothEnabled'), ds.smoothEnabled, false);
    ui.efSmoothWin.Value    = callbacks.guiTernary(isfield(ds,'smoothWindow'),  ds.smoothWindow,  5);
    ui.ddSmoothMethod.Value = callbacks.guiTernary(isfield(ds,'smoothMethod'),  ds.smoothMethod,  'Moving');
    ui.efXTrimMin.Value     = callbacks.nan2str(callbacks.guiTernary(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN));
    ui.efXTrimMax.Value     = callbacks.nan2str(callbacks.guiTernary(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN));
    ui.ddNormalize.Value    = callbacks.guiTernary(isfield(ds,'normMethod'),    ds.normMethod,    'None');
    ui.ddDerivative.Value   = callbacks.guiTernary(isfield(ds,'derivativeMode'), ds.derivativeMode, 'None');

    % Restore magnetometry sample parameters
    ui.efSampleMass.Value   = callbacks.guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
    ui.efSampleWidth.Value  = callbacks.guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
    ui.efSampleHeight.Value = callbacks.guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
    ui.ddDimUnit.Value      = callbacks.guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
    ui.efSampleThick.Value  = callbacks.guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
    ui.ddThickUnit.Value    = callbacks.guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
    ui.ddMomentUnit.Value   = callbacks.guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu');
    ui.ddFieldUnit.Value    = callbacks.guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe');
    ui.ddUnitSystem.Value   = callbacks.guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');

    % Restore wavelength override field; auto-fill from metadata if no override set
    wl_meta = callbacks.extractWavelength_A(ds);
    if isfield(ds,'wavelengthOverride_A') && ~isnan(ds.wavelengthOverride_A) && ds.wavelengthOverride_A > 0
        ui.efWavelength.Value = ds.wavelengthOverride_A;
    elseif ~isnan(wl_meta) && wl_meta > 0
        ui.efWavelength.Value = wl_meta;
    else
        ui.efWavelength.Value = 0;
    end

    % Restore per-dataset axis limits (auto-scale if not yet saved)
    if isfield(ds, 'axLims')
        ui.efXMin.Value  = ds.axLims.xMin;
        ui.efXMax.Value  = ds.axLims.xMax;
        ui.efXStep.Value = ds.axLims.xStep;
        ui.efYMin.Value  = ds.axLims.yMin;
        ui.efYMax.Value  = ds.axLims.yMax;
        ui.efYStep.Value = ds.axLims.yStep;
        ui.efY2Min.Value  = callbacks.guiTernary(isfield(ds.axLims,'y2Min'), ds.axLims.y2Min, '');
        ui.efY2Max.Value  = callbacks.guiTernary(isfield(ds.axLims,'y2Max'), ds.axLims.y2Max, '');
        ui.efY2Step.Value = callbacks.guiTernary(isfield(ds.axLims,'y2Step'), ds.axLims.y2Step, '');
    else
        ui.efXMin.Value = '';  ui.efXMax.Value = '';  ui.efXStep.Value = '';
        ui.efYMin.Value = '';  ui.efYMax.Value = '';  ui.efYStep.Value = '';
        ui.efY2Min.Value = '';  ui.efY2Max.Value = '';  ui.efY2Step.Value = '';
    end

    % Show Y2 rows/columns only when a right-axis channel is active
    y2Active = ~all(strcmp(callbacks.ensureCell(ui.lbY2.Value), '(none)'));
    ui.limGL.RowHeight{3}  = 26 * y2Active;
    callbacks.toggleY2Appearance(y2Active);

    [fp2, fn2, ~] = fileparts(ds.filepath);
    if ~isempty(ds.corrData)
        ui.efSavePath.Value = fullfile(fp2, [fn2, '_corrected.csv']);
    elseif isfield(ds, 'parserName') && callbacks.isNeutronParser(ds.parserName)
        ui.efSavePath.Value = fullfile(fp2, [callbacks.neutronBaseName(ds.filepath), '_neutron.csv']);
    else
        ui.efSavePath.Value = fullfile(fp2, [fn2, '_export.csv']);
    end

    callbacks.applyParserAnalysisConfig(callbacks.resolvedCorrStyle());

    % Pull the per-dataset plot-state struct (may be empty for legacy
    % sessions loaded from disk before this field existed).
    hasPS = isfield(ds, 'plotState') && isstruct(ds.plotState);
    ps    = callbacks.guiTernary(hasPS, ds.plotState, struct());

    % Parser-aware Y-scale default — used only when the user has not
    % explicitly chosen a scale for this dataset (ps.yScale is '').
    hasRCol      = any(strcmp(d.labels, 'R'));
    hasTheoryCol = any(strcmpi(d.labels, 'theory'));
    if callbacks.isNeutronParser(ds.parserName) || (hasRCol && hasTheoryCol)
        rIdx = find(strcmp(d.labels, 'R'), 1);
        if ~isempty(rIdx)
            ui.lbY.Value = d.labels(rIdx);
        end
        defaultYScale = 'Log';
    elseif isfield(ds, 'parserName') && strcmp(ds.parserName, 'importSIMS')
        % Auto-select all elements so each gets its own legend entry
        if numel(d.labels) > 1
            ui.lbY.Value = d.labels;
        end
        defaultYScale = 'Log';  % SIMS concentrations span many decades
    elseif callbacks.is2DDataset(ds)
        % Lazy Q-space: compute Qx/Qz on first activation if wavelength available
        map = ds.data.metadata.parserSpecific.map2D;
        map = callbacks.computeQSpace(map);
        ds.data.metadata.parserSpecific.map2D = map;
        appData.datasets{appData.activeIdx} = ds;
        % Update map dimension info label
        ui.lblMap2DInfo.Text = sprintf('%d %s positions  \xD7  %d 2\xB0 pixels', ...
            numel(map.axis1), map.axis1Name, numel(map.axis2));
        % Enable Q-space toggle and arc integration only when wavelength was available
        if isfield(map, 'Qx')
            ui.cbMap2DQSpace.Enable  = 'on';
            ui.btnArcIntegrate.Enable = 'on';
        else
            ui.cbMap2DQSpace.Enable  = 'off';
            ui.cbMap2DQSpace.Value   = false;
            ui.btnArcIntegrate.Enable = 'off';
        end
        defaultYScale = 'Log';  % log intensity standard for reciprocal-space maps
    else
        defaultYScale = 'Linear';
    end

    % Apply user-specified plot state, else fall back to parser default.
    ui.ddScaleY.Value  = psGet(ps, 'yScale',  defaultYScale);
    ui.ddScaleX.Value  = psGet(ps, 'xScale',  'Linear');
    ui.ddScaleY2.Value = psGet(ps, 'y2Scale', 'Linear');

    % 2D map dropdowns — only meaningful for 2D datasets, but setting the
    % value for 1D datasets is harmless (panel is hidden).
    if isfield(ui, 'ddMap2DCmap') && ~isempty(ui.ddMap2DCmap) && isvalid(ui.ddMap2DCmap)
        ui.ddMap2DCmap.Value  = psGet(ps, 'map2DCmap',  ui.ddMap2DCmap.Value);
        ui.ddMap2DScale.Value = psGet(ps, 'map2DScale', ui.ddMap2DScale.Value);
        ui.efMap2DCMin.Value  = psGet(ps, 'map2DCMin',  '');
        ui.efMap2DCMax.Value  = psGet(ps, 'map2DCMax',  '');
    end

    ui.ddX.ValueChangedFcn  = @(src,evt) callbacks.onAxisChanged(src,evt);
    ui.lbY.ValueChangedFcn  = @(src,evt) callbacks.onAxisChanged(src,evt);
    ui.lbY2.ValueChangedFcn = @(~,~) callbacks.onPlot();

    appData.selectedPeakIdx = 0;   % clear peak selection on dataset switch
    callbacks.refreshPeakTable();

    % Refresh data table if visible
    appData.tableMask   = [];  % reset mask on dataset switch
    appData.filterMask  = [];  % reset row filter on dataset switch
    ui.efFilter.Value   = '';  % clear filter text field
    callbacks.refreshDataTable();
    % Grid and axis-direction restoration happens post-draw via
    % applyAxesPlotState in BosonPlotter, which reads directly from
    % the active dataset's ds.plotState struct.
end

function v = psGet(ps, field, defaultVal)
%PSGET  Read a plotState field, falling back to defaultVal when the
%  struct lacks the field or stores an empty placeholder.
    if isfield(ps, field) && ~isempty(ps.(field))
        v = ps.(field);
    else
        v = defaultVal;
    end
end
