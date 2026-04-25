# Tutorial: End-to-end Superconductor Characterization

This tutorial walks through the complete characterization pipeline for a new superconductor candidate measured on a Quantum Design PPMS or MPMS. Starting from raw R(T), R(H), and M(H) data files, we extract the transition temperature $T_c$, the upper critical field $H_{c2}(T)$ and its zero-temperature extrapolation $H_{c2}(0)$, the Bean critical current density $J_c(H)$, the BCS weak-coupling gap $\Delta(0)$, and the derived microscopic length scales $\xi_0$, $\lambda_L$, and the Ginzburg-Landau parameter $\kappa$.

**Research question:** "I have R(T), M(H), and R(H) data on a new superconductor candidate. How do I extract $T_c$, $H_{c2}(T)$, $J_c(H)$, and the BCS gap, and how do they relate?"

The Bean $J_c$ extraction (Stage 4) is treated here in summary only — the full step-by-step is documented in [`bean_jc_extraction.md`](bean_jc_extraction.md).

See [`docs/theory/superconductivity.md`](../theory/superconductivity.md) for the underlying physics and derivations.

---

## 1. Physics background in 60 seconds

A superconductor is characterized by a single transition temperature $T_c$, but a single number is rarely enough. The full classification requires three more measurements:

- **Critical fields.** A type-I superconductor has one critical field $H_c(T)$ and expels flux entirely (Meissner state). A type-II has two — a lower $H_{c1}$ below which flux is fully expelled, and an upper $H_{c2}$ above which superconductivity is destroyed. The boundary between type-I and type-II is set by the GL parameter $\kappa = \lambda_L/\xi_0$: type-I if $\kappa < 1/\sqrt{2}$, type-II otherwise.

- **Pinning and $J_c$.** In the mixed state ($H_{c1} < H < H_{c2}$) flux enters as Abrikosov vortices. The maximum supercurrent the sample can carry without vortex motion is $J_c$ — set by defect-mediated pinning, not by the intrinsic pair amplitude. Bean's critical-state hypothesis turns the hysteresis loop width $\Delta M$ into $J_c(H)$ via geometry factors.

- **Pairing strength.** BCS weak coupling predicts $2\Delta(0)/k_B T_c = 2 \times 1.764 = 3.528$. Strong-coupling phonon-mediated pairs (Pb, Hg) show $\sim 4.3$. Unconventional gap structures (d-wave, p-wave) often give larger or anisotropic ratios. Comparing optical/STS gap data to $1.764 k_B T_c$ tells you which regime you are in.

**$H_{c2}(T)$ near $T_c$ — the WHH formula.** The Werthamer-Helfand-Hohenberg result for the orbital-limited $H_{c2}$ in the dirty limit gives, at zero temperature:

$$H_{c2}^\mathrm{orb}(0) = 0.693\,T_c \left|\frac{dH_{c2}}{dT}\right|_{T=T_c}$$

(in Tesla when $T$ is in K and $|dH_{c2}/dT|$ in T/K). This bypasses long extrapolations; you just measure the slope of $H_{c2}(T)$ near $T_c$ and apply the prefactor 0.693.

For full derivations of all of the above, see [`docs/theory/superconductivity.md`](../theory/superconductivity.md). For Drude/normal-state context behind R(T) above $T_c$, see [`docs/theory/transport.md`](../theory/transport.md).

---

## 2. What you need

Minimum dataset:

- An R(T) sweep at zero applied field, spanning at least from $\sim 0.5\,T_c$ to $\sim 2\,T_c$, with enough points across the transition to resolve the width (10 K span / 200 points is comfortable).

Ideal full characterization adds:

- **R(T) at multiple fixed fields** $\{H_1, H_2, \ldots\}$ (typical: 0, 1, 3, 5, 9 T) — for $H_{c2}(T)$.
- **Or: R(H) at multiple fixed temperatures** $\{T_1, T_2, \ldots\}$ — equivalent information, often faster to collect.
- **M(H) loops below $T_c$** at one or more temperatures — for Bean $J_c$.
- **Sample dimensions in cm** — for the Bean formula.
- **Optional spectroscopic gap** from STS, ARPES, point-contact, or tunneling — for the BCS comparison in Stage 5.

Typical PPMS protocol:

1. R(T) at $H = 0$, 2 K to 30 K, 0.5 K/min, in 4-probe ETO mode.
2. R(T) at $H = 1, 3, 5, 7, 9$ T, same temperature window. Each sweep takes ~1 hour.
3. M(H) at $T = 5$ K, $-9$ to $+9$ T and back, in VSM mode.

Total ~10 hours unattended. Files end up as `.dat` in the standard QD format and are imported with `parser.importPPMS` or `parser.importQDVSM`.

---

## 3. Stage 1 — $T_c$ from R(T)

```matlab
setupToolbox    % run once

% Load R(T) at zero field
data = parser.importPPMS('NbN_film_RvsT_0T.dat', ...
            XAxis='temp', YAxis='resistance');

T = data.values(:, 1);
R = data.values(:, 2);

figure;
plot(T, R, 'k.-');
xlabel('T (K)'); ylabel('R (\Omega)');
title('R(T) at H = 0');
grid on;
```

Run `extractTc` with `Method='all'` to get every common criterion at once:

```matlab
tcRes = calc.superconductor.extractTc(T, R);   % default Method='all'

fprintf('Tc (onset, 90%%)    = %.3f K\n', tcRes.Tc_onset);
fprintf('Tc (midpoint, 50%%) = %.3f K\n', tcRes.Tc_midpoint);
fprintf('Tc (offset, 10%%)   = %.3f K\n', tcRes.Tc_offset);
fprintf('Tc (max dR/dT)     = %.3f K\n', tcRes.Tc_derivative);
fprintf('Transition width    = %.3f K\n', tcRes.transitionWidth);
fprintf('R_normal            = %.3e Ohm\n', tcRes.R_normal);
```

Worked example output for an NbN thin film:

```
Tc (onset, 90%)    = 16.21 K
Tc (midpoint, 50%) = 16.05 K
Tc (offset, 10%)   = 15.91 K
Tc (max dR/dT)     = 16.04 K
Transition width    = 0.30 K
R_normal            = 1.42e+02 Ohm
```

### How to choose the criterion

The four definitions agree to within $\Delta T_c$ for sharp transitions. They diverge for broad transitions (granular films, percolation through a non-uniform $T_c$ landscape, fluctuation-broadened transitions in disordered systems). Conventions:

- **Onset (90%)** — used in the inhomogeneity-tolerant literature (cuprates, iron pnictides). Optimistic for samples with tails.
- **Midpoint (50%)** — most common for clean BCS films and bulk crystals.
- **Offset (10%)** — pessimistic; a true zero-resistance state. Useful as a lower bound when comparing thermometric (specific-heat) and transport $T_c$.
- **Derivative (max $|dR/dT|$)** — the most robust against background drift; equivalent to midpoint for a symmetric transition.

**Always state the criterion** when reporting, e.g. "$T_c^\mathrm{mid} = 16.05$ K, $\Delta T_c = 0.30$ K (onset–offset)". Comparing your "onset" to a competitor's "midpoint" is a recurring source of disagreement in the literature.

---

## 4. Stage 2 — $H_{c2}(T)$ from R(T) at multiple fields

For each field $H_i$, repeat the R(T) sweep and extract a field-dependent $T_c(H)$ — equivalently, the locus of points where the resistance drops to 50% of its normal-state value defines $H_{c2}(T)$:

```matlab
fields    = [0, 1, 3, 5, 7, 9];      % Tesla
TcAtField = zeros(size(fields));
files     = {'NbN_RvsT_0T.dat', 'NbN_RvsT_1T.dat', ...
             'NbN_RvsT_3T.dat', 'NbN_RvsT_5T.dat', ...
             'NbN_RvsT_7T.dat', 'NbN_RvsT_9T.dat'};

for k = 1:numel(fields)
    d = parser.importPPMS(files{k}, XAxis='temp', YAxis='resistance');
    Tk = d.values(:,1);  Rk = d.values(:,2);
    rk = calc.superconductor.extractTc(Tk, Rk, Method='midpoint');
    TcAtField(k) = rk.Tc_midpoint;
end

figure;
plot(TcAtField, fields, 'ko-', LineWidth=1.5, MarkerFaceColor='k');
xlabel('T (K)'); ylabel('H_{c2} (T)');
title('Upper critical field locus');
grid on;
```

Equivalently, sweep field at fixed T (R(H) curves) and pick the $H_{c2}$ at 50% $R_n$ for each temperature:

