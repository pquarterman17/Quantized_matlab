# Tutorial: Curve Fitting Workflow

This tutorial walks through the complete curve-fitting workflow using the `+fitting/` package: load data, choose a model, run the fit, inspect residuals, and report the result with parameter uncertainties and confidence bands.

**Research question:** "I measured a peak with a sloping background. How do I extract the peak position, width, and amplitude — with proper error bars and a residual diagnostic?"

The example fits a **Gaussian peak on a linear background** to synthetic data, but the workflow is identical for any model in `fitting.models()` (peak shapes, decays, hysteresis, polynomials) and applies straightforwardly to real measurement data.

See [`docs/theory/fitting.md`](../theory/fitting.md) for the underlying mathematics.

---

## 1. Set up — generate or load data

For a real workflow you would load measurement data with the unified parser:

```matlab
setupToolbox    % run once to add packages to MATLAB path

data = parser.importAuto('myscan.xrdml');
x    = data.time;            % e.g. 2θ in degrees
y    = data.values(:, 1);    % e.g. intensity in counts
```

For this tutorial we generate a noisy synthetic peak so the answers are known:

```matlab
rng(42, 'twister');                        % reproducible noise

% True parameters: A = 5.0, mu = 30.0, sigma = 0.4, slope = 0.05, offset = 1.2
xTrue = linspace(28, 32, 200)';
yTrue = 5.0 * exp(-(xTrue - 30.0).^2 / (2 * 0.4^2)) + 0.05 * xTrue + 1.2;
y     = yTrue + 0.15 * randn(size(xTrue));    % add Gaussian noise (sigma = 0.15)
x     = xTrue;

figure;
plot(x, y, 'k.', x, yTrue, 'r--');
xlabel('2\theta (deg)'); ylabel('Intensity (a.u.)');
legend('Noisy data', 'True curve', 'Location', 'NW');
title('Synthetic peak with linear background');
```

You should see a Gaussian peak centred near $2\theta = 30^\circ$ sitting on a sloped background.

---

## 2. Define the model

A "Gaussian + linear background" model has 5 parameters: amplitude $A$, centre $\mu$, width $\sigma$, slope $m$, and offset $c$:

$$y(x; A, \mu, \sigma, m, c) = A \exp\!\left(-\frac{(x - \mu)^2}{2\sigma^2}\right) + m x + c$$

Define it as a function handle that takes `(x, p)` and returns a column vector `y`:

```matlab
gaussLinBG = @(x, p) p(1) * exp(-(x - p(2)).^2 ./ (2 * p(3).^2)) + p(4)*x + p(5);
paramNames = {'A', 'mu', 'sigma', 'slope', 'offset'};
```

For models in the built-in catalog you can skip this step and grab the function handle plus parameter names from `fitting.models()`:

```matlab
cat   = fitting.models();
gauss = cat(strcmp({cat.name}, 'Gaussian'));   % no background
% then use gauss.fcn, gauss.paramNames, gauss.lb, gauss.ub
```

---

## 3. Initial guess

A good starting point is the difference between converging in 50 iterations and not converging at all. For a peak on a background, eyeball the values:

```matlab
% Inspect the data to estimate starting parameters
[yMax, idxMax] = max(y);
A0    = yMax - min(y);             % amplitude above background
mu0   = x(idxMax);                 % peak centre
sigma0 = (max(x) - min(x)) / 20;   % rough FWHM/2.355 estimate
slope0  = (y(end) - y(1)) / (x(end) - x(1));   % linear background slope
offset0 = mean(y) - slope0 * mean(x);          % background offset

p0 = [A0, mu0, sigma0, slope0, offset0];
fprintf('Initial guess: A=%.2f mu=%.2f sigma=%.2f slope=%.3f offset=%.2f\n', p0);
```

For a Gaussian-only model in the catalog, `fitting.autoGuess` does this automatically — see [`autoGuess.m`](../../+fitting/autoGuess.m) for the heuristic per model.

---

## 4. Set bounds (always)

Real fits need physical bounds. The amplitude and width must be positive; the centre should be inside the scan range; slope and offset are unconstrained:

```matlab
lb = [0,         min(x),  0,    -Inf, -Inf];
ub = [Inf,       max(x),  Inf,  Inf,  Inf];
```

Without bounds the simplex may wander into nonphysical regions (negative widths give imaginary Gaussian arguments) and produce a non-converging cost surface.

---

## 5. Run the fit

`fitting.curveFit` is the main entry point. It returns a struct with parameters, errors, residuals, goodness-of-fit metrics, and the covariance matrix:

