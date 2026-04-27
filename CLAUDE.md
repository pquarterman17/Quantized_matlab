# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for magnetometry and generic lab data. Supports Quantum Design PPMS/VSM/DynaCool/MPMS, Rigaku XRD, PANalytical XRDML, Bruker XRD, Lake Shore VSM, NCNR neutron reflectometry, SIMS depth profiles, and generic CSV/Excel/TSV data.

## Repository Structure

```
quantized_matlab/
├── setupToolbox.m            # Adds toolbox root to MATLAB path
├── BosonPlotter.m             # Main GUI: browse, preview, correct, peaks, export
├── xrdConvertGUI.m           # Batch XRD file converter GUI
├── DiraCulator.m              # Materials property calculator (18 panels)
├── FermiViewer.m             # Electron microscopy image viewer
├── runAllTests.m             # Master test runner (see Testing section)
├── tests/                    # Test suites organized by domain
│   ├── parser/               # Parser smoke tests, edge cases, round-trip
│   ├── gui/                  # BosonPlotter headless API tests
│   ├── imaging/              # EM parsers, imaging utils, EM GUI, EDS, EELS, diffraction
│   ├── calc/                 # Calculator module tests (xray, superconductor, CIF, optics, ...)
│   ├── batch/                # Batch import and XRD converter tests
│   └── fitting/              # Curve fitting engine, models, auto-guess, equation parser
├── +parser/                  # Data import (see +parser/README.md)
├── +imaging/                 # EM image processing (see +imaging/README.md)
├── +calc/                    # Calculator backend (see +calc/README.md)
├── +utilities/               # Data processing helpers (see +utilities/README.md)
├── +plotting/                # Plot formatting and export
├── +styles/                  # Visual themes
├── +scripts/                 # Batch workflows (see +scripts/README.md)
├── +fitting/                 # General curve fitting engine, model library, equation parser
├── +bosonPlotter/             # Extracted BosonPlotter subsystems
├── +dataWorkspace/            # DataWorkspace model, formula engine, autosave (see +dataWorkspace/README.md)
├── DataWorkspace.m            # Standalone spreadsheet GUI (shares WorkspaceModel with BosonPlotter)
├── docs/                     # Detailed feature documentation
│   ├── gui_bosonplotter.md    # BosonPlotter features, tools, figure builder
│   ├── gui_emviewer.md       # FermiViewer features, EELS, EDS, diffraction
│   └── architecture.md       # Data flow, state management, design patterns
└── plans/                    # Feature roadmaps and organization plans
```

## Conventions

- **Functions:** `PascalCase` — **Variables:** `camelCase` — **Struct fields:** lowercase
- **Parameters:** named arguments via `arguments` block (R2021b+)
- **No external toolboxes** — MATLAB built-ins only
- **Minimum version:** R2022b. If backward compatibility to R2022b would require a significantly inferior solution, use version detection (`isMATLABReleaseOlderThan('R20XXx')`) to branch: implement the best solution for current MATLAB and a fallback for R2022b. When the fallback path is taken, print a one-time warning to the Command Window: `fprintf('Note: [feature] using fallback mode. Upgrade to R20XXx+ for full support.\n')`
- **Unified data struct:** all parsers return `.time`, `.values`, `.labels`, `.units`, `.metadata` via `parser.createDataStruct()`
- **Section dividers:** `% ════════...` style
- **Pipeline:** parse → correct → plot (each stage independent)

### Column Shorthands (`importQDVSM` / `importPPMS`)

`'field'` → Magnetic Field (Oe), `'moment'` → Moment (emu), `'temp'` → Temperature (K), `'time'` → Time Stamp, `'stderr'` → M. Std. Err., `'all'` → all numeric columns except x-axis

## Quick Start

