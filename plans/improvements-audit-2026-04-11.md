# Improvements Audit

Comprehensive codebase audit produced by four parallel subagents (Usability, Refactor/Perf,
UI, Docs) running in isolated worktrees at HEAD `c9fcb0d`. Covers `quantized_matlab` —
BosonPlotter, FermiViewer, materialsCalcGUI, xrdConvertGUI, and all `+` packages.

**Status:** Active
**Created:** 2026-04-11
**Updated:** 2026-04-12 (W1 complete)

---

## Context

### How the pieces fit together
This audit spans the full toolbox. The four workstreams are largely independent:

- **W1 — Usability** targets BosonPlotter user-facing features (Recent Files, notes, etc.)
- **W2 — Refactor/Perf** targets BosonPlotter.m internals (lineCache, struct copy-back, extraction)
- **W3 — UI** targets layout/theming/tooltips across all GUIs
- **W4 — Docs** targets README coverage, stale docs, and thin docstrings
- **W5 — Version Compatibility** removes dead pre-R2022b guards and adds version-branching for newer MATLAB features

### Data / control flow
```
BosonPlotter.m (13,659 lines, 317 nested functions)
  ├── appData (handle class: AppState.m) ← W2 touches this layer
  ├── +bosonPlotter/ (37 extracted modules) ← W2 extraction targets
  ├── GUI widgets (347 in BP, 208 in FV, 377 in matCalc) ← W3 tooltip/layout targets
  └── corrections → renderPlot → overlays pipeline ← W1 usability features plug in here

Package READMEs (8 packages) ← W4 documentation targets
Feature docs (docs/*.md) ← W4 stale doc fixes
```

### Dependency map
- W1 (Usability) and W3 (UI) are independent of each other
- W2 items 7-8 (captureUndoState, neutronSiblings extraction) unblock cleaner W1 implementations
- W2 item 11 (Dataset handle class) touches everything — do last
- W4 (Docs) is fully independent — can run in parallel with any other workstream
- Within W2: item 5 (lineCache) should go first (regression fix)

---

## Cross-cutting priorities

| # | Item | Workstream | Why first |
|---|------|------------|-----------|
| 5 | lineCache fast-path restore | W2 — Perf | Regression from Phase G — every replot is full-cost |
| 6 | CSV export with writematrix | W2 — Perf | 10-100x speedup on big files |
| 21 | Plot Style dialog scroll/resize | W3 — UI | Apply button unreachable on laptops |
| 26 | materialsCalcGUI tooltips | W3 — UI | 377 widgets, zero tooltips |
| 1 | Recent Files menu | W1 — Usability | Single biggest friction reducer |

---

## W1 — Usability

Features that reduce friction on common BosonPlotter tasks.

### Tier 1 — High Impact

1. ~~**Recent Files / Recent Folders menu**~~ — done, see Completed section

2. ~~**Per-dataset notes / metadata annotations**~~ — done, see Completed section

3. ~~**Rename / relabel dataset from list**~~ — done, see Completed section

4. ~~**Autosave / crash-recovery session**~~ — done, see Completed section

### Tier 2 — Medium Impact

5. ~~**Bulk-apply corrections to selected/all datasets**~~ — already implemented (`btnApplyAll` + `onApplyCorrectionsAll`)

6. ~~**Correction presets (named, saved)**~~ — done, see Completed section

7. ~~**Legend location dropdown**~~ — done, see Completed section

8. ~~**Reload-from-disk button**~~ — done, see Completed section

9. ~~**xrdConvertGUI: remember last folders**~~ — done (Lane B agent)

### Tier 3 — Nice-to-Have

10. ~~**Data-cursor pin/lock**~~ — done, Ctrl+click pins persistent marker with cycling colors

11. ~~**Quick unit-prefix cycling**~~ — done, Alt+Up/Down cycles Y prefix; Alt+Shift+Up/Down for X

12. ~~**Extension-specific file filter presets**~~ — done, grouped into XRD/VSM/CSV/Excel/Microscopy/Images/Neutron

13. ~~**"Copy Row as MATLAB code" for materialsCalcGUI**~~ — done (Lane F agent): history panel + context menu + 4 tabs wired

