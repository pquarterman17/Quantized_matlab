# Materials Calculator & Unit Converter — Architecture Plan

## Codebase Context (for new sessions)

This section provides everything needed to pick up implementation without
re-exploring the codebase.

### Repository & conventions
- **Repo root:** `thin_film_toolkit_matlab/`
- **MATLAB built-ins only** — no external toolboxes allowed.
- **Functions:** PascalCase. **Variables:** camelCase. **Named args** via
  `arguments` blocks (R2021b+).
- All parsers return a unified struct: `.time`, `.values`, `.labels`,
  `.units`, `.metadata`.
- Read `CLAUDE.md` at the repo root for full conventions and structure.

### Existing GUI architecture patterns

All three standalone GUIs follow the same monolithic-function architecture:

| File | Lines | Pattern |
|------|-------|---------|
| `xrdConvertGUI.m` | ~700 | Simplest. Single `function`, closure state via `appData` struct, nested callbacks. State stored in `fig.UserData`. |
| `emViewerGUI.m` | ~6000+ | `function varargout = emViewerGUI()`. State in `appData` (closure variable, not UserData). Nested grid layouts. Returns `api` struct when `nargout > 0`. Semantic button color palette. |
| `dataImportGUI.m` | ~11000+ | Same as emViewerGUI pattern. Largest GUI. Sub-dialogs (FFT thickness, lattice refinement, Williamson-Hall) are nested functions launching their own `uifigure`. |

**Key pattern details:**

1. **State management:** `appData` is a plain struct held in function closure.
   Nested callbacks read/write it directly. No classes, no global state.
   (emViewerGUI.m line 85-119, dataImportGUI.m line 120-136)

2. **API struct for testing:** When called with an output argument, GUIs
   return an `api` struct of function handles sharing the same closure.
   (emViewerGUI.m lines 1066-1107)
   ```matlab
   function varargout = myGUI()
       % ... build GUI, define appData ...
       if nargout > 0
           api.fig   = fig;
           api.doX   = @(arg) doXInternal(arg);
           api.close = @() close(fig);
           varargout{1} = api;
       end
   end
   ```

3. **Grid layout hierarchy:** All GUIs use `uigridlayout` exclusively for
   layout — no absolute positioning. Nested grids create sub-panels.
   (emViewerGUI.m lines 200-206: root 3-row grid; toolbar, content, status)

4. **Button color constants:** Semantic palette defined early in the function.
   (emViewerGUI.m lines 172-177)
   ```matlab
   BTN_PRIMARY = [0.18 0.52 0.18];  % green
   BTN_DANGER  = [0.55 0.15 0.15];  % red
   BTN_TOOL    = [0.28 0.28 0.28];  % gray
   BTN_EXPORT  = [0.18 0.32 0.52];  % blue
   BTN_FG      = [1 1 1];           % white text
   ```

5. **Section dividers:** `% ════════...` style between logical sections.

6. **Figure naming:** `'EM Image Viewer — Thin Film Toolkit'` pattern.

### Existing unit conversion: `+utilities/convertUnits.m` (142 lines)
- Simple `fromUnit`/`toUnit` string matching via struct lookup tables.
- Groups: magnetic field (base A/m), moment (base A*m^2), temperature
  (K/C/F with special-case formulas), angle, length.
- Each group uses `tryConvert()` helper: normalize to base unit, divide
  by target factor. Temperature uses offset formulas instead.
- Canonical display strings stored in parallel struct.
- **Limitation:** Does not parse compound units like "mA/cm^2", no SI
  prefix decomposition, no energy-wavelength conversions. The new tool
  should build a richer engine in `+calc/` that coexists with
  (and eventually could replace) this function.

---

## Problem Statement

Researchers working with thin film data constantly need to:
1. Convert between units — often compound/prefixed units like `mA/um^2`.
2. Compute crystallographic, electrical, magnetic, and thin-film quantities
   from a handful of input parameters.

These calculations are currently done in separate scripts, spreadsheets, or
mental arithmetic. A single always-open utility GUI eliminates context-switching
and reduces errors.

---

## Proposed Architecture

### File Organization

Each calculation domain is a nested package (`+calc/+crystal/`, `+calc/+electrical/`, etc.). Each public function is its own `.m` file. This allows `calc.crystal.dSpacing(...)` syntax while keeping one function per file.

#### Core modules (Phases 1-3)

```
thin_film_toolkit_matlab/
├── materialsCalcGUI.m              # Standalone GUI (~1500-2000 lines est.)
├── +calc/                          # NEW package: calculation modules
│   ├── constants.m                 # Physical constants struct (CODATA 2018)
│   ├── unitConvert.m               # Unit parsing + conversion engine
│   ├── elementData.m               # Periodic table data: Z, mass, radii, scattering lengths, etc.
│   ├── +crystal/                   # Crystal/lattice + epitaxy/strain calculations
│   │   ├── dSpacing.m
│   │   ├── twoThetaFromD.m
│   │   └── # ... 8 more functions (see table below)
│   ├── +electrical/                # Resistivity, conductivity, mobility
│   │   └── # ... 5 functions
│   ├── +semiconductor/             # Carrier densities, Fermi level, band gap, Debye length
│   │   └── # ... 13 functions
│   ├── +thinFilm/                  # Deposition rate, Kiessig, Stoney, thermal
│   │   └── # ... 7 functions
│   ├── +magnetic/                  # Magnetic unit conversions + derived quantities
│   │   └── # ... 4 functions
│   └── +substrates/                # Substrate preset library (Si, Al2O3, STO, etc.)
│       ├── getSubstrate.m
│       └── listSubstrates.m
├── tests/
│   ├── test_calc_units.m           # Unit parser + conversion engine tests
│   ├── test_calc_modules.m         # All calculation module tests (crystal, electrical, etc.)
│   └── test_materials_calc_gui.m   # Headless GUI API tests
```

#### Phase 4: X-ray/Neutron integration (into dataImportGUI)

```
├── +calc/
│   └── +xrayNeutron/               # Bragg, Q<->2theta, SLD, stoichiometry, formula parser
│       └── # ... 11 functions
├── tests/
│   └── test_calc_xrayneutron.m     # X-ray/neutron module tests
```

#### Phase 5: Extensions

```
├── +calc/
│   ├── +superconductor/            # London depth, coherence length, critical fields
│   │   └── # ... 5 functions
│   ├── importCIF.m                 # CIF file parser → crystal structure struct
│   └── crystalCache.m              # Local crystal structure database (load/save/search/add)
├── data/                           # Gitignored — local user data
│   ├── cif/                        # Folder for user-exported CIF files from ICSD etc.
│   └── crystal_cache.mat           # Parsed crystal structure cache (auto-generated)
├── tests/
│   ├── test_cif_parser.m           # CIF parser tests (synthetic CIF files)
│   └── test_superconductor.m       # Superconductor module tests
```

#### Deferred / Optional (not scheduled)

```
├── +calc/
│   ├── +optics/                    # Thin film optics: Fresnel, refractive index, penetration depth
│   ├── +vacuum/                    # Vacuum/gas: mean free path, pump-down, sputter yield
│   └── +electrochemistry/          # Nernst, Butler-Volmer, Tafel
├── tests/
│   ├── test_calc_optics.m
│   ├── test_calc_vacuum.m
│   └── test_calc_electrochemistry.m
```

**Why a new `+calc/` package instead of extending `+utilities/`?**
- `+utilities/` contains data-processing helpers (normalize, smooth, etc.)
  that operate on parsed data arrays. The calculator modules are a different
  concern: they take scalar physical parameters and return derived quantities.
- Keeping them separate makes the calculator usable from scripts without
  pulling in GUI or parser dependencies.
- `+utilities/convertUnits.m` remains untouched — existing code that calls
  it is unaffected. The new `calc.unitConvert` is a superset.

### GUI Layout Design

Window size: 720 x 560 px default (fits comfortably on 13-inch laptops at 1366x768 or 1440x900 resolution after the OS taskbar). The figure is resizable (`'Resize', 'on'`) and will scale up on larger monitors — the grid layouts handle resizing naturally.

6 core tabs, fitting on a single row:

```
+===================================================================+
|  Materials Calculator — Thin Film Toolkit                          |
+===================================================================+
|  [Unit Converter] [Crystal] [Electrical] [Semiconductor]          |
|  [Thin Film] [Periodic Table]                                      |
+-------------------------------------------------------------------+
|                                                                   |
|  ┌─────────────────────────────────────────────────────────────┐  |
|  │                                                             │  |
|  │              Tab-specific content area                      │  |
|  │              (varies per selected tab)                      │  |
|  │                                                             │  |
|  └─────────────────────────────────────────────────────────────┘  |
|                                                                   |
+-------------------------------------------------------------------+
| Status: Ready  |  History: [▼ log]                                |
+===================================================================+
```

**Implementation:** Use `uitabgroup` with `uitab` children — this is the
simplest MATLAB built-in for multi-page layouts and requires zero custom
tab-switching logic. Each tab contains its own `uigridlayout`.

#### Unit Converter Tab Layout

```
+-------------------------------------------------------------------+
|  Input: [___________] [unit field: "mA/cm^2"___]                  |
|                                                                   |
|  Output: [computed___] [unit field: "A/m^2"_____]                 |
|                                                                   |
|  [Swap]  [Copy Result]                                            |
|                                                                   |
|  ── Quick Presets ──────────────────────────────────               |
|  [Oe->A/m] [emu->A*m^2] [eV->nm] [Ang->nm] [Pa->Torr]          |
|                                                                   |
|  ── Conversion Details ─────────────────────────────               |
|  "1 mA/cm^2 = 10 A/m^2"                                          |
|  "milli-Ampere per centimeter^2 -> Ampere per meter^2"            |
+-------------------------------------------------------------------+
```

The input unit field is a free-text `uieditfield` — the user types arbitrary
unit expressions. The output unit field is also free-text. As the user types
(or on pressing Enter), the conversion updates live.

#### Calculator Tab Layout (generic, each module follows this)

```
+-------------------------------------------------------------------+
|  ── d-spacing from (hkl) ──────────────────────────                |
|                                                                   |
|  Crystal system: [Cubic______v]                                    |
|  a (Ang): [____]  b (Ang): [____]  c (Ang): [____]               |
|  h: [__]  k: [__]  l: [__]                                       |
|                                                                   |
|  [Calculate]                                                       |
|                                                                   |
|  d = 2.3456 Ang                                                   |
|  ────────────────────────────────────                              |
|  ── 2theta from d-spacing ──────────────────────────               |
|  d (Ang): [____]   lambda (Ang): [1.5406__]                       |
|  ...                                                              |
+-------------------------------------------------------------------+
```

Each tab is a vertical scrollable area (using `uigridlayout` inside a
`uipanel` with scroll) containing multiple "calculation cards" stacked
vertically. Each card is one formula with labeled inputs, a Calculate
button, and a result display.

---

## Unit Parser Design

### Architecture: `calc.unitConvert`

The unit parser must handle expressions like:

| Input | Parsed as |
|-------|-----------|
| `mA/cm^2` | milli-Ampere / (centi-meter)^2 |
| `uOhm*cm` | micro-Ohm * centi-meter |
| `ions/cm^2` | (dimensionless) / (centi-meter)^2 |
| `kA/m` | kilo-Ampere / meter |
| `eV` | electron-volt |
| `nm` | nano-meter |
| `Ang` or `Å` | Angstrom |

> **Note:** `A` is always Ampere. Use `Ang` or `Å` for Angstrom. This eliminates all ambiguity.

### Parsing Strategy

The parser works in three stages:

**Stage 1: Tokenize.** Split the unit string on `/` and `*` operators,
tracking whether each token is in the numerator or denominator. Handle
`^N` exponents.

```
"mA/cm^2" -> tokens: [{str:'mA', exp:1, pos:'num'}, {str:'cm', exp:2, pos:'den'}]
```

