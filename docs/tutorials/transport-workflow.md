# Tutorial: PPMS Transport Workflow — Resistivity, Hall, and Wiedemann-Franz

This tutorial walks through extracting the **carrier concentration**, **mobility**, and **Wiedemann-Franz ratio** from a coupled PPMS measurement set: resistivity vs temperature $R(T)$, Hall voltage vs field $V_H(B)$, and (optionally) thermal conductivity $\kappa(T)$ from the Thermal Transport Option (TTO).

**Research question:** "I have $R(T)$, Hall, and thermal conductivity data from a PPMS measurement. How do I extract carrier concentration, mobility, and check the Wiedemann-Franz law to identify quasiparticle character?"

The workflow uses `parser.importPPMS` to load each scan, `+calc/+electrical/` for transport quantities, and `+calc/+semiconductor/` for the carrier-concentration cross-checks. See [`docs/theory/transport.md`](../theory/transport.md) for the full theoretical background.

---

## 1. Physics in 60 seconds

Within the **Drude picture**, free carriers of density $n$, charge $e$, effective mass $m^*$, and momentum-relaxation time $\tau$ give

$$\sigma = \frac{n e^2 \tau}{m^*} = n e \mu, \qquad \mu = \frac{e\tau}{m^*}$$

A magnetic field $B$ deflects the moving carriers, producing the **Hall voltage** $V_H$ across the sample. For a single carrier type,

$$R_H \;\equiv\; \frac{E_y}{j_x B_z} \;=\; \frac{1}{n e}\quad \text{(electrons: } R_H<0\text{; holes: } R_H>0\text{)}$$

so the slope $dV_H/dB$ at fixed current $I$ and thickness $t$ gives both the **sign** and **density** of carriers in one measurement. Combining with $\rho$, the **Hall mobility** is

$$\mu_H = \frac{|R_H|}{\rho} = |R_H|\,\sigma$$

The **Wiedemann-Franz law** says that for elastic scattering of free fermions, the electronic thermal conductivity satisfies

$$\frac{\kappa_e}{\sigma T} \;=\; L_0 \;=\; \frac{\pi^2}{3}\!\left(\frac{k_B}{e}\right)^{\!2} \;\approx\; 2.44\times 10^{-8}\;\mathrm{V^2/K^2}$$

When the measured ratio $L \equiv \kappa/(\sigma T)$ exceeds $L_0$ at low $T$, **phonons** (or magnons) are also carrying heat. When $L < L_0$, scattering is **inelastic** (electron-phonon, electron-electron) — a hallmark of strongly correlated metals, hydrodynamic transport (e.g. graphene near charge neutrality), or phonon drag. So the dimensionless ratio $L/L_0$ is a single-number diagnostic for *quasiparticle character*.

Cross-references:
- [`docs/theory/transport.md`](../theory/transport.md) — Drude/Boltzmann derivations, anomalous Hall
- [`docs/theory/electrochemistry.md`](../theory/electrochemistry.md) — ion transport for context on Nernst-Einstein
- [`docs/theory/statistics.md`](../theory/statistics.md) — linear regression for the Hall slope

---

## 2. What you need

- A **Quantum Design PPMS** (or DynaCool) with the Resistivity option for $\rho(T)$ and ETO/AC-Transport for $V_H(B)$. For $\kappa(T)$, the Thermal Transport Option (TTO) puck.
- Six-wire **Hall bar** or **Van der Pauw** geometry. Hall bars give $V_{xx}$ and $V_{xy}$ directly; Van der Pauw needs symmetric and switched contact configurations.
- Sample dimensions in cm:
  - Bulk: width $w$, length $\ell$ between voltage taps, thickness $t$
  - Thin film: same plus an accurate $t$ (profilometry or X-ray reflectivity, see [`../tutorials/curve-fitting-workflow.md`](curve-fitting-workflow.md))
- A **swept field** Hall measurement at one or more fixed temperatures, ideally from $-B_{\max}$ to $+B_{\max}$ so you can anti-symmetrize.
- For the WF check: $\kappa(T)$ from TTO covering the same $T$ range as $\rho(T)$.

---

## 3. Stage 1 — $R(T)$ and resistivity

