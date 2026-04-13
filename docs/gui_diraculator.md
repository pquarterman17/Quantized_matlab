# DiraCulator — Feature Reference

> For core conventions and quick-start, see [CLAUDE.md](../CLAUDE.md). For the backend API, see [+calc/README.md](../+calc/README.md).

`DiraCulator` is a standalone dark-themed calculator covering 18 panels across 5 domains. It shares no state with BosonPlotter and can be run completely headless via its API struct.

---

## Getting Started

```matlab
DiraCulator              % open interactively
api = DiraCulator();     % headless — returns api struct for scripting/testing
```

The window opens at **Unit Converter**, the default panel. Select any panel from the tree on the left. Every calculation appends a timestamped entry to the History panel and enables the **Copy Result**, **Copy LaTeX**, and **Save** buttons in the status bar.

---

## Navigation Model

The left sidebar is a `uitree` with five category nodes, each expanded by default. Clicking a leaf node shows its panel; clicking a category header does nothing. The active panel key is stored in `appData.activeNavKey`.

```
Reference
  ├── Unit Converter       (navKey: unitConverter)
  ├── ▼ History            (navKey: history)
  └── ★ Favorites          (navKey: favorites)
Materials
  ├── Crystal              (navKey: crystal)
  ├── Thin Film            (navKey: thinFilm)
  ├── Substrates           (navKey: substrates)
  └── Periodic Table       (navKey: periodicTable)
Electronic
  ├── Electrical           (navKey: electrical)
  ├── Semiconductor        (navKey: semiconductor)
  └── Electrochem          (navKey: electrochemistry)
Optics & Scattering
  ├── Optics               (navKey: optics)
  ├── X-ray/Neutron        (navKey: xrayNeutron)
  └── Reflectivity         (navKey: reflectivity)
Thermal-Magnetic
  ├── Superconductor       (navKey: superconductor)
  ├── Magnetic             (navKey: magnetic)
  ├── Thermal              (navKey: thermal)
  ├── Diffusion            (navKey: diffusion)
  └── Vacuum               (navKey: vacuum)
```

Pressing **Enter** at any time triggers the primary Calculate button of the active panel (registered via `registerPrimaryBtn`).

---

## Status Bar

The status bar spans the full window width at the bottom. It contains:

| Control | Description |
|---------|-------------|
| Status label | Plain-text summary of the last calculation result |
| **Copy Result** | Copies the last result string (HTML tags stripped) to the clipboard. Enabled after the first calculation. |
| **Copy LaTeX** | Copies the LaTeX formula string. Only enabled when the last calculation produced one. |
| **★ Save** | Pins the last calculation to the Favorites panel for cross-session recall. |

---

## Panel Reference

### Unit Converter

Converts between any two unit symbols using `calc.unitConvert`.

| Control | Description |
|---------|-------------|
| Value | Numeric value to convert |
| From / To | Unit symbol strings (e.g. `Oe`, `T`, `eV`, `nm`, `GPa`, `deg`) |
| Convert | Runs the conversion; result appears in the Result field and the detail label shows the conversion factor |
| Swap | Exchanges From/To and re-runs |
| Copy Result / Copy LaTeX | Panel-local copy buttons (in addition to status bar) |
| Quick Presets | 8 preset pairs: Oe→T, emu→A·m², eV→nm, Ang→nm, Pa→Torr, K→C, GPa→Pa, deg→rad |

---

### Crystal

Scrollable panel with five cards. Uses `+calc/+crystal/` functions.

**Card 1: d-Spacing**

Computes d-spacing via Bragg's law generalized to all crystal systems: d = f(a, b, c, α, β, γ, h, k, l). Formula via `calc.crystal.dSpacing`.

- Crystal system dropdown constrains lattice parameters (e.g. Cubic disables b, c, angles).
- (hkl) preset dropdown fills h, k, l from common Miller index choices.
- Substrate dropdown auto-fills lattice parameters from `calc.substrates.getSubstrate`.
- After calculation, the **→ Q/2θ** button becomes active and sends the d value to the X-ray/Neutron panel.

