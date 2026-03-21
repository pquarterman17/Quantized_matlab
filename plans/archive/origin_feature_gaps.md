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

## Priority 3: General Curve Fitting Engine with Parameter Errors ✅ IMPLEMENTED

**Status:** Implemented as `+fitting/` package (2026-03-21).

**What Origin has:** LM optimizer with covariance matrix → parameter standard errors, confidence intervals, correlation matrix. This is what makes fitting results publishable — you need σ on every parameter.

**What we had:** Nelder-Mead (`fminsearch`) — robust but gave no uncertainty estimates.

**Implementation (chose different approach than original plan):**
- `+fitting/curveFit.m` — fminsearch with logit bound transforms, parameter errors via numerical Hessian
- `+fitting/models.m` — 23 built-in models (decay, growth, peaks, power, sigmoid, magnetic, thermal)
- `+fitting/autoGuess.m` — heuristic initial parameter estimation from data shape
- `+fitting/parseEquation.m` — safe RPN-based custom equation parser (no eval)
- Refactored `+dataplotter/curveFitting.m` dialog: category/model dropdowns, bounds, fixed params, weights, simulate, auto-guess, error display, chi²/AIC stats
- Returns: params ± errors, covariance matrix, R², χ²_red, RMSE, AIC
- 35 unit tests (all passing)

---

## Priority 4: FFT-Based Filtering ✅ IMPLEMENTED

**Status:** Implemented as `+utilities/fftFilter.m` (2026-03-21).

**What Origin has:** Full frequency-domain filter suite. Essential for removing periodic noise (60 Hz pickup, mechanical vibrations) from transport/magnetometry measurements.

**What we had:** Nothing in frequency domain for 1D data (emViewerGUI has FFT for images).

**Implementation:**
- `+utilities/fftFilter.m` — Butterworth-based frequency-domain filters for 1D data
- Filter types: lowpass, highpass, bandpass, notch (band-reject)
- Window functions: none, Hamming, Hanning, Blackman
- Optional detrend (removes/restores linear trend across filtering)
- Returns: filtered data + power spectrum + transfer function for diagnostics
- 10 unit tests (all passing)
- GUI integration: not yet wired into DataPlotter corrections panel

---

## Priority 5: Interpolation / Resampling ✅ IMPLEMENTED

**Status:** Implemented as `+utilities/resampleData.m` (2026-03-21).

**Implementation:**
- Methods: linear, pchip, spline, makima (default)
- Modes: NPoints, Step, Grid, MatchDataset
- Preserves labels, units, metadata; adds resampling metadata
- 8 unit tests (all passing)

---

## Priority 6: Statistics Module ✅ IMPLEMENTED

**Status:** Core statistics implemented (2026-03-21). GUI dialog not yet wired.

**Implementation:**
- `+utilities/descriptiveStats.m` — N, mean, median, std, SEM, var, min, max, range, Q1, Q3, IQR, skewness, kurtosis (with NaN handling)
- `+utilities/tTest.m` — one-sample, two-sample (Welch), paired t-tests with p-values via betainc (no Statistics Toolbox)
- `+utilities/linRegress.m` — OLS polynomial regression with R², R²adj, F-stat, p-values, coefficient SEs, confidence/prediction bands
- All use MATLAB built-ins only (t-CDF via regularized incomplete beta function)
- 23 unit tests (all passing)
- Still TODO: ANOVA, GUI dialog

---

## Priority 7: Interactive On-Graph Analysis (Origin "Gadgets") ✅ IMPLEMENTED

**Status:** Implemented as `+dataplotter/roiAnalysis.m` (2026-03-21).

**Implementation:**
- `+dataplotter/roiAnalysis.m` — Interactive ROI gadget dialog
- Click two points on the main axes to define region (shaded patch overlay)
- Live readout: N, integral (trapz), mean, std, min/max with x-positions, median, FWHM
- Copy stats to clipboard
- Export region as new dataset (callback or workspace variable)
- Channel selector, numeric bound fields, visual overlay with boundary lines

---

## Summary Table

| # | Feature | Impact | Effort | Status |
|---|---------|--------|--------|--------|
| 1 | Savitzky-Golay filter | High | Small | ✅ Done |
| 2 | Analysis Templates (batch pipeline) | Very High | Medium | ✅ Done |
| 3 | General curve fitting + param errors | Very High | Medium | ✅ Done |
| 4 | FFT filtering (bandpass/notch) | High | Medium | ✅ Done |
| 5 | Interpolation / resampling | Medium | Small | ✅ Done |
| 6 | Statistics module | Medium | Large | ✅ Done (core) |
| 7 | Interactive ROI analysis | Medium | Large | ✅ Done |
