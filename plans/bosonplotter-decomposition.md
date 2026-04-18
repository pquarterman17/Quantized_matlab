# BosonPlotter Decomposition Plan

Systematic reduction of BosonPlotter.m to stay permanently below MATLAB's parser
complexity ceiling. The file currently has 14,349 lines and 346 nested functions
inside a single function closure. MATLAB's undocumented AST limit trips at roughly
this count, meaning we cannot add even one new nested function without extracting
something first.

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-17 (undo callbacks extracted + #12/#19 audited — 295 nested fns, 50 slots headroom)

---

## Context

### How the pieces fit together

```
BosonPlotter.m (14,349 lines)
  ├── Lines 1-13,366: main function closure
  │     ├── 346 nested functions (THIS IS THE PROBLEM)
  │     ├── 218 unique GUI widget handle variables (closure-captured)
  │     ├── appData (handle class: AppState.m) — shared state
  │     └── 13 one-liner delegates to peakCallbacks (redundant)
  ├── Lines 13,367-14,349: 40 local (file-scope) functions — FREE, don't count
  └── +bosonPlotter/ package: 40 extracted modules (16,626 lines)
```

The parser ceiling depends on total AST complexity (tokens x nesting depth x scope
chain length), not a fixed function count. At the current file size (~14k lines),
the threshold sits around 346-348 nested functions. It was previously believed to be
384 but dropped as the file grew.

### Why extraction is hard today

Every nested function captures the full closure — including 218 widget handles.
When we extract a function to `+bosonPlotter/`, we must explicitly pass every widget
it references. The top 3 hardest functions touch 23, 25, and 54 widgets respectively.
This makes extraction a per-function battle over argument lists.

### The key insight

Most nested functions only use a small subset of the 218 widgets. A census of the
30 largest functions shows:

| Widget deps | Functions | Example |
|-------------|-----------|---------|
| 0           | ~8        | saveConsolidatedNeutronCSV, computeAutoWaterfallSpacing |
| 1-5         | ~6        | loadFilePaths, refreshDataTable |
| 6-15        | ~8        | draw2DMap, extract2DBoxIntegral, onShowAdvancedMenu |
| 16-30       | ~4        | applyParserAnalysisConfig (23), onApplyCorrections (25) |
| 30+         | ~2        | updateControlsForActiveDataset (54) |

Functions with 0-5 widget deps can be extracted trivially today. Functions with
6-15 can be extracted with a targeted handle struct. Functions with 16+ need a
full `ui` struct approach.

### Dependency map

- Item 1 (delete delegates) is independent — pure deletion, no architecture change
- Items 2-6 (Tier 1 extractions) are independent of each other
- Item 7 (ui struct) is a prerequisite for items 8-10
- Items 8-10 depend on item 7 but are independent of each other
- Item 11 (delegate callsite rewrite) can happen any time after item 1

---

## Tier 1 — High Impact

Immediate headroom: delete redundant delegates and extract zero/low-widget functions.
Target: free 20+ nested function slots.

1. **Delete 13 redundant peak callback delegates** — one-line description
   - The 13 `function onX(s,e), peakCb.onX(s,e); end` delegates at lines 4534-4547
     are fully redundant: every button is rewired to `peakCb.*` directly at lines
     2201-2223, and none appear in the `api` struct.
   - `refreshPeakTable()` is called from 8 nested functions — replace with
     `peakCb.refreshPeakTable()` at each callsite.
   - `@onAutoPeak` and `@onManualPeakAdd` at lines 1120/1127 are immediately
     overwritten at lines 2201-2202 — change initial wiring to `@(~,~)[]` or
     remove and rely on the rewiring.
   - **Net: -13 nested functions, 0 lines of real logic removed.**

2. **Extract `saveConsolidatedNeutronCSV`** (173 lines, 0 widgets) — pure data
   transformation that writes polarized neutron CSV. Only needs `appData` and the
   data struct. Zero GUI coupling.

3. **Extract `refreshDataTable`** (177 lines, 2 widgets: tblData, tblUnits) — syncs
   the spreadsheet panel. Pass `appData` + the two table handles.

4. **Extract `computeAutoWaterfallSpacing`** (85 lines, 0 widgets) — pure
   computation of Y-offset spacing for waterfall plots. Only reads `appData.datasets`.

5. **Extract `onEstimateBaseline`** (95 lines, few widgets) — baseline estimation
   dialog. Opens its own uifigure so most logic is self-contained.

6. **Extract `onDatasetAlgebra`** (106 lines) — dataset math dialog. Self-contained
   uifigure dialog with minimal widget deps from the main GUI.

## Tier 2 — Medium Impact

Extract medium-widget functions with targeted handle passing. Each function receives
a small struct of the specific handles it needs.

7. ~~**Extract `draw2DMap`**~~ (171 lines, 11 widgets) — 2D heatmap rendering. Extracted to `+bosonPlotter/draw2DMap.m`, delegate passes widget struct.

8. ~~**Extract `extract2DBoxIntegral`**~~ (128 lines, 11 widgets) — box integration on 2D maps. Extracted to `+bosonPlotter/extract2DBoxIntegral.m`.

9. ~~**Extract `extract2DArcIntegral`**~~ (107 lines) — arc/azimuthal integration. Extracted to `+bosonPlotter/extract2DArcIntegral.m`.

10. ~~**Extract `onBGMouseUp`**~~ (120 lines) — background fitting mouse-up handler. Extracted to `+bosonPlotter/onBGMouseUp.m`.

11. **Extract `onAutoMagCorrections`** (115 lines) — automatic magnetometry
    correction logic. Needs correction panel widgets. Still a nested function.

12. ~~**Rewrite delegate callsites**~~ (2026-04-17) — audit complete: no residual `@onPeak*` handles; all 6 `refreshPeakTable()` callsites already route through `peakCb.*`; 3 `peakCb.*` wrappers at api-export (lines 2670, 2671, 2720) are legitimate, not delegate clutter.

## Tier 3 — Nice-to-Have

Introduce a `ui` struct to enable extraction of the hardest remaining functions.
These are the largest nested functions but they touch 20-54 widgets each.

13. ~~**Introduce `ui` widget handle struct**~~ — `ui = struct()` built after all widgets created, aggregating 60+ handles. Passed to `+bosonPlotter/` helpers (onApplyCorrections, draw2DMap, etc.).

14. **Extract `applyParserAnalysisConfig`** (243 lines, 23 widgets) — sets up
    corrections panel defaults per parser type. Receives `ui` + `appData`. Still a nested function.

15. ~~**Extract `onApplyCorrections`**~~ (209 lines, 25 widgets) — extracted to `+bosonPlotter/onApplyCorrections.m`. Receives `appData`, `ui`, `callbacks`.

16. **Extract `updateControlsForActiveDataset`** (188 lines, 54 widgets) — syncs
    all panel widgets to the active dataset. The hardest extraction — touches nearly
    every widget. Still a nested function.

17. **Extract `onPlotTemplates`** (163 lines) — plot template save/load dialog with
    4 nested sub-functions. Still a nested function.

18. ~~**Extract table model callbacks**~~ (2026-04-17, commit b0d3804) — tableCallbacks.m, 321→298 fns, 47 slots headroom

19. ~~**Extract neutron sibling propagation**~~ (2026-04-17) — already out of BosonPlotter.m; the cross-polarization propagation block lives in `+bosonPlotter/onApplyCorrections.m:148-211` (moved as part of the onApplyCorrections extraction 2026-04-12). No nested-fn slots to reclaim.

20. ~~**Extract undo state helpers**~~ (2026-04-17) — onUndo, onRedo, updateUndoButtons extracted to `+bosonPlotter/undoCallbacks.m`; struct stored on `appData.undoCb` and wired via handle-class reference so anonymous callbacks resolve at call time. 3 slots freed (298→295).

---

## Budget

Current: 346 nested functions, ~0 headroom.

| Action | Functions removed | Cumulative headroom |
|--------|-------------------|---------------------|
| Tier 1 items 1-6 | ~19 | ~19 |
| Tier 2 items 7-12 | ~7 | ~26 |
| Tier 3 items 13-17 | ~9 (+ sub-fns) | ~35+ |

Tier 1 alone should provide enough headroom for the next several months of
feature development. Tier 2 extends that to a comfortable margin. Tier 3 is
insurance for the long term.

---

## Testing strategy

- Run `BosonPlotter(Visible='off'); close(gcf)` after each extraction to verify parsing
- Run `powershell -ExecutionPolicy Bypass -File tests/run_gui_hidden.ps1 gui` after
  each tier to verify no regressions
- For extractions that touch corrections or data import paths, also run
  `runAllTests(Group="parser")` to verify data flow

---

## Completed

- ~~**Delete 13 redundant peak callback delegates**~~ (2026-04-12) — all 13 one-liner delegates removed, 8 `refreshPeakTable()` callsites rewritten to `peakCb.refreshPeakTable()`, 3 initial button wirings changed to `@(~,~)[]`
- ~~**Extract `saveConsolidatedNeutronCSV`**~~ (2026-04-12) — 172 lines → 4-line delegate, 0 widget deps
- ~~**Extract `computeAutoWaterfallSpacing`**~~ (2026-04-12) — 82 lines → 4-line delegate, lbY/ddScaleY passed as args
- ~~**Extract `refreshDataTable`**~~ (2026-04-12) — 177 lines → delegate, tblData/tblUnits/lblTableUnits/lblTableStats passed
- ~~**Extract `onEstimateBaseline`**~~ (2026-04-12) — 95 lines → delegate, opens own uifigure dialog
- ~~**Extract `onDatasetAlgebra`**~~ (2026-04-12) — 106 lines → delegate, opens own uifigure dialog
- ~~**Extract `draw2DMap`**~~ (2026-04-12) — 171 lines → `+bosonPlotter/draw2DMap.m`, widget struct passed
- ~~**Extract `extract2DBoxIntegral`**~~ (2026-04-12) — 128 lines → `+bosonPlotter/extract2DBoxIntegral.m`
- ~~**Extract `extract2DArcIntegral`**~~ (2026-04-12) — 107 lines → `+bosonPlotter/extract2DArcIntegral.m`
- ~~**Extract `onBGMouseUp`**~~ (2026-04-12) — 120 lines → `+bosonPlotter/onBGMouseUp.m`
- ~~**Introduce `ui` widget handle struct**~~ (2026-04-12) — 60+ widget handles aggregated into `ui` struct after widget creation
- ~~**Extract `onApplyCorrections`**~~ (2026-04-12) — 209 lines → `+bosonPlotter/onApplyCorrections.m`, receives `appData`, `ui`, `callbacks`

**Result (Tier 1):** 346 → 331 nested functions (−15), 14,349 → 13,737 lines (−612), 40 → 45 extracted modules. 16/16 GUI tests pass.
**Result (Tier 2-3):** Additional 5 extractions (draw2DMap, extract2DBox/Arc, onBGMouseUp, onApplyCorrections) + `ui` struct introduced.
- ~~**Extract analysis callbacks**~~ (2026-04-16) — 19 functions (620 lines) → `+bosonPlotter/analysisCallbacks.m`. Uses ctx/unpack pattern + `anaCb` struct. 4 thin stubs remain for toolbar-wired callbacks. 342 → 321 total (23 slots headroom). 19/19 GUI suites pass.
- ~~**Extract undo callbacks (item 20)**~~ (2026-04-17) — `onUndo`, `onRedo`, `updateUndoButtons` → `+bosonPlotter/undoCallbacks.m`. `undoCb` struct stored on `appData` (handle class) so anonymous callbacks at toolbar / keyboard handlers resolve at call time. 298 → 295 nested fns.
- ~~**Neutron sibling propagation already extracted (item 19)**~~ (2026-04-17) — lives in `+bosonPlotter/onApplyCorrections.m:148-211`; moved as part of onApplyCorrections extraction 2026-04-12. No separate extraction needed.
- ~~**Audit delegate callsites (item 12)**~~ (2026-04-17) — grep confirmed no residual `@onPeak*` handles; all `refreshPeakTable()` callsites use `peakCb.*`; remaining api-export wrappers at lines 2670–2720 are legitimate.
