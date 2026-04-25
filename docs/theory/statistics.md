# Statistics

This document covers the general-purpose statistical utilities in the `+utilities/` package: descriptive summaries, hypothesis tests (t, ANOVA), ordinary least squares regression, principal component analysis, confidence/prediction bands, and linearised error propagation. These tools sit alongside — but are conceptually separate from — the curve-fitting machinery in `+fitting/`.

The `docs/theory/fitting.md` companion already covers the *model-fit* analogues of several topics here (parameter uncertainties from the covariance matrix, AIC/BIC/F-test for nested model comparison, residual diagnostics including Q-Q plots, Durbin-Watson, runs test, and skewness/kurtosis-of-residuals, plus confidence and prediction bands in the nonlinear-fit context). This document covers the *general-purpose* utilities a researcher reaches for outside the curve-fit context — sanity-checking a vector of measurements, comparing groups, doing a quick linear regression, reducing dimensionality, or propagating measurement uncertainties through a derived quantity.

All routines are implemented in base MATLAB without the Statistics Toolbox. Probabilities are reported in $[0, 1]$; significance levels $\alpha$ default to $0.05$ throughout. Where a critical value or $p$-value requires the Student's $t$-, $F$-, or normal distribution, the toolbox uses Numerical-Recipes-style continued-fraction inversions of the regularised incomplete beta and gamma functions (the same routines used by `fitting.fitBands`).

---

## Descriptive Statistics

### Theory

Given $N$ samples $\{x_i\}$ drawn from an unknown distribution, the standard summary quantities are:

**Sample mean** (arithmetic average):

$$\bar x = \frac{1}{N} \sum_{i=1}^{N} x_i .$$

**Sample variance** (Bessel-corrected, unbiased estimator of the population variance):

$$s^2 = \frac{1}{N - 1} \sum_{i=1}^{N} (x_i - \bar x)^2 .$$

The $N - 1$ denominator (rather than $N$) corrects for the loss of one degree of freedom in estimating the mean — using $N$ would systematically underestimate the population variance. The square root $s$ is the **sample standard deviation**.

**Standard error of the mean**, the uncertainty on $\bar x$ as an estimator of the population mean:

$$\mathrm{SEM} = \frac{s}{\sqrt N} .$$

This is the quantity to report when quoting "mean $\pm$ uncertainty" for a measured quantity. The standard deviation $s$ describes the *spread of the data*; the SEM describes the *uncertainty of the mean*.

**Median** is the 50th percentile — the value with half the data above and half below. For even $N$ the median is the average of the two middle values.

**Interquartile range** $\mathrm{IQR} = q_{0.75} - q_{0.25}$ is the spread of the central half of the data. The IQR is robust against outliers that would inflate $s$, and is the recommended scale measure when the distribution is heavy-tailed or contains spurious values. The toolbox computes quartiles by linear interpolation on the sorted sample, matching the convention of MATLAB's `quantile` for compatibility.

### Higher moments

**Skewness** (Fisher's $g_1$) measures asymmetry:

$$g_1 = \frac{1}{N} \sum_i \left(\frac{x_i - \bar x}{s}\right)^3 .$$

A symmetric distribution has $g_1 = 0$; positive skew means a long right tail (e.g. log-normal contaminants), negative skew a long left tail. For a Gaussian, $|g_1| \lesssim \sqrt{6/N}$ at the $1\sigma$ level — anything larger is suggestive of non-normality.

**Excess kurtosis** ($g_2$) measures tail heaviness *relative to a Gaussian*:

$$g_2 = \frac{1}{N} \sum_i \left(\frac{x_i - \bar x}{s}\right)^4 - 3 .$$

The constant $-3$ is what makes this *excess* kurtosis: a Gaussian has $g_2 = 0$, a heavy-tailed distribution (e.g. a $t$-distribution with low df, or data with outliers) has $g_2 > 0$, a "platykurtic" distribution (uniform, bimodal) has $g_2 < 0$. Strongly positive $g_2$ ($> 2$) is a robust signal that outliers are present.

### Worked example

A coercivity measurement repeated $N = 12$ times on the same sample yields (in Oe): $58.2,\ 61.4,\ 60.1,\ 59.8,\ 62.0,\ 60.5,\ 58.9,\ 61.1,\ 59.4,\ 60.7,\ 59.0,\ 60.3$.

```matlab
s = utilities.descriptiveStats(Hc);
% s.mean   = 60.12 Oe
% s.std    = 1.13  Oe       (sample spread)
% s.sem    = 0.327 Oe       (uncertainty on the mean)
% s.median = 60.20 Oe       (close to mean → no skew)
% s.iqr    = 1.55  Oe
% s.skewness ≈ -0.10        (effectively symmetric)
% s.kurtosis ≈ -0.74        (mildly platykurtic, no outliers)
```

Reportable: $H_c = 60.12 \pm 0.33$ Oe (mean $\pm$ SEM, $N = 12$).

### When to use

- **Always run `descriptiveStats` before any modelling step.** The mean/median agreement, the spread, the skewness, and the kurtosis together flag outliers, asymmetry, or wildly non-Gaussian data that would invalidate downstream parametric tests.
- Use the **median + IQR** in preference to mean $\pm$ std when reporting a single-number summary of skewed or heavy-tailed data.
- Use the **SEM** (not the std) when reporting uncertainty on a mean of repeated measurements.

### References

- Casella, G. & Berger, R.L., *Statistical Inference*, 2nd ed. (Duxbury/Cengage, 2002), §1-3.
- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003), Ch. 1-2.

