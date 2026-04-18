# Backlog — Open Work Across All Plans

Single-source dashboard aggregating every open top-level item from `plans/*.md`.
Regenerate whenever a plan changes; archived plans are excluded automatically.

**Last regenerated:** 2026-04-17

**How to read this file:**
- Items are grouped by **tier** (impact), then by **plan source**.
- Each line: `[ ] #<num>` plan → `title` — optional one-line context.
- Strike an item (`~~[ ] ...~~`) when it's done, or move the whole line to the plan's Completed section.
- If a plan's remaining items all ship, set its header `**Status:** Complete` and move the plan to `plans/archive/`.

---

## Tier 1 — High Impact (open)

### Known bugs — `plans/known-bugs.md`
- [ ] **#1** Pixel3D box-integration ROI broken — rectangle disappears after first integration; drag-hold not tracked
- [ ] **#2** Per-dataset plot state resets on toggle — log/grid/aspect/colormap/cLim revert on dataset switch
- [ ] **#3** Copy/Save plot leaks dark-mode background — need transparent PNG export path
- [ ] **#10** FermiViewer measurement stuck yellow/filled after drag — `deselectMeasurement` not called in `dragRelease` (FermiViewer.m:5806); also `MarkerFaceColor` regression
- [ ] **#11** `imaging.lineProfile` string dispatch crash — relax `arguments` block to accept `char|string` or convert at call sites

### BosonPlotter decomposition — `plans/bosonplotter-decomposition.md`
- [ ] **#1** Delete 13 redundant peak callback delegates
- [ ] **#2** Extract `saveConsolidatedNeutronCSV` (173 lines)
- [ ] **#3** Extract `refreshDataTable` (177 lines, 2 widgets)
- [ ] **#4** Extract `computeAutoWaterfallSpacing` (85 lines, pure)
- [ ] **#5** Extract `onEstimateBaseline` (95 lines)
- [ ] **#6** Extract `onDatasetAlgebra` (106 lines, self-contained dialog)

### FermiViewer decomposition — `plans/fermiviewer-decomposition-2026-04-16.md`
- [ ] **#1** Infrastructure: create `+emViewer/` + ui struct (done for diffraction/annotation/export; not yet for EELS/EDS)
- [ ] **#2** Extract EELS subsystem (~14 nested fns freed)
- [ ] **#3** Extract EDS subsystem (~12 nested fns freed)

### Codebase — `plans/codebase-roadmap.md`
- [ ] **#1** Continue `+bosonPlotter/` extraction — drive parent below 8k lines

### Origin parity — `plans/origin-feature-gap.md` (Python port — MATLAB side complete)
- [ ] **#1** AIC/BIC/F-test fit comparison → Python
- [ ] **#2** Plot templates → Python
- [ ] **#3** Box/Violin/Bee-Swarm plots → Python
- [ ] **#4** Auto-recalculate on parameter change → Python
- [ ] **#5** Global parameter sharing → Python
- [ ] **#6** Confidence/prediction bands → Python

### DataWorkspace Python port — `plans/dataworkspace-python-port.md`
- [ ] **#1** WorkspaceModel → Python
- [ ] **#2** ColumnRoles → Python
- [ ] **#3** FormulaEngine → Python

### Docs (retroactive) — `plans/retroactive-docs.md`
- [ ] **#6** Spectroscopy theory doc
- [ ] **#7** Thin films theory doc
- [ ] **#8** Electrochemistry theory doc
- [ ] **#9** Fitting theory doc
- [ ] **#10** Statistics theory doc

### Parsers — `plans/parser-roadmap.md` (Paused: blocked on example files)
- [ ] **#1** `importRaman` — Horiba LabSpec / Renishaw ASCII

---

## Tier 2 — Medium Impact (open)