14. ~~**Keyboard shortcut for "next peak"**~~ — done, Up/Down/Enter/Delete in Peak Analysis window via peakCallbacks.onKeyPress

15. ~~**Dataset color swatch in list**~~ — done, colored ● prefix + uistyle FontColor matching plot line color

---

## W2 — Refactor / Performance

Code health, hot-loop fixes, and extraction targets in BosonPlotter.m.

### Tier 1 — High Impact

16. ~~**Cache colormap dispatch**~~ — done: only 1 of 13 sites remained (rest already routed through `bosonPlotter.colorMaps`)

17. ~~**Hoist static `rCtx_` fields**~~ — done: 17 static fields (fig, 7 widget handles, 9 function handles) allocated once into `rCtxStatic_`, merged via loop at each replot

18. **Extract `applyToNeutronSiblings.m`** — cross-polarization loop at ~5806-5854 is ~48 lines, deeply coupled to corrections pipeline. Low priority.

19. ~~**Extract `captureUndoState.m`**~~ — already deduplicated: `pushUndoCorrectionEntry` exists with 2 call sites (not 60 as originally claimed)

20. **Promote `Dataset` to handle class** — 42 copy-back sites remain. Deferred: high-risk (struct→handle semantics change), requires per-site verification and session serialization rewrite.
    - [ ] Create `+bosonPlotter/Dataset.m` handle class
    - [ ] Migrate high-churn fields first
    - [ ] Update all 42 copy-back sites

### Tier 2 — Medium Impact

21. ~~**Audit silent `try/catch` blocks**~~ — done: 9 empty catch blocks audited; 2 converted to `logGUIError` (unit conversion, colormap resolution), 7 confirmed as intentional silent-fail (zoom, pan, template listing, file size check, figure close)

22. ~~**Cache `rebuildDatasetList` badge strings**~~ — already implemented: badges computed inline per rebuild (no `displayString` field needed since `getParserBadge` is fast)

23. ~~**Hoist Excel sheet-name fallback**~~ — done: `excelExts` moved outside the file-loading `for` loop

24. ~~**Replace `findall(ax,'Tag',...)` chains**~~ — done: overlay cleanup consolidated to single `findall(-regexp)`, smooth preview uses stored handle directly

### Tier 3 — Nice-to-Have

25. ~~**Cache smoothing method map**~~ — done: `persistent methMap` with `isempty` guard

26. ~~**Simplify `num2cell(1:N)` for listbox ItemsData**~~ — skipped: `Multiselect='on'` uilistbox requires cell array ItemsData

27. ~~**Single `findall('-regexp','Tag',...)` for overlay cleanup**~~ — done: 5 sequential `delete(findall)` calls consolidated to single `-regexp` pattern

---

## W3 — UI

Layout, interaction, theming, tooltips, and accessibility across all GUIs.

### Tier 1 — High Impact

28. ~~**Figure Builder scroll/resize**~~ — done, see Completed section

29. **Dialog theme propagation** — popup dialogs leak light mode when parent is dark. — popup dialogs leak light mode when parent is dark.
    `templateDialog.m:46-78`, Dataset Math, Plot Templates, Batch Figure Export, Integrate
    — none read `appData.theme`. Add shared `applyDialogTheme(dlg)` helper

30. ~~**xrdConvertGUI resize + contrast**~~ — done (Lane B agent): Resize='on', min 480x600

31. ~~**materialsCalcGUI nav overhaul**~~ — done (Lane B agent): uitree with 5 categories

32. ~~**materialsCalcGUI keyboard shortcuts**~~ — already implemented (WindowKeyPressFcn + primaryBtnMap)

33. ~~**materialsCalcGUI theme consistency**~~ — done (Lane B agent): full dark theme with applyDarkPanelTheme()

### Tier 2 — Medium Impact

34. **Corrections panel header click-target** — label-styled `uibutton` with tiny
    triangle glyph. Add hover background via `MouseEnterFcn`

35. **Collapse empty Y2 listbox** — `lbY2` always visible with `'(none)'` placeholder.
    Collapse row to 0 height when no Y2 channel selected

