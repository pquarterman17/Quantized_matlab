# Curve & Surface Fitting

This document covers the numerical and statistical methods that power the `+fitting/` package. The package is a self-contained least-squares engine that uses only base MATLAB (no Optimization or Statistics Toolbox), so every formula here also documents an explicit implementation choice.

The primary entry points are `fitting.curveFit` (1D), `fitting.surfaceFit` (2D), `fitting.parrattRefl` (specular reflectivity), `fitting.pawleyRefine` (powder XRD), `fitting.batchFit` / `fitting.globalFit` / `fitting.globalCurveFit` (multi-dataset), and `fitting.mcmcSample` (posterior sampling). Diagnostic and post-processing helpers are `fitting.fitBands`, `fitting.fitCompare`, `fitting.residualDiagnostics`, and `fitting.odrFit`.

---

## Nonlinear Least Squares

### Theory

Given $N$ data points $\{x_i, y_i\}$ with measurement uncertainties $\sigma_i$ and a model $f(x; \mathbf{p})$ with $M$ parameters, the maximum-likelihood estimate of $\mathbf{p}$ under independent Gaussian errors is the minimiser of the chi-squared statistic

$$\chi^2(\mathbf{p}) = \sum_{i=1}^{N} w_i \, \big[y_i - f(x_i; \mathbf{p})\big]^2 ,$$

where the weights $w_i = 1/\sigma_i^2$ encode the per-point variance. When $\sigma_i$ is unknown the toolbox sets $w_i = 1$ and reports a *reduced* chi-squared that absorbs the unknown overall scale:

$$\chi^2_\nu = \frac{\chi^2}{N - M_\text{free}} .$$

A correctly specified model with correct error bars yields $\chi^2_\nu \approx 1$. Values $\gg 1$ mean the model is too restrictive, the error bars are too small, or both; values $\ll 1$ usually mean the error bars are overestimated.

### Levenberg-Marquardt (the textbook choice)

Most production fitting code uses the Levenberg-Marquardt algorithm, which interpolates between Gauss-Newton (small step) and steepest-descent (large step) using a damping parameter $\lambda$:

$$(\mathbf{J}^\top \mathbf{W} \mathbf{J} + \lambda \mathbf{D}) \, \delta\mathbf{p} = \mathbf{J}^\top \mathbf{W} \mathbf{r},$$

where $\mathbf{J} = \partial f / \partial \mathbf{p}$ is the Jacobian, $\mathbf{W} = \mathrm{diag}(w_i)$, $\mathbf{r}$ is the residual vector, and $\mathbf{D}$ is a diagonal scaling. LM is the algorithm in `lsqcurvefit`, `lmfit` (Python), and most commercial packages.

### What this toolbox does instead

To avoid the Optimization Toolbox dependency, `fitting.curveFit` uses MATLAB's built-in `fminsearch` (Nelder-Mead simplex; Lagarias et al. 1998) to minimise $\chi^2$ in the *transformed* parameter space described below. Nelder-Mead is derivative-free, robust to mildly noisy cost surfaces, and converges acceptably for problems with $\lesssim 20$ parameters. For problems with many parameters or tight convergence requirements, switch to a dedicated LM implementation.

**Practical implications of using Nelder-Mead:**

- Convergence is slower than LM by 5-50x in iteration count, but for typical fits with $N \lesssim 10^4$ points and $M \lesssim 10$ parameters the wall time is still fractions of a second.
- The algorithm has no gradient information, so it cannot detect a saddle point as a non-minimum. Always inspect residuals and parameter errors after the fit.
- Tolerance settings (`TolFun`, `TolX`) default to $10^{-12}$ and $10^{-10}$ respectively, tighter than the default Nelder-Mead settings, to compensate for the slower convergence.

### References

- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003), Ch. 8 and 11.
- Press, W.H., Teukolsky, S.A., Vetterling, W.T. & Flannery, B.P., *Numerical Recipes*, 3rd ed. (Cambridge, 2007), Ch. 15.
- Lagarias, J.C., Reeds, J.A., Wright, M.H. & Wright, P.E., "Convergence Properties of the Nelder-Mead Simplex Method in Low Dimensions", *SIAM J. Optim.* **9**, 112-147 (1998).

---

## Bound Constraints

### Theory

Real fits almost always need bounds: amplitudes must be positive, mixing fractions $\eta \in [0, 1]$, decay times $\tau > 0$. `fminsearch` is unbounded, so `fitting.curveFit` and `fitting.surfaceFit` map each bounded parameter to an inner unbounded variable using the following invertible transforms:

| Bounds | Forward $p_\text{free} = T(p)$ | Inverse $p = T^{-1}(p_\text{free})$ |
|---|---|---|
| $p \in (-\infty, +\infty)$ | $p_\text{free} = p$ | $p = p_\text{free}$ |
| $p \in (a, +\infty)$ | $p_\text{free} = \log(p - a)$ | $p = a + e^{p_\text{free}}$ |
| $p \in (-\infty, b)$ | $p_\text{free} = -\log(b - p)$ | $p = b - e^{-p_\text{free}}$ |
| $p \in (a, b)$ | $p_\text{free} = \mathrm{logit}\!\left(\frac{p - a}{b - a}\right)$ | $p = a + \frac{b - a}{1 + e^{-p_\text{free}}}$ |