```matlab
setupToolbox                                    % add to path (once)
data = parser.importAuto('sample.dat');         % auto-detect format
data = parser.importQDVSM('f.dat', 'XAxis', 'field', 'YAxis', 'moment');
data = parser.importXRDML('scan.xrdml', Intensity='cps');
data = parser.importCSV('data.csv');
BosonPlotter                                     % interactive GUI
DataWorkspace                                    % standalone spreadsheet GUI
DataWorkspace(Model=model)                       % with a shared WorkspaceModel
api = DataWorkspace(Visible='off')               % headless / scripted use
scripts.quickPlot('scan.xrdml')                 % one-liner plot
scripts.batchImport('measurements/', 'Recursive', true);
devReload DiraCulator                            % close+flush+relaunch after edits
```

## Testing

```matlab
runAllTests                          % full suite
runAllTests(Group="parser")          % parser smoke tests (fast)
runAllTests(Group="gui")             % headless BosonPlotter API tests
runAllTests(Group="em")              % EM parsers + imaging utilities
runAllTests(Group="emgui")           % EM Viewer GUI API tests
runAllTests(Group="batch")           % batch import + XRD converter
runAllTests(Group="fitting")         % curve fitting engine + models + parser
```

Groups: `parser`, `batch`, `xrd2d`, `gui`, `calcgui`, `sims`, `em`, `emgui`, `eds`, `xrayneutron`, `superconductor`, `cif`, `optics`, `vacuum`, `electrochemistry`, `eels`, `eels_adv`, `diffindex`, `diff_sim`, `edsquant`, `contour`, `fitting`, `plotting`, `spectral`, `interp2d`, `baseline`, `errorprop`, `utilities`, `templates`

## Tracking Work

**`BACKLOG.md`** at the repo root is the single source of truth for what's open
right now. It aggregates every open top-level item from every active plan in
`plans/*.md` (grouped by tier, then by plan). It is **tracked in git** and
survives across machines / parallel terminals.

`plans/*.md` files are **gitignored working documents** — detailed context,
dependency maps, and sub-task checklists for each workstream. Plans are per-
machine; BACKLOG.md is shared.

### Workflow

- Before starting work, check `BACKLOG.md` to see what's open.
- When completing an item:
  1. Strike it in the source `plans/<plan>.md` (`~~**#5 ...**~~ (YYYY-MM-DD) — outcome`) and move it to that plan's `## Completed` section.
  2. Remove (or strike) the corresponding line in `BACKLOG.md`.
- When all items in a plan ship, set the plan's `**Status:** Complete` and move the file to `plans/archive/`.
- When a plan drifts (items marked done in one, still open in another), reconcile by trusting the code (`git log`, tests) as the source of truth — see memory `feedback_plan_drift`.
- Regenerate `BACKLOG.md` any time a plan gains or loses items; it's a manually curated aggregation, not a script output.

## Key Design Decisions

- **Functional approach** — pure functions returning structs; no heavy OOP for orchestrators (BosonPlotter, FermiViewer, DiraCulator stay procedural). `handle` classes ARE used for state containers (`AppState`, `UndoManager`, `WorkspaceModel`, future `*WorkshopModel`). The rule prohibits class-ifying the orchestrator script, not all classes.
- **Workshop pattern** — heavy GUI features (Peak, Curve Fit, Hysteresis, Reflectivity) live in their own `+bosonPlotter/+<feature>/` subpackage with three pieces: a `<Feature>WorkshopModel` handle class owning the feature's state, a functional view builder (e.g. `buildPeakWindow.m`), and callbacks that operate on `(model, hook)` rather than the parent's closure. The parent passes a small **hook API** (~9 named function handles for getActiveData / setStatus / drawOverlay / etc.) so the workshop never reaches into the parent's state directly. Two contract rules every workshop must follow: (1) the model's `bindFromDataset` must call a `normalizePeaks`-style helper that ensures incoming data has the canonical field set — so legacy sessions don't blow up assignments with "dissimilar structures"; (2) the model's test suite must include at least one regression case fed *legacy-shaped* input (not just freshly-constructed via the canonical helpers), since unit tests with helper-constructed data will silently miss shape mismatches at the bind boundary. Active conversion plan: `plans/workshop-conversion-plan.md`. Reference implementation: `+bosonPlotter/+peak/` (Peak shipped 2026-04-26).
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred
- **Unified data struct** — parser-agnostic GUI and plotting code
- **Peak fitting** — Lorentzian model (appropriate for XRD Bragg peaks)
- **General curve fitting** — `+fitting/` package with bounds, parameter errors, custom equations, batch fitting, peak tracking (see [+fitting/README.md](+fitting/README.md) for the full model catalog)
- **Publication templates** — `styles.template('aps')` etc. for journal-ready figures
- **Statistics** — t-tests, linear regression, descriptive stats (no Statistics Toolbox)