**Stage 2: Decompose each token** into (prefix, base_unit) using a
prefix table and a base-unit registry.

```
'mA' -> prefix='m' (1e-3), base='A' (Ampere)
'cm' -> prefix='c' (1e-2), base='m' (meter)
```

This requires careful disambiguation: `mm` = milli-meter (not mega-milli),
`mA` = milli-Ampere, `Pa` = Pascal (not peta-Ampere). The strategy:

1. Try matching the full token against known base units first (`Pa`, `Torr`,
   `eV`, `Oe`, `emu`, `Ang`, etc.).
2. If no match, try splitting off known SI prefixes (longest prefix first)
   and check if the remainder is a known base unit.
3. Special-case: `um` and `u` as micro (in addition to the proper `mu`).

**Stage 3: Compute dimension vector and scale factor.** Each base unit maps
to a dimension vector (M, L, T, I, Theta, N, J) and a scale-to-SI factor.
The full expression accumulates these:

```
mA/cm^2:
  mA  = 1e-3 * A  -> scale=1e-3, dims=[0,0,0,1,0,0,0]  (current)
  cm^2 = (1e-2)^2 * m^2 -> scale=1e-4, dims=[0,2,0,0,0,0,0]  (area, denom)

Combined: scale = 1e-3 / 1e-4 = 10,  dims = [0,-2,0,1,0,0,0]  (A/m^2)
```

To convert between two unit expressions: both must have the same dimension
vector. The conversion factor is `fromScale / toScale`.

### Data Structures

```matlab
% Base unit registry entry
%   key: string identifier (e.g., 'A', 'm', 'kg', 'eV')
%   dims: [M L T I Theta N J] dimension vector
%   toSI: scale factor to convert 1 of this unit to SI base
%   aliases: cell array of alternative spellings
%   display: canonical display string

% SI prefix table
%   prefix -> factor
%   'Y' -> 1e24, 'Z' -> 1e21, ..., 'k' -> 1e3, '' -> 1,
%   'm' -> 1e-3, 'u' -> 1e-6 (also 'mu', 'micro'),
%   'n' -> 1e-9, 'p' -> 1e-12, ...

% Parsed unit expression (returned by parseUnits)
%   .tokens   — struct array: {base, prefix, exponent, position}
%   .dims     — [1x7] net dimension vector
%   .scale    — net SI scale factor
%   .display  — formatted display string (e.g., "mA/cm^2")
```

### Public Interface: `calc.unitConvert`

```matlab
function [result, info] = unitConvert(value, fromStr, toStr)
%UNITCONVERT  Convert a value between arbitrary unit expressions.
%
%   [result, info] = calc.unitConvert(1, 'mA/cm^2', 'A/m^2')
%   [result, info] = calc.unitConvert(300, 'K', 'C')
%   [result, info] = calc.unitConvert(1.5406, 'Ang', 'nm')
%
%   info is a struct with fields:
%     .factor     — multiplication factor (result = value * factor)
%     .fromParsed — parsed unit struct for fromStr
%     .toParsed   — parsed unit struct for toStr
%     .description — human-readable conversion string
```

### Special-case conversions (non-dimensional)

Some "conversions" are not simple scaling — they involve different physical
dimensions connected by a formula:

| Conversion | Formula | Dimension change |
|-----------|---------|-----------------|
| eV <-> nm (wavelength) | E = hc/lambda | energy <-> length |
| eV <-> cm^-1 | E = hc * wavenumber | energy <-> 1/length |
| eV <-> THz | E = h * f | energy <-> frequency |
| K <-> C <-> F | offset formulas | temperature (same dim, nonlinear) |
| Oe <-> T | B = mu0 * H | H-field <-> B-field |

These are handled as named "equivalence bridges" — when a straight
dimensional conversion fails, the engine checks if a known bridge connects
the two dimension vectors and applies the formula.

```matlab
% Bridge registry (inside unitConvert)
bridges = {
    % {fromDims, toDims, forwardFcn, reverseFcn, description}
    {dimOf('eV'), dimOf('m'), @(E) h*c./E, @(L) h*c./L, 'energy-wavelength'}
    {dimOf('eV'), dimOf('Hz'), @(E) E/h, @(f) f*h, 'energy-frequency'}
    {dimOf('eV'), dimOf('1/m'), @(E) E/(h*c), @(k) k*h*c, 'energy-wavenumber'}
    % Temperature handled separately (offset, not scale)
};
```

---

## Calculation Module Design

### Pattern: Each module is a single file with multiple public functions

Each function in `+calc/` takes scalar or small-vector inputs and returns
a result struct. No GUI dependencies — pure computation.

```matlab
% Example: calc.crystal
function result = dSpacing(a, b, c, alpha, beta, gamma, h, k, l)
    arguments
        a      (1,1) double
        b      (1,1) double
        c      (1,1) double
        alpha  (1,1) double = 90   % degrees
        beta   (1,1) double = 90
        gamma  (1,1) double = 90
        h      (1,1) double
        k      (1,1) double
        l      (1,1) double
    end
    % ... compute d-spacing for general triclinic case ...
    result.d = d;           % Angstroms
    result.formula = '1/d^2 = ...';  % human-readable formula used
    result.system = detectedSystem;  % 'cubic', 'tetragonal', etc.
    result.latex = '$d_{111} = 2.35\,\text{\AA}$';  % LaTeX for copy
end
```

Result structs include a `.latex` field for copy-to-clipboard functionality.
Each `+calc/` function generates its own LaTeX string since it knows its
own variable names and formatting conventions.

### Module: `calc.crystal`

| Function | Inputs | Output |
|----------|--------|--------|
| `dSpacing(a,b,c,alpha,beta,gamma,h,k,l)` | Lattice params + Miller indices | `d` in Ang |
| `twoThetaFromD(d, lambda)` | d-spacing, wavelength (Ang) | `twoTheta` in degrees |
| `dFromTwoTheta(twoTheta, lambda)` | 2theta (deg), wavelength (Ang) | `d` in Ang |
| `atomicDensity(a, b, c, alpha, beta, gamma, Z)` | Lattice params + atoms/cell | atoms/cm^3 |
| `unitCellVolume(a, b, c, alpha, beta, gamma)` | Lattice params (Ang) | Volume in Ang^3 |
| `densityFromMolar(molarMass, a, b, c, alpha, beta, gamma, Z)` | g/mol, lattice, Z | g/cm^3 |
| `latticeMismatch(aFilm, aSub)` | Film and substrate lattice parameters (Ang) | Mismatch `(aFilm - aSub)/aSub` (dimensionless) |
| `criticalThickness(aFilm, aSub, nu)` | Film/substrate lattice params, Poisson ratio | Matthews-Blakeslee critical thickness (Ang) |
| `strainFromPoisson(epsInPlane, nu)` | In-plane strain, Poisson ratio | Out-of-plane strain `eps_perp = -2*nu/(1-nu) * eps_par` |
| `tetragonalDistortion(aRelaxed, cMeasured, cRelaxed)` | Relaxed a, measured c, relaxed c (Ang) | c/a ratio, tetragonal distortion (%) |

**Epitaxy / strain functions detail:**

- `latticeMismatch` returns a struct with `.mismatch` (fractional),
  `.mismatchPct` (percent), and `.description` (tensile/compressive).
- `criticalThickness` implements the Matthews-Blakeslee model:
  `h_c = (b / (2*pi*f)) * (1 - nu*cos^2(alpha)) / ((1+nu)*cos(lambda)) * (ln(h_c/b) + 1)`
  Solved iteratively (self-consistent equation). `b` is the Burgers vector
  magnitude (defaults to `a/sqrt(2)` for FCC {110}<-110>). The function
  warns when the result depends heavily on assumed slip system.
- `strainFromPoisson` converts in-plane biaxial strain to out-of-plane strain
  using elasticity of a (001)-oriented cubic film. Returns struct with
  `.epsPerp`, `.epsParallel`, `.formula`.
- `tetragonalDistortion` computes `c/a` ratio and reports whether the film
  is tetragonally distorted relative to its bulk cubic structure.

For convenience, cubic/tetragonal/hexagonal cases: when `b`, `c`, `alpha`,
`beta`, `gamma` are omitted (default), the function infers the system:
- Only `a` given -> cubic (b=c=a, all angles 90).
- `a` and `c` given -> tetragonal (b=a, angles 90).
- Full set -> triclinic (general case).

### Module: `calc.electrical`

| Function | Inputs | Output |
|----------|--------|--------|
| `resistivity(Rs, t)` | Sheet resistance (Ohm/sq), thickness | rho (Ohm*cm) |
| `conductivity(rho)` | Resistivity | sigma (S/cm) |
| `mobility(rho, n)` | Resistivity, carrier concentration (cm^-3) | mu (cm^2/V*s) |
| `currentDensity(I, area)` | Current (A), area (cm^2) | J (A/cm^2) |
| `sheetResistance(rho, t)` | Resistivity, thickness | Rs (Ohm/sq) |

### Module: `calc.thinFilm`

| Function | Inputs | Output |
|----------|--------|--------|
| `depositionRate(thickness, time, fromUnit, toUnit)` | thickness, time | rate in toUnit |
| `kiessigThickness(deltaQ)` | Q-spacing between fringes (Ang^-1) | thickness (Ang) |
| `stoneyStress(Es, nus, ts, tf, R)` | Substrate E, nu, thickness; film t; radius of curvature | stress (Pa) |
| `doseFromCurrent(current, time, area)` | beam current, time, area | dose (ions/cm^2) |
| `thermalMismatchStrain(alphaFilm, alphaSub, deltaT)` | Thermal expansion coefficients (1/K), temperature change (K) | Thermal mismatch strain (dimensionless) |
| `multilayerThermalConductivity(layers)` | Struct array: `.thickness` (nm), `.kappa` (W/m/K) per layer | Effective kappa (W/m/K) for series and parallel models |
| `diffusionLength_thermal(D, t)` | Diffusion coefficient (cm^2/s), anneal time (s) | Diffusion length `sqrt(D*t)` in cm and nm |

**Thermal calculations detail:**

