# Backlog — Open Work Across All Plans

Single-source dashboard aggregating every open top-level item from `plans/*.md`.
Regenerate whenever a plan changes; archived plans are excluded automatically.

**Last regenerated:** 2026-04-24 (W3 #8 shipped — instrument resolution smearing wired into `reflFitting` dialog with Pointwise dQ-from-data checkbox; W3 #12 RSM decomposition shipped 2026-04-21)

**How to read this file:**
- Items are grouped by **tier** (impact), then by **plan source**.
- Each line: `[ ] #<num>` plan → `title` — optional one-line context.
- Strike an item (`~~[ ] ...~~`) when it's done, or move the whole line to the plan's Completed section.
- If a plan's remaining items all ship, set its header `**Status:** Complete` and move the plan to `plans/archive/`.

---

## Tier 1 — High Impact (open)

### MASTERPLAN (MATLAB consolidated) — `plans/MASTERPLAN.md`
- [ ] **#22** W5 Decomposition → Continue `+bosonPlotter/` extraction — drive parent below 8k lines

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

### Porting — `plans/porting_plan.md`
- Architecture doc; 7 phase-level items — see plan for current Python+Tauri porting status

---

## Tier 2 — Medium Impact (open)

### MASTERPLAN (MATLAB consolidated) — `plans/MASTERPLAN.md`
- [ ] **#1** W1 Bugs → FermiViewer right-side tools panel overcrowded (tabled)
- [ ] **#4** W2 UX → Toolbar metrics consistent across all four GUIs (deferred)
- [ ] **#9** W3 Features → Small-angle scattering (Guinier / Porod / IFT)
- [ ] **#11** W3 Features → Free-form SLD profile (spline) for reflectometry
- [ ] **#24** W5 Decomposition → Documentation coverage — package READMEs
- [ ] **#29** W6 Docs → Theory: spectroscopy.md
- [ ] **#30** W6 Docs → Theory: thin_films.md
- [ ] **#31** W6 Docs → Theory: electrochemistry.md
- [ ] **#32** W6 Docs → Theory: fitting.md
- [ ] **#33** W6 Docs → Theory: statistics.md
- [ ] **#34** W6 Docs → Theory: imaging.md
- [ ] **#35** W6 Docs → Tutorial: magnetometry-workflow.md
- [ ] **#36** W6 Docs → Tutorial: superconductor-workflow.md
- [ ] **#37** W6 Docs → Tutorial: xrd-analysis-workflow.md
- [ ] **#38** W6 Docs → Tutorial: reflectometry-workflow.md
- [ ] **#39** W6 Docs → Tutorial: transport-workflow.md
- [ ] **#40** W6 Docs → Tutorial: eels-analysis-workflow.md
- [ ] **#47** W7 Parsers → `importOxford` (paused — awaiting example file)
- [ ] **#48** W7 Parsers → `importOpus` (paused — awaiting example file)
- [ ] **#50** W8 DataWorkspace → Shared model migration (PARTIAL)
- [ ] **#53** W9 Bug-reporting → Auto-offer on uncaught errors
- [ ] **#54** W9 Bug-reporting → Screenshot capture (opt-in)
- [ ] **#55** W9 Bug-reporting → Standalone `reportBug` command

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

---

## Tier 3 — Nice-to-Have (open)

### MASTERPLAN (MATLAB consolidated) — `plans/MASTERPLAN.md`
- [ ] **#5** W2 UX → Transfer function ramp overlay on histogram
- [ ] **#6** W2 UX → Click-drag-on-histogram for brightness/contrast
- [ ] **#7** W2 UX → Clipping indicators (saturated-pixel tails)
- [ ] **#13** W3 Features → Connect batch fitting to multi-peak + reflectivity
- [ ] **#14** W3 Features → Action-log macro replay
- [ ] **#15** W3 Features → Analysis provenance log (Mantid-style)
- [ ] **#16** W3 Features → 2D histogram / density plot
- [ ] **#28** W5 Decomposition → Extract FermiViewer measurement subsystem
- [ ] **#42** W6 Docs → Docstring upgrade: `+calc/` formulas
- [ ] **#44** W6 Docs → Docstring upgrade: `+utilities/` physics functions
- [ ] **#45** W6 Docs → Docstring upgrade: `+imaging/` physics functions
- [ ] **#46** W6 Docs → Plan hygiene: update physics-analysis-gaps.md
- [ ] **#49** W7 Parsers → `importSPC` (paused — awaiting example file)
- [ ] **#51** W8 DataWorkspace → Multi-dataset operations
- [ ] **#52** W8 DataWorkspace → Remove legacy table from BosonPlotter (~400–500 line cleanup)
- [ ] **#56** W9 Bug-reporting → Cloudflare Worker relay
- [ ] **#57** W9 Bug-reporting → "Submit directly" button in dialog
- [ ] **#58** W9 Bug-reporting → Rate-limit + spam protection

### Origin parity (Python) — `plans/origin-feature-gap.md`
- [ ] **#14** Column formulas → Python

---

## Plans dashboard

| Plan | Status | Open items | Notes |
|------|--------|------------|-------|
| MASTERPLAN (MATLAB consolidated) | Active | 1 T1 / 23 T2 / 18 T3 | 9 source plans consolidated 2026-04-19; W4 Physics (4 items) shipped 2026-04-19; W5 #23/#25/#26/#27 reconciled as already done; W1 #59, W3 #17, W6 #41, W6 #43 shipped 2026-04-19; W2 #2 + #3 (FermiViewer measurement UX) reconciled 2026-04-21; W3 #10 (session round-trip) + W3 #12 (RSM decomposition) shipped 2026-04-21; **W3 #8 (resolution smearing wired into reflFitting) shipped 2026-04-24** |
| origin-feature-gap | Active (Python) | 6 T1 / 7 T2 / 1 T3 | MATLAB side complete; Python port pending — excluded from MASTERPLAN |
| dataworkspace-python-port | Active (Python) | 3 T1 / 3 T2 / 2 T3 | Python-port architecture; excluded from MASTERPLAN |
| porting_plan | Active (Python) | 7 phase-level items | Thin film toolkit architecture; excluded from MASTERPLAN |

### Archived 2026-04-19 (consolidated into MASTERPLAN.md)

The following per-topic plans were archived on 2026-04-19. Their open items live in `plans/MASTERPLAN.md` with continuous numbering across workstreams W1–W9. Archived files preserve their original Completed sections for history.

- `known-bugs.md` → W1 #1
- `fermiviewer-measurement-polish-2026-04-17.md` → W2 #2–3
- `fermiviewer-interactive-histogram.md` → W2 #5–7
- `repo-audit-2026-04-13.md` → W2 #4, W3 #8/#9/#10/#11/#12/#13/#14, W4 #18/#19/#20/#21
- `software-feature-gaps.md` → W3 #15–17
- `codebase-roadmap.md` → W5 #22, #24
- `bosonplotter-decomposition.md` → W5 #23, #25–27
- `fermiviewer-decomposition-2026-04-16.md` → W5 #28
- `retroactive-docs.md` → W6 #29–46
- `parser-roadmap.md` → W7 #47–49
- `data-workspace.md` → W8 #50–52
- `bug-reporting.md` → W9 #53–58
- `dataset-templates.md` → archived (sole open item #12 is Python-port design doc; tracked under Python-port scope)