```matlab
% Alternative: R(H) at fixed temperatures
temps = [4, 8, 12, 14, 15, 15.5];
Hc2   = zeros(size(temps));
for k = 1:numel(temps)
    d = parser.importPPMS(sprintf('NbN_RvsH_%gK.dat', temps(k)), ...
            XAxis='field', YAxis='resistance');
    Hk = d.values(:,1) / 1e4;        % Oe -> T
    Rk = d.values(:,2);
    Rn = max(Rk);
    Hc2(k) = interp1(Rk, abs(Hk), 0.5*Rn, 'linear');
end
```

### WHH extrapolation to $H_{c2}(0)$

Fit the $H_{c2}(T)$ data near $T_c$ to extract the slope $|dH_{c2}/dT|_{T_c}$, then apply WHH. The toolbox call is `criticalFields`, but it expects the parameters that emerge from the fit, so we do the fit ourselves first:

```matlab
% Linear fit to H_c2(T) near Tc -- use the top few field points only
nearTc = TcAtField > 0.7 * max(TcAtField);
p = polyfit(TcAtField(nearTc), fields(nearTc), 1);
slope    = p(1);                         % dHc2/dT in T/K (negative)
Tc0      = -p(2) / slope;                % T-axis intercept
fprintf('|dHc2/dT|_Tc = %.3f T/K\n', abs(slope));
fprintf('Tc (zero field) from fit = %.2f K\n', Tc0);

% WHH zero-T extrapolation
Hc2_0_orb = 0.693 * Tc0 * abs(slope);
fprintf('Hc2(0) [WHH orbital] = %.2f T\n', Hc2_0_orb);
```

For a typical NbN film with $T_c = 16.05$ K and $|dH_{c2}/dT|_{T_c} \approx 1.8$ T/K:

$$H_{c2}(0) \approx 0.693 \times 16.05 \times 1.8 \approx 20\,\mathrm{T}$$

To get $H_{c2}(T)$ at any specific temperature with full type-II classification (and Hc1 if you provide $\lambda$, $\xi$), call:

```matlab
hcRes = calc.superconductor.criticalFields( ...
            Hc0=200,         ...   % thermodynamic Hc(0) in Oe (estimated)
            Tc=16.05,        ...
            T=4.2,           ...
            lambda=200,      ...   % from Stage 3 below, in nm
            xi=4.0);               % from Stage 3 below, in nm

fprintf('Type:  %s\n', hcRes.type);
fprintf('Hc1:   %.2f Oe\n', hcRes.Hc1);
fprintf('Hc2:   %.3e Oe = %.2f T\n', hcRes.Hc2, hcRes.Hc2/1e4);
```

---

## 5. Stage 3 — coherence length, penetration depth, GL classification

Once $H_{c2}(0)$ is known, the GL coherence length follows from the flux-quantum relation:

$$\xi_0 = \sqrt{\frac{\Phi_0}{2\pi H_{c2}(0)}}$$

with $\Phi_0 = 2.068 \times 10^{-15}$ Wb (or $2.068 \times 10^{-7}$ G·cm$^2$). Numerically: $\xi_0\,[\mathrm{nm}] = 18.1 / \sqrt{H_{c2}(0)\,[\mathrm{T}]}$.

```matlab
Hc2_0 = 20.0;                                  % Tesla, from Stage 2
xi0_nm = 18.1 / sqrt(Hc2_0);
fprintf('xi0 = %.2f nm\n', xi0_nm);            % ~4.05 nm for Hc2(0)=20 T
```

Or look up `xi(T)` at the measurement temperature:

```matlab
xiRes = calc.superconductor.coherenceLength(xi0=xi0_nm, T=4.2, Tc=16.05);
fprintf('xi(4.2 K) = %.2f nm\n', xiRes.xi);
```

The London penetration depth $\lambda_L$ is harder to extract from transport alone — it is best measured directly via mutual inductance, microwave surface impedance, muon spin rotation, or optical conductivity. If you have a $\lambda_0$ value (from a separate measurement or a clean BCS estimate from the carrier density), feed it in:

```matlab
lamRes = calc.superconductor.londonDepth( ...
            lambda0=200, T=4.2, Tc=16.05);
fprintf('lambda(4.2 K) = %.1f nm\n', lamRes.lambda);
```

