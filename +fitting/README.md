# +fitting — Curve & Surface Fitting Package

General-purpose fitting engine for 1D curves, 2D surfaces, reflectometry, and
hysteresis loops. All fitting is done with `fminsearch` (bounded via
penalty/reflection), so no Optimization Toolbox is required. Functions accept
plain `[x, y]` vectors or the toolbox unified data struct. The package powers
three BosonPlotter dialogs — **Curve Fit**, **Surface Fit** (`surfaceFitDialog`),
and **Reflectivity Fit** (`reflFitting`) — and is fully scriptable outside the
GUI.

---

## Quick Start

```matlab
% Fit a Gaussian to an XRD peak
data = parser.importXRDML('scan.xrdml');
x = data.time;
y = data.values(:,1);

cat = fitting.models();
m   = cat(strcmp({cat.name}, 'Gaussian'));
res = fitting.curveFit(x, y, m.fcn, fitting.autoGuess('Gaussian', x, y), ...
        Lower=m.lb, Upper=m.ub);
fprintf('Center = %.4f°,  FWHM = %.4f°,  R² = %.4f\n', ...
        res.params(2), res.params(3)*2.355, res.R2);

% Plot fit with confidence bands
xg    = linspace(min(x), max(x), 500)';
bands = fitting.fitBands(xg, m.fcn, res.params, res.covar, res.nPoints, res.nFree);
figure; hold on
plot(x, y, 'k.')
plot(xg, bands.yFit, 'r-')
fill([xg; flipud(xg)], [bands.ciLo; flipud(bands.ciHi)], 'r', ...
     FaceAlpha=0.2, EdgeColor='none')
```

---

## Curve Fitting Engine

| Function | Description |
|---|---|
| `curveFit` | General-purpose nonlinear 1D fit via fminsearch; returns params, errors, covariance, AIC, chi-squared |
| `fitBands` | Confidence and prediction bands from a `curveFit` result (numerical Jacobian; no Statistics Toolbox) |
| `fitCompare` | Model comparison metrics: adjusted R², AIC, AICc, BIC, F-test for nested models |
| `residualDiagnostics` | Residual quality statistics: Q-Q quantiles, Durbin-Watson, runs test, skewness, kurtosis |

### `curveFit` example

```matlab
% Exponential decay with bounds and fixed offset
m   = cat(strcmp({cat.name}, 'Exponential Decay'));
res = fitting.curveFit(t, M, m.fcn, [1e-3 100 0], ...
        Lower=[0 0 -Inf], Upper=[Inf Inf Inf], Fixed=[false false true]);
disp(res.params)    % [A, tau, C]
disp(res.errors)    % parameter standard errors
```

---

## Model Library

23 built-in models in `models.m`, returned as a struct array by `fitting.models()`.

**Linear / Polynomial:** Linear, Quadratic, Cubic, Poly 4

**Decay / Growth:** Exponential Decay, Stretched Exponential, Bi-exponential Decay,
Exponential Growth, Saturation Growth

**Peak shapes:** Gaussian, Lorentzian, Pseudo-Voigt

**Power / Empirical:** Power Law, Allometric, Logistic, Tanh, Logarithmic, Square Root

**Physics:** Langevin, Curie-Weiss, Bloch T^3/2, Arrhenius, Langmuir

Each entry has `.name`, `.category`, `.equation`, `.fcn`, `.paramNames`,
`.p0`, `.lb`, `.ub`, `.nParams`.

| Function | Description |
|---|---|
| `models` | Return the 23-entry built-in model catalog |
| `autoGuess` | Heuristic initial-parameter estimation from data shape for any catalog model |
| `parseEquation` | Parse a user equation string into a function handle without `eval` (RPN stack machine) |

### `parseEquation` example

```matlab
% Custom user equation entered in the GUI or script
[fcn, names] = fitting.parseEquation('A * exp(-x / tau) + C');
% names = {'A', 'tau', 'C'}
res = fitting.curveFit(x, y, fcn, [1 50 0]);
```

---

## Hysteresis / Magnetometry

| Function | Description |
|---|---|
| `hysteresisModels` | 5-entry model catalog for magnetic hysteresis loop fitting |

**Built-in hysteresis models:** Tanh Hysteresis, Two-Component (F+P), Linear
Background, Approach to Saturation, Langevin + Background.

```matlab
% Fit a ferromagnet + paramagnet hysteresis loop
hcat = fitting.hysteresisModels();
m    = hcat(strcmp({hcat.name}, 'Two-Component (F+P)'));
res  = fitting.curveFit(H, M, m.fcn, m.p0, Lower=m.lb, Upper=m.ub);
fprintf('Ms = %.4f emu,  Hc = %.1f Oe\n', res.params(1), res.params(2));
```

---

## Batch / Global / Tracking

| Function | Description |
|---|---|
| `batchFit` | Fit the same model to every dataset in a cell array; collects a parameter summary table |
| `globalFit` | Simultaneous fit of N datasets with shared vs. per-dataset parameter split |
| `globalCurveFit` | Richer global fitting: per-dataset model structs, named shared-parameter constraints, full covariance |
| `trackPeak` | Follow a single peak across a series (e.g., temperature scan), with adaptive search window |
| `odrFit` | Orthogonal distance regression (Deming): minimises perpendicular residuals when both axes have uncertainty |

### `batchFit` example

