# +bosonPlotter/ — Extracted BosonPlotter Subsystems

Functions extracted from the monolithic `BosonPlotter.m` to reduce its size and improve maintainability. BosonPlotter delegates to these functions; they can also be called independently for scripting and testing.

## Design Pattern

Each extracted function:
- Creates its own `uifigure` (for dialog functions) or is a pure function (for pipeline functions)
- Receives data/state as explicit arguments instead of accessing closure variables
- Uses callbacks (`StatusFcn`, `LoadCallback`) to communicate results back to the main GUI
- Can be tested independently of the GUI

---

## Functions

### Rendering

| Function | Description |
|----------|-------------|
| `renderPlot(targetAx, ctx)` | Render selected datasets into axes; dispatches Y/Y2/colormap channels |
| `drawOverlays(targetAx, ds)` | Render peak markers, fit curves, SNIP background, annotations, reference lines |
| `resolveStyle(template, globalOverrides, ds, channelIdx)` | Merge template + overrides into an effective appearance struct (precedence chain) |
| `applyPostRenderStyle(targetAx, appearance)` | Post-draw axes pass: applies font, tick, box, grid from appearance struct |
| `applyDsOverride(aBase, ds, channelIdx)` | Layer per-dataset and per-channel style overrides onto a base appearance struct |
| `applyAlphaToLine(h, alphaVal)` | Apply alpha transparency to a Line or ErrorBar handle |
| `applyFaceModeToLine(h, faceMode)` | Set `MarkerFaceColor` mode on a Line or ErrorBar handle |
| `applyAppearanceToAxes(targetAx, appearance)` | Apply font, tick, box, grid from a resolved appearance struct to any axes |
| `applyAppearanceToColorbar(cbh, appearance)` | Apply font and label style from a resolved appearance struct to a colorbar |

#### Example
```matlab
% Apply a style to standalone axes (e.g. in a secondary dialog)
appearance = bosonPlotter.resolveStyle(styles.template('aps'));
bosonPlotter.applyAppearanceToAxes(gca, appearance);
bosonPlotter.applyPostRenderStyle(gca, appearance);
```

---

### Peak Analysis

| Function | Description |
|----------|-------------|
| `buildPeakWindow(appData, constants)` | Construct the Peak Analysis floating window; returns widget struct `w` |
| `peakCallbacks(ctx)` | Build callback struct for peak detection, fitting, and export actions |
| `peakTools` | Static-method class: lattice refinement, phase matching, FFT thickness, Williamson–Hall |
| `peakAnalysis(datasets, activeIdx, mainAx)` | Open the advanced peak detection and fitting dialog |

#### peakTools static methods
| Method | Description |
|--------|-------------|
| `peakTools.refineLattice(ds, wavelength_A)` | Assign hkl indices and refine lattice parameters |
| `peakTools.matchPhases(ds, wavelength_A)` | Match detected peaks to crystal phase database |
| `peakTools.fftThickness(ds, wavelength_A)` | Estimate thin-film thickness from interference fringes |
| `peakTools.reflectivityFFT(ds)` | FFT of reflectivity data to extract thickness oscillation period |
| `peakTools.williamsonHall(ds, wavelength_A, kFactor, instBroadening_deg)` | Williamson–Hall plot for crystallite size and microstrain |

#### Example
```matlab
result = bosonPlotter.peakTools.williamsonHall(ds, 1.5406, 0.9, 0.05);
```

---

### Corrections

| Function | Description |
|----------|-------------|
| `applyCorrections(rawData, params)` | Run the full corrections pipeline: trim, offset, background, smooth, normalize, derivative |
| `correctionParams(ds, uiValues)` | Build a params struct from a dataset struct and GUI widget values |

