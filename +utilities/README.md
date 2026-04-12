# +utilities/ — Data Processing Helpers

General-purpose data manipulation functions. No external toolboxes required.

---

## Functions

### Signal Smoothing and Normalization

| Function | Description |
|----------|-------------|
| `normalize(y)` | Normalize columns: range, peak, or z-score |
| `smoothData(y)` | Moving-average, Gaussian, or Savitzky-Golay smoothing |
| `derivative(x, y)` | Numerical first or second derivative; optional pre-smoothing |
| `logDerivative(x, y)` | d(log Y)/d(log X) for power-law analysis |
| `cumulativeIntegral(x, y)` | Cumulative trapezoidal integral (∫Y dx) |

#### Example
```matlab
normI = utilities.normalize(data.values, Method='range');
smI   = utilities.smoothData(data.values, Method='gaussian', Window=9);
sgI   = utilities.smoothData(data.values, Method='savitzky-golay', Window=7, PolyOrder=3);
dydx  = utilities.derivative(data.time, data.values);
intY  = utilities.cumulativeIntegral(data.time, data.values);
```

---

### Baseline Estimation

| Function | Description |
|----------|-------------|
| `baselineALS(y)` | Asymmetric Least Squares baseline (iterative weighted regression) |
| `baselineModPoly(y)` | Modified polynomial baseline (iteratively removes peak-affected points) |
| `baselineRollingBall(y)` | Rolling ball baseline (morphological minimum-filter approach) |
| `estimateBackground(x, y)` | SNIP peak-clipping algorithm for background estimation |

#### Example
```matlab
[bl, ~] = utilities.baselineALS(data.values, Lambda=1e5, P=0.01);
[bl, ~] = utilities.baselineModPoly(data.values, Degree=4);
[bl, ~] = utilities.baselineRollingBall(data.values, BallRadius=50);
corrected = data.values - bl;
```

---

### Statistics

| Function | Description |
|----------|-------------|
| `descriptiveStats(x)` | Mean, median, std, min, max, skewness, kurtosis |
| `tTest(x, y)` | One-sample, two-sample, or paired t-test (no Statistics Toolbox) |
| `linRegress(x, y)` | Linear regression with slope, intercept, R², confidence intervals |
| `confidenceBand(datasets)` | Mean ± std or median ± IQR across N repeat datasets |
| `anova1(groups)` | One-way ANOVA with F-statistic and p-value (no Statistics Toolbox) |
| `pcaAnalysis(X)` | Principal component analysis via SVD (no Statistics Toolbox) |

#### Example
```matlab
stats  = utilities.descriptiveStats(data.values(:,1));
tRes   = utilities.tTest(groupA, groupB, Paired=false);
lrRes  = utilities.linRegress(data.time, data.values(:,1));
band   = utilities.confidenceBand({d1, d2, d3}, Method='mean');
anovaR = utilities.anova1({groupA, groupB, groupC});
pcaR   = utilities.pcaAnalysis(X, NumComponents=3);
```

---

### Error Propagation

| Function | Description |
|----------|-------------|
| `errorAdd(a, da, b, db)` | Propagated uncertainty for addition/subtraction: σ = √(da²+db²) |
| `errorMul(a, da, b, db)` | Propagated uncertainty for multiplication |
| `errorDiv(a, da, b, db)` | Propagated uncertainty for division |
| `errorFunc(func, a, da)` | Propagated uncertainty for a single-variable function via numeric derivative |
| `errorProp(func, values, errors)` | General multi-variable uncertainty propagation via partial derivatives |

#### Example
```matlab
[val, err] = utilities.errorAdd(m1, dm1, m2, dm2);
[val, err] = utilities.errorDiv(signal, dSignal, ref, dRef);
[val, err] = utilities.errorFunc(@log, x, dx);

% General: f(x,y) = x*sin(y)
[val, err] = utilities.errorProp(@(v) v(1)*sin(v(2)), [x y], [dx dy]);
```

---

### Signal Processing

| Function | Description |
|----------|-------------|
| `fftFilter(xData, yData)` | Apply frequency-domain filters (low-pass, high-pass, band-pass, notch) |
| `fftSpectral(xData, yData)` | Comprehensive spectral analysis: FFT, Welch PSD, windowing |
| `crossCorrelation(x, y)` | Normalized cross-correlation between two signals via FFT; returns lag and peak shift |

#### Example
```matlab
filtered = utilities.fftFilter(data.time, data.values, Type='lowpass', Cutoff=0.1);
spec     = utilities.fftSpectral(data.time, data.values, Window='hann');
xcorr    = utilities.crossCorrelation(sig1, sig2);
fprintf('Peak lag: %.4f\n', xcorr.peakLag);
```

---

### Resampling and Interpolation

| Function | Description |
|----------|-------------|
| `resampleData(dataIn)` | Resample a data struct onto a new x-grid (linear, cubic, or PCHIP) |
| `interpolate2D(x, y, z, xq, yq)` | Interpolate scattered or gridded 2D data at query points |
| `regrid2D(x, y, z)` | Resample scattered 2D data onto a regular Cartesian grid |

#### Example
```matlab
% Resample to uniform 0.01° step
dataOut = utilities.resampleData(data, XGrid=(20:0.01:80)', Method='pchip');

% Regrid a 2D map to 200×200 uniform grid
[Xq, Yq, Zq] = utilities.regrid2D(mapX, mapY, mapZ, GridSize=[200 200]);
```

---

### Peak Shapes