**Card 2: 2θ ↔ d**

Converts between Bragg angle and d-spacing using Bragg's law d = λ/(2 sin θ). Calls `calc.crystal.dFromTwoTheta` and `calc.crystal.twoThetaFromD`.

**Card 3: Lattice Mismatch & Critical Thickness**

Formula: f = (a_film − a_sub)/a_sub. Critical thickness h_c via `calc.crystal.criticalThickness`. Substrate dropdown auto-fills a_sub from the built-in database.

**Card 4: Unit Cell Volume & Density**

V = abc sin(α) sin(β) sin(γ_eff) via `calc.crystal.unitCellVolume`. Density via `calc.crystal.densityFromMolar` using M, Z, and the volume. Receives molar mass from the **→ Cell Vol** button in X-ray/Neutron.

**Card 5: Plane Spacing Table**

Enumerates all (hkl) reflections up to a user-specified max index for the current lattice, applies Bravais centering extinction rules, and tabulates d (Å), 2θ (°), and multiplicity. **Copy Table** copies the result as TSV to the clipboard. Calls `calc.crystal.planeSpacings`.

---

### Thin Film

Scrollable panel with six cards. Uses `+calc/+thinFilm/` functions.

| Card | Formula |
|------|---------|
| Deposition Rate | rate = thickness / time (Å/s and nm/min). `calc.thinFilm.depositionRate` |
| Kiessig Fringe Thickness | t = 2π/ΔQ from fringe spacing. `calc.thinFilm.kiessigThickness` |
| Stoney Film Stress | σ = E_s t_s² / (6(1−ν_s) t_f R) (Stoney equation). `calc.thinFilm.stoneyStress` |
| Thermal Mismatch Strain | ε = (α_f − α_s)·ΔT; σ = Eε/(1−ν). `calc.thinFilm.thermalMismatchStrain` |
| Ion Dose | dose = I·t/(q·A). `calc.thinFilm.doseFromCurrent` |
| Scherrer Grain Size | D = Kλ/(β cos θ), K = 0.9. Computed inline. |

---

### Substrates

Reference panel listing 10 common thin-film growth substrates: SrTiO₃, LaAlO₃, MgO, Si, Al₂O₃ (Sapphire), GaAs, LSAT, NdGaO₃, SiO₂, YSZ. Select from the dropdown to view a table of crystallographic and physical properties (a, b, c, density, α_th, ε_r, T_m, bandgap). **Copy Properties** copies the full table as plain text.

---

### Periodic Table

Interactive 18×10 periodic table grid.

**Color Modes** (dropdown): Category (group colors), Atomic Mass, Density, Electronegativity, Atomic Radius (pm), Ionization Energy (eV), Melting Point (K), Electron Affinity (eV), Thermal Conductivity (W/m·K), b_coh (fm). Numeric properties use a viridis gradient; elements with no data appear dark gray.

**Display Checkboxes**: Show Z, Show Mass, Show Property Value — each toggles whether that datum appears inside the element button. Font size scales down automatically when showing more than two lines.

**Search**: Live filter by element name, symbol, or category. Matching elements are shown in bold; non-matching are disabled.

**Element Detail Panel**: Clicking an element populates the monospace text area at the bottom with full properties: atomic number, name, category, period/group, electron configuration, mass, density, atomic radius, electronegativity, ionization energy, electron affinity, melting/boiling point, thermal conductivity, coherent neutron scattering length (b_coh), and X-ray absorption edges (K, L) where available.

---

### Electrical

Scrollable panel with five cards. Uses `+calc/+electrical/` functions.

