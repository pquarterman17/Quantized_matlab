# Magnetometry

This document covers the physics behind the magnetometry analysis functions in the toolbox: Curie-Weiss fitting, hysteresis loop parameter extraction, demagnetization corrections, FORC analysis, Kissinger thermal analysis, background subtraction, and unit conversions between CGS and SI systems.

The target audience is a graduate student or postdoc who has measured $M(T)$ or $M(H)$ data on a SQUID magnetometer or VSM and needs to extract quantitative physical parameters.

---

## Curie-Weiss Analysis

### Theory

A localized-moment paramagnet above its ordering temperature obeys the **Curie-Weiss law**:

$$\chi = \frac{C}{T - \theta_\mathrm{CW}}$$

where $\chi$ is the molar magnetic susceptibility (emu/Oe/mol in CGS), $C$ is the **Curie constant**, and $\theta_\mathrm{CW}$ is the **Weiss temperature**. The sign of $\theta_\mathrm{CW}$ encodes the dominant exchange interaction:

| $\theta_\mathrm{CW}$ | Interpretation |
|---|---|
| $> 0$ | Ferromagnetic exchange |
| $< 0$ | Antiferromagnetic exchange |
| $= 0$ | Ideal paramagnet (pure Curie law) |

Taking the reciprocal gives a linear relation in temperature:

$$\frac{1}{\chi} = \frac{T}{C} - \frac{\theta_\mathrm{CW}}{C}$$

A least-squares fit of $1/\chi$ vs $T$ in the paramagnetic regime yields:

$$\text{slope} = \frac{1}{C}, \qquad \text{intercept} = -\frac{\theta_\mathrm{CW}}{C}$$

from which:

$$C = \frac{1}{\text{slope}}, \qquad \theta_\mathrm{CW} = -\frac{\text{intercept}}{\text{slope}}$$

The **effective magnetic moment** per formula unit is derived from the Curie constant. Starting from the classical result for $N_A$ non-interacting moments, each with total angular momentum quantum number $J$:

$$C = \frac{N_A \mu_\mathrm{eff}^2}{3 k_B}$$

Solving for $\mu_\mathrm{eff}$ in units of Bohr magnetons ($\mu_B$):

$$\mu_\mathrm{eff} = \sqrt{\frac{3 k_B C}{N_A \mu_B^2}}$$

When $C$ is in CGS molar units (emu K / Oe mol), the conversion to SI is $C_\mathrm{SI} = C_\mathrm{CGS} \times 10^{-3}$ (since 1 emu/Oe = $10^{-3}$ m$^3$), and the numerical shortcut is:

$$\mu_\mathrm{eff} = \sqrt{7.9735 \, C_\mathrm{CGS}} \quad [\mu_B]$$

For a free ion with total angular momentum $J$, the theoretical effective moment is $\mu_\mathrm{eff} = g_J \sqrt{J(J+1)} \, \mu_B$, where $g_J$ is the Lande g-factor. Some reference values:

| Ion | Config | $g_J\sqrt{J(J+1)}$ ($\mu_B$) | Typical observed |
|-----|--------|-------------------------------|-----------------|
| Fe$^{3+}$ ($3d^5$) | $^6S_{5/2}$ | 5.92 | 5.7--6.0 |
| Fe$^{2+}$ ($3d^6$) | $^5D_4$ | 6.71 | 5.1--5.5 |
| Co$^{2+}$ ($3d^7$) | $^4F_{9/2}$ | 6.63 | 4.3--5.2 |
| Ni$^{2+}$ ($3d^8$) | $^3F_4$ | 5.59 | 2.8--3.4 |
| Mn$^{2+}$ ($3d^5$) | $^6S_{5/2}$ | 5.92 | 5.7--6.0 |
| Gd$^{3+}$ ($4f^7$) | $^8S_{7/2}$ | 7.94 | 7.9--8.0 |

For $3d$ transition metals the orbital moment is partially quenched by crystal-field effects, so observed values often fall below the free-ion prediction. For $4f$ rare earths, spin-orbit coupling dominates and the free-ion formula works well.

### When to use

