# +calc/ — Materials Calculator Backend

Backend functions for `DiraCulator`. Organized into subpackages by domain.

## Top-Level Functions

| Function | Description |
|----------|-------------|
| `constants` | Physical constants (h, c, e, kB, NA, ...) |
| `unitConvert` | Unit conversion engine |
| `elementData` | Periodic table data (Z, mass, symbol, name) |
| `importCIF` | CIF crystallographic file parser |
| `crystalCache` | Cache for parsed crystal structures |

## Subpackages

| Package | Functions | Domain |
|---------|-----------|--------|
| `+crystal/` | 13 | d-spacing, plane spacings, lattice, symmetry |
| `+electrical/` | 5 | Resistivity, sheet resistance, conductivity |
| `+semiconductor/` | 12 | Band gap, mobility, doping, carrier concentration |
| `+thinFilm/` | 9 | Thickness, stress, deposition rate, ion beam |
| `+magnetic/` | 4 | Magnetization, susceptibility, demagnetization |
| `+substrates/` | 2 | Substrate properties, lattice mismatch |
| `+xrayNeutron/` | 11 | SLD, Q↔2θ, reflectivity, absorption, form factors |
| `+superconductor/` | 6 | London depth, critical fields, coherence length |
| `+optics/` | 7 | Fresnel equations, Snell's law, penetration depth |
| `+vacuum/` | 6 | Mean free path, pump-down, sputter yield |
| `+electrochemistry/` | 5 | Nernst, Butler-Volmer, Tafel, diffusion |

## GUI

```matlab
DiraCulator              % interactive (18 panels)
api = DiraCulator();     % headless API for testing/scripting
api.convert(1, 'eV', 'nm')
api.calcDSpacing(3.905, 1, 1, 0)
api.calcNeutronSLD('SrTiO3', 5.12)
api.close()
```

### Headless API — Full Method Table

| Method | Arguments | Returns | Panel |
|--------|-----------|---------|-------|
| `fig` | — | `uifigure` handle | — |
| `selectTab` | `navKey` (char) | — | navigation |
| `getStatus` | — | char | status bar |
| `close` | — | — | — |
| `convert` | `value, from, to` | char result string | Unit Converter |
| `calcDSpacing` | `a, h, k, l` | char label HTML | Crystal |
| `getDResult` | — | char | Crystal |
| `getMismatchResult` | — | char | Crystal |
| `calcPlaneSpacings` | `a, centering` | N×6 cell array | Crystal |
| `calcIntrinsic` | `materialPreset` (char) | char | Semiconductor |
| `getNiResult` | — | char | Semiconductor |
| `selectElement` | `symbol` (char) | — | Periodic Table |
| `getElementDetail` | — | cell array of lines | Periodic Table |
| `calcNeutronSLD` | `formula, density` | char | X-ray/Neutron |
| `calcXraySLD` | `formula, density` | char | X-ray/Neutron |
| `calcQToTwoTheta` | `Q (Å⁻¹), lambda (Å)` | char | X-ray/Neutron |
| `calcLondonDepth` | `material (char), T (K)` | char | Superconductor |
| `calcCriticalFields` | `material (char), T (K)` | char | Superconductor |
| `calcFresnel` | `n1, n2, theta (deg)` | char | Optics |
| `calcMeanFreePath` | `P (Pa), T (K)` | char | Vacuum |
| `calcNernst` | `E0 (V), n, Q` | char | Electrochem |
| `getMultilayerStack` | — | cell array of layer structs | Reflectivity |
| `getDensityMode` | — | `'sld'` or `'density'` | Reflectivity |
| `addLayer` | `name, formula, t(Å), rho, sigma(Å)` | — | Reflectivity |
| `addFavorite` | `name, tabName, result, latex` | — | Favorites |
| `getFavorites` | — | cell array of structs | Favorites |
| `getHistory` | — | cell array of entries | History |
| `getHistoryMatlabCall` | `rowIndex` | char | History |
| `copyHistoryRowAsMatlabCode` | `rowIndex` | char (+ clipboard) | History |
| `exportReport` | `filePath` | — | History |

**Layer struct fields:** `.name`, `.formula`, `.thickness` (Å), `.density` (SLD ×10⁻⁶ Å⁻² or g/cm³ per `getDensityMode`), `.roughness` (Å).

**History entry format:** `{timestamp, tabKey, description, latexStr, matlabCall}` — 5-element cell. `matlabCall` is empty for tabs without reproducible single-line calls.

**navKey values:** `unitConverter`, `crystal`, `thinFilm`, `substrates`, `periodicTable`, `electrical`, `semiconductor`, `electrochemistry`, `optics`, `xrayNeutron`, `reflectivity`, `superconductor`, `magnetic`, `thermal`, `diffusion`, `vacuum`, `favorites`, `history`.
