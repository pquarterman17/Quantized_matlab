# Improvements Audit — 2026-04-11

Parallel audit by four subagents (usability, refactor/perf, UI, docs), each
running in an isolated worktree. Covers `quantized_matlab` toolbox at HEAD
`c9fcb0d` (data table split). Read-only research — no code changes in this
pass. Use this file as the backlog for follow-up work; check items off as
they land.

**Agent briefs:**
- Usability: `general-purpose` — features that reduce friction on common tasks
- Refactor / perf: `code-architect` — hot loops, duplication, dead code, extraction opportunities
- UI: `ux-frontend-expert` — layout, interaction, theming, tooltips, accessibility
- Docs: `docs-example-writer` — stale, missing, or thin documentation (report came back partial — only tail captured; resume via agent `a657e9d3d989c40e1` for the full list)

---

## Top 5 across all dimensions (start here)

| # | Category | Item | Why it's #1 |
|---|---|---|---|
| **1** | Perf | `lineCache` fast-path is dead — `BosonPlotter.m:7864` sets `appData.lineCache.valid=false` before every `drawToAxes`, so every color/visibility toggle re-runs full `renderPlot` | Regression from the Phase G extraction. Every soft-update is wasted work. |
| **2** | Perf | CSV row-by-row export loop at `BosonPlotter.m:11638-11642` — one `sprintf` + one `fprintf` per row | 10–100× speedup on 100k-row SIMS/VSM scans via single `writematrix` call |
| **3** | UI | Plot Style dialog fixed at `dlgH = 780` + `Resize='off'` (`+bosonPlotter/plotStyleDialog.m:43,68`) — doesn't fit on 1366×768 laptops, Apply button unreachable | Users can't finish a style edit on common laptop screens |
| **4** | UI | `materialsCalcGUI.m`: **0 tooltips across 377 widgets** | Calculator is unusable for anyone outside the author's head |
| **5** | Usability | Recent Files / Recent Folders menu for BosonPlotter (`FermiViewer.m:152-283` has it, BosonPlotter doesn't — `BosonPlotter.m:2341-2353` resets every session) | Single biggest friction reducer per hour of use |

---

## 1. Usability — feature additions that reduce friction

Ranked by (impact × ease).

### High impact / easy

1. **Recent Files / Recent Folders menu for BosonPlotter** — mirror FermiViewer's `.emviewer_recent.mat` pattern; persist last 10 paths via `prefdir`. Add a dropdown next to Add Files. _Ref: `BosonPlotter.m:2341-2353`, `FermiViewer.m:152-283`._
2. **Per-dataset notes / metadata annotations** — add `ds.notes` string, a "Notes…" context menu entry on `lbDatasets`, persist in session `.mat`, render as tooltip on hover. _Ref: `BosonPlotter.m:473-486`._
3. **Rename / relabel dataset from list** — "Rename…" context-menu entry → `ds.displayName`; refresh `rebuildDatasetList`. _Ref: `BosonPlotter.m:1780` (hidden legendName field)._
4. **Autosave / crash-recovery session** — `timer` that serializes `appData.datasets` to `prefdir/boson_autosave.mat` every 2 min. On startup, offer to restore if file newer than last save.
5. **Bulk-apply corrections / appearance to selected or all datasets** — button in the corrections panel iterates `lbDatasets.Value`, copies the correction state, calls `applyCorrections`. _Ref: `BosonPlotter.m:4387` (only match for an `applyToAll` pattern)._
6. **Correction presets (named, saved)** — small "Save/Load Preset…" dropdown under corrections; persist to `prefdir/boson_corr_presets.mat`.
7. **Legend location dropdown** — `legend(ax,'show')` is called twice at `BosonPlotter.m:12472, 12534` with no `Location` argument. Add `ddLegendLoc` (NE/NW/SE/SW/EastOutside/none) and pass through.
8. **Reload-from-disk button** — context menu "Reload from disk" that re-calls `guiImport(ds.filepath)` and replaces `ds.data`, preserving corrections and legend name.
9. **`xrdConvertGUI`: remember last input / output folders** — persist via `getpref('BosonXRDConvert', …)`. _Ref: `xrdConvertGUI.m:241, 259, 516`._
10. **Data-cursor value readout pin / lock** — Ctrl+click to pin a cursor; draw a small marker + text label into `appData.pinnedCursors` with a "Clear Pinned" entry. _Ref: `BosonPlotter.m:836`._
11. **Quick unit-prefix cycling via keyboard** — extend `onFigureKeyPress` (`BosonPlotter.m:9505`) so Alt+Up/Down cycles the prefix index on X/Y. _Ref: submenu at `BosonPlotter.m:764-778`._
12. **Extension-specific file filter presets in Add Files dialog** — split the one-liner at `BosonPlotter.m:2343` into multiple entries `{'*.xrdml;*.raw;*.brml','XRD'; '*.dat','VSM/PPMS'; ...}`. Pure data-structure change.
13. **"Copy Row as MATLAB code" for materialsCalcGUI history** — context menu on history table → `clipboard('copy', sprintf('calc.%s(…)', …))`. _Ref: `materialsCalcGUI.m:105`._
14. **Keyboard shortcut for "next peak" in Peak Analysis** — install `KeyPressFcn` on `peakFig` for Down/Up/Enter to select + fit.
15. **Dataset color swatch in list + "Set Color…" picker** — uilistbox HTML markup for a colored square prefix, plus context menu entry.

### Excluded

Items in `plans/origin-feature-gap.md` that are already marked `[x]` — confirmed by the agent to be done.

---

## 2. Refactor / Perf — code health & speed

### (1) High-impact perf / correctness

1. **`lineCache` fast-path is dead.** `softUpdateLines()` at `BosonPlotter.m:7792` early-exits if `~appData.lineCache.valid`. `appData` is now a handle class (`+bosonPlotter/AppState.m:1`) so writes from `+bosonPlotter/renderPlot.m:918-946` DO propagate — but `onPlot` at `BosonPlotter.m:7864` immediately sets `valid = false` before `drawToAxes`, defeating the cache. **Fix:** move `lineCache.valid = false` out of the regular replot prelude into actual invalidation paths only (dataset add/remove, channel change).
2. **CSV table-export row-by-row loop.** `BosonPlotter.m:11638-11642` does `arrayfun(@sprintf, wc(ri,:))` + `fprintf` per row. For 100k-row scans this is O(N) MATLAB dispatches. **Fix:** `writematrix(wc, outPath, 'WriteMode','append')` after writing headers, or one `sprintf` over the whole matrix.
3. **`feval(cmapName, 256)` repeated in 13 sites.** `FermiViewer.m:2456,3254,5975,6988,7656,8063,8406,8771,8889,8902,10913,11340`, `BosonPlotter.m:8254`, `+bosonPlotter/colorMaps.m:27`, `+plotting/groupedPlot.m:240`, `+plotting/colorScatterZ.m:199`. Several are inside per-frame redraws. Also violates the `no-eval` project rule. **Fix:** cache `containers.Map('viridis', @viridis, ...)` once at startup; route every site through `bosonPlotter.colorMaps`.
4. **`drawToAxes` rebuilds a 30-field `rCtx_` struct on every replot.** `BosonPlotter.m:7984-8050` rebuilds the full struct including 9 function-handle fields that never change. Fires on every slider drag. **Fix:** allocate the static portion (handles, fig, isMainAx) once into `appData.renderCtxStatic` and only refresh widget-derived fields per call.
5. **Cross-polarization correction loop duplicates `onApplyCorrections`.** `BosonPlotter.m:5602-5647` re-walks every dataset after every Apply, building a 2nd undo struct + uiVals + `applyCorrections` call. O(N) per click. **Fix:** extract `+bosonPlotter/applyToNeutronSiblings.m(state, activeIdx, params)` and call once.
6. **51× `appData.datasets{di} = ds` struct copy-back.** Each writes the entire `ds` struct (including potentially huge `data.values` / `corrData.values`) back into the cell. Cell elements are value-semantic even though `appData` is a handle. **Fix:** promote `Dataset` to a handle class (`+bosonPlotter/Dataset.m`) so `ds.field = x` mutates in place. Migrate gradually — start with high-churn fields (`corrData`, `peaks`, `mask`).

### (2) Code health

7. **176 lines of dead curve-fitting code in a `%{ … %}` block** at `BosonPlotter.m:12677-12853`. Replaced by `+bosonPlotter/curveFitting.m` but the block-comment rots in the parent file. **Fix:** delete.
8. **Undo-state struct construction repeated 60 times** across `BosonPlotter.m:5503-5530, 5615-5626, 5665-5687, …`. `onApplyCorrections` and `onApplyCorrectionsAll` build essentially the same 20-field undo struct twice each. **Fix:** `+bosonPlotter/captureUndoState.m(ds)` returning the struct.
9. **`BosonPlotter.m` at 14,167 lines / 317 nested functions.** Only 1 top-level function; everything else is inlined into the parent. Subsystems that look extractable: peak callbacks (~4359), hysteresis dialog (12430+), batch fit / global fit / track peak (12581-12628), FFT filter dialog (~12550), table edit + units sync (~11140-11500), line-cache helpers (~7780-7860), neutron sibling propagation (5602-5647), undo helpers. **Fix:** continue the existing `+bosonPlotter/` extraction. Next targets: `tableModel.m`, `neutronSiblings.m`, `undoState.m`. Aim to drive the parent below 8k lines.
10. **Silent `try/catch` swallows.** 81 in `BosonPlotter.m`, 81 in `FermiViewer.m`. Several have empty bodies: `BosonPlotter.m:570-571, 5269-5271, 5281-5283, 5294-5296, 8083-8084, 4960-4961, 6251-6253, 8342-8344, 8957-8959`. **Fix:** replace `catch / end` with `catch ME; logGUIError('section', ME.message, ME); end` (helper already exists).
11. **`CLAUDE.md` "empty packages reserved" note is stale.** Says `+plotting`, `+scripts`, `+styles`, `+utilities` are empty. Each now has 5–40 files. **Fix:** update CLAUDE.md (listed in docs section too).
12. **`rebuildDatasetList` rebuilds badges per item** at `BosonPlotter.m:3367-3397`. The badge string is derived from `parserName` which never changes per ds. Entire list rebuilds even for filter changes. **Fix:** cache `ds.displayString` once in `buildDs`; rebuild loop becomes pure cell assembly.
13. **Excel sheet-name fallback inside import loop** at `BosonPlotter.m:2466-2470` — `try sheetnames(fp) catch allSheetNames = {'Sheet1'}; end` runs per-file. **Fix:** hoist `excelExts` cell literal outside the for loop.

### (3) Nice-to-have cleanup

14. **`findall(ax,'Tag',…)` peppered through cleanup paths.** `BosonPlotter.m:4713, 4778-4780, 6264, 8938-8942, 9734, 12408-12410`. Each is a full graphics-tree walk. Most have a known single-element handle that could be tracked in `appData`. **Fix:** store the handle on `appData` when creating it and `delete(appData.smoothPreviewLine)` directly.
15. **`containers.Map` of smoothing methods built per-call** at `BosonPlotter.m:6240-6242`. **Fix:** `persistent` or hoisted constants.
16. **`num2cell(1:N)` for listbox `ItemsData` when numeric is accepted.** `BosonPlotter.m:3369, 12883`. **Fix:** `lbDatasets.ItemsData = visIdx;` directly.
17. **Six sequential `delete(findall(...,'Tag','...'))` calls** at `BosonPlotter.m:8938-8942`. Each walks the entire tree. **Fix:** single `findall('-regexp','Tag',...)` or an `appData.overlayHandles` list.
18. **`safeEvalMathExpr` duplicated.** `BosonPlotter.m:14084` is a stub-thin wrapper around `+bosonPlotter/safeEvalMathExpr.m`. **Fix:** delete the local copy.

### Summary of biggest wins

1. Fix `lineCache` invalidation in `onPlot:7864` — restores soft-update fast path after Phase G regression
2. Replace per-row CSV export with `writematrix` — 10–100× on big files
3. Extract neutron sibling propagation + undo capture helpers — kills largest duplicated blocks (~150 lines net)
4. Promote `Dataset` to a handle class — single change unlocks the 51× struct copy-back
5. Delete dead `%{…%}` block at `BosonPlotter.m:12677-12853`

---

## 3. UI — layout, interaction, theming, tooltips

### BosonPlotter

#### High
- **[H] `analysisGL` row 1 fixed at 110 px while `corrGL` declares 29 rows** — `BosonPlotter.m:879` vs `925-927` (summing ~250+ px). When sections are expanded, bottom Apply/Reset row may clip. **Fix:** rely on `axLimGL`-style reflow or verify `Scrollable='on'` on `corrPanel`.
- **[H] Plot Style dialog hard-codes `dlgH = 780` and `Resize='off'`** — `+bosonPlotter/plotStyleDialog.m:43,68`. Doesn't fit 1366×768 laptops. **Fix:** set `Resize='on'`, wrap rows 2-7 in a `Scrollable` uipanel, or compute `dlgH = min(780, screenHeight - 80)`.
- **[H] Figure Builder fixed at 700×600, no resize** — `+bosonPlotter/figureBuilder.m:46`. Same fix.
- **[H] Popup dialogs leak light mode when parent is dark** — `+plotting/templateDialog.m:46-78` has no `dlg.Color`, no theme propagation. Same for `BosonPlotter.m:10980` (Dataset Math), `:12902` (Plot Templates), `:13065` (Batch Figure Export), `:12221` (Integrate). None read `appData.theme`. **Fix:** shared `applyDialogTheme(dlg)` helper (matches the `applyThemeRecursive` pattern from Phase G).

#### Medium
- **[M] Corrections panel header click-target confusing** — `BosonPlotter.m:972-980` (`lblSecOffsets`) uses a label-styled `uibutton` with a 10 px triangle glyph. Users won't realize the whole row is clickable. **Fix:** hover background via `MouseEnterFcn` or render the toggle as a 24×24 button anchored left with the title to its right.
- **[M] Right Y-axis listbox always visible even when empty** — `BosonPlotter.m:531-535` (`lbY2`). `'(none)'` placeholder permanently occupies flex row 3 (~80 px). **Fix:** collapse `y2GL` row to 0 height when no Y2 channel selected.
- **[M] Style/Plot/Annotate row has mismatched widget alignment** — `BosonPlotter.m:651-675`. Checkbox + two buttons in `1x 1x 1x` grid look misaligned. **Fix:** checkbox narrow in col 1, buttons equal-width cols 2-3.
- **[M] `WF` checkbox label is cryptic** — `BosonPlotter.m:619-624`. Plenty of horizontal space. **Fix:** change Text to `'Waterfall'`.
- **[M] Save/Export Tools section collapsed by default** — `BosonPlotter.m:1845-1846`. Common items (Copy Plot, HDF5, Origin) buried two clicks deep. **Fix:** expand by default; persist user state.
- **[M] Macro Record button uses unicode `char(9210)`** — `BosonPlotter.m:858`. Renders as a square in many fonts; status bar is 16 px dark-gray-on-dark-gray. **Fix:** use `'REC'` in red or a coloured circle via `uihtml`.
- **[M] Dataset list context menu gated on R2023b+ with silent fallback** — `BosonPlotter.m:472-490`. Older MATLAB users get no menu and no notice. **Fix:** log to status bar once.
- **[M] Advanced Analysis menu is 26 rows × 2 cols** — `BosonPlotter.m:12034`. Scrolls; hard to find actions. **Fix:** add top filter `uieditfield` that hides non-matching buttons.

#### Low
- **[L] `corrGL` column widths `{80,'1x',80,'1x'}` wasteful** — labels are 6–12 chars but columns are 80 px. **Fix:** drop label cols to 60 px.
- **[L] Status bar 9 pt gray on dark** — `BosonPlotter.m:853-855`. Below WCAG AA. **Fix:** 10 pt + `[0.7 0.7 0.7]`.
- **[L] `efWaterfallSpacing` is `text` not `numeric`** — `BosonPlotter.m:626-630`. **Fix:** switch to numeric with `AllowEmpty=true`.
- **[L] No keyboard focus shortcuts for dataset list / Y selector** — `BosonPlotter.m:462, 511, 516`. **Fix:** `Ctrl+L`, `Ctrl+Y` via `WindowKeyPressFcn`.
- **[L] Remove Selected has no multi-select confirmation** — `BosonPlotter.m:374-379`. **Fix:** `uiconfirm` when `numel(selected)>1`.

### FermiViewer

#### High
- **[H] Toolbar row 2 packs 14 fixed-width controls** — `FermiViewer.m:260-368`. Sums ~498 px before filename label; narrow windows clip silently. **Fix:** replace `|` labels with `RowSpacing`/dividers, group related tools, raise min widths to 32 px.
- **[H] Tools panel fixed 276 px wide hosting 520 px EDS content** — `FermiViewer.m:377, 485-498`. On 1280×800 laptops opening EDS at 520 px tall leaves axes at ~250 px. **Fix:** `toggleSection` should refuse to open a section taller than `figH * 0.6`.

#### Medium
- **[M] Stack navigator `< >` buttons never show Disabled state when only one frame** — `FermiViewer.m:431-441`. **Fix:** bind `Enable` to `numel(stack) > 1` in `loadStack`.
- **[M] Many buttons spend lifetime `Enable='off'`** — Measurement panel alone has 15 pre-load (`FermiViewer.m:687,696,711,…`). Dark-disabled is barely distinguishable. **Fix:** paler background + placeholder text.
- **[M] `btnScaleBarColor` shows text only, background doesn't reflect color** — `FermiViewer.m:692-698`. **Fix:** bind `BackgroundColor` to the target colour.
- **[M] EELS/Diff/EDS collapsed by default, Export open by default** — `FermiViewer.m:485-494`. Inverted priority. **Fix:** persist last-opened sections to `.fermiviewer_layout.mat`.
- **[M] Tools panel has 20 rows (10 sections × 2)** — `FermiViewer.m:500`. 220 px of headers alone. **Fix:** combine EDS/EELS/Diff into a single tabbed "Spectroscopy" panel.
- **[M] Verify Tab-based keyboard nav actually works** — `FermiViewer.m:316-322, 475 onKeyPress`.

#### Low
- **[L] Image list has no context menu** — `FermiViewer.m:394-400`. **Fix:** add Hide/Show, Duplicate, Set Reference.
- **[L] Status bar uses 10 pt mid-gray, mouse readout may clip narrow windows** — `FermiViewer.m:1899-1913`. **Fix:** `'fit'` column for mouse readout.

### materialsCalcGUI

#### Critical
- **[C] 377 widgets, ZERO tooltips.** Every dropdown and edit field needs at least `Tooltip` with unit + one-line description.

#### High
- **[H] No theme handling** — `materialsCalcGUI.m:33` creates default light figure, then every tab uses dark `INPUT_BG=[0.18 0.18 0.18]` edit fields. Dark inputs floating in light figure — inconsistent with other GUIs. **Fix:** full light OR full dark, not mixed.
- **[H] Single-column nav listbox hosts 17 uncategorized entries** — `materialsCalcGUI.m:41, 47-56`. **Fix:** switch to a `uitree` with categories (Materials / Optics / Devices / Thermal-Magnetic / Reference).
- **[H] Global "Copy Result" buttons target last-active tab with no source indicator** — `materialsCalcGUI.m:87-100`. **Fix:** status label showing "Last result from <tab>".
- **[H] No keyboard shortcuts — no `KeyPressFcn` on figure or any input.** **Fix:** bind Enter → active tab's primary Compute button.

#### Medium
- **[M] Crystal tab `gD` 9-column grid is hard to read** — `materialsCalcGUI.m:478`. **Fix:** split into two rows of 4 columns.
- **[M] Result fields use same colors as editable** — `materialsCalcGUI.m:321-322`. Users try to type in them. **Fix:** distinct result-field colour scheme.
- **[M] Periodic Table cell targets likely < 30 px square** — verify `materialsCalcGUI.m:1788`.

#### Low
- **[L] Substrate dropdown rebuilds on every nav change** — `materialsCalcGUI.m:495-498`. Confirm it's once-off.

### xrdConvertGUI

#### High
- **[H] Fixed 600×720 window, no resize handler** — `xrdConvertGUI.m:24`. `taLog` row 11 flex is `Visible='off'` initially so file listbox occupies that space, but no min-height enforcement — small screens clip rows 9-12 (Convert button + status). **Fix:** `Resize='on'`, min size 480×600.
- **[H] Convert button has green background, no `FontColor`** — `xrdConvertGUI.m:169-176`. Default black text on dark-primary green is poor contrast. **Fix:** `FontColor=[1 1 1]`.

#### Medium
- **[M] No tooltips on Format / Intensity / Output dropdowns** — `xrdConvertGUI.m:106-140`. Format choice "Send to Origin" is destructive (requires Origin running) — needs warning tooltip.
- **[M] No drag-and-drop folder support.** BosonPlotter and FermiViewer both have `DropFcn`. **Fix:** add `fig.DropFcn`.
- **[M] No progress bar** — `xrdConvertGUI.m:182-185` uses a textarea log. **Fix:** `uiprogressbar` or "Processing 12/100..." label.

#### Low
- **[L] No Cancel during batch.**
- **[L] Select All / Deselect All could be one toggle button.**

### Plot Style dialog

- **[H] Fixed 400×780, no scroll** — see BosonPlotter section above.
- **[M] Apply-to radio group at row 8 (bottom)** — users scroll down on small screens to see the scope. **Fix:** move radio group above the parameter sections (set scope first).
- **[M] No live preview** — comment at `+bosonPlotter/plotStyleDialog.m:34` justifies. **Fix:** opt-in "Preview" toggle for advanced users.
- **[L] Save as / Delete buttons in row 1 vs template dropdown** — confusing scope. **Fix:** move them to row 9 next to Apply.

### Other Dialogs

- **[H] `toolbarConfig.m` is `WindowStyle='modal'` + `Resize='off'` 520×380** — `+bosonPlotter/toolbarConfig.m:51-54`. Locks the parent, user can't reference the live toolbar while customising. **Fix:** non-modal.
- **[H] Customise Toolbar `lbAvail` lacks per-action descriptions** — `+bosonPlotter/toolbarConfig.m:89-95`. Can't distinguish similar actions. **Fix:** append description column or show selected-item tooltip in a label below.
- **[M] `curveFitting.m` Global Fit dialog 560×480 fixed** — `+bosonPlotter/curveFitting.m:1018`.
- **[M] `peakFig` has `peakBtnGL` with `{24,22,22,22,22,22,0,18,0,96}` rows** — `+bosonPlotter/buildPeakWindow.m:70,93`. Confirm `onToggleAdvancedPeakTools` actually shrinks the 96 px row when collapsed.
- **[M] Most popups use `Resize='off'` consistently** — `BosonPlotter.m:10980, 12902, 13065`, `+plotting/templateDialog.m:48`. Collectively risk not fitting 1366×768.
- **[L] `templateDialog` has an empty description field stored but unused** — `+plotting/templateDialog.m:62-63`.

### Cross-cutting

- **Tooltip coverage:** BosonPlotter 204/347 widgets (~59%), FermiViewer 162/208 (~78%), materialsCalcGUI **0/377**. Calculator is the biggest accessibility gap.
- **Destructive-action confirmations:** only `Remove Selected` in BosonPlotter has one. Missing on Reset, Clear All Peaks, Clear All Reference Lines, etc.
- **Screen-reader focus announcement:** neither BosonPlotter nor FermiViewer announces keyboard focus changes.
- **Button palette inconsistency:** BosonPlotter 8 roles, FermiViewer 4, materialsCalcGUI 3. Same role should mean same colour everywhere. **Fix:** extract shared `+styles/buttonPalette.m`.

---

## 4. Documentation — gaps

### 4.1 Stale docs

- **`CLAUDE.md` Detailed Documentation table (lines 103–110)** — omits entries for `+plotting/`, `+styles/`, and `+fitting/`. The inline tree comment at lines 28–30 calls them "Visual themes" / "Plot formatting" without flagging they are active packages with significant content. **Fix:** add rows to the table pointing at each package's README (or stub one where missing).
- **`docs/architecture.md:151-157` — Extracted Subsystems table is severely incomplete.** Lists 5 `+bosonPlotter/` modules; the package now has 37. Missing: `renderPlot`, `resolveStyle`, `plotStyleDialog`, `applyPostRenderStyle`, `applyDsOverride`, `applyAlphaToLine`, `applyFaceModeToLine`, `applyAppearanceToColorbar`, `AppState`, `UndoManager`, `sessionManager`, `userTemplates`, `peakCallbacks`, `multiPanel`, `buildMap2DPanel`, `hysteresisDialog`, `reflFitting`, `surfaceFitDialog`, `toolbarConfig`, `roiAnalysis`, `spreadsheetPopup`, `datasetGroups`. **Fix:** expand the table or link to a comprehensive `+bosonPlotter/README.md`.
- **`docs/architecture.md:61` — data-flow diagram still labels the render step `drawToAxes()`** — it was extracted to `bosonPlotter.renderPlot` in commit `1598103`. **Fix:** rename in the diagram and add `renderPlot` to the extracted subsystems table.
- **`docs/architecture.md:78-82` — `appData` state container block is missing Phase G fields.** No `appData.styleOverrides` (global override struct from Plot Style dialog), no `appData.activeTemplate`. **Fix:** add both fields to the listing.
- **`docs/gui_bosonplotter.md:71` — "15 built-in models" for Curve Fit.** `+fitting/models.m` contains 24 `mdl(` calls. **Fix:** update to the actual count (count in source: 24).
- **`CLAUDE.md:86` — "+fitting/ package with 23 models."** Off by one — actual is 24. **Fix:** correct the count.
- **`+bosonPlotter/README.md:9-13` — lists only 5 functions, 37 exist.** Also repeats the "15 models" claim for `curveFitting`. **Fix:** overhaul the function table and correct the model count.
- **`+styles/README.md:4-6` — lists `default` and `dark` only.** Package has 4 files: `default`, `dark`, `template`, `palette`. `template` powers the journal publication presets referenced in CLAUDE.md Key Design Decisions; `palette` powers the Phase G dialog. Both missing from README. **Fix:** add rows for `template` and `palette` with usage examples.
- **`+plotting/README.md:3-7` — lists 3 functions, package has 15 `.m` files.** Missing: `applyTemplate`, `boxViolinSwarm`, `colorScatterZ`, `composeFigure`, `groupedPlot`, `marginalHistogram`, `plotTemplate`, `polarContour`, `polarPlot`, `surface3D`, `templateDialog`, `ternaryPlot`. **Fix:** expand the table.
- **`+scripts/README.md:3-8` — lists 4 functions, 7 exist.** Missing: `batchPlot`, `dataConnector`, `generateReport`. **Fix:** add entries.
- **`+utilities/README.md` — lists 16, 38 exist.** Missing 22 entries including all baseline algorithms (`baselineALS`, `baselineModPoly`, `baselineRollingBall`), all statistics additions (`anova1`, `pcaAnalysis`), error propagation (`errorAdd`, `errorDiv`, `errorMul`, `errorProp`, `errorFunc`), signal processing (`fftFilter`, `fftSpectral`, `crossCorrelation`), resampling (`interpolate2D`, `regrid2D`, `resampleData`), `convertMagUnits`, and `logError`. **Fix:** expand the table with a Baselines sub-section.
- **`+parser/README.md` — lists 15, 27 files exist.** Missing: `importAFM`, `importBCF`, `importImage`, `importMRC`, `importSER`, `importDM4` (only DM3 listed), `computeQSpace`, `resolveColumnShorthand`, `resolveParser`. **Fix:** add a Microscopy/EM subsection; list `computeQSpace` and the resolver helpers under Internal.
- **`+imaging/README.md` — lists ~46, 52 exist.** Missing 6: `clahe`, `connectedComponents`, `distanceTransform`, `eelsSVD`, `particleAnalysis`, `watershed`. `eelsSVD` (from commit `dc88368`) is not referenced anywhere outside its own docstring. **Fix:** add a Morphology/Segmentation section and add `eelsSVD` under EELS Analysis.

### 4.2 Missing feature docs (for recent work)

- **Phase G Plot Style rollout — no user-facing docs anywhere.** Commits `638b68c..47fae60` added the Plot Style dialog (palette picker, per-dataset scope, legend font weight, marker face mode, tick length), the `resolveStyle` cascade (`template < globalOverrides < ds.styleOverride < ds.channelStyles{k}`), `applyPostRenderStyle` for axes-wide legend styling, `applyAppearanceToColorbar` for 2D map colorbars, `applyDsOverride` for per-dataset merge. **Fix:** new "Plot Style Dialog" section in `docs/gui_bosonplotter.md` (after "2D Map Colormap Editor") covering the 4-layer precedence cascade, the palette picker, and each apply-to scope.
- **Data table units-row split — docs describe the old single-table layout.** `docs/gui_bosonplotter.md:58-66` still talks about a single table with a units "row" inside it. `docs/architecture.md` makes no mention of the split. **Fix:** update the Data Table section to describe the `tblUnits` + `tblData` architecture with the ~10× scroll speedup rationale.
- **`+fitting/` package — zero user-facing documentation.** 19 files including `batchFit`, `fitBands`, `fitCompare`, `globalFit`, `globalCurveFit`, `hysteresisModels`, `parrattRefl`, `reflSLDPresets`, `residualDiagnostics`, `sldProfile`, `surfaceFit`, `surfaceModels`, `surfaceAutoGuess`, `trackPeak`. CLAUDE.md gives a 1-line mention; no README exists. **Fix:** create `+fitting/README.md` covering models, surface fitting, Parratt reflectometry, ODR, batch fitting, and peak tracking.
- **`+plotting/polarContour` and `+plotting/ternaryPlot` — undocumented.** Added in `e4b8ec5` and `e16da27`. Not in `+plotting/README.md`, `docs/gui_bosonplotter.md`, or `CLAUDE.md`. **Fix:** add entries to `+plotting/README.md` and a brief mention in the Advanced Analysis / Figure Builder section of `docs/gui_bosonplotter.md`.
- **`+utilities/convertMagUnits` — undocumented in README.** Added in `90ac1c1`, wired to the mag unit dropdowns in `309b4a3`. **Fix:** add to `+utilities/README.md` under a Magnetometry sub-heading.
- **`+utilities/anova1` and `pcaAnalysis` — undocumented in README.** Added in `b6b99ec`. **Fix:** add alongside the existing `tTest` / `linRegress` entries under a Statistics group.

### 4.3 Thin or outdated package READMEs

Cross-referenced with section 4.1 but collected here for completeness:

| Package | Documented | Actual | Gap |
|---|---|---|---|
| `+bosonPlotter` | 5 | 37 | 32 functions + wrong model count |
| `+plotting` | 3 | 15 | 12 functions + no examples for newest (polarContour, ternaryPlot) |
| `+styles` | 2 | 4 | `template` + `palette` both missing |
| `+utilities` | 16 | 38 | 22 functions across baselines / stats / errors / signal proc / mag |
| `+parser` | 15 | 27 | 9 missing (mostly EM/microscopy) |
| `+imaging` | ~46 | 52 | 6 missing (5 morphology + `eelsSVD`) |
| `+scripts` | 4 | 7 | `batchPlot`, `dataConnector`, `generateReport` |
| **`+fitting`** | **—** | **19** | **No README exists at all** |

The `+fitting` gap is the biggest — it's the only active package with no README, and it includes public surfaces like Parratt reflectivity fitting that users would reasonably look for.

### 4.4 Missing / thin function docstrings

Phase G helpers (`applyPostRenderStyle`, `applyAppearanceToColorbar`, `applyDsOverride`, `applyAlphaToLine`, `applyFaceModeToLine`, `palette`) all have adequate docstrings — flagged as OK. The thin ones:

- **`+bosonPlotter/multiPanel.m`** — one-line summary + Syntax line, no Inputs/Outputs. The `datasets` cell array and options struct are undocumented. **Fix:** add Inputs block describing `datasets` and key options (`Layout`, `SharedX`, `Appearance`).
- **`+bosonPlotter/peakCallbacks.m`** — one summary line, no description of the returned `cb` struct of function handles. **Fix:** add Outputs block listing each handle and its call signature.
- **`+bosonPlotter/renderPlot.m`** — summary line only; the `ctx` struct's required fields (`.datasets`, `.activeIdx`, `.overlayMode`, `.appearance`, etc.) are not documented. **Fix:** add Inputs block describing the context struct.
- **`+bosonPlotter/filterRows.m`** — two-line help, no description of the `expression` argument format. **Fix:** add Inputs block with a usage example showing a valid expression string.
- **`+bosonPlotter/colorMaps.m`** — summary line only, no list of supported names. **Fix:** add a "Named colormaps" list matching the 10 names referenced throughout the GUI.
- **`+parser/computeQSpace.m`** — two-sentence inline note, no Inputs/Outputs. **Fix:** document the `map` struct's input fields (`.wavelength_A`, `.axis1`, `.axis2`) and output fields (`.Qx`, `.Qz`).
- **`+parser/resolveParser.m`** — one-line summary + one syntax example. The `result` struct's fields (`parserName`, `parserFcn`, `extension`, `formatType`) are not documented. **Fix:** add Outputs block.

### 4.5 Missing examples (from previous agent's captured output)

- **`+bosonPlotter/resolveStyle.m`** — no example in docstring. It's the single choke-point for the style cascade; contributors wiring new render paths need a three-line example showing `resolveStyle → applyDsOverride → applyPostRenderStyle`. **Fix:** add to docstring after the INPUTS block.
- **`+utilities/README.md`** — no example for `convertMagUnits`. Called from GUI and scripts, common workflow step. **Fix:** add to Usage section.

### 4.6 Onboarding

`CLAUDE.md` Quick Start is adequate for programmers. `docs/gui_bosonplotter.md` is a GUI reference but has no "workflow sequence" walkthrough (load file → pick axes → apply corrections → export). Low severity for a developer-facing repo — flagged for awareness, not blocking.

---

## Prioritized execution order

Pick from this list based on time available:

### Session 1 — regression + quick perf (30–60 min)
- [ ] Fix `lineCache` invalidation (item 2.1)
- [ ] Replace CSV row-by-row with `writematrix` (item 2.2)
- [ ] Delete dead `%{…%}` block at `BosonPlotter.m:12677-12853` (item 2.7)
- [ ] Delete duplicate `safeEvalMathExpr` local (item 2.18)

### Session 2 — Plot Style dialog fit (15–30 min)
- [ ] Make dialog `Resize='on'` + wrap parameter sections in scrollable uipanel (UI high #2)
- [ ] Same treatment for Figure Builder (UI high #3)

### Session 3 — materialsCalcGUI accessibility (1–2 h, mostly mechanical)
- [ ] Add tooltip to every `uidropdown` / `uieditfield` creation site (UI critical)
- [ ] Wire Enter key → primary compute button via `KeyPressFcn` (UI high)
- [ ] Pick a single theme (light or dark) consistently (UI high)

### Session 4 — usability sprint (half day)
- [ ] Recent Files menu (Usability #1)
- [ ] Per-dataset notes (Usability #2)
- [ ] Rename dataset from list (Usability #3)
- [ ] Bulk-apply corrections (Usability #5)
- [ ] Legend location dropdown (Usability #7)

### Session 5 — refactor / extraction (half day to day)
- [ ] Extract `captureUndoState.m` (~60 sites, item 2.8)
- [ ] Extract `applyToNeutronSiblings.m` (item 2.5)
- [ ] Cache colormap dispatch table (item 2.3)
- [ ] Hoist static part of `rCtx_` into `appData.renderCtxStatic` (item 2.4)

### Session 6 — bigger refactors (multi-day)
- [ ] Promote `Dataset` to a handle class (item 2.6) — highest leverage perf win long-term
- [ ] Continue extracting BosonPlotter subsystems to drive parent below 8k lines (item 2.9)
- [ ] Audit 81 silent `try/catch` and route through `logGUIError` (item 2.10)

### Session 7 — documentation pass (split into 7a / 7b / 7c)

**7a — Stale corrections (quick, ~1 hour):**
- [ ] Fix "15 models" → 24 in `docs/gui_bosonplotter.md:71`, `+bosonPlotter/README.md`, `CLAUDE.md:86`
- [ ] Update `docs/architecture.md:61` — rename `drawToAxes` → `renderPlot` in data-flow diagram
- [ ] Update `docs/architecture.md:78-82` — add `appData.styleOverrides`, `appData.activeTemplate`
- [ ] Update `docs/architecture.md:151-157` — expand Extracted Subsystems table (or link to a comprehensive `+bosonPlotter/README.md`)
- [ ] Update `CLAUDE.md:103-110` — add `+plotting`, `+styles`, `+fitting` rows to Detailed Documentation table

**7b — Missing feature docs for recent work (~2 hours):**
- [ ] Add "Plot Style Dialog" section to `docs/gui_bosonplotter.md` covering the 4-layer cascade, palette picker, and apply-to scopes (item 4.2 Phase G)
- [ ] Update `docs/gui_bosonplotter.md:58-66` Data Table section to describe `tblUnits` + `tblData` split
- [ ] Add usage example to `+bosonPlotter/resolveStyle.m` docstring (item 4.5)
- [ ] Add `convertMagUnits` example to `+utilities/README.md` (item 4.5)

**7c — Package READMEs (~3 hours, mostly mechanical):**
- [ ] Create `+fitting/README.md` from scratch (biggest gap — 19 files, no README)
- [ ] Rewrite `+bosonPlotter/README.md` to cover all 37 modules grouped by subsystem
- [ ] Add `template` + `palette` rows to `+styles/README.md` with examples
- [ ] Expand `+plotting/README.md` with the 12 missing functions, examples for `polarContour` + `ternaryPlot`
- [ ] Expand `+utilities/README.md` with 22 missing functions under Baselines / Statistics / Errors / Signal / Magnetometry subsections
- [ ] Expand `+parser/README.md` with 9 missing parsers (Microscopy/EM subsection)
- [ ] Expand `+imaging/README.md` with Morphology/Segmentation section + `eelsSVD`
- [ ] Add `batchPlot`, `dataConnector`, `generateReport` to `+scripts/README.md`

**7d — Thin function docstrings (~1 hour):**
- [ ] `+bosonPlotter/multiPanel.m` — add Inputs block
- [ ] `+bosonPlotter/peakCallbacks.m` — add Outputs block listing handles
- [ ] `+bosonPlotter/renderPlot.m` — add Inputs block describing `ctx` struct
- [ ] `+bosonPlotter/filterRows.m` — document `expression` format + example
- [ ] `+bosonPlotter/colorMaps.m` — list supported names
- [ ] `+parser/computeQSpace.m` — document `map` input/output fields
- [ ] `+parser/resolveParser.m` — add Outputs block

---

## Notes

- All four agents ran in isolated worktrees at HEAD `c9fcb0d`. Worktrees were
  read-only and auto-cleaned on completion.
- The docs agent's full report is retrievable via `SendMessage(to:
  "a657e9d3d989c40e1", …)` until its context expires.
- Other agent IDs (for follow-up questions):
  - Usability: `ac616403015dbc61d`
  - Refactor/perf: `ad08bd8d467ce3b1c`
  - UI: `aaa031ed6061ed81d`
  - Docs (full): `ae92af09f912334de` (replaces partial `a657e9d3d989c40e1`)
- Any items addressed by future commits should be checked off in the
  Prioritized execution order section above, not deleted — the list is
  more useful as a historical record of what was considered.