```matlab
setupToolbox;    % once per session

dRT = parser.importPPMS('Cu_film_RvsT.dat', ...
        'XAxis', 'temp', 'YAxis', 'all');

T   = dRT.values(:, dRT.labels == "Temperature (K)");
R   = dRT.values(:, dRT.labels == "Resistance Ch1 (Ohms)");

figure;
plot(T, R, 'k.-'); xlabel('T (K)'); ylabel('R (\Omega)'); grid on;
title('Raw R(T)');
```

Convert the four-probe resistance to **bulk resistivity** using the sample geometry. For a Hall bar with current passing along the length and voltage taps separated by $\ell$,

$$\rho = R \cdot \frac{w \cdot t}{\ell}$$

```matlab
% Geometry (cm) — measured with calipers / profilometry
w = 0.20;        % width
L = 0.50;        % distance between voltage taps
t = 100e-7;      % thickness: 100 nm = 100e-7 cm

rho = R * (w * t) / L;       % Ohm·cm, vector vs T
```

**Thin films:** if instead you only know the **sheet resistance** $R_s = V/I$ from a Van der Pauw measurement, convert to bulk resistivity once you know $t$:

```matlab
Rs  = 12.5;                              % Ohm/sq (single T point)
rB  = calc.electrical.resistivity(Rs, t);
fprintf('rho = %s\n', rB.latex);
```

To go the other way (bulk $\rho$ to sheet for a thin-film figure), use `calc.electrical.sheetResistance(rho, t)`.

### Identify the conduction regime

Slope of $\rho(T)$ tells you metal vs semiconductor:

| Behaviour | Diagnostic |
|---|---|
| **Metal-like** | $d\rho/dT > 0$ over the whole range |
| **Semiconducting** | $d\rho/dT < 0$, often exponential $\rho \propto e^{E_a/k_B T}$ |
| **Bad metal / mixed** | non-monotonic; check for a minimum (Kondo, weak localisation) |
| **Superconductor** | $\rho \to 0$ below $T_c$ — see [`docs/theory/superconductivity.md`](../theory/superconductivity.md) |

```matlab
RRR = R(T == max(T)) / R(T == min(T));
fprintf('Residual resistance ratio RRR = %.1f\n', RRR);
```

**Worked example.** A 100 nm sputtered Cu film with $w = 2$ mm, $\ell = 5$ mm, $R(300\,\mathrm{K}) = 1.0\,\Omega$ gives

$$\rho_{300\,K} = 1.0 \times \frac{0.2 \times 10^{-5}}{0.5} = 4.0\times 10^{-6}\;\Omega\,\mathrm{cm} \approx 4\,\mu\Omega\,\mathrm{cm}$$

A high-purity film should hit $\rho_{300\,K} \approx 1.7\,\mu\Omega\cdot$cm with RRR $\sim 50$; values above $\sim 10\,\mu\Omega\cdot$cm at room temperature flag grain-boundary or surface scattering.

---

## 4. Stage 2 — Hall analysis

Load the field sweep at fixed $T$ and extract $V_H$ from the transverse channel. Always anti-symmetrise to remove the longitudinal magnetoresistance bleed-through caused by imperfect contact alignment.

```matlab
dHall = parser.importPPMS('GaAs_HEMT_Hall_300K.dat', ...
            'XAxis', 'field', 'YAxis', 'all');

B  = dHall.values(:, dHall.labels == "Magnetic Field (Oe)") / 1e4;   % Oe -> T
Vxy = dHall.values(:, dHall.labels == "Bridge 1 Voltage (V)");
I  = 100e-6;            % excitation current, A

% Anti-symmetrise: V_H(B) = (V(+B) - V(-B)) / 2
% This requires a symmetric field sweep; interpolate to a common grid:
Bgrid = linspace(0, max(abs(B)), 51)';
V_pos = interp1(B(B>=0),  Vxy(B>=0),  Bgrid, 'linear', 'extrap');
V_neg = interp1(-B(B<=0), Vxy(B<=0),  Bgrid, 'linear', 'extrap');
V_H   = (V_pos - V_neg) / 2;             % anti-symmetrised V_H(|B|)

% Convert V_H -> Hall resistance R_xy = V_H / I
Rxy = V_H / I;

figure;
plot(Bgrid, Rxy*1e3, 'b.-'); xlabel('B (T)'); ylabel('R_{xy} (m\Omega)');
title('Anti-symmetrised Hall resistance'); grid on;
```

A clean linear $R_{xy}(B)$ confirms a single carrier type. Now fit the slope and extract carrier density and Hall mobility in one call. `calc.electrical.hallAnalysis` does the linear fit, returns $R_H$ in cm³/C with the correct sign, and (when you supply `Thickness` and `Sigma`) returns $n$ and $\mu_H$ as well.