| Card | Formula |
|------|---------|
| Resistivity / Sheet Resistance | ρ = R_s · t; R_s = ρ/t. `calc.electrical.resistivity`, `calc.electrical.sheetResistance` |
| Conductivity | σ = 1/ρ. `calc.electrical.conductivity` |
| Mobility | μ = 1/(nqρ) in cm²/(V·s). `calc.electrical.mobility` |
| Current Density | J = I/A in A/cm². `calc.electrical.currentDensity` |
| Hall Effect | R_H = V_H·t/(I·B); n = 1/(R_H·q). Computed inline; reports carrier type (n-/p-type). |

---

### Semiconductor

Scrollable panel with four cards. Uses `+calc/+semiconductor/` functions.

| Card | Formula |
|------|---------|
| Intrinsic Properties | n_i = √(N_c N_v)·exp(−E_g/(2k_BT)). Material presets: Si, Ge, GaAs, InP, GaN, SiC. `calc.semiconductor.intrinsicCarrierConc` |
| Doping & Carrier Concentrations | n = (N_d−N_a)/2 + √((N_d−N_a)²/4 + n_i²). `calc.semiconductor.carrierConcentration` |
| Depletion Width (p-n Junction) | W = √(2ε₀ε_r V_bi (N_a+N_d)/(q N_a N_d)). `calc.semiconductor.depletionWidth` |
| Transport | D = μ k_BT/q (Einstein); L = √(Dτ). `calc.semiconductor.diffusionCoeff`, `calc.semiconductor.diffusionLength` |

---

### Electrochem

Four cards using `+calc/+electrochemistry/` functions.

| Card | Formula |
|------|---------|
| Nernst Potential | E = E⁰ − (RT/nF)·ln Q. `calc.electrochemistry.nernstPotential` |
| Butler-Volmer | j = j₀[exp(αFη/RT) − exp(−(1−α)Fη/RT)]. `calc.electrochemistry.butlerVolmer` |
| Tafel Slope | b = (RT)/(αF) in mV/decade. `calc.electrochemistry.tafelSlope` |
| Double Layer Capacitance | C = ε₀ε_r A/d (Helmholtz model). `calc.electrochemistry.doubleLayerCapacitance` |

---

### Optics

Scrollable panel with four cards. Uses `+calc/+optics/` functions.

| Card | Formula |
|------|---------|
| Fresnel Coefficients | r_s, r_p via Fresnel equations; R_s = r_s², T_s = 1−R_s. `calc.optics.fresnelCoefficients` |
| Critical / Brewster Angle | θ_c = arcsin(n₂/n₁); θ_B = arctan(n₂/n₁). `calc.optics.criticalAngle`, `calc.optics.brewsterAngle` |
| Penetration Depth | depth = λ/(4πk). `calc.optics.penetrationDepth` |
| Skin Depth | δ = √(ρ/(πfμ₀)). `calc.optics.skinDepth` |

---

### X-ray / Neutron

Four cards on a non-scrolling layout. Uses `+calc/+xrayNeutron/` functions.

**Card 1: Neutron SLD**

Computes coherent neutron scattering length density from a chemical formula and mass density. Formula: SLD = (N_A · ρ / M) · Σ b_coh. Result in units of 10⁻⁶ Å⁻². After calculation the **→ Reflectivity** button becomes active and adds the material as a layer in the Reflectivity builder. `calc.xrayNeutron.neutronSLD`.

**Card 2: X-ray SLD**

Uses the formula and density fields from Card 1. Computes X-ray SLD from electron density. `calc.xrayNeutron.xraySLD`.

**Card 3: Q / 2θ Converter**

Bidirectional: Q (Å⁻¹) ↔ 2θ (°) via Q = 4π sin(θ)/λ. Wavelength presets: Cu Kα (1.5406 Å), Mo Kα (0.7107 Å), Co Kα (1.7902 Å), Ag Kα (0.5594 Å). Receives d-spacing from the Crystal panel via the **→ Q/2θ** button. `calc.xrayNeutron.qToTwoTheta`, `calc.xrayNeutron.twoThetaToQ`.

**Card 4: Molecular Weight**

Parses a chemical formula and returns molar mass (g/mol). The **→ Cell Vol** button sends the result to the Crystal panel's Unit Cell Density card. `calc.xrayNeutron.molecularWeight`.