---

## Hypothesis Testing — Student's t-test

### Theory — three flavours

The $t$-test asks whether an observed mean (or pair of means) is consistent with a null hypothesis $H_0$ given the sampling noise. Three forms are supported by `utilities.tTest`.

**One-sample:** test whether a single sample's mean equals a hypothesised $\mu_0$.

$$t = \frac{\bar x - \mu_0}{s / \sqrt N}, \qquad \mathrm{df} = N - 1 .$$

**Two-sample independent (unequal variances, Welch).** Two samples of sizes $N_1, N_2$ with means $\bar x_1, \bar x_2$ and variances $s_1^2, s_2^2$. The unequal-variance Welch form is the default because it remains valid when $s_1 \ne s_2$:

$$t = \frac{\bar x_1 - \bar x_2}{\sqrt{s_1^2/N_1 + s_2^2/N_2}} ,$$

with the Welch-Satterthwaite approximation for the degrees of freedom

$$\mathrm{df} = \frac{(s_1^2/N_1 + s_2^2/N_2)^2}{(s_1^2/N_1)^2/(N_1 - 1) + (s_2^2/N_2)^2/(N_2 - 1)} .$$

The pooled-variance form ($\mathrm{df} = N_1 + N_2 - 2$, equal-variance assumption) is available when the variances are known to match; in practice Welch is safer and only fractionally more conservative.

**Paired:** when each observation in sample 1 has a natural partner in sample 2 (before/after, sample-with-A vs same-sample-with-B), test the differences $d_i = x_{1,i} - x_{2,i}$ as a one-sample test against $\mu_0 = 0$. Pairing removes between-subject variability and is far more sensitive than the unpaired test when the pairing is meaningful.

The $p$-value is the two-tailed area under the Student's $t$ density beyond $|t|$:

$$p = 2 \int_{|t|}^{\infty} f_t(\tau; \mathrm{df}) \, d\tau ,$$

computed via the regularised incomplete beta function. One-sided variants (`Tail="left"`, `"right"`) are available when the alternative hypothesis specifies a direction.

### Multiple-comparison correction

If you run $K$ independent t-tests at level $\alpha = 0.05$, the family-wise probability of *at least one* false positive is roughly $1 - (1 - \alpha)^K$, which reaches 0.40 at $K = 10$. Two standard corrections:

| Method | Per-test threshold | Notes |
|---|---|---|
| **Bonferroni** | $\alpha / K$ | Conservative; controls family-wise error rate exactly. |
| **Holm-Bonferroni** | Sort $p$-values; reject $p_{(i)}$ if $p_{(i)} < \alpha/(K - i + 1)$ | Strictly more powerful than Bonferroni and equally safe. |

For more than ~3 comparisons, prefer one-way ANOVA (next section) which controls the family-wise error rate via a single global F-test before any pairwise comparisons.

### Worked example — does measured $H_c$ match the literature?

You measured $H_c = 60.12 \pm 0.33$ Oe ($N = 12$ from the descriptive-statistics example). The literature value for this composition is $\mu_0 = 58.5$ Oe. Are the data consistent?

```matlab
r = utilities.tTest(Hc, [], Mu=58.5);
% r.tStat   = (60.12 - 58.5) / 0.327 = 4.95
% r.df      = 11
% r.pValue  = 4.4e-4
% r.reject  = true
```

The measurement differs significantly from the literature value ($t_{11} = 4.95$, $p = 4 \times 10^{-4}$). Possible explanations: composition or processing differs from the reference, the literature value comes from a single measurement with unstated uncertainty, or there is a systematic instrument offset. Always inspect the data before concluding the literature value is wrong.

### When to use

- **One-sample**: comparing a measured quantity against a calibration value, a theoretical prediction, or zero (e.g. is a magnetic moment offset distinguishable from zero?).
- **Two-sample independent**: comparing two batches, two processing conditions, or two operators when the samples are not paired.
- **Paired**: same physical sample measured twice (before/after annealing; same instrument with two configurations). Always paired when the pairing is real — ignoring pairing wastes statistical power.
- For three or more groups, jump directly to ANOVA rather than running $\binom{K}{2}$ pairwise t-tests.

### References

- Student (W.S. Gosset), "The probable error of a mean", *Biometrika* **6**, 1-25 (1908).
- Welch, B.L., "The generalisation of Student's problem when several different population variances are involved", *Biometrika* **34**, 28-35 (1947).
- Casella & Berger, *Statistical Inference*, 2nd ed., §8.
- Holm, S., "A simple sequentially rejective multiple test procedure", *Scand. J. Statist.* **6**, 65-70 (1979).

---

## One-Way Analysis of Variance (ANOVA)

### Theory

ANOVA generalises the two-sample t-test to $k \ge 2$ groups. The null hypothesis is

$$H_0: \mu_1 = \mu_2 = \cdots = \mu_k ,$$

against the alternative that at least one mean differs. With group sizes $N_j$, group means $\bar x_j$, group variances $s_j^2$, total sample size $N = \sum_j N_j$, and grand mean $\bar x_{..} = N^{-1} \sum_j N_j \bar x_j$, the variance is decomposed as

