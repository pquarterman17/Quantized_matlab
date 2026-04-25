# Tutorial: Magnetometry Workflow — Hysteresis and Curie-Weiss Analysis

This tutorial walks through the complete DC-magnetometry workflow for two of the most common measurements made on a Quantum Design VSM, MPMS, or DynaCool: an $M(H)$ hysteresis loop and an $M(T)$ susceptibility curve.

**Research question:** "I have an $M(H)$ hysteresis loop and an $M(T)$ susceptibility curve from a Quantum Design VSM/SQUID. How do I extract coercivity, saturation magnetization, and the Curie-Weiss constants?"

The workflow covers loading, background subtraction, demagnetization correction, hysteresis-loop parameter extraction, unit conversion to $\mu_B$/atom, and a Curie-Weiss fit on the paramagnetic susceptibility.

See [`docs/theory/magnetometry.md`](../theory/magnetometry.md) for the underlying physics and formula derivations.

---

## 1. Physics background in 60 seconds

**What hysteresis tells you.** A hysteresis loop $M(H)$ is the fingerprint of a magnetic material's response to an applied field. The shape encodes the dominant magnetic regime:

- **Ferromagnet (FM):** open loop with finite coercivity $H_c$ and remanence $M_r$. The loop traces an irreversible domain-wall / coherent-rotation switching path. $M$ saturates at $\pm M_s$ for $|H| \gg H_c$.
- **Superparamagnet (SPM):** $S$-shaped curve that closes ($H_c \approx 0$, $M_r \approx 0$) above the blocking temperature, but reopens below it. Typically Langevin- or Brillouin-like.
- **Paramagnet (PM) / diamagnet:** linear $M(H)$ with no hysteresis, slope $\chi = \partial M / \partial H$. Diamagnets have $\chi < 0$; paramagnets have $\chi > 0$ that grows with $1/T$.

**The four loop parameters:**

- $H_c$ — coercive field, the reverse field needed to drive $M$ back to zero.
- $M_r$ — remanent magnetization, the value of $M$ at $H = 0$ after saturation.
- $M_s$ — saturation magnetization, the high-field plateau.
- Squareness $S = M_r / M_s$ — closeness to a perfect rectangular loop ($S=1$ ideal hard magnet, $S=0.5$ random Stoner-Wohlfarth ensemble).

**Curie-Weiss law.** Above any ordering transition the susceptibility of a localized-moment paramagnet follows

$$\chi(T) = \frac{C}{T - \theta_{\text{CW}}}, \qquad \mu_{\text{eff}} = \sqrt{\frac{3 k_B C}{N_A \mu_B^2}}$$

The Weiss temperature $\theta_{\text{CW}}$ encodes the sign and strength of the dominant exchange: $\theta_{\text{CW}} > 0$ is FM-like, $\theta_{\text{CW}} < 0$ is AFM-like, $\theta_{\text{CW}} \approx 0$ is an ideal Curie paramagnet. The effective moment $\mu_{\text{eff}}$ should match $g_J\sqrt{J(J+1)}\,\mu_B$ for free-ion $J$ ground states (e.g. 7.94 $\mu_B$ for Gd$^{3+}$, $S=7/2$).

Cross-link: [`docs/theory/magnetometry.md`](../theory/magnetometry.md) for the derivations and the full FM/AFM/SPM hierarchy.

---

## 2. What you need

Checklist before you start:

- [ ] A `.dat` file from a Quantum Design **MPMS**, **VSM**, or **DynaCool**. Either an $M$-vs-$H$ scan at fixed $T$ or an $M$-vs-$T$ scan at fixed $H$.
- [ ] **Sample mass** (mg) or **volume** (cm³). Mass is easy from a microbalance; volume needs density or measured dimensions.
- [ ] **Sample shape** for the demagnetization correction. Sphere, thin film, cylinder, prolate spheroid, or oblate spheroid.
- [ ] **Field range covered.** For $M_s$ you must reach saturation — typically $|H| > 5\,H_c$ for soft FMs, $|H| > 2$–5 T for hard FMs and rare-earth oxides.
- [ ] **Temperature range.** For Curie-Weiss, fit only the paramagnetic regime $T > T_C$ (FM) or $T > T_N$ (AFM) — usually $T > 2\,T_C$ as a rule of thumb.

Optional but recommended:

- [ ] A bare-substrate measurement under identical conditions (for clean background subtraction).
- [ ] An empty-straw / sample-holder measurement (often pre-tabulated by the QD instrument).

---

## 3. Load and inspect