#### Example
```matlab
params = struct('xOff', 0, 'yOff', 0, 'bgSlope', 0, 'bgInt', 0, ...
    'xTrimMin', NaN, 'xTrimMax', NaN, ...
    'smoothEnabled', true, 'smoothWindow', 5, 'smoothMethod', 'gaussian', ...
    'normMethod', 'None', 'derivativeMode', 'None', ...
    'isNeutron', false, 'isMag', false);
corrData = bosonPlotter.applyCorrections(rawData, params);
```

---

### UI Builders

| Function | Description |
|----------|-------------|
| `buildMap2DPanel(parentGL, isMac)` | Construct the 2D Map View panel inside the analysis grid; returns widget struct |
| `figureBuilder(datasets, activeIdx)` | Open the Advanced Figure Builder dialog (10 figure types, journal templates) |
| `plotStyleDialog(parentFig, ctx)` | Modal Plot Style editor: font, line width, marker, template save/load |
| `toolbarConfig(currentConfig, availableActions)` | Open toolbar customisation dialog; returns updated action-ID cell array |
| `toolbarDefaultConfig()` | Return factory-default ordered list of toolbar action IDs |
| `spreadsheetPopup(dataStruct)` | Open a standalone resizable spreadsheet window for a dataset |

#### Example
```matlab
% Open Figure Builder standalone
bosonPlotter.figureBuilder(datasets, 1);

% Show data in a spreadsheet
bosonPlotter.spreadsheetPopup(data, Title='VSM scan', ReadOnly=true);
```

---

### State Management

| Function | Description |
|----------|-------------|
| `AppState` | Handle class: shared GUI state for BosonPlotter; all `appData.X` fields |
| `UndoManager` | Unlimited undo/redo stack; entries carry `undo`/`redo` function handles |
| `sessionManager` | Static-method class: save/load BosonPlotter session `.mat` files |
| `actionLog` | Handle class: record GUI actions as reproducible MATLAB commands; `record(str)` for string commands or `recordCall(fn, args, Lhs=, Raw=)` for structured tuples; `exportScript(path)` writes a `.m` script |
| `serializeArg` | Convert any value to its MATLAB literal source form; round-trips via `eval`; used by `actionLog.recordCall` |
| `exportScript(fig, path)` | Free-function form of `actionLog.exportScript` — pulls the macroLog off the figure via `getappdata` |
| `datasetGroups` | Handle class: manage named groups of dataset indices for batch operations |

#### AppState
```matlab
state = bosonPlotter.AppState();
state.datasets{end+1} = newDs;
state.activeIdx = numel(state.datasets);
```

#### UndoManager
```matlab
mgr = bosonPlotter.UndoManager(MaxSize=50);
prevDs = state.datasets{idx};
% ... perform operation ...
mgr.push(struct('type','correction','label','Smooth', ...
    'undo', @() restoreDs(prevDs), ...
    'redo', @() reapplySmooth()));
mgr.undo();   % calls the undo function handle
```

#### sessionManager
```matlab
% Save session
guiState = bosonPlotter.sessionManager.collectGuiState(widgets);
bosonPlotter.sessionManager.save('session.mat', appData, guiState);

% Load session
[datasets, restored] = bosonPlotter.sessionManager.load('session.mat');
bosonPlotter.sessionManager.applyGuiState(restored.guiState, widgets);
```

#### actionLog
```matlab
log = bosonPlotter.actionLog();

% String-based recording (the original API; still works for ad-hoc commands)
log.record("d = parser.importAuto('sample.dat');");

% Structured recording — auto-serializes args via bosonPlotter.serializeArg
log.recordCall("parser.importAuto", {'sample.dat'}, Lhs="d");
log.recordCall("utilities.smoothData", ...
    {"d.time", "d.values", 5}, ...
    Lhs="d.values", Raw=[true true false]);   % d.time / d.values are expressions

log.exportScript('analysis.m');               % method form (writes the script)

% Free-function form — pulls the macroLog off any open BosonPlotter window
% via setappdata(fig, 'macroLog', ...). Convenient when only the figure
% handle (not the api struct) is in scope.
bosonPlotter.exportScript(api.fig, 'analysis.m');
```

