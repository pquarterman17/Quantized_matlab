# Tutorial: X-Ray and Neutron Reflectometry Workflow

This tutorial walks through the complete specular-reflectometry workflow: compute scattering length densities (SLDs) for each layer of a thin-film stack, build the layer model, simulate Parratt reflectivity with instrument-resolution smearing, and fit the model to a measured curve.

**Research question:** "I have a thin-film stack and I want to predict its X-ray or neutron reflectivity, then compare to measured data. How do I build the SLD profile, simulate Parratt reflectivity, and fit it?"

The example uses a Si / SiO$_2$ / Au stack measured with Cu K$\alpha_1$ X-rays. The same workflow applies to neutron reflectometry on PBR / CANDOR (just swap `xraySLD` for `neutronSLD` and load with `parser.importNCNRRefl`).

See [`docs/theory/reflectometry.md`](../theory/reflectometry.md) for the full Parratt derivation and [`docs/theory/thin_films.md`](../theory/thin_films.md) for Kiessig fringes and Fresnel coefficients.

---

## 1. Physics in 60 seconds

X-rays and neutrons interact weakly with matter, giving a refractive index slightly less than unity:

$$n = 1 - \delta + i\beta, \qquad \delta = \frac{\lambda^2}{2\pi}\,\mathrm{Re}(\mathrm{SLD}), \qquad \beta = \frac{\lambda^2}{2\pi}\,\mathrm{Im}(\mathrm{SLD}).$$

The scattering length density (SLD) is

- **X-ray:** $\mathrm{SLD}_x = r_e \rho_e$, where $r_e = 2.818 \times 10^{-15}$ m is the classical electron radius and $\rho_e$ is the electron number density.
- **Neutron:** $\mathrm{SLD}_n = (\rho_m N_A / M) \sum_i n_i b_i$, where $b_i$ is the bound coherent scattering length per element.

Below the **critical edge** $Q_c = 4\sqrt{\pi\,\mathrm{SLD}}$ the wave is totally externally reflected ($R = 1$). Above $Q_c$ each interface reflects a small Fresnel amplitude, and the layer thicknesses set up interference.

The **Parratt recursion** chains Fresnel coefficients from the substrate up to the surface:

$$R_j = \frac{r_j + R_{j+1}\, e^{2 i k_{z,j} d_j}}{1 + r_j R_{j+1}\, e^{2 i k_{z,j} d_j}}, \qquad r_j = \frac{k_{z,j} - k_{z,j+1}}{k_{z,j} + k_{z,j+1}}.$$

Interfacial roughness $\sigma$ damps the Fresnel coefficient by the **Névot–Croce factor** $\exp(-2 k_{z,j} k_{z,j+1} \sigma_j^2)$.

**Kiessig fringes** appear above $Q_c$ from interference between the top and bottom of each film, with periodicity

$$\Delta Q = \frac{2\pi}{t}.$$

A 200 Å film therefore shows fringes spaced by $\Delta Q \approx 0.031$ Å$^{-1}$. Rule of thumb: count fringes between $Q_c$ and your $Q_{\max}$, multiply by $2\pi/(Q_{\max}-Q_c)$, and you have the thickness within ~10%.

---

## 2. What you need

- Layer composition: chemical formula and bulk density (g/cm$^3$) for each layer, **or** a pick from `fitting.reflSLDPresets` for common materials.
- Expected thicknesses (Å) — within a factor of ~3; the fit converges over a wide basin.
- A reflectivity scan as a $(Q, R, \sigma_R)$ table (optional, for fitting). For NCNR data the file also contains a $\sigma_Q$ column for resolution.
- Beam type and energy / wavelength: X-ray (Cu K$\alpha_1$ at 8.048 keV is standard) or neutron (typical $\lambda = 4.75$ Å on PBR, polychromatic on CANDOR).

---

## 3. Compute SLDs for each layer

For X-rays with no absorption edge nearby, just pass formula and density:

```matlab
setupToolbox    % run once to add packages to MATLAB path

si  = calc.xrayNeutron.xraySLD('Si',   2.33);
ox  = calc.xrayNeutron.xraySLD('SiO2', 2.20);
au  = calc.xrayNeutron.xraySLD('Au',   19.32);
fprintf('SLD_x  Si   = %.2f x10^-6 A^-2\n', si.SLDe6);
fprintf('SLD_x  SiO2 = %.2f x10^-6 A^-2\n', ox.SLDe6);
fprintf('SLD_x  Au   = %.2f x10^-6 A^-2\n', au.SLDe6);
```