Or use a material preset if your sample matches a tabulated entry:

```matlab
lamRes = calc.superconductor.londonDepth(Material='Nb', T=4.2);
```

The GL parameter and type-I/II classification:

```matlab
glRes = calc.superconductor.glParameter( ...
            lambda=lamRes.lambda, xi=xiRes.xi);
fprintf('kappa = %.2f  (type %s)\n', glRes.kappa, glRes.type);
```

For our NbN example: $\xi(4.2\,\mathrm{K}) \approx 4.1$ nm, $\lambda(4.2\,\mathrm{K}) \approx 210$ nm, so $\kappa \approx 51$ — strongly type-II, well above the $1/\sqrt{2} \approx 0.71$ boundary.

| Material | $T_c$ (K) | $\xi_0$ (nm) | $\lambda_L$ (nm) | $\kappa$ | Type |
|---|---|---|---|---|---|
| Al | 1.2 | ~1600 | ~50 | 0.03 | I |
| Pb | 7.2 | ~80 | ~40 | 0.5 | I |
| Nb | 9.25 | ~38 | ~39 | 1.0 | II (borderline) |
| NbN | 16 | ~4 | ~200 | 50 | II |
| YBCO (ab) | 92 | ~1.5 | ~150 | ~100 | II |
| MgB$_2$ | 39 | ~6 | ~140 | ~25 | II |

---

## 6. Stage 4 — Bean $J_c(H)$ from M(H) (summary)

This stage is documented in detail in [`bean_jc_extraction.md`](bean_jc_extraction.md). The condensed pipeline:

```matlab
mh = parser.importQDVSM('NbN_MvsH_5K.dat', ...
        XAxis='field', YAxis='moment');
H = mh.values(:, 1);             % Oe
M = mh.values(:, 2);             % emu

dims.width     = 0.50;           % cm
dims.length    = 0.50;           % cm
dims.thickness = 1.0e-5;         % cm  (100 nm)

bean = calc.superconductor.beanJc(H, M, dims);

figure;
plot(bean.field/1e4, bean.Jc/1e6, 'b-', LineWidth=1.5);
xlabel('H (T)'); ylabel('J_c (MA/cm^2)');
title(sprintf('Bean J_c(H) at T = %.0f K', 5));
set(gca, YScale='log');
grid on;
```

### What to expect from the $J_c(H)$ curve

- **Monotone decrease** is the textbook behaviour: $J_c$ falls roughly as a power law $J_c \propto H^{-n}$ with $n \sim 0.5$–$1$ in the flux-flow regime, then drops sharply approaching the irreversibility field $H_\mathrm{irr}$.

- **Fishtail (second peak)** — a non-monotonic $J_c(H)$ with a peak well below $H_{c2}$ is characteristic of disorder-driven vortex-lattice phase transitions (commonly seen in YBCO, BSCCO, Ba-122 iron pnictides). It signals an order-disorder transition in the vortex lattice.

- **Peak effect** — a sharp upturn in $J_c$ very close to $H_{c2}$, well-known in NbSe$_2$ and clean Nb. It marks a softening of the vortex lattice that improves pinning right before depinning.

If your sample shows fishtail or peak-effect features, the simple Bean analysis still gives correct $J_c$ values point-by-point — only the *interpretation* of the field dependence requires a model beyond Bean.

---

## 7. Stage 5 — BCS weak-coupling gap and spectroscopic comparison

The weak-coupling BCS gap at $T = 0$ is fixed by the transition temperature alone:

$$\Delta(0) = 1.764\,k_B T_c$$

so the universal ratio is $2\Delta(0)/k_B T_c = 3.528$. To compute it from your $T_c$:

```matlab
% bcsGap fits a measured Delta(T) curve, but for the weak-coupling
% prediction from Tc alone you can synthesize a single-point dataset:
Tarr     = [0; 16.05];           % K, with one point at T=0
Delta_meV = 1.764 * 8.617e-5 * 16.05 * 1e3 * [1; 0];   % meV at T=0
gapRes = calc.superconductor.bcsGap(Tarr, Delta_meV, Tc=16.05);

fprintf('BCS Delta(0)            = %.3f meV\n', gapRes.Delta0);
fprintf('2*Delta(0)/(kB*Tc)       = %.3f  (BCS = 3.528)\n', gapRes.ratio);
```