Replay with `run('analysis.m')`. See
[docs/gui_bosonplotter.md → Macro Recording & Replay](../docs/gui_bosonplotter.md#macro-recording--replay)
for full toolbar workflow and caveats.

#### serializeArg
```matlab
% Convert any value to its MATLAB literal source form (round-trip via eval)
bosonPlotter.serializeArg(5)                          % '5'
bosonPlotter.serializeArg('hello')                    % '''hello'''
bosonPlotter.serializeArg([1 2; 3 4])                 % '[1 2;3 4]'
bosonPlotter.serializeArg({1, 'two', true})           % '{1, ''two'', true}'
bosonPlotter.serializeArg(struct('a', 1))             % 'struct(''a'', 1)'
% Falls back to '<unsupported:CLASS>' for exotic types so a single weird
% arg never breaks an entire macro export.
```

#### datasetGroups
```matlab
grp = bosonPlotter.datasetGroups();
grp.createGroup('Temperature Series', [1 2 3 4 5]);
grp.createGroup('Field Sweeps');
grp.addToGroup('Field Sweeps', [6 7 8]);
indices = grp.getGroup('Temperature Series');  % [1 2 3 4 5]
```

---

### Analysis Dialogs

| Function | Description |
|----------|-------------|
| `curveFitting(datasets, activeIdx, mainAx)` | Open general curve fitting dialog (see [`+fitting/README.md`](../+fitting/README.md)) |
| `roiAnalysis(datasets, activeIdx, mainAx)` | Interactive region-of-interest analysis gadget |
| `reflFitting(datasets, activeIdx, mainAx)` | Reflectivity fitting dialog with layer stack editor |
| `surfaceFitDialog(mapData)` | Interactive 2D surface fitting for map datasets |
| `hysteresisDialog(datasets, activeIdx, mainAx)` | Hysteresis loop analysis: Hc, Mr, saturation |
| `graphDigitizer()` | Standalone graph digitizer: extract data from graph screenshots |
| `multiPanel(datasets)` | Create a multi-panel figure with linked axes |

#### Example
```matlab
% Open hysteresis analysis on the active dataset
bosonPlotter.hysteresisDialog(datasets, 1, ax);

% Digitize data from a scanned graph image
bosonPlotter.graphDigitizer();
```

---

### Style and Colors

| Function | Description |
|----------|-------------|
| `colorMaps(colormapName, nColors)` | Generate N colours from a named colormap; supports `viridis`, `plasma`, `inferno`, all MATLAB builtins |
| `userTemplates` | Static-method class: save/load/list/delete user-defined style templates in `prefdir` |

#### Example
```matlab
% Get 8 viridis colours for a temperature-series plot
colors = bosonPlotter.colorMaps('viridis', 8);

% Save the current appearance as a named user template
bosonPlotter.userTemplates.save('my_aps_style', appearance);
names = bosonPlotter.userTemplates.list();
tpl   = bosonPlotter.userTemplates.load('my_aps_style');
```

---

### Utilities

| Function | Description |
|----------|-------------|
| `filterRows(dataStruct, expression)` | Evaluate a filter expression against a data struct; returns logical mask |
| `safeEvalMathExpr(expr, vars)` | Evaluate dataset-math expressions (`D1 - D2`, `log10(D1)`) without `eval()` |

#### filterRows
```matlab
mask = bosonPlotter.filterRows(data, 'Field > 0 & Temp < 300');
mask = bosonPlotter.filterRows(data, 'between(x, 30, 60)');
filteredValues = data.values(mask, :);
```

#### safeEvalMathExpr
```matlab
vars.D1 = data1.values(:,1);
vars.D2 = data2.values(:,1);
result = bosonPlotter.safeEvalMathExpr('(D1 - D2) / (D1 + D2)', vars);
```