- `thermalMismatchStrain` returns `(alphaFilm - alphaSub) * deltaT`. Simple
  but frequently looked up. Returns struct with `.strain`, `.stressMPa`
  (if optional Young's modulus provided), `.description`.
- `multilayerThermalConductivity` computes effective thermal conductivity for
  a stack of layers: series model (`sum(d_i/k_i) / sum(d_i)`)^-1 and
  parallel model `sum(k_i*d_i) / sum(d_i)`. Returns both.
- `diffusionLength_thermal` is a convenience function for estimating how far
  atoms diffuse during a thermal anneal. Returns `L = sqrt(D*t)`.

**Ion beam / implantation functions** (`projectedRange`, `doseToConcentration`,
`sputterRate`) are deferred — see the Deferred / Optional section.

### Module: `calc.magnetic`

| Function | Inputs | Output |
|----------|--------|--------|
| `momentPerAtom(totalMoment, volume, atomicDensity)` | emu, cm^3, atoms/cm^3 | mu_B/atom |
| `magnetization(moment, volume)` | emu, cm^3 | M in emu/cm^3 and kA/m |
| `bohrMagnetonConvert(moment, unit)` | numeric + unit string | moment in mu_B |
| `demagFactor(shape, dims)` | 'sphere'/'cylinder'/... + dimensions | N (dimensionless) |

### Module: `calc.xrayNeutron`

> **Note:** Integrated into `dataImportGUI` as sub-dialogs (SLD calculator,
> Q-to-2theta converter) rather than `materialsCalcGUI` tabs. See Phase 4.

| Function | Inputs | Output |
|----------|--------|--------|
| `braggLaw(d, theta, lambda, solve)` | Any 2 of 3 + which to solve | The third |
| `qToTwoTheta(Q, lambda)` | Q (Ang^-1), wavelength (Ang) | 2theta (deg) |
| `twoThetaToQ(twoTheta, lambda)` | 2theta (deg), wavelength (Ang) | Q (Ang^-1) |
| `neutronSLD(composition, density)` | Chemical formula string, g/cm^3 | SLD (Ang^-2) |
| `xraySLD(composition, density, energy)` | Formula, density, X-ray energy | SLD (Ang^-2) |
| `molecularWeight(formula)` | Chemical formula string (e.g., 'Fe3O4') | Molecular weight (g/mol) |
| `weightToAtomicPercent(elements, weightPcts)` | Cell array of element symbols, weight percent array | Atomic percent array |
| `atomicToWeightPercent(elements, atomicPcts)` | Cell array of element symbols, atomic percent array | Weight percent array |
| `balanceReaction(reactants, products)` | Cell arrays of formula strings | Balanced integer coefficients |
| `coDepositionRatio(rates, densities, molarMasses)` | Deposition rates (nm/s), densities (g/cm^3), molar masses (g/mol) per source | Atomic fraction of each source in co-deposited film |
| `parseFormula(formula)` | Chemical formula string | Element-count struct |

**Stoichiometry functions detail:**

- `molecularWeight` uses `parseFormula` plus `calc.elementData`
  atomic masses. Returns scalar molecular weight in g/mol.
- `weightToAtomicPercent` / `atomicToWeightPercent` convert between the two
  common composition representations. Input percentages need not sum to 100
  (normalized internally).
- `balanceReaction` solves for integer stoichiometric coefficients using a
  null-space approach on the element composition matrix. Works for simple
  reactions (up to ~6 species). Returns coefficient arrays for reactants
  and products.
- `coDepositionRatio` calculates the atomic fraction contribution of each
  source in a co-deposited film given individual source deposition rates,
  bulk densities, and molar masses: `n_i = rate_i * rho_i / M_i`,
  `fraction_i = n_i / sum(n_i)`.

**SLD calculator detail:** `neutronSLD` reads coherent scattering lengths from
`calc.elementData` (the single source of truth for all per-element data —
see the `elementData` section). `xraySLD` similarly reads atomic form factors
from `calc.elementData`. Neither function maintains its own scattering-length
table. Data covers the ~40 most common thin-film elements; remainder set to NaN.

**Chemical formula parsing:** `"Fe3O4"` -> `{Fe:3, O:4}`. Handle parentheses
in a second pass if needed: `"(Fe0.5Co0.5)3O4"`.

### Module: `calc.semiconductor`

| Function | Inputs | Output |
|----------|--------|--------|
| `intrinsicCarrierConc(Eg, T, meStar, mhStar)` | Band gap (eV), temperature (K), effective masses (m0) | n_i (cm^-3) |
| `carrierConcentration(Nd, Na, ni)` | Donor conc, acceptor conc, intrinsic conc (all cm^-3) | n, p (cm^-3), type ('n'/'p') |
| `fermiLevel(Eg, T, Nd, Na, meStar, mhStar)` | Band gap, temp, doping, effective masses | E_F relative to E_i (eV) |
| `debyeLength(epsilon_r, T, n)` | Relative permittivity, temperature (K), carrier conc (cm^-3) | L_D (nm) |
| `depletionWidth(epsilon_r, Vbi, Na, Nd)` | Permittivity, built-in voltage (V), doping (cm^-3) | W (nm), xn, xp |
| `builtInPotential(Na, Nd, ni, T)` | Acceptor, donor, intrinsic conc (cm^-3), temp (K) | V_bi (V) |
| `mobilityModel(material, T, N)` | Material name, temperature, total doping | mu_e, mu_h (cm^2/V*s) |
| `diffusionCoeff(mu, T)` | Mobility (cm^2/V*s), temperature (K) | D (cm^2/s) via Einstein relation |
| `diffusionLength(D, tau)` | Diffusion coeff (cm^2/s), lifetime (s) | L (um) |
| `sheetCarrierDensity(n, t)` | Volume carrier conc (cm^-3), layer thickness (cm) | n_s (cm^-2) |
| `hallCoefficient(n, p, mu_e, mu_h)` | Carrier concs + mobilities | R_H (cm^3/C), apparent carrier type |
| `thermalVelocity(mStar, T)` | Effective mass (m0), temperature (K) | v_th (cm/s) |
| `dosEffectiveMass(material, carrier)` | Material name, 'e'/'h' | m* in units of m0 |

**Key formulas:**

- **Intrinsic carrier concentration:**
  `n_i = sqrt(Nc * Nv) * exp(-Eg / (2*kB*T))`
  where `Nc = 2*(2*pi*me**kB*T/h^2)^(3/2)` (effective density of states).

- **Fermi level from midgap:**
  `E_F - E_i = kB*T * ln(Nd/ni)` (n-type, non-degenerate)
  `E_F - E_i = -kB*T * ln(Na/ni)` (p-type, non-degenerate)

- **Debye length:**
  `L_D = sqrt(epsilon_0 * epsilon_r * kB * T / (q^2 * n))`

- **Depletion width (abrupt junction):**
  `W = sqrt(2*eps*(1/Na + 1/Nd)*Vbi / q)`

- **Einstein relation:**
  `D = mu * kB * T / q`

**Material presets:** A built-in lookup table for common semiconductors
provides default values for band gap, effective masses, permittivity, and
mobility model parameters:

```matlab
% Material preset struct (inside calc.semiconductor)
materials.Si   = struct('Eg', 1.12, 'eps_r', 11.7, 'me', 1.08, 'mh', 0.81, 'name', 'Silicon');
materials.Ge   = struct('Eg', 0.66, 'eps_r', 16.0, 'me', 0.55, 'mh', 0.37, 'name', 'Germanium');
materials.GaAs = struct('Eg', 1.42, 'eps_r', 12.9, 'me', 0.067,'mh', 0.45, 'name', 'Gallium Arsenide');
materials.InP  = struct('Eg', 1.35, 'eps_r', 12.5, 'me', 0.08, 'mh', 0.6,  'name', 'Indium Phosphide');
materials.GaN  = struct('Eg', 3.4,  'eps_r', 8.9,  'me', 0.2,  'mh', 1.4,  'name', 'Gallium Nitride');
materials.SiC  = struct('Eg', 3.26, 'eps_r', 9.7,  'me', 0.37, 'mh', 1.0,  'name', '4H-SiC');
materials.SiO2  = struct('Eg', 9.0,  'eps_r', 3.9,  'me', 0.5,  'mh', NaN,  'name', 'Silicon Dioxide');
materials.Al2O3 = struct('Eg', 8.8,  'eps_r', 9.0,  'me', 0.4,  'mh', NaN,  'name', 'Sapphire (alpha-Al2O3)');
```

Functions accept either explicit numeric parameters or a `Material` name-value
argument that auto-fills defaults:
```matlab
% Explicit
ni = calc.semiconductor.intrinsicCarrierConc(1.12, 300, 1.08, 0.81);
% Preset
ni = calc.semiconductor.intrinsicCarrierConc(Material='Si', T=300);
```

**Mobility model:** `mobilityModel` uses the Caughey-Thomas empirical formula
for doping-dependent mobility:
```
mu = mu_min + (mu_max - mu_min) / (1 + (N/N_ref)^alpha)
```
with coefficients stored per material. Returns both electron and hole
mobilities. Temperature dependence via power-law scaling `(T/300)^beta`.

**GUI tab layout for Semiconductor:**

The Semiconductor tab groups calculations into cards:
1. **Intrinsic Properties** — material dropdown (auto-fills Eg, m*, eps_r) + temperature -> n_i, Nc, Nv
2. **Doping & Fermi Level** — Nd, Na inputs -> n, p, E_F, carrier type
3. **Transport** — resistivity/mobility/diffusion coefficient/diffusion length
4. **Junction** — built-in potential, depletion width, Debye length
5. **Hall Effect** — carrier concs + mobilities -> Hall coefficient, apparent type

### Module: `calc.superconductor`

> **Note:** Added in Phase 5.

Superconductor property calculations and material presets.

| Function | Inputs | Output |
|----------|--------|--------|
| `londonDepth(ns, mStar)` | Superfluid density (m^-3), effective mass (kg) | London penetration depth lambda_L (nm) |
| `coherenceLength(vf, Tc)` | Fermi velocity (m/s), critical temperature (K) | BCS coherence length xi_0 (nm) |
| `glParameter(lambda, xi)` | Penetration depth (nm), coherence length (nm) | Ginzburg-Landau kappa; Type I/II classification |
| `criticalFields(Tc, xi, lambda)` | Critical temperature (K), coherence length (nm), penetration depth (nm) | Hc, Hc1, Hc2 (T) at T=0 |
| `depairingCurrent(Hc, lambda)` | Thermodynamic critical field (T), penetration depth (nm) | Depairing current density J_d (A/cm^2) |

**Key formulas:**

- **London penetration depth:**
  `lambda_L = sqrt(m* / (mu0 * ns * e^2))`
  where `ns` is the superfluid electron density and `m*` the effective mass.

- **BCS coherence length:**
  `xi_0 = hbar * vf / (pi * Delta_0)` with `Delta_0 = 1.764 * kB * Tc`.

- **Ginzburg-Landau parameter:**
  `kappa = lambda / xi`. Type I if kappa < 1/sqrt(2), Type II otherwise.

- **Critical fields (at T=0):**
  - Thermodynamic: `Hc = Phi_0 / (2*sqrt(2)*pi*lambda*xi)`
  - Lower: `Hc1 = (Phi_0 / (4*pi*lambda^2)) * ln(kappa)`
  - Upper: `Hc2 = Phi_0 / (2*pi*xi^2)`
  where `Phi_0 = h/(2e)` is the flux quantum.

- **Depairing current:**
  `J_d = Hc / (3*sqrt(6)*lambda)` (Ginzburg-Landau result).

**Superconductor material presets:**

```matlab
% Preset table (values at T=0 unless noted)
sc.Nb    = struct('Tc', 9.3,  'lambda', 39,  'xi', 38,  'type', 'II', 'name', 'Niobium');
sc.NbN   = struct('Tc', 16.0, 'lambda', 200, 'xi', 5,   'type', 'II', 'name', 'Niobium Nitride');
sc.NbTi  = struct('Tc', 10.0, 'lambda', 300, 'xi', 4,   'type', 'II', 'name', 'Nb-Ti alloy');
sc.YBCO  = struct('Tc', 92,   'lambda', 150, 'xi', 1.5, 'type', 'II', 'name', 'YBa2Cu3O7');
sc.MgB2  = struct('Tc', 39,   'lambda', 140, 'xi', 5,   'type', 'II', 'name', 'Magnesium Diboride');
sc.Al    = struct('Tc', 1.18, 'lambda', 16,  'xi', 1600,'type', 'I',  'name', 'Aluminum');
sc.Pb    = struct('Tc', 7.2,  'lambda', 37,  'xi', 83,  'type', 'I',  'name', 'Lead');
sc.In    = struct('Tc', 3.41, 'lambda', 24,  'xi', 440, 'type', 'I',  'name', 'Indium');
sc.Sn    = struct('Tc', 3.72, 'lambda', 34,  'xi', 230, 'type', 'I',  'name', 'Tin');
```

Functions accept either explicit numeric parameters or a `Material` name-value
argument that auto-fills defaults:
```matlab
% Explicit
result = calc.superconductor.criticalFields(Tc=9.3, xi=38, lambda=39);
% Preset
result = calc.superconductor.criticalFields(Material='Nb');
```

**GUI tab layout for Superconductor (added in Phase 5):**

The Superconductor tab groups calculations into cards:
1. **Material Selector** — dropdown of presets, auto-fills Tc, lambda, xi
2. **London Depth / Coherence Length** — input params -> lambda_L, xi_0
3. **GL Parameter & Classification** — lambda, xi -> kappa, Type I/II
4. **Critical Fields** — Tc, xi, lambda -> Hc, Hc1, Hc2
5. **Depairing Current** — Hc, lambda -> J_d

> **Preset data note:** Published values for lambda and xi vary significantly
> between sources (thin film vs. bulk, dirty vs. clean limit). The preset
> table should cite specific references and note whether values are for bulk
> single-crystal or typical thin-film samples.

### Module: `calc.substrates`

Preset library of common single-crystal substrates used in thin film growth.
This module provides a lookup table — no heavy computation.

```matlab
function sub = getSubstrate(name)
%GETSUBSTRATE  Return preset substrate data by name.
%
%   sub = calc.substrates.getSubstrate('Si(100)')
%   sub = calc.substrates.getSubstrate('SrTiO3(100)')
%
%   sub fields:
%     .name        — display name (e.g., 'Si(100)')
%     .formula     — chemical formula (e.g., 'Si')
%     .orientation — Miller indices string (e.g., '(100)')
%     .a, .b, .c   — lattice parameters (Ang)
%     .alpha, .beta, .gamma — lattice angles (deg)
%     .thermalExpansion — linear CTE (1e-6 / K)
%     .dielectric  — static relative permittivity (dielectric constant)
%     .density     — bulk density (g/cm^3)
%     .latticeType — 'cubic', 'hexagonal', 'rhombohedral', etc.

function list = listSubstrates()
%LISTSUBSTRATES  Return cell array of all available substrate names.
%   list = calc.substrates.listSubstrates()
```

**Preset substrate table:**

| Name | Formula | Orient. | a (Ang) | c (Ang) | CTE (1e-6/K) | eps_r | Density (g/cm^3) | Type |
|------|---------|---------|---------|---------|---------------|-------|-------------------|------|
| Si(100) | Si | (100) | 5.431 | — | 2.6 | 11.7 | 2.329 | cubic |
| Si(111) | Si | (111) | 5.431 | — | 2.6 | 11.7 | 2.329 | cubic |
| SiO2/Si | SiO2 | amorphous | — | — | 0.5 | 3.9 | 2.20 | amorphous |
| Al2O3(0001) | Al2O3 | (0001) | 4.758 | 12.991 | 5.0 | 9.0 | 3.987 | hexagonal |
| Al2O3(1-102) | Al2O3 | (1-102) | 4.758 | 12.991 | 5.0 | 9.0 | 3.987 | hexagonal |
| MgO(100) | MgO | (100) | 4.212 | — | 10.5 | 9.8 | 3.585 | cubic |
| SrTiO3(100) | SrTiO3 | (100) | 3.905 | — | 11.0 | 300 | 5.117 | cubic |
| GaAs(100) | GaAs | (100) | 5.653 | — | 5.73 | 12.9 | 5.317 | cubic |
| LaAlO3(100) | LaAlO3 | (100) | 3.789 | — | 10.0 | 24 | 6.52 | cubic (pseudo) |
| LSAT(100) | (LaAlO3)0.3(Sr2AlTaO6)0.7 | (100) | 3.868 | — | 10.0 | 22 | 6.74 | cubic |
| Ge(100) | Ge | (100) | 5.658 | — | 5.9 | 16.0 | 5.323 | cubic |
| InP(100) | InP | (100) | 5.869 | — | 4.6 | 12.5 | 4.81 | cubic |
| YSZ(100) | (ZrO2)0.92(Y2O3)0.08 | (100) | 5.125 | — | 10.5 | 27 | 5.96 | cubic |
| MgAl2O4(100) | MgAl2O4 | (100) | 8.083 | — | 7.45 | 8.1 | 3.578 | cubic |

**GUI integration:**

The substrate table is accessible from:
- **Crystal tab** — "Select substrate" dropdown auto-fills lattice parameters
  for epitaxy/strain calculations. Selecting a substrate + entering film
  lattice parameter triggers automatic lattice mismatch computation.
- **Thin Film tab** — substrate CTE for thermal mismatch strain calculations.

### Module: `calc.elementData`

Central periodic table database. Returns a struct array (118 elements) with
per-element properties. Loaded once via `persistent` variable on first call.

```matlab
function elements = elementData()
%ELEMENTDATA  Return periodic table data for all elements.
%   elements = calc.elementData()
%   elements(26)           % Iron
%   elements(26).symbol    % 'Fe'
```

**Fields per element:**

| Field | Type | Description |
|-------|------|-------------|
| `Z` | int | Atomic number |
| `symbol` | char | Element symbol ('H', 'He', ...) |
| `name` | char | Full name ('Hydrogen', ...) |
| `mass` | double | Atomic mass (u / g/mol) |
| `group` | int | Group number (1-18, 0 for lanthanides/actinides) |
| `period` | int | Period (1-7) |
| `category` | char | 'alkali metal', 'transition metal', 'noble gas', etc. |
| `density` | double | Bulk density (g/cm^3), NaN if unavailable |
| `electronConfig` | char | Abbreviated e.g. '[Ar] 3d6 4s2' |
| `electronegativity` | double | Pauling scale, NaN if unavailable |
| `atomicRadius` | double | Empirical atomic radius (pm) |
| `ionizationEnergy` | double | First ionization energy (eV) |
| `electronAffinity` | double | Electron affinity (eV), NaN if unavailable |
| `meltingPoint` | double | Melting point (K), NaN if unavailable |
| `boilingPoint` | double | Boiling point (K), NaN if unavailable |
| `thermalConductivity` | double | W/(m*K), NaN if unavailable |
| `bCoherent` | double | Neutron coherent scattering length (fm), NaN if unavailable |
| `xrayEdges` | struct | K, L1, L2, L3 absorption edge energies (eV), empty if unavailable |

**Data source:** Hard-coded struct array. Covers all 118 elements for basic
fields (Z, symbol, name, mass, group, period, category). Physical properties
populated for ~80 most common elements; remainder set to NaN. Neutron
scattering lengths populated for the ~40 elements most common in thin-film
work. `calc.elementData` is the single source of truth for scattering lengths —
`calc.xrayNeutron.neutronSLD` reads `.bCoherent` from here rather than
maintaining a separate table.

**Accessor helpers:**

```matlab
function el = bySymbol(sym)
%BYSYMBOL  Look up element by symbol string.
%   fe = calc.elementData.bySymbol('Fe')

function el = byZ(Z)
%BYZ  Look up element by atomic number.
%   fe = calc.elementData.byZ(26)

function props = getProperty(elements, propName)
%GETPROPERTY  Extract a property vector for all elements.
%   masses = calc.elementData.getProperty(elements, 'mass')
%   % Returns [1x118] double with NaN for missing values
```

### Module: `calc.importCIF`

> **Note:** Added in Phase 5.

Parses standard CIF (Crystallographic Information File) format into a
MATLAB struct. CIF is the standard export format from ICSD, COD, and
most crystallography databases.

```matlab
function crystal = importCIF(filepath)
%IMPORTCIF  Parse a CIF file into a crystal structure struct.
%
%   crystal = calc.importCIF('Fe3O4_icsd.cif')
%
%   crystal fields:
%     .name         — chemical name (from _chemical_name_common or _systematic)
%     .formula      — chemical formula (from _chemical_formula_sum)
%     .spaceGroup   — Hermann-Mauguin symbol (from _symmetry_space_group_name_H-M)
%     .spaceGroupNo — International Tables number (from _symmetry_Int_Tables_number)
%     .a, .b, .c    — lattice parameters (Ang) (from _cell_length_a/b/c)
%     .alpha, .beta, .gamma — lattice angles (deg) (from _cell_angle_alpha/beta/gamma)
%     .volume       — unit cell volume (Ang^3) (from _cell_volume, or computed)
%     .Z            — formula units per cell (from _cell_formula_units_Z)
%     .density      — calculated density (g/cm^3)
%     .atoms        — struct array of atoms in asymmetric unit:
%         .symbol   — element symbol
%         .label    — site label (e.g. 'Fe1', 'O2')
%         .x, .y, .z — fractional coordinates
%         .occupancy — site occupancy (default 1.0)
%         .Biso     — isotropic displacement (Ang^2), NaN if absent
%     .source       — source file path
%     .icsdId       — ICSD collection code (from _database_code_ICSD), '' if absent
%     .rawTags      — containers.Map of all CIF tag-value pairs (for advanced use)
```

**CIF parsing strategy:**

CIF files are plain-text with `_tag value` pairs and `loop_` blocks.
The parser needs to handle:

1. **Simple tag-value pairs:** `_cell_length_a 5.4309(1)` — extract numeric
   value, strip uncertainty in parentheses.
2. **Loop blocks:** `loop_` followed by tag names, then rows of values.
   Atom site coordinates are always in a loop.
3. **Quoted strings:** Single-quote or semicolon-delimited multi-line text.
4. **Numeric uncertainties:** `5.4309(1)` -> `5.4309`. Strip `(N)` suffix.
5. **Multiple data blocks:** Some CIF files contain `data_blockname` sections.
   Parse the first block by default; accept optional `DataBlock` name-value
   argument to select a specific one.

```matlab
% Core parsing pseudocode
function tags = parseCIFtext(text)
    % Split into lines, skip comments (#)
    % State machine: NORMAL | IN_LOOP | IN_SEMICOLON_STRING
    % In NORMAL: match _tag value → store in tags map
    % In IN_LOOP: collect tag names after loop_, then read value rows
    %   until next _tag, loop_, or data_ line
    % Strip numeric uncertainties: regexp '(\d+\.?\d*)\(\d+\)' → '$1'
end
```

**Error handling:**
- Missing required tags (cell params, space group): return partial struct
  with warnings, set `.incomplete = true`.
- Malformed lines: skip with warning, continue parsing.
- Non-ASCII characters: CIF allows UTF-8 in newer versions; use
  `fopen(..., 'r', 'UTF-8')`.

### Module: `calc.crystalCache`

> **Note:** Added in Phase 5.

Manages a local database of parsed crystal structures stored in
`data/crystal_cache.mat`. Acts as a persistent lookup table so CIF files
only need to be parsed once.

```matlab
function result = crystalCache(action, varargin)
%CRYSTALCACHE  Manage local crystal structure database.
%
%   % Import a single CIF file into the cache
%   crystal = calc.crystalCache('add', 'path/to/Fe3O4.cif')
%
%   % Batch-import all CIF files in a folder
%   added = calc.crystalCache('import', 'data/cif/')
%
%   % Search the cache
%   matches = calc.crystalCache('search', 'Fe3O4')
%   matches = calc.crystalCache('search', 'formula', 'Fe3O4')
%   matches = calc.crystalCache('search', 'spaceGroup', 'Fd-3m')
%   matches = calc.crystalCache('search', 'elements', {'Fe', 'O'})
%
%   % Get all entries
%   all = calc.crystalCache('list')
%
%   % Get a specific entry by ICSD ID
%   crystal = calc.crystalCache('get', 'icsd', '26410')
%
%   % Remove an entry
%   calc.crystalCache('remove', 'icsd', '26410')
%
%   % Rebuild cache from all CIF files in data/cif/
%   calc.crystalCache('rebuild')
%
%   % Export cache summary to CSV (for quick reference)
%   calc.crystalCache('export', 'my_materials.csv')
```

**Storage format:**

```matlab
% crystal_cache.mat contains:
%   cache — struct with fields:
%     .entries    — [1xN] struct array, each entry = output of importCIF
%     .index      — containers.Map: ICSD ID string → index into entries
%     .formulaIdx — containers.Map: formula string → [array of indices]
%     .version    — cache format version (for future migrations)
%     .lastModified — datetime of last add/remove
```

**Cache location:** `<toolbox_root>/data/crystal_cache.mat`. The `data/`
folder is gitignored — each machine builds its own cache from CIF files.
CIF files can live in `data/cif/` or anywhere the user specifies.

**Search capabilities:**

| Search type | Example | How it works |
|-------------|---------|--------------|
| Free text | `'search', 'iron oxide'` | Matches against name, formula, and ICSD ID |
| Formula | `'search', 'formula', 'Fe3O4'` | Exact or substring match on formula |
| Space group | `'search', 'spaceGroup', 'Fd-3m'` | Exact match on H-M symbol |
| Elements | `'search', 'elements', {'Fe','O'}` | All entries containing these elements |
| Lattice range | `'search', 'a', [5.0, 6.0]` | Entries with `a` in range [5.0, 6.0] Ang |
| ICSD ID | `'get', 'icsd', '26410'` | Direct lookup by collection code |

**Workflow for populating the cache:**

```
1. User exports CIF files from ICSD (or downloads from COD) into data/cif/
2. In MATLAB:  calc.crystalCache('import', 'data/cif/')
   → Parses all .cif files, adds to crystal_cache.mat
   → Reports: "Added 47 structures, 3 skipped (parse errors)"
3. Cache persists across sessions. New CIF files can be added incrementally.
```

#### Periodic Table Tab Layout

```
+===================================================================+
|  Property: [Atomic Mass_______v]  Color by: [Category______v]     |
|  [Show values] [Show symbols]  Highlight: [_______________]       |
+-------------------------------------------------------------------+
|                                                                   |
|  ┌──┐┌──┐                                        ┌──┐            |
|  │H ││He│  ...                                    │He│            |
|  │1 ││4 │                                         │4 │            |
|  └──┘└──┘                                        └──┘            |
|  ┌──┐┌──┐┌──┐                        ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐  |
|  │Li││Be││  │  ...                    │B ││C ││N ││O ││F ││Ne│  |
|  │7 ││9 ││  │                         │11││12││14││16││19││20│  |
|  └──┘└──┘└──┘                        └──┘└──┘└──┘└──┘└──┘└──┘  |
|  ... (standard 18-column periodic table layout) ...              |
|                                                                   |
|  ┌──┐┌──┐┌──┐ ... ┌──┐   <- Lanthanides (row below main table)  |
|  └──┘└──┘└──┘ ... └──┘                                          |
|  ┌──┐┌──┐┌──┐ ... ┌──┐   <- Actinides                           |
|  └──┘└──┘└──┘ ... └──┘                                          |
+-------------------------------------------------------------------+
| Selected: Fe — Iron | Z=26 | 55.845 u | [Ar] 3d6 4s2            |
+===================================================================+
```

**Implementation details:**

1. **Grid of buttons:** Each element is a `uibutton` placed in an 10x18
   `uigridlayout` (7 main periods + gap + 2 f-block rows). Buttons are
   small (~38x36 px cells). Each button shows the symbol and, below it,
   the selected property value in smaller font.

2. **Property dropdown:** Controls which numeric property is displayed
   under each element symbol. Options:
   - Atomic Mass (u)
   - Atomic Number
   - Density (g/cm^3)
   - Electronegativity
   - Atomic Radius (pm)
   - 1st Ionization Energy (eV)
   - Electron Affinity (eV)
   - Melting Point (K)
   - Boiling Point (K)
   - Thermal Conductivity (W/m*K)
   - Neutron b_coh (fm)

   When the user changes the dropdown, all buttons update their secondary
   text. Elements with `NaN` for that property show "--".

3. **Color-by dropdown:** Controls the background color of each button.
   Options:
   - **Category** — each `category` string maps to a distinct color
     (alkali=soft red, transition=blue, noble gas=purple, etc.)
   - **Property gradient** — color-map the currently selected property
     from blue (low) to red (high), with NaN elements shown in gray.
   - **None** — uniform background.

4. **Highlight search:** A text field that highlights elements matching
   a typed string. Useful for quickly finding an element by name. As the
   user types, matching element buttons get a thick border or glow effect;
   non-matching ones dim slightly.

5. **Click to select:** Clicking any element button updates the detail
   bar at the bottom with all available properties for that element.

6. **Detail bar:** A single-row panel at the bottom showing the full
   property set for the selected element: symbol, name, Z, mass,
   config, and whichever properties are non-NaN.

**Color palette for element categories:**

```matlab
catColors = struct( ...
    'alkali_metal',         [0.85 0.45 0.45], ...  % soft red
    'alkaline_earth_metal', [0.90 0.65 0.40], ...  % orange
    'transition_metal',     [0.45 0.60 0.80], ...  % steel blue
    'post_transition_metal',[0.55 0.75 0.55], ...  % sage green
    'metalloid',            [0.70 0.70 0.50], ...  % olive
    'nonmetal',             [0.50 0.78 0.50], ...  % green
    'halogen',              [0.65 0.55 0.80], ...  % lavender
    'noble_gas',            [0.70 0.50 0.75], ...  % purple
    'lanthanide',           [0.75 0.65 0.75], ...  % mauve
    'actinide',             [0.80 0.60 0.65], ...  % dusty rose
    'unknown',              [0.75 0.75 0.75]);     % gray
```

---

## GUI Architecture: `materialsCalcGUI.m`

### Structure (follows emViewerGUI pattern)

```matlab
function varargout = materialsCalcGUI()
    % ── appData ──
    appData.lastTab = 'Unit Converter';
    appData.history = {};        % conversion/calculation history log
    appData.presets = struct();  % saved user presets (future)
    appData.commonWavelengths = struct( ...
        'CuKa1',  1.5406, ...
        'CuKa2',  1.5444, ...
        'MoKa1',  0.7093, ...
        'CoKa1',  1.7890, ...
        'CrKa1',  2.2897, ...
        'neutronCold', 4.75);

    % ── Button colors ──
    BTN_PRIMARY = [0.18 0.52 0.18];
    BTN_TOOL    = [0.28 0.28 0.28];
    BTN_CALC    = [0.18 0.32 0.52];  % blue — calculate actions
    BTN_FG      = [1 1 1];

    % ── Figure ──
    fig = uifigure('Name', 'Materials Calculator — Thin Film Toolkit', ...
                   'Position', [100 100 720 560], ...
                   'Resize', 'on');

    % ── Root grid: toolbar (30) + tabs (1x) + status (22) ──
    rootGL = uigridlayout(fig, [3 1], ...
        'RowHeight', {30, '1x', 22}, ...
        'Padding', [6 6 6 6]);

    % ── Toolbar: history, copy, clear ──
    % ── Tab group ──
    tabGroup = uitabgroup(rootGL);
    tabGroup.Layout.Row = 2;
    % ... build each tab ...

    % ── Status bar ──

    % ── API (for testing) ──
    if nargout > 0
        api.fig = fig;
        api.convert = @(val, from, to) convertAPI(val, from, to);
        api.calculate = @(module, func, args) calculateAPI(module, func, args);
        api.getHistory = @() appData.history;
        api.close = @() close(fig);
        varargout{1} = api;
    end

    % ── Nested callbacks ──
    % ... one section per tab ...
end
```

### Tab Construction Pattern

Each tab is built by a helper nested function:

```matlab
function buildCrystalTab(tab)
    gl = uigridlayout(tab, [N 3], 'RowHeight', {...}, ...
        'ColumnWidth', {120, '1x', '1x'}, 'Padding', [10 10 10 10]);

    % Card 1: d-spacing
    lblSection = uilabel(gl, 'Text', 'd-spacing from (hkl)', ...
        'FontWeight', 'bold', 'FontSize', 13);
    lblSection.Layout.Row = 1; lblSection.Layout.Column = [1 3];

    % ... input fields, dropdown for crystal system, Calculate button ...

    % Card 2: 2theta from d
    % ...
end
```

### Live Update vs. Calculate Button

**Decision:** Use explicit "Calculate" buttons, not live-update-on-keystroke.

**Rationale:**
- Several calculations are multi-field (need all inputs valid before computing).
- Avoids confusing intermediate states while the user is still typing.
- Consistent with the rest of the toolkit's explicit-action pattern
  (Apply Corrections, Convert, etc.).
- Exception: The Unit Converter tab updates on Enter or pressing a Convert
  button — since it only has two fields (value + unit), live feedback is
  appropriate there.

### History Log

Every conversion or calculation appends a one-line summary to
`appData.history`. A "History" panel (or a small text area at the bottom
of the window, toggled by a toolbar button) shows the log. Users can
copy individual lines or the full log.

```matlab
appData.history{end+1} = struct( ...
    'timestamp', datetime('now'), ...
    'type', 'convert', ...       % 'convert' | 'crystal' | 'electrical' | ...
    'summary', '1 mA/cm^2 = 10 A/m^2', ...
    'inputs', struct('value', 1, 'from', 'mA/cm^2', 'to', 'A/m^2'), ...
    'result', 10, ...
    'latex', '$1\,\text{mA/cm}^2 = 10\,\text{A/m}^2$');
```

### Copy-as-LaTeX

Every result display area has a small "TeX" button that copies a
LaTeX-formatted string to the system clipboard. Each calculation result
struct includes a `.latex` field generated by the `+calc/` function
alongside the numeric result. The "TeX" button calls
`clipboard('copy', result.latex)`.

**Format examples:**
```
d-spacing:      $d_{111} = 2.35\,\text{\AA}$
2theta:         $2\theta = 38.47°$
SLD:            $\mathrm{SLD} = 6.35 \times 10^{-6}\,\text{\AA}^{-2}$
resistivity:    $\rho = 1.72 \times 10^{-6}\,\Omega\cdot\text{cm}$
critical field: $H_{c2} = 14.5\,\text{T}$
```

---

## Key Decisions

### 1. New `+calc/` package vs. extending `+utilities/`

**Decided:** New `+calc/` package.

**Alternatives:**
- (a) Add functions to `+utilities/` — rejected because utilities is for
  array-level data processing, not scalar physics calculations. Mixing
  concerns makes the namespace harder to navigate.
- (b) Put everything in the GUI file — rejected because the calculations
  are independently useful from scripts and the command line.

**Rationale:** Clean separation of concerns. Calculator functions are usable
without the GUI (`calc.crystal.dSpacing(5.43, 5.43, 5.43, 90, 90, 90, 1, 1, 1)`).
Testable in isolation.

### 2. `uitabgroup` vs. custom tab bar

**Decided:** `uitabgroup` (MATLAB built-in).

**Alternatives:**
- (a) Custom button bar that shows/hides panels — more visual control but
  significant manual state management.
- (b) `uitabgroup` — zero tab-switching code, built-in rendering, good enough
  visually.

**Rationale:** Simplicity. The tab bar does not need custom styling. Using
the built-in saves ~100 lines of switching logic and is guaranteed to work
across MATLAB versions.

### 3. Unit parser scope

**Decided:** Build a real dimensional-analysis parser that handles
`prefix + base_unit` decomposition and compound expressions with `/`, `*`,
and `^N`.

**Alternatives:**
- (a) Extend the existing enum-style lookup in `convertUnits.m` with more
  entries — simple but cannot handle `mA/um^2` or arbitrary prefix+unit
  combos. Dead end for extensibility.
- (b) Full symbolic CAS-style parser — overkill, pulls in complexity we
  don't need (parenthesized sub-expressions, implicit multiplication
  disambiguation, etc.).