The optimizer searches on $\mathbb{R}^{M_\text{free}}$ in $p_\text{free}$ space; every cost evaluation maps back through $T^{-1}$ before calling the user model. Parameter standard errors computed in the unbounded space are propagated back through the transform's Jacobian:

$$\sigma_{p_i} = \sigma_{p_\text{free},i} \, \left|\frac{\partial p_i}{\partial p_{\text{free},i}}\right| .$$

### Equality constraints

In addition to bounds, `fitting.curveFit` accepts a `Constraints` cell array of expression strings — e.g. `{'', '2*p1', 'sqrt(p1)'}` says parameter 2 is twice parameter 1 and parameter 3 is $\sqrt{p_1}$. The `fitting.applyConstraints` helper rewrites these expressions to reference only free parameters, parses them with `fitting.parseEquation` (a stack-machine RPN evaluator — no `eval`), and evaluates the constrained slots at every model call. Constrained parameters do not appear in the optimizer state.

### When to use

- **Always** apply physical bounds on amplitudes, widths, and any parameter whose sign is fixed by physics.
- Use `Fixed` (the boolean mask in `fitting.curveFit`) to hold a parameter at its initial value when you know it precisely (e.g., a calibrated wavelength).
- Use `Constraints` for parameter relationships that arise from a physical model (e.g., a Voigt profile where the Lorentzian and Gaussian widths are tied by a calibrated instrument function).

---

## Auto-Guess Heuristics

### Theory

Nonlinear least squares is sensitive to the starting point. A bad initial guess can lead the optimizer into a local minimum or cause divergence. `fitting.autoGuess` and `fitting.surfaceAutoGuess` examine the data to produce a reasonable starting point for each model in the catalog.

The general strategy is to extract a few summary statistics — data range, peak position, half-maximum width, slopes near the endpoints — and translate them into model-specific parameters. Examples:

**Exponential decay** $y = A e^{-x/\tau} + C$:
- $A$ from the data range.
- $\tau$ from the $1/e$-crossing of the normalised data.
- $C$ from the data minimum.

**Gaussian** $y = A \exp\!\left(-(x-\mu)^2/(2\sigma^2)\right)$:
- $A$ from the data maximum, $\mu$ from its location.
- FWHM measured between the half-max crossings, then $\sigma = \mathrm{FWHM} / (2\sqrt{2\ln 2}) \approx \mathrm{FWHM}/2.355$.

**Power law** $y = A x^n + C$:
- Linear regression of $\log y$ vs $\log x$ (positive points only) gives $\log A$ and $n$ directly.

### Width-to-parameter conventions

The width parameters in the catalog use different conventions across peak shapes — a common stumbling block when comparing fits. The auto-guess heuristic accounts for this:

| Model | Width parameter | FWHM relation | Initial seed |
|---|---|---|---|
| Gaussian | $\sigma$ (std dev) | $\mathrm{FWHM} = 2\sqrt{2\ln 2}\,\sigma \approx 2.355\,\sigma$ | $\sigma = \mathrm{FWHM}/2.355$ |
| Lorentzian | $\gamma$ (HWHM) | $\mathrm{FWHM} = 2\gamma$ | $\gamma = \mathrm{FWHM}/2$ |
| Pseudo-Voigt | $w$ (Lorentzian HWHM) | $\mathrm{FWHM} \approx 2w$ | $w = \mathrm{FWHM}/2$ |

Using $\sigma$ for all three would seed Lorentzian and pseudo-Voigt fits with widths roughly 18% too narrow ($\approx 2.355/2 - 1$), which biases or stalls convergence. See `docs/theory/xrd.md` for the full mathematical derivation.

### When to use

- Always try `autoGuess` before hand-tuning $p_0$. If the auto-guess gives a noticeably bad starting fit, look at the data — the heuristic assumes the model is approximately correct.
- For surface fits, `surfaceAutoGuess` uses Vandermonde least-squares for the linear-in-parameters models (Plane, Paraboloid, Polynomial 2D) and weighted-centroid + range estimates for the peak shapes.

### Reference

- Thompson, P., Cox, D.E. & Hastings, J.B., "Rietveld refinement of Debye-Scherrer synchrotron X-ray data from Al$_2$O$_3$", *J. Appl. Cryst.* **20**, 79-83 (1987). (Pseudo-Voigt FWHM conventions.)

---

## Parameter Uncertainties

### Theory

At the best-fit parameters $\hat{\mathbf{p}}$, the curvature of the cost surface determines the parameter covariance matrix. The Hessian $\mathbf{H}_{ij} = \partial^2 \chi^2 / \partial p_i \partial p_j$ evaluated at $\hat{\mathbf{p}}$ gives, for the Gaussian-error model,

$$\mathrm{Cov}(\hat{\mathbf{p}}) = \left(\frac{1}{2}\mathbf{H}\right)^{-1} \cdot \chi^2_\nu .$$

The factor of $\chi^2_\nu$ rescales the covariance to handle the case of unknown error bars: when $w_i = 1$ throughout, the absolute size of $\chi^2$ has no statistical meaning, but $\chi^2_\nu$ acts as the empirical variance estimator. Parameter standard errors are the square root of the diagonal:

