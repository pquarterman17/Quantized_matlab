# XRD Analysis Feature Roadmap

## Context
- Primary data: XRD (XRDML/Rigaku/Bruker)
- Main pain point: extracting quantitative results (d-spacing, lattice params, crystallite size, film thickness)
- Current issue: overlapping peak detection fails when two peaks are close together
- All features extend the existing Peak Analysis panel in `dataImportGUI.m`
- User also wants: pseudo-Voigt peaks, polynomial backgrounds, Williamson-Hall strain analysis

---

## Phase 1 — Foundation: Improved Peak Fitting

### 1.1 Pseudo-Voigt peak model ✓ COMPLETE
**Model: Sonnet**

Replace/augment current Lorentzian with pseudo-Voigt (mixing parameter η blends Gaussian + Lorentzian). More physically accurate for XRD; η itself indicates strain vs. size broadening character.

**Scope:**
- Add `+utilities/pseudoVoigt.m` — function evaluating pV(x; x0, FWHM, A, η)
- Update peak fitting in `dataImportGUI.m` to use pseudo-Voigt instead of pure Lorentzian
- Add η column to peak table
- Update multi-peak simultaneous fit to use sum-of-pseudo-Voigts
- Update analytical area integral for pseudo-Voigt (weighted sum of Gaussian + Lorentzian integrals)
- Add dropdown or toggle to select peak shape: Lorentzian / Gaussian / Pseudo-Voigt

**Why Sonnet:** Straightforward mathematical function + mechanical GUI wiring. Well-defined inputs/outputs, no architectural decisions.

---

### 1.2 Improved overlapping peak detection ✓ COMPLETE
**Model: Opus**

Fix the peak finder so closely-spaced peaks are properly resolved. Current `findpeaks` misses shoulders; manual add can snap to wrong peak; multi-peak fit can diverge with bad initial guesses.

**Scope:**
- Improve auto-detection: use second derivative (or wavelet) to find inflection points that indicate hidden shoulders
- Better initial guess generation for multi-peak fits (use detected inflection points as seed positions)
- Add minimum peak separation parameter (user-configurable)
- Constrained fitting: bound peak positions within a window of their initial guess to prevent crossover
- Test with real data where two peaks are < 1° apart

**Why Opus:** Requires careful algorithm design, understanding of numerical optimization pitfalls, and judgment about edge cases. The second-derivative approach needs tuning thresholds that interact with noise levels.

---

### 1.3 Polynomial background fitting ✓ COMPLETE
**Model: Sonnet**

Fit and subtract polynomial baselines (order 1–6) before peak analysis. Replaces/augments the current linear BG slope+intercept.

**Scope:**
- Add `ddBGOrder` dropdown to corrections panel: Linear (current) / Poly 2 / Poly 3 / Poly 4 / Poly 5 / Poly 6
- Use `polyfit`/`polyval` on user-selected BG regions (reuse existing rubber-band box selection)
- Allow multiple BG region selections (left + right of a peak cluster)
- Store polynomial coefficients in `ds.bgPoly` for undo/session persistence
- Display fitted BG curve on plot as dashed line

**Why Sonnet:** Standard polyfit/polyval usage, straightforward GUI additions. The rubber-band region selection mechanism already exists.

---

## Phase 2 — XRD Parameter Extraction

### 2.1 d-spacing column in peak table ✓ COMPLETE
**Model: Sonnet**

Automatic Bragg's law conversion: peak 2θ → d-spacing using wavelength from parser metadata.

**Scope:**
- Read wavelength from `ds.data.metadata.parserSpecific.wavelength_nm` (already parsed by importXRDML, importRigaku_raw, importBruker)
- Compute d = λ / (2·sin(θ)), where θ = peak_center / 2 (degrees → radians)
- Add "d (Å)" column to peak table (auto-populated on fit)
- If wavelength is missing from metadata, show a small edit field for manual entry
- Persist wavelength override in `ds.wavelength_nm`

**Why Sonnet:** Pure formula application + one new column. No algorithmic complexity.

---

### 2.2 Crystallite size column (Scherrer) ✓ COMPLETE
**Model: Sonnet**

FWHM → crystallite size via the Scherrer equation: D = Kλ / (β·cos θ).

**Scope:**
- Add "Size (nm)" column to peak table
- K factor: default 0.9 (configurable via small edit field, stored in appData)
- β = FWHM in radians (corrected for instrument broadening if provided)
- Optional instrument broadening field: `efInstBroadening` (FWHM of a standard, e.g. LaB6)
- Corrected β = sqrt(β_measured² − β_instrument²) (Gaussian deconvolution)
- Auto-compute on peak fit; update when instrument broadening changes