---

### Superconductor

Four cards on a non-scrolling layout. Uses `+calc/+superconductor/` functions. Material presets: Nb, NbN, YBCO, MgB₂, Al, Pb, In, Sn.

| Card | Formula |
|------|---------|
| London Penetration Depth | λ(T) = λ₀ / √(1−(T/T_c)⁴). `calc.superconductor.londonDepth` |
| Coherence Length | ξ(T) = ξ₀ / √(1−(T/T_c)⁴) (Gorkov). `calc.superconductor.coherenceLength` |
| GL Parameter | κ = λ/ξ; κ > 1/√2 → Type II. `calc.superconductor.glParameter` |
| Critical Fields | H_c(T) = H_c0[1−(T/T_c)²]; H_c1, H_c2 via GL theory. `calc.superconductor.criticalFields` |

---

### Magnetic

Scrollable panel with five cards. Formulas computed inline (no +calc subpackage call for most).

| Card | Formula |
|------|---------|
| Moment Conversions | Converts emu, A·m², memu, μemu; optionally outputs M (emu/cm³, A/m) and μ_B/atom |
| Demagnetization Factors | Lookup table: sphere N=1/3, thin film OOP N=1, long cylinder axial N=0 |
| Curie-Weiss Law | μ_eff = √(3k_BC/N_A); infers FM/AFM from sign of θ |
| Langevin / Superparamagnetism | L(x) = coth(x) − 1/x where x = μH/(k_BT) |
| Domain Wall & Anisotropy | δ = π√(A/K); E_wall = 4√(AK) |

---

### Thermal

Three cards; formulas computed inline.

| Card | Formula |
|------|---------|
| Wiedemann-Franz Law | κ = L₀σT, L₀ = 2.44×10⁻⁸ W·Ω/K² |
| Debye Temperature | Θ_D = (ℏ/k_B)·v_s·(6π²n)^(1/3) |
| Thermal Diffusivity | α = κ/(ρ c_p) in m²/s |

---

### Diffusion

Three cards; formulas computed inline.

| Card | Formula |
|------|---------|
| Arrhenius Diffusion Coefficient | D = D₀ exp(−E_a/(k_BT)) |
| Diffusion Length | L = √(Dt) |
| Fick's First Law (Flux) | J = −D·ΔC/Δx in atoms/(cm²·s) |

---

### Vacuum

Four cards using `+calc/+vacuum/` functions plus inline calculations.

| Card | Formula |
|------|---------|
| Mean Free Path | λ = k_BT/(√2 π d² P). Gas species dropdown (N₂, He, Ar, H₂, O₂, Xe, Kr). `calc.vacuum` inline |
| Monolayer Formation Time | t_mono from impingement rate at pressure P. `calc.vacuum.monolayerTime` |
| Sputter Yield (Lookup) | Y(target, ion, E). `calc.vacuum.sputterYield` |
| Pump-Down Estimate | t = (V/S)·ln(P₀/P_f); τ = V/S. `calc.vacuum.pumpDownTime` |

---

### Reflectivity Builder

Multilayer stack editor with Parratt recursion and SLD profile plot.

**Layer Stack Table** — Each row is a layer: Name, Formula, Thickness (Å), Density (SLD or g/cm³), Roughness (Å). The first row is the ambient medium (thickness = 0), the last row is the substrate (thickness = 0). Inner rows are editable film layers.

- **Add Layer** inserts a new film layer above the substrate.
- **Remove** deletes the selected non-boundary layer.
- **Move Up / Move Down** reorders film layers.
- **Density units** dropdown: Switch between entering values as SLD (×10⁻⁶ Å⁻²) or mass density (g/cm³). Switching mode auto-converts existing density values via `calc.xrayNeutron.neutronSLD`.

**Computed Properties** — Shows total stack thickness, average SLD/density, and expected Kiessig fringe spacing ΔQ = 2π/t.

**SLD Profile / R(Q)** buttons:

