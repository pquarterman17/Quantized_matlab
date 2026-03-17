# XRR / Neutron Reflectivity Fitting — Implementation Plan

## Codebase Context (for new sessions)

This section provides everything needed to pick up implementation without
re-exploring the codebase.

### Repository & conventions
- **Repo root:** `thin_film_toolkit_matlab/`
- **MATLAB built-ins only** — no external toolboxes allowed
- **Functions:** PascalCase. **Variables:** camelCase. **Named args** via
  `arguments` blocks (R2021b+).
- All parsers return a unified struct: `.time`, `.values`, `.labels`,
  `.units`, `.metadata`.
- Read `CLAUDE.md` at the repo root for full conventions and structure.

### Key file: `dataImportGUI.m`
- ~11,000-line single-file uifigure GUI.
- All analysis dialogs (FFT thickness, reflectivity FFT, Williamson-Hall,
  lattice refinement) are **nested functions** inside `dataImportGUI.m`,
  each launching their own `uifigure` popup with `uigridlayout`.
- The new "Fit R(Q)" dialog should follow the same pattern.

### GUI button styling constants (defined near line 329)
```matlab
BTN_ACCENT = [0.15 0.37 0.63];  % blue — analysis/fit actions
BTN_TOOL   = [0.28 0.28 0.28];  % gray — secondary tools
BTN_FG     = [1 1 1];           % white text on dark buttons
```

### Where to add the launch button
The advanced peak tools row is at **line ~1806**:
```matlab
peakAdvGL = uigridlayout(peakBtnGL, [1 3], ...);  % currently 3 columns
peakAdvGL.Layout.Row = 8; peakAdvGL.Layout.Column = [1 2];
```
It holds: `btnWHPlot` (col 1), `btnFFTThickness` (col 2),
`btnRefineLattice` (col 3). Expand to `[1 4]` and add `btnFitRefl` in
col 4. The `btnReflFFT` button is in a separate row above (line ~1787).

### Visibility / enable logic (line ~3140–3254)
The GUI switches UI visibility based on the parser used:
- **XRD parsers** (~line 3143): all peak tools + `btnReflFFT` visible.
  The new `btnFitRefl` should also be visible here.
- **Neutron parsers** (~line 3220): peak tools hidden, but `btnReflFFT`
  visible (line 3242). The new `btnFitRefl` should be visible alongside it.
- **Magnetometry / SIMS / generic**: `btnFitRefl` should be hidden.

The enable/disable arrays to update are at lines ~3155–3158 (XRD) and
~3237–3242 (neutron).

### Existing helper functions (bottom of dataImportGUI.m)
| Function | Line | Purpose |
|----------|------|---------|
| `guiTernary(cond, a, b)` | ~11095 | Inline ternary: returns `a` if cond, else `b` |
| `isNeutronParser(pName)` | ~11417 | Returns true for NCNR parsers |
| `extractWavelength_A(ds)` | ~11642 | Gets wavelength from dataset metadata |
| `guiCountingTime(ds)` | ~11466 | Gets XRD counting time |

### How existing FFT dialogs access data
```matlab
ds  = appData.datasets{appData.activeIdx};
d   = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
xAll = d.time(:);      % Q (Å⁻¹) for neutron; 2θ (°) for XRR
yAll = d.values(:,1);  % R or intensity
```

### Existing FFT results that can seed initial layer guesses
- `ds.filmThickness` — set by the Laue FFT dialog (`onFFTThickness`,
  line ~4901). Fields: `.thickness_nm`, `.uncertainty_nm`, `.wavelength_A`
- `ds.kiessigThickness` — set by the reflectivity FFT dialog
  (`onReflectivityFFT`, line ~5135). Fields: `.thicknesses_nm`,
  `.amplitudes`, `.superlattice.detected`, `.superlattice.bilayerPeriod_nm`,
  `.superlattice.totalThickness_nm`, `.superlattice.nRepeats`,
  `.superlattice.sublayerA_nm`, `.superlattice.sublayerB_nm`

### X-ray source lookup table (line ~1833)
`XRAY_SOURCES` is a cell array `{displayName, wavelength_A; ...}` with
Cu Kα1, Cu Kα2, Mo Kα1, Co Kα1, Cr Kα1, Fe Kα1, Ag Kα1, Custom.
Available in the parent scope of any nested function.

