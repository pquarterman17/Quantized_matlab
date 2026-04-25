# Tutorial: Powder XRD Analysis — Peak Fits, Williamson-Hall, and Phase ID

This tutorial walks through the complete powder XRD analysis workflow: load a scan from a Bruker, Rigaku, or PANalytical instrument; subtract the background; fit individual Bragg peaks with a pseudo-Voigt profile; convert peak positions to lattice spacings; separate crystallite size from microstrain via the Williamson-Hall plot; and identify the phases present by matching against the built-in reference database.

**Research question:** "I have a powder XRD scan from a Bruker / Rigaku / PANalytical instrument. How do I fit the peaks, extract crystallite size and microstrain via Williamson-Hall, and identify which phases are present?"

The example uses Cu Kα₁ ($\lambda = 1.5406$ Å) throughout. See [`docs/theory/xrd.md`](../theory/xrd.md) for the underlying physics (Bragg's law, Scherrer, the Williamson-Hall derivation) and [`docs/theory/fitting.md`](../theory/fitting.md) for the fitting machinery.

---

## 1. Physics in 60 seconds

Three relationships drive every step of this tutorial:

**Bragg's law** turns peak position into a lattice-plane spacing:

$$2 d_{hkl} \sin\theta = n\lambda \;\Longrightarrow\; d_{hkl} = \frac{\lambda}{2\sin\theta}$$

For a cubic phase the $(hkl)$ family fixes $d$ via $d_{hkl} = a / \sqrt{h^2 + k^2 + l^2}$, so a single well-indexed peak yields the lattice parameter $a$.

**Scherrer's equation** turns peak width (FWHM) into a crystallite size:

$$D = \frac{K\lambda}{\beta_\text{intrinsic}\cos\theta}, \qquad \beta_\text{intrinsic} = \sqrt{\beta_\text{obs}^2 - \beta_\text{inst}^2}$$

with $K \approx 0.9$ for spherical grains. The instrumental width $\beta_\text{inst}$ must be subtracted in quadrature — typically measured with a strain-free standard (LaB6 or Si).

**Williamson-Hall** separates size from strain by fitting the angular dependence of the broadening across multiple reflections:

$$\beta_\text{intrinsic}\cos\theta = \frac{K\lambda}{D} + 4\varepsilon\sin\theta$$

A linear regression of $\beta\cos\theta$ vs $4\sin\theta$ gives $D$ from the intercept and the microstrain $\varepsilon$ from the slope. Three or more reflections are required; five or more give a meaningful slope.

**Phase identification** is pattern fingerprinting: compute the $d$-spacing of each measured peak, look up phases whose calculated reflections match within tolerance, and rank by the fraction of observed peaks accounted for. The toolbox ships a database of ~52 common substrate, semiconductor, oxide, perovskite, and metal phases.

Cross-link: see [`docs/theory/xrd.md`](../theory/xrd.md) for the full derivation of each formula above (instrumental deconvolution, the spherical-vs-platelet $K$ factor, anisotropic strain models, and the modified Williamson-Hall variants).

---

## 2. What you need

- **An instrument file.** One of:
  - `.xrdml` (PANalytical / Malvern Panalytical X'Pert)
  - `.brml` or `.raw` (Bruker D8, D2 PHASER, etc.)
  - `.ras` (Rigaku SmartLab, MiniFlex, Ultima)
  - or a generic two-column ASCII file (use `parser.importCSV`)
- **The wavelength.** Default is Cu Kα₁ = 1.5406 Å. If the source is Mo Kα₁ use 0.7093 Å, Co Kα₁ uses 1.7889 Å. Check your instrument log — many tubes report a Kα₁/Kα₂-weighted average ≈ 1.5418 Å.
- **An instrumental resolution function (optional but strongly recommended).** A scan of an LaB6 (NIST SRM 660) or Si (SRM 640) standard, fit with the same pseudo-Voigt profile, gives the FWHM-vs-$2\theta$ curve to subtract. Without it the Scherrer/Williamson-Hall result conflates sample and instrument broadening.
- **A rough composition guess.** Phase ID against the full database is unconstrained; restricting to `Categories={'oxide','perovskite'}` or similar dramatically improves specificity.

---

## 3. Load and inspect the scan

```matlab
setupToolbox    % run once to add packages to MATLAB path

% Auto-detect: works for any registered extension
data = parser.importAuto('LSMO_film.xrdml');

% Or call the parser directly:
data = parser.importXRDML('LSMO_film.xrdml', Intensity='cps');
data = parser.importBruker('LSMO_film.brml');
data = parser.importRigaku_raw('LSMO_film.ras');

% Pull 2theta and intensity by label (parser-agnostic)
twoTheta = data.values(:, data.labels == "2Theta (deg)");
I        = data.values(:, data.labels == "Intensity (cps)");

figure;
plot(twoTheta, I, 'k-');
xlabel('2\theta (deg)'); ylabel('Intensity (cps)');
title('Raw XRD pattern');
set(gca, 'YScale', 'log');   % log-y reveals weak peaks
```

Visually identify a few candidate Bragg peaks. A typical perovskite thin film on STO (001) might show:

- Sharp substrate peaks at $2\theta = 22.76^\circ$ (STO 001), $46.47^\circ$ (002), $72.55^\circ$ (003) — these come from the substrate, not your film
- Broader film peaks shifted by 0.2–0.5° from the substrate (epitaxial strain) at nearby angles
- Possibly secondary phases at intermediate angles (impurities)

For a powder sample you would expect five to ten well-separated peaks distributed across the 20°–90° range.

---

## 4. Background subtraction

The simplest reliable approach is a polynomial fit through user-selected off-peak baseline points. For most powder scans a third-order polynomial is enough.

```matlab
% Define windows that contain ONLY background (no peaks)
isBg = (twoTheta > 18 & twoTheta < 21) | ...
       (twoTheta > 25 & twoTheta < 28) | ...
       (twoTheta > 38 & twoTheta < 42) | ...
       (twoTheta > 60 & twoTheta < 65) | ...
       (twoTheta > 78 & twoTheta < 82);

p   = polyfit(twoTheta(isBg), I(isBg), 3);
bg  = polyval(p, twoTheta);
Ibs = I - bg;            % background-subtracted intensity

figure;
plot(twoTheta, I, 'k-', twoTheta, bg, 'r--', twoTheta, Ibs, 'b-');
xlabel('2\theta (deg)'); ylabel('Intensity (cps)');
legend('Raw','Background','Subtracted');
```

If the air-scattering tail at low angle dominates a third-order polynomial, switch to a piecewise approach: fit $I_\text{bg} = A/2\theta + B + C\cdot 2\theta$ in the tail and a quadratic above 25°. For complex backgrounds (amorphous halo, fluorescence on Fe samples with a Cu source), an iterative rolling-ball or SNIP filter would be appropriate — see `+utilities/` for general baseline tools that may be applicable.

---

## 5. Single-peak fit with pseudo-Voigt

Pick one isolated peak — a strong, well-separated reflection. Fit it with the pseudo-Voigt profile, which interpolates between Gaussian and Lorentzian via the mixing parameter $\eta$:

$$P(2\theta) = A\left[\eta \frac{1}{1 + ((2\theta-2\theta_0)/w)^2} + (1-\eta)\exp\!\left(-\ln 2\,\frac{(2\theta-2\theta_0)^2}{w^2}\right)\right]$$

where $w$ is the half-width at half-maximum (HWHM) shared between the two components and $\eta \in [0,1]$ is the Lorentz fraction.

```matlab
% Window around an isolated peak (e.g. LSMO (110) near 32.6 deg)
window = (twoTheta > 31.5) & (twoTheta < 33.5);
xw = twoTheta(window);
yw = Ibs(window);

% Get the model from the fitting catalog
cat = fitting.models();
pv  = cat(strcmp({cat.name}, 'Pseudo-Voigt'));

% Auto-guess starting parameters from the data shape
p0 = fitting.autoGuess('Pseudo-Voigt', xw, yw);

% Bounds: positive amplitude/width, centre inside window, eta in [0,1]
lb = [0,         min(xw),   0,    0];
ub = [Inf,       max(xw),   Inf,  1];

res = fitting.curveFit(xw, yw, pv.fcn, p0, ...
        Lower=lb, Upper=ub, ParamNames=pv.paramNames);

fprintf('Peak fit (chi^2_red = %.3f, R^2 = %.5f):\n', res.chiSqRed, res.R2);
for k = 1:numel(res.params)
    fprintf('  %-5s = %10.4f  +/-  %.4f\n', pv.paramNames{k}, ...
            res.params(k), res.errors(k));
end
```

For the LSMO (110) peak you might see:

```
Peak fit (chi^2_red = 1.04, R^2 = 0.9987):
  A     =   2840.3  +/-  18.5
  μ     =   32.612  +/-  0.0021    % peak centre, deg 2-theta
  w     =    0.118  +/-  0.0024    % HWHM, deg
  η     =    0.43   +/-  0.045     % Lorentz fraction
```

The FWHM is $\beta_\text{obs} = 2w = 0.236^\circ$. Convert peak centre to a $d$-spacing:

```matlab
twoTheta0 = res.params(2);
fwhm_obs  = 2 * res.params(3);             % deg, since w = HWHM

dHkl = calc.crystal.dFromTwoTheta(twoTheta0, Lambda=1.5406);
fprintf('d_{110} = %.4f Angstrom  (2theta = %.4f deg)\n', dHkl, twoTheta0);
% -> d_{110} = 2.7438 Angstrom
```

For a perovskite indexed as $(110)$ pseudocubic, $a = d_{110}\sqrt{2} \approx 3.880$ Å — consistent with bulk LSMO.

**Why pseudo-Voigt?** Powder peaks are convolutions of Gaussian (instrumental, microstrain) and Lorentzian (size broadening, mosaic) contributions. A pure Gaussian fits the wings poorly; a pure Lorentzian over-emphasises them. Pseudo-Voigt is the standard pragmatic choice. For Rietveld-style work the Thompson-Cox-Hastings parameterisation is preferred (see Section 6).

---

## 6. Multi-peak fits and the TCH profile (optional)

For overlapping reflections (close pseudocubic doublets, Kα₁/Kα₂ splitting at high angle, or impurity-phase shoulders), fit two or more pseudo-Voigt peaks with a shared linear background:

```matlab
% Two-PV model: 4 params per peak + 2 background params
twoPV = @(x, p) ...
    p(1)*(p(4)./(1+((x-p(2))./p(3)).^2) + (1-p(4)).*exp(-log(2).*((x-p(2))./p(3)).^2)) + ...
    p(5)*(p(8)./(1+((x-p(6))./p(7)).^2) + (1-p(8)).*exp(-log(2).*((x-p(6))./p(7)).^2)) + ...
    p(9)*x + p(10);

paramNames = {'A1','μ1','w1','η1','A2','μ2','w2','η2','m','c'};
p0 = [1000, 32.5, 0.12, 0.5,  500, 32.9, 0.10, 0.5,  0, 0];

resM = fitting.curveFit(xw, yw, twoPV, p0, ParamNames=paramNames);
```

When peaks overlap heavily, **constrain** to keep the fit identifiable:

- Tie $\eta_1 = \eta_2$ — same line shape on neighbouring reflections
- Force $w_2 = w_1 \cdot (\tan\theta_2 / \tan\theta_1)$ to lock the angular dispersion
- For Kα₁/Kα₂, fix $A_2 = 0.5\,A_1$ and $2\theta_2 = 2\theta_1 + \Delta_{12}(\theta)$

For Rietveld-style refinement use the **Thompson-Cox-Hastings** modified pseudo-Voigt — it parameterises the Gaussian and Lorentzian FWHMs independently, which physically corresponds to instrument vs sample broadening:

```matlab
y = utilities.tchPseudoVoigt(xw, [H, x0, fG, fL, bg]);
% H  = peak height
% x0 = centre
% fG = Gaussian FWHM (instrument + microstrain)
% fL = Lorentzian FWHM (size + mosaic)
% bg = constant baseline
```

The TCH profile is the standard line shape in GSAS-II, FullProf, and TOPAS; use it whenever you plan to feed the results into a full pattern refinement.

---

## 7. Crystallite size from Scherrer (single peak)

If you have only one well-fitted peak, use Scherrer directly. Subtract the instrumental FWHM in quadrature:

```matlab
% Instrumental width at this 2theta — measured separately on LaB6 or Si
fwhm_inst = 0.060;                               % deg, typical lab diffractometer
fwhm_intrinsic = sqrt(fwhm_obs^2 - fwhm_inst^2);

theta = deg2rad(twoTheta0 / 2);                  % half-angle in radians
beta  = deg2rad(fwhm_intrinsic);                 % FWHM in radians
K     = 0.9;                                     % spherical grains
lambda_A = 1.5406;

D_A  = K * lambda_A / (beta * cos(theta));      % Angstrom
fprintf('Crystallite size D = %.1f nm\n', D_A / 10);
```

**Worked example.** A film (110) peak at $2\theta_0 = 35.0^\circ$ with $\beta_\text{obs} = 0.40^\circ$ and instrumental $\beta_\text{inst} = 0.06^\circ$:

- $\beta_\text{intrinsic} = \sqrt{0.40^2 - 0.06^2} = 0.396^\circ = 6.91 \times 10^{-3}$ rad
- $\theta = 17.5^\circ$, $\cos\theta = 0.9537$
- $D = (0.9 \times 1.5406) / (6.91\times 10^{-3} \times 0.9537) = 210.4$ Å $= 21$ nm

A 25 nm crystallite size is typical for a sputtered or sol-gel oxide film. Below 5 nm the Scherrer assumption (well-defined Bragg peak) breaks down — peaks become asymmetric and $D$ underestimates the true size.

**Caveat — Scherrer assumes zero strain.** If the sample has microstrain, Scherrer overestimates the broadening attributable to size and underestimates $D$. Move to Williamson-Hall whenever you can fit three or more peaks.

---

## 8. Williamson-Hall analysis (multiple peaks)

Fit the same pseudo-Voigt to each visible peak, collect $(2\theta_i, \beta_i)$ pairs, and pass them to `calc.crystal.williamsonHall`:

```matlab
% After fitting peaks at, e.g., (110), (200), (211), (220), (310):
twoThetaList = [32.612, 46.812, 58.117, 68.218, 77.621]';   % deg
fwhmList     = [0.236,  0.272,  0.301,  0.328,  0.358]';    % deg
fwhm_inst    = 0.060;                                       % deg, from LaB6

wh = calc.crystal.williamsonHall(twoThetaList, fwhmList, ...
        Wavelength_A=1.5406, ...
        KFactor=0.9, ...
        InstrumentalBroadening=fwhm_inst);

fprintf('Williamson-Hall fit (R^2 = %.4f):\n', wh.R2);
fprintf('  Crystallite size D = %.1f nm\n', wh.grainSize_nm);
fprintf('  Microstrain eps   = %.4f  (%.2f %%)\n', ...
        wh.microstrain, wh.microstrain*100);
```

Plot the linearised data — every reflection should lie on the same line:

```matlab
figure;
plot(wh.plotData.x, wh.plotData.y, 'ko', 'MarkerFaceColor','b'); hold on;
xLine = linspace(0, max(wh.plotData.x)*1.05, 50);
slope     = wh.plotData.fitLine(1);
intercept = wh.plotData.fitLine(2);
plot(xLine, slope*xLine + intercept, 'r-', 'LineWidth', 1.5);
xlabel('4 sin\theta');
ylabel('\beta cos\theta  (rad)');
title(sprintf('Williamson-Hall: D = %.1f nm, \\epsilon = %.3f %%', ...
      wh.grainSize_nm, wh.microstrain*100));
grid on;
```

**Worked example.** Five peaks from the simulated dataset above give:

```
Williamson-Hall fit (R^2 = 0.987):
  Crystallite size D = 28.4 nm
  Microstrain eps   = 0.0018  (0.18 %)
```

The intercept $K\lambda/D = 0.0049$ rad gives $D = 28$ nm; the slope $4\varepsilon = 0.0072$ gives $\varepsilon = 0.18\%$. A 0.18 % microstrain is moderate — typical of films with epitaxial mismatch or bulk samples after grinding. Values $> 1\%$ indicate severe deformation; $< 0.05\%$ indicates a near-perfect crystal.

### When uniform Williamson-Hall fails

The plain (uniform-strain) Williamson-Hall model assumes isotropic broadening. Two common failure modes:

- **Curved instead of linear plot.** The $(\beta\cos\theta)$ vs $(4\sin\theta)$ data bends — usually because size and strain broadening combine via a *Voigt* convolution rather than the simple sum used here. Switch to the Halder-Wagner method or fit a Voigt explicitly to each peak and Fourier-decompose.
- **Scatter much larger than the fit residuals would suggest.** Anisotropic strain (different microstrain along different crystallographic directions) shows up as systematically high or low points for $(h00)$ vs $(hk0)$ vs $(hkl)$. The remedy is the modified Williamson-Hall ($\beta\cos\theta$ vs $4\sin\theta \cdot \sqrt{C_{hkl}}$ with contrast factors) — see `docs/theory/xrd.md`.

If `wh.R2 < 0.85` or the plot looks visibly curved, do not report a single $D$ and $\varepsilon$ — the assumption has failed.

---

## 9. Phase identification

Collect the centres of the strongest peaks from the fit and pass them to the matcher:

```matlab
% Peak centres extracted from individual fits, sorted by 2theta
peakCentres = [22.76, 28.44, 32.61, 47.30, 56.12, 58.12, 69.13, 76.37]';

matches = calc.crystal.matchPhases(peakCentres, ...
    Lambda=1.5406, ...
    Tolerance=0.04, ...
    MinMatchFrac=0.5);

% Top three candidates
fprintf('Best phase matches:\n');
for k = 1:min(3, numel(matches))
    m = matches(k);
    fprintf('  %d. %s  (%s)  score = %.0f%%  matched %d/%d peaks\n', ...
            k, m.phaseName, m.formula, m.score*100, m.nMatched, m.nObserved);
end
```

Output for a real Si + SiO₂ powder sample might look like:

```
Best phase matches:
  1. Si              (Si)        score = 75%  matched 6/8 peaks
  2. SrTiO3          (SrTiO3)    score = 25%  matched 2/8 peaks
  3. Quartz alpha    (SiO2)      score = 25%  matched 2/8 peaks
```

The 6/8 match for Si is convincing; the unmatched 2 peaks are the candidates for a second phase. Constrain the categories and re-search:

```matlab
% Search only oxides for the leftover peaks
leftover = peakCentres([2 4]);   % the two unmatched peaks
m2 = calc.crystal.matchPhases(leftover, ...
    Categories={'oxide'}, Tolerance=0.05);
```

Overlay the predicted reflections on the data:

```matlab
figure;
plot(twoTheta, Ibs, 'k-'); hold on;
yLim = ylim;
% Stick spectrum for the top match
for k = 1:numel(matches(1).allRefTwoTheta)
    t = matches(1).allRefTwoTheta(k);
    if t > min(twoTheta) && t < max(twoTheta)
        plot([t t], [0 yLim(2)*0.4], 'r-', 'LineWidth', 1);
    end
end
xlabel('2\theta (deg)'); ylabel('Intensity (cps)');
title(sprintf('Overlay: %s reference reflections', matches(1).phaseName));
```

**Important: do not confuse `calc.crystal.matchPhases` with `imaging.simulateDiffraction`.** The latter generates 2D *electron* diffraction spot patterns from a zone axis (for use with TEM data in FermiViewer), not 1D powder XRD intensities. For powder simulation use `calc.crystal.planeSpacings` to enumerate reflections, then weight by multiplicity and Lorentz-polarisation if you need synthetic patterns:

```matlab
% Reference reflections for FCC Si (a = 5.431 Å)
ref = calc.crystal.planeSpacings(5.431, Centering='F', MaxHKL=5, Lambda=1.5406);
fprintf('Si reflection list:\n');
for k = 1:min(8, numel(ref.d))
    fprintf('  (%d %d %d)  d = %.4f Å  2theta = %.3f°  m = %d\n', ...
            ref.hkl(k,1), ref.hkl(k,2), ref.hkl(k,3), ...
            ref.d(k), ref.twoTheta(k), ref.multiplicity(k));
end
```

---

## 10. Common pitfalls

- **Reading raw FWHM as if it were intrinsic.** The Scherrer formula uses $\beta_\text{intrinsic} = \sqrt{\beta_\text{obs}^2 - \beta_\text{inst}^2}$. Skipping the deconvolution makes every "size" you report a lower bound. Always measure an LaB6 or Si standard with the same slits, source, and step size, and pass `InstrumentalBroadening=fwhm_inst` to `williamsonHall`.

- **Williamson-Hall with too few peaks.** Three reflections give a noisy slope (and hence a noisy strain); five or more are needed for a meaningful $\varepsilon$. If you only have two reflections, report Scherrer-only $D$ and note that strain is unconstrained.

- **Mixing Kα₁ vs Kα-weighted wavelengths.** `1.5406` is Cu Kα₁; `1.5418` is the Kα₁/Kα₂ weighted average. For precise lattice-parameter work fit Kα₁ and Kα₂ as separate peaks (intensity ratio 2:1, $\Delta(2\theta) \propto \tan\theta$) and use Kα₁ exclusively. Using the average wavelength on a Kα₁-only fit shifts $a$ by ~0.05%.

- **Single-peak phase ID.** A single matched reflection means almost nothing — many phases share peaks within the database tolerance. Require three or more matched reflections, ideally distributed across the full $2\theta$ range, before claiming a phase identification.

- **Forgetting absorption correction for highly absorbing samples.** A Bragg-Brentano scan on a Tb, Dy, or Pb-bearing sample with Cu radiation has a finite penetration depth; the effective sampled volume changes with $2\theta$ and distorts intensities. Either use a thicker sample (so penetration $\ll$ thickness across the scan) or apply a $1/(2\mu)\cdot[1 - \exp(-2\mu t/\sin\theta)]$ correction.

- **Substrate peaks contaminating the fit list.** If the film is on STO, MgO, or LSAT, those substrate Bragg peaks will dominate the pattern. Mask the substrate $2\theta$ ranges before passing peak centres to `matchPhases` and `williamsonHall`, or you will get nonsense.

- **Background subtraction that crosses zero.** A polynomial fit forced to track an air-scattering tail can dip below the low-angle peaks and turn part of the peak into "negative background". Always plot raw, background, and subtracted on the same axes before fitting.

---

## 11. Reporting template

For publication or a lab report, include all of the following:

1. **Instrument and source.** "Bruker D8 DISCOVER, Cu Kα₁ ($\lambda = 1.5406$ Å), Bragg-Brentano geometry, 0.02° step, 1 s/step, 10–90° range."

2. **Peak table.** $2\theta$ centre, FWHM, integrated intensity, assigned $(hkl)$, calculated $d$-spacing — for every fit peak.

3. **Lattice parameter** with method. "$a = 3.880(2)$ Å from a Nelson-Riley extrapolation across (110), (200), (211), (220), (310)."

4. **Crystallite size and microstrain.** "Williamson-Hall analysis (5 reflections, $K = 0.9$, instrumental FWHM 0.060° from LaB6) yields $D = 28(2)$ nm and $\varepsilon = 0.18(3)$ %, $R^2 = 0.99$."

5. **Phase identification.** "Pattern is consistent with cubic LSMO ($Pm\bar{3}m$, ICSD #51787); 7/8 observed reflections match within 0.04°. The remaining peak at $2\theta = 28.4^\circ$ is unindexed and may indicate a minor secondary phase."

6. **Goodness-of-fit metric** if you ran a full pattern refinement: $R_p$ and/or $R_{wp}$ from your Rietveld code. Single-peak fits should report $\chi^2_\nu$ and $R^2$ from `fitting.curveFit`.

7. **Residual plot** for at least the strongest peak — small inset is enough; readers should be able to see whether the line shape is correct.

---

## 12. Going further

| If you need to... | Use |
|---|---|
| Convert $d$ ↔ $2\theta$ for a given $\lambda$ | [`calc.crystal.dFromTwoTheta`](../../+calc/+crystal/dFromTwoTheta.m), [`calc.crystal.twoThetaFromD`](../../+calc/+crystal/twoThetaFromD.m) |
| Compute $d_{hkl}$ for any unit cell | [`calc.crystal.dSpacing`](../../+calc/+crystal/dSpacing.m) |
| Enumerate allowed $(hkl)$ for a Bravais lattice | [`calc.crystal.planeSpacings`](../../+calc/+crystal/planeSpacings.m) |
| Match peaks against the built-in phase database | [`calc.crystal.matchPhases`](../../+calc/+crystal/matchPhases.m) |
| Track a peak across a series of scans (T, time, position) | [`fitting.trackPeak`](../../+fitting/trackPeak.m) |
| Fit the same pseudo-Voigt to many scans and tabulate trends | [`fitting.batchFit`](../../+fitting/batchFit.m) |
| Use the Thompson-Cox-Hastings profile (Rietveld-grade line shape) | [`utilities.tchPseudoVoigt`](../../+utilities/tchPseudoVoigt.m) |
| Compute lattice mismatch and critical thickness for an epi system | [`calc.crystal.latticeMismatch`](../../+calc/+crystal/latticeMismatch.m), [`calc.crystal.criticalThickness`](../../+calc/+crystal/criticalThickness.m) |

For 2D area-detector data (XRDML files containing reciprocal-space maps), `parser.importXRDML` populates `data.metadata.parserSpecific.map2D` with the intensity grid plus optional $Q_x, Q_z$ axes — see the 2D XRDML notes in [`+parser/README.md`](../../+parser/README.md).

---

## 13. References

- Cullity, B.D. & Stock, S.R., *Elements of X-Ray Diffraction*, 3rd ed. (Prentice Hall, 2001). Ch. 9 (intensity calculation), Ch. 14 (microstructure from line broadening).
- Warren, B.E., *X-Ray Diffraction* (Dover, 1990). Ch. 13 (size and strain from line shapes).
- Williamson, G.K. & Hall, W.H., "X-ray line broadening from filed aluminium and wolfram," *Acta Metall.* **1**, 22 (1953). DOI: [10.1016/0001-6160(53)90006-6](https://doi.org/10.1016/0001-6160(53)90006-6)
- Scherrer, P., "Bestimmung der Größe und der inneren Struktur von Kolloidteilchen mittels Röntgenstrahlen," *Nachr. Ges. Wiss. Göttingen* **2**, 98 (1918).
- Thompson, P., Cox, D.E. & Hastings, J.B., "Rietveld refinement of Debye-Scherrer synchrotron X-ray data from Al₂O₃," *J. Appl. Crystallogr.* **20**, 79 (1987). DOI: [10.1107/S0021889887087090](https://doi.org/10.1107/S0021889887087090)
- Langford, J.I. & Wilson, A.J.C., "Scherrer after sixty years: a survey and some new results in the determination of crystallite size," *J. Appl. Crystallogr.* **11**, 102 (1978). DOI: [10.1107/S0021889878012844](https://doi.org/10.1107/S0021889878012844)

For derivations, see [`docs/theory/xrd.md`](../theory/xrd.md). For fitting machinery and uncertainty analysis, see [`docs/theory/fitting.md`](../theory/fitting.md).