| Button | Action |
|--------|--------|
| Neutron SLD | Plots SLD vs depth (Å) for the current stack |
| X-ray SLD | Same but using X-ray scattering factors |
| R(Q) | Computes reflectivity via Parratt recursion with Nevot-Croce roughness; plots R(Q) on a log scale |
| Export CSV | Saves the layer stack to a CSV file |

The **→ Reflectivity** button in the X-ray/Neutron Neutron SLD card adds the last-computed material as a new layer in this stack.

---

### History

Session history table with columns: Time, Tab, Description, MATLAB Call. Each calculation from any panel appends one row automatically. Rows are sorted chronologically; the table auto-scrolls to the latest entry.

**Right-click** a row to copy it as a MATLAB function call (e.g. `result = calc.crystal.dSpacing(3.905, 0, 0, 1, ...)`) or copy the plain-text description. If no MATLAB call was recorded for that entry, the copy action is disabled.

**Clear History** removes all entries from both the table and `appData.history`.

History entries are stored as `{timestamp, tabKey, description, latexStr, matlabCall}` in `appData.history` (max 100 entries; oldest dropped when full).

---

### Favorites

Pin calculations for quick recall across sessions. After running any calculation, click **★ Save** in the status bar to pin the current result. Favorites are stored in `appData.favorites` as structs with fields `.name`, `.tab`, `.lastResult`, `.lastLatex`.

- Left panel: list of pinned favorites. Clicking one shows its detail on the right.
- **Remove Selected** deletes the selected entry.
- If the same name+tab combination is pinned again, the existing entry is updated instead of duplicated.

Favorites are not persisted to disk between sessions (in-memory only).

---

## Cross-Tab Data Flow

Several results can be sent directly to another panel via cross-tab transfer buttons:

| Source | Button | Destination | What is transferred |
|--------|--------|-------------|---------------------|
| Crystal — d-Spacing card | **→ Q/2θ** | X-ray/Neutron Q/2θ card | d value (Å) → fills Value field and runs d→2θ |
| X-ray/Neutron — Mol. Weight card | **→ Cell Vol** | Crystal — Unit Cell Density card | M (g/mol) → fills molar mass field |
| X-ray/Neutron — Neutron SLD card | **→ Reflectivity** | Reflectivity builder | Adds formula + SLD as a new film layer |

These hooks are implemented via `appData.api` callbacks registered in `buildXrayNeutronTab` and consumed by `buildCrystalTab` / `buildReflectivityTab`.

---

## Headless API

```matlab
api = DiraCulator();     % returns api struct; GUI opens but can be hidden

% Navigation
api.selectTab('crystal')      % switch to any panel by navKey
api.getStatus()               % read current status bar text

% Unit conversion
result = api.convert(1, 'Oe', 'T')             % '0.0001 T'

% Crystal
txt = api.calcDSpacing(3.905, 0, 0, 1)         % d-spacing (cubic, 001)
txt = api.getDResult()                          % last d-spacing label text
tbl = api.calcPlaneSpacings(3.905, 'F')        % plane spacing table (cell array)
txt = api.getMismatchResult()                  % last mismatch label text

% Semiconductor
txt = api.calcIntrinsic('Si')                  % intrinsic properties for Si
txt = api.getNiResult()                        % last ni label text

% Periodic table
api.selectElement('Fe')                        % click an element
lines = api.getElementDetail()                 % detail text area contents

% X-ray / Neutron
txt = api.calcNeutronSLD('SrTiO3', 5.12)
txt = api.calcXraySLD('SrTiO3', 5.12)
txt = api.calcQToTwoTheta(0.5, 1.5406)        % Q (Å⁻¹), λ (Å)

% Superconductor
txt = api.calcLondonDepth('Nb', 4.2)           % material preset, T (K)
txt = api.calcCriticalFields('Nb', 4.2)

% Optics / Vacuum / Electrochem
txt = api.calcFresnel(1.0, 1.5, 45)           % n1, n2, theta (deg)
txt = api.calcMeanFreePath(1e-4, 300)          % P (Pa), T (K)
txt = api.calcNernst(0.77, 1, 0.01)           % E0 (V), n, Q

% Reflectivity
stack = api.getMultilayerStack()               % cell array of layer structs
mode  = api.getDensityMode()                   % 'sld' or 'density'
api.addLayer('Fe film', 'Fe', 200, 8.024, 5)  % name, formula, t(Å), ρ, σ(Å)

% Favorites / History
api.addFavorite('my calc', 'crystal', 'result text', 'latex')
favs = api.getFavorites()                      % cell array of favorite structs
h    = api.getHistory()                        % cell array of history entries
call = api.getHistoryMatlabCall(1)             % MATLAB call string for row 1
api.copyHistoryRowAsMatlabCode(1)              % copy to clipboard

% Export
api.exportReport('session_report.txt')        % dump history to text file

% Teardown
api.close()
```

