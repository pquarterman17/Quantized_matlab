# Codebase Organization & Documentation TODO

## Session Context (2026-03-21)

This plan was created after implementing Savitzky-Golay filtering and Analysis Templates (see `planning/origin_feature_gaps.md`). During that work it became clear the codebase is getting unwieldy — DataPlotter.m alone is 17,838 lines and CLAUDE.md is 715 lines loaded into every conversation. The user explicitly asked Claude to suggest how to improve organization.

**Relationship to origin_feature_gaps.md:** That plan covers *new features* to add (LM fitting, FFT filtering, stats, etc.). This plan covers *structural improvements* to make the existing code more maintainable. Both are independent tracks — you can work on either.

**Uncommitted changes from this session:** See `origin_feature_gaps.md` for the full list. All changes need to be committed.

---

## The Problem

The codebase has grown organically to **~33,500 lines across 3 monolithic GUI files** and **~150 package functions across 88+ calc modules**. It works, but it's becoming unwieldy for both humans and Claude to navigate, modify, and extend.

| File | Lines | Role |
|------|-------|------|
| `DataPlotter.m` | 17,838 | Main GUI — corrections, peaks, figures, templates, data table, ... |
| `emViewerGUI.m` | 11,877 | EM viewer — contrast, measurements, EELS, EDS, stitching, ... |
| `materialsCalcGUI.m` | 3,118 | Materials calculator (13 tabs) |
| `CLAUDE.md` | 715 | Project documentation (already long, growing) |
| `+calc/` | 88 files | Calculator backend |
| `+parser/` | ~20 files | Data import |
| `+imaging/` | ~20 files | EM utilities |
| `+utilities/` | ~15 files | Data processing |

---

## TODO 1: Break up monolithic GUIs

### DataPlotter.m (17,838 lines) — highest priority

DataPlotter is the worst offender. It contains:
- GUI layout construction (~2,000 lines)
- Corrections pipeline (~500 lines)
- Peak detection + fitting (~1,500 lines)
- Peak analysis window (~800 lines)
- Figure Builder (~2,000 lines)
- Data Table (~800 lines)
- Session save/load (~500 lines)
- Templates (~300 lines)
- Advanced analysis (curve fit, digitizer, etc.) (~2,000 lines)
- Event handlers, plotting, keyboard shortcuts (~3,000+ lines)

**Proposed decomposition:**
- `DataPlotter.m` — main GUI layout, event dispatch, state management (~3,000 lines)
- `+dataplotter/buildLayout.m` — GUI construction helpers
- `+dataplotter/correctionsPipeline.m` — apply corrections to data struct
- `+dataplotter/peakAnalysis.m` — peak detection, fitting, table management
- `+dataplotter/figureBuilder.m` — advanced figure builder dialog
- `+dataplotter/dataTable.m` — spreadsheet view panel
- `+dataplotter/curveFitting.m` — general curve fitting dialog
- `+dataplotter/graphDigitizer.m` — graph digitizer dialog
- `+dataplotter/sessionIO.m` — session save/load logic

**Challenge:** MATLAB nested functions share the parent workspace (closures over GUI handles like `ax`, `fig`, `appData`). Extracting them to separate files requires passing state explicitly or using a shared state struct/handle class. This is a significant refactor.

**Recommended approach:** Use a shared `AppState` handle class that holds `fig`, `ax`, `appData`, and all GUI handles. Pass it to extracted functions. This is idiomatic for large MATLAB GUIs.

### emViewerGUI.m (11,877 lines) — medium priority

Similar pattern. Could extract:
- `+emviewer/measurements.m` — line profile, distance, angle, polyline, ROI
- `+emviewer/eelsAnalysis.m` — EELS background, maps, thickness
- `+emviewer/edsComposite.m` — EDS multi-channel blending
- `+emviewer/imageProcessing.m` — filters, FFT, crop, rotate
- `+emviewer/stitching.m` — panoramic mosaic

---

## TODO 2: CLAUDE.md is becoming a liability