$$\underbrace{\sum_{j,i} (x_{j,i} - \bar x_{..})^2}_{\mathrm{SS}_\text{tot}} = \underbrace{\sum_j N_j (\bar x_j - \bar x_{..})^2}_{\mathrm{SS}_\text{between}} + \underbrace{\sum_{j,i} (x_{j,i} - \bar x_j)^2}_{\mathrm{SS}_\text{within}} .$$

The mean squares are sums of squares divided by degrees of freedom:

$$\mathrm{MS}_\text{between} = \frac{\mathrm{SS}_\text{between}}{k - 1} , \qquad \mathrm{MS}_\text{within} = \frac{\mathrm{SS}_\text{within}}{N - k} .$$

$\mathrm{MS}_\text{within}$ is the pooled within-group variance (an unbiased estimator of the common $\sigma^2$ under $H_0$). The F-statistic

$$F = \frac{\mathrm{MS}_\text{between}}{\mathrm{MS}_\text{within}}$$

follows the Fisher-Snedecor $F(k - 1,\, N - k)$ distribution under $H_0$. Large $F$ (means spread further apart than within-group noise predicts) gives small $p$-values and rejects $H_0$.

### Effect size

The $p$-value tells you whether the difference is real; it does not tell you how large the difference is. The standard effect-size measure for ANOVA is

$$\eta^2 = \frac{\mathrm{SS}_\text{between}}{\mathrm{SS}_\text{tot}} \in [0, 1] ,$$

the fraction of total variance explained by group membership. Conventional Cohen-style benchmarks: small $\eta^2 \approx 0.01$, medium $0.06$, large $0.14$. A statistically significant but tiny $\eta^2$ usually means the sample is very large; significance with $\eta^2 \gtrsim 0.1$ is a substantively meaningful difference.

### Assumptions

ANOVA's $F$-test is exact when (i) within-group residuals are independent and Gaussian, (ii) the within-group variance is the same for every group (homoscedasticity), and (iii) groups are independent samples. The test is reasonably robust to (i) for $N_j \gtrsim 10$ but breaks down for heavily skewed or heavy-tailed data — check `descriptiveStats(group)` per group first. Strong heteroscedasticity (variance ratio $> 4$) inflates the false-positive rate; in that case use Welch's ANOVA (not yet implemented in the toolbox) or run Welch t-tests on selected pairs with Holm correction.

### Worked example — three sample preparations

Three substrate temperatures (300, 500, 700 K) for a thin-film deposition; $T_c$ measured on $N_j = 8$ films at each setting. Means $\bar T_c$: 89.1, 91.4, 90.7 K. Pooled within-group std $\approx 0.6$ K.

```matlab
r = utilities.anova1({Tc300, Tc500, Tc700});
% r.fStat   = 31.2
% r.df1     = 2     (k-1)
% r.df2     = 21    (N-k)
% r.pValue  = 5.7e-7
% r.reject  = true
% r.groupMeans = [89.1; 91.4; 90.7]
```

The mean $T_c$ differs significantly between substrate temperatures. To find *which* pair drives the difference, run pairwise t-tests with Holm correction; here the dominant contrast is 300 K vs 500 K ($\Delta = 2.3$ K, $\sim 4\sigma_\text{pooled}$), with 500 K vs 700 K weaker.

### When to use

- Three or more groups when you want to know if *any* group differs before running pairwise tests. The single global F-test controls the family-wise false-positive rate at $\alpha$.
- Variance-decomposition reasoning ("how much of the variance does treatment X explain?") via $\eta^2$.
- Do not use one-way ANOVA when groups are matched/repeated-measures (use repeated-measures ANOVA, not yet implemented) or when there are multiple grouping factors (use two-way ANOVA, not yet implemented).

### References

- Fisher, R.A., *Statistical Methods for Research Workers* (Oliver & Boyd, 1925).
- Casella & Berger, *Statistical Inference*, 2nd ed., §11.
- Bevington & Robinson, *Data Reduction and Error Analysis*, 3rd ed., Ch. 7.

---

## Ordinary Least Squares Linear Regression

### Theory

Given $\{x_i, y_i\}$ for $i = 1, \ldots, N$, OLS fits the linear model

$$y = \beta_0 + \beta_1 x + \varepsilon , \qquad \varepsilon \sim \mathcal{N}(0, \sigma^2) ,$$

by minimising the sum of squared *vertical* residuals $\sum_i (y_i - \beta_0 - \beta_1 x_i)^2$. With the design matrix $\mathbf{X}$ (columns: a constant 1 and $x$, extending to powers $x^2, x^3, \ldots$ for `Order > 1` polynomial regression) and observation vector $\mathbf{y}$, the closed-form solution is

$$\hat{\boldsymbol\beta} = (\mathbf{X}^\top \mathbf{X})^{-1} \mathbf{X}^\top \mathbf{y} .$$

The residual variance is $\hat\sigma^2 = \mathrm{RSS}/(N - p)$ where $p$ is the number of fitted parameters (2 for a straight line). The covariance of the parameters is

$$\mathrm{Cov}(\hat{\boldsymbol\beta}) = \hat\sigma^2 \, (\mathbf{X}^\top \mathbf{X})^{-1} ,$$

