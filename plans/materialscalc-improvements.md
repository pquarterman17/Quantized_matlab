# Materials Calculator GUI — Improvements Plan

Comprehensive improvement plan for `materialsCalcGUI.m` covering UX fixes, missing backend
exposure, cross-tab workflows, documentation, and code quality. Sourced from a UX agent audit,
documentation agent audit, and manual backend gap analysis.

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-12 (items 1–5 landed)

---

## Context

### How the pieces fit together

`materialsCalcGUI.m` is a 4,580-line uifigure with 18 panels navigated via a sidebar tree.
Each panel is built by a `buildXxxTab()` nested function that creates input fields, buttons,
and result labels, then calls into the `+calc/` package hierarchy (~85 functions across 11
subpackages). A global history/favorites system, status bar with copy buttons, and headless
API complete the architecture.

```
materialsCalcGUI.m (4,580 lines)
  ├── Navigation: uitree sidebar (5 categories, 18 leaf panels)
  ├── Status bar: Copy Result / Copy LaTeX / Save Favorite
  ├── 18 buildXxxTab() nested functions → call +calc subpackages
  ├── History/Favorites cross-tab system
  └── Headless API struct (nargout>0) for scripted/test use

+calc/ (85 functions, 11 subpackages)
  ├── ~45 functions exposed in GUI
  └── ~40 functions with NO GUI card (see W2 below)
```

### Dependency map
- W1 (UX) and W2 (Backend exposure) are largely independent
- W2 items that add new cards must follow W1 scroll-wrapper fixes (item 1)
- W3 (Cross-tab workflow) requires W2 cards to exist before linking them
- W4 (Documentation) is fully independent — can run in parallel with anything
- W5 (Code quality) is independent but low priority

---

## Cross-cutting priorities

| # | Item | Workstream | Why first |
|---|------|------------|-----------|
| 1 | Add scroll wrappers to dense tabs | W1 — UX | Blocks all new cards — they'll clip without this |
| 5 | Fix `refreshPTColoring` → `refreshPTColors` bug | W1 — UX | Actual crash on clearing periodic table search |
| 12 | Fill out Optics tab (6 missing functions) | W2 — Backend | Sparsest tab relative to backend completeness |
| 13 | Fill out Vacuum tab (5 missing functions) | W2 — Backend | Second sparsest tab |
| 22 | Create `docs/gui_materialscalc.md` user guide | W4 — Docs | Only GUI without a feature doc |

---

## W1 — UX & Usability

### Tier 1 — High Impact

1. **Add scroll wrappers to Electrical, Semiconductor, Magnetic, Optics tabs** — These 4 tabs
   use fractional row heights without a `Scrollable='on'` panel. On a 640px window, bottom
   cards clip (especially Hall Effect, Domain Wall). Crystal and Thin Film tabs already have
   the correct pattern to follow.
   - [ ] Wrap Electrical tab content in scrollable panel (line 1036)
   - [ ] Wrap Semiconductor tab content in scrollable panel (line 1293)
   - [ ] Wrap Magnetic tab content in scrollable panel (line 2750)
   - [ ] Wrap Optics tab content in scrollable panel (line 2986)
   - [ ] Run `checkClippedLayouts` after changes

2. **Cross-tab data flow: "Use in..." buttons** — Users frequently chain calculations
   (d-spacing → Q/2θ, neutron SLD → Reflectivity, molecular weight → unit cell density).
   Currently requires manual re-entry. Add "Use in..." links for the most common chains:
   - [ ] d-spacing result → Q/2θ converter on X-ray/Neutron tab
   - [ ] Neutron SLD formula/density → Reflectivity builder layer
   - [ ] Molecular weight → Unit Cell Volume molar mass field
   - [ ] Substrate selection → auto-fill across Crystal, Thin Film, Mismatch cards

3. **Add temperature input to Langevin card** — Currently hardcodes T=300 K (line 2927).
   Every other temperature-dependent card has an editable field. Add `efLangT` field.

4. **Visual distinction for error results** — All result labels use the same color for
   success and error. Add red font color (`[0.9 0.3 0.3]`) on error catches across all tabs.
   - [ ] Create helper: `showError(label, msg)` that sets text + red color
   - [ ] Create helper: `showResult(label, msg)` that sets text + normal color
   - [ ] Replace `lblXxx.Text = ['Error: ' ME.message]` pattern across all tabs

5. **Fix periodic table search crash** — `doSearch` calls `refreshPTColoring()` when search
   is cleared, but the function is named `refreshPTColors()` (line 2032). Runtime error.

### Tier 2 — Medium Impact

6. **Add `Limits` to numeric input fields** — Only `efPSMax` has limits. Add physically
   meaningful bounds to prevent nonsense inputs (negative thickness, zero wavelength, etc.).
   - [ ] Wavelength fields: `Limits=[0.01 100]`
   - [ ] Temperature fields: `Limits=[0 Inf]`
   - [ ] Thickness/length fields: `Limits=[0 Inf]`
   - [ ] Lattice parameter fields: `Limits=[0.1 100]`
   - [ ] Concentration fields: `Limits=[0 Inf]`