For NbN ($T_c = 16.05$ K): $\Delta(0) \approx 2.44$ meV.

If you also have spectroscopic gap data (STS conductance, point-contact Andreev, ARPES, optical reflectivity), you can fit it directly:

```matlab
% Suppose you measured Delta(T) by STS at multiple temperatures:
T_meas     = [4, 6, 8, 10, 12, 14, 15, 15.8]';
Delta_meas = [2.50, 2.46, 2.39, 2.27, 2.07, 1.66, 1.27, 0.45]';   % meV

gapFit = calc.superconductor.bcsGap(T_meas, Delta_meas);
fprintf('Fitted Delta(0) = %.2f meV  (BCS = %.2f meV)\n', ...
        gapFit.Delta0, 1.764 * 8.617e-5 * 16.05 * 1e3);
fprintf('Strong-coupling ratio = %.2f\n', gapFit.ratio);
```

| Material | $T_c$ (K) | Measured $2\Delta/k_B T_c$ | Coupling |
|---|---|---|---|
| Al | 1.2 | 3.30 | weak |
| Sn | 3.7 | 3.50 | weak |
| Nb | 9.25 | 3.80 | intermediate |
| Pb | 7.2 | 4.30 | strong |
| Hg | 4.15 | 4.60 | strong |
| NbN | 16 | 3.6–4.2 | weak/intermediate |
| YBCO | 92 | 5–8 (anisotropic, d-wave) | unconventional |

A measured ratio significantly above 3.5 indicates either strong electron-phonon coupling (Eliashberg corrections, $\lambda_{ep} > 1$) or an unconventional pairing channel (d-wave nodal gap with antinodal maximum, multiband with a large gap). A ratio significantly below 3.5 typically signals impurity-averaging or a smaller-gap band in a multiband system.

---

## 8. Stage 6 — cross-checks

### $J_c$ vs. depairing current

The depairing (Ginzburg-Landau pair-breaking) current $J_d$ is the *theoretical* maximum supercurrent — set by the condensation energy and the penetration depth, not by pinning:

$$J_d(T) = \frac{H_c(T)}{3\sqrt{6}\,\pi\,\lambda(T)}$$

Real samples reach 1–10% of $J_d$ at low field; reaching 30% is exceptional and usually only seen in nanowires, 2D films at very low temperature, or carefully-engineered nanocomposite pinning landscapes.

```matlab
jdRes = calc.superconductor.depairingCurrent( ...
            Hc0=2000, lambda0=200, Tc=16.05, T=4.2);
fprintf('Jd(4.2 K)        = %.2f MA/cm^2\n', jdRes.JdMA);

% Take Jc at near-self-field from Stage 4
[~, idxLowH] = min(abs(bean.field));
Jc_self      = bean.Jc(idxLowH);
fprintf('Jc(self-field)   = %.2f MA/cm^2\n', Jc_self / 1e6);
fprintf('Jc / Jd          = %.1f%%\n', 100 * Jc_self / (jdRes.JdMA * 1e6));
```

If $J_c / J_d > 50\%$, double-check your sample dimensions and units — the Bean formula scales as $1/V$, and a thickness mistakenly entered in nm instead of cm shifts the result by 14 orders of magnitude.

### $H_{c2}(0)$ vs. Pauli paramagnetic limit

Beyond the orbital limit, Cooper pairs can also be broken by Zeeman alignment of the electron spins. The Clogston-Chandrasekhar (Pauli) limit, in Tesla:

$$H_P\,[\mathrm{T}] \approx 1.84\,T_c\,[\mathrm{K}]$$

For our NbN ($T_c = 16$ K): $H_P \approx 29.4$ T. If your measured $H_{c2}(0)$ is comparable to or larger than $H_P$, you have evidence for unconventional pairing or strong spin-orbit scattering:

```matlab
Hp = 1.84 * 16.05;                     % T
fprintf('Pauli limit H_P  = %.1f T\n', Hp);
fprintf('Hc2(0) [WHH]      = %.1f T\n', Hc2_0);
fprintf('Maki ratio alpha = %.2f  (>1.4 => significant Pauli limiting)\n', ...
        sqrt(2) * Hc2_0_orb / Hp);
```

Materials that exceed the Pauli limit substantially — heavy-fermion CeCoIn$_5$, organic salts, some iron pnictides — are candidates for non-singlet pairing (triplet, FFLO, spin-orbit-mixed singlets).

