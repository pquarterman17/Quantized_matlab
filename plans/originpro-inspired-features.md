# OriginPro-Inspired Features — Implementation Plan

## Codebase Context (for new sessions)

### Repository & conventions
- **Repo root:** `thin_film_toolkit_matlab/`
- **MATLAB built-ins only** — no external toolboxes allowed.
- **Functions:** PascalCase. **Variables:** camelCase. **Named args** via
  `arguments` blocks (R2021b+).
- All parsers return a unified struct: `.time`, `.values`, `.labels`,
  `.units`, `.metadata`.
- Read `CLAUDE.md` at the repo root for full conventions and structure.

### Current capabilities (baseline)

The toolkit currently has:
- **Plotting:** line, scatter, line+markers, waterfall, heatmap, contour,
  dual-axis (Y/Y2), 2D RSM with line-cuts, log/linear toggle, reference lines
- **Peak fitting:** Lorentzian, Gaussian, Pseudo-Voigt, Split Pearson VII;
  auto-detect + individual/multi-peak simultaneous; d-spacing, Scherrer,
  lattice refinement, FFT thickness
- **Data ops:** smoothing (moving avg, Gaussian), normalization (range/peak/z),
  derivatives (1st/2nd), dataset math (D1/D2, log10, diff), column calculator,
  resampling, merging, trim, offset
- **Export:** CSV (standard + Origin ASCII), XLSX, HDF5, PNG/PDF/SVG/EPS/TIFF,
  OriginPro COM automation, LabTalk script generation, clipboard
- **Unit conversion:** field, moment, temperature, angle, length

### Key file: `DataPlotter.m`
- ~11,000-line single-file uifigure GUI.
- Analysis dialogs (FFT thickness, reflectivity FFT, Williamson-Hall,
  lattice refinement) are **nested functions** inside `DataPlotter.m`,
  each launching their own `uifigure` popup with `uigridlayout`.
- New analysis features should follow the same nested-function popup pattern.

### GUI button styling constants (defined near line 329)
```matlab
BTN_ACCENT = [0.15 0.37 0.63];  % blue — analysis/fit actions
BTN_TOOL   = [0.28 0.28 0.28];  % gray — secondary tools
BTN_FG     = [1 1 1];           % white text on dark buttons
```

### Status
- **Plan written:** 2026-03-17
- **Phase 1 (Curve Fitting Engine):** Implemented 2026-03-21.

---

## Goal

Add OriginPro-inspired analysis and visualization features to the toolkit,
filling the gaps between "data import + peak fitting" and a general-purpose
scientific data analysis environment. Features are prioritized by impact for
thin-film / magnetometry / XRD researchers.

---

## Phase 1 — General Curve Fitting Engine ✅ IMPLEMENTED

**Priority:** Highest. This is the single biggest capability gap vs. OriginPro.

Currently the toolkit only fits peak shapes (Lorentzian, Gaussian, etc.).
OriginPro's power comes from fitting arbitrary models to data. This phase
adds a general-purpose curve fitting dialog with physics-relevant built-in
models.

### 1.1 Built-in model library: `+fitting/models.m`

A function returning a struct array of named models. Each model has:
- Display name, category, equation string (for UI display)
- Function handle `f(x, p)` where `p` is a parameter vector
- Parameter names, default initial guesses, and bounds
- Jacobian (optional, for future gradient-based fitting)

