# Backlog — Open Work Across All Plans

Single-source dashboard aggregating every open top-level item from `plans/*.md`.
Regenerate whenever a plan changes; archived plans are excluded automatically.

**Last regenerated:** 2026-06-07 (FermiViewer scrub finalized — all EM code deleted from qm, FV plans archived. MASTERPLAN #45 (+imaging docstrings) moved to fv. Added previously-missing sections for the three BosonPlotter plans created in May: ui-construction-extraction, ux-cleanup, smoke-testing. Previous: 2026-05-22 fermi-viewer split.)

**How to read this file:**
- Items are grouped by **tier** (impact), then by **plan source**.
- Each line: `[ ] #<num>` plan → `title` — optional one-line context.
- Strike an item (`~~[ ] ...~~`) when it's done, or move the whole line to the plan's Completed section.
- If a plan's remaining items all ship, set its header `**Status:** Complete` and move the plan to `plans/archive/`.

---

## Tier 1 — High Impact (open)

### MASTERPLAN (MATLAB consolidated) — `plans/MASTERPLAN.md`
- [ ] **#68** W5 Decomposition → Drive `BosonPlotter.m` below **6,000 lines** (current 7,084, -15% to go). Replaces achieved #22 <8k milestone.

*(W5 #69 FermiViewer <6k moved to [fermi-viewer](https://github.com/pquarterman17/fermi-viewer) on 2026-05-22 as fv MASTERPLAN #3; qm-side scrub finalized 2026-06-07.)*

### BosonPlotter UX cleanup — `plans/bosonplotter-ux-cleanup.md`
- [ ] **#1** Centralize font-size scale (`tk.font.*` tokens)
- [ ] **#2** Fix corrGL 62-px label clipping (BG Intercept, Thick. Unit)
- [ ] **#3** Add top-level menu bar via `+bosonPlotter/buildMenuBar.m`

### Smoke testing & CI — `plans/smoke-testing-plan.md`
- [ ] **#4** exportapp snapshot infrastructure — manifest.json + metadata + cleanup remain (dir/naming/capture shipped with #1)

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
- [ ] **#4** W2 UX → Toolbar metrics consistent across the three GUIs (deferred)
- [ ] **#9** W3 Features → Small-angle scattering (Guinier / Porod / IFT)
- [ ] **#24** W5 Decomposition → Documentation coverage — package READMEs
- [ ] **#63** W5 Decomposition → Cross-workshop test harness (unblocked 2026-04-26)
- [ ] **#64** W5 Decomposition → Subfolder reorg of remaining `+bosonPlotter/` cross-cutters (after workshops carve out their pieces)
- [ ] **#47** W7 Parsers → `importOxford` (paused — awaiting example file)
- [ ] **#48** W7 Parsers → `importOpus` (paused — awaiting example file)
- [ ] **#50** W8 DataWorkspace → Shared model migration (PARTIAL)
- [ ] **#53** W9 Bug-reporting → Auto-offer on uncaught errors
- [ ] **#54** W9 Bug-reporting → Screenshot capture (opt-in)
- [ ] **#55** W9 Bug-reporting → Standalone `reportBug` command

### BosonPlotter UI-construction extraction — `plans/bosonplotter-ui-construction-extraction.md`
- [ ] **#4** Extract Data Table panel → `+bosonPlotter/buildDataTablePanel.m`
- [ ] **#5** Extract Axes context menu → `+bosonPlotter/buildAxesContextMenu.m`

### BosonPlotter UX cleanup — `plans/bosonplotter-ux-cleanup.md`
- [ ] **#4** Centralize label/text color palette
- [ ] **#5** Document & token-ize padding/spacing (`tk.pad.*`)
- [ ] **#6** Audit `'1x'` flex columns in narrow analysisGL panels

### Smoke testing & CI — `plans/smoke-testing-plan.md`
- [ ] **#6** JUnit XML output from `runAllTests` (CI prerequisite)
- [ ] **#7** GitHub Actions CI workflow (self-hosted runner)
- [ ] **#8** Claude agent visual review step (screenshot inspection)

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
- [ ] **#13** W3 Features → Connect batch fitting to multi-peak + reflectivity
- [ ] **#49** W7 Parsers → `importSPC` (paused — awaiting example file)
- [ ] **#51** W8 DataWorkspace → Multi-dataset operations
- [ ] **#52** W8 DataWorkspace → Remove legacy table from BosonPlotter (~400–500 line cleanup)
- [ ] **#56** W9 Bug-reporting → Cloudflare Worker relay
- [ ] **#57** W9 Bug-reporting → "Submit directly" button in dialog
- [ ] **#58** W9 Bug-reporting → Rate-limit + spam protection

#### Deprioritized — theory docs (lowest priority, pick up only when no other T3 work remains)
- [ ] **#42** W6 Docs → Docstring upgrade: `+calc/` formulas
- [ ] **#44** W6 Docs → Docstring upgrade: `+utilities/` physics functions
- [ ] **#46** W6 Docs → Plan hygiene: update physics-analysis-gaps.md

### BosonPlotter UI-construction extraction — `plans/bosonplotter-ui-construction-extraction.md`
- [ ] **#7** Extract Peak Analysis window scaffolding → `+bosonPlotter/peak/buildPeakScaffold.m`
- [ ] **#9** Extract palette + token initialization → `+bosonPlotter/initPalettes.m`

### BosonPlotter UX cleanup — `plans/bosonplotter-ux-cleanup.md`
- [ ] **#7** Convert section-header buttons (▼ / ▶) into a shared helper
- [ ] **#8** Drop redundant trailing colons on form labels
- [ ] **#9** Audit `+bosonPlotter/` dialog windows for token conformance
- [ ] **#10** Add `tk.color.btn*` aliases for existing `BTN_*` constants
- [ ] **#12** Audit other small-numeric editfields for the `'1x'` width issue

### Smoke testing & CI — `plans/smoke-testing-plan.md`
- [ ] **#9** Dialog auto-responder framework (configurable per-dialog defaults; basic timer responder shipped with #1)
- [ ] **#10** Parameterized parser smoke tests (every parser × every test file)
- [ ] **#11** Performance baseline tests (launch/load time regression)
- [ ] **#12** Post-refactor diff validator

### Origin parity (Python) — `plans/origin-feature-gap.md`
- [ ] **#14** Column formulas → Python

---

## Plans dashboard

| Plan | Status | Open items | Notes |
|------|--------|------------|-------|
| MASTERPLAN (MATLAB consolidated) | Active | 1 T1 / 11 T2 / 7+3 T3 | 9 source plans consolidated 2026-04-19. W5 #22 ratchet reached + workshops #59-#62 shipped 2026-04-26. **2026-05-22 fermi-viewer split / 2026-06-07 scrub final:** W1 #1 + W5 #28/#65/#69 + W6 #45 moved to fv repo. BosonPlotter/DiraCulator/DataWorkspace only now. |
| bosonplotter-ux-cleanup | Active | 3 T1 / 3 T2 / 5 T3 | Token conformance + layout fixes; #11 shipped |
| bosonplotter-ui-construction-extraction | Active | 2 T2 / 2 T3 | Feeds MASTERPLAN W5 #68 (<6k lines) |
| smoke-testing-plan | Active | 1 T1 / 3 T2 / 4 T3 | #1/#2/#5 shipped 2026-05-04; #3 moved to fv |
| workshop-conversion-plan | Active | (mirrored as MASTERPLAN W5 #63/#64) | #1–#4 shipped; #7 moved to fv |
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