## 2D Area-Detector Extension (`importXRDML`)

When XRDML contains multi-frame area-detector data, `data.metadata.parserSpecific` gains:
- `.is2D` — `true` (also `false` for 1D files)
- `.map2D.intensity` — [N×M] matrix, `.map2D.axis1`/`.axis2` — motor positions
- `.map2D.Qx`, `.map2D.Qz` — reciprocal-space grids (when wavelength available)

## Detailed Documentation

Feature-level docs are in separate files to keep this context compact:

| Topic | File |
|-------|------|
| BosonPlotter tools, figure builder, curve fitting, digitizer | [docs/gui_bosonplotter.md](docs/gui_bosonplotter.md) |
| DataWorkspace features, formulas, masking, session management | [docs/gui_dataworkspace.md](docs/gui_dataworkspace.md) |
| FermiViewer features, EELS, EDS, diffraction | [docs/gui_emviewer.md](docs/gui_emviewer.md) |
| DiraCulator — 18-panel calculator, reflectivity builder, headless API | [docs/gui_diraculator.md](docs/gui_diraculator.md) |
| Architecture, data flow, state management | [docs/architecture.md](docs/architecture.md) |
| Parser formats and dispatch | [+parser/README.md](+parser/README.md) |
| Imaging utilities | [+imaging/README.md](+imaging/README.md) |
| Calculator modules | [+calc/README.md](+calc/README.md) |
| Data processing utilities | [+utilities/README.md](+utilities/README.md) |
| Batch scripts | [+scripts/README.md](+scripts/README.md) |
| Plot formatting and export | [+plotting/README.md](+plotting/README.md) |
| Visual themes and templates | [+styles/README.md](+styles/README.md) |
| Curve fitting engine and models | [+fitting/README.md](+fitting/README.md) |
| DataWorkspace package | [+dataWorkspace/README.md](+dataWorkspace/README.md) |
| **Physics theory** (LaTeX formulas, derivations) | [docs/theory/](docs/theory/) |
| **Tutorials** (step-by-step workflows) | [docs/tutorials/](docs/tutorials/) |

## GUI Development Notes

### Reloading a GUI after code edits
MATLAB caches function definitions in memory once loaded. After editing a GUI file (e.g. `DiraCulator.m`), calling `DiraCulator` again in an open MATLAB session re-runs the *old* cached code unless the function has been flushed. Use `devReload` to do the minimal-sufficient reset in one command:

```matlab
devReload DiraCulator   % close all figures + clear function cache + relaunch
devReload               % same, defaults to DiraCulator
devReload BosonPlotter  % works for any GUI in the toolbox
```

This is preferred over `clear classes` (which also destroys class state and is slower) and over restarting MATLAB (rarely needed — only for corrupted MEX/Java state). When asking the user to re-test a GUI change, direct them to `devReload <GuiName>` rather than "restart MATLAB".

### Layout integrity — catch clipped widgets early
MATLAB silently allows `uigridlayout` clipping: if a parent row allocates 22 px and a nested grid needs 44 px, the widget renders but is partially or fully invisible with no warning.  This has bitten us multiple times (e.g. the Phase A Template dropdown was clipped out of sight).