```matlab
% Bulk conductivity at the same T (from Stage 1)
sigma_300K = 1 / rho(T == 300);          % S/cm

res = calc.electrical.hallAnalysis(Bgrid, Rxy, ...
        Thickness=t, ...                 % cm
        Sigma=sigma_300K);                % S/cm

fprintf('R_H        = %+.3e cm^3/C  (%s carriers)\n', ...
        res.R_H, res.carrierType);
fprintf('n          = %.3e cm^-3\n', res.carrierDensity);
fprintf('mu_H       = %.1f cm^2/V.s\n', res.mobility);
fprintf('Linear R^2 = %.4f\n', res.fitR2);
```

**Sign convention.** `R_H > 0` = holes (p-type), `R_H < 0` = electrons (n-type). The function reports `carrierType` so you don't have to remember.

**Sheet density for 2DEGs.** For a confined 2D electron gas (HEMT, oxide interface), the relevant figure of merit is the sheet density $n_s = n \cdot t$ — but in practice you get $n_s = 1/(R_{H,\mathrm{sheet}} e)$ directly from the slope of $V_H$ vs $B$ without needing the thickness. Compute it from the bulk $n$ by

```matlab
nsRes = calc.semiconductor.sheetCarrierDensity(res.carrierDensity, t);
fprintf('n_s = %s\n', nsRes.latex);
```

**Worked example.** A modulation-doped GaAs/AlGaAs HEMT 2DEG, $t = 25$ nm, slope $dR_{xy}/dB = -125\,\Omega/$T → $R_H = -3.1\times 10^{-4}\,\mathrm{m^3/C} = -3.1\times 10^{-2}\,\mathrm{cm^3/C}$ × $t$. With $\rho_{300\,K} = 5\times 10^{-3}\,\Omega\cdot$cm,

$$n_s = \frac{1}{|R_H| e} = 5\times 10^{11}\;\mathrm{cm^{-2}}, \qquad \mu_H = \frac{|R_H|}{\rho} \approx 8000\;\mathrm{cm^2/V\!\cdot\! s}$$

— textbook values for an unintentionally-doped HEMT at room temperature.

---

## 5. Stage 3 — Mobility vs temperature

If you have $\rho(T)$ from Stage 1 and Hall $R_H(T)$ from a temperature-stepped Hall scan, you can plot $\mu_H(T)$ and identify the dominant scattering mechanism.

```matlab
% Pretend we have a vector of Hall coefficients vs T (one Hall sweep per T)
Tk     = [10 50 100 150 200 250 300];     % K
Rh_vec = [-3.0 -3.0 -3.1 -3.1 -3.2 -3.2 -3.3] * 1e-2;   % cm^3/C
rho_T  = interp1(T, rho, Tk);                          % Ohm·cm at the same T

mu_T = abs(Rh_vec) ./ rho_T;     % cm^2/V·s

figure;
loglog(Tk, mu_T, 'o-'); xlabel('T (K)'); ylabel('\mu_H (cm^2/V\cdots)');
grid on; title('Hall mobility vs temperature');
```

For a single quantity at fixed $T$, use the standalone helper:

```matlab
m = calc.electrical.mobility(rho_T(end), abs(1./(Rh_vec(end)*1.602e-19)));
fprintf('mu = %.1f cm^2/V.s\n', m.mu);
```

(Note: `calc.electrical.mobility` takes `(rho, n)` and returns $\mu = 1/(n e \rho)$. The Hall path through `hallAnalysis(..., Sigma=sigma)` is usually more direct.)

### Scattering regimes

| Regime | $\mu(T)$ scaling | Source |
|---|---|---|
| Acoustic-phonon limited (high $T$) | $\mu \propto T^{-3/2}$ | deformation potential |
| Polar-optical phonon (III-V at $T \gtrsim 100$ K) | $\mu \propto T^{-1}$ to $T^{-1/2}$ | LO phonons |
| Ionised-impurity limited (low $T$) | $\mu \propto T^{+3/2}$ | Brooks-Herring |
| Neutral-impurity / surface | $\mu \approx \mathrm{const}$ | Erginsoy |

**Matthiessen's rule** combines them: $1/\mu = \sum_i 1/\mu_i$. For Si under standard conditions, the doping- and temperature-dependent **Caughey-Thomas** parameterisation in `calc.semiconductor.mobilityModel` returns electron and hole mobilities directly:

```matlab
mm = calc.semiconductor.mobilityModel(Material='Si', N=1e16, T=300);
fprintf('Si @ N=1e16, 300 K: mu_e = %.0f, mu_h = %.0f cm^2/V.s\n', ...
        mm.muE, mm.muH);
```

To compare your data to the model, evaluate the model on the same temperature grid and overlay; for non-Si materials it falls back to Si coefficients with a warning, so use it for back-of-the-envelope rather than quantitative analysis on GaAs / GaN / SiC.

---

## 6. Stage 4 — Two-band Hall (when $V_H$ is non-linear)

If the anti-symmetrised $V_H(B)$ deviates from a straight line, a single carrier type is no longer enough. **Semimetals** (Bi, Sb, graphite, WTe$_2$) and lightly-compensated semiconductors have comparable populations of electrons and holes; the Hall response is

$$R_H(B) \;=\; \frac{(\mu_h^2 p - \mu_e^2 n) + (\mu_h \mu_e)^2 (p - n) B^2}{e\,\big[(\mu_h p + \mu_e n)^2 + (\mu_h \mu_e)^2 (p - n)^2 B^2\big]}$$

A diagnostic plot is sufficient before you reach for the full two-band fit:

```matlab
% Slope at low and high B from a fitted line in two windows
loB = abs(Bgrid) < 0.3;     hiB = abs(Bgrid) > 0.7 * max(abs(Bgrid));
sLo = polyfit(Bgrid(loB), Rxy(loB), 1);   slopeLo = sLo(1);
sHi = polyfit(Bgrid(hiB), Rxy(hiB), 1);   slopeHi = sHi(1);
fprintf('Low-B slope:  %+.4e Ohm/T\n', slopeLo);
fprintf('High-B slope: %+.4e Ohm/T\n', slopeHi);
fprintf('Ratio (deviation from single-band): %.3f\n', slopeHi/slopeLo);
```

If the ratio differs from 1 by more than a few percent, reach for a two-band fit (see Hurd 1972 or Ashcroft & Mermin Ch. 12). A custom two-band model can be passed to [`fitting.curveFit`](../../+fitting/curveFit.m) — see [`curve-fitting-workflow.md`](curve-fitting-workflow.md) for the bound-and-fit pattern.

---

## 7. Stage 5 — Wiedemann-Franz check

Load the thermal conductivity from a TTO scan, interpolate it onto the same $T$ grid as $\rho(T)$, and form $L = \kappa/(\sigma T)$. The toolbox helper `calc.electrical.wiedemannFranz(T, rho)` computes the **predicted** $\kappa_e$ from $L_0 \cdot T/\rho$ — useful for comparing measured to predicted directly.

```matlab
dTC = parser.importPPMS('Cu_film_TTO.dat', 'XAxis', 'temp', 'YAxis', 'all');
T_k = dTC.values(:, dTC.labels == "Temperature (K)");
kappa = dTC.values(:, dTC.labels == "Thermal Conductivity (W/(cm K))");

% Interpolate rho onto the kappa grid
rho_on_k = interp1(T, rho, T_k, 'linear');

% Predicted electronic kappa from Wiedemann-Franz
kappa_pred = calc.electrical.wiedemannFranz(T_k, rho_on_k);

% Measured Lorenz ratio L = kappa/(sigma T) and dimensionless L/L0
sigma_T = 1 ./ rho_on_k;
L0      = 2.44e-8;          % W·Omega/K^2
L_meas  = kappa ./ (sigma_T .* T_k);
ratio   = L_meas / L0;

figure;
subplot(2,1,1);
loglog(T_k, kappa, 'b.-', T_k, kappa_pred, 'r--'); grid on;
xlabel('T (K)'); ylabel('\kappa (W cm^{-1} K^{-1})');
legend('measured', 'WF prediction (\kappa_e only)', 'Location', 'best');

subplot(2,1,2);
semilogx(T_k, ratio, 'k.-'); grid on; yline(1, 'r--');
xlabel('T (K)'); ylabel('L / L_0');
title('Lorenz ratio — should be 1 for elastic free-fermion scattering');
```

### Interpreting $L/L_0$