36. ~~**Rename "WF" checkbox**~~ — done, changed to "Waterfall"

37. ~~**Expand Save/Export by default**~~ — done, sectionCollapsed.saveTools = false

38. **Advanced Analysis filter** — 26-row menu. Add top `uieditfield` filter

39. ~~**FermiViewer toolbar overflow**~~ — done (Lane E agent)

40. ~~**FermiViewer EDS height cap**~~ — done (Lane E agent)

41. ~~**xrdConvertGUI tooltips**~~ — done (Lane E agent)

### Tier 3 — Nice-to-Have

42. **Corrections panel label columns** — 80px wasteful for 6-12 char labels, drop to 60px

43. **Status bar readability** — 9pt gray on dark, below WCAG AA. Use 10pt + lighter color

44. **Numeric waterfall spacing field** — `efWaterfallSpacing` is `text` not `numeric`

45. **Keyboard focus shortcuts** — Ctrl+L for dataset list, Ctrl+Y for Y selector

46. **Multi-select delete confirmation** — `uiconfirm` when `numel(selected) > 1`

47. **Button palette consistency** — BosonPlotter 8 roles, FermiViewer 4,
    materialsCalcGUI 3. Extract shared `+styles/buttonPalette.m`

---

## W4 — Documentation

Stale docs, missing feature docs, thin package READMEs, and function docstrings.

### Tier 1 — High Impact

48. **Plot Style Dialog docs** — no user-facing docs for Phase G rollout. Add section to
    `docs/gui_bosonplotter.md` covering 4-layer precedence cascade, palette picker, scopes

49. **Data table split docs** — `docs/gui_bosonplotter.md:58-66` describes old single-table
    layout. Update for `tblUnits` + `tblData` architecture with ~10x scroll speedup rationale

50. ~~**Expand `+bosonPlotter/README.md`**~~ — done (Lane C agent): 37 functions in 8 subsections

51. ~~**Expand `+utilities/README.md`**~~ — done (Lane C agent): 7 new subsections

52. ~~**Expand `+plotting/README.md`**~~ — done (Lane C agent): 12 functions added

### Tier 2 — Medium Impact

53. ~~**Expand `+parser/README.md`**~~ — done (Lane C agent): EM parsers + internal helpers

54. ~~**Add `template` + `palette` to `+styles/README.md`**~~ — done (Lane C agent)

55. ~~**Expand `+imaging/README.md`**~~ — done (Lane C agent): morphology/segmentation + eelsSVD

56. ~~**Add 3 entries to `+scripts/README.md`**~~ — done (Lane C agent)

57. **`resolveStyle` usage example** — add 3-line example to docstring showing
    `resolveStyle → applyDsOverride → applyPostRenderStyle`

58. **`convertMagUnits` example** — add to `+utilities/README.md`

### Tier 3 — Nice-to-Have

59. **Thin function docstrings** — add Inputs/Outputs blocks to:
    - [ ] `multiPanel.m` — document `datasets` cell array and options struct
    - [ ] `peakCallbacks.m` — document returned `cb` struct of function handles
    - [ ] `renderPlot.m` — document `ctx` struct required fields
    - [ ] `filterRows.m` — document expression format with example
    - [ ] `colorMaps.m` — list supported colormap names
    - [ ] `computeQSpace.m` — document `map` input/output fields
    - [ ] `resolveParser.m` — document result struct fields

---

## W5 — Version Compatibility

Enforce R2022b floor, remove dead guards for pre-R2022b, and branch for newer
MATLAB where it provides a meaningfully better solution (with Command Window notice
on the fallback path per CLAUDE.md convention).

### Tier 1 — High Impact

60. ~~**Remove dead version guards**~~ — `copygraphics`, `exportgraphics`, `uistyle`/`addStyle`/`removeStyle` all predate R2022b; guards already removed in prior sessions. FermiViewer clipboard copy also cleaned up (inverted print/copygraphics replaced with copygraphics-primary)