- (c) Middle ground: tokenize on `/` and `*`, decompose prefix+base per
  token, accumulate dimensions — this is option (c) and is what we chose.

**Rationale:** Option (c) handles all the real-world use cases listed in
the requirements without the complexity of a general expression parser. If
parenthesized expressions are needed later, the tokenizer can be extended.

### 4. Single-file GUI vs. multi-file

**Decided:** Single `materialsCalcGUI.m` file, following existing convention.

**Rationale:** All three existing GUIs are single-file. Consistency with the
codebase matters more than theoretical separation. The file will be
~1500-2000 lines — smaller than dataImportGUI (~11000) or emViewerGUI
(~6000). With 6 tabs, this is comfortably within single-file scope. The
heavy logic lives in `+calc/`. If the file exceeds ~2500 lines,
tab-builder functions can be extracted to `+calc/gui/` helpers (one
function per tab).

### 5. Disambiguation of SI prefixes vs. unit names

**Decided:** Match full token against known base units first, then try
prefix splitting.

Examples of ambiguity:
- `Pa` = Pascal (not peta-Ampere). Resolved: `Pa` is in the base unit registry.
- `mm` = milli-meter. Resolved: `mm` is not a base unit, so split as `m` + `m`.
- `mT` = milli-Tesla. Same approach.
- `um` = micro-meter. Special alias: `u` recognized as micro prefix.
- `Torr`, `atm`, `bar` = base units (no prefix splitting).
- `Oe` = base unit (Oersted).