```matlab
setupToolbox    % run once to add packages to MATLAB path

% Hysteresis loop: M vs H at fixed T
loop = parser.importQDVSM('sample.dat', 'XAxis', 'field', 'YAxis', 'moment');

% Susceptibility curve: M vs T at fixed H
chiData = parser.importQDVSM('sample.dat', 'XAxis', 'temp', 'YAxis', 'moment');
```

Both calls return the unified struct with `.time`, `.values`, `.labels`, `.units`, and `.metadata`. The `XAxis`/`YAxis` shorthands accept `'field'`, `'moment'`, `'temp'`, `'time'`, `'stderr'`, `'all'` (see CLAUDE.md). Use `parser.importMPMS` (sister parser) or `parser.importAuto` (auto-detect) if you do not know the instrument up front.

Resolve the columns by label rather than by index — the column order varies between Quantum Design firmware versions:

```matlab
% Robust column resolution by label
idxH = find(loop.labels == "Magnetic Field (Oe)", 1);
idxM = find(loop.labels == "Moment (emu)", 1);
H = loop.values(:, idxH);
M = loop.values(:, idxM);

figure;
plot(H/1e4, M, 'k.-');
xlabel('H (T)'); ylabel('M (emu)');
title('Raw M(H) loop — sanity check');
grid on;
```

Sanity-check the raw plot before any processing:

- Does the loop **close** at the high-field ends? (Open loops indicate drift or incomplete saturation.)
- Is **saturation** reached? The high-field branches should be flat or have a small linear (paramagnetic / diamagnetic) slope only.
- Are **both branches** present? You need ascending and descending field sweeps for $H_c$ and $M_r$.
- Are there **ghost spikes or dropouts**? Quantum Design files occasionally have fit-flag rejections; remove rows where `Moment Std. Err.` is anomalously large.

---

## 4. Background subtraction

Most magnetometry samples sit on a substrate (Si, MgO, sapphire) or in a holder (gelcap, straw) that contributes a linear paramagnetic or diamagnetic background. Si is diamagnetic with $\chi \approx -3 \times 10^{-6}$ emu/(cm³·Oe). For a thin-film sample on a 5×5×0.5 mm Si substrate the substrate moment can rival or exceed the film moment at high field.

**Subtract the linear high-field slope before reading $M_s$**, otherwise you will under- or over-estimate it by exactly that slope contribution:

```matlab
% Identify the high-field tails (top 20% of |H|)
Hmax = max(abs(H));
highH = abs(H) > 0.8 * Hmax;

% Linear fit to both tails together — slope = chi_d (diamagnetic susceptibility)
p = polyfit(H(highH), M(highH), 1);
chi_d = p(1);                    % emu/Oe
fprintf('Diamagnetic slope = %.3e emu/Oe\n', chi_d);

% Subtract chi_d * H from the entire loop (keep only the FM contribution)
M_corr = M - chi_d * H;          % retain offset p(2) — it absorbs the constant offset

figure;
plot(H/1e4, M, 'b.-', H/1e4, M_corr, 'r.-');
xlabel('H (T)'); ylabel('M (emu)');
legend('Raw', 'Background subtracted', 'Location', 'best');
title('Effect of linear background subtraction');
grid on;
```

The cross-link to [`docs/theory/statistics.md`](../theory/statistics.md) explains the linear-regression error estimate for $\chi_d$ — this slope inherits the noise of the high-field tail and propagates into your final $M_s$ value.

**Caveat:** if the substrate is paramagnetic (e.g. Gd-doped) or if the sample itself has a paramagnetic component, the high-field slope is no longer purely diamagnetic. In that case, measure a bare substrate under identical conditions and subtract its loop point-wise.

---

## 5. Demagnetization correction

The magnetometer applies field $H_{\text{ext}}$ to the sample, but the field inside is reduced by the demagnetizing field of the sample itself:

$$H_{\text{int}} = H_{\text{ext}} - N M \quad \text{(SI)}, \qquad H_{\text{int}} = H_{\text{ext}} - 4\pi N M \quad \text{(CGS)}$$

The factor $N$ (0 to 1) depends only on geometry. Compute it with `calc.magnetic.demagFactor`:

```matlab
% Example: thin film measured out-of-plane (field along film normal)
r  = calc.magnetic.demagFactor('thin_film');
Nz = r.Nz;                       % 1 for thin film out-of-plane

% Apply the CGS correction (Oe and emu/cm³)
V    = 0.50 * 0.50 * 1e-5;       % 5x5 mm film, 100 nm thick → cm³
M_v  = M_corr / V;               % emu/cm³
H_int = H - 4*pi * Nz * M_v;     % Oe
```