61. ~~**Native line alpha on R2024b+**~~ — `applyAlphaToLine.m` already had `isMATLABReleaseOlderThan('R2024b')` branch; added one-time `fprintf` notice on fallback path per CLAUDE.md convention; test updated to cover both branches

### Tier 2 — Medium Impact

62. **`containers.Map` → `dictionary` migration** — `dictionary` is R2022b+ (at our floor), typed, and faster; 20 files use `containers.Map`
    - [ ] Audit each of the 20 call sites — some may need `containers.Map` for heterogeneous value types (`dictionary` requires homogeneous)
    - [ ] Migrate eligible sites (homogeneous value type) to `dictionary`
    - [ ] Leave `containers.Map` where heterogeneous values are required (e.g. `'KeyType','char','ValueType','any'`)

### Tier 3 — Nice-to-Have

63. **Future version opportunities to watch** — not actionable now, but worth branching when the codebase encounters them:
    - `uispreadsheet` (R2025a) — native spreadsheet widget for DataWorkspace if/when we raise the floor
    - `backgroundPool` / `parfeval` improvements (R2023b+) — async parser loading
    - `uicolorpicker` (if/when introduced) — replace `uisetcolor` in Plot Style dialog

---

## Known systemic issues

- **BosonPlotter.m is 13,659 lines / 317 nested functions** — three agents flagged the
  monolith. Policy: new features go in `+bosonPlotter/` by default.
- **Literal numbers in docs are maintenance time-bombs** — "23 vs 24 models" drift
  triggered reconciliation. Same risk for "25+ parsers", "55+ processing tools", "13 tabs".
  Use indirect references pointing at a single source of truth.
- **Worktree directories get OneDrive-locked** — `git worktree remove --force` fails.
  Orphaned metadata under `.git/worktrees/` is harmless.

---

## Completed