The base unit registry is checked first (exact match). Only on failure does
prefix stripping occur. This eliminates almost all ambiguity.

### 6. How to handle Oe <-> T (H-field vs. B-field)

**Decided:** Treat this as a named equivalence bridge, not a dimensional
conversion.

**Rationale:** Oe measures H-field (A/m in SI), while T measures B-field
(kg/A/s^2 in SI). They are physically different quantities related by
B = mu0 * H in free space. Researchers routinely "convert" between them
using the free-space relationship, so the tool should support it — but as
an explicit bridge with a note that it assumes mu0 (vacuum permeability).

---

## Calculation Module Details

### Physical Constants (defined in `+calc/constants.m`)

```matlab
% Fundamental constants (CODATA 2018)
h     = 6.62607015e-34;    % Planck constant (J*s)
hbar  = 1.054571817e-34;   % reduced Planck (J*s)
c     = 2.99792458e8;      % speed of light (m/s)
e     = 1.602176634e-19;   % elementary charge (C)
kB    = 1.380649e-23;      % Boltzmann constant (J/K)
NA    = 6.02214076e23;     % Avogadro number (1/mol)
mu0   = 4*pi*1e-7;         % vacuum permeability (H/m)
muB   = 9.2740100783e-24;  % Bohr magneton (J/T)
r_e   = 2.8179403262e-15;  % classical electron radius (m)
R     = 8.314462618;       % gas constant (J/mol/K)
F     = 96485.33212;       % Faraday constant (C/mol)
Phi0  = 2.067833848e-15;   % magnetic flux quantum (Wb)
```