Expected output (close to the [`reflSLDPresets`](../../+fitting/reflSLDPresets.m) tabulated values):

```
SLD_x  Si   = 19.97 x10^-6 A^-2
SLD_x  SiO2 = 18.87 x10^-6 A^-2
SLD_x  Au   = 124.07 x10^-6 A^-2
```

**Near an absorption edge**, anomalous dispersion matters. Pass the photon energy:

```matlab
fe = calc.xrayNeutron.xraySLD('Fe', 7.874, Energy_keV=8.048);
fprintf('Fe at Cu Ka: SLD = %.2f - i %.2f x10^-6 A^-2\n', ...
        fe.SLDe6, fe.sldImagE6);
% Fe at Cu Ka: SLD = 50.4 - i 6.8  (vs. 59.4 in the f=Z limit)
```

For **neutrons**, the imaginary SLD comes from thermal absorption (1/v absorbers) and is automatic:

```matlab
si_n = calc.xrayNeutron.neutronSLD('Si',   2.33);
au_n = calc.xrayNeutron.neutronSLD('Au',   19.32);
gd_n = calc.xrayNeutron.neutronSLD('Gd2O3', 7.41);
fprintf('SLD_n Si   = %.3f - i %.3f x10^-6 A^-2\n', si_n.SLDe6, si_n.sldImagE6);
fprintf('SLD_n Au   = %.3f - i %.3f x10^-6 A^-2\n', au_n.SLDe6, au_n.sldImagE6);
fprintf('SLD_n Gd2O3= %.3f - i %.3f x10^-6 A^-2  (extreme absorber)\n', ...
        gd_n.SLDe6, gd_n.sldImagE6);
```

A reference table for the running example (X-ray, Cu K$\alpha_1$):

| Layer | Formula | $\rho$ (g/cm$^3$) | SLD$_x$ Re ($10^{-6}$ Å$^{-2}$) | SLD$_x$ Im ($10^{-6}$ Å$^{-2}$) |
|---|---|---|---|---|
| Substrate | Si | 2.33 | 20.0 | 0 |
| Native oxide | SiO$_2$ | 2.20 | 18.9 | 0 |
| Film | Au | 19.32 | 124 | 0.44 |
| Incident | air | — | 0 | 0 |

For quick lookups without a calculator call:

```matlab
p   = fitting.reflSLDPresets();
au  = p(strcmp({p.name}, 'Gold'));
fprintf('Au preset: SLD_x=%.1f, SLD_n=%.2f, iSLD_x=%.3f x10^-6\n', ...
        au.sldX*1e6, au.sldN*1e6, au.sldImag*1e6);
```

---

## 4. Build the layer model

The toolbox layer table is an `[M x 4]` matrix:

| Column | Meaning | Units |
|---|---|---|
| 1 | Thickness | Å |
| 2 | SLD real part | Å$^{-2}$ |
| 3 | SLD imag part (absorption) | Å$^{-2}$ |
| 4 | Roughness $\sigma$ at the interface **above** this layer | Å |

**Layer-stack convention** (see [`parrattRefl.m`](../../+fitting/parrattRefl.m)):

- **Row 1:** incident medium (air / vacuum / D$_2$O), thickness ignored, SLD typically 0.
- **Rows 2..M-1:** thin-film layers, listed top → bottom.
- **Row M:** substrate, semi-infinite, thickness ignored.

For the running example (Si / 30 Å SiO$_2$ / 200 Å Au at Cu K$\alpha_1$):

```matlab
% [thickness(A), SLD_real(A^-2), SLD_imag(A^-2), roughness(A)]
layers = [ ...
    0     0          0          0     ;   % air (incident)
    200   124.07e-6  0.442e-6   3.0   ;   % Au top layer (rough surface ~3 A)
    30    18.87e-6   0          3.0   ;   % SiO2 native oxide
    0     19.97e-6   0          3.0   ];  % Si substrate (semi-infinite)
```

The roughness on row $j$ describes the interface **between row $j$ and row $j-1$** (top of that layer). Set the substrate row's roughness for the SiO$_2$/Si interface, and the top film's roughness for the air / film boundary.

---