7. **Substrates tab: use canonical `calc.substrates` API** — Tab hardcodes 10 substrates
   (lines 3652–3702) instead of calling `calc.substrates.getSubstrate()`. Data will drift
   out of sync with the backend. Refactor to read from the canonical source.

8. **Review `registerPrimaryBtn` targets** — Some choices are questionable (Electrical
   registers conductivity instead of resistivity). Add subtle visual cue (e.g., bold text
   or underline) to indicate which button Enter will trigger.

### Tier 3 — Nice-to-Have

9. **Add category icons to navigation tree** — Use `uitreenode` `Icon` property (R2023a+)
   for visual scanning. Fall back gracefully on older MATLAB.

10. **Rename shadowed `btnCopyResult`** — Global status bar (line 137) and Unit Converter
    (line 414) both use `btnCopyResult`. Rename local to `btnUCCopyResult`.

11. **Register primary buttons for History/Favorites/Substrates** — Currently Enter does
    nothing on these tabs. Could trigger "Copy" or "Search" as appropriate.

---

## W2 — Backend Exposure (Missing GUI Cards)

### Tier 1 — High Impact

12. **Fill out Optics tab** — Currently only Fresnel (1 card). Backend has 6 more:
    - [ ] Critical angle card (`calc.optics.criticalAngle`)
    - [ ] Brewster angle card (`calc.optics.brewsterAngle`)
    - [ ] Penetration depth card (`calc.optics.penetrationDepth`)
    - [ ] Skin depth card (`calc.optics.skinDepth`)
    - [ ] Refractive ↔ dielectric conversion card (`calc.optics.refractiveToDielectric` / `dielectricToRefractive`)

13. **Fill out Vacuum tab** — Currently only mean free path (1 card). Backend has 5 more:
    - [ ] Knudsen number card (`calc.vacuum.knudsenNumber`)
    - [ ] Monolayer formation time card (`calc.vacuum.monolayerTime`)
    - [ ] Sputter yield card (`calc.vacuum.sputterYield`)
    - [ ] Pump-down time card (`calc.vacuum.pumpDownTime`)
    - [ ] Gas flow regimes card (`calc.vacuum.gasFlow`)

14. **Fill out Electrochemistry tab** — Currently only Nernst (1 card). Backend has 4 more:
    - [ ] Butler-Volmer card (`calc.electrochemistry.butlerVolmer`)
    - [ ] Tafel slope card (`calc.electrochemistry.tafelSlope`)
    - [ ] Ohmic drop card (`calc.electrochemistry.ohmicDrop`)
    - [ ] Double-layer capacitance card (`calc.electrochemistry.doubleLayerCapacitance`)

### Tier 2 — Medium Impact

15. **Semiconductor tab: add missing cards** — 7 backend functions without GUI:
    - [ ] Fermi level card (`calc.semiconductor.fermiLevel`)
    - [ ] Debye screening length card (`calc.semiconductor.debyeLength`)
    - [ ] Built-in potential card (`calc.semiconductor.builtInPotential`)
    - [ ] Sheet carrier density card (`calc.semiconductor.sheetCarrierDensity`)
    - [ ] Thermal velocity card (`calc.semiconductor.thermalVelocity`)

16. **Thin Film tab: add missing cards** — 4 backend functions without GUI:
    - [ ] Sputter rate card (`calc.thinFilm.sputterRate`)
    - [ ] Projected range (SRIM-style) card (`calc.thinFilm.projectedRange`)
    - [ ] Dose to concentration card (`calc.thinFilm.doseToConcentration`)
    - [ ] Multilayer thermal conductivity card (`calc.thinFilm.multilayerThermalConductivity`)

17. **Superconductor tab: add missing cards** — 3 backend functions without GUI:
    - [ ] Coherence length card (`calc.superconductor.coherenceLength`)
    - [ ] Depairing current card (`calc.superconductor.depairingCurrent`)
    - [ ] Ginzburg-Landau parameter card (`calc.superconductor.glParameter`)

18. **Crystal tab: add missing cards** — 4 backend functions without GUI:
    - [ ] Tetragonal distortion card (`calc.crystal.tetragonalDistortion`)
    - [ ] Strain from Poisson ratio card (`calc.crystal.strainFromPoisson`)
    - [ ] Atomic density card (`calc.crystal.atomicDensity`)

19. **X-ray/Neutron tab: add missing cards** — 4 backend functions without GUI:
    - [ ] Weight ↔ atomic percent converter (`calc.xrayNeutron.weightToAtomicPercent` / `atomicToWeightPercent`)
    - [ ] Chemical reaction balancer card (`calc.xrayNeutron.balanceReaction`)
    - [ ] Co-deposition ratio card (`calc.xrayNeutron.coDepositionRatio`)

