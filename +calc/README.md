# +calc/ — Materials Calculator Backend

Backend functions for `materialsCalcGUI`. Organized into subpackages by domain.

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
materialsCalcGUI              % interactive (13 tabs)
api = materialsCalcGUI();     % headless API for testing/scripting
api.convert(1, 'eV', 'nm')
api.calcDSpacing(3.905, 1, 1, 0)
api.calcNeutronSLD('SrTiO3', 5.12)
api.close()
```