| Category | Model | Equation | Parameters | Use case |
|----------|-------|----------|------------|----------|
| Decay | Exponential decay | `A·exp(-x/τ) + C` | A, τ, C | Relaxation, demagnetization |
| Decay | Stretched exponential | `A·exp(-(x/τ)^β) + C` | A, τ, β, C | Glassy dynamics |
| Decay | Bi-exponential | `A₁·exp(-x/τ₁) + A₂·exp(-x/τ₂) + C` | A₁, τ₁, A₂, τ₂, C | Two-process relaxation |
| Growth | Saturation growth | `A·(1 - exp(-x/τ)) + C` | A, τ, C | Magnetization buildup |
| Power | Power law | `A·x^n + C` | A, n, C | Critical phenomena |
| Power | Allometric | `A·x^n` | A, n | Scaling relations |
| Magnetic | Langevin | `A·(coth(x/B) - B/x)` | A, B | Superparamagnetic M(H) |
| Magnetic | Brillouin | `A·B_J(g·μ_B·J·x / k_B·T)` | A, J, T | Paramagnetic M(H,T) |
| Magnetic | Curie-Weiss | `C / (x - θ)` | C, θ | χ vs T above T_C |
| Thermal | Arrhenius | `A·exp(-E_a / (k_B·x))` | A, E_a | Activated processes |
| Thermal | Bloch T^(3/2) | `M_0·(1 - B·x^(3/2))` | M_0, B | M_s(T) for ferromagnets |
| Linear | Linear | `m·x + b` | m, b | Baseline, susceptibility |
| Linear | Quadratic | `a·x² + b·x + c` | a, b, c | Polynomial baseline |
| Polynomial | Poly-N | `Σ aₙ·xⁿ` | a₀..aₙ | General polynomial (order 1–6) |
| Sigmoid | Logistic | `A / (1 + exp(-k·(x - x₀))) + C` | A, k, x₀, C | Switching curves |
| Sigmoid | Tanh | `A·tanh(k·(x - x₀)) + C` | A, k, x₀, C | Hysteresis branch |
| XRD | Williamson-Hall line | `m·(4sinθ) + (Kλ/D)` | m (strain), D (size) | W-H plot |
| Custom | User-defined | parsed expression | user-defined | Anything else |

### 1.2 Fitting dialog: nested function in `DataPlotter.m`

**Layout (~800 × 650 uifigure):**

```
┌──────────────────────────────────────────────────┐
│ Row 1: Model Selection                            │
│  Category: [dropdown]  Model: [dropdown]          │
│  Equation display (uilabel, italic)               │
├──────────────────────────────────────────────────┤
│ Row 2: Parameter Table (uitable, editable)        │
│  Name │ Value │ Lower │ Upper │ Fixed? │ Fitted  │
│  A    │ 1.0   │ 0     │ Inf   │ □      │ —       │
│  τ    │ 100   │ 0     │ Inf   │ □      │ —       │
│  C    │ 0     │ -Inf  │ Inf   │ □      │ —       │
├──────────────────────────────────────────────────┤
│ Row 3: Fit Controls                               │
│  X range: [min] to [max]  │ Weights: [none|1/y|1/y²|custom]   │
│  [Auto-Guess]  [Simulate]  [FIT]  [Copy Results] │
├──────────────────────────────────────────────────┤
│ Row 4 (flex): Plot                                │
│  Data + model overlay. Residuals below.           │
├──────────────────────────────────────────────────┤
│ Row 5: Fit Statistics                             │
│  R² = 0.9987  χ²_red = 1.23  RMSE = 0.0045      │
│  AIC = -234.5  Iterations: 847                    │
└──────────────────────────────────────────────────┘
```

### 1.3 Fitting engine: `+fitting/curveFit.m`

```matlab
function result = curveFit(xData, yData, modelFcn, p0, options)
%CURVEFIT  General-purpose curve fitting via fminsearch.
%
%   result = curveFit(x, y, @(x,p) model(x,p), p0)
%   result = curveFit(x, y, modelFcn, p0, 'Lower', lb, 'Upper', ub)
%
%   Inputs:
%     xData    - [N×1] independent variable
%     yData    - [N×1] dependent variable
%     modelFcn - function handle f(x, p) → [N×1]
%     p0       - [1×M] initial parameter vector
%     options (name-value):
%       Lower     - [1×M] lower bounds (enforced via penalty)
%       Upper     - [1×M] upper bounds (enforced via penalty)
%       Weights   - [N×1] weights (default: uniform)
%       MaxIter   - max iterations (default: 5000·M)
%       TolFun    - function tolerance (default: 1e-10)
%
%   Output (struct):
%     .params   - [1×M] fitted parameters
%     .residuals- [N×1] yData - yModel
%     .yFit     - [N×1] model at fitted params
%     .R2       - coefficient of determination
%     .chiSqRed - reduced chi-squared
%     .RMSE     - root mean squared error
%     .AIC      - Akaike information criterion
%     .exitFlag - fminsearch exit condition
%     .nIter    - number of iterations used
```

**Bound enforcement:** Since `fminsearch` is unconstrained, enforce bounds
via parameter transformation (logit mapping for bounded params) or barrier
penalty. The logit approach is cleaner:

```matlab
% Map bounded param to unbounded space for optimizer
pFree = log((p - lb) ./ (ub - p));    % logit transform
% Inverse: p = lb + (ub - lb) ./ (1 + exp(-pFree))
```