- You have $\chi(T)$ or $M(T)$ data at a fixed low field ($H \lesssim 1000$ Oe) measured on warming.
- The sample contains localized magnetic moments (transition-metal oxides, rare-earth compounds, molecular magnets).
- You want to determine: the ordering temperature (approximate, from $\theta_\mathrm{CW}$), the type of exchange coupling, and the effective moment to identify the oxidation state / spin state of the magnetic ion.
- **Fit only in the paramagnetic regime** --- well above $T_C$ or $T_N$. As a rule of thumb, restrict the fit to $T > 2|\theta_\mathrm{CW}|$ or higher, since short-range correlations persist above the ordering temperature and cause curvature in $1/\chi$.

### Implementation

The function `calc.magnetic.curieWeiss` performs a linear least-squares fit of $1/\chi$ vs $T$. If no explicit `FitRange` is provided, it auto-selects the region above the temperature at which $1/\chi$ is maximum, which typically corresponds to the onset of the paramagnetic linear regime. The fit returns $\theta_\mathrm{CW}$, $C$, $\mu_\mathrm{eff}$ (assuming CGS molar susceptibility), the $R^2$ coefficient, and the full $1/\chi$ vector for plotting.

### References

- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Ch. 3.
- Kittel, C., *Introduction to Solid State Physics*, 8th ed., Wiley, 2005, Ch. 11.
- Blundell, S.J., *Magnetism in Condensed Matter*, Oxford University Press, 2001, Ch. 2.

---

## Hysteresis Loop Analysis

### Theory

A ferromagnetic or ferrimagnetic hysteresis loop $M(H)$ encodes several key material parameters:

**Coercive field** $H_c$: the applied field at which the magnetization passes through zero. For a full loop with ascending and descending branches:

$$H_c = \frac{|H_c^\uparrow| + |H_c^\downarrow|}{2}$$

where $H_c^\uparrow$ and $H_c^\downarrow$ are the zero-crossings on the ascending and descending branches respectively. Significant asymmetry ($|H_c^\uparrow| \neq |H_c^\downarrow|$) indicates exchange bias, minor-loop effects, or instrumental drift.

**Remanent magnetization** $M_r$: the magnetization remaining at zero applied field:

$$M_r = \frac{|M_r^\uparrow| + |M_r^\downarrow|}{2}$$

**Saturation magnetization** $M_s$: the magnetization at high field, where $M(H)$ plateaus. Operationally, this is the average moment in the field range $|H| > f \cdot H_\mathrm{max}$, where $f$ is a saturation fraction (default 0.8). If $M$ is still increasing at $H_\mathrm{max}$, the sample may not be saturated --- a common issue for nanoparticles, antiferromagnets, and samples with significant paramagnetic or diamagnetic backgrounds.

**Squareness ratio** $S$:

$$S = \frac{M_r}{M_s}$$

$S = 1$ for a perfectly square loop (coherent rotation of a uniaxial single-domain particle, Stoner-Wohlfarth limit). $S = 0.5$ for randomly oriented non-interacting single-domain particles. $S \ll 0.5$ suggests multi-domain behavior or broad anisotropy distributions.

**Hysteresis loss** (loop area):

$$W = \oint M \, dH = \int_\mathrm{desc} M \, dH - \int_\mathrm{asc} M \, dH$$

This integral gives the energy dissipated per cycle per unit volume (in erg/cm$^3$ for CGS or J/m$^3$ for SI). It is relevant for magnetic recording media and hyperthermia applications.

**Switching field distribution (SFD)**: the derivative $dM/dH$ of the ascending branch, evaluated numerically. The peak position gives the most probable switching field, and the FWHM of $|dM/dH|$ characterizes the width of the coercivity distribution. For recording media, a narrow SFD (small FWHM relative to $H_c$) indicates sharp switching and good signal-to-noise.

### When to use

- You have a complete $M(H)$ loop measured at constant temperature.
- You want quantitative figures of merit: $H_c$, $M_r$, $M_s$, squareness, loop area, switching field distribution.
- Works for both SQUID/VSM data in emu and normalized data in A/m or $\mu_B$/atom.

### Implementation

The function `utilities.hysteresisAnalysis` auto-detects ascending and descending branches from field reversal points, optionally identifies and removes a virgin curve, and extracts all parameters via interpolation. The SFD is computed using a Savitzky-Golay smoothed numerical derivative. Diagnostic warnings flag unsaturated loops, asymmetric coercivity, or missing zero-crossings.

### References

- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Ch. 1, 9.
- Stoner, E.C. & Wohlfarth, E.P., "A mechanism of magnetic hysteresis in heterogeneous alloys," *Phil. Trans. R. Soc. A* **240**, 599 (1948).