```matlab
% Extract decay time constant from 8 temperature scans
m   = cat(strcmp({cat.name}, 'Exponential Decay'));
s   = fitting.batchFit(datasets, m.fcn, m.p0, ...
        Lower=m.lb, Upper=m.ub, ModelName='Exponential Decay', MetaField='temperature');
plot(s.metaValues, s.params(:,2), 'o-');   % tau vs T
xlabel('Temperature (K)');  ylabel('\tau (s)');
```

### `globalCurveFit` example

```matlab
% Three XRD patterns: shared sigma, independent peak center and amplitude
m = fitting.models();
gauss = m(strcmp({m.name}, 'Gaussian'));
c(1).paramName = 'sigma';  c(1).datasets = [1 2 3];
r = fitting.globalCurveFit(datasets, gauss, c);
fprintf('Shared sigma = %.3f deg\n', r.shared(1).value);
```

### `trackPeak` example

```matlab
% Track a Bragg peak at 2θ = 44.8° across a heating series
r = fitting.trackPeak(scans, 44.8, Window=1.0, Shape='lorentzian');
plot(temperatures, r.center, 'o-');   % d-spacing shift vs T
```

### `odrFit` example

```matlab
% Instrument calibration: both x and y have measurement uncertainty
r = fitting.odrFit(xCal, yCal, Lambda=4);   % lambda = sigma_y^2 / sigma_x^2
fprintf('slope = %.4f ± %.4f\n', r.slope, r.slopeErr);
```

---

## Surface Fitting

7 built-in surface models in `surfaceModels.m`.

**Available models:** Plane, Paraboloid, 2D Gaussian, 2D Lorentzian,
2D Pseudo-Voigt, Polynomial 2D, Exponential Decay 2D.

| Function | Description |
|---|---|
| `surfaceFit` | Fit a named or custom 2D model z = f(x,y) to scattered or meshgrid data |
| `surfaceModels` | Return the 7-entry built-in 2D model catalog |
| `surfaceAutoGuess` | Heuristic initial parameter estimation for 2D models |

### `surfaceFit` example

```matlab
% Fit a 2D Gaussian to a diffraction map
[X, Y] = meshgrid(qx, qz);
result  = fitting.surfaceFit(X, Y, intensity, '2D Gaussian');
fprintf('Peak at (%.4f, %.4f) A^-1\n', result.params(2), result.params(4));
fprintf('R^2 = %.4f\n', result.R2);
```

---

## Reflectometry

| Function | Description |
|---|---|
| `parrattRefl` | Specular reflectivity R(Q) via Parratt recursion with Névot-Croce roughness; optional instrument resolution smearing |
| `sldProfile` | Depth-resolved SLD profile from a layer stack with error-function interfacial transitions |
| `splineSLD` | Free-form SLD profile from spline-interpolated knot points (PCHIP / cubic / linear); for graded interfaces and model-independent fitting |
| `profileToLayers` | Convert any (z, SLD) profile into the layer-matrix format expected by `parrattRefl` via microslicing |
| `reflSLDPresets` | Material SLD lookup table (X-ray and neutron) for common substrates, metals, oxides, and polymers |

### `parrattRefl` example

```matlab
% 200 Å Permalloy on Si with roughness
presets = fitting.reflSLDPresets();
py  = presets(strcmp({presets.name}, 'Permalloy'));
si  = presets(strcmp({presets.name}, 'Silicon'));

Q = linspace(0.005, 0.3, 500)';
layers = [ ...
    0,   0,         0, 0;      % air
    200, py.sldN,   0, 5;      % Permalloy film
    0,   si.sldN,   0, 3];     % Si substrate
R = fitting.parrattRefl(Q, layers);
semilogy(Q, R);
xlabel('Q (A^{-1})');  ylabel('Reflectivity');

% Fit to measured data
[z, sld] = fitting.sldProfile(layers);
plot(z, sld * 1e6);   ylabel('SLD (10^{-6} A^{-2})');
```

### Free-form spline SLD (graded interfaces)

For polymer brushes, graded oxides, or any profile not well-described by
a stack of boxes, define the SLD at a few depth knots and let `splineSLD`
fill in the continuous profile. `profileToLayers` then microslices it
into the layer matrix `parrattRefl` consumes.

```matlab
% Polymer brush: graded transition from D2O ambient through brush to Si
zKnots   = [0 50 150 200 250]';
sldKnots = [6.36e-6 5.5e-6 3.0e-6 2.2e-6 2.07e-6]';

[z, sld] = fitting.splineSLD(zKnots, sldKnots, ...
    SldAmbient=6.36e-6, SldSubstrate=2.07e-6, ZRange=[-30 280]);

layers = fitting.profileToLayers(z, sld, ...
    SldAmbient=6.36e-6, SldSubstrate=2.07e-6);

Q = linspace(0.005, 0.25, 200)';
R = fitting.parrattRefl(Q, layers, Roughness=false);  % profile already smooth
```

**When to use which:**
- `sldProfile` (layer-based) — sharp box-like layers with explicit roughness; minimum parameters.
- `splineSLD` + `profileToLayers` — graded / spline-described interfaces; more parameters but model-independent.

PCHIP is the default interpolation because reflectometry profiles often
have sharp layer boundaries between widely-different SLDs and cubic spline
can ring around them. Use `Method='spline'` only when the underlying SLD
is genuinely smooth.