### Tier 3 — Nice-to-Have

20. **Magnetic tab: refactor inline physics to use `+calc.magnetic.*`** — All 5 cards use
    inline formulas instead of calling the backend. Refactoring means backend improvements
    automatically propagate to the GUI.
    - [ ] Moment conversions → `calc.magnetic.bohrMagnetonConvert`
    - [ ] Demagnetization → `calc.magnetic.demagFactor`
    - [ ] Curie-Weiss → new `calc.magnetic.curieWeiss` function
    - [ ] Langevin → new `calc.magnetic.langevin` function
    - [ ] Domain wall → new `calc.magnetic.domainWall` function

21. **Electrical tab: refactor Hall Effect to use `calc.semiconductor.hallCoefficient`** —
    Currently inline calculation (lines 1258–1281). Should call the backend function.

---

## W3 — Cross-Tab Workflow

### Tier 2 — Medium Impact

(Item 2 in W1 covers the core cross-tab data flow. Additional workflow items:)

22. **Shared formula/density state** — The formula + density fields appear on Neutron SLD,
    X-ray SLD, and Molecular Weight cards. Unify into a shared state so changing formula on
    one auto-updates the others (within the X-ray/Neutron tab this partially works already).

23. **"Open in Reflectivity Builder" from SLD cards** — After computing SLD, offer a button
    to add a layer to the Reflectivity tab's multilayer stack with the computed SLD value.

---

## W4 — Documentation

### Tier 1 — High Impact

24. **Create `docs/gui_materialscalc.md` user guide** — The only GUI without a feature doc.
    Should cover:
    - [ ] Navigation model (5 categories, 18 panels)
    - [ ] Tab-by-tab feature summary with physics formulas used
    - [ ] History/Favorites workflow
    - [ ] Copy Result / Copy LaTeX / Copy as MATLAB code features
    - [ ] Headless API surface with examples
    - [ ] Reflectivity builder workflow
    - [ ] Periodic table interaction

25. **Add CLAUDE.md section for materialsCalcGUI** — Currently one line in the file tree.
    Add a section matching the BosonPlotter/DataWorkspace/FermiViewer pattern:
    - [ ] Navigation model
    - [ ] Headless API pattern
    - [ ] Key nested function conventions
    - [ ] Known gotchas (substrates data duplication, inline vs backend formulas)

### Tier 2 — Medium Impact

26. **Add per-tab builder docstrings** — None of the 18 `buildXxxTab()` functions have
    docstrings. Add header comments naming: physics domain, which `+calc.*` functions are
    called, any assumptions or valid input ranges.

27. **Document headless API method table** — 20+ methods exposed via the `api` struct, none
    have documented signatures, arguments, or return values. Add a table to
    `+calc/README.md` or the new user guide.

28. **Document physics formulas per card** — Tooltips cover units/ranges but not which
    formula variant is used (e.g., which Stoney equation, which London depth model). Add
    as in-code comments above each card section.

### Tier 3 — Nice-to-Have

29. **Backend function docstring sweep** — ~60 functions across 11 subpackages lack
    individual docstrings with input/output specs and units.

30. **Improve test_calc_modules.m section comments** — Six domains in one file with no
    per-section headers explaining which function each assertion tests.

---

## W5 — Code Quality

### Tier 3 — Nice-to-Have

31. **~~Extract error/result display helpers~~** — Completed as part of item 4: `errText()`
    helper with HTML red styling replaces all ~45 catch blocks.

32. **Consistent dark theme application** — Some widgets created in `buildPeriodicTableTab`
    may not pick up the post-hoc `applyDarkInputTheme` sweep if they use non-standard types.
    Verify all 18 tabs render correctly after theme application.

---

## Completed

- ~~**1. Add scroll wrappers to 4 dense tabs**~~ (2026-04-12) — Electrical, Semiconductor, Magnetic, Optics wrapped in scrollable panels with fixed pixel heights
- ~~**2. Cross-tab data flow**~~ (2026-04-12) — d-spacing→Q/2θ, mol weight→cell volume, SLD→Reflectivity with API hooks
- ~~**3. Add temperature input to Langevin card**~~ (2026-04-12) — Replaced hardcoded T=300K with editable field + validation
- ~~**4. Visual distinction for error results**~~ (2026-04-12) — `errText()` helper wraps errors in red HTML span; ~45 catch blocks updated
- ~~**5. Fix refreshPTColoring crash**~~ (2026-04-12) — Renamed to `refreshPTColors()` matching actual function name
- ~~**23. "Open in Reflectivity Builder" from SLD cards**~~ (2026-04-12) — Implemented as part of item 2 cross-tab flow
- ~~**31. Extract error display helper**~~ (2026-04-12) — Completed as part of item 4