```matlab
res = fitting.curveFit(x, y, gaussLinBG, p0, ...
        Lower=lb, Upper=ub);

fprintf('\nFit results (chi^2_red = %.3f, R^2 = %.5f):\n', res.chiSqRed, res.R2);
for k = 1:numel(res.params)
    fprintf('  %-7s = %10.4f  ±  %.4f\n', paramNames{k}, ...
            res.params(k), res.errors(k));
end
```

For the synthetic data above you should see something like:

```
Fit results (chi^2_red = 0.025, R^2 = 0.99427):
  A       =     4.9818  ±  0.0461
  mu      =    30.0024  ±  0.0044
  sigma   =     0.4029  ±  0.0046
  slope   =     0.0504  ±  0.0089
  offset  =     1.2056  ±  0.2691
```

All five fitted values are within $1\sigma$ of the true ones, and the reduced chi-squared is $\sim 0.03$ — small because we used Gaussian noise of $\sigma_y = 0.15$ but did not pass the weights, so the absolute scale is meaningless and only relative comparisons of $\chi^2_\nu$ across competing fits are meaningful here.

**To get a meaningful $\chi^2_\nu \approx 1$** when you know your error bar, pass `Weights = 1./sigma_y.^2`:

```matlab
sig = 0.15 * ones(size(y));            % known measurement uncertainty
res = fitting.curveFit(x, y, gaussLinBG, p0, ...
        Lower=lb, Upper=ub, Weights=1./sig.^2);
fprintf('chi^2_red with weights = %.3f\n', res.chiSqRed);    % ~1
```

---

## 6. Inspect residuals — the most important step

A high $R^2$ does not mean the fit is correct. Residuals must look like white noise; any structure means the model is missing something. Always plot residuals and run `residualDiagnostics`:

```matlab
diag = fitting.residualDiagnostics(res.residuals);

figure;
subplot(2, 1, 1);
plot(x, y, 'k.', x, res.yFit, 'r-', 'LineWidth', 1.2);
xlabel('2\theta (deg)'); ylabel('Intensity');
title('Data + fit');
legend('Data', 'Fit', 'Location', 'NW');

subplot(2, 1, 2);
plot(x, res.residuals, 'b.', [min(x) max(x)], [0 0], 'k--');
xlabel('2\theta (deg)'); ylabel('Residual');
title('Residuals (should look like noise)');

fprintf('\nResidual diagnostics:\n%s\n', diag.summary);
```

A good fit shows:

- Residuals scattered evenly around zero with no visible trend.
- `DW` between 1.5 and 2.5 (no autocorrelation).
- Runs test $p > 0.05$ (no clustering of signs).
- Skewness near 0 (symmetric error distribution).
- Excess kurtosis near 0 (no outliers).

For our synthetic example the diagnostic prints something like:

```
DW = 2.193  [no significant autocorrelation]
Runs test: Z = 0.359, p = 0.7195  [no significant pattern]
Skewness = 0.005  [approximately symmetric]
Excess kurtosis = 0.078  [tail weight near normal]
N = 200  |  nPos = 99  |  nNeg = 101  |  nRuns = 104
```