so each coefficient's standard error is the square root of the corresponding diagonal entry. The t-statistic for testing $H_0: \beta_j = 0$ is $t_j = \hat\beta_j / \mathrm{SE}(\hat\beta_j)$ on $N - p$ degrees of freedom.

The **coefficient of determination** is

$$R^2 = 1 - \frac{\mathrm{RSS}}{\mathrm{TSS}} = 1 - \frac{\sum_i r_i^2}{\sum_i (y_i - \bar y)^2} ,$$

the fraction of total variance in $y$ explained by the linear model. Adjusted $R^2$ penalises extra polynomial terms:

$$R^2_\text{adj} = 1 - (1 - R^2) \frac{N - 1}{N - p} .$$

The **F-statistic** for overall model significance,

$$F = \frac{(\mathrm{TSS} - \mathrm{RSS}) / (p - 1)}{\mathrm{RSS} / (N - p)} \sim F(p - 1,\, N - p) ,$$

tests whether the regression as a whole explains more variance than the constant-mean model.

### Caveats — when $R^2$ is misleading

$R^2$ rises monotonically with the number of parameters; high $R^2$ alone never proves a model is correct. Specific traps:

- **Anscombe's quartet:** four datasets with identical $\bar x, \bar y, s_x, s_y$, slope, intercept, and $R^2$, but visually drastically different (one is a linear cluster + one outlier; one is a parabola; one is a step function). *Always plot residuals.*
- **Range of $x$:** $R^2$ depends on how spread out the $x$ values are. Compressing the $x$ range can drop $R^2$ without changing the underlying physics.
- **Polynomial overfitting:** Order-$N$ polynomial fits $N$ points perfectly with $R^2 = 1$ and residuals identically zero. Use $R^2_\text{adj}$ or AIC (`fitting.fitCompare`) for order selection.
- **Heteroscedasticity:** if $\sigma$ varies with $x$, OLS is no longer optimal — switch to weighted least squares (`fitting.curveFit` with `Weights`) or take logs.

### Assumptions and diagnostics

OLS estimates are the maximum-likelihood solution under (i) linearity in $\mathbf{X}$, (ii) Gaussian errors with constant variance, and (iii) independence of the residuals. To check these, run `fitting.residualDiagnostics(result.residuals)` — see [`fitting.md` § Residual Diagnostics](fitting.md) for the Q-Q plot, Durbin-Watson, runs test, and skewness/kurtosis interpretation. Systematic structure in the residual plot (a curve, a fan, autocorrelation) is far more informative than a single $R^2$ number.

For data where **both** $x$ and $y$ have measurement uncertainty (instrument-vs-instrument calibration, Arrhenius plots), OLS gives a biased slope. Use `fitting.odrFit` instead, which minimises orthogonal distance — see [`fitting.md` § Orthogonal Distance Regression](fitting.md).

### Worked example — Curie-Weiss inverse susceptibility

Above the ordering temperature, a paramagnet obeys $\chi(T) = C/(T - \Theta_\mathrm{CW})$, so a plot of $1/\chi$ vs $T$ is linear with slope $1/C$ and $x$-intercept $\Theta_\mathrm{CW}$:

$$\frac{1}{\chi} = \frac{1}{C}\, T - \frac{\Theta_\mathrm{CW}}{C} .$$

Suppose you measure $\chi(T)$ from $T = 200$-$400$ K on a Cr-substituted ferrite ($N = 60$ points, evenly spaced).

```matlab
invChi = 1 ./ chi;
r = utilities.linRegress(T, invChi);
% r.coeffs    = [-7.62e-3, 9.18e-5]    (intercept, slope)
% r.se        = [ 1.2e-4 , 4.1e-7  ]
% r.tStats    = [-63.5   , 224     ]
% r.pValues   = [<1e-30  , <1e-30  ]   (slope highly significant)
% r.R2        = 0.9988
% r.R2adj     = 0.9988
% r.RMSE      = 7.4e-5  emu/cm³ Oe
% C           = 1/slope = 1.089e4 emu·K/(cm³·Oe)
% Theta_CW    = -intercept/slope = +83.1 K  (ferromagnetic correlations)
```

A positive $\Theta_\mathrm{CW}$ indicates ferromagnetic exchange dominates above the ordering temperature; a negative $\Theta_\mathrm{CW}$ would indicate antiferromagnetic correlations. To propagate the parameter uncertainties to $C$ and $\Theta_\mathrm{CW}$, use `utilities.errorProp` on the algebraic combinations (next section).

### When to use

- Linear or low-order polynomial relationships where the model is known to be correct (Curie-Weiss, Arrhenius, lattice-parameter linear-thermal-expansion fits).
- Quick sanity checks before launching a nonlinear fit — does a log-log plot of the data have a clean linear region?
- For arbitrary nonlinear models, use [`fitting.curveFit`](fitting.md) instead.

### References

- Draper, N.R. & Smith, H., *Applied Regression Analysis*, 3rd ed. (Wiley, 1998), Ch. 1-3.
- Bevington & Robinson, *Data Reduction and Error Analysis*, 3rd ed., Ch. 6 and 7.
- Anscombe, F.J., "Graphs in statistical analysis", *American Statistician* **27**, 17-21 (1973).

---

## Principal Component Analysis

### Theory