---

## Demagnetization Corrections

### Theory

The magnetic field inside a uniformly magnetized body of finite size differs from the externally applied field due to the **demagnetizing field** $H_d$:

$$H_\mathrm{int} = H_\mathrm{ext} - N \, M$$

where $N$ is the dimensionless demagnetization factor (in SI; in CGS, $H_\mathrm{int} = H_\mathrm{ext} - 4\pi N M$). For a general ellipsoid with principal axes, the trace condition holds:

$$N_x + N_y + N_z = 1 \quad \text{(SI)}$$

For shapes with rotational symmetry about $z$ (spheroids, cylinders), $N_x = N_y \equiv N_{xy}$, so:

$$N_{xy} = \frac{1 - N_z}{2}$$

#### Exact results for ellipsoids (Osborn 1945)

**Sphere:**

$$N_z = N_{xy} = \frac{1}{3}$$

**Infinite thin film** (field normal to film plane):

$$N_z = 1, \quad N_{xy} = 0$$

This means the internal field along the film normal is $H_\mathrm{int} = H_\mathrm{ext} - M$, which is a huge correction for in-plane vs out-of-plane geometry.

**Prolate spheroid** (elongated, $c > a$, needle-like): with eccentricity $e^2 = 1 - (a/c)^2$ and aspect ratio $m = c/a > 1$:

$$N_z = \frac{1 - e^2}{e^2}\left(-1 + \frac{1}{2e}\ln\frac{1+e}{1-e}\right)$$

As $m \to \infty$ (long needle), $N_z \to 0$ and $N_{xy} \to 1/2$.

**Oblate spheroid** (flattened, $a > c$, disk-like): with $e^2 = 1 - (c/a)^2$ and aspect ratio $m = a/c > 1$:

$$N_z = \frac{1}{e^2}\left(1 - \frac{\sqrt{1-e^2}}{e}\arcsin e\right)$$

As $m \to \infty$ (thin disk), $N_z \to 1$.

**Finite cylinder** (Osborn approximation): for a cylinder of length $L$ and diameter $d$:

$$N_z \approx \frac{1}{1 + 1.6\,(L/d)}$$

This approximation is valid for $L/d \in [0.1, 10]$ and gives the correct limits: $N_z \to 1$ for $L \ll d$ (disk) and $N_z \to 0$ for $L \gg d$ (rod).

### When to use

- Whenever you are comparing measured $M(H)$ data to intrinsic material properties (anisotropy fields, saturation), especially for bulk samples or thick films.
- The correction matters most when $N \cdot M$ is comparable to $H_\mathrm{ext}$. For a thin-film sample measured in-plane ($N \approx 0$), the correction is negligible. For the same film measured out-of-plane ($N \approx 1$), the correction is enormous.
- For soft magnetic materials ($H_c \ll 4\pi M_s$), the demagnetizing field can completely dominate the apparent hysteresis.

### Implementation

The function `calc.magnetic.demagFactor` accepts a shape string (`'sphere'`, `'thin_film'`, `'cylinder'`, `'prolate'`, `'oblate'`) and returns $N_z$ and $N_{xy}$. For cylinders, the user provides the physical length $L$ and diameter $d$; for spheroids, the aspect ratio.

### References

- Osborn, J.A., "Demagnetizing factors of the general ellipsoid," *Phys. Rev.* **67**, 351 (1945).
- Chen, D.-X., Brug, J.A. & Goldfarb, R.B., "Demagnetizing factors for cylinders," *IEEE Trans. Magn.* **27**, 3601 (1991).
- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Ch. 2.

---

## FORC Analysis

### Theory

**First-Order Reversal Curves (FORCs)** provide a two-dimensional map of the coercivity and interaction field distributions in a magnetic system. The measurement protocol is:

1. Saturate the sample at positive saturation $H_\mathrm{sat}$.
2. Decrease the field to a **reversal field** $H_a < H_\mathrm{sat}$.
3. Measure $M$ as the field increases from $H_a$ back toward $H_\mathrm{sat}$. The measurement field is denoted $H_b \geq H_a$.
4. Repeat for a series of reversal fields $H_a$, sampling the $(H_a, H_b)$ plane.

The **FORC distribution** is defined as the mixed second derivative:

$$\rho(H_a, H_b) = -\frac{1}{2}\frac{\partial^2 M}{\partial H_a \, \partial H_b}$$