$$\sigma_{p_i} = \sqrt{\mathrm{Cov}_{ii}} .$$

`fitting.curveFit` computes the Hessian by central-difference finite differences (step $h = \max(10^{-4}|p|, 10^{-6})$) and falls back to NaN errors if the Hessian is singular or non-positive-definite. The errors are then transformed back to the bounded parameter space via the Jacobian of the bound transform (see "Bound Constraints" above).

### Caveats

- The covariance approximation assumes the cost surface is locally quadratic and the residuals are independent and Gaussian-distributed. Always run `fitting.residualDiagnostics(res.residuals)` to check.
- For strongly correlated parameters (typical in reflectivity: thickness $\times$ SLD trade-offs), the Gaussian approximation can underestimate uncertainties. Use `fitting.mcmcSample` for the full posterior.
- For very small $N$ or very stiff models, the central-difference Hessian step size matters; the toolbox value is conservative but not optimal in every case.

### References

- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis*, 3rd ed. (McGraw-Hill, 2003), Ch. 8 (linear $\chi^2$) and Ch. 11 (curvature matrix).
- Press et al., *Numerical Recipes*, 3rd ed. (Cambridge, 2007), §15.5 (covariance matrix from the Hessian).

---

## Confidence and Prediction Bands

### Theory

`fitting.fitBands` propagates the parameter covariance to the model output. At a grid point $x$, the variance of the predicted mean is

$$\mathrm{Var}\big[\hat{f}(x)\big] = \mathbf{J}(x) \, \mathrm{Cov}(\hat{\mathbf{p}}) \, \mathbf{J}(x)^\top ,$$

where $\mathbf{J}(x) = \partial f / \partial \mathbf{p}$ is computed by forward finite differences. The half-width of the **confidence band** at level $1 - \alpha$ is

$$\Delta_\text{CI}(x) = t_{\alpha/2,\,\nu} \sqrt{\mathrm{Var}\big[\hat{f}(x)\big]} ,$$

where $t_{\alpha/2,\,\nu}$ is the two-tailed Student's $t$ critical value with $\nu = N - M_\text{free}$ degrees of freedom. The **prediction band** adds the residual variance $s^2$ to account for the spread of new observations:

$$\Delta_\text{PI}(x) = t_{\alpha/2,\,\nu} \sqrt{\mathrm{Var}\big[\hat{f}(x)\big] + s^2} .$$

The toolbox computes $t_{\alpha/2,\,\nu}$ without the Statistics Toolbox using the Abramowitz-Stegun rational approximation for the inverse normal followed by a Cornish-Fisher expansion for the $t$-distribution; for $\nu \le 5$ a continued-fraction inversion of the regularised incomplete beta is used directly.

### When to use

- **Confidence band**: where would the model curve fall if we measured the same experiment many times? Use this to compare the fit to a theoretical curve or to other measurements.
- **Prediction band**: where would individual new data points fall? Use this when forecasting or asking whether a new measurement is consistent with the model.

The prediction band is always wider than the confidence band; for $N \gg M$ the difference shrinks because $s^2$ dominates only the constant term.

### References

- Draper, N.R. & Smith, H., *Applied Regression Analysis*, 3rd ed. (Wiley, 1998), §1.4 and Ch. 5.
- Abramowitz, M. & Stegun, I.A., *Handbook of Mathematical Functions* (Dover, 1972), §26.2.23.
- Hill, G.W., "Algorithm 395: Student's $t$-distribution", *Comm. ACM* **13**, 617-619 (1970).

---

## Model Comparison

`fitting.fitCompare` reports several scalar metrics for ranking competing fits to the same dataset.

### Coefficient of determination

$$R^2 = 1 - \frac{\sum_i r_i^2}{\sum_i (y_i - \bar y)^2}$$

$R^2$ rises monotonically with model complexity. Use the **adjusted** form

$$R^2_\text{adj} = 1 - (1 - R^2) \frac{N - 1}{N - p - 1}$$

to penalise extra parameters.

### Information criteria

For Gaussian errors with $\hat{\sigma}^2 = \mathrm{RSS}/N$, the log-likelihood is $\log L = -N/2 \, \log(2\pi\hat{\sigma}^2) - N/2$, giving

$$\mathrm{AIC} = 2p - 2\log L = N \log(\mathrm{RSS}/N) + 2p \;\; (+ \text{const})$$

$$\mathrm{AIC}_c = \mathrm{AIC} + \frac{2 p (p + 1)}{N - p - 1}$$

$$\mathrm{BIC} = N \log(\mathrm{RSS}/N) + p \log N$$

The corrected $\mathrm{AIC}_c$ is required for $N/p \lesssim 40$ to remove finite-sample bias (Hurvich & Tsai 1989). $\mathrm{BIC}$ penalises complexity more aggressively than $\mathrm{AIC}$ for $N \ge 8$ and tends to select simpler models.

**Decision rules (Burnham & Anderson 2002):** $\Delta\mathrm{AIC} < 2$ "weak evidence", $4-7$ "considerable", $> 10$ "decisive". Always compare AIC differences, not absolute values.

### F-test for nested models

When comparing a "full" model (parameters $p$) to a strictly simpler "reference" model (parameters $p_\text{ref} < p$, every parameter of the reference also appears in the full model), the F-statistic