Sample-shape guidance, sign conventions, and the full CGS-vs-SI table are covered in [`demag_correction_vsm.md`](demag_correction_vsm.md). Use that tutorial when your sample is not a thin film, when you need to choose between cylinder / oblate / prolate spheroid models, or when the corrected loop looks unphysical.

---

## 6. Hysteresis loop analysis

With the loop background-subtracted and demag-corrected, extract all four loop parameters in one call:

```matlab
params = utilities.hysteresisAnalysis(H_int, M_corr);

fprintf('Hc        = %.1f Oe   (mean of two branches)\n', params.HcMean);
fprintf('Mr        = %.4g emu  (mean of two branches)\n', params.MrMean);
fprintf('Ms        = %.4g emu  (mean of |+sat|, |-sat|)\n', params.MsMean);
fprintf('Squareness = %.3f\n', params.squareness);
fprintf('Loop area = %.3e erg/cycle (energy product)\n', params.loopArea);
```

The function auto-detects ascending and descending branches, returns per-branch values in `params.Hc`, `params.Mr`, `params.Ms` (each a 2-element vector) plus the scalar means `HcMean`, `MrMean`, `MsMean`. The `params.SFD` substruct gives the switching-field distribution width (FWHM of $dM/dH$ near $H_c$).

Worked example — a 100 nm Co$_{50}$Fe$_{50}$ film on Si, measured in plane:

```
Hc        = 24.7 Oe   (mean of two branches)
Mr        = 4.21e-04 emu  (mean of two branches)
Ms        = 4.45e-04 emu  (mean of |+sat|, |-sat|)
Squareness = 0.946
Loop area = 8.93e-02 erg/cycle (energy product)
```

Volume-normalized: with $V = 0.50 \times 0.50 \times 1.0\times10^{-5}\,\text{cm}^3 = 2.5\times10^{-6}\,\text{cm}^3$, the film $M_s = 4.45\times10^{-4} / 2.5\times10^{-6} \approx 1780$ emu/cm³. (Bulk Co$_{50}$Fe$_{50}$: $\sim 1900$ emu/cm³ — your sample saturates 6% below bulk, plausible for a sputtered film with slight off-stoichiometry.)

---

## 7. Unit conversions: emu → A/m → $\mu_B$/atom

The CGS-to-SI conversion for volumetric magnetization is

$$1\;\text{emu/cm}^3 = 1000\;\text{A/m}$$

so $M_s = 1780$ emu/cm³ $= 1.78 \times 10^6$ A/m. Single-line conversion:

```matlab
Ms_volumetric = params.MsMean / V;       % emu/cm³
Ms_SI         = Ms_volumetric * 1000;    % A/m
fprintf('M_s = %.0f emu/cm^3 = %.3e A/m\n', Ms_volumetric, Ms_SI);
```

For a per-atom value in Bohr magnetons, use either `bohrMagnetonConvert` (for a single moment) or `momentPerAtom` (which folds in the volume and atomic number density):

```matlab
% Atomic number density of CoFe (BCC, a = 2.86 Å, 2 atoms/unit cell):
a_lattice = 2.86e-8;                     % cm
n_atoms   = 2 / a_lattice^3;             % atoms/cm³  ≈ 8.55e22

r = calc.magnetic.momentPerAtom(params.MsMean, V, n_atoms);
fprintf('μ_atom = %.3f μ_B\n', r.muB);
```

Or for a quick check on the total moment:

```matlab
r = calc.magnetic.bohrMagnetonConvert(params.MsMean, 'emu');
fprintf('Total moment = %.3e μ_B\n', r.muB);
```

Worked example — Ni at $M_s = 484$ emu/cm³, lattice constant 3.52 Å (FCC, 4 atoms/cell), so $n = 4/(3.52\times10^{-8})^3 \approx 9.18 \times 10^{22}$ atoms/cm³:

$$\mu_{\text{atom}} = \frac{M_s}{n \cdot \mu_B^{\text{cgs}}} = \frac{484}{9.18\times10^{22} \cdot 9.274\times10^{-21}} \approx 0.57\;\mu_B/\text{atom}$$

The textbook value for Ni is 0.606 $\mu_B$/atom. The 5% shortfall is realistic noise in a benchtop measurement.

---

## 8. Curie-Weiss fit on M(T) data

For a paramagnetic sample the susceptibility $\chi(T) = M(T)/H$ at fixed (small) field is approximately the differential susceptibility, provided $H$ is well below saturation. Compute $\chi$, fit $1/\chi$ vs $T$, and extract $C$ and $\theta_{\text{CW}}$:

```matlab
% Load M vs T at a fixed small field (typically 100 Oe to 1 kOe)
chiData = parser.importQDVSM('sample.dat', 'XAxis', 'temp', 'YAxis', 'moment');

idxT = find(chiData.labels == "Temperature (K)", 1);
idxM = find(chiData.labels == "Moment (emu)",    1);
T = chiData.values(:, idxT);
M_T = chiData.values(:, idxM);

H_meas = 1000;                           % Oe — the fixed measurement field

% Compute susceptibility (per-mole if you know the molar quantity, otherwise raw)
chi = M_T / H_meas;                      % emu/Oe

% Fit Curie-Weiss in the paramagnetic regime (above any transition)
result = calc.magnetic.curieWeiss(T, chi, 'FitRange', [150 350]);

fprintf('Curie constant C = %.3f emu·K/Oe\n', result.C);
fprintf('Weiss temp θ_CW = %.1f K\n',          result.theta_CW);
fprintf('Effective moment μ_eff = %.2f μ_B\n', result.mu_eff);
fprintf('Fit R²           = %.4f\n',           result.R2);

% Plot 1/chi vs T with the fit
figure;
plot(T, result.invChi, 'k.', 'MarkerSize', 8);
hold on;
Tfit = linspace(min(T), max(T), 200);
plot(Tfit, result.fitLine(1)*Tfit + result.fitLine(2), 'r-', 'LineWidth', 1.5);
xlabel('T (K)'); ylabel('1/\chi (Oe/emu)');
title(sprintf('Curie-Weiss fit: \\theta = %.1f K, \\mu_{eff} = %.2f \\mu_B', ...
    result.theta_CW, result.mu_eff));
grid on;
```

**Worked example — Gd$_2$O$_3$.** The free-ion ground state of Gd$^{3+}$ is $^8S_{7/2}$, predicting $\mu_{\text{eff}} = g_J\sqrt{J(J+1)}\,\mu_B = 2\sqrt{63/4}\,\mu_B = 7.94\,\mu_B$. Gd$_2$O$_3$ is a weak antiferromagnet ($T_N \approx 3.8$ K), so for $T > 50$ K the Curie-Weiss law applies with $\theta_{\text{CW}} \approx 0$ K and $\mu_{\text{eff}} \approx 7.94\,\mu_B$ per Gd ion. A typical fit returns:

```
Curie constant C = 7.88 emu·K/Oe
Weiss temp θ_CW = -1.3 K
Effective moment μ_eff = 7.93 μ_B
Fit R²           = 0.9998
```

The slight negative $\theta_{\text{CW}}$ confirms weak AFM exchange. The 0.13% discrepancy in $\mu_{\text{eff}}$ from the free-ion value is well within sample-mass and field-calibration uncertainty.

For molar normalization: if you measured a known mole quantity, normalize $\chi$ to emu/(Oe·mol) before calling `curieWeiss`, and the returned $\mu_{\text{eff}}$ will be physically meaningful per formula unit. The function uses the standard CGS conversion $\mu_{\text{eff}} = \sqrt{7.9735\,C}$ (Bohr magnetons, with $C$ in emu·K/(Oe·mol)).

---

## 9. Common pitfalls

- **Forgot the diamagnetic substrate.** Skipping background subtraction underestimates $M_s$ by the slope contribution at high field, and creates phantom low-$T$ susceptibility tails because the substrate's diamagnetism dominates the small Curie tail of dilute paramagnets.
- **Reading $M_s$ from an unsaturated sample.** The high-field branch should have zero slope (after background subtraction). A residual slope means the sample has not saturated — either increase the field range, or fit the high-field tail to $M(H) = M_s + a/H + b/H^2$ and extrapolate to $1/H \to 0$.
- **Demag correction in the wrong unit convention.** SI uses $H_{\text{int}} = H_{\text{ext}} - N M$; CGS uses $H_{\text{int}} = H_{\text{ext}} - 4\pi N M$. A factor-of-12.57 mistake makes the corrected $H_c$ either grow huge or go negative. See `demag_correction_vsm.md` for the convention table.
- **Sample mass / volume calibration dominates the $M_s$ error budget.** Quantum Design instruments are typically accurate to 0.1% in moment, but a 1 mg uncertainty in a 5 mg sample is a 20% volume error — and that error propagates linearly into $M_s$.
- **Curie-Weiss fit on data with FM contamination.** A trace ferromagnetic phase (e.g. an Fe inclusion) will dominate the low-field $M(T)$ at low temperatures, producing a fictitiously steep $1/\chi$ near zero and a large negative $\theta_{\text{CW}}$ that misrepresents the bulk exchange. Diagnose by measuring at multiple fields: if $\chi(T) = M/H$ depends on $H$, you have nonlinear contamination.
- **Conflating $\theta_{\text{CW}}$ with $T_C$.** Mean-field theory gives $\theta_{\text{CW}} = T_C$ for an idealized FM, but real materials have $|\theta_{\text{CW}}| \neq T_C$ because of frustration, fluctuations, and short-range correlations. The ratio $f = |\theta_{\text{CW}}|/T_N$ is the *frustration index* in geometrically frustrated AFMs (e.g. $f > 10$ in spin-ice pyrochlores).
- **Ignoring the paramagnetic regime cutoff.** A Curie-Weiss fit must use only data well above the ordering temperature. Including the critical fluctuation regime curves $1/\chi$ downward and pulls $\theta_{\text{CW}}$ toward $T_C$ from below. Rule of thumb: fit $T > 2\,T_C$.

