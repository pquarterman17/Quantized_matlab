# Backlog — Open Work Across All Plans

Single-source dashboard aggregating every open top-level item from `plans/*.md`.
Regenerate whenever a plan changes; archived plans are excluded automatically.

**Last regenerated:** 2026-04-19 (W1 + W2 batch shipped — W2 #16/#20/#25 added via `e9a0108`; repo-audit down to 17 open items)

**How to read this file:**
- Items are grouped by **tier** (impact), then by **plan source**.
- Each line: `[ ] #<num>` plan → `title` — optional one-line context.
- Strike an item (`~~[ ] ...~~`) when it's done, or move the whole line to the plan's Completed section.
- If a plan's remaining items all ship, set its header `**Status:** Complete` and move the plan to `plans/archive/`.

---

## Tier 1 — High Impact (open)

### BosonPlotter decomposition — `plans/bosonplotter-decomposition.md`
(Tier 1 items 1–6 all shipped 2026-04-12 — see plan's Completed section.)

### FermiViewer decomposition — `plans/fermiviewer-decomposition-2026-04-16.md`
- [ ] **#1** Infrastructure: `+emViewer/` + ui struct — done for diffraction/annotation/export; NOT yet for EELS/EDS
- [ ] **#2** Extract EELS subsystem (~14 nested fns freed)
- [ ] **#3** Extract EDS subsystem (~12 nested fns freed)

### Codebase — `plans/codebase-roadmap.md`
- [ ] **#1** Continue `+bosonPlotter/` extraction — drive parent below 8k lines

### Origin parity (Python port, MATLAB side complete) — `plans/origin-feature-gap.md`
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

### Repo audit — `plans/repo-audit-2026-04-13.md` (W1 all Tier 1/2 bugs + most of W2 shipped — remaining items are W2 polish, W3 Features, W4 Physics)
- (See plan for W2 UX polish #17/22/23/24/27, W3 Features, W4 Physics workstreams — 31 items)

### Parsers — `plans/parser-roadmap.md` (Paused: blocked on example files)
- [ ] **#1** `importRaman` — Horiba LabSpec / Renishaw ASCII

### Porting — `plans/porting_plan.md`
- Architecture doc; 7 phase-level items — see plan for current Python+Tauri porting status

---

## Tier 2 — Medium Impact (open)

### Known bugs — `plans/known-bugs.md`
- [ ] **#16** FermiViewer right-side tools panel overcrowded — buttons overlap on standard sizes (tabled)

### BosonPlotter decomposition — `plans/bosonplotter-decomposition.md`
- [ ] **#11** Extract `onAutoMagCorrections` (115 lines)

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
- [ ] **#4** `DataWorkspaceView.vue` component
- [ ] **#5** WebSocket sync
- [ ] **#6** Workspace file format

### Software gaps — `plans/software-feature-gaps.md`
(Tier 3 only — see Tier 3 section below)

### Bug reporting — `plans/bug-reporting.md` (Stage 2 deferred)
- [ ] **#6** Auto-offer on uncaught errors
- [ ] **#7** Screenshot capture (opt-in)
- [ ] **#8** Standalone `reportBug` command

### Parsers — `plans/parser-roadmap.md`
- [ ] **#2** `importOxford` — Oxford Instruments MagLab CSV
- [ ] **#3** `importOpus` — Bruker OPUS FTIR

### Docs (theory) — `plans/retroactive-docs.md` (plan labels as Tier 2)
- [ ] **#6** Spectroscopy theory doc
- [ ] **#7** Thin films theory doc
- [ ] **#8** Electrochemistry theory doc
- [ ] **#9** Fitting theory doc
- [ ] **#10** Statistics theory doc
- [ ] **#11** Imaging theory doc

### Docs (tutorials) — `plans/retroactive-docs.md`
- [ ] **#12–18** Tutorial walkthroughs (magnetometry, superconductor, xrd, reflectometry, transport, eels, curve-fitting)

### Codebase — `plans/codebase-roadmap.md`
- [ ] **#2** Documentation coverage — package READMEs

---

## Tier 3 — Nice-to-Have (open)

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

### DataWorkspace — `plans/data-workspace.md`
- [ ] **#13** Multi-dataset operations
- [ ] **#16** Remove legacy table from BosonPlotter (~400–500 line cleanup; blocks clean break)

### Dataset templates — `plans/dataset-templates.md`
- [ ] **#12** Python port contract — design document for thin_film_toolkit equivalent

### DataWorkspace Python port — `plans/dataworkspace-python-port.md`
- [ ] **#7** Shared template JSON schema (partially done)
- [ ] **#8** Performance benchmarks

### Origin parity (Python) — `plans/origin-feature-gap.md`
- [ ] **#14** Column formulas → Python

### Software gaps — `plans/software-feature-gaps.md`
- [ ] **#11** Analysis provenance log (Mantid-style operation history)
- [ ] **#12** 2D histogram / density plot
- [ ] **#13** Smart unit/symbol rendering in axis labels

### Parsers — `plans/parser-roadmap.md`
- [ ] **#4** `importSPC` — GRAMS/Thermo SPC spectral format

### Bug reporting — `plans/bug-reporting.md` (Stage 2)
- [ ] **#9** Cloudflare Worker relay
- [ ] **#10** "Submit directly" button in dialog
- [ ] **#11** Rate-limit + spam protection

### Docs — `plans/retroactive-docs.md`
- [ ] **#19** Docstring upgrade: `+calc/` formulas
- [ ] **#20** Docstring upgrade: `+fitting/` formulas
- [ ] **#21** Docstring upgrade: `+utilities/` physics functions
- [ ] **#22** Docstring upgrade: `+imaging/` physics functions
- [ ] **#23** Plan hygiene: update physics-analysis-gaps.md

---

## Plans dashboard

| Plan | Status | Open items | Notes |
|------|--------|------------|-------|
| known-bugs | Active (mostly complete) | 0 T1 / 1 T2 / 0 T3 | Only #16 tools panel overcrowded (tabled); 14 items shipped 2026-04-13 |
| bosonplotter-decomposition | Active | 0 T1 / 1 T2 / 3 T3 | Tier 1 complete; 295 nested fns, 50 slots headroom |
| fermiviewer-decomposition-2026-04-16 | Active | 3 T1 / 0 T2 / 1 T3 | EELS/EDS extraction next |
| fermiviewer-interactive-histogram | Active (T3-only) | 0 T1 / 0 T2 / 3 T3 | Tier 1–2 all shipped |
| fermiviewer-measurement-polish-2026-04-17 | Active | 0 T1 / 2 T2 / 0 T3 | Panel controls + annotation right-panel sync |
| data-workspace | Active | 0 T1 / 1 T2 / 2 T3 | Partial migration + cleanup |
| dataset-templates | Active (T3-only) | 0 T1 / 0 T2 / 1 T3 | Only Python port contract |
| dataworkspace-python-port | Active | 3 T1 / 3 T2 / 2 T3 | Deferred to Python sprint |
| retroactive-docs | Active | 0 T1 / 13 T2 / 5 T3 | Tier 1 theory done 2026-04-13; theory + tutorials remaining |
| origin-feature-gap | Active | 6 T1 / 7 T2 / 1 T3 | MATLAB done; Python pending |
| software-feature-gaps | Active (T3-only) | 0 T1 / 0 T2 / 3 T3 | Tier 1–2 shipped |
| repo-audit-2026-04-13 | Active | ~31 mixed (23 done of 54) | W1 + most of W2 shipped; remaining work is W2 polish (#17/22/23/24/27), W3 Features, W4 Physics |
| codebase-roadmap | Active | 1 T1 / 1 T2 / 0 T3 | Rolling umbrella |
| parser-roadmap | Paused | 1 T1 / 2 T2 / 1 T3 | Blocked on example files |
| bug-reporting | Active (Stage 2 deferred) | 0 T1 / 3 T2 / 3 T3 | Stage 1 shipped |
| porting_plan | Active | 7 phase-level items | Thin film toolkit architecture |

---

## Archive candidates (all items shipped)

None currently pending — the 5 plans completed this sprint were moved to `plans/archive/` on 2026-04-17:
- `diraculator-ux-polish-2026-04-17.md` (17 items)
- `fermiviewer-ux-pass-2026-04-16.md`
- `materialscalc-improvements.md` (33 items)
- `physics-analysis-gaps.md` (15 items)
- `improvements-audit-2026-04-11.md` (60/63 items; #18/#20/#63 deferred)