$$F = \frac{(\mathrm{RSS}_\text{ref} - \mathrm{RSS}_\text{full}) / (p - p_\text{ref})}{\mathrm{RSS}_\text{full} / (N - p)}$$

follows the $F(p - p_\text{ref}, \, N - p)$ distribution under the null hypothesis that the additional parameters are zero. A small $p$-value rejects the simpler model in favour of the full one.

### When to use

- Always look at `R2_adj`, `AIC`, and `BIC` together. If they disagree, ask why — usually the model is misspecified or the residuals are not Gaussian.
- Use the F-test only for *nested* models. To compare non-nested models (e.g. Gaussian vs Lorentzian), use information criteria.

### References

- Akaike, H., "A new look at the statistical model identification", *IEEE Trans. Autom. Control* **19**, 716-723 (1974).
- Schwarz, G., "Estimating the dimension of a model", *Ann. Statist.* **6**, 461-464 (1978).
- Burnham, K.P. & Anderson, D.R., *Model Selection and Multimodel Inference*, 2nd ed. (Springer, 2002).
- Hurvich, C.M. & Tsai, C.L., "Regression and time series model selection in small samples", *Biometrika* **76**, 297-307 (1989).

---

## Residual Diagnostics

A fit with high $R^2$ can still be wrong. `fitting.residualDiagnostics` computes statistics designed to surface systematic structure in the residuals.

### Q-Q plot

Sort residuals to produce sample quantiles $r_{(i)}$ and compare against the standard-normal theoretical quantiles using the Blom plotting positions $p_i = (i - 3/8)/(N + 1/4)$. A straight line in the Q-Q plot indicates Gaussian residuals; curvature indicates skew or heavy tails.

### Durbin-Watson statistic

$$\mathrm{DW} = \frac{\sum_{i=2}^{N} (r_i - r_{i-1})^2}{\sum_i r_i^2} \in [0, 4]$$

- $\mathrm{DW} \approx 2$: no first-order autocorrelation (good).
- $\mathrm{DW} < 1.5$: positive autocorrelation — residuals trend together. The model is missing a slow component.
- $\mathrm{DW} > 2.5$: negative autocorrelation — residuals oscillate. The model is over-fit or the data is over-differenced.

Critical values depend on $N$ and the number of regressors (Durbin & Watson 1951); the toolbox flags $\mathrm{DW} \notin [1.5, 2.5]$ for visual attention.

### Wald-Wolfowitz runs test

Count the number of sign-change runs $R$ in the residual sequence. Under random sign assignment with $n_+$ positive and $n_- = N - n_+$ non-positive residuals,

$$\mu_R = \frac{2 n_+ n_-}{N} + 1 ,
\quad
\sigma_R^2 = \frac{2 n_+ n_- (2 n_+ n_- - N)}{N^2 (N - 1)} ,$$

so $Z = (R - \mu_R)/\sigma_R$ is approximately standard normal for $n_+, n_- \gtrsim 10$. Significant $Z$ ($|Z| > 1.96$) means the residual signs cluster non-randomly — the model is missing structure.

### Skewness and excess kurtosis

Third and fourth standardised central moments of the residuals. For Gaussian residuals: skewness $\approx 0$, excess kurtosis $\approx 0$. Heavy tails (excess kurtosis $> 2$) suggest outliers; non-zero skewness suggests asymmetric error distributions and may motivate a transformation of the data.

### References

- Durbin, J. & Watson, G.S., "Testing for serial correlation in least squares regression. II", *Biometrika* **38**, 159-178 (1951).
- Wald, A. & Wolfowitz, J., "On a test whether two samples are from the same population", *Ann. Math. Stat.* **11**, 147-162 (1940).
- Bevington & Robinson, *Data Reduction and Error Analysis*, 3rd ed., Ch. 4.

---

## Global / Shared-Parameter Fitting

### Theory

When the same physical model applies to multiple datasets, but only some parameters can vary across datasets (e.g., temperature changes), a *global* fit constrains the shared parameters to a single value while letting the rest vary per dataset. The cost is the sum of per-dataset weighted residual sums:

$$\chi^2_\text{global}(\mathbf{p}_1, \ldots, \mathbf{p}_K) = \sum_{k=1}^{K} \sum_{i=1}^{N_k} w_{k,i} \, \big[y_{k,i} - f_k(x_{k,i}; \mathbf{p}_k)\big]^2$$

with the constraint that selected components of $\mathbf{p}_k$ are equal across all $k$.

### Implementation

Two functions provide this functionality:

- **`fitting.globalFit(datasets, modelFcn, p0, sharedMask)`** — single model function across all datasets, boolean mask selects which parameters are shared. Simple and fast.
- **`fitting.globalCurveFit(datasets, models, constraints)`** — accepts per-dataset model structs (so different datasets can have *different* models with shared-named parameters), a struct array of constraints `(.paramName, .datasets)` to specify sharing groups, and Greek-name aliases (`sigma` $\leftrightarrow$ $\sigma$) for parameter names.

Internally each builds a "super-vector" of dimension $n_\text{shared} + \sum_k n_\text{free,k}$, runs `fminsearch` once, and reports per-dataset parameter vectors plus global covariance. Errors on the shared parameters are typically smaller than those from independent batch fits because they pool information across all datasets.

### When to use