- ~~**lineCache fast-path restore**~~ (2026-04-11) — moved invalidation out of regular replot prelude
- ~~**CSV export with writematrix**~~ (2026-04-11) — replaced per-row sprintf+fprintf loop
- ~~**Delete dead `%{...%}` block**~~ (2026-04-11) — 176-line commented curve-fitting block removed
- ~~**Delete duplicate safeEvalMathExpr**~~ (2026-04-11) — removed local stub, kept +bosonPlotter/ version
- ~~**Plot Style dialog scroll/resize**~~ (2026-04-11) — dynamic `dlgH = min(780, screenH-120)`, `Resize='on'`, root grid `Scrollable='on'`, 4 regression assertions
- ~~**materialsCalcGUI tooltips**~~ (2026-04-11) — 108 of ~159 eligible input widgets got physics-accurate tooltips
- ~~**Architecture.md stale fixes**~~ (2026-04-11) — `drawToAxes → renderPlot`, added `styleOverrides`/`activeTemplate`, expanded Extracted Subsystems table
- ~~**CLAUDE.md Detailed Documentation table**~~ (2026-04-11) — added +plotting, +styles, +fitting rows
- ~~**Create `+fitting/README.md`**~~ (2026-04-11) — 19 functions + 23-model catalog, biggest doc gap closed
- ~~**Model-count reconciliation**~~ (2026-04-11) — 5 docs switched to indirect references; canonical count is 23 via `numel(fitting.models())`
- ~~**Figure Builder scroll/resize**~~ (2026-04-11) — dynamic height `min(600, screenH-120)`, `Resize='on'`, root grid `Scrollable='on'`
- ~~**Recent Files menu**~~ (2026-04-11) — dropdown next to Add Files, persisted to `prefdir/boson_recent.mat`, MRU-first, deduplicated, capped at 10, stale-entry cleanup, test K55
- ~~**Per-dataset notes**~~ (2026-04-11) — `ds.notes` field, "Notes..." context menu, pencil indicator in list, note shown in tooltip, persists in session. Test K56
- ~~**Rename dataset**~~ (2026-04-11) — "Rename..." context menu, updates displayName + legendName, refreshes legend. Test K57
- ~~**Autosave / crash-recovery**~~ (2026-04-11) — `+bosonPlotter/autosave.m` static class: 2-min timer saves datasets to `prefdir/boson_autosave.mat`, recovery prompt on startup, cleanup on clean exit. Zero new nested functions in BosonPlotter.m
- ~~**Bulk-apply corrections**~~ — already existed: `btnApplyAll` + `onApplyCorrectionsAll`
- ~~**xrdConvertGUI folder memory**~~ (2026-04-11) — getpref/setpref for last input/output dirs, min size enforcement
- ~~**xrdConvertGUI resize + contrast**~~ (2026-04-11) — Resize='on', min 480x600, white FontColor on Convert
- ~~**materialsCalcGUI uitree nav**~~ (2026-04-11) — replaced listbox with uitree, 5 categories, all expanded by default
- ~~**materialsCalcGUI keyboard shortcuts**~~ — already existed: WindowKeyPressFcn + primaryBtnMap
- ~~**materialsCalcGUI dark theme**~~ (2026-04-11) — full dark theme with applyDarkPanelTheme() utility
- ~~**Package READMEs**~~ (2026-04-11) — all 7 expanded: +bosonPlotter (37 funcs), +utilities (38), +plotting (15), +parser (27), +styles (4), +imaging (52), +scripts (7)
- ~~**Correction presets**~~ (2026-04-11) — `+bosonPlotter/correctionPresets.m` static class, dropdown+save+delete in corrections panel row 29, persisted to `prefdir/boson_corr_presets.mat`
- ~~**Legend location dropdown**~~ (2026-04-11) — replaced checkbox with dropdown (best/NE/NW/SE/SW/EastOutside/off), wired to `styleOverrides.legendLocation`
- ~~**Reload from disk**~~ (2026-04-11) — "Reload from Disk" context menu entry, re-imports via guiImport preserving corrections state
- ~~**FermiViewer toolbar overflow**~~ (2026-04-11) — removed separator labels, raised ColumnSpacing, min 32px buttons
- ~~**FermiViewer EDS height cap**~~ (2026-04-11) — toggleSection caps at figH*0.6
- ~~**xrdConvertGUI tooltips**~~ (2026-04-11) — tooltips on all dropdowns and controls
- ~~**Plot Style Dialog docs**~~ (2026-04-11) — 4-layer cascade, palette picker, apply-to scopes
- ~~**Data table split docs**~~ (2026-04-11) — tblUnits + tblData architecture documented
- ~~**Function docstrings**~~ (2026-04-11) — multiPanel, peakCallbacks, renderPlot, filterRows, colorMaps, computeQSpace, resolveParser, resolveStyle, convertMagUnits
- ~~**Data-cursor pin/lock**~~ (2026-04-12) — Ctrl+click in cursor mode pins persistent diamond markers with cycling colors; cleared on toggle-off
- ~~**Quick unit-prefix cycling**~~ (2026-04-12) — Alt+Up/Down cycles Y-axis SI prefix (pico→…→Giga); Alt+Shift for X-axis
- ~~**Keyboard shortcut for "next peak"**~~ (2026-04-12) — peakCallbacks.onKeyPress: Up/Down navigate table, Enter fits, Delete removes
- ~~**Dataset color swatch in list**~~ (2026-04-12) — ● prefix + uistyle FontColor per item matching resolved plot color (override or default palette)
- ~~**Hoist static rCtx_ fields**~~ (2026-04-12) — 17 static fields (fig, widget handles, function handles) allocated once into `rCtxStatic_`, merged via fieldnames loop per replot
- ~~**Audit silent try/catch**~~ (2026-04-12) — 9 empty catch blocks audited; 2 fixed with logGUIError, 7 confirmed intentional
- ~~**Hoist Excel excelExts**~~ (2026-04-12) — moved outside per-file loop
- ~~**Cache smoothing method map**~~ (2026-04-12) — persistent + isempty guard
- ~~**findall overlay consolidation**~~ (2026-04-12) — 5 sequential calls → single `-regexp`; smooth preview → stored handle
- ~~**Colormap cache verified**~~ (2026-04-12) — only 1 of 13 sites remained; bosonPlotter.colorMaps handles the rest
- ~~**captureUndoState verified**~~ (2026-04-12) — already deduplicated to pushUndoCorrectionEntry (2 call sites)