The factor of $-1/2$ and the sign convention ensure that $\rho \geq 0$ for physical (irreversible) magnetization processes.

#### Physical coordinates

The raw $(H_a, H_b)$ coordinates are transformed to physically meaningful axes:

$$H_c = \frac{H_b - H_a}{2} \geq 0 \qquad \text{(coercivity)}$$

$$H_u = \frac{H_a + H_b}{2} \qquad \text{(interaction/bias field)}$$

In FORC space, the distribution $\rho(H_c, H_u)$ reveals:

- **Peak position along $H_c$**: the characteristic coercivity of the dominant magnetic phase.
- **Spread along $H_c$**: the coercivity distribution (grain size distribution, shape anisotropy variation).
- **Spread along $H_u$**: the strength of magnetostatic interactions between particles/grains. Non-interacting single-domain particles produce a ridge centered on $H_u = 0$; strong interactions broaden the distribution along $H_u$.
- **Negative regions**: reversible magnetization processes contribute $\rho < 0$ near the $H_c = 0$ axis.

#### Numerical evaluation

The mixed partial derivative is estimated by fitting a local second-order polynomial in a $(2\,\mathrm{SF}+1)$-point sliding window (the Pike method):

$$m(H_a, H_b) = c_1 + c_2 H_a + c_3 H_b + c_4 H_a H_b + c_5 H_a^2 + c_6 H_b^2$$

The FORC distribution is then:

$$\rho = -\frac{1}{2} c_4$$

The **smoothing factor** SF controls the trade-off between spatial resolution and noise suppression. Larger SF produces smoother diagrams at the cost of resolving closely spaced features.

### When to use

- You have a set of FORC curves (tens to hundreds of partial hysteresis loops) measured on a VSM or SQUID.
- You want to distinguish single-domain vs multi-domain behavior, quantify interaction fields, identify multiple magnetic phases, or characterize recording media.
- FORC diagrams are particularly powerful for samples where standard hysteresis parameters ($H_c$, $M_r/M_s$) are insufficient --- e.g., mixtures of soft and hard phases, or systems where interaction effects obscure intrinsic coercivity.

### Implementation

The function `calc.magnetic.forcDiagram` takes the reversal field vector $H_a$, the measurement field matrix $H_b$, and the magnetization matrix $M$, then computes $\rho(H_c, H_u)$ on a regular grid. The smoothing factor and grid resolution are adjustable. Output includes suggested contour levels based on percentiles of the positive $\rho$ values.

### References

- Pike, C.R., Roberts, A.P. & Verosub, K.L., "Characterizing interactions in fine magnetic particle systems using first order reversal curves," *J. Appl. Phys.* **85**, 6660 (1999).
- Pike, C.R., "First-order reversal-curve diagrams and reversible magnetization," *Phys. Rev. B* **68**, 104424 (2003).
- Roberts, A.P. et al., "First-order reversal curve diagrams: A new tool for characterizing the magnetic properties of natural samples," *J. Geophys. Res.* **105**, 28461 (2000).

---

## Kissinger Analysis

### Theory

The **Kissinger method** extracts an activation energy $E_a$ from the shift of a thermal analysis peak (DSC, DTA, TGA derivative, or magnetic transition) with heating rate. The governing equation assumes thermally activated kinetics with an Arrhenius rate:

$$\frac{d\alpha}{dt} = A(1-\alpha)^n \exp\left(-\frac{E_a}{RT}\right)$$

where $\alpha$ is the fraction transformed, $A$ is a pre-exponential factor, $n$ is the reaction order, and $R$ is the gas constant. Kissinger (1957) showed that at the peak temperature $T_p$, the following relation holds regardless of $n$:

$$\ln\frac{\beta}{T_p^2} = -\frac{E_a}{R}\cdot\frac{1}{T_p} + \text{const}$$

where $\beta$ is the heating rate (K/min). A plot of $\ln(\beta/T_p^2)$ vs $1/T_p$ is linear with slope $-E_a/R$:

$$E_a = -\text{slope} \times R$$

In SI units, $R = 8.314$ J/(mol K). To convert to eV per atom: $E_a \,[\text{eV}] = E_a \,[\text{J/mol}] \,/\, (N_A \cdot e)$, where $e = 1.602 \times 10^{-19}$ J/eV.

#### Conventional plot