- Multi-temperature fits where the activation energy is shared but the prefactor varies.
- Multi-loading hysteresis fits where the saturation magnetisation is shared but the coercive field varies.
- Multi-energy XRR or contrast-variation NR where the structural parameters are shared but the SLDs change.
- Always start with `fitting.batchFit` (independent fits per dataset), inspect the parameter trends, and only switch to a global fit when one or more parameters are statistically consistent across datasets.

### Reference

- Beechem, J.M., "Global analysis of biochemical and biophysical data", *Methods Enzymol.* **210**, 37-54 (1992). DOI: [10.1016/0076-6879(92)10004-W](https://doi.org/10.1016/0076-6879(92)10004-W). Canonical introduction to shared-parameter analysis.

---

## Orthogonal Distance Regression

### Theory

Ordinary least squares (OLS) minimises *vertical* residuals $y_i - f(x_i; \mathbf{p})$, implicitly assuming the independent variable $x$ is exact. When both axes have measurement uncertainty — instrument calibration, Arrhenius plots, two-detector comparisons — OLS gives a biased slope. **Orthogonal distance regression (ODR)** minimises the perpendicular distance from each point to the fitted line.

For a linear fit $y = a x + b$, the orthogonal distance from $(x_i, y_i)$ to the line is

$$d_i = \frac{a x_i - y_i + b}{\sqrt{a^2 + 1}} .$$

Minimising $\sum d_i^2$ gives the **Deming estimator**, which generalises to a weight ratio $\lambda = \sigma_y^2 / \sigma_x^2$:

$$\hat a = \frac{S_{yy} - \lambda S_{xx} + \mathrm{sgn}(S_{xy}) \sqrt{(S_{yy} - \lambda S_{xx})^2 + 4\lambda S_{xy}^2}}{2 S_{xy}} ,$$

$$\hat b = \bar y - \hat a \bar x ,$$

where $S_{xx}$, $S_{yy}$, $S_{xy}$ are centered second moments. The limits are:

| $\lambda$ | Method | Assumption |
|---|---|---|
| $\lambda \to \infty$ | OLS | All error in $y$ |
| $\lambda \to 0$ | Inverse OLS | All error in $x$ |
| $\lambda = 1$ | Symmetric ODR | Equal-variance |
| $\lambda = (\bar\sigma_y / \bar\sigma_x)^2$ | Weighted Deming | From measured uncertainties |

`fitting.odrFit` implements the closed-form Deming estimator and uses jackknife resampling for slope and intercept standard errors (no toolbox required).

### When to use

- Both axes from independent measurements: instrument-vs-instrument calibration, M-vs-H hysteresis when $H$ has noticeable uncertainty, $J_c(B)$ when $B$ from a Hall probe has its own scatter.
- Activation-energy plots ($\ln k$ vs $1/T$) where temperature has finite uncertainty.
- Anywhere a "normal" linear fit gives suspiciously different slopes when you swap $x \leftrightarrow y$.

### References

- Deming, W.E., *Statistical Adjustment of Data* (Wiley, 1943).
- Linnet, K., "Necessary sample size for method comparison studies based on regression analysis", *Clin. Chem.* **45**, 882-894 (1999).
- Press et al., *Numerical Recipes*, 3rd ed., §15.3.

---

## MCMC Posterior Sampling

### Theory

For nonlinear models with strongly correlated parameters or non-Gaussian posteriors — common in reflectometry (thickness $\times$ SLD $\times$ roughness trade-offs), peak-shape fits with $\eta$ near 0 or 1, or any fit near a parameter bound — the local Gaussian covariance estimate is unreliable. Markov-chain Monte Carlo (MCMC) draws samples from the full posterior

$$P(\mathbf{p} \mid \text{data}) \propto P(\text{data} \mid \mathbf{p}) \, P(\mathbf{p})$$

without ever computing the Hessian. Marginal distributions and credible intervals come directly from the sample histogram.

### Implementation

`fitting.mcmcSample(logPosterior, initialParams, ...)` is currently a single-chain random-walk Metropolis sampler with Gaussian proposals. The user supplies a function handle `logPosterior(p)` that returns log-likelihood + log-prior (or `-Inf` for out-of-prior parameters), and the sampler runs `NumSteps` iterations with `BurnIn` discarded and `Thin`-th sample retained.

**Acceptance rate:** target 0.2-0.5; tune `StepSize` (Gaussian proposal scale) until you land in this range. Outside this range, mixing is poor and effective sample size collapses.

**Diagnostics:** `result.acceptRate`, `result.diagnostic.ess` (effective sample size per dimension via integrated autocorrelation time). `rHat` (Gelman-Rubin) is reserved for the multi-chain ensemble upgrade.

**Roadmap:** the current scaffold is acceptable for educational use and small ($M < 5$) problems with weak parameter correlations. The production target is the affine-invariant ensemble sampler (Goodman & Weare 2010, popularised as `emcee`), which adapts to the local posterior covariance without hand-tuning step sizes and mixes well even for stiff reflectivity fits.

### When to use

- Reflectivity fits where you suspect a multi-modal posterior (multiple physically distinct stack solutions giving similar $R(Q)$).
- Any fit where the parameter standard errors look unphysical (e.g. negative-going errors, errors larger than the parameter, errors that change drastically with starting point).
- When you need a credible interval rather than a $\pm \sigma$ summary — e.g. for publication of nanoparticle size distributions.

### References

- Goodman, J. & Weare, J., "Ensemble samplers with affine invariance", *Commun. Appl. Math. Comput. Sci.* **5**, 65-80 (2010).
- Foreman-Mackey, D., Hogg, D.W., Lang, D. & Goodman, J., "emcee: the MCMC Hammer", *PASP* **125**, 306-312 (2013). DOI: [10.1086/670067](https://doi.org/10.1086/670067)
- Sivia, D.S. & Skilling, J., *Data Analysis: A Bayesian Tutorial*, 2nd ed. (Oxford, 2006).
- Gelman, A. & Rubin, D.B., "Inference from iterative simulation using multiple sequences", *Statistical Science* **7**, 457-472 (1992). (R-hat convergence diagnostic.)

---

## Reflectivity Fitting

### Parratt recursion

The exact specular reflectivity from a stratified medium is computed by the Parratt recursion (`fitting.parrattRefl`). For $M$ layers labelled top ($j = 1$, incident medium) to bottom ($j = M$, substrate), the perpendicular wavevector inside layer $j$ is

$$k_{z,j} = \sqrt{\left(\frac{Q}{2}\right)^2 - 4\pi \, \rho_j} ,$$

where $\rho_j = \rho'_j + i \rho''_j$ is the complex SLD (real part is scattering, imaginary part is absorption). The Fresnel coefficient at the interface between layers $j-1$ and $j$ is

$$r_{j-1, j} = \frac{k_{z,j-1} - k_{z,j}}{k_{z,j-1} + k_{z,j}} ,$$

modified for interfacial roughness (Nevot-Croce) by

$$r_{j-1, j}^{\text{rough}} = r_{j-1, j} \exp\!\left(-2 k_{z,j-1} k_{z,j} \sigma_j^2 \right) .$$

The recursion runs from the substrate upward:

$$X_{j-1} = \frac{r_{j-1,j} + X_j \, e^{2 i k_{z,j} d_j}}{1 + r_{j-1,j} \, X_j \, e^{2 i k_{z,j} d_j}}$$

with $X_M = 0$ at the substrate. The measured reflectivity is $R(Q) = |X_0|^2$, scaled and shifted by

$$R_\text{meas}(Q) = S \cdot R(Q) + B$$

for instrument scale $S$ and background $B$.

**Resolution smearing.** Real reflectometers have finite Q-resolution $\sigma_Q(Q)$ (typical $\Delta Q / Q = 3$-$6\%$ for laboratory and reactor instruments). Fitting unsmeared $R(Q)$ biases thicknesses (Kiessig fringes get sharper than measured) and roughness (interfaces look sharper). `fitting.parrattRefl` accepts a `Resolution` option (scalar fractional or per-point vector) and Gaussian-convolves the calculated reflectivity on an oversampled grid before returning.

See `docs/theory/reflectometry.md` for the full derivation, the layer-stack convention, and the connection to SLD profiles.

### SLD profile

The real-space dual of the layer stack is computed by `fitting.sldProfile`, which sums error-function transitions across each interface:

$$\rho(z) = \rho_1 + \sum_{j=2}^{M} \frac{\Delta\rho_j}{2}\left[1 + \mathrm{erf}\!\left(\frac{z - z_{j-1}}{\sigma_j \sqrt 2}\right)\right] ,$$

with $\Delta\rho_j = \rho_j - \rho_{j-1}$ and $z_{j-1}$ the cumulative depth to the top of layer $j$. Plot the SLD profile alongside every reflectivity fit to verify the model is physically reasonable (no negative SLD where it shouldn't be, roughness $\ll$ layer thickness, total film thickness consistent with deposition).

### SLD presets

`fitting.reflSLDPresets` returns a struct array of $\sim$30 common materials (substrates, magnetic metals, oxides, polymers, solvents) with X-ray (Cu K$\alpha$) and neutron SLDs, formula, and bulk density. Use it for starting models:

```matlab
p   = fitting.reflSLDPresets();
si  = p(strcmp({p.name}, 'Silicon'));
fe  = p(strcmp({p.name}, 'Iron'));
% 100 A Fe on Si, mild interfacial roughness
layers = [0  0       0  0;
          100 fe.sldN 0  3;
          0  si.sldN  0  3];
```

### When to use

- Specular X-ray or neutron reflectivity from any planar stratified system: thin films, multilayers, polymer brushes, lipid bilayers at liquid interfaces.
- Total film thickness in the range $\sim$10 A to $\sim$5000 A; thicker films give Kiessig fringes too closely spaced for typical instruments to resolve.
- For roughness $\sigma \gtrsim d/3$ the layer model breaks down — use a microslice approach (subdivide each layer into many thin slabs with continuously varying SLD) or fit the SLD profile directly.

### References

- Parratt, L.G., "Surface Studies of Solids by Total Reflection of X-Rays", *Phys. Rev.* **95**, 359-369 (1954). DOI: [10.1103/PhysRev.95.359](https://doi.org/10.1103/PhysRev.95.359)
- Nevot, L. & Croce, P., "Caracterisation des surfaces par reflexion rasante de rayons X", *Rev. Phys. Appl.* **15**, 761-779 (1980).
- Als-Nielsen, J. & McMorrow, D., *Elements of Modern X-ray Physics*, 2nd ed. (Wiley, 2011), Ch. 3.
- Sears, V.F., "Neutron scattering lengths and cross sections", *Neutron News* **3**(3), 26-37 (1992).

---

## Pawley Refinement

### Theory

Pawley refinement (`fitting.pawleyRefine`) extracts unit-cell parameters from a powder XRD pattern *without* requiring a structural model. Each Bragg peak's position is fixed by the cell parameters via the chosen $d$-spacing formula (see `docs/theory/xrd.md`), but the peak *intensities* are fit as free linear parameters. This contrasts with Rietveld refinement, which constrains intensities via atomic positions, thermal parameters, and structure factors.

The cost function is the sum of weighted squared residuals between the observed and model intensities:

$$R_\text{wp} = \sqrt{\frac{\sum_i w_i (y_i^\text{obs} - y_i^\text{calc})^2}{\sum_i w_i (y_i^\text{obs})^2}}$$

with $w_i = 1/\sigma_i^2 \approx 1/y_i^\text{obs}$ for Poisson counting statistics. Rwp is the standard "weighted profile R-factor" used in Rietveld codes; values below $\sim$0.10 indicate a good fit.

### Implementation

The current `fitting.pawleyRefine` is a scaffold:

1. Enumerate symmetry-allowed reflections within `MaxTwoTheta` for the given Bravais centering (P, F, I, A, B, C, R) using `calc.crystal.planeSpacings`.
2. Build a pseudo-Voigt basis of width `ProfileFWHM` for each peak.
3. Solve the linear least-squares problem $\big[\text{basis} \, \big|\, \text{background}\big] \, \mathbf{x} = \mathbf{y}$ for the integrated peak intensities (constrained $\ge 0$) and a linear background.
4. Refine the cell parameters by an adaptive grid search (cubic systems step $a$ only and mirror; tetragonal step $a, c$; lower symmetry steps all three independently).

**Production target:** Levenberg-Marquardt over (cell, profile widths, background) with a Cagliotti $U/V/W$ profile-width model

$$\mathrm{FWHM}^2(2\theta) = U \tan^2\theta + V \tan\theta + W ,$$

extinction handling for screw axes and glide planes (currently only Bravais centering is applied), and full integration with the `+calc/+crystal/` phase database.

### When to use

- You have a single-phase powder pattern and want to refine the lattice parameter without a full structural model.
- You need lattice parameters of a known structure to compute residual strain, thermal expansion coefficients, or to identify a unit-cell phase transition.
- For full structural refinement (occupancies, thermal parameters, preferred orientation), graduate to a dedicated Rietveld code (GSAS-II, FullProf, TOPAS).

### References

- Pawley, G.S., "Unit-cell refinement from powder diffraction scans", *J. Appl. Cryst.* **14**, 357-361 (1981). DOI: [10.1107/S0021889881009618](https://doi.org/10.1107/S0021889881009618)
- Rietveld, H.M., "A profile refinement method for nuclear and magnetic structures", *J. Appl. Cryst.* **2**, 65-71 (1969).
- Cagliotti, G., Paoletti, A. & Ricci, F.P., "Choice of collimators for a crystal spectrometer for neutron diffraction", *Nucl. Instrum.* **3**, 223-228 (1958).
- Larson, A.C. & Von Dreele, R.B., "General Structure Analysis System (GSAS)", *Los Alamos Nat. Lab. Report LAUR* 86-748 (2004).

---

## Hysteresis-Loop Models

`fitting.hysteresisModels` provides a small catalog of empirical models for fitting magnetic $M(H)$ loops:

| Model | Equation | Typical use |
|---|---|---|
| Tanh Hysteresis | $M = M_s \tanh\!\left((H - H_c)/H_w\right)$ | Soft ferromagnet, single-branch fit |
| Two-Component (F+P) | $M = M_s \tanh\!\left((H - H_c)/H_w\right) + \chi H$ | FM film + paramagnetic substrate |
| Linear Background | $M = \chi H + \text{offset}$ | Pure paramagnetic / diamagnetic |
| Approach to Saturation | $M = M_s\!\left(1 - a/H - b/H^2\right) + \chi H$ | High-field $M_s$ extraction |
| Langevin + Background | $M = M_s\, L(\mu H/k_BT) + \chi H$ | Superparamagnetic nanoparticles |

The Langevin function is

$$L(x) = \coth x - \frac{1}{x} ,$$

evaluated with a Taylor expansion ($L(x) \approx x/3 - x^3/45$ for $|x| < 10^{-4}$) to avoid the $0/0$ form near $x = 0$.

The $a/H + b/H^2$ approach-to-saturation form (Akulov 1931) lets you extract $M_s$ from a high-field branch where the loop is reversible, useful when measurement artifacts make low-field data unreliable.

**Caveats.** These tanh-based descriptions are *empirical* — they reproduce the gross loop shape but do not solve the Stoner-Wohlfarth astroid (which has no closed form in general). For the actual physics of single-domain switching see `docs/theory/magnetometry.md`; for critical-state superconductor loops see `docs/theory/superconductivity.md`.

### References

- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed. (Wiley/IEEE, 2009). Ch. 9 (hysteresis), Ch. 11 (superparamagnetism).
- Akulov, N.S., "Zur Theorie der Magnetisierungskurve von Einkristallen", *Z. Phys.* **67**, 794-807 (1931).
- Stoner, E.C. & Wohlfarth, E.P., "A mechanism of magnetic hysteresis in heterogeneous alloys", *Phil. Trans. R. Soc. A* **240**, 599-642 (1948).

---

## Surface (2D) Fitting

`fitting.surfaceFit` and `fitting.surfaceModels` extend the 1D engine to functions $z = f(x, y; \mathbf{p})$. The optimisation, bound transforms, and error propagation are identical to `curveFit`; the cost is

$$\chi^2(\mathbf{p}) = \sum_i \big[z_i - f(x_i, y_i; \mathbf{p})\big]^2$$

over scattered or gridded $(x, y, z)$ data. The catalog includes:

- **Plane**, **Paraboloid**, **Polynomial 2D** — for tilt/curvature subtraction (e.g., AFM topography, sample-mounting tilt in XRD area-detector data).
- **2D Gaussian**, **2D Lorentzian**, **2D Pseudo-Voigt** — for peak fits in reciprocal-space maps (e.g., a single Bragg peak on a $(q_x, q_z)$ map).
- **Exponential Decay 2D** — for separable decay processes.

The auto-guess in `fitting.surfaceAutoGuess` uses a closed-form Vandermonde least-squares for the linear-in-parameters models and weighted-centroid + range estimates for the peak shapes.

### When to use

- Fitting a single peak on a 2D detector image (e.g., a Bragg peak on a Pilatus or Eiger frame). Use `2D Gaussian` or `2D Pseudo-Voigt`.
- Subtracting sample tilt from height-map data before computing rms roughness. Use `Plane` or `Paraboloid`.
- For full 2D crystallographic analysis (powder rings, texture, multiple overlapping peaks), step up to a dedicated tool — the `+fitting/` engine is single-peak.

---

## Peak Tracking Across Scans

`fitting.trackPeak` follows a single peak (specified by an initial 2$\theta$, or any $x$-coordinate) across a series of scans, fitting a local Gaussian or Lorentzian in a window around the current best estimate. With `Follow=true` the search window migrates with the peak from scan to scan, which is essential for steep peak motion (e.g., across a phase transition).

The width-to-FWHM and area conversions match the `+fitting/models.m` conventions:

| Shape | Width parameter | FWHM | Area |
|---|---|---|---|
| Gaussian | $\sigma$ | $2\sqrt{2\ln 2}\,\sigma$ | $A \, \sigma \sqrt{2\pi}$ |
| Lorentzian | $\gamma$ | $2\gamma$ | $A \, \pi \gamma$ |

Successful fits ($R^2 > 0.5$) populate the `result.found` mask; failed fits leave NaN entries so they are easy to filter out downstream.

### When to use

- Temperature-, pressure-, or composition-series XRD where a single peak's $d$-spacing or width is the quantity of interest.
- Time-resolved studies where peak migration is the science.
- For overlapping peaks or pattern-wide changes, switch to `fitting.pawleyRefine` (whole-pattern fit with cell refinement).

---

## References (consolidated)

The canonical references for this package's methods, in approximate order of utility:

- **General fitting.** Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003). The standard reference for chi-squared, error propagation, and the F-test.
- **Numerical methods.** Press, W.H. et al., *Numerical Recipes*, 3rd ed. (Cambridge, 2007). Source of the continued-fraction algorithms for the incomplete beta and gamma functions used in the toolbox's no-Statistics-Toolbox $t$- and $F$-distribution code.
- **Bayesian / MCMC.** Sivia, D.S. & Skilling, J., *Data Analysis: A Bayesian Tutorial*, 2nd ed. (Oxford, 2006). Foreman-Mackey, D. et al., "emcee: the MCMC Hammer", *PASP* **125**, 306 (2013).
- **Reflectivity.** Als-Nielsen, J. & McMorrow, D., *Elements of Modern X-ray Physics*, 2nd ed. (Wiley, 2011). Parratt, L.G., *Phys. Rev.* **95**, 359 (1954). Nevot, L. & Croce, P., *Rev. Phys. Appl.* **15**, 761 (1980).
- **Powder diffraction.** Cullity, B.D. & Stock, S.R., *Elements of X-Ray Diffraction*, 3rd ed. (Prentice Hall, 2001). Pawley, G.S., *J. Appl. Cryst.* **14**, 357 (1981). Rietveld, H.M., *J. Appl. Cryst.* **2**, 65 (1969).
- **Magnetism.** Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed. (Wiley/IEEE, 2009).
- **Model selection.** Burnham, K.P. & Anderson, D.R., *Model Selection and Multimodel Inference*, 2nd ed. (Springer, 2002).
- **ODR.** Deming, W.E., *Statistical Adjustment of Data* (Wiley, 1943). Linnet, K., *Clin. Chem.* **45**, 882 (1999).
- **Global analysis.** Beechem, J.M., *Methods Enzymol.* **210**, 37 (1992).
- **Optimization.** Lagarias, J.C. et al., *SIAM J. Optim.* **9**, 112 (1998). (Nelder-Mead convergence theory; matches MATLAB's `fminsearch`.)