| Observation | What it means |
|---|---|
| $L/L_0 \approx 1$ at low and high $T$ | Standard metal; elastic scattering dominates |
| $L/L_0 \gg 1$ everywhere | Phonons carry significant heat — typical of dirty metals, alloys, ceramics, and any semiconductor where $\kappa_{\mathrm{ph}}$ dominates. **Do not** apply WF here. |
| $L/L_0 < 1$ in the intermediate-$T$ regime ($\sim 0.1\,\Theta_D$ to $\Theta_D$) | Inelastic small-angle electron-phonon scattering — relaxes momentum but not energy. Classical "WF violation" in clean simple metals. |
| $L/L_0 < 1$ at the lowest $T$ | Strong inelastic e-e scattering: heavy-fermion compounds, hydrodynamic transport (graphene near CNP, PdCoO$_2$), strange metals near a quantum critical point. Worth reporting. |

A measured $L/L_0$ that **decreases** from $\sim 1$ at room $T$ to $\sim 0.5$ at $T \sim \Theta_D/3$ and recovers to $\sim 1$ below $T \sim \Theta_D/30$ is the canonical "Wilson-Sommerfeld" curve and is reproduced by Bloch-Grüneisen theory.

---

## 8. Stage 6 — Cross-checks

### Semiconductor: $n(T)$ vs intrinsic prediction

For an undoped or lightly-doped semiconductor, the Hall density should follow the **intrinsic** carrier concentration

$$n_i(T) = \sqrt{N_c N_v}\,\exp\!\left(-\frac{E_g}{2 k_B T}\right)$$

The toolbox provides this directly (with effective masses pulled from `materialPresets`):

```matlab
mp = calc.semiconductor.materialPresets('Si');
TT = linspace(200, 600, 50);
ni = arrayfun(@(Tk) calc.semiconductor.intrinsicCarrierConc( ...
        Tk, mp.Eg, mp.me_eff, mp.mh_eff).ni, TT);

figure;
semilogy(1000./TT, ni, 'b-', 1000./Tk_data, n_Hall, 'ro');
xlabel('1000/T (K^{-1})'); ylabel('n (cm^{-3})'); grid on;
legend('Intrinsic (preset)', 'Hall measurement', 'Location','SW');
```

A linear Arrhenius fit to $\ln n$ vs $1/T$ recovers $E_g$ — see [`docs/theory/statistics.md`](../theory/statistics.md) for the linear-regression formulas and confidence intervals.

For doped material, use `calc.semiconductor.carrierConcentration(Nd, Na, ni)` to get the equilibrium $n$, $p$ given dopants and $n_i$, and compare to the Hall density to identify the carrier-freezeout regime at low $T$.

### Metal: free-electron sanity check

For a simple metal, the free-electron density is set by valence and unit-cell volume:

$$n_{\mathrm{fe}} = \frac{Z}{V_\mathrm{cell}}$$

A measured Hall density that is within a factor of ~2 of $n_{\mathrm{fe}}$ confirms a single-band picture. Larger discrepancies flag multi-band Fermi surfaces (transition metals, semimetals) or anomalous Hall contributions in magnetic samples — see the AHE section in [`docs/theory/transport.md`](../theory/transport.md).

---

## 9. Common pitfalls

- **Hall voltage not anti-symmetrised.** Imperfect contact placement contaminates $V_{xy}$ with a longitudinal $V_{xx}\cdot \tan\theta$ term that survives field reversal. Always do $V_H = (V(+B) - V(-B))/2$ before fitting.
- **Sample thickness wrong.** $R_H$ scales as $1/(net)$ for a Hall bar, so a thickness that is wrong by an integer factor (e.g. nm vs $10^{-7}$ cm) gives $n$ wrong by the same factor. Verify with profilometry or XRR.
- **Wiedemann-Franz applied where electronic $\kappa$ isn't dominant.** In insulators, polymers, ceramics, and most semiconductors at moderate doping, phonons carry the heat. $L/L_0 \gg 1$ in those cases is not a "violation" — WF simply doesn't apply.
- **Two-band carriers mistaken for single-carrier $1/(ne)$.** A non-linear $V_H(B)$ is a red flag. Check with the low-B / high-B slope ratio (Stage 4) before quoting a single $n$.
- **Sheet vs bulk confusion.** Sheet resistance $R_s = \rho/t$ has units of $\Omega/\square$, not $\Omega\cdot$cm. Likewise sheet density $n_s = n\,t$ in cm$^{-2}$, not bulk $n$ in cm$^{-3}$. The toolbox helpers (`sheetResistance`, `sheetCarrierDensity`) make the conversion explicit — use them rather than dividing by $t$ in your own code.
- **Hall mobility vs drift mobility differ.** The Hall factor $r_H = \langle\tau^2\rangle/\langle\tau\rangle^2$ depends on the scattering mechanism; for non-degenerate carriers $r_H \approx 1.18$ (acoustic phonons) to $\approx 1.93$ (ionised impurities), so $\mu_H = r_H \mu_d$. For most metals (degenerate carriers) $r_H \to 1$ and the distinction vanishes. Note this in the report when it matters.
- **PPMS column labels drift between firmware versions.** Always inspect `data.labels` after `parser.importPPMS` and match by string rather than column index. The labels referenced above ("Temperature (K)", "Magnetic Field (Oe)", "Bridge 1 Voltage (V)", etc.) are the QD defaults but can be renamed in the sequence file.