**Decision:** Put constants in `+calc/constants.m` as a function returning a
struct. Every `+calc/` module calls `C = calc.constants()` at the top.
Avoids magic numbers scattered across files.

**Performance:** Uses `persistent` variable internally — the struct is built
once on first call, then returned from cache on subsequent calls. Zero overhead
after initialization.

### Neutron SLD Calculation

The SLD for a material is:
```
SLD = (sum_i n_i * b_i) / V_cell
```
where `n_i` = number of atoms of element i per formula unit, `b_i` =
coherent scattering length, `V_cell` = molecular volume = M/(rho * NA).

Scattering length data comes from `calc.elementData` (the single source of
truth). The `.bCoherent` field on each element struct holds the coherent
scattering length in fm (NaN for elements not yet populated). `neutronSLD`
calls `calc.elementData()` and looks up each element by symbol — no duplicate
table in `calc.xrayNeutron`.

### Chemical Formula Parser (inside `calc.xrayNeutron`)

Parses strings like `"Fe3O4"`, `"SiO2"`, `"Co0.5Fe0.5"` into element-count
pairs.

```matlab
function elems = parseFormula(formula)
%PARSEFORMULA  Parse a chemical formula string into element-count pairs.
%   elems = parseFormula('Fe3O4')
%   elems = struct with fields Fe=3, O=4
```

Regex approach: match `([A-Z][a-z]?)(\d*\.?\d*)` globally. If the number
is empty, default to 1. Parenthesized groups `(Fe0.5Co0.5)3O4` are a
stretch goal — document as unsupported initially.

---

## Integration Points with Existing Toolbox

1. **`+utilities/convertUnits.m`** — remains as-is. The new `calc.unitConvert`
   is strictly additive. If desired later, `convertUnits` can be refactored
   to delegate to `calc.unitConvert` internally.

2. **`dataImportGUI.m`** — Phase 4 adds `calc.xrayNeutron` sub-dialogs (SLD
   calculator, Q-to-2theta converter) integrated directly into the data GUI
   where the measurement data lives. An optional toolbar button can launch
   `materialsCalcGUI` (like the existing "Batch Convert" button launches
   `xrdConvertGUI`).

3. **`setupToolbox.m`** — already adds the repo root to path, which covers
   `+calc/`. Phase 5 adds a one-time `mkdir` for `data/` and `data/cif/`
   (create on first use in `calc.crystalCache`).

4. **`runAllTests.m`** — add test groups: `"calc"` (core modules + units),
   `"calcgui"` (GUI tests).

5. **Common wavelengths** — the GUI stores a wavelength preset dropdown
   (Cu Ka1, Mo Ka1, etc.). The same values are used in `dataImportGUI`
   (XRD analysis). Extract to `calc.constants()` so both GUIs share the
   same source of truth.

---

## Migration / Implementation Path

Each step leaves the system fully working. Steps are ordered by dependency.

### Phase 1: Foundation (4 steps)

**Purpose:** Build the unit conversion engine and element database that
everything else depends on.

1. Create `+calc/constants.m` — physical constants struct.
2. Create `+calc/unitConvert.m` — unit parser + conversion engine.
   - Base unit registry (length, mass, time, current, temperature, amount,
     energy, pressure, magnetic field, magnetic moment, angle, frequency).
   - SI prefix table with disambiguation logic.
   - Tokenizer for compound expressions.
   - Dimension vector arithmetic.
   - Equivalence bridges (eV<->nm, eV<->cm^-1, eV<->THz, K<->C<->F, Oe<->T).
3. Create `+calc/elementData.m` — periodic table database (118 elements,
   all properties).
4. Create `tests/test_calc_units.m` — comprehensive unit conversion tests.
   Verify: `calc.unitConvert(1, 'mA/cm^2', 'A/m^2')` returns 10.

### Phase 2: Core calculation modules (7 steps)

**Purpose:** Build the pure-computation backends for each domain. All
functions are usable from the command line independent of the GUI.

5. Create `+calc/+crystal/` — dSpacing, twoThetaFromD, dFromTwoTheta,
   atomicDensity, unitCellVolume, densityFromMolar, latticeMismatch,
   criticalThickness, strainFromPoisson, tetragonalDistortion.
6. Create `+calc/+electrical/` — resistivity, conductivity, mobility,
   currentDensity, sheetResistance.
7. Create `+calc/+semiconductor/` — all 13 functions + material presets.
8. Create `+calc/+thinFilm/` — depositionRate, kiessigThickness, stoneyStress,
   doseFromCurrent, thermalMismatchStrain, multilayerThermalConductivity,
   diffusionLength_thermal.
9. Create `+calc/+magnetic/` — momentPerAtom, magnetization,
   bohrMagnetonConvert, demagFactor.
10. Create `+calc/+substrates/` — getSubstrate, listSubstrates with 14
    presets (including dielectric constants).
11. Create `tests/test_calc_modules.m` — tests for all Phase 2 modules.

### Phase 3: GUI (6 steps)

**Purpose:** Build the standalone materials calculator with 6 tabs covering
the most frequently used calculations.

12. Create `materialsCalcGUI.m` — figure, root grid, tab group, status bar,
    API struct.
13. Build Unit Converter tab (free-text parser, swap, presets, live update).
14. Build Crystal, Electrical, Semiconductor, Thin Film tabs (calculation
    cards with Calculate buttons).
15. Build Periodic Table tab (element grid, property/color dropdowns,
    highlight search, detail bar).
16. Add history log + copy-as-LaTeX on result displays.
17. Create `tests/test_materials_calc_gui.m` — headless API tests.

### Phase 4: X-ray/Neutron integration (4 steps)

**Purpose:** Add scattering and diffraction calculations. These integrate
into dataImportGUI (where the data lives) rather than the standalone
calculator.

18. Create `+calc/+xrayNeutron/` — braggLaw, qToTwoTheta, twoThetaToQ,
    neutronSLD, xraySLD, parseFormula, molecularWeight,
    weightToAtomicPercent, atomicToWeightPercent, balanceReaction,
    coDepositionRatio.
19. Add SLD calculator and Q-to-2theta converter as sub-dialog or panel in
    dataImportGUI.
20. Create `tests/test_calc_xrayneutron.m`.
21. Update `CLAUDE.md` and `runAllTests.m` with all new modules and test
    groups.

### Phase 5: Extensions (5 steps)

**Purpose:** Add niche-but-valuable features once the core tool is stable
and tested.

22. Create `+calc/+superconductor/` — londonDepth, coherenceLength,
    glParameter, criticalFields, depairingCurrent + material presets
    (Nb, NbN, YBCO, MgB2, Al, Pb, In, Sn). Add Superconductor tab to
    materialsCalcGUI.
    *Why: Superconducting thin films are a significant research area. The
    module is small (5 functions + presets) but the calculations are tedious
    to do by hand.*
23. Create `+calc/importCIF.m` — CIF file parser (tag-value pairs, loop
    blocks, uncertainty stripping, multi-block).
24. Create `+calc/crystalCache.m` — local crystal structure database
    (add/import/search/list/remove/rebuild). Create `data/` and `data/cif/`
    folders (gitignored).
    *Why: Once you start exporting CIFs from ICSD, having a searchable local
    cache that auto-fills Crystal tab inputs saves significant time vs.
    manually entering lattice parameters.*
25. Add Favorites tab to materialsCalcGUI — pin/unpin toggle on calculation
    cards, Favorites tab renders pinned cards.
    *Why: With 7+ tabs (after Superconductor), navigating to frequently-used
    calculations gets tedious. Pinning the 3-4 you use daily to one tab
    eliminates tab-switching.*
26. Create `tests/test_cif_parser.m` and `tests/test_superconductor.m`.

---

## Deferred / Optional

Items that have been designed but are not scheduled. Each includes what it
is, why it is deferred, when to build it, and a pointer to its detailed
design (in the Deferred Module Details section below).

### 1. `calc.optics` module + Optics tab

Fresnel coefficients, refractive index ↔ dielectric constant, critical
angle, penetration depth, Brewster angle, skin depth.

**Why deferred:** Useful but secondary to core materials calculations. The
optics functions are self-contained with no dependencies on other `+calc/`
modules.

**When to build:** When doing optical characterization work (ellipsometry,
reflectance, transmittance). Can be added independently at any time after
Phase 2.

**Detailed design:** See Deferred Module Details — Optics below.

### 2. `calc.vacuum` module + Vacuum tab

Mean free path, Knudsen number, monolayer time, sputter yield lookup,
pump-down time, gas flow conductance.

**Why deferred:** Operationally distinct from materials properties — more
about the deposition system than the material. Could become a small
standalone `vacuumCalcGUI.m` (~300 lines) rather than a tab in
materialsCalcGUI.

**When to build:** When vacuum system calculations become a recurring need.
Can be added independently at any time after Phase 2.

**Detailed design:** See Deferred Module Details — Vacuum below.

### 3. `calc.electrochemistry` module + Electrochemistry tab

Nernst potential, Butler-Volmer, Tafel slope, double-layer capacitance,
ohmic drop.

**Why deferred:** Different research domain. No dependencies on other
`+calc/` modules.

**When to build:** If electrochemical measurements become part of the
workflow.

**Detailed design:** See Deferred Module Details — Electrochemistry below.

### 4. Multilayer Builder tab

Layer stack management, SLD profile plotting, Kiessig fringe prediction,
export to XRR fit format.

**Why deferred:** Depends on the XRR fitting plan (`xrr_fitting_plan.md`)
being implemented first. The multilayer struct format must align with
`utilities.parrattRefl`. Building the builder before the XRR engine exists
means the "Export to XRR Fit" path cannot be tested end-to-end.

**When to build:** Alongside `parrattRefl` implementation. The builder and
the fitting engine should be developed in the same phase.