PCA finds the orthogonal directions of greatest variance in a data matrix $\mathbf{X} \in \mathbb{R}^{n \times p}$ (rows: observations, columns: variables). It is a *linear* dimensionality reduction: it does nothing useful for data that lies on a curved manifold, but it is fast, exact, and has unambiguous statistical interpretation.

After centering each column ($\mathbf{X}_c = \mathbf{X} - \mathbf{1}_n \bar{\mathbf{x}}^\top$, where $\bar{\mathbf{x}}$ is the column-mean vector), the sample covariance matrix is

$$\mathbf{C} = \frac{1}{n - 1} \mathbf{X}_c^\top \mathbf{X}_c \in \mathbb{R}^{p \times p} .$$

The eigendecomposition $\mathbf{C} = \mathbf{V} \boldsymbol\Lambda \mathbf{V}^\top$ produces orthonormal eigenvectors (the **principal components**) sorted by descending eigenvalue. PC$_j$ is the unit-norm direction along which the data has variance $\lambda_j$.

Equivalently, and more numerically robust, the SVD $\mathbf{X}_c = \mathbf{U} \boldsymbol\Sigma \mathbf{V}^\top$ gives the same loadings $\mathbf{V}$ and eigenvalues $\lambda_j = \sigma_j^2/(n - 1)$. The toolbox uses `svd(Xc, 'econ')`, which works correctly even when $n < p$ (more variables than observations — e.g. spectra with thousands of energies and only tens of samples). The **scores** matrix is $\mathbf{T} = \mathbf{X}_c \mathbf{V}$; its $j$-th column is the projection of every observation onto PC$_j$.

### Fraction of variance explained

The total variance in the centered data is $\sum_j \lambda_j$. The fraction explained by PC$_j$ is $\lambda_j / \sum_k \lambda_k$, and the cumulative fraction by the first $m$ components is $\sum_{j \le m} \lambda_j / \sum_k \lambda_k$. These are returned in `result.explained` and `result.cumulative`.

### Covariance vs correlation method

If the variables are measured in *different units* (concentration in atomic %, peak intensity in counts, binding energy in eV) the column with the largest absolute scale dominates the covariance matrix and the first PC just points along that variable. Setting `Scale=true` standardises each column to unit variance before the SVD — equivalently, $\mathbf{C}$ becomes the *correlation* matrix. Use `Scale=true` whenever variables are heterogeneous; use `Scale=false` (the default) when all columns are in compatible units (e.g. an XPS spectrum where every column is photoelectron intensity at a different energy).

### Choosing the number of components

Three common heuristics, in increasing order of rigour:

1. **Cumulative-variance rule:** retain the smallest $m$ such that $\sum_{j \le m} \lambda_j / \sum_k \lambda_k \ge 0.95$ (or $0.99$ for spectroscopy). Simple and robust in practice.
2. **Scree plot:** plot $\lambda_j$ vs $j$ on a log scale; retain components above the visible "elbow" where the curve flattens.
3. **Kaiser criterion:** retain components with $\lambda_j > 1$ when using the correlation method (each PC must explain more variance than a single original standardised variable).

For spectroscopic problems the cumulative-variance rule is usually preferred because it ties directly to a noise floor.

### Worked example — XPS multi-element scan

You have $n = 200$ XPS survey spectra over $p = 12$ elemental peak intensities (after background subtraction). Question: are all 12 channels independent, or does the chemistry-driven covariation reduce the dimensionality?

```matlab
r = utilities.pcaAnalysis(intensities, Scale=true, NumComponents=4);
% r.explained  = [78.4, 14.1,  5.7,  1.2, ...]   % percent per PC
% r.cumulative = [78.4, 92.5, 98.2, 99.4, ...]
% → first 3 PCs capture 98% of variance
% r.coeff(:,1) = loading vector for PC1 — interpret as a chemical motif
% r.score(:,1) = projection of each spectrum onto PC1
```

The first three PCs capture 98% of the variance; the rest is noise. The PC1 loading vector tells you which elements covary together (e.g. positive loadings on Fe and O, negative on C and N, suggests an oxide vs carbide motif). Plot `score(:,1)` vs `score(:,2)` to look for sample clusters.

### When to use

- Reducing high-dimensional spectroscopic data (XPS, EDS, EELS, FTIR) to a handful of interpretable factors.
- Pre-conditioning input to a downstream regression or classifier when the original variables are highly collinear.
- Visualising structure in datasets with $p \gg 3$ via a 2-D scatter of (PC1, PC2) scores.
- **Do not** use PCA when the underlying physics is intrinsically nonlinear (phase transitions, log-scale dependences) — use the appropriate physical model first, then PCA on the residuals if needed.

### References

- Pearson, K., "On lines and planes of closest fit to systems of points in space", *Philosophical Magazine* **2**, 559-572 (1901).
- Hotelling, H., "Analysis of a complex of statistical variables into principal components", *J. Educ. Psychol.* **24**, 417-441 (1933).
- Jolliffe, I.T., *Principal Component Analysis*, 2nd ed. (Springer, 2002).

---

## Confidence and Prediction Bands

### Theory — OLS regression case

For a linear regression at a new point $x^\ast$, the predicted mean response $\hat y^\ast = \hat\beta_0 + \hat\beta_1 x^\ast$ has variance

