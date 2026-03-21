# OriginPro Feature Gaps

Comparison of essential OriginPro features missing from thin_film_toolkit_matlab.
Prioritized by impact for thin-film / magnetometry / XRD researchers.

## Session Context (2026-03-21)

**What happened this session:**
1. User asked what essential OriginPro features are missing from this codebase
2. Identified 7 prioritized gaps (see below)
3. Implemented #1 (Savitzky-Golay) and #2 (Analysis Templates) — both done and tested
4. Created `planning/codebase_organization.md` — a separate TODO for restructuring the codebase
5. All changes are uncommitted (user went to bed before committing)

**Files modified this session:**
- `+utilities/smoothData.m` — added `'savitzky-golay'` method with `PolyOrder` param, proper edge handling via asymmetric polynomial fits
- `DataPlotter.m` — added SG to smoothing dropdown, added "Batch Apply..." button to Templates dialog with `doBatchApplyTemplate()` nested function
- `+scripts/applyAnalysisTemplate.m` — NEW file, batch-applies saved DataPlotter templates to folders of files (import → correct → export CSV + optional peaks)
- `CLAUDE.md` — updated smoothData description, added SG examples, added analysis template workflow docs, added applyAnalysisTemplate to scripts listing
- `planning/origin_feature_gaps.md` — this file
- `planning/codebase_organization.md` — codebase restructuring TODO

**Tests run:** `runAllTests(Group='batch')` — 21/21 passed. SG-specific smoke tests passed (constant/linear/quadratic preservation, noisy signal, edge cases, polyorder validation).