If `DW` is below 1.5 or the runs test is significant, your model is missing structure — typically a wrong line-shape (e.g. trying Gaussian on a Lorentzian peak) or a missing peak. See [Section 9](#9-troubleshooting) for diagnosis recipes.

### Q-Q plot for normality check

```matlab
figure;
plot(diag.qqX, diag.qqY, 'k.', ...
     diag.qqX, diag.qqX*std(res.residuals), 'r--');
xlabel('Theoretical normal quantile');
ylabel('Sample residual quantile');
title('Q-Q plot — should be a straight line for Gaussian residuals');
```

Curvature in the Q-Q plot indicates skew (S-curve = asymmetric errors) or heavy tails (corners turn outward = outliers).

---

## 7. Confidence bands

The parameter standard errors describe how well each parameter is constrained. `fitting.fitBands` propagates this through the Jacobian to give **confidence** (uncertainty in the mean prediction) and **prediction** (where individual new measurements would fall) bands:

```matlab
xGrid = linspace(min(x), max(x), 400)';
bands = fitting.fitBands(xGrid, gaussLinBG, ...
            res.params, res.covar, res.nPoints, res.nFree, Level=0.95);

figure; hold on
% Prediction band (light)
fill([xGrid; flipud(xGrid)], [bands.piLo; flipud(bands.piHi)], ...
     [1 0.85 0.85], EdgeColor='none', DisplayName='95% prediction');
% Confidence band (darker)
fill([xGrid; flipud(xGrid)], [bands.ciLo; flipud(bands.ciHi)], ...
     [1 0.5 0.5], EdgeColor='none', DisplayName='95% confidence');
% Data + fit
plot(x, y, 'k.', xGrid, bands.yFit, 'r-', 'LineWidth', 1.5);
xlabel('2\theta (deg)'); ylabel('Intensity');
legend('Location', 'NW');
title('Fit with 95% bands');
```

Most data points should fall inside the prediction band; if more than $\sim$5% lie outside, your error bars are underestimated or your model is wrong.

---

## 8. Compare alternative models

Often you have more than one candidate model. Use information criteria for non-nested models and the F-test for nested models:

```matlab
% Alternative: Lorentzian + linear background (nested? no — different shape)
lorentzLinBG = @(x, p) p(1) ./ (1 + ((x - p(2))./p(3)).^2) + p(4)*x + p(5);
res2 = fitting.curveFit(x, y, lorentzLinBG, p0, Lower=lb, Upper=ub);

m1 = fitting.fitCompare(y, res.residuals,  res.nFree);
m2 = fitting.fitCompare(y, res2.residuals, res2.nFree);

fprintf('\n              Gaussian   Lorentzian\n');
fprintf('  R^2_adj  : %10.5f  %10.5f\n', m1.adjR2, m2.adjR2);
fprintf('  AIC      : %10.2f  %10.2f   (lower is better)\n', m1.aic, m2.aic);
fprintf('  BIC      : %10.2f  %10.2f\n', m1.bic, m2.bic);
fprintf('  Delta AIC: %10.2f                \n', m2.aic - m1.aic);
```

For our synthetic Gaussian data the Gaussian wins decisively (Delta-AIC > 10). For a real peak you might need to try several shapes — pseudo-Voigt is usually the best general-purpose pick because it interpolates between Gaussian and Lorentzian via the mixing parameter $\eta$.

For **nested** comparisons (e.g. linear vs quadratic background), use the F-test:

```matlab
% Nested test: does adding a quadratic background term improve the fit?
gaussQuadBG = @(x, p) p(1)*exp(-(x-p(2)).^2./(2*p(3).^2)) + p(4)*x.^2 + p(5)*x + p(6);
p0Q = [p0(1:3), 0, p0(4), p0(5)];
lbQ = [lb(1:3), -Inf, -Inf, -Inf];  ubQ = [ub(1:3), Inf, Inf, Inf];
res3 = fitting.curveFit(x, y, gaussQuadBG, p0Q, Lower=lbQ, Upper=ubQ);

mTest = fitting.fitCompare(y, res3.residuals, res3.nFree, ...
            ResidRef=res.residuals, NParamsRef=res.nFree);
fprintf('\nF-test (linear vs quadratic background):\n');
fprintf('  F(%d, %d) = %.3f,  p = %.4f\n', ...
        res3.nFree - res.nFree, res3.nPoints - res3.nFree, ...
        mTest.fStat, mTest.fPvalue);
```

If $p < 0.05$ the quadratic term is justified; otherwise stick with the simpler linear background.

---

## 9. Troubleshooting

### "The fit doesn't converge"

**Symptom:** `res.exitFlag = 0` or the parameters are nonsense (e.g. $\sigma$ much larger than the scan range).

**Fixes, in order:**

1. **Bad starting point.** Plot `gaussLinBG(x, p0)` overlaid on the data. If the initial curve is wildly off, `fminsearch` has no chance. Tighten `p0` by inspection.
2. **Missing or wrong bounds.** Without `Lower=[0 -Inf 0 ...]` for a Gaussian, the optimizer can wander to negative widths.
3. **Increase `MaxIter`.** Default is `5000 * nFree`; for a 5-parameter fit that is 25,000 — usually enough but pathological starting points may need more.
4. **Reparameterise.** A common issue is fitting $\log(\tau)$ instead of $\tau$ when $\tau$ spans orders of magnitude. The bound transform handles this internally for one-sided bounds, but a manual log reparameterisation often helps for unconstrained cases.

### "$\chi^2_\nu$ is much greater than 1"

The model is too restrictive, the error bars are too small, or there are outliers. Look at residuals — if they show systematic structure (sine wave, bowl shape, asymmetric tails), add a missing component. If they look random but large, your `Weights` are over-confident.

### "$\chi^2_\nu$ is much less than 1"

The error bars are over-estimated, or you're over-fitting (too many parameters). Try a simpler model and use `fitCompare` to check.

### "Errors are NaN"

The Hessian was singular. Causes:

- The fit converged to a parameter at its bound — relax the bound or remove it.
- Two parameters are perfectly correlated (e.g. $A$ and $\sigma$ in a Gaussian when only the peak area $A \cdot \sigma$ is constrained). Reparameterise to fit the constrained quantity directly.
- Too few data points relative to parameters ($N - M_\text{free} \le 0$).

### "Residuals show oscillations near a sharp feature"

Your model has the wrong line shape. Try `Lorentzian` instead of `Gaussian` (or vice versa), or `Pseudo-Voigt` to let the optimizer pick the mixing.

### "Bands look fine but errors disagree with replicate measurements"

The covariance from one fit assumes Gaussian residuals and a quadratic cost surface. For strongly nonlinear models or correlated parameters, switch to `fitting.mcmcSample` for the full posterior.

---

## 10. Reporting the result

For publication, report:

1. **The model equation** with explicit parameter symbols.
2. **Best-fit values with $1\sigma$ uncertainties.** Use significant-figure rounding consistent with the error: e.g. `mu = 30.002 ± 0.004` (not `30.00237 ± 0.00442`).
3. **Goodness-of-fit summary.** R$^2$, $\chi^2_\nu$ (if you used real weights), and the residual diagnostics ("Durbin-Watson 2.19, runs test p = 0.72").
4. **A residual plot** — small inset is plenty.
5. **The bandwidth.** "95% confidence band" or "1$\sigma$ prediction interval".

Example reporting paragraph:

> The peak at $2\theta = 30^\circ$ was fitted with a Gaussian on a linear background, $y = A \exp[-(x - \mu)^2/(2\sigma^2)] + m x + c$. Best-fit parameters were $A = 4.98 \pm 0.05$, $\mu = 30.002 \pm 0.004^\circ$, $\sigma = 0.403 \pm 0.005^\circ$ (FWHM $= 0.949 \pm 0.011^\circ$), $m = 0.050 \pm 0.009$ counts/deg, $c = 1.21 \pm 0.27$ counts ($R^2 = 0.994$, Durbin-Watson 2.19). Residuals showed no structure; the Gaussian model was preferred over Lorentzian by $\Delta \mathrm{AIC} = 18$.

The FWHM reported above uses the conversion $\mathrm{FWHM} = 2\sqrt{2 \ln 2}\, \sigma \approx 2.355\,\sigma$, with the error propagated through the same factor.

---

## 11. Going further

| If you need to... | Use |
|---|---|
| Fit the same model to many datasets and tabulate parameter trends | [`fitting.batchFit`](../../+fitting/batchFit.m) |
| Share parameters across datasets in a single global optimisation | [`fitting.globalCurveFit`](../../+fitting/globalCurveFit.m) or [`fitting.globalFit`](../../+fitting/globalFit.m) |
| Track a peak's position across a series of scans | [`fitting.trackPeak`](../../+fitting/trackPeak.m) |
| Fit when both x and y have measurement uncertainty | [`fitting.odrFit`](../../+fitting/odrFit.m) |
| Write your own model equation as a string instead of `@(x,p)` | [`fitting.parseEquation`](../../+fitting/parseEquation.m) — no `eval` |
| Fit a 2D surface $z = f(x, y)$ | [`fitting.surfaceFit`](../../+fitting/surfaceFit.m) |
| Fit specular X-ray or neutron reflectivity | [`fitting.parrattRefl`](../../+fitting/parrattRefl.m) |
| Fit a hysteresis loop with shared $M_s$, free $H_c$ across temperatures | `fitting.globalCurveFit` with `fitting.hysteresisModels` |
| Get a posterior distribution rather than $\pm \sigma$ | [`fitting.mcmcSample`](../../+fitting/mcmcSample.m) |

The same load-model-fit-diagnose-report workflow applies to all of them; only the model and the data shape change.

---

## 12. References

- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003). Ch. 8 and 11.
- Press, W.H., Teukolsky, S.A., Vetterling, W.T. & Flannery, B.P., *Numerical Recipes*, 3rd ed. (Cambridge, 2007). Ch. 15.
- Burnham, K.P. & Anderson, D.R., *Model Selection and Multimodel Inference*, 2nd ed. (Springer, 2002).
- Sivia, D.S. & Skilling, J., *Data Analysis: A Bayesian Tutorial*, 2nd ed. (Oxford, 2006).

For derivations of every formula behind the toolbox calls, see [`docs/theory/fitting.md`](../theory/fitting.md).