At 715 lines and growing, CLAUDE.md is approaching the point where:
- It consumes significant context window space on every conversation
- It's hard for humans to find things in it
- Adding new features means the doc grows linearly forever

**Proposed restructuring:**
- Keep `CLAUDE.md` as a **concise summary** (~200 lines): project overview, key conventions, common workflows, testing commands
- Move detailed feature docs to `docs/` or per-package README files:
  - `+parser/README.md` — parser format table, column shorthands, dispatch logic
  - `+imaging/README.md` — imaging utilities, EELS, EDS, diffraction
  - `+calc/README.md` — calculator modules, API reference
  - `docs/gui_dataplotter.md` — DataPlotter features, keyboard shortcuts, advanced tools
  - `docs/gui_emviewer.md` — emViewerGUI features, capture modes, pipeline
- Claude can read these on-demand via `Read` tool rather than loading everything into context every time

**Alternative:** Use a `CLAUDE.md` hierarchy — MATLAB supports reading `+package/CLAUDE.md` files if they exist. Each package could have its own concise instructions.

---

## TODO 3: Organize the +calc/ package (88 files)

The `+calc/` package has exploded to 88 files across 10+ subpackages. Most are small single-function files, which is fine, but:
- No index or discovery mechanism beyond reading the directory listing
- No README explaining what's available
- Some subpackages (`+crystal/` 13 files, `+semiconductor/` 12 files) are getting large

**Actions:**
- [ ] Add `+calc/README.md` with a function table (name, one-line description, inputs/outputs)
- [ ] Consider whether some subpackages should be consolidated (e.g., do we really need 12 separate semiconductor functions or could some be methods on a shared module?)
- [ ] Add `help` text to any functions missing it

---

## TODO 4: Test organization

Tests are all flat in `tests/` (19+ files). As the codebase grows:
- [ ] Consider `tests/parser/`, `tests/gui/`, `tests/imaging/`, `tests/calc/` subdirectories
- [ ] Ensure `runAllTests.m` group system supports subdirectories
- [ ] Add a test for `applyAnalysisTemplate` (new feature)

---

## TODO 5: Document the architecture for humans

There's no high-level architecture document. A new contributor (or Claude in a new session) has to reverse-engineer:
- How DataPlotter's state management works (`appData`, `datasets`, `activeIdx`)
- The corrections pipeline order and what each step does
- The peak analysis workflow (detection → fitting → deconposition → export)
- How the Figure Builder assembles multi-panel figures
- How emViewerGUI's image pipeline works (`rawPixels` → `filteredPixels` → `displayImg`)

**Actions:**
- [ ] Create `docs/architecture.md` — data flow diagrams, state management, key design decisions
- [ ] Add sequence diagrams for: file import → display, corrections pipeline, peak workflow

---

## Suggestions for Claude: How to improve organization

### Short-term (can do now, low risk)
1. **Split CLAUDE.md** into core + per-package docs — biggest context window win
2. **Add README.md to each package** — helps both Claude and human discovery
3. **Extract `correctionsPipeline` from DataPlotter** — it's the most self-contained piece (pure function, no GUI handles needed)

### Medium-term (needs planning)
4. **Create `AppState` handle class** for DataPlotter — prerequisite for GUI decomposition
5. **Extract Figure Builder** into `+dataplotter/figureBuilder.m` — it's a separate dialog, mostly self-contained
6. **Extract curve fitting and graph digitizer** — also separate dialogs

### Long-term (architectural)
7. **Full DataPlotter decomposition** — after AppState is in place, systematically extract each subsystem
8. **Event bus pattern** — replace direct function calls between subsystems with an event/listener pattern (cleaner coupling)
9. **Consider whether materialsCalcGUI should be plugin-based** — 13 tabs, each independent, natural plugin boundary

### What NOT to do
- Don't try to decompose everything at once — it's a 17,000-line refactor that will break things
- Don't move to OOP classes for the sake of it — MATLAB's class system adds overhead and this codebase's functional style works
- Don't create abstraction layers that aren't needed yet — the current flat package structure is fine for the function count