### Known bugs — `plans/known-bugs.md`
- [ ] **#4** Box-integration file naming `{source}_boxInt_along{dir}_…`
- [ ] **#5** Accept `all`/`:`/`*`/empty for full-range in box integration
- [ ] **#6** Legend editor — full editor with inline + dialog entry
- [ ] **#7** Legend edits persist per-dataset (uses #2's plotState)
- [ ] **#8** Pre-populate `all` placeholder in box-integration GUI
- [ ] **#13** `FontColor` warning on `uitable` during template match (noisy)
- [ ] **#14** Log-scale `Negative data ignored` + `Background transparency not supported` warning flood
- [ ] **#16** FermiViewer right-side tools panel overcrowded — buttons overlap on standard sizes

### BosonPlotter decomposition — `plans/bosonplotter-decomposition.md`
- [ ] **#11** Extract `onAutoMagCorrections` (115 lines)
- [ ] **#12** Rewrite delegate callsites (after #1)

### FermiViewer measurement polish — `plans/fermiviewer-measurement-polish-2026-04-17.md`
- [ ] **#4** Expose symbol + color in Measurement panel (optional controls)
- [ ] **#5** Annotation selection + editing — right-panel sync remaining

### DataWorkspace — `plans/data-workspace.md`
- [ ] **#7** Shared model migration — complete `appData.datasets` read-through (PARTIAL)

### Origin parity (Python) — `plans/origin-feature-gap.md`
- [ ] **#7** Unlimited undo → Python
- [ ] **#8** Data filter (expression rows) → Python
- [ ] **#9** Residual diagnostics → Python
- [ ] **#10** Surface / 3D fitting → Python
- [ ] **#11** Spreadsheet popup → Python
- [ ] **#12** Customizable toolbar → Python
- [ ] **#13** Drag columns to plot → Python

### DataWorkspace Python port — `plans/dataworkspace-python-port.md`
- [ ] **#4** DataWorkspaceView.vue component
- [ ] **#5** WebSocket sync
- [ ] **#6** Workspace file format

### Software gaps — `plans/software-feature-gaps.md`
- [ ] **#11** Analysis provenance log (Mantid-style operation history)
- [ ] **#12** 2D histogram / density plot
- [ ] **#13** Smart unit/symbol rendering in axis labels

### Bug reporting — `plans/bug-reporting.md` (Stage 2 deferred)
- [ ] **#6** Auto-offer on uncaught errors
- [ ] **#7** Screenshot capture (opt-in)
- [ ] **#8** Standalone `reportBug` command

### Parsers — `plans/parser-roadmap.md`
- [ ] **#2** `importOxford` — Oxford Instruments MagLab CSV
- [ ] **#3** `importOPUS` — Bruker OPUS FTIR

### Docs — `plans/retroactive-docs.md`
- [ ] **#11** Imaging theory doc
- [ ] **#12–18** Tutorial walkthroughs (magnetometry, superconductor, xrd, reflectometry, transport, eels, curve-fitting)

### Codebase — `plans/codebase-roadmap.md`
- [ ] **#2** Documentation coverage — package READMEs

---

## Tier 3 — Nice-to-Have (open)

### Known bugs — `plans/known-bugs.md`
- [ ] **#9** "Match target application background" clipboard paste (long-term replacement for #3's transparent-PNG)
- [ ] **#12** FermiViewer window title is stale — says "EM Image Viewer" should be "FermiViewer"

### FermiViewer histogram — `plans/fermiviewer-interactive-histogram.md`
- [ ] **#8** Transfer function ramp overlay on histogram
- [ ] **#9** Click-drag-on-histogram for brightness/contrast (ImageJ-style)
- [ ] **#10** Clipping indicators (red/orange tails when pixels saturate)

### FermiViewer decomposition — `plans/fermiviewer-decomposition-2026-04-16.md`
- [ ] **#7** Extract measurement subsystem (~10 nested fns, hardest — partially done via `+emViewer/measurements.m`)