**Detailed design:** See Deferred Module Details — Multilayer Builder below.

### 5. Ion beam / implantation functions

`projectedRange`, `doseToConcentration`, `sputterRate` in `+calc/+thinFilm/`.

**Why deferred:** Niche use case. The LSS-based projected range estimate is
approximate (~20-30%), and users typically use SRIM for precise work.
Lookup tables for sputter yield are similarly approximate and vary with
surface conditions.

**When to build:** When ion beam work (implantation, sputtering, FIB)
becomes active. These are standalone functions with no GUI impact — they
can be dropped into `+calc/+thinFilm/` at any time.

**Function specifications (preserved for implementation):**

| Function | Inputs | Output |
|----------|--------|--------|
| `projectedRange(ion, target, energy)` | Ion symbol, target symbol, energy (keV) | Rp and deltaRp (nm) via simplified LSS estimate |
| `doseToConcentration(dose, Rp, deltaRp)` | Dose (ions/cm^2), projected range (nm), straggle (nm) | Peak concentration (atoms/cm^3) from Gaussian profile |
| `sputterRate(Y, J, rho, M)` | Sputter yield (atoms/ion), current density (mA/cm^2), target density (g/cm^3), molar mass (g/mol) | Sputter rate (nm/s) |

- `projectedRange` uses the simplified LSS (Lindhard-Scharff-Schiott) nuclear
  stopping approximation. Returns Rp (projected range) and deltaRp (straggle)
  in nm. Accuracy is within ~20-30% for typical ion/target combinations at
  10-1000 keV. A warning note is included in the result struct reminding users
  that SRIM/TRIM is more accurate for precise work.
- `doseToConcentration` assumes a Gaussian implant profile:
  `C_peak = dose / (sqrt(2*pi) * deltaRp)`. Returns peak concentration.
- `sputterRate` converts sputter yield + beam current density to a material
  removal rate: `rate = Y * J / (rho * NA / M) * 1e7` (nm/s).

### 6. Export calculation report

Toolbar button to dump session history to a formatted text file suitable
for lab notebook records.

**Why deferred:** Nice-to-have polish feature. The history log covers the
immediate need for reviewing past calculations. A text export is
convenience, not functionality.

**When to build:** After the GUI is stable and the history log is proven
useful.

**Detailed design:** See Deferred Module Details — Export Report below.

### 7. Color-coded history with re-run buttons

History entries grouped/colored by calculation type, with a re-run button
that navigates to the appropriate tab and repopulates input fields.

**Why deferred:** The basic history log is sufficient for v1. Color-coding
and re-run are UX polish that add complexity to the history data structure
(each entry must store enough input data to reconstruct card state).

**When to build:** When the basic history proves useful enough to invest in
enhanced UX.

**Detailed design:** See Deferred Module Details — Color-Coded History below.

### 8. Crystal database GUI integration

"Load from database" and "Import CIF files" buttons in Crystal tab,
browse/search dialog that queries `calc.crystalCache`.

**Why deferred:** Depends on Phase 5 CIF parser and crystal cache being
built first. The cache is command-line usable after Phase 5; GUI
integration is a follow-up.

**When to build:** After Phase 5 is complete and the cache has been
populated with enough structures to be useful.

---

## Deferred Module Details

### Optics

Thin film optics calculations. All angles in degrees unless noted.

| Function | Inputs | Output |
|----------|--------|--------|
| `refractiveToDielectric(n, k)` | Refractive index n, extinction coefficient k | Complex dielectric constant `eps = (n + i*k)^2` -> eps1, eps2 |
| `dielectricToRefractive(eps1, eps2)` | Real and imaginary parts of dielectric constant | n, k from `n + i*k = sqrt(eps1 + i*eps2)` |
| `fresnelCoefficients(n1, n2, theta)` | Refractive indices of media 1 and 2, incidence angle (deg) | rs, rp, ts, tp (complex Fresnel coefficients) |
| `criticalAngle(n1, n2)` | Refractive indices (real parts) | Total external reflection angle (deg); NaN if n2 > n1 |
| `penetrationDepth(n, k, lambda)` | Refractive index, extinction coeff, wavelength (Ang or nm) | 1/e penetration depth (same unit as lambda) |
| `brewsterAngle(n1, n2)` | Refractive indices of media 1 and 2 | Brewster angle (deg) |
| `skinDepth(rho, f)` | Resistivity (Ohm*m), frequency (Hz) | Electromagnetic skin depth (m, um, nm) |

**Key formulas:**

- **Fresnel coefficients** at an interface (s and p polarization):
  ```
  rs = (n1*cos(theta_i) - n2*cos(theta_t)) / (n1*cos(theta_i) + n2*cos(theta_t))
  rp = (n2*cos(theta_i) - n1*cos(theta_t)) / (n2*cos(theta_i) + n1*cos(theta_t))
  ```
  where `theta_t` from Snell's law: `n1*sin(theta_i) = n2*sin(theta_t)`.
  For complex n (absorbing media), `cos(theta_t)` is computed via
  `sqrt(1 - (n1/n2 * sin(theta_i))^2)`.
  Returns struct with `.rs`, `.rp`, `.ts`, `.tp`, `.Rs` (reflectance),
  `.Rp`, `.Ts`, `.Tp`.

- **Penetration depth** (X-ray / neutron):
  `d = lambda / (4*pi*k)` for evanescent wave below critical angle.
  Also computes absorption length `1/(2*mu)` where `mu = 4*pi*k/lambda`.

- **Skin depth:** `delta = sqrt(2*rho / (2*pi*f*mu0))`. Returns in multiple
  unit scales (m, um, nm) for convenience.

**GUI tab layout for Optics:**

The Optics tab groups calculations into cards:
1. **Refractive Index / Dielectric** — n,k <-> eps1,eps2 converter
2. **Fresnel Coefficients** — n1, n2, angle -> rs, rp, Rs, Rp plot vs angle
3. **Critical / Brewster Angle** — n1, n2 -> angles
4. **Penetration Depth** — n, k, lambda -> depth
5. **Skin Depth** — resistivity, frequency -> depth

### Vacuum

Vacuum science and gas-phase calculations for deposition and sputtering systems.

| Function | Inputs | Output |
|----------|--------|--------|
| `meanFreePath(P, T, d)` | Pressure (Pa), temperature (K), molecular diameter (m) | Mean free path (m) |
| `knudsenNumber(mfp, L)` | Mean free path (m), characteristic length (m) | Kn (dimensionless) + flow regime string |
| `monolayerTime(P, m, T)` | Pressure (Pa), molecular mass (kg), temperature (K) | Monolayer formation time (s) via Langmuir formula |
| `sputterYield(material, ion, energy)` | Target material, ion species, energy (eV) | Sputter yield (atoms/ion) from lookup table |
| `pumpDownTime(V, S, P0, Pf)` | Chamber volume (L), pump speed (L/s), initial/final pressure (Pa) | Time (s) for exponential pump-down |
| `gasFlow(P1, P2, d, L, T, m)` | Upstream/downstream pressure (Pa), tube diameter (m), length (m), temp (K), molecular mass (kg) | Conductance (L/s) and throughput (Pa*L/s) for molecular and viscous regimes |

**Key formulas:**

- **Mean free path:** `mfp = kB*T / (sqrt(2) * pi * d^2 * P)`
  where `d` is the effective molecular diameter. Common defaults:
  N2 = 3.64e-10 m, Ar = 3.58e-10 m, O2 = 3.46e-10 m.

- **Knudsen number:** `Kn = mfp / L`. Reports flow regime:
  - Kn > 1: molecular flow
  - 0.01 < Kn < 1: transition flow
  - Kn < 0.01: viscous (continuum) flow

- **Monolayer formation time (Langmuir):**
  `t_mono = 1 / (P / sqrt(2*pi*m*kB*T) * A_site)` where `A_site` is the
  adsorption site area (~1e-19 m^2 for typical surfaces). At 1e-6 Torr,
  t_mono ~ 1 second — the classic rule of thumb.

- **Sputter yield lookup table:** A struct of common ion/target/energy
  combinations, sourced from Yamamura & Tawara (1996) and Matsunami et al.
  Common entries include:
  ```matlab
  % sputterYields.(target).(ion) = [energy_eV, yield] pairs
  sputterYields.Si.Ar  = [200 0.4; 500 0.9; 1000 1.2; 5000 1.4];
  sputterYields.Cu.Ar  = [200 1.5; 500 3.0; 1000 4.0; 5000 4.5];
  sputterYields.Fe.Ar  = [200 0.8; 500 1.6; 1000 2.2; 5000 2.6];
  sputterYields.Au.Ar  = [200 1.5; 500 3.2; 1000 4.4; 5000 5.0];
  sputterYields.Ti.Ar  = [200 0.3; 500 0.7; 1000 1.1; 5000 1.4];
  sputterYields.SiO2.Ar = [200 0.3; 500 0.7; 1000 1.0; 5000 1.2];
  % ... ~20 more common combinations ...
  ```
  Interpolates between tabulated energies. Returns NaN with warning for
  combinations not in the table. The function docstring clearly states that
  tabulated values are approximate (within ~30%) and that SRIM is recommended
  for precise work.

- **Pump-down time:** `t = (V/S) * ln(P0/Pf)` for ideal exponential pump-down.
  Also returns the time constant `tau = V/S`. Warns that real pump-down is
  slower due to outgassing, which this model does not account for.

- **Gas flow (tube conductance):**
  - Molecular regime: `C_mol = (pi*d^3/(12*L)) * sqrt(8*kB*T/(pi*m))`
  - Viscous regime: `C_visc = (pi*d^4/(128*eta*L)) * P_avg`
  Returns both regimes and the Knudsen number to indicate which applies.

**GUI tab layout for Vacuum:**

The Vacuum tab groups calculations into cards:
1. **Mean Free Path** — pressure, temperature, gas -> mfp + Knudsen number
2. **Monolayer Time** — pressure, gas -> time to form one monolayer
3. **Sputter Yield** — material/ion/energy dropdowns -> yield
4. **Pump-Down Estimate** — volume, pump speed, pressures -> time
5. **Tube Conductance** — dimensions, gas, pressures -> conductance + regime

### Electrochemistry

Basic electrochemistry calculations for thin film electrode work.

| Function | Inputs | Output |
|----------|--------|--------|
| `nernstPotential(E0, n, Q, T)` | Standard potential (V), electron count, reaction quotient, temperature (K) | Equilibrium potential (V) |
| `exchangeCurrentDensity(j0, eta, alpha, T)` | Exchange current density (A/cm^2), overpotential (V), transfer coefficient, temperature (K) | Current density (A/cm^2) via Butler-Volmer |
| `tafelSlope(alpha, T)` | Transfer coefficient, temperature (K) | Tafel slope (mV/decade) |
| `doubleLayerCapacitance(epsilon, d, A)` | Dielectric constant, double layer thickness (nm), electrode area (cm^2) | Capacitance (F) via parallel plate model |
| `ohmicDrop(I, R)` | Current (A), resistance (Ohm) | IR drop (V) |

**Key formulas:**

- **Nernst equation:**
  `E = E0 - (R*T)/(n*F) * ln(Q)`
  where `F` = 96485 C/mol (Faraday constant), `R` = gas constant, `n` =
  number of electrons transferred, `Q` = reaction quotient.

- **Butler-Volmer equation:**
  `j = j0 * [exp(alpha*F*eta/(R*T)) - exp(-(1-alpha)*F*eta/(R*T))]`
  Returns the full current density at the given overpotential. Also returns
  the Tafel approximation (valid for |eta| >> RT/F).

- **Tafel slope:**
  `b = 2.303 * R * T / (alpha * F)` in V/decade (displayed as mV/decade).
  At 298 K with alpha=0.5: b ~ 118 mV/decade.