| Function | Description |
|----------|-------------|
| `pseudoVoigt(x, x0, fwhm, H, eta, bg)` | Pseudo-Voigt peak shape (eta-weighted Gaussian + Lorentzian) |
| `splitPearsonVII(x, params)` | Asymmetric split Pearson VII peak profile for XRD fitting |
| `findPeaksRobust(x, y)` | Peak detection with adaptive local noise and prominence filtering |
| `hysteresisAnalysis(H, M)` | Extract coercive field, remanence, and saturation from a hysteresis loop |

#### Example
```matlab
% Evaluate a pseudo-Voigt peak centred at 44.5° with FWHM 0.3°
y = utilities.pseudoVoigt(twoTheta, 44.5, 0.3, 1000, 0.5, 0);

% Find peaks above a prominence threshold
[peaks, bgEst] = utilities.findPeaksRobust(data.time, data.values, MinProminence=50);

% Hysteresis parameters
loop = utilities.hysteresisAnalysis(data.time, data.values(:,1));
fprintf('Hc = %.1f Oe, Mr = %.4f emu\n', loop.Hc, loop.Mr);
```

---

### Unit Conversion

| Function | Description |
|----------|-------------|
| `convertUnits(value, fromUnit, toUnit)` | Convert between common lab units (field, moment, temperature, pressure, …) |
| `convertMagUnits(xIn, yIn)` | Convert magnetometry field and moment arrays between unit systems |

#### Example
```matlab
[H_T, unit] = utilities.convertUnits(1000, 'Oe', 'T');  % → 0.1 T
[Hout, Mout, xU, yU, ~] = utilities.convertMagUnits(data.time, data.values(:,1), ...
    XUnit='Oe', YUnit='emu', XUnitOut='T', YUnitOut='A/m');
```

---

### Magnetometry Analysis

| Function | Description |
|----------|-------------|
| `hysteresisAnalysis(H, M)` | Extract Hc, Mr, Ms, and loop area from a magnetic hysteresis loop |
| `convertMagUnits(xIn, yIn)` | Convert magnetometry field and moment arrays between unit systems |

#### convertMagUnits

Converts field (x) and moment (y) arrays between supported unit systems without mutating the input data. If a conversion requires sample mass or volume but those are not supplied (or are zero), the function returns the input unchanged and populates the fifth output `warnMsg` with a human-readable explanation.

**Supported field units:** `'Oe'`, `'T'`, `'mT'`, `'A/m'`

**Supported moment units:** `'emu'`, `'A·m²'`, `'emu/g'`, `'emu/cm³'`, `'kA/m'`

```matlab
% Load a VSM hysteresis loop (field in Oe, moment in emu)
data = parser.importQDVSM('loop.dat', XAxis='field', YAxis='moment');
H = data.time;
M = data.values(:,1);

% Convert field from Oe to T (50,000 Oe → 5 T)
[H_T, M_emu, xU, yU] = utilities.convertMagUnits(H, M, ...
    'FromField', 'Oe', 'ToField', 'T');
fprintf('H range: %.2f to %.2f %s\n', min(H_T), max(H_T), xU);

% Convert moment to emu/g using sample mass 12.5 mg
[~, M_g, ~, yU] = utilities.convertMagUnits(H, M, ...
    'ToMoment', 'emu/g', 'SampleMass', 0.0125);
fprintf('Ms ≈ %.2f %s\n', max(M_g), yU);

% Convert moment to kA/m using sample volume 0.06 cm³
[~, M_kAm, ~, yU, warn] = utilities.convertMagUnits(H, M, ...
    'ToMoment', 'kA/m', 'SampleVolume', 0.06);
if ~isempty(warn)
    warning(warn);   % surface the reason if conversion was skipped
end

% No-op: missing volume → returns original emu, populates warnMsg
[~, M_safe, ~, yU_safe, w] = utilities.convertMagUnits(H, M, ...
    'ToMoment', 'emu/cm³', 'SampleVolume', 0);
% M_safe == M, yU_safe == 'emu', w contains the reason string
```

---

### Dataset Operations

| Function | Description |
|----------|-------------|
| `datasetAlgebra(dsA, dsB, operation)` | Combine two data structs: `A-B`, `A+B`, `A*B`, `A/B`, `(A-B)/(A+B)` |
| `confidenceBand(datasets)` | Compute mean ± spread envelope from multiple repeat datasets |

#### Example
```matlab
diff   = utilities.datasetAlgebra(dsA, dsB, 'A-B');
asym   = utilities.datasetAlgebra(dsPlus, dsMinus, '(A-B)/(A+B)');
band   = utilities.confidenceBand({d1, d2, d3}, Method='std');
```

---

### Export

| Function | Description |
|----------|-------------|
| `exportHDF5(data, filepath)` | Export a unified data struct to a self-describing HDF5 file |
| `exportOriginScript(data, scriptPath)` | Generate an Origin LabTalk `.ogs` import script |
| `toOrigin(data)` | Send a data struct to OriginPro directly via COM automation |
| `writeXRDcsv(data, outputPath)` | Write XRD data struct to CSV with optional metadata header |

#### Example
```matlab
utilities.exportHDF5(data, 'results.h5');
utilities.writeXRDcsv(data, 'scan.csv', Format='standard');
utilities.toOrigin(data, BookName='VSM_data');
```

---

### Logging

| Function | Description |
|----------|-------------|
| `logError(title, msg, ME)` | Append a structured error entry to `gui_bug_log.txt` at the toolbox root |

#### Example
```matlab
try
    result = someOperation();
catch ME
    utilities.logError('Parser error', 'importQDVSM failed on file', ME);
end
```
