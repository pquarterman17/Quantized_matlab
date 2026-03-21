# +utilities/ — Data Processing Helpers

General-purpose data manipulation functions. No external toolboxes required.

## Functions

| Function | Description |
|----------|-------------|
| `normalize` | Normalize columns: range / peak / z-score |
| `smoothData` | Moving-average, Gaussian, or Savitzky-Golay smoothing |
| `convertUnits` | Convert between lab units (field, moment, temp, ...) |
| `writeXRDcsv` | Write XRD data to CSV (standard or Origin ASCII format) |
| `estimateBackground` | Polynomial background estimation for XRD/spectroscopy |
| `findPeaksRobust` | Peak detection with prominence filtering (no toolbox) |
| `pseudoVoigt` | Pseudo-Voigt peak shape (eta-weighted Gaussian+Lorentzian) |
| `splitPearsonVII` | Split Pearson VII asymmetric peak shape |
| `derivative` | Numerical derivative (dY/dX, d²Y/dX²) with optional smoothing |
| `cumulativeIntegral` | Cumulative trapezoidal integral (∫Y dx) |
| `logDerivative` | d(log Y)/d(log X) for power-law detection |
| `datasetAlgebra` | Combine datasets: A±B, A×B, A/B, (A-B)/(A+B) |
| `confidenceBand` | Mean±std or median±IQR from N repeat datasets |
| `exportHDF5` | Export data struct to HDF5 format |
| `exportOriginScript` | Generate Origin import script |
| `toOrigin` | Direct Origin connection helper |

## Usage

```matlab
normI  = utilities.normalize(data.values);
smI    = utilities.smoothData(data.values, 'Window', 9);
sgI    = utilities.smoothData(data.values, 'Method', 'savitzky-golay', ...
                              'Window', 7, 'PolyOrder', 3);
[H_T, u] = utilities.convertUnits(data.time, 'Oe', 'T');
dydx   = utilities.derivative(data.time, data.values);
intY   = utilities.cumulativeIntegral(data.time, data.values);
diff   = utilities.datasetAlgebra(dsA, dsB, 'A-B');
band   = utilities.confidenceBand({d1, d2, d3}, 'Method', 'mean');
```