$$\mathrm{Var}[\hat y^\ast] = \hat\sigma^2 \left[ \frac{1}{N} + \frac{(x^\ast - \bar x)^2}{\sum_i (x_i - \bar x)^2} \right] .$$

The first term is the uncertainty on the mean; the second grows quadratically with distance from $\bar x$, so the band is narrowest at the data centroid and flares out at the extremes — never extrapolate a confidence band beyond the range of the fitted data.

The **confidence band** at level $1 - \alpha$ for the *mean* response is

$$\hat y^\ast \pm t_{\alpha/2,\, N - p} \, \sqrt{\mathrm{Var}[\hat y^\ast]} ,$$

with $p$ parameters in the model. The **prediction band** for a *single new observation* additionally includes the residual variance:

$$\hat y^\ast \pm t_{\alpha/2,\, N - p} \, \sqrt{\mathrm{Var}[\hat y^\ast] + \hat\sigma^2} .$$

The prediction band is always wider than the confidence band; for $N \gg p$ they differ by roughly $\hat\sigma$ (a constant), so the prediction band looks like the confidence band offset outward.

These bands are **pointwise** — at each $x^\ast$ the band has the stated coverage. **Simultaneous** bands (which contain the entire fitted curve with the stated probability) are wider by a factor of $\sqrt{p \cdot F_{\alpha,\, p,\, N-p}}$ in place of $t_{\alpha/2,\, N-p}$ (Working & Hotelling 1929). The toolbox returns pointwise bands by default; multiply by the Working-Hotelling factor when you need to make a global statement about the curve.

`utilities.linRegress` returns `confBand` and `predBand` as function handles — call them on any new $x$-grid to evaluate the bands. For a generic fit (nonlinear or otherwise), see [`fitting.fitBands`](fitting.md), which propagates the full parameter covariance through the model Jacobian.

### Empirical bands from repeats — `confidenceBand`

A separate utility, `utilities.confidenceBand`, accepts $K \ge 2$ datasets of the same measurement, interpolates them onto a common $x$-grid, and returns the pointwise mean (or median) and spread (std or IQR). This is *not* a regression confidence band — it is the empirical scatter of repeat measurements, useful for plotting "shaded errorbar"-style figures from $K$ replicate sweeps.

```matlab
% K = 5 repeat M(H) loops on the same sample
band = utilities.confidenceBand({d1,d2,d3,d4,d5}, Method="mean");
% band.x      — common field grid
% band.center — mean M(H)
% band.upper, band.lower — mean ± 1 std envelope
```

Use `Method="median"` for the robust IQR version when one of the repeats has known artifacts.

### When to use

- **Confidence band**: quantifying the uncertainty on the *fitted curve* — the appropriate band when you compare a fit to a theoretical prediction.
- **Prediction band**: forecasting where a *new measurement* would fall — the appropriate band for outlier detection or for asking "is this new data point consistent with the model?".
- **Empirical band from repeats**: visualising experimental reproducibility across $K$ runs.

### References

- Draper & Smith, *Applied Regression Analysis*, 3rd ed., Ch. 1 and 5.
- Working, H. & Hotelling, H., "Application of the theory of error to the interpretation of trends", *J. Amer. Statist. Assoc.* Suppl. **24**, 73-85 (1929). (Simultaneous bands.)
- See also [`fitting.md` § Confidence and Prediction Bands](fitting.md) for the nonlinear-fit generalisation via the Jacobian.

---

## Linearised (Gaussian) Error Propagation

### Theory — the master formula

Given a function $f(x_1, \ldots, x_n)$ and inputs with means $\bar x_i$, variances $\sigma_i^2$, and covariances $\sigma_{ij}$, a first-order Taylor expansion around the mean gives

$$\sigma_f^2 \;\approx\; \sum_i \left(\frac{\partial f}{\partial x_i}\right)^2 \sigma_i^2 \;+\; 2 \sum_{i < j} \left(\frac{\partial f}{\partial x_i}\right)\!\left(\frac{\partial f}{\partial x_j}\right) \sigma_{ij} ,$$

evaluated at $\bar{\mathbf{x}}$. This is the **Gauss propagation-of-error formula**. The covariance term vanishes when the inputs are independent (the usual assumption, but check — fits often produce strongly correlated parameters).

### Direct formulas for common operations

The toolbox provides closed-form helpers for the standard cases:

**Addition / subtraction** ($z = x \pm y$): partials are $\pm 1$ each, so

$$\sigma_z^2 = \sigma_x^2 + \sigma_y^2 \qquad \text{(independent)}.$$

This is `utilities.errorAdd`. *Subtractions of nearly-equal numbers blow up the relative error* — when $x \approx y$ the absolute error stays the same while the difference goes to zero. This is the classic "catastrophic cancellation" failure mode in measurement chains; redesign the experiment if you find yourself there.

**Multiplication / division** ($z = xy$ or $z = x/y$): relative errors add in quadrature,

$$\left(\frac{\sigma_z}{z}\right)^2 = \left(\frac{\sigma_x}{x}\right)^2 + \left(\frac{\sigma_y}{y}\right)^2 \qquad \text{(independent)}.$$

This is `utilities.errorMul` and `utilities.errorDiv` — the formula is identical because $\partial \ln(x/y)/\partial \ln x = +1$ and $\partial \ln(x/y)/\partial \ln y = -1$, both squared.