**What to do next session:**
- Commit all changes (or review first)
- Pick next feature to implement (#3 Levenberg-Marquardt or #4 FFT filtering)
- OR start on codebase organization (see `planning/codebase_organization.md`)
- Need a test for `applyAnalysisTemplate` (noted in organization TODO)

---

## Priority 1: Savitzky-Golay Filter ✅ IMPLEMENTED

**Status:** Added to `+utilities/smoothData.m` and DataPlotter GUI dropdown.

The single most-used smoothing method in experimental science. Polynomial-preserving — keeps peak shapes, heights, and positions intact unlike moving average or Gaussian which always broaden peaks. Critical for XRD and spectroscopy data where peak integrity matters.

**What Origin has:** SG filter with configurable polynomial order and window size.
**What we had:** Moving average and Gaussian only.
**Implementation:** New `'savitzky-golay'` method in `smoothData.m` with `PolyOrder` parameter (default 2). Convolution matrix built via Vandermonde pseudoinverse — no toolbox required.

---

## Priority 2: Analysis Templates (Reproducible Pipelines) ✅ IMPLEMENTED

**Status:** Added `+scripts/applyAnalysisTemplate.m` and extended DataPlotter template system.

**What Origin has:** Save an entire analysis workflow (import → column assignments → baseline → corrections → peak detection → export) as a reusable template. Apply to new files with one click. This is Origin's biggest productivity feature for repetitive measurements.

**What we had:** Plot Templates that save visual settings (axis limits, labels, scale) and corrections values, but no batch-apply workflow and no column selection persistence.

**Implementation:**
- Extended template `.mat` files to include: column selections (X/Y channels), correction style, peak detection enable flag
- New `scripts.applyAnalysisTemplate(template, files)` function that batch-applies a template to multiple files: import → select columns → apply corrections → optionally detect peaks → export CSV + peak summary
- "Batch Apply..." button in Templates dialog

---

## Priority 3: Levenberg-Marquardt Fitting with Parameter Errors

**What Origin has:** LM optimizer with covariance matrix → parameter standard errors, confidence intervals, correlation matrix. This is what makes fitting results publishable — you need σ on every parameter.

**What we have:** Nelder-Mead (`fminsearch`) — robust but gives no uncertainty estimates. Already flagged as "Future" in CLAUDE.md.

**Implementation plan:**
- Write `+utilities/lmFit.m` using Gauss-Newton with Marquardt damping (no toolbox)
- Return: parameters, standard errors, covariance matrix, chi², reduced chi², R²
- Integrate into DataPlotter curve fitting dialog as optimizer option
- Add confidence band overlay on fitted curves

**Effort:** Medium (core algorithm ~150 lines, integration ~100 lines)

---

## Priority 4: Savitzky-Golay + FFT-Based Filtering

### FFT Filtering (bandpass/lowpass/highpass/notch)

**What Origin has:** Full frequency-domain filter suite. Essential for removing periodic noise (60 Hz pickup, mechanical vibrations) from transport/magnetometry measurements.

**What we have:** Nothing in frequency domain for 1D data (emViewerGUI has FFT for images).

**Implementation plan:**
- `+utilities/fftFilter.m` — apply frequency-domain filters to 1D data
- Filter types: lowpass, highpass, bandpass, notch (band-reject)
- Window functions: Hamming, Hanning, Blackman (reduce spectral leakage)
- Optional: power spectrum display for choosing cutoff frequencies
- GUI integration: add to corrections panel or as Advanced tool

**Effort:** Medium (~120 lines for core, ~80 for GUI integration)

---

## Priority 5: Interpolation / Resampling as Standalone Operations

**What Origin has:** Named interpolation operations (linear, cubic, spline, Akima) that output to new columns. Resample-to-common-grid for comparing datasets measured on different x-axes.

**What we have:** Internal interpolation in `datasetAlgebra.m` when combining datasets, but no standalone resample tool.

**Implementation plan:**
- `+utilities/resampleData.m` — resample data struct to a new x-grid
- Methods: linear, pchip, spline, makima
- Modes: uniform grid (specify N or step), match another dataset's grid, custom grid
- GUI: "Resample..." in Advanced menu

**Effort:** Small (~60 lines)

---

## Priority 6: Statistics Module

**What Origin has:** Descriptive stats, hypothesis testing (t-test, paired t-test, ANOVA), linear/polynomial regression with full diagnostics (R², adjusted R², F-statistic, p-values, residual normality tests).

**What we have:** Basic column stats in Data Table (mean, std, min, max). No hypothesis testing.

**Implementation plan:**
- `+utilities/tTest.m` — one-sample, two-sample, paired t-tests
- `+utilities/linRegress.m` — linear regression with R², adjusted R², F-stat, p-values, residual plots
- `+utilities/anova1way.m` — one-way ANOVA (F-test)
- GUI: "Statistics..." dialog accessible from Advanced menu
- All using MATLAB built-ins (no Statistics Toolbox)

**Effort:** Large (~400 lines total across functions + GUI)

---

## Priority 7: Interactive On-Graph Analysis (Origin "Gadgets")

**What Origin has:** Drag a region-of-interest on a plot and instantly compute: integral over region, statistics in region, interpolated values, rise/fall time, baseline. Results update as you drag the ROI.

**What we have:** Data Cursor (snap to point, delta between two clicks). Not interactive ROI-based.

**Implementation plan:**
- Interactive shaded ROI on main axes (drag edges to resize)
- Live readout panel: integral, mean, std, min, max, N points, FWHM if peak
- "Lock region" to persist the analysis
- Export region data to new dataset

**Effort:** Large (significant GUI work, ~300 lines)

---

## Summary Table

| # | Feature | Impact | Effort | Status |
|---|---------|--------|--------|--------|
| 1 | Savitzky-Golay filter | High | Small | ✅ Done |
| 2 | Analysis Templates (batch pipeline) | Very High | Medium | ✅ Done |
| 3 | Levenberg-Marquardt + param errors | Very High | Medium | Planned |
| 4 | FFT filtering (bandpass/notch) | High | Medium | Planned |
| 5 | Interpolation / resampling | Medium | Small | Planned |
| 6 | Statistics module | Medium | Large | Planned |
| 7 | Interactive ROI analysis | Medium | Large | Planned |