- **Detection helper:** `tests/gui/checkClippedLayouts.m` walks every `uigridlayout` and flags nested grids whose fixed pixel row/column spec overflows the slot the parent allocates.  Also flags leaf widgets with `Position(3|4) == 0` after `drawnow`.  Treats allocated == 0 as "collapsed section" (legitimate), not clipping.
- **Regression test:** `tests/gui/test_layoutIntegrity.m` — run via `runAllTests(Group="gui")`.  Includes synthetic broken layouts to verify the detector itself works.
- **Workflow:** after editing any `uigridlayout` `RowHeight` / `ColumnWidth` in BosonPlotter.m or `+bosonPlotter/*.m`, run `runAllTests(Group="gui")` before assuming the layout works.  The `ux-frontend-expert` agent should invoke `checkClippedLayouts(fig)` during any GUI layout review.
- **Common fix:** if the detector reports `Nested grid needs N px but parent row allocates M px`, bump the parent `uigridlayout` `RowHeight{row}` entry from M to at least N.

### Cross-GUI theme system (Dark / Light / Auto)
All four GUIs (BosonPlotter, FermiViewer, DiraCulator, DataWorkspace) share a single theme preference via `+bosonPlotter/themePref.m` (read/write, persisted to `prefdir/boson_theme.mat`). `+bosonPlotter/resolveTheme.m` turns `'Auto'` into a concrete `'Dark'` or `'Light'` value at apply time (MATLAB R2025a+ `MATLABTheme` setting → Windows registry → macOS defaults → Dark fallback). Toolbar/menu quick toggles flip Dark↔Light explicitly (clearing Auto); the Settings dropdown round-trips Auto.

Two layers always need updating together (see `feedback_matlab_two_theme_layers`):
1. `theme(fig, 'dark'|'light')` — built-in MATLAB chrome (uitable empty viewport, scrollbars, dropdown overlays)
2. Per-widget `BackgroundColor` / `FontColor` — cells, panels, buttons

BosonPlotter uses `+bosonPlotter/uxTokens.m` as the single colour-token source; FermiViewer's `applyTheme` also reads from `uxTokens(themeName)`. DiraCulator + DataWorkspace branch local FIG_BG/etc constants on the resolved value at startup. Adding a new GUI: see `memory/reference_theme_system.md` for the four-step recipe.

### BosonPlotter
- `cla()` alone does not remove `HandleVisibility='off'` objects — use `delete(ax.Children)` before `cla()`
- Each dataset stores axis limits in `ds.axLims` (persisted across switches)
- Peak Analysis window: see [docs/gui_bosonplotter.md](docs/gui_bosonplotter.md)

### BosonPlotter — where new code goes
MASTERPLAN W5 #22 targets `BosonPlotter.m` under 8,000 lines. Without a policy, new features tend to land inside the monolith as fast as extractions pull lines out and the target never arrives. Rule for any new BosonPlotter code:

- **Default to `+bosonPlotter/<feature>.m`** — implement the feature as a public package function that takes the handles/state it needs (typically the `ui` struct + callback structs like `corrCb_`, `ptCb_`, `anaCb_`). Call it from a minimal nested dispatcher in `BosonPlotter.m`.
- **Do not add new nested functions to `BosonPlotter.m`** unless they are one- or two-liners that merely forward to a `+bosonPlotter/` helper. The legacy nested-function pattern is closed for new code.
- **Never add doubly-nested functions** (8-space indent) to `BosonPlotter.m` — see `matlab-gui-complexity.md` for why (parser-slot cost and worse refactorability).
- **Enforcement:** `tests/gui/test_bosonPlotterSize.m` asserts `BosonPlotter.m <= 8,650 lines` and nested-fn total `<= 290`. Runs via `runAllTests(Group="gui")`. **Ratchet the ceiling downward** as extractions lower the baseline; never raise it to accept growth. Current baseline: 8,609 lines / 270 nested fns (2026-04-21).