**Power** ($z = x^n$, $n$ exact): one partial $\partial z / \partial x = n x^{n-1}$ gives

$$\frac{\sigma_z}{|z|} = |n|\,\frac{\sigma_x}{|x|} ,$$

so an exponent multiplies the relative error by $|n|$.

**Logarithm** ($z = \ln x$): $\partial z / \partial x = 1/x$, so $\sigma_z = \sigma_x / x$. For base-10 logarithms, divide by $\ln 10 \approx 2.303$:

$$\sigma_{\log_{10} x} = \frac{\sigma_x}{x \ln 10} .$$

In the toolbox this is computed via `utilities.errorFunc(@log, x, sigma_x)` (or `@log10`), which uses central-difference numerical differentiation.

**Generic single-variable** ($z = f(x)$): `utilities.errorFunc(func, a, da)` evaluates `func(a)` and propagates with $\sigma_z = |f'(a)|\,\sigma_a$, using a central-difference numerical derivative. Convenient when $f$ is complicated (e.g. an empirical lookup or a closed-form expression with many terms).

**Generic multivariate** ($z = f(x_1, \ldots, x_n)$): `utilities.errorProp(func, values, errors)` is the dispatcher. With `Method="linear"` (the default) it computes all partials by central differences and returns the Gauss formula result, plus the correlation matrix if `Correlated=C` is supplied. With `Method="montecarlo"` it draws $N_\text{samples}$ from a multivariate normal with the given covariance, evaluates $f$ on each sample, and returns the empirical mean, std, and confidence interval — the right tool when $f$ is strongly nonlinear or when the inputs have correlated uncertainties large enough to take you near a kink in $f$.

### When linearisation fails

The first-order Taylor expansion is the leading term of an infinite series. It is accurate when:

1. Relative errors are small ($\sigma_i / x_i \lesssim 0.1$).
2. $f$ is smooth and nearly linear over the range $[\bar x_i - 3\sigma_i, \bar x_i + 3\sigma_i]$ for every $i$.
3. The inputs do not approach any pole, branch cut, or zero of a denominator.

When any of these fail — e.g. $\sigma_x / x = 0.3$ on a square root, or division by a quantity with $\sigma_y / y = 0.5$ — the symmetric $\bar z \pm \sigma_z$ description is wrong: the true distribution of $z$ is skewed, and the "mean" you computed by plugging in $\bar x_i$ is a *biased* estimator of $\mathbb{E}[f(\mathbf{x})]$. In that regime, switch to the Monte Carlo method (`Method="montecarlo"` in `errorProp`), which makes no linearity assumption.

### Worked example — Hall mobility

The Hall mobility from a transport experiment is $\mu = 1/(n e \rho)$, with carrier density $n$, charge $e$ (exact), and resistivity $\rho$. A measurement gives $n = (5.2 \pm 0.3) \times 10^{20}\,\mathrm{cm}^{-3}$ and $\rho = (4.8 \pm 0.2) \times 10^{-4}\,\Omega\cdot\mathrm{cm}$.

Direct multiplicative formula:

$$\frac{\sigma_\mu}{\mu} = \sqrt{\left(\frac{\sigma_n}{n}\right)^2 + \left(\frac{\sigma_\rho}{\rho}\right)^2} = \sqrt{(0.058)^2 + (0.042)^2} = 0.072 .$$

```matlab
n   = 5.2e20;   sn = 0.3e20;
rho = 4.8e-4;   sr = 0.2e-4;
e   = 1.602e-19;

% Method 1 — direct (errorMul ∘ errorMul, treating e as exact)
[neRho, sNeRho] = utilities.errorMul(n*e, sn*e, rho, sr);
[mu, sMu]       = utilities.errorDiv(1, 0, neRho, sNeRho);
% mu  = 25.0  cm²/(V·s)
% sMu =  1.81 cm²/(V·s)

% Method 2 — generic dispatcher with closed-form formula string
r = utilities.errorProp(@(n,rho) 1./(n*1.602e-19.*rho), {n,rho}, {sn,sr});
% r.value    = 25.0  cm²/(V·s)
% r.error    =  1.81 cm²/(V·s)
% r.relError = 7.2%
```

Both give the same answer to within numerical-derivative accuracy. Reportable: $\mu = 25.0 \pm 1.8\,\mathrm{cm}^2/(\mathrm{V}\cdot\mathrm{s})$.

### When to use

- Whenever a *derived* physical quantity is reported alongside a measurement uncertainty — coercivity ratios, mobilities, effective masses, cell volumes from lattice parameters, etc.
- For the simple algebraic cases (sum, product, quotient, power, log) reach for `errorAdd`/`errorMul`/`errorDiv`/`errorFunc` directly — they are zero-overhead and the formulas are transparent.
- For composed expressions or when correlations matter, use `errorProp` with the function handle (linear method, with `Correlated=C` to include parameter correlations from a previous fit).
- For strongly nonlinear $f$ or large relative errors, use `errorProp` with `Method="montecarlo"`.
- For propagating *fit* parameter covariance through to a model curve, use [`fitting.fitBands`](fitting.md) instead of building it from the propagation utilities.

### References

- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003), Ch. 3-4. The canonical physics reference; covers the master formula, common cases, and Monte Carlo.
- Taylor, J.R., *An Introduction to Error Analysis*, 2nd ed. (University Science Books, 1997). Undergraduate-friendly derivations and worked examples.
- Joint Committee for Guides in Metrology, *Evaluation of measurement data — Guide to the expression of uncertainty in measurement* (ISO/IEC GUM, 2008). The international standard; precise definitions of "Type A" (statistical) and "Type B" (systematic) uncertainty contributions.

---

## Implementation Table

The functions that this document covers, with one-line role descriptions and the governing equation reference. All live in `+utilities/` and are invoked as `utilities.<name>(...)`.

| Function | Role | Key equation | Important arguments |
|---|---|---|---|
| `descriptiveStats(x)` | Summary stats: mean, median, std, sem, var, min/max/range, q1/q3/iqr, skewness, kurtosis | $\bar x$, $s^2 = \tfrac{1}{N-1}\sum(x_i-\bar x)^2$, $\mathrm{SEM} = s/\sqrt N$ | — |
| `tTest(x, y, ...)` | One-sample, two-sample (Welch), paired t-test | $t = (\bar x - \mu_0) / (s/\sqrt N)$ etc. | `Mu`, `Paired`, `Alpha`, `Tail` |
| `anova1(groups)` | One-way ANOVA F-test for $k$ group means | $F = \mathrm{MS}_\text{between} / \mathrm{MS}_\text{within}$ | `Alpha`, `Group` |
| `linRegress(x, y)` | OLS linear / polynomial regression with SE, t/p, $R^2$, F-test, conf/pred bands | $\hat{\boldsymbol\beta} = (\mathbf{X}^\top \mathbf{X})^{-1}\mathbf{X}^\top \mathbf{y}$ | `Order`, `Alpha` |
| `pcaAnalysis(X)` | PCA via SVD on centered (and optionally scaled) data | $\mathbf{X}_c = \mathbf{U}\boldsymbol\Sigma\mathbf{V}^\top$; $\lambda_j = \sigma_j^2/(n-1)$ | `Center`, `Scale`, `NumComponents` |
| `confidenceBand(datasets)` | Empirical mean (or median) ± std (or IQR) across $K$ replicate datasets | pointwise mean ± std on common grid | `Method`, `Channel`, `NPoints` |
| `errorAdd(a, da, b, db)` | Error propagation for $z = a + b$ | $\sigma_z^2 = \sigma_a^2 + \sigma_b^2$ | — |
| `errorMul(a, da, b, db)` | Error propagation for $z = a b$ | $(\sigma_z/z)^2 = (\sigma_a/a)^2 + (\sigma_b/b)^2$ | — |
| `errorDiv(a, da, b, db)` | Error propagation for $z = a / b$ | same as `errorMul` | — |
| `errorFunc(func, a, da)` | Error propagation for $z = f(a)$ via central-difference $f'$ | $\sigma_z = \lvert f'(a)\rvert\,\sigma_a$ | — |
| `errorProp(func, vals, errs)` | Generic dispatcher: linear (Gauss) or Monte Carlo | $\sigma_f^2 = \mathbf{J}^\top\mathbf{C}\mathbf{J}$ (linear) | `Method`, `NSamples`, `Correlated`, `Confidence` |

Cross-references for related functionality covered in the companion documents:

- Nonlinear fit parameter covariance, AIC/BIC, F-test for nested models, residual diagnostics: [`fitting.md`](fitting.md).
- ODR linear regression (errors in both $x$ and $y$): [`fitting.md` § Orthogonal Distance Regression](fitting.md).
- MCMC posterior sampling (when the linearised covariance is unreliable): [`fitting.md` § MCMC Posterior Sampling](fitting.md).

---

## Consolidated References

- **General physics statistics.** Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003). The canonical reference — covers descriptive stats, $\chi^2$, error propagation, and the F-test in a physics-friendly notation.
- **Mathematical statistics.** Casella, G. & Berger, R.L., *Statistical Inference*, 2nd ed. (Duxbury/Cengage, 2002). Rigorous treatment of t-tests, ANOVA, and confidence intervals.
- **Regression.** Draper, N.R. & Smith, H., *Applied Regression Analysis*, 3rd ed. (Wiley, 1998). Linear and polynomial regression, residual analysis, confidence/prediction bands.
- **PCA.** Jolliffe, I.T., *Principal Component Analysis*, 2nd ed. (Springer, 2002).
- **Error analysis (undergraduate).** Taylor, J.R., *An Introduction to Error Analysis*, 2nd ed. (University Science Books, 1997).
- **Metrology standard.** Joint Committee for Guides in Metrology, *Evaluation of measurement data — Guide to the expression of uncertainty in measurement* (ISO/IEC GUM, 2008).
- **Original method papers.** Student, *Biometrika* **6**, 1 (1908); Welch, *Biometrika* **34**, 28 (1947); Fisher, *Statistical Methods for Research Workers* (1925); Pearson, *Phil. Mag.* **2**, 559 (1901); Hotelling, *J. Educ. Psychol.* **24**, 417 (1933); Working & Hotelling, *J. Amer. Statist. Assoc.* Suppl. **24**, 73 (1929); Holm, *Scand. J. Statist.* **6**, 65 (1979); Anscombe, *Amer. Statist.* **27**, 17 (1973).