**Why Sonnet:** Direct formula. The instrument broadening correction is a single subtraction. GUI is one edit field + one column.

---

### 2.3 Lattice parameter refinement ✓ COMPLETE
**Model: Opus**

Refine lattice parameters from multiple peak positions + hkl assignments.

**Scope:**
- Add "Refine Lattice..." button below peak table
- Opens a dialog/panel where user assigns hkl indices to each detected peak (editable table)
- Crystal system dropdown: Cubic / Tetragonal / Hexagonal / Orthorhombic
- Least-squares refinement: minimize Σ(d_obs − d_calc)² over lattice parameters
- For cubic: single parameter a; tetragonal: a, c; hexagonal: a, c; orthorhombic: a, b, c
- Display refined parameters + residuals + Nelson-Riley extrapolation plot
- Store results in `ds.latticeParams`

**Why Opus:** Requires designing the hkl assignment UX, implementing least-squares for multiple crystal systems, and handling edge cases (insufficient peaks, degenerate hkl). Architectural decisions about the dialog layout.

---

## Phase 3 — Whole-Pattern Analysis

### 3.1 Film thickness from Laue fringes (FFT) ✓ COMPLETE
**Model: Opus**

FFT of XRD pattern to extract fringe periodicity → film thickness.

**Scope:**
- Add "FFT Thickness" button to peak panel
- User selects a 2θ range containing fringes (reuse rubber-band selection)
- Interpolate to uniform Δ(2θ) grid, apply window function (Hann), compute FFT
- Convert FFT frequency axis to thickness (nm) using: t = λ / (2·Δ(2θ)·cos θ_center)
- Display FFT magnitude plot in a popup figure with the dominant peak marked
- Report thickness ± uncertainty (from FFT peak width)
- Store result in `ds.filmThickness`

**Why Opus:** FFT frequency-to-thickness conversion involves non-trivial coordinate transforms. Choosing the right windowing, interpolation grid, and uncertainty estimation requires physics judgment. The popup figure needs good UX.

---

### 3.2 Williamson-Hall strain analysis ✓ COMPLETE
**Model: Opus**

Plot β·cos(θ) vs. 4·sin(θ) for selected peaks; linear fit extracts crystallite size (intercept) and microstrain (slope).

**Scope:**
- Add "W-H Plot" button to peak panel (enabled when ≥3 peaks are fitted)
- Collect (2θ, FWHM) from all fitted peaks; correct FWHM for instrument broadening
- Compute β·cos(θ) and 4·sin(θ) for each peak
- Linear fit: β·cos(θ) = (Kλ/D) + 4ε·sin(θ)
- Display W-H plot in popup figure with data points + fit line
- Report: crystallite size D, microstrain ε, R² of fit
- Store results in `ds.williamsonHall`

**Why Opus:** Requires understanding which peaks are valid for W-H analysis (same crystallographic phase), handling the instrument broadening pipeline from 2.2, and producing a well-labeled diagnostic plot. The physics interpretation layer (what constitutes a good vs. suspicious W-H fit) benefits from stronger reasoning.

---

## Implementation Order

| Step | Task | Model | Est. Edits | Dependencies |
|------|------|-------|------------|--------------|
| 1 | 1.1 Pseudo-Voigt model | Sonnet | ~150 lines | None |
| 2 | 1.3 Polynomial background | Sonnet | ~100 lines | None |
| 3 | 1.2 Overlapping peak detection | Opus | ~200 lines | Benefits from 1.1 |
| 4 | 2.1 d-spacing column | Sonnet | ~50 lines | 1.1 (needs fitted peaks) |
| 5 | 2.2 Scherrer size column | Sonnet | ~80 lines | 2.1 (needs wavelength) |
| 6 | 2.3 Lattice parameter refinement | Opus | ~300 lines | 2.1 (needs d + hkl) |
| 7 | 3.1 FFT film thickness | Opus | ~200 lines | None (independent) |
| 8 | 3.2 Williamson-Hall plot | Opus | ~150 lines | 2.2 (needs corrected FWHM) |

**Total estimate:** ~1,300 lines of new/modified code across 8 tasks.

Steps 1+2 can run in parallel. Steps 4+5 are quick wins after Phase 1. Steps 7 is independent and can be done anytime.

---

## Model Cost Summary

| Model | Tasks | Rationale |
|-------|-------|-----------|
| **Sonnet** | 1.1, 1.3, 2.1, 2.2 | Formula implementation, mechanical GUI wiring, well-defined scope |
| **Opus** | 1.2, 2.3, 3.1, 3.2 | Algorithm design, numerical optimization, UX decisions, physics judgment |