### API Method Reference

| Method | Signature | Returns |
|--------|-----------|---------|
| `fig` | property | `uifigure` handle |
| `selectTab` | `(navKey)` | — |
| `getStatus` | `()` | char |
| `close` | `()` | — |
| `convert` | `(value, from, to)` | char (result string) |
| `calcDSpacing` | `(a, h, k, l)` | char (label HTML) |
| `getDResult` | `()` | char |
| `getMismatchResult` | `()` | char |
| `calcPlaneSpacings` | `(a, centering)` | cell array N×6 |
| `calcIntrinsic` | `(materialPreset)` | char |
| `getNiResult` | `()` | char |
| `selectElement` | `(symbol)` | — |
| `getElementDetail` | `()` | cell array of lines |
| `calcNeutronSLD` | `(formula, density)` | char |
| `calcXraySLD` | `(formula, density)` | char |
| `calcQToTwoTheta` | `(Q, lambda)` | char |
| `calcLondonDepth` | `(material, T)` | char |
| `calcCriticalFields` | `(material, T)` | char |
| `calcFresnel` | `(n1, n2, theta)` | char |
| `calcMeanFreePath` | `(P, T)` | char |
| `calcNernst` | `(E0, n, Q)` | char |
| `getMultilayerStack` | `()` | cell array of structs |
| `getDensityMode` | `()` | `'sld'` or `'density'` |
| `addLayer` | `(name, formula, t, rho, sigma)` | — |
| `addFavorite` | `(name, tabName, result, latex)` | — |
| `getFavorites` | `()` | cell array |
| `getHistory` | `()` | cell array |
| `getHistoryMatlabCall` | `(rowIndex)` | char |
| `copyHistoryRowAsMatlabCode` | `(rowIndex)` | char (also copies) |
| `exportReport` | `(filePath)` | — |

---

## Implementation Notes

- All 18 panels are built at startup and stacked in the same `contentGL` grid cell. Visibility toggling (`Visible = 'on/off'`) is used to switch between them — no lazy loading.
- `errText(msg)` wraps error messages in a red HTML span (`<span style="color:#e64040">`) for inline display in result labels.
- `addHistory(description, latex, matlabCall)` appends to `appData.history`, updates the status bar, enables the Copy/Save buttons in the status bar, and calls `appData.api.refreshHistoryTable` to update the History panel live.
- Tab builders register their primary button via `registerPrimaryBtn(navKey, btn)`. The global `WindowKeyPressFcn` fires that button when Enter is pressed.
- Cross-tab hooks are stored in `appData.api` by the *producer* tab and consumed by the *consumer* tab. The API field must exist before the consumer calls it, which is guaranteed since all tabs are built sequentially at startup.
- Scrollable tabs (Crystal, Electrical, Semiconductor, Thin Film, Magnetic, Optics) wrap their content in a `uipanel(..., 'Scrollable', 'on')` to allow content taller than the window.
- The dark theme is applied in bulk via `applyDarkInputTheme` and `applyDarkPanelTheme` after all panels are built.