The x-axis is typically displayed as $1000/T_p$ (units of $10^3$ K$^{-1}$), which scales the slope by a factor of 1000. The implementation accounts for this rescaling when producing plot data.

### When to use

- You have DSC/DTA peak temperatures at three or more heating rates.
- Typical applications: crystallization kinetics of amorphous alloys, magnetic annealing (e.g., exchange bias setting temperature), decomposition reactions, glass transition in polymers.
- The method assumes a single rate-limiting thermally activated process. If the mechanism changes with temperature, the Kissinger plot will be nonlinear --- check $R^2$.
- At least 3 heating rates are required; 5+ rates spanning a factor of 10 in $\beta$ give more reliable results.

### Implementation

The function `calc.magnetic.kissinger` performs the linear fit, returning $E_a$ in both eV and kJ/mol, the $R^2$ value, and plot-ready data with the conventional $1000/T_p$ x-axis.

### References

- Kissinger, H.E., "Reaction kinetics in differential thermal analysis," *Anal. Chem.* **29**, 1702 (1957).
- Blaine, R.L. & Kissinger, H.E., "Homer Kissinger and the Kissinger equation," *Thermochim. Acta* **540**, 1 (2012).

---

## Background Subtraction

### Theory

A measured $M(T)$ curve often contains contributions from multiple sources:

$$M_\mathrm{total}(T) = M_\mathrm{ferro}(T) + \chi_\mathrm{bg} \, H + M_0$$

where $M_\mathrm{ferro}(T)$ is the ferromagnetic signal of interest, $\chi_\mathrm{bg}$ is a temperature-independent susceptibility from diamagnetic (substrate, sample holder) or Pauli paramagnetic contributions, and $M_0$ is a constant offset. At temperatures well above $T_C$, the ferromagnetic contribution vanishes or is negligible, leaving a linear background:

$$M_\mathrm{bg}(T) = \chi_\mathrm{bg} \, H + M_0 \approx a \, T + b$$

Note that for a field-cooled $M(T)$ measurement at constant $H$, the background appears as a linear function of $T$ because $\chi_\mathrm{bg} H$ is constant and any residual temperature dependence (e.g., from a weak Curie tail of impurities) manifests as a slope.

The procedure is:

1. Select a high-temperature region where only the background contributes (default: top 10% of the temperature range).
2. Fit a line $M_\mathrm{bg} = a T + b$ in that region.
3. Subtract: $M_\mathrm{corr}(T) = M_\mathrm{total}(T) - (aT + b)$.

### When to use

- $M(T)$ measurements on thin films where the substrate (Si, MgO, SrTiO$_3$) has a diamagnetic contribution that can be comparable to or larger than the film signal at high $T$.
- Samples with a small ferromagnetic moment on a large paramagnetic or diamagnetic background.
- **Not appropriate** when the background is nonlinear (e.g., Curie-Weiss paramagnetic impurity phase). In that case, fit and subtract the impurity Curie-Weiss contribution separately.

### Implementation

The function `utilities.subtractMagBackground` fits a linear background in the high-$T$ region (auto-selected or user-specified) and subtracts it from the full dataset. Returns the corrected moment, slope, and intercept.

### References

- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Ch. 1.
- Quantum Design Application Notes: "Subtracting the diamagnetic background in SQUID measurements."

---

## Unit Conversions

### CGS vs SI in magnetometry

Magnetometry remains one of the last fields where CGS units are widely used alongside SI, because the major SQUID and VSM manufacturers (Quantum Design, Lake Shore) report data in CGS. The key quantities and their conversions:

| Quantity | CGS unit | SI unit | Conversion |
|----------|----------|---------|------------|
| Magnetic moment $m$ | emu | A m$^2$ | 1 emu = $10^{-3}$ A m$^2$ |
| Magnetization $M$ | emu/cm$^3$ | A/m | 1 emu/cm$^3$ = $10^3$ A/m |
| Magnetic field $H$ | Oe | A/m | 1 Oe = $10^3/(4\pi)$ A/m $\approx$ 79.577 A/m |
| Magnetic induction $B$ | G | T | 1 G = $10^{-4}$ T |
| Susceptibility $\chi$ (vol.) | emu/(cm$^3$ Oe) [dim'less] | dim'less (SI) | $\chi_\mathrm{SI} = 4\pi \chi_\mathrm{CGS}$ |
| Molar susceptibility $\chi_m$ | emu/(Oe mol) | m$^3$/mol | 1 emu/(Oe mol) = $4\pi \times 10^{-6}$ m$^3$/mol |

### Magnetization from moment and volume

$$M = \frac{m}{V}$$

where $m$ is the total moment and $V$ is the sample volume. In CGS: $M$ [emu/cm$^3$] = $m$ [emu] / $V$ [cm$^3$]. Converting to SI:

$$M_\mathrm{SI} \,[\text{A/m}] = M_\mathrm{CGS} \,[\text{emu/cm}^3] \times 10^3$$

### Bohr magneton conversions

The Bohr magneton is the natural unit of atomic magnetic moments:

$$\mu_B = \frac{e\hbar}{2m_e} = \begin{cases} 9.2740100783 \times 10^{-24} \text{ J/T} = \text{A m}^2 & \text{(SI)} \\ 9.2740100783 \times 10^{-21} \text{ emu} & \text{(CGS)} \end{cases}$$

To express a measured moment in Bohr magnetons:

$$n_{\mu_B} = \frac{m}{\mu_B}$$

using $\mu_B$ in the same unit system as $m$.

### Moment per atom

Given a total sample moment $m$, volume $V$, and atomic number density $n_\mathrm{at}$ (atoms/cm$^3$):

$$\mu_\mathrm{atom} = \frac{m / V}{n_\mathrm{at}} = \frac{M}{n_\mathrm{at}} \quad [\text{emu/atom}]$$

$$\mu_\mathrm{atom} \,[\mu_B/\text{atom}] = \frac{\mu_\mathrm{atom} \,[\text{emu}]}{\mu_B \,[\text{emu}]}$$

For example, bcc Fe has $n_\mathrm{at} = 8.49 \times 10^{22}$ atoms/cm$^3$ and $M_s = 1714$ emu/cm$^3$ at 0 K, giving $\mu_\mathrm{atom} = 2.22 \, \mu_B$/atom.

### Implementation

- `calc.magnetic.magnetization` --- moment + volume to $M$ in emu/cm$^3$, A/m, and kA/m.
- `calc.magnetic.bohrMagnetonConvert` --- moment in emu, A m$^2$, or J/T to number of Bohr magnetons.
- `calc.magnetic.momentPerAtom` --- total moment + volume + atom density to $\mu_B$/atom.

### References

- Jackson, J.D., *Classical Electrodynamics*, 3rd ed., Wiley, 1999, Appendix on units.
- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Appendix 1 (unit conversion tables).

---

## References

1. Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., IEEE Press / Wiley, 2009.
2. Kittel, C., *Introduction to Solid State Physics*, 8th ed., Wiley, 2005.
3. Blundell, S.J., *Magnetism in Condensed Matter*, Oxford University Press, 2001.
4. Osborn, J.A., "Demagnetizing factors of the general ellipsoid," *Phys. Rev.* **67**, 351--357 (1945). [DOI: 10.1103/PhysRev.67.351](https://doi.org/10.1103/PhysRev.67.351)
5. Chen, D.-X., Brug, J.A. & Goldfarb, R.B., "Demagnetizing factors for cylinders," *IEEE Trans. Magn.* **27**, 3601--3619 (1991).
6. Pike, C.R., Roberts, A.P. & Verosub, K.L., "Characterizing interactions in fine magnetic particle systems using first order reversal curves," *J. Appl. Phys.* **85**, 6660 (1999). [DOI: 10.1063/1.370176](https://doi.org/10.1063/1.370176)
7. Pike, C.R., "First-order reversal-curve diagrams and reversible magnetization," *Phys. Rev. B* **68**, 104424 (2003).
8. Roberts, A.P. et al., "First-order reversal curve diagrams: A new tool for characterizing the magnetic properties of natural samples," *J. Geophys. Res.* **105**, 28461 (2000).
9. Kissinger, H.E., "Reaction kinetics in differential thermal analysis," *Anal. Chem.* **29**, 1702--1706 (1957). [DOI: 10.1021/ac60131a045](https://doi.org/10.1021/ac60131a045)
10. Stoner, E.C. & Wohlfarth, E.P., "A mechanism of magnetic hysteresis in heterogeneous alloys," *Phil. Trans. R. Soc. A* **240**, 599--642 (1948).
11. Jackson, J.D., *Classical Electrodynamics*, 3rd ed., Wiley, 1999.