---

## 10. Reporting template

For publication-grade reporting of an $M(H)$ loop and an $M(T)$ Curie-Weiss fit, quote:

**Hysteresis:**
- $H_c$ in Oe (or kA/m) with $\pm 1\sigma$ from `params.Hc(1) - params.Hc(2)` spread.
- $M_s$ in **all three units**: emu, emu/cm³, and $\mu_B$/atom (or formula unit).
- $M_s$ also in SI (A/m) for cross-comparison with European literature.
- Squareness $S = M_r/M_s$.
- Sample dimensions and mass (mg or μg) — explicitly state which was used to compute the volume.
- Field range $|H_{\text{max}}|$ used for $M_s$ averaging (the `SaturationFraction` setting in `hysteresisAnalysis`).
- Whether the data were demag-corrected (yes/no, and the $N$ factor + geometry).
- Temperature at which the loop was measured.

**Curie-Weiss:**
- Curie constant $C$ in emu·K/(Oe·mol) — molar normalization required for $\mu_{\text{eff}}$ to be physical.
- Weiss temperature $\theta_{\text{CW}}$ in K.
- Effective moment $\mu_{\text{eff}}$ in $\mu_B$ per formula unit, with the comparison to the free-ion value.
- Fit range $[T_{\min}, T_{\max}]$ in K.
- Fit $R^2$ and (if available) the $1\sigma$ uncertainty on $C$ and $\theta_{\text{CW}}$ from the linear regression.
- Measurement field $H$ — confirm it is in the linear-response regime ($H \ll k_B T / \mu_{\text{eff}}$).

Example reporting paragraph:

> The 100 nm Co$_{50}$Fe$_{50}$ film was measured at 300 K on a Quantum Design VSM with field swept from $\pm 1$ T at 10 Oe/s. After subtracting a linear diamagnetic background ($\chi_d = -2.9 \times 10^{-7}$ emu/Oe from the high-field tails $|H| > 0.8$ T) and applying the out-of-plane demagnetization correction ($N_z = 1$), the loop yielded $H_c = 24.7 \pm 0.3$ Oe, $M_s = 1780 \pm 90$ emu/cm³ ($1.78 \times 10^6$ A/m, $2.1\,\mu_B$/atom), $M_r/M_s = 0.95$. The Gd$_2$O$_3$ powder sample was measured at $H = 1$ kOe from 5–350 K; a Curie-Weiss fit over $T \in [150, 350]$ K returned $C = 7.88$ emu·K/(Oe·mol·Gd), $\theta_{\text{CW}} = -1.3$ K (weak AFM), $\mu_{\text{eff}} = 7.93\,\mu_B$ ($R^2 = 0.9998$), in excellent agreement with the Gd$^{3+}$ free-ion value of $7.94\,\mu_B$.

---

## 11. References

- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009. Ch. 2 (demag), Ch. 3 (paramagnetism / Curie-Weiss), Ch. 9 (hysteresis).
- Kittel, C., *Introduction to Solid State Physics*, 8th ed., Wiley, 2005. Ch. 11–12.
- O'Handley, R.C., *Modern Magnetic Materials: Principles and Applications*, Wiley, 2000. Ch. 1–4.
- Quantum Design, *Application Note 1014-213, "Subtraction of Sample Holder Background from DC Magnetization Measurements,"* San Diego, 2002.
- Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis*, 3rd ed., McGraw-Hill, 2003. Ch. 6 (linear regression for the diamagnetic-slope fit).

For derivations of every formula behind the toolbox calls, see [`docs/theory/magnetometry.md`](../theory/magnetometry.md). For the demagnetization-correction details, see the sibling tutorial [`demag_correction_vsm.md`](demag_correction_vsm.md). For the linear-regression error propagation used in the background-subtraction step, see [`docs/theory/statistics.md`](../theory/statistics.md).