## 5. Visualise the SLD profile

Before running the reflectivity calculation, plot the depth profile and sanity-check it:

```matlab
[z, sldZ] = fitting.sldProfile(layers, NPoints=800, Padding=80);

figure;
plot(z, sldZ * 1e6, 'b-', 'LineWidth', 1.5);
xlabel('Depth z (A)');  ylabel('SLD (10^{-6} A^{-2})');
title('Si / SiO_2 / Au depth profile');
grid on;
```

What you should see:

- A flat plateau at SLD$_x \approx 20.0$ on the Si side (depth = total stack thickness).
- A small step down to 18.9 across the Si/SiO$_2$ interface (often invisible — they are nearly contrast-matched for X-rays).
- A large jump up to 124 across SiO$_2$/Au.
- A drop to 0 at the Au surface.
- Smooth error-function transitions whose width matches the per-interface roughness.

If the substrate plateau is at the wrong level, your row order is flipped (see [Section 11](#11-common-pitfalls)).

---

## 6. Forward Parratt simulation

Pick a $Q$ range that covers $Q_c$ and at least 5 fringes. For 200 Å films at X-ray energies, $Q_{\max} = 0.25$ Å$^{-1}$ is plenty:

```matlab
Q = linspace(0.005, 0.25, 600)';        % A^-1
R = fitting.parrattRefl(Q, layers);     % no resolution smearing yet

figure;
semilogy(Q, R, 'b-', 'LineWidth', 1.2);
xlabel('Q (A^{-1})');  ylabel('Reflectivity R');
title('Si / 30 A SiO_2 / 200 A Au — ideal (no smearing)');
ylim([1e-9, 2]);  grid on;
```

Check three features against the physics:

1. **Critical edge.** $Q_c = 4\sqrt{\pi \cdot \mathrm{SLD}}$. For the 200 Å Au top layer, $Q_c \approx 4\sqrt{\pi \cdot 124 \times 10^{-6}} \approx 0.079$ Å$^{-1}$. (Below this the curve sits at $R = 1$.)
2. **Kiessig fringes.** Spacing $\Delta Q = 2\pi / 200 \approx 0.0314$ Å$^{-1}$ in the Au-dominated region.
3. **High-$Q$ damping.** At $Q = 0.2$ Å$^{-1}$, the Névot–Croce factor for $\sigma = 3$ Å gives $\exp(-2 \cdot 0.1^2 \cdot 9) \approx 0.83$ per interface — a smooth, monotonically decaying envelope.

A Lorentzian-like spike at $Q_c$ plus regular fringes is the signature of a sane forward calculation.

---

## 7. Add instrument resolution

Real instruments smear $Q$ by $\sigma_Q(Q)$. Without smearing your simulated curve has unphysically sharp fringes that won't fit the data. Two ways to specify resolution:

**Constant relative resolution** (good for synchrotron and some lab X-ray setups):

```matlab
R3pct = fitting.parrattRefl(Q, layers, Resolution=0.03);   % dQ/Q = 3 %

figure;
semilogy(Q, R, 'k--', Q, R3pct, 'r-', 'LineWidth', 1.2);
xlabel('Q (A^{-1})');  ylabel('R');
legend('Ideal', 'dQ/Q = 3 %', 'Location', 'NE');
title('Effect of instrument resolution on Kiessig fringes');
ylim([1e-9, 2]);  grid on;
```

You should see fringes increasingly damped at high $Q$ (larger $\sigma_Q = 0.03 Q$) while the low-$Q$ critical edge survives.

**Pointwise resolution from NCNR data.** NCNR `.refl` files include a per-point $\sigma_Q$ column from the reductus pipeline. Use it directly:

```matlab
data = parser.importNCNRRefl('SAMPLE.refl');
Qd   = data.time;
Rd   = data.values(:, data.labels == "Intensity");
dRd  = data.values(:, data.labels == "dI");
dQd  = data.values(:, data.labels == "dQ");

Rsim = fitting.parrattRefl(Qd, layers, Resolution=dQd);  % per-point sigma_Q
```

For polarised neutron (PNR) data use [`parser.importNCNRPNR`](../../+parser/importNCNRPNR.m) — it returns the four spin channels in `data.values`.

---

## 8. Compare to measured data

Overlay the model on the data and look for systematic mismatches:

```matlab
figure; hold on;
errorbar(Qd, Rd, dRd, 'k.', 'CapSize', 0, 'DisplayName', 'measured');
plot(Qd, Rsim, 'r-', 'LineWidth', 1.2, 'DisplayName', 'model');
set(gca, 'YScale', 'log');
xlabel('Q (A^{-1})');  ylabel('R');
legend('Location', 'NE');  ylim([1e-7, 2]);  grid on;
title('Data vs. initial model');
```

Diagnose visually:

- **Fringe period off:** thickness wrong. $\Delta Q_{\rm data} > \Delta Q_{\rm model}$ ⇒ film is thinner than guess; $\Delta Q_{\rm data} < \Delta Q_{\rm model}$ ⇒ thicker.
- **Fringe contrast too low / too high:** roughness wrong. Increase $\sigma$ to damp; decrease to amplify.
- **Wrong critical edge:** wrong SLD. Check density and formula. (Underdense porous films are a common cause.)
- **Overall amplitude offset:** scale or background — fit those as nuisance parameters.

---

## 9. Fit the model to data

Wrap `parrattRefl` in a model handle that takes `(Q, p)` and returns `R(Q)`. For our 3-parameter fit (Au thickness, Au roughness, SiO$_2$ thickness), holding SLDs fixed:

```matlab
% p = [t_Au, sigma_Au, t_SiO2]
function R = reflModel(Q, p, dQ, sldAu, isldAu, sldSiO2, sldSi, sigmaTopOx, sigmaSub)
    layersP = [ ...
        0      0          0         0          ;
        p(1)   sldAu      isldAu    p(2)       ;   % Au with free thickness, roughness
        p(3)   sldSiO2    0         sigmaTopOx ;   % SiO2 with free thickness
        0      sldSi      0         sigmaSub   ];
    R = fitting.parrattRefl(Q, layersP, Resolution=dQ);
end
```

Save that as a separate `.m` file (or use an anonymous handle if all extra arguments are bound from the workspace). Then call `fitting.curveFit`:

```matlab
% Bind nuisance parameters into a closure
modelH = @(Q, p) reflModel(Q, p, dQd, ...
            124.07e-6, 0.442e-6, 18.87e-6, 19.97e-6, 3.0, 3.0);

p0 = [200, 3.0, 30];                         % initial guesses (A)
lb = [ 50, 0.5,  5];                         % must be positive, < bulk lattice
ub = [400, 15,  60];                         % SiO2 native oxide rarely > 50 A

% Fit log-R to compress dynamic range — equivalent to weighting each
% point by 1/R^2, which is closer to constant relative error than the
% raw counts gives. For NCNR, prefer Weights = 1./dRd.^2 on R itself.
res = fitting.curveFit(Qd, Rd, modelH, p0, ...
        Lower=lb, Upper=ub, Weights=1./dRd.^2);

fprintf('\nFit results (chi^2_red = %.3f):\n', res.chiSqRed);
names = {'t_Au (A)', 'sigma_Au (A)', 't_SiO2 (A)'};
for k = 1:numel(res.params)
    fprintf('  %-13s = %8.2f  +/-  %.2f\n', names{k}, ...
            res.params(k), res.errors(k));
end
```

A successful fit on a clean Si / 30 Å SiO$_2$ / 200 Å Au sample at Cu K$\alpha_1$ converges in 100–300 iterations and gives $\chi^2_\nu \sim 1$–3 (higher if you didn't pass the per-point uncertainties, since $\chi^2$'s absolute scale is tied to the error bars). See [`docs/theory/fitting.md`](../theory/fitting.md) for goodness-of-fit interpretation.

**Bound discipline.** Always set $t > 0$ and $\sigma \geq 0$. Roughness must be less than half the layer thickness — beyond that the Névot–Croce model breaks down and the SLD profile becomes degenerate (you can no longer tell a thin rough layer from a thick smooth one).

---

## 10. Worked example

**System:** Si / 30 Å SiO$_2$ / 200 Å Au, Cu K$\alpha_1$ ($\lambda = 1.5406$ Å, $E = 8.048$ keV).

**Predicted features:**

- Au $Q_c = 4\sqrt{\pi \cdot 124.07 \times 10^{-6}} = 0.0786$ Å$^{-1}$ — note this is the dominant edge because Au is the thickest, highest-SLD layer.
- Kiessig $\Delta Q = 2\pi / 200 = 0.0314$ Å$^{-1}$ — about 5–6 fringes between $Q_c$ and $Q_{\max} = 0.25$.
- A faint beat envelope from the thin SiO$_2$ at $\Delta Q_{\rm SiO_2} = 2\pi / 30 \approx 0.21$ Å$^{-1}$ — too long to resolve in this $Q$ range, so it shows up as a slow modulation of the fringe amplitude near $Q \sim 0.2$.
- Roughness 3 Å on each interface ⇒ Névot–Croce factor $\sim 0.83$ per interface at $Q = 0.2$ Å$^{-1}$, so deep into the fringe regime $R$ drops by ~50% compared to the perfectly sharp case.

**Sanity checks:**

```matlab
% Predicted critical edge for Au
sldAu = 124.07e-6;
Qc_Au = 4*sqrt(pi*sldAu);    % 0.0786 A^-1
fprintf('Q_c (Au)      = %.4f A^-1\n', Qc_Au);

% Predicted Kiessig spacing for 200 A film
fprintf('DeltaQ Kiessig= %.4f A^-1\n', 2*pi/200);

% Brewster-equivalent angle: 2 theta_c = lambda * Q_c / (2 pi)
lambda = 1.5406;
theta_c = lambda * Qc_Au / (4*pi) * 180/pi;
fprintf('theta_c (Au)  = %.3f deg\n', theta_c);
```

Expected console output:

```
Q_c (Au)      = 0.0786 A^-1
DeltaQ Kiessig= 0.0314 A^-1
theta_c (Au)  = 0.552 deg
```

If the measured data shows a critical edge at 0.078 Å$^{-1}$ and 5 fringes between 0.08 and 0.25 Å$^{-1}$, the gold film is at the design thickness within ~5%. If the edge is at 0.072 the film is underdense (porous evaporation, $\rho \approx 0.85 \rho_{\rm bulk}$).

---

## 11. Common pitfalls

- **Layer-stack ordering reversed.** Swapping incident medium and substrate flips the entire reflectivity curve. The substrate must be the **last row** with the largest SLD typically; the incident medium (air) is the **first row** with SLD $\approx 0$. Always run [Section 5](#5-visualise-the-sld-profile) first and verify the SLD plateau matches the substrate.
- **Mixing X-ray and neutron SLDs.** Au has SLD$_x = 124 \times 10^{-6}$ but SLD$_n = 4.5 \times 10^{-6}$ — a factor of ~28 difference. Always use the right calculator for the beam type. For polarised neutrons the magnetic SLD adds (or subtracts) to the nuclear SLD by polarisation, which `parrattRefl` does **not** handle automatically.
- **Forgetting resolution smearing.** Fringes appear too sharp and amplitude too high. Use `Resolution=` always when comparing to data; for NCNR pass the `dQ` column directly.
- **Bulk density in thin films.** A 50 Å sputtered Au film is often only 80–90% of the bulk density — directly hits the SLD. If $Q_c$ is consistently low, refine density or carry a `dens_Au` parameter in the fit.
- **Roughness greater than thickness/2.** The Névot–Croce factor is a Gaussian approximation that breaks down for $\sigma > t/2$; the SLD profile then no longer resembles a film. The fit may still converge but the parameters become unphysical and degenerate. If your fit pushes $\sigma \to t/2$, add a constraint or simplify the layer structure.
- **Anomalous dispersion near absorption edges.** For Fe, Co, Ni, Cu films at Cu K$\alpha_1$, the f$\,'$ correction can shift SLD by 10–20%. Pass `Energy_keV` to [`xraySLD`](../../+calc/+xrayNeutron/xraySLD.m).
- **Polarised neutron data on `parrattRefl`.** PNR has spin-up and spin-down channels with different effective SLDs (nuclear ± magnetic). Run `parrattRefl` once per channel with the appropriate magnetic SLD added, then compare to the four channels returned by [`importNCNRPNR`](../../+parser/importNCNRPNR.m) separately.
- **Confusing $Q$ and $2\theta$.** $Q = (4\pi/\lambda) \sin\theta$ where $\theta$ is the **incidence** angle (half of $2\theta$). Some XRD parsers report $2\theta$; convert with `calc.xrayNeutron.twoThetaToQ` before passing to `parrattRefl`.

---

## 12. Reporting template

For publication, include:

- **Layer table** of refined parameters with 1$\sigma$ uncertainties:

  | Layer | $t$ (Å) | SLD ($10^{-6}$ Å$^{-2}$) | $\sigma$ (Å) |
  |---|---|---|---|
  | Au | 198.4 ± 0.6 | 124.07 (fixed) | 3.2 ± 0.3 |
  | SiO$_2$ | 27.8 ± 1.5 | 18.87 (fixed) | 3.0 ± 0.4 |
  | Si substrate | $\infty$ | 19.97 (fixed) | 2.8 ± 0.3 |

- **$\chi^2_\nu$** with how it was computed (per-point $\sigma_R$ from data, or assumed weights). The covariance matrix `res.covar` if reviewers ask for parameter correlations.
- **Plot** of $\log_{10} R$ vs. $Q$ with data + model overlaid, plus a residual panel — points should scatter randomly around zero with no systematic trend.
- **Instrument metadata.** For X-ray: source, wavelength or energy, mono/analyzer setup, detector. For neutron: instrument (PBR, MAGIK, CANDOR), polarisation status, wavelength range, $\sigma_Q(Q)$ source.
- **Reproducibility.** Cite the toolbox version and provide the layer matrix used for the final fit.

Example reporting paragraph:

> Specular X-ray reflectometry (Cu K$\alpha_1$, $\lambda = 1.5406$ Å, $\sigma_Q/Q = 3\%$) was fit with the Parratt recursion (Névot–Croce roughness) using the [`fitting.parrattRefl`](../../+fitting/parrattRefl.m) routine in `quantized_matlab`. The Au top layer thickness refined to $198.4 \pm 0.6$ Å with surface roughness $3.2 \pm 0.3$ Å; the native SiO$_2$ interlayer was $27.8 \pm 1.5$ Å with $\sigma = 3.0 \pm 0.4$ Å. Reduced $\chi^2 = 1.7$ over 412 data points, with no significant residual structure (Durbin–Watson 1.96).

---

## 13. Going further

| If you need to... | Use |
|---|---|
| Fit several reflectivity curves with shared substrate | [`fitting.globalCurveFit`](../../+fitting/globalCurveFit.m) |
| Track a Bragg peak in superlattices | Build the period as a repeating unit in `layers`, fit period thickness |
| Posterior distributions for correlated $t$ / $\sigma$ | [`fitting.mcmcSample`](../../+fitting/mcmcSample.m) |
| Fit polarised neutron data | Run `parrattRefl` per spin channel; compare to `parser.importNCNRPNR` outputs |
| Build the layer model interactively | `DiraCulator` → Reflectivity Builder tab |
| Extract dQ from a non-NCNR scan | Pass `Resolution=0.03` (3% relative) as a starting estimate |

The same load → SLD → layer model → simulate → fit workflow applies to all of these — only the layer table grows or the fit dimensionality changes.

---

## 14. References

- Parratt, L.G. "Surface studies of solids by total reflection of X-rays," *Phys. Rev.* **95**, 359 (1954). DOI: [10.1103/PhysRev.95.359](https://doi.org/10.1103/PhysRev.95.359)
- Névot, L. & Croce, P. "Caractérisation des surfaces par réflexion rasante de rayons X," *Rev. Phys. Appl.* **15**, 761 (1980).
- Als-Nielsen, J. & McMorrow, D. *Elements of Modern X-ray Physics*, 2nd ed. (Wiley, 2011), Ch. 3.
- Sears, V.F. "Neutron scattering lengths and cross sections," *Neutron News* **3**(3), 26 (1992).
- Henke, B.L., Gullikson, E.M. & Davis, J.C. "X-ray interactions: photoabsorption, scattering, transmission, and reflection at E = 50–30000 eV, Z = 1–92," *At. Data Nucl. Data Tables* **54**, 181 (1993).
- Russell, T.P. "X-ray and neutron reflectivity for the investigation of polymers," *Mater. Sci. Rep.* **5**, 171 (1990).

For the underlying derivations (Fresnel coefficients, Parratt recursion, Kiessig analysis), see [`docs/theory/reflectometry.md`](../theory/reflectometry.md) and [`docs/theory/thin_films.md`](../theory/thin_films.md). For fit diagnostics and uncertainty propagation, see [`docs/theory/fitting.md`](../theory/fitting.md).