### 1.4 Auto-guess: `+fitting/autoGuess.m`

Heuristic initial parameter estimation from data shape:
- **Exponential:** A ≈ range(y), τ ≈ x at y = A/e, C ≈ min(y)
- **Power law:** log-log linear regression for A, n
- **Langevin:** A ≈ max(|y|), B from slope at origin
- **Sigmoid:** A ≈ range(y), x₀ ≈ midpoint, k from steepness

### 1.5 Custom equation parser

Allow users to type equations like `A*exp(-x/tau) + C`. Parse into a
function handle using a safe tokenizer (NOT `eval`). The parser should:
- Recognize `x` as the independent variable
- Identify single-letter or named parameters (A, tau, C, etc.)
- Support: `+`, `-`, `*`, `/`, `^`, `()`, `exp`, `log`, `log10`, `sqrt`,
  `sin`, `cos`, `tan`, `abs`, `tanh`, `coth`, `erf`
- Build a function handle via nested anonymous functions or a switch-based
  expression tree

### 1.6 Files to create

| File | Purpose |
|------|---------|
| `+fitting/models.m` | Built-in model library (struct array) |
| `+fitting/curveFit.m` | General curve fitting engine |
| `+fitting/autoGuess.m` | Heuristic initial parameter estimation |
| `+fitting/parseEquation.m` | Safe custom equation → function handle |
| `tests/test_curve_fitting.m` | Unit tests for fitting engine + models |

---

## Phase 2 — Worksheet / Data Table View

**Priority:** High. OriginPro's worksheet is where users inspect, edit, and
understand their data. The GUI currently shows only plots — no way to see
the actual numbers.

### 2.1 Data table panel in `DataPlotter.m`

Add a toggleable panel (button or tab) that shows raw data in a `uitable`:
- Columns: X-axis + all Y columns, with headers from `.labels` and `.units`
- Row numbers in first column
- Editable cells: user can correct outliers, fill NaN gaps
- Changes write back to `ds.corrData` (non-destructive; raw data preserved)
- Summary row at bottom: mean, σ, min, max per column

### 2.2 Data masking

- Click a row to toggle "masked" state (grayed out, excluded from fits/stats)
- Masked points appear as hollow markers on the plot
- Range masking: enter X or Y bounds, mask all points in range
- Conditional masking: `Y < threshold` or `Y > threshold`
- Masks stored in `ds.mask` as a logical vector
- All fitting/stats code checks mask before operating

### 2.3 Column operations from table context menu

Right-click a column header to access:
- Sort ascending/descending
- Set as X-axis
- Statistics (popup with mean, median, σ, skew, kurtosis)
- Fill NaN (linear interp, previous value, or constant)
- Delete column

### 2.4 Where to add in the GUI

Add a toggle button in the toolbar area (near the plot controls). When
active, the main plot area splits: top half = plot, bottom half = table.
Or use a tabbed view: "Plot" | "Table" | "Both" radio buttons.

---

## Phase 3 — Publication Graph Templates ✅ IMPLEMENTED

**Priority:** High. Researchers spend significant time reformatting plots
for different journals.

### 3.1 Template struct: `+styles/template.m`

Extend the existing `styles.default()` pattern:

```matlab
t = styles.template('aps');
% t.fontSize.axis    = 9;
% t.fontSize.label   = 10;
% t.fontSize.title   = 11;
% t.fontName         = 'Helvetica';
% t.lineWidth        = 1.5;
% t.markerSize       = 4;
% t.figWidth_cm      = 8.6;   % single-column APS
% t.figHeight_cm     = 6.5;
% t.dpi              = 600;
% t.axisBox          = true;
% t.gridAlpha        = 0;     % no grid for journals
% t.legendLocation   = 'northeast';
% t.legendBox        = false;
% t.tickDirection    = 'in';
% t.tickLength       = 0.02;
% t.colors           = [...]; % journal-appropriate color cycle
```

### 3.2 Built-in templates

| Name | Width | Font | Target |
|------|-------|------|--------|
| `aps` | 8.6 cm (single) / 17.8 cm (double) | Helvetica 9pt | APS journals (PRB, PRL, PRApplied) |
| `nature` | 8.9 cm (single) / 18.3 cm (double) | Arial 7pt | Nature family |
| `thesis` | 15 cm | Times 11pt | Dissertation figures |
| `presentation` | 25 cm | Arial 18pt | Conference slides |
| `poster` | 30 cm | Arial 24pt | Research posters |
| `dark` | 25 cm | Consolas 14pt, white-on-black | Screen presentations |