### Fitting pattern already used in the codebase
Peak fitting (line ~4095) uses:
```matlab
opts = optimset('MaxFunEvals', 3000, 'MaxIter', 1500, ...
                'TolFun', 1e-10, 'TolX', 1e-8, 'Display', 'off');
pFit = fminsearch(objFun, p0, opts);
```
Follow this same pattern for reflectivity fitting.

### Test data available
- `+test_datasets/NCNR/` — neutron reflectometry `.refl`, `.pnr`,
  `.datA`–`.datD` files (with Q, dQ, R, dR, theory, fresnel columns)
- Verify against the `theory` column in `.datA` files — these are
  refl1d-computed reflectivity curves that serve as ground truth.

### New files to create
| File | Purpose |
|------|---------|
| `+utilities/parrattRefl.m` | Pure function: Parratt recursion → R(Q) |
| `+utilities/sldProfile.m` | Pure function: stack → SLD vs depth |
| `+utilities/reflSLDPresets.m` | Function returning the SLD lookup table |
| `tests/test_parratt.m` | Unit tests for parrattRefl against known cases |

### Status
- **Plan written:** 2026-03-16
- **Implementation:** Not started. Begin with Phase 1 (core engine).

---

## Goal

Add a simple reflectivity fitting capability to `dataImportGUI.m` that lets users
define a layer stack (substrate / films / ambient), compute a model reflectivity
curve via Parratt recursion, overlay it on measured data, and refine layer
parameters with least-squares fitting. Inspired by the NIST reflectometry
calculator (https://pages.nist.gov/reflectometry-calculators/).

**Scope:** Deliberately simple — a quick in-GUI fitting tool for 3–8 layer
systems, not a replacement for refl1d / GenX / Motofit. The emphasis is on
interactive exploration and rapid thickness/roughness estimation, not
publication-grade fits.

---

## 1. Physics Engine: `+utilities/parrattRefl.m`

A single pure function. No classes, no OOP. Returns R(Q) for an arbitrary
slab model.

### Signature

```matlab
function R = parrattRefl(Q, layers, options)
%PARRATTREFL  Specular reflectivity via Parratt recursion.
%
%   R = parrattRefl(Q, layers)
%   R = parrattRefl(Q, layers, 'Background', 1e-7, 'Intensity', 1.0)
%
%   Inputs
%     Q       - [N×1] wavevector transfer (Å⁻¹)
%     layers  - [M×4] matrix, one row per layer (top → bottom):
%               [thickness_A, SLD_1e-6A-2, iSLD_1e-6A-2, roughness_A]
%               Row 1 = incident medium (air): thickness = 0
%               Row M = substrate:             thickness = 0 (semi-infinite)
%     options (name-value):
%       Background  - additive constant (default 0)
%       Intensity   - multiplicative scale factor I₀ (default 1)
%
%   Output
%     R       - [N×1] specular reflectivity (|r|²)
```

### Algorithm (Parratt recursion, bottom-up)

```
For each Q value:
  1. k_z = Q / 2
  2. For each layer j, compute the z-component of the wavevector:
       k_j = sqrt(k_z² - 4π·SLD_j + i·4π·iSLD_j)
     (complex square root; evanescent waves handled naturally)
  3. Start from the substrate (bottom). Set r_{M} = 0 (no reflection below substrate).
  4. Recurse upward j = M-1 ... 1:
       Fresnel coefficient at interface j/j+1:
         f_j = (k_j - k_{j+1}) / (k_j + k_{j+1})
       Nevot-Croce roughness damping:
         f_j = f_j · exp(-2 · k_j · k_{j+1} · σ_j²)
       Parratt recursion:
         r_j = (f_j + r_{j+1} · exp(2i · k_{j+1} · d_{j+1}))
             / (1 + f_j · r_{j+1} · exp(2i · k_{j+1} · d_{j+1}))
  5. R = I₀ · |r_1|² + background
```

**No toolbox needed** — only `sqrt`, `exp`, `abs`, `real`, `imag`.

### Resolution smearing (optional, v2)

Gaussian convolution of R(Q) with instrument dQ. Defer to a later version
unless dQ is available in the loaded dataset.

---

## 2. Layer Stack Data Structure

Keep it minimal — a struct array matching the table rows in the GUI.

```matlab
stack(j).name       = 'SiO2';           % display label
stack(j).thickness  = 150;              % Å (0 for substrate/ambient)
stack(j).sld        = 3.47;             % ×10⁻⁶ Å⁻²
stack(j).isld       = 0;                % ×10⁻⁶ Å⁻² (absorption)
stack(j).roughness  = 5;                % Å (Nevot-Croce σ)
stack(j).fitT       = true;             % fit thickness?
stack(j).fitSLD     = false;            % fit SLD?
stack(j).fitRough   = true;             % fit roughness?
```

Row 1 is always "Ambient" (air/vacuum, SLD ≈ 0, thickness = 0).
Last row is always "Substrate" (thickness = 0).
User adds/removes film layers in between.

### Common SLD presets (built-in lookup)

| Material  | SLD (×10⁻⁶ Å⁻²) | Notes            |
|-----------|-------------------|------------------|
| Air       | 0.000             | incident medium  |
| Si        | 2.074             | common substrate |
| SiO2      | 3.47              | native oxide     |
| Al2O3     | 5.67              | sapphire         |
| Au        | 4.66              | gold cap         |
| Ni        | 9.41              | magnetic layer   |
| Fe        | 8.02              | magnetic layer   |
| Ti        | -1.95             | negative SLD     |
| Cu        | 6.55              |                  |
| D2O       | 6.34              | deuterated water |
| H2O       | -0.56             | light water      |

For X-ray mode, SLD = r_e · ρ_e where r_e = 2.818e-5 Å. Provide a
toggle or separate presets for neutron vs. X-ray SLD values.

---

## 3. GUI Dialog: "Fit Reflectivity"

Launched from a new button in the advanced peak tools row (next to the
existing "FFT Thick." and "Refl FFT" buttons). Only enabled when the
loaded data looks like reflectivity (neutron .refl/.pnr or XRR with
appropriate Q/2θ x-axis).

### Layout (uifigure, ~900 × 700)

```
┌─────────────────────────────────────────────────────┐
│ Row 1 (120px): Layer Table (uitable, editable)      │
│  # │ Name │ d (Å) │ SLD │ iSLD │ σ (Å) │ Fit?     │
│  1 │ Air  │  0    │ 0.0 │  0   │  —    │          │
│  2 │ Film │ 200   │ 4.0 │  0   │  5    │ ☑d ☑σ    │
│  3 │ Sub  │  0    │ 2.07│  0   │  3    │ ☑σ       │
│  [+ Add Layer]  [- Remove]  [▲ Up]  [▼ Down]       │
│  [Material preset dropdown]                         │
├─────────────────────────────────────────────────────┤
│ Row 2 (28px): Global params + Fit button            │
│  I₀: [1.0]  Bkg: [1e-7]  [Simulate]  [FIT]        │
├─────────────────────────────────────────────────────┤
│ Row 3 (flex, '2x'): R vs Q plot                     │
│  Log scale. Data points + model curve overlay.      │
│  Residuals sub-plot below (optional).               │
├─────────────────────────────────────────────────────┤
│ Row 4 (100px): SLD profile plot                     │
│  SLD vs. depth (z). Step profile with erf roughness.│
├─────────────────────────────────────────────────────┤
│ Row 5 (50px): Fit results                           │
│  χ² = X.XX   Iterations: N   Status: converged     │
└─────────────────────────────────────────────────────┘
```

### Layer table details

- **uitable** with editable cells for thickness, SLD, iSLD, roughness
- "Fit?" column: checkboxes (one per fittable param: d, SLD, σ)
  - Implementation: three logical columns (FitT, FitSLD, FitRough) shown
    as checkboxes, or a single text column with abbreviated flags
- Row 1 (Ambient) and last row (Substrate) have thickness locked at 0
- Ambient iSLD locked at 0
- "[+ Add Layer]" inserts a row above the substrate
- "[- Remove]" deletes selected film layer (not ambient/substrate)
- "[▲ Up] [▼ Down]" reorder film layers
- Material preset dropdown → populates SLD/iSLD for the selected row

### Interaction flow

1. **On open**: Pre-fill from FFT results if available (use bilayer period
   from the reflectivity FFT or Laue FFT as initial thickness guess).
   Default: Air / single Film / Si substrate.
2. **Simulate**: Compute R(Q) from current table values, overlay on data.
   No fitting — just forward calculation.
3. **Fit**: Run `fminsearch` on checked parameters. Update table with
   fitted values. Update plots. Show χ².
4. **Live simulation**: Optionally, recompute on every table cell edit
   (checkbox to enable/disable — can be slow for large datasets).

---

## 4. Fitting Algorithm

### Parameter vector assembly

```matlab
% Gather fittable parameters into a 1D vector p0
p0 = [];
paramMap = {};  % tracks which parameter maps to which layer/field
for j = 1:numel(stack)
    if stack(j).fitT
        p0(end+1) = stack(j).thickness;
        paramMap{end+1} = struct('layer', j, 'field', 'thickness');
    end
    if stack(j).fitSLD
        p0(end+1) = stack(j).sld;
        paramMap{end+1} = struct('layer', j, 'field', 'sld');
    end
    if stack(j).fitRough
        p0(end+1) = stack(j).roughness;
        paramMap{end+1} = struct('layer', j, 'field', 'roughness');
    end
end
```

### Objective function

```matlab
function chi2 = refl_objective(p, Q, R_data, R_err, stack, paramMap, I0, bkg)
    % Unpack p into stack
    for k = 1:numel(p)
        stack(paramMap{k}.layer).(paramMap{k}.field) = p(k);
    end
    % Enforce physical constraints
    for j = 1:numel(stack)
        stack(j).thickness = max(stack(j).thickness, 0);
        stack(j).roughness = max(stack(j).roughness, 0);
    end
    % Build layers matrix
    layers = stack2matrix(stack);
    % Compute model
    R_model = parrattRefl(Q, layers, 'Background', bkg, 'Intensity', I0);
    % Chi-squared (log-space for reflectivity spanning decades)
    logR_data  = log10(max(R_data, 1e-30));
    logR_model = log10(max(R_model, 1e-30));
    if ~isempty(R_err) && any(R_err > 0)
        % Propagate errors to log space: δ(log R) ≈ δR / (R · ln10)
        logR_err = R_err ./ (max(R_data, 1e-30) * log(10));
        chi2 = sum(((logR_data - logR_model) ./ logR_err).^2);
    else
        chi2 = sum((logR_data - logR_model).^2);
    end
end
```

### Optimizer

Use `fminsearch` (Nelder-Mead, no toolbox required). Set reasonable
options:

```matlab
opts = optimset('MaxFunEvals', 5000 * numel(p0), ...
                'MaxIter',     2000 * numel(p0), ...
                'TolFun',      1e-8, ...
                'TolX',        1e-6, ...
                'Display',     'off');
pFit = fminsearch(@(p) refl_objective(p, Q, R, Rerr, stack, paramMap, I0, bkg), p0, opts);
```

**Why fminsearch**: Already used elsewhere in the GUI for peak fitting.
No toolbox needed. Nelder-Mead is robust for ~5-20 parameters typical of
simple reflectivity models. Not ideal for large parameter spaces, but fine
for the 3–8 layer scope here.

**Parameter scaling**: Before fitting, normalise parameters so they're
similar magnitude (divide thickness by 100, multiply SLD by 10, etc.).
The NIST calculator does similar scaling. This helps Nelder-Mead converge.

---

## 5. SLD Profile Plot

Display the real-space SLD depth profile:

```matlab
function [z, sld_profile] = computeSLDProfile(stack, zRange, nPts)
    % Build step profile with error-function (erf) roughness transitions
    z = linspace(0, zRange, nPts);
    sld_profile = zeros(size(z));
    zInterface = 0;
    for j = numel(stack):-1:2  % substrate → top
        d_j   = stack(j).thickness;
        sld_j = stack(j).sld;
        sig   = max(stack(j).roughness, 0.1);  % avoid /0
        % erf transition at each interface
        sld_profile = sld_profile + ...
            (sld_j - prevSLD) * 0.5 * (1 + erf((z - zInterface) / (sig * sqrt(2))));
        zInterface = zInterface + d_j;
    end
end
```

Plot as a step-like curve with smooth transitions at interfaces. Update
on every simulate/fit. Shows the user their physical model at a glance.

---

## 6. Integration with Existing GUI

### Where to launch

Add a button `btnFitRefl` in the advanced peak tools row, next to the
existing `btnFFTThickness` and `btnReflFFT`:

```matlab
btnFitRefl = uibutton(peakAdvGL, 'Text', 'Fit R(Q)', ...
    'ButtonPushedFcn', @onFitReflectivity, ...
    'Tooltip', 'Fit reflectivity data with a slab model (Parratt recursion)');
```

Enable only when data has reflectivity-like characteristics (check parser
name or x-axis units for Q / 2θ).

### Pre-population from FFT results

If `ds.kiessigThickness` exists (from the reflectivity FFT dialog):
- Use the detected bilayer period or dominant thickness as initial film
  thickness
- If superlattice detected, pre-build a [A/B]×N stack using the estimated
  Λ, d_A, d_B, and N values

If `ds.filmThickness` exists (from the Laue FFT dialog):
- Use as single-film initial thickness

### Data extraction

```matlab
d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
Q = d.time(:);     % Already in Å⁻¹ for neutron; convert from 2θ for XRR
R = d.values(:,1); % Primary reflectivity column

% Look for error bars
errCol = find(contains(d.labels, 'dR') | contains(d.labels, 'err'), 1);
if ~isempty(errCol)
    R_err = d.values(:, errCol);
else
    R_err = [];
end
```

### Persisting fit results

```matlab
ds.reflFit.stack      = stack;       % fitted layer stack
ds.reflFit.Q          = Q;
ds.reflFit.R_model    = R_fit;       % model curve at fitted params
ds.reflFit.chi2       = chi2;
ds.reflFit.I0         = I0;
ds.reflFit.background = bkg;
```

---

## 7. File Organisation

| File | Purpose |
|------|---------|
| `+utilities/parrattRefl.m` | Pure function: Parratt recursion → R(Q) |
| `+utilities/sldProfile.m` | Pure function: stack → SLD vs depth |
| `+utilities/reflSLDPresets.m` | Function returning the SLD lookup table |
| `dataImportGUI.m` | New `onFitReflectivity` nested function + dialog |

No new GUI files — the reflectivity fit dialog is a nested function inside
`dataImportGUI.m`, same pattern as `onFFTThickness` and `onReflectivityFFT`.

---

## 8. Implementation Phases

### Phase 1: Core engine (small, testable)
- [ ] `parrattRefl.m` — Parratt recursion with Nevot-Croce roughness
- [ ] `sldProfile.m` — SLD depth profile computation
- [ ] `reflSLDPresets.m` — material SLD lookup table
- [ ] Unit tests: verify against known analytical cases
  - Single interface (Fresnel): R = |( k₁ − k₂ ) / ( k₁ + k₂ )|²
  - Si substrate in air: critical edge at Q_c = 0.0316 Å⁻¹
  - Known thin film: compare to refl1d output

### Phase 2: GUI dialog (simulate only)
- [ ] Button + enable/disable logic in dataImportGUI
- [ ] Dialog layout: layer table, SLD profile, R(Q) overlay
- [ ] Material preset dropdown
- [ ] Add/remove/reorder layers
- [ ] Simulate button: forward calculation, overlay on data
- [ ] Pre-populate from FFT results

### Phase 3: Fitting
- [ ] Parameter vector assembly from fit checkboxes
- [ ] Objective function (log-space χ²)
- [ ] fminsearch integration
- [ ] Update table + plots with fitted values
- [ ] χ² and convergence status display
- [ ] Persist results to dataset struct

### Phase 4: Polish
- [ ] Live simulation toggle (auto-recompute on cell edit)
- [ ] Residuals sub-plot (R_data / R_model or log difference)
- [ ] Export fitted parameters to workspace / CSV
- [ ] Resolution smearing (Gaussian convolution with dQ if available)
- [ ] Superlattice repeat shorthand: define [A/B]×N without manually
  adding N×2 rows

---

## 9. Known Limitations & Out of Scope

- **No magnetic SLD** — would need separate SLD⁺/SLD⁻ for spin-up/down.
  Out of scope for v1; users should use refl1d for magnetic fitting.
- **No off-specular** — purely specular R(Q).
- **No graded layers** — only discrete slabs with erf roughness.
- **No co-refinement** — single dataset at a time.
- **Nelder-Mead limitations** — can get stuck in local minima for
  complex models. Mitigated by good initial guesses from FFT and by
  keeping models small (3–8 layers). For better optimisation, users
  should export to refl1d.
- **No MCMC / uncertainty** — just point estimates from fminsearch.

---

## 10. References

- Parratt, L. G. (1954). Phys. Rev. 95, 359.
- Névot, L. & Croce, P. (1980). Rev. Phys. Appl. 15, 761.
- NIST reflectometry calculator: https://pages.nist.gov/reflectometry-calculators/
  - Maranville, B. B. et al. (2018). J. Res. NIST 122, 34. doi:10.6028/jres.122.034
- refl1d: https://github.com/reflectometry/refl1d