---

## 9. Common pitfalls

- **Mixing $T_c$ criteria across literature comparisons.** Always quote the criterion in parentheses: "$T_c = 16.05\pm0.30$ K (50% $R_n$, onset–offset width)". Comparing your onset to a competitor's offset can disagree by $\Delta T_c$ — full transition width.

- **Linear $H_{c2}(T)$ extrapolation when WHH curvature matters.** Near $T_c$ the WHH curve is nearly linear, but it bends downward at low $T$. A naive linear extrapolation from $T \sim 0.7\,T_c$ overestimates $H_{c2}(0)$ by 10–30%. Use the WHH prefactor of 0.693 with the *near-$T_c$* slope, not a linear fit through low-T points.

- **Bean formula in wrong unit convention.** The toolbox uses Gaussian CGS: field in Oe, moment in emu, dimensions in cm, output $J_c$ in A/cm$^2$. SI conversions are easy to fumble — pass `dims.thickness` in **cm** even for thin films (100 nm = $1\times10^{-5}$ cm). See [Bean tutorial pitfalls](bean_jc_extraction.md#8-common-pitfalls).

- **Wrong sample dimension parallel to H.** In the Bean formula, the *thickness* is the dimension along the applied field. For thin films with $H \perp$ film plane, that is the film thickness ($\sim 100$ nm). For $H \parallel$ film plane, that is one of the in-plane dimensions ($\sim 5$ mm) and the formula breaks down because thin-film flux penetration in this geometry is dominated by demagnetization, not Bean.

- **BCS gap from $T_c$ alone for strong-coupling materials.** Quoting $\Delta(0) = 1.764\,k_B T_c$ is BCS *weak-coupling*; it is wrong for Pb ($\Delta_\mathrm{exp} \approx 1.4$ meV, BCS prediction 1.10 meV) by 25%. Always state whether the $\Delta(0)$ you report comes from spectroscopy or from the $T_c$ assumption.

- **$\lambda_L$ from clean BCS when material is in the dirty limit.** The clean-limit relation $\lambda_L = \sqrt{m^*c^2/4\pi n_s e^2}$ applies only when the mean free path $\ell \gg \xi_0$. For dirty/disordered films (NbN, granular Al, amorphous MoGe) the effective penetration depth grows as $\lambda_\mathrm{eff} \approx \lambda_L \sqrt{\xi_0/\ell}$. If you do not measure $\lambda$ directly, do not pretend to know it to better than a factor of 2.

- **Fitting $H_{c2}(T)$ using $T_c$ as a fit parameter.** Fix $T_c$ from the zero-field R(T), do not let it float — small errors in the high-field $T_c(H_i)$ compound and shift the extrapolated slope.

---

## 10. Reporting template

For a publication on a new superconductor, report at minimum:

| Quantity | How obtained | Example value |
|---|---|---|
| $T_c$ (criterion) | R(T) at $H = 0$ | 16.05 K (midpoint, 50% $R_n$) |
| $\Delta T_c$ (width) | onset–offset | 0.30 K |
| RRR | $R(300\,\mathrm{K})/R_n(T_c^\mathrm{onset})$ | 1.4 |
| $|dH_{c2}/dT|_{T_c}$ | linear fit near $T_c$ | 1.80 T/K |
| $H_{c2}(0)$ (method) | WHH orbital | 20.0 T |
| Maki $\alpha$ | $\sqrt{2}\,H_{c2}^\mathrm{orb}(0)/H_P$ | 0.96 |
| $\xi_0$ | $\sqrt{\Phi_0 / 2\pi H_{c2}(0)}$ | 4.05 nm |
| $\lambda_L(0)$ | direct measurement / source cited | 200 nm (μSR, ref. X) |
| $\kappa$ | $\lambda/\xi$ | 49 |
| Type | $\kappa \gtrless 1/\sqrt{2}$ | II |
| $J_c(H_0)$ at $T_0$ | Bean from M(H) | 5.4 MA/cm$^2$ at 0.1 T, 5 K |
| $J_c$ at $H_0 = 1$ T | Bean from M(H) | 1.2 MA/cm$^2$ at 5 K |
| $J_c/J_d$ | ratio to depairing | 6% |
| $2\Delta(0)/k_B T_c$ | spectroscopy or BCS | 3.6 (STS) |

Example reporting paragraph:

> The film was characterised on a Quantum Design PPMS using four-probe ETO transport ($I = 10\,\mu\mathrm{A}$) and DC VSM. The zero-field transition gave $T_c = 16.05$ K (50% $R_n$ midpoint) with a 10–90% width of $\Delta T_c = 0.30$ K. R(T) at $H = 0$–9 T (out of plane) gave a near-$T_c$ slope $|dH_{c2}/dT|_{T_c} = 1.80$ T/K, yielding via WHH an orbital $H_{c2}^\mathrm{orb}(0) = 20.0$ T (Maki $\alpha = 0.96$, well below the Pauli limit $H_P = 29.5$ T). The corresponding GL coherence length is $\xi_0 = 4.0$ nm. Combining with $\lambda_L(0) = 200$ nm from mutual-inductance measurements (Ref. X) gives $\kappa = 49$, placing the film deep in the type-II regime. M(H) hysteresis loops at 5 K analysed via the Bean formula (rectangular geometry, $0.50\times 0.50\times 1.0\times 10^{-5}\,\mathrm{cm^3}$) gave $J_c = 5.4$ MA/cm$^2$ at self-field and $1.2$ MA/cm$^2$ at $\mu_0 H = 1$ T, corresponding to $J_c/J_d \approx 6\%$. STS at 4.2 K gave a single-gap $\Delta(0) = 2.49$ meV, in good agreement with the BCS weak-coupling prediction $1.764\,k_B T_c = 2.44$ meV ($2\Delta/k_B T_c = 3.6$).

---

## 11. Going further

| If you need to... | Use |
|---|---|
| Auto-extract $T_c$ from many R(T) datasets | `calc.superconductor.extractTc` in a `for` loop, or `fitting.batchFit` with a sigmoid model |
| Track $T_c$ across a thickness or doping series | feed a struct array to `fitting.batchFit` and tabulate `Tc_midpoint` |
| Work up M(H) loops for the Bean formula | [`bean_jc_extraction.md`](bean_jc_extraction.md) |
| Fit the full WHH curve (not just the linear slope) | implement WHH numerically; the toolbox does not ship a closed-form solver |
| Compare your sample to a tabulated entry | `calc.superconductor.materialPresets` |
| Compute $H_{c1}$, $H_{c2}$, $H_c$ all at one $T$ | `calc.superconductor.criticalFields(Material=..., T=...)` |
| Estimate $J_d$ for a "% of depairing" benchmark | `calc.superconductor.depairingCurrent` |

---

## 12. References

- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004 — chapters 3 (GL theory), 4 (BCS), and 5 (mixed state and pinning).
- Werthamer, N.R., Helfand, E. & Hohenberg, P.C. "Temperature and Purity Dependence of the Superconducting Critical Field, $H_{c2}$. III." *Phys. Rev.* **147**, 295 (1966). DOI: [10.1103/PhysRev.147.295](https://doi.org/10.1103/PhysRev.147.295)
- Bean, C.P. "Magnetization of Hard Superconductors," *Phys. Rev. Lett.* **8**, 250 (1962). DOI: [10.1103/PhysRevLett.8.250](https://doi.org/10.1103/PhysRevLett.8.250)
- Clogston, A.M. "Upper Limit for the Critical Field in Hard Superconductors," *Phys. Rev. Lett.* **9**, 266 (1962). DOI: [10.1103/PhysRevLett.9.266](https://doi.org/10.1103/PhysRevLett.9.266)
- Bardeen, J., Cooper, L.N. & Schrieffer, J.R. "Theory of Superconductivity," *Phys. Rev.* **108**, 1175 (1957). DOI: [10.1103/PhysRev.108.1175](https://doi.org/10.1103/PhysRev.108.1175)
- Poole, C.P., Farach, H.A., Creswick, R.J. & Prozorov, R. *Superconductivity*, 3rd ed., Academic Press, 2014 — practical handbook with tabulated parameters for hundreds of compounds.
- Ekin, J.W. *Experimental Techniques for Low-Temperature Measurements*, Oxford University Press, 2006 — the definitive reference for transport and magnetisation measurements on superconductors.

For derivations of every formula behind the toolbox calls, see [`docs/theory/superconductivity.md`](../theory/superconductivity.md).