### 3.3 Template save/load

- "Save as template" button: captures current plot appearance → `.mat` file
  in `+styles/templates/`
- "Apply template" dropdown in GUI toolbar
- Template affects: fonts, sizes, line widths, colors, grid, box, ticks,
  legend style, figure dimensions

### 3.4 Files to create/modify

| File | Purpose |
|------|---------|
| `+styles/template.m` | Template loader (returns struct by name) |
| `+styles/templates/` | Directory for user-saved template `.mat` files |
| `+plotting/applyTemplate.m` | Apply a template struct to axes + figure |
| `DataPlotter.m` | Template dropdown + save/apply buttons |

---

## Phase 4 — Statistical Analysis Panel ✅ CORE IMPLEMENTED

**Priority:** Medium. Fills a significant gap for users who currently
export to Origin just for basic statistics.

### 4.1 Descriptive statistics dialog

Popup dialog (nested function in `DataPlotter.m`) showing:
- Per-column: N, mean, median, σ, SEM, min, max, skewness, kurtosis
- Histogram of selected column with optional distribution fit
  (normal, log-normal)
- Export to CSV or clipboard

### 4.2 Linear regression with confidence bands

Extend the curve fitting engine or add a quick-access "Linear Fit" button:
- Slope, intercept, R², standard errors
- 95% confidence band and prediction band overlaid on plot
- Residuals subplot

### 4.3 Dataset comparison

For comparing two loaded datasets (e.g., sample A vs. sample B):
- Two-sample t-test (assuming unequal variance)
- Kolmogorov-Smirnov test (distribution comparison)
- Results shown in a summary popup

### 4.4 Correlation matrix

When a dataset has multiple Y columns:
- Compute pairwise Pearson correlation coefficients
- Display as a colored matrix (heatmap) in a popup figure
- Useful for multi-channel magnetometry or multi-element SIMS data

---

## Phase 5 — Interactive Analysis Gadgets ✅ ROI IMPLEMENTED

**Priority:** Medium. OriginPro's gadgets are floating tools that operate
on a selected region. These would add significant interactivity.

### 5.1 Integration gadget

- User drags a region on the plot (two vertical lines)
- Area computed via trapezoidal rule + Simpson's rule
- Result displayed in a floating label on the plot
- Useful for: integrated intensity, total magnetization change

### 5.2 Rise time gadget

- User selects a transition region
- Computes 10-90% rise time (or user-defined percentiles)
- Shows horizontal reference lines at 10% and 90% levels
- Useful for: switching measurements, thermal transitions

### 5.3 Spline baseline editor

Upgrade from the current linear background subtraction:
- Click to place anchor points on the plot
- Spline (pchip) interpolated through anchor points
- Drag anchor points to refine
- "Subtract" button removes the spline baseline from data
- Useful for: XRD with curved backgrounds, broad amorphous humps

### 5.4 Cluster / region statistics

- Draw a freeform region on a 2D plot (e.g., RSM)
- Get: point count, mean intensity, integrated intensity, centroid
- Useful for: isolating a Bragg peak in a 2D RSM, ROI analysis

---

## Phase 6 — Multi-Panel / Linked Plots ✅ IMPLEMENTED

**Priority:** Medium. Essential for publication figures and fitting
diagnostics.

### 6.1 Split-panel layouts

Add a "Layout" menu or toolbar section:
- **1×1** (default): single plot
- **2×1 stacked**: main plot + residuals below (shared X-axis)
- **1×2 side-by-side**: two datasets compared (shared Y-axis)
- **2×2 grid**: four panels for multi-dataset comparison

Implementation: use nested `uigridlayout` to create sub-axes. Each panel
gets its own `uiaxes`. Linked axes share limits via `linkaxes()` equivalent
(listener on `XLim`/`YLim` changes).

### 6.2 Residuals panel

When fitting is active (peak fit or curve fit), auto-show a residuals
subplot below the main plot:
- Residuals = data - model (or data/model for reflectivity)
- Horizontal zero line
- Helps users judge fit quality at a glance

### 6.3 Inset zoom (already partially exists)

Enhance the existing inset feature:
- Draggable inset position and size
- Rectangle on main plot showing the zoomed region
- Auto-update when main plot is modified

---