This policy applies to `BosonPlotter.m` specifically. `FermiViewer.m` and `DiraCulator.m` have separate cap-tracking memories — apply the same pattern if they grow unchecked.

### DataWorkspace
- BosonPlotter creates `appData.model` (a `WorkspaceModel`) at startup; both the toolbar "Workspace" button and the "Open in DataWorkspace" button pass `Model=appData.model` so both windows share the same instance
- All data mutations go through `WorkspaceModel` methods, never by writing `model.datasets{k}` directly (`SetAccess=private`)
- `createTableWidget` returns `(widget, isSpreadsheet)` — branch on `isSpreadsheet` when setting callbacks that differ between `uispreadsheet` and `uitable`
- Computed column values are stored as snapshots; call `model.recomputeColumns(dsIdx)` if the underlying dataset changes after a column was added
- Autosave file path: `fullfile(prefdir, 'dataworkspace_autosave.dwk')`

### DiraCulator
- **Navigation model:** sidebar is a `uitree` (not `uitabgroup`) — panels are stacked `uipanel` widgets in the same grid cell; visibility is toggled, not tab-switched. Category header clicks are no-ops; only leaf node clicks trigger `selectPanel`.
- **`errText(msg)`:** shared helper that returns `'<span style="color:#e64040">Error: msg</span>'` for inline error display inside HTML-interpreter labels. All tab builders rely on it — never `error()` or `setStatus` alone for card-level errors.
- **Cross-tab hooks via `appData.api`:** producer tabs register function handles in `appData.api` during their `buildXxxTab` call; consumer tabs look up those handles to push data across panels. The critical ordering constraint: all tabs are built sequentially at startup so all `appData.api` fields are populated before any consumer reads them. The three active cross-tab flows are: d-Spacing → Q/2θ (`fillQ2TFromD`), Mol. Weight → Cell Vol (`fillVCMolarMass`), Neutron SLD → Reflectivity (`addLayer`).
- **Scrollable panel pattern:** Electrical, Semiconductor, Thin Film, Crystal, Magnetic, and Optics tabs use `uipanel(..., 'Scrollable', 'on')` as the inner container. The outer grid has `RowHeight = {'1x'}` so the scroll wrapper fills the panel. Do not add `Scrollable` to `uigridlayout` directly — it does not support that property.
- **`registerPrimaryBtn(key, btn)`:** maps navKey strings to the primary Calculate button for that panel. The global `WindowKeyPressFcn` fires the mapped button on Enter. Each tab builder calls this once with its own key and button. Tabs without a clear primary action (Substrates, Periodic Table, History, Favorites) do not register.
- **Headless API pattern:** `if nargout > 0` at the end of the top-level function assembles the `api` struct from `appData.api` fields populated by tab builders. Tests call `api = DiraCulator()` to get the struct, then use `api.close()` to tear down. The GUI is fully functional even in headless mode — all buttons and callbacks work normally. See [docs/gui_diraculator.md](docs/gui_diraculator.md) for the full API method table.
- **History entries:** stored as `{timestamp, tabKey, description, latexStr, matlabCall}` (5-element cell). `matlabCall` is empty for tabs that don't generate reproducible single-line calls (Magnetic, Thermal, Diffusion). Consumers must guard with `numel(e) >= 5`.

### FermiViewer
- Image pipeline: `rawPixels` → `filteredPixels` → `displayImg`
- Enable/disable triad: `displayImage()`, `clearDisplay()`, `setToolsEnabled()`
- `undoPush()` inside `try` blocks only — prevents phantom undo on failure
- FFT mask uses `ButtonDownFcn`, not `ginput()` (unreliable in uifigure)
- See [docs/gui_emviewer.md](docs/gui_emviewer.md) for full details