### BosonPlotter decomposition — `plans/bosonplotter-decomposition.md`
- [ ] **#14** Extract `applyParserAnalysisConfig` (243 lines, 23 widgets)
- [ ] **#16** Extract `updateControlsForActiveDataset` (188 lines, 54 widgets)
- [ ] **#17** Extract `onPlotTemplates` (163 lines)
- [ ] **#19** Extract neutron sibling propagation (~45 lines)
- [ ] **#20** Extract undo state helpers

### DataWorkspace — `plans/data-workspace.md`
- [ ] **#13** Multi-dataset operations
- [ ] **#16** Remove legacy table from BosonPlotter (~400–500 line cleanup; blocks clean break)

### Dataset templates — `plans/dataset-templates.md`
- [ ] **#12** Python port contract — design document for thin_film_toolkit equivalent

### DataWorkspace Python port — `plans/dataworkspace-python-port.md`
- [ ] **#7** Shared template JSON schema (already partially done)
- [ ] **#8** Performance benchmarks

### Origin parity (Python) — `plans/origin-feature-gap.md`
- [ ] **#14** Column formulas → Python

### Bug reporting — `plans/bug-reporting.md` (Stage 2)
- [ ] **#9** Cloudflare Worker relay
- [ ] **#10** "Submit directly" button in dialog
- [ ] **#11** Rate-limit + spam protection

---

## Plans dashboard

| Plan | Status | Open items | Notes |
|------|--------|------------|-------|
| known-bugs | Active | 5 T1 / 8 T2 / 2 T3 | Highest-value batch |
| bosonplotter-decomposition | Active | 6 T1 / 2 T2 / 5 T3 | Drive parent <8k lines |
| fermiviewer-decomposition-2026-04-16 | Active | 3 T1 / 0 T2 / 1 T3 | EELS/EDS extraction next |
| fermiviewer-interactive-histogram | Active (T3-only) | 0 T1 / 0 T2 / 3 T3 | Tier 1–2 all shipped |
| fermiviewer-measurement-polish-2026-04-17 | Active | 0 T1 / 2 T2 / 0 T3 | Panel controls + annotation sync |
| data-workspace | Active | 0 T1 / 1 T2 / 2 T3 | Partial migration + cleanup |
| dataset-templates | Active (T3-only) | 0 T1 / 0 T2 / 1 T3 | Only Python port contract |
| dataworkspace-python-port | Active | 3 T1 / 3 T2 / 2 T3 | Deferred to Python sprint |
| retroactive-docs | Active | 5 T1 / 8 T2 / 0 T3 | Tier 1 theory done 2026-04-13 |
| origin-feature-gap | Active | 6 T1 / 7 T2 / 1 T3 | MATLAB done; Python pending |
| physics-analysis-gaps | Complete → archive | — | All 15 items shipped |
| software-feature-gaps | Active | 0 T1 / 3 T2 / 0 T3 | Tier 1 shipped |
| repo-audit-2026-04-13 | Active | ~10 mixed | Plan drift — needs reconcile |
| codebase-roadmap | Active | 1 T1 / 1 T2 / 0 T3 | Rolling umbrella |
| parser-roadmap | Paused | 1 T1 / 2 T2 / 0 T3 | Blocked on example files |
| bug-reporting | Active (Stage 2 deferred) | 0 T1 / 3 T2 / 3 T3 | Stage 1 shipped |
| porting_plan | Active | 7 items | Thin film toolkit architecture |

---

## Archive candidates (all items shipped)

None currently pending — the 5 plans completed this sprint were moved to `plans/archive/` on 2026-04-17:
- `diraculator-ux-polish-2026-04-17.md` (17 items)
- `fermiviewer-ux-pass-2026-04-16.md`
- `materialscalc-improvements.md` (33 items)
- `physics-analysis-gaps.md` (15 items)
- `improvements-audit-2026-04-11.md` (60/63 items; #18/#20/#63 deferred)