## Phase 7 — Batch Parameter Extraction ✅ IMPLEMENTED

**Priority:** Medium-high. This is the workflow that makes Origin
indispensable for systematic studies.

### 7.1 Batch fit dialog

- Select a model (from Phase 1's library)
- Select multiple loaded datasets
- Run the same fit on each dataset
- Collect fitted parameters into a summary table (one row per dataset)

### 7.2 Parameter trend plotting

- After batch fitting, plot any extracted parameter vs. dataset index
  or vs. a metadata field (temperature, field, thickness)
- Example: fit Langevin to 20 M(H) curves at different T,
  plot saturation magnetization vs. T → get Bloch T^3/2 law

### 7.3 Peak tracking across datasets

OriginPro's "Quick Peaks" tracks a peak across a series:
- Select a peak in one dataset (by position)
- Auto-find the nearest peak in each other loaded dataset
- Output: peak center, FWHM, height, area vs. dataset index
- Useful for: tracking Bragg peak shift with temperature/strain

### 7.4 Files to create

| File | Purpose |
|------|---------|
| `+fitting/batchFit.m` | Run a model fit across multiple datasets |
| `+fitting/trackPeak.m` | Track a peak across a dataset series |
| `DataPlotter.m` | Batch fit dialog + parameter trend plot |

---

## Phase 8 — Quality-of-Life & Polish

### 8.1 Figure composition / report sheet

- Arrange multiple plots on a canvas with labeled panels (a, b, c, d)
- Add shared title, arrows, text annotations
- Export composite figure as single PNG/PDF
- Implementation: a new standalone GUI (`figureComposerGUI.m`)

### 8.2 Dataset grouping / project tree

- Organize loaded datasets into named groups (folders in the list)
- Collapse/expand groups
- Batch operations on groups (export all, apply same fit, etc.)

### 8.3 Script / macro log

- Record all GUI actions as MATLAB commands
- Export as a reproducible `.m` script
- Users can replay or modify the script

### 8.4 3D surface plots

- `surf`/`mesh` rendering for 2D RSM data (already have the data)
- Interactive rotation, lighting
- Useful for: reciprocal space maps, angular-dependent measurements

---

## Implementation Order (Recommended)

| Order | Phase | Effort | Impact | Dependencies |
|-------|-------|--------|--------|--------------|
| 1 | Phase 1: Curve Fitting Engine | Large | Highest | ✅ Done — `+fitting/` package |
| 2 | Phase 3: Graph Templates | Small | High | ✅ Done — `+styles/template.m` |
| 3 | Phase 7: Batch Parameter Extraction | Medium | High | ✅ Done — `+fitting/batchFit.m`, `trackPeak.m` |
| 4 | Phase 2: Worksheet View | Medium | High | ✅ Already existed in DataPlotter |
| 5 | Phase 5: Analysis Gadgets | Medium | Medium | ✅ ROI done — `+dataplotter/roiAnalysis.m` |
| 6 | Phase 6: Multi-Panel Plots | Medium | Medium | ✅ Done — `+dataplotter/multiPanel.m` |
| 7 | Phase 4: Statistics Panel | Small | Medium | ✅ Core done (no GUI yet) |
| 8 | Phase 8: QoL & Polish | Large | Medium | Phases 1-7 benefit from these |

---

## Known Constraints

- **No external toolboxes** — all fitting uses `fminsearch` (Nelder-Mead).
  No `lsqcurvefit`, `nlinfit`, or Optimization Toolbox.
- **No `eval()`** — custom equation parsing must use safe tokenization,
  not `eval` or `str2func` with dynamic strings.
- **GUI is monolithic** — new dialogs are nested functions in
  `DataPlotter.m`. Consider whether the file (already ~11k lines) needs
  to be split before adding more. The curve fitting dialog alone could add
  500-800 lines.
- **fminsearch limitations** — no native bounds support (use logit
  transform), no gradient information, can get stuck in local minima for
  complex models. Adequate for 2-8 parameter models typical of this toolkit.

---

## References & Inspiration

- [OriginPro Feature List](https://www.originlab.com/index.aspx?go=Products/Origin)
- OriginPro's Analysis → Fitting → Nonlinear Curve Fit dialog
- OriginPro's Gadgets (Quick Fit, Integrate, Rise Time, Statistics)
- OriginPro's Graph Templates and Theme Organizer
- OriginPro's Batch Processing with Parameter Summary