---

## 10. Reporting template

A complete transport report for a publication should include:

```
Sample:         <material, geometry, deposition method>
Geometry (cm):  w = ..., L = ..., t = ...                (Hall bar)
                or Van der Pauw on <substrate>
T range:        <Tmin> – <Tmax> K
B range:        <Bmin> – <Bmax> T
Anti-symmetrised Hall: yes / no

Resistivity:    rho(300K) = ... uOhm.cm
                RRR = rho(300K) / rho(<Tmin>K) = ...

Hall:           R_H = ... cm^3/C   (sign: electron/hole)
                n   = ... cm^-3   (or n_s = ... cm^-2 for 2D)
                mu_H(300K) = ... cm^2/V.s
                mu_H(<Tmin>K) = ... cm^2/V.s
                Single-band fit R^2 = ...

Wiedemann-Franz: L/L_0 at <T_low>, <T_mid>, <T_high>
                Interpretation: <free-fermion / phonon-dominated /
                inelastic / hydrodynamic>

Cross-check:    n_Hall vs n_intrinsic (semiconductor) — gap E_g = ...
                or n_Hall vs n_fe (metal) — within factor X
```

Reproducible pipeline (copy-paste from `+scripts/`, when one exists for transport):

```matlab
dRT   = parser.importPPMS('Sample_RvsT.dat',  'XAxis','temp', 'YAxis','all');
dHall = parser.importPPMS('Sample_Hall_300K.dat','XAxis','field','YAxis','all');
dTTO  = parser.importPPMS('Sample_TTO.dat',   'XAxis','temp', 'YAxis','all');

% --- resistivity, Hall, mobility, WF check, all in one struct
report = struct();
report.rho300 = ...;            % see Stage 1
report.RRR    = ...;
report.hall   = calc.electrical.hallAnalysis(B, Rxy, ...
                    Thickness=t, Sigma=1/report.rho300);
report.LoverL0 = ...;           % see Stage 5
disp(report);
```

---

## 11. References

- Ashcroft, N. W. & Mermin, N. D., *Solid State Physics*, Saunders, 1976. Ch. 1 (Drude), Ch. 13 (semiclassical transport), Ch. 12 (Hall effect, two-band).
- Ziman, J. M., *Principles of the Theory of Solids*, 2nd ed., Cambridge, 1972. Ch. 7 (transport, Bloch-Grüneisen), Ch. 9 (Wiedemann-Franz).
- Hurd, C. M., *The Hall Effect in Metals and Alloys*, Plenum, 1972. The standard reference for two-band fits.
- Sze, S. M. & Ng, K. K., *Physics of Semiconductor Devices*, 3rd ed., Wiley, 2007. Ch. 1 (mobility, Caughey-Thomas), Appendix (material parameters).
- Mahajan, Y. & Wakeham, N., "Wiedemann-Franz law and the violation in heavy-fermion systems," *Nat. Commun.* **2**, 396 (2011).
- Crossno, J. et al., "Observation of the Dirac fluid and the breakdown of the Wiedemann-Franz law in graphene," *Science* **351**, 1058 (2016).
- Quantum Design, *Physical Property Measurement System: Resistivity Option User's Manual* (current rev.) — Hall bar / Van der Pauw geometry conventions and contact-misalignment correction.

For the underlying derivations (Boltzmann equation, Sommerfeld expansion, Lorenz number) see [`docs/theory/transport.md`](../theory/transport.md). For the Hall-slope linear regression with proper error bars see [`docs/theory/statistics.md`](../theory/statistics.md).