- **Double layer capacitance:**
  `C = epsilon_0 * epsilon * A / d`
  Typical values: epsilon ~ 6-80 (solvent), d ~ 0.3-1 nm (Helmholtz layer).

**GUI tab layout for Electrochemistry:**

The Electrochemistry tab groups calculations into cards:
1. **Nernst Potential** — E0, n, concentrations, T -> E_eq
2. **Butler-Volmer** — j0, eta, alpha, T -> j (plot j vs eta optional)
3. **Tafel Slope** — alpha, T -> slope
4. **Double Layer Capacitance** — epsilon, d, A -> C
5. **Ohmic Drop** — I, R -> IR correction

### Multilayer Builder

A dedicated tab for constructing thin film layer stacks and computing
derived properties. This is the bridge between the materials calculator
and the XRR/reflectometry fitting workflow.

#### Layout

```
+===================================================================+
|  ── Layer Stack ──────────────────────────────────                  |
|                                                                    |
|  ┌────────────────────────────────────────────────────────────┐    |
|  │  #  Material      Thickness(Ang)  Density  Roughness(Ang) │    |
|  │  0  Ambient (air)  —              —        —              │    |
|  │  1  Fe             200            7.87     5.0            │    |
|  │  2  MgO            50             3.58     3.0            │    |
|  │  3  Si (substrate) —              2.33     2.0            │    |
|  └────────────────────────────────────────────────────────────┘    |
|                                                                    |
|  [Add Layer] [Remove] [Move Up] [Move Down]                       |
|  [Load from Crystal Cache] [Load Substrate Preset]                 |
|                                                                    |
|  ── Computed Properties ──────────────────────────                  |
|  Total thickness: 250 Ang                                          |
|  Average density: 5.87 g/cm^3                                     |
|  Expected Kiessig fringe spacing: deltaQ = 0.0251 Ang^-1          |
|                                                                    |
|  ── SLD Profile ──────────────────────────                         |
|  [X-ray SLD] [Neutron SLD]  Energy: [8.048__] keV                 |
|  ┌─────────────────────────────────────────────┐                   |
|  │         SLD vs Depth plot                    │                   |
|  │  ───────────────────────────────             │                   |
|  └─────────────────────────────────────────────┘                   |
|                                                                    |
|  [Export to XRR Fit] [Export Stack as CSV] [Copy LaTeX Table]      |
+===================================================================+
```

#### Layer Stack Data Structure

Each layer in the stack is a struct matching the format expected by the XRR
fitting plan (`xrr_fitting_plan.md`):

```matlab
% appData.multilayer.stack — struct array, top to bottom
stack(1).name      = 'Ambient';
stack(1).formula   = '';
stack(1).thickness = 0;          % Ang (0 = semi-infinite)
stack(1).density   = 0;          % g/cm^3
stack(1).roughness = 0;          % Ang
stack(1).sld       = 0;          % 1e-6 Ang^-2 (computed)
stack(1).isld      = 0;          % 1e-6 Ang^-2 (computed, imaginary)
stack(1).source    = 'manual';   % 'manual' | 'cache' | 'substrate'

% Middle layers: film stack
stack(2).name      = 'Fe';
stack(2).formula   = 'Fe';
stack(2).thickness = 200;
stack(2).density   = 7.874;
stack(2).roughness = 5.0;
stack(2).sld       = [];         % auto-computed from formula + density
stack(2).isld      = [];
stack(2).source    = 'cache';

% Last layer: substrate (thickness = 0, semi-infinite)
stack(end).name    = 'Si';
stack(end).formula = 'Si';
stack(end).thickness = 0;
stack(end).density = 2.329;
stack(end).roughness = 2.0;
stack(end).sld     = [];
stack(end).source  = 'substrate';
```

#### XRR Export Format

The "Export to XRR Fit" button converts the multilayer stack into the
`[M x 4]` matrix format expected by `utilities.parrattRefl`:

```matlab
% Export: stack → [thickness, SLD, iSLD, roughness] per row
function layers = exportToXRR(stack)
    M = numel(stack);
    layers = zeros(M, 4);
    for j = 1:M
        layers(j, :) = [stack(j).thickness, stack(j).sld, ...
                         stack(j).isld, stack(j).roughness];
    end
end
```

This matrix can be passed directly to `utilities.parrattRefl(Q, layers)` for
reflectivity simulation, or used as the starting model in the XRR fitting
dialog (`onFitReflectivity` in `dataImportGUI.m`).

#### SLD Profile Computation

For each layer, the SLD is computed via:
- **Neutron:** `calc.xrayNeutron.neutronSLD(formula, density)` per layer
- **X-ray:** `calc.xrayNeutron.xraySLD(formula, density, energy)` per layer

The SLD-vs-depth profile is plotted as a step function with error-function
interfaces (Nevot-Croce roughness model):

```matlab
% For each interface between layer j and j+1:
%   SLD(z) = (SLD_j + SLD_{j+1})/2 + (SLD_{j+1} - SLD_j)/2 * erf((z - z_j) / (sigma_j * sqrt(2)))
```

#### FFT Prediction

From the layer thicknesses, predict expected FFT peak positions (Kiessig
fringes) that would appear in an XRR measurement:

```matlab
% For each individual layer of thickness d:
%   deltaQ = 2*pi / d
% For total stack thickness D:
%   deltaQ_total = 2*pi / D
```

These predicted positions can be overlaid on actual FFT data in the
dataImportGUI reflectivity FFT dialog.

#### Computed Properties

- **Total thickness:** `sum([stack(2:end-1).thickness])`
- **Average density:** weighted average by thickness
- **Kiessig fringe spacing:** `deltaQ = 2*pi / totalThickness` (Ang^-1)

> **Standalone note:** The multilayer builder works independently even before
> `utilities.parrattRefl` (from the XRR fitting plan) is implemented. SLD
> profile computation, CSV export, and LaTeX table copy all work without it.
> The "Export to XRR Fit" button is only enabled when `parrattRefl` exists,
> checked at runtime via `exist('utilities.parrattRefl', 'file')`.

### Export Report

A toolbar button ("Report" or export icon) dumps the current session's inputs
and results to a formatted text file suitable for lab notebook records.

**Report contents:**
```
============================================================
Materials Calculator — Session Report
Date: 2026-03-16 14:23:05
============================================================

--- Unit Conversions ---
[14:01] 1 mA/cm^2 = 10 A/m^2
[14:03] 1.5406 Ang = 0.15406 nm

--- Crystal Calculations ---
[14:05] d-spacing: d(111) = 2.3456 Ang
        Inputs: a=4.08 Ang, cubic, hkl=(1,1,1)
[14:07] Lattice mismatch: Fe(100) on MgO(100)
        aFilm=2.87 Ang, aSub=4.21 Ang → f = -31.8%

--- Thin Film ---
[14:10] Stoney stress: sigma = 450 MPa (compressive)
        Inputs: Es=130 GPa, nus=0.28, ts=500 um, tf=100 nm, R=25 m

============================================================
Total calculations: 5
```

**Implementation:**
- Iterates over `appData.history`, groups by type.
- Writes to a user-selected `.txt` file via `uiputfile`.
- Timestamp in header, each entry shows time, summary, and full inputs.
- The "Report" button is in the toolbar row at the top of the GUI.

### Color-Coded History

History entries are grouped and colored by calculation type. Each type maps
to a background highlight color in the history panel:

```matlab
historyColors = struct( ...
    'convert',         [0.85 0.92 1.00], ...  % light blue
    'crystal',         [0.85 1.00 0.85], ...  % light green
    'electrical',      [1.00 0.95 0.80], ...  % light amber
    'semiconductor',   [1.00 0.85 0.85], ...  % light coral
    'thinFilm',        [0.90 0.85 1.00], ...  % light purple
    'magnetic',        [0.85 0.95 0.95], ...  % light teal
    'xrayNeutron',     [0.95 0.90 0.85], ...  % light tan
    'superconductor',  [0.90 0.88 1.00]);     % pale lavender
```

Each history entry row shows:
- Colored left-border or background indicating type
- Timestamp (HH:MM format)
- One-line summary (e.g., "d(111) = 2.35 Ang [cubic, a=4.08]")
- **Re-run button** — clicking it navigates to the appropriate tab and
  repopulates all input fields from `entry.inputs`, allowing the user to
  re-execute or modify the calculation. Implementation: each history entry
  stores enough input data to reconstruct the calculation card state.

### Favorites

The Favorites tab collects pinned calculation cards for quick access.

**Mechanism:**
- Each calculation card (across all tabs) has a small pin/star toggle button
  in its header row. When toggled on, the card appears in the Favorites tab.
- Pinned state is stored in `appData.favorites` — a cell array of structs
  identifying each favorite by `{module, function}` key.
- The Favorites tab renders cloned versions of the pinned cards. Calculations
  executed from Favorites use the same `+calc/` backend functions and append
  to the same history log.
- If no cards are pinned, the Favorites tab shows a help message:
  "Pin frequently used calculations from any tab using the star icon."

```matlab
appData.favorites = {};  % each entry: struct('module','crystal','func','dSpacing')

% Pin/unpin callback
function onToggleFavorite(module, func, btn)
    key = struct('module', module, 'func', func);
    idx = findFavorite(key);
    if isempty(idx)
        appData.favorites{end+1} = key;
        btn.Icon = 'star_filled';   % or change button text/color
    else
        appData.favorites(idx) = [];
        btn.Icon = 'star_outline';
    end
    rebuildFavoritesTab();
end
```

**Persistence (optional):** Favorites can be saved to a `.mat` file alongside
the crystal cache in `data/`, loaded on GUI startup.

---

## Risks & Open Questions

### Risks

1. **Unit disambiguation edge cases.** The prefix-vs-base-unit logic
   handles known cases, but exotic combinations may surprise. Mitigation:
   extensive test coverage with ~50+ unit string examples; the base unit
   registry takes priority so new entries fix ambiguity.

2. **SLD calculator accuracy.** Neutron scattering lengths vary by isotope.
   The initial table uses natural-abundance values. For isotope-specific work
   (e.g., deuterated layers), the function should accept isotope notation
   (`D` for deuterium) but full isotope support is a stretch goal.

3. **GUI size creep.** With 6 tabs, target ~1500-2000 lines. All computation
   lives in `+calc/` — the GUI file only contains layout and callbacks. The
   Periodic Table tab is the largest single tab (~200 lines for 118 button
   placements + callbacks), but the element data itself lives in
   `calc.elementData`. If the file exceeds ~2500 lines, tab-builder
   functions can be extracted to `+calc/gui/` helpers (one function per tab).

4. **Matthews-Blakeslee critical thickness is self-consistent.** The equation
   `h_c = f(h_c)` must be solved iteratively. For very small mismatch, the
   iteration may converge slowly or not at all. Mitigation: cap iterations
   at 100, return NaN with warning if no convergence; validate against known
   values (e.g., InGaAs on GaAs).

### Open Questions

1. **Should `calc.unitConvert` replace `utilities.convertUnits`?** Not
   immediately. The old function has a simpler API that existing code
   depends on. A future PR could make `convertUnits` a thin wrapper around
   the new engine.

2. **X-ray SLD: which electron form factor data to include?** The Henke
   tables are comprehensive but large. For a first pass, use the simple
   classical electron scattering formula: SLD_xray = r_e * electron_density.
   Full anomalous scattering (f' + f'') can be added later.

3. **Parenthesized chemical formulas** like `(La0.7Sr0.3)MnO3` — support
   in Phase 4 or defer? Recommend deferring to keep the formula parser
   simple initially. Users can expand manually: `La0.7Sr0.3Mn1O3`.

4. **Symmetry expansion of atom positions?** The CIF asymmetric unit only
   lists symmetry-unique atoms. Full unit cell visualization would require
   applying space group operations. Defer this — the calculator only needs
   the asymmetric unit for density/SLD calculations (using Z from the CIF).
   Full symmetry expansion is a stretch goal.
