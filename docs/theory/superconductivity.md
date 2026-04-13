# Superconductivity

This document covers the physics behind the `+calc/+superconductor/` module, which provides tools for extracting superconducting parameters from experimental data. The module handles transition temperature extraction from transport measurements, BCS gap analysis, London electrodynamics, Ginzburg-Landau theory, critical fields, depairing currents, and Bean critical-state analysis of magnetization hysteresis loops.

---

## Transition Temperature Extraction

### Theory

The superconducting transition temperature $T_c$ is the temperature at which a material enters the superconducting state. In a resistivity measurement, the transition appears as a drop from the normal-state resistance $R_n$ to zero. Because real transitions have finite width (due to inhomogeneity, flux flow, or grain boundary effects), several conventions exist for defining $T_c$ from $R(T)$ data.

**Midpoint criterion.** The most commonly reported definition. $T_c$ is the temperature where the resistance equals half the normal-state value:

$$R(T_c^{\mathrm{mid}}) = \frac{1}{2}\, R_n$$

This is robust against asymmetric transitions and is the default in most transport measurement software.

**Onset criterion.** $T_c^{\mathrm{onset}}$ marks the temperature where resistance first begins to deviate from its normal-state value. Operationally, it is defined as the temperature where $R$ drops to a specified fraction $f_{\mathrm{on}}$ of $R_n$ (typically $f_{\mathrm{on}} = 0.9$):

$$R(T_c^{\mathrm{onset}}) = f_{\mathrm{on}} \cdot R_n$$

The onset $T_c$ is the highest of the three criteria and is most sensitive to the earliest nucleation of superconductivity. It is preferred when reporting the intrinsic $T_c$ of a material with broad transitions.

**Offset criterion.** $T_c^{\mathrm{offset}}$ marks the completion of the transition, defined where $R$ drops to a fraction $f_{\mathrm{off}}$ of $R_n$ (typically $f_{\mathrm{off}} = 0.1$):

$$R(T_c^{\mathrm{offset}}) = f_{\mathrm{off}} \cdot R_n$$

**Transition width.** The difference between onset and offset temperatures quantifies the sharpness of the transition:

$$\Delta T_c = T_c^{\mathrm{onset}} - T_c^{\mathrm{offset}}$$

A narrow transition ($\Delta T_c < 1$ K for conventional superconductors) indicates good sample homogeneity. Broad transitions suggest compositional variation, strain, or granularity.

**Derivative criterion.** $T_c^{\mathrm{deriv}}$ is the temperature at which $|dR/dT|$ reaches its maximum, i.e., the steepest point of the resistive transition:

$$T_c^{\mathrm{deriv}} = \underset{T}{\mathrm{arg\,max}}\; \left|\frac{dR}{dT}\right|$$

This is equivalent to the inflection point of the $R(T)$ curve. The derivative method is less sensitive to the choice of $R_n$ and works well for both warming and cooling sweeps. A smoothing window (moving average) is applied before differentiation to suppress noise.

**Normal-state resistance.** $R_n$ is estimated as the mean resistance in the flat region above $T_c$, identified by finding where $|dR/dT|$ is small (below 20% of the peak derivative) in the upper half of the temperature range.

**Residual resistance ratio.** The RRR provides a measure of sample purity and crystalline quality:

$$\mathrm{RRR} = \frac{R(300\;\mathrm{K})}{R(T_c^{\mathrm{onset}})}$$

Higher RRR indicates lower defect scattering. For example, clean Nb single crystals can have RRR > 100, while sputtered Nb films typically show RRR of 2--10.

### When to use

- **Four-probe resistance vs. temperature** measurements on superconducting wires, films, or bulk samples.
- Works for both warming and cooling sweeps; the derivative criterion is sign-agnostic.
- Data should span from well below to well above the transition. At minimum, include several points in the zero-resistance state and several in the normal state.
- The midpoint criterion is standard for publication; report onset and width as supplementary figures of merit for sample quality.
- For samples with multiple transitions (e.g., multiphase), examine $dR/dT$ directly to resolve individual transitions.

### Implementation

`calc.superconductor.extractTc` sorts data by temperature, estimates $R_n$ from the flat normal-state region, then extracts each $T_c$ criterion via linear interpolation through the relevant resistance level. The derivative method uses a smoothed $dR/dT$ with the search restricted to the central 70% of the temperature range to avoid edge artefacts.

### References

- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 1--2.
- Ekin, J. W. *Experimental Techniques for Low-Temperature Measurements*, Oxford University Press, 2006, Ch. 9.

---

## BCS Energy Gap

### Theory

The Bardeen-Cooper-Schrieffer (BCS) theory predicts that the superconducting energy gap $\Delta(T)$ vanishes at $T_c$ and saturates to a maximum value $\Delta_0 = \Delta(0)$ at zero temperature. The full BCS gap equation is an implicit integral equation that must be solved numerically. A widely used analytical approximation due to Muhlschlegel (1959) captures the essential temperature dependence:

$$\frac{\Delta(T)}{\Delta(0)} \approx \tanh\!\left(1.74\,\sqrt{\frac{T_c}{T} - 1}\right) \qquad \text{for } T < T_c$$

$$\Delta(T) = 0 \qquad \text{for } T \geq T_c$$

This approximation is accurate to within 2% of the full BCS solution across the entire temperature range.

**BCS coupling ratio.** The ratio of the zero-temperature gap to $T_c$ is a dimensionless measure of coupling strength:

$$\frac{2\Delta_0}{k_B T_c} = 3.528 \qquad \text{(weak-coupling BCS)}$$

Deviations from 3.528 indicate strong-coupling effects (Eliashberg theory). Typical values:

| Material | $T_c$ (K) | $\Delta_0$ (meV) | $2\Delta_0 / k_B T_c$ |
|----------|-----------|-------------------|----------------------|
| Al       | 1.18      | 0.172             | 3.38                 |
| Sn       | 3.72      | 0.592             | 3.69                 |
| Nb       | 9.25      | 1.55              | 3.88                 |
| Pb       | 7.19      | 1.33              | 4.29                 |
| NbN      | 16.0      | 2.6               | 3.77                 |

Materials with ratios significantly above 3.528 (e.g., Pb at 4.29) are strong-coupling superconductors.

**Penetration depth mode.** When the input is $\lambda(T)$ rather than $\Delta(T)$, the two-fluid (Gorter-Casimir) model is used instead:

$$\lambda(T) = \frac{\lambda_0}{\sqrt{1 - (T/T_c)^4}}$$

where $\lambda_0 = \lambda(0)$ is the zero-temperature penetration depth. This empirical expression follows from the two-fluid picture in which the superfluid fraction varies as $n_s/n = 1 - (T/T_c)^4$. It is not derived from BCS microscopics but agrees well with experiment for conventional superconductors.

### When to use

- **Tunneling spectroscopy** (SIS or SIN junctions): direct measurement of $\Delta(T)$.
- **Point-contact spectroscopy** (Andreev reflection): gap extraction from conductance fits.
- **Muon spin rotation** ($\mu$SR) or **microwave cavity** measurements: $\lambda(T)$ data that can be fit to the two-fluid model.
- Compare the fitted $2\Delta_0 / k_B T_c$ to 3.528 to assess coupling strength.
- For multi-gap superconductors (e.g., MgB$_2$ with $\sigma$ and $\pi$ bands), the single-gap BCS model is insufficient; fit each gap separately or use an appropriate two-gap model.

### Implementation

`calc.superconductor.bcsGap` accepts either gap or penetration-depth data. For gap data, $\Delta_0$ is estimated from the low-temperature plateau ($T < 0.3\,T_c$). $T_c$ can be auto-detected (from where $\Delta \to 0$) or supplied explicitly. The Muhlschlegel approximation generates the theoretical curve on a fine temperature grid.

### References

- Bardeen, J., Cooper, L. N. & Schrieffer, J. R. "Theory of Superconductivity," *Phys. Rev.* **108**, 1175 (1957). DOI: [10.1103/PhysRev.108.1175](https://doi.org/10.1103/PhysRev.108.1175)
- Muhlschlegel, B. "Die thermodynamischen Funktionen des Supraleiters," *Z. Phys.* **155**, 313 (1959). DOI: [10.1007/BF01332932](https://doi.org/10.1007/BF01332932)
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 3 (especially Table 3.1 for the gap approximation).

---

## London Penetration Depth

### Theory

The London penetration depth $\lambda_L$ characterizes how deeply an external magnetic field penetrates into a superconductor. It arises from the London equation:

$$\nabla^2 \mathbf{B} = \frac{1}{\lambda_L^2}\,\mathbf{B}$$

which yields exponential screening of the magnetic field: $B(x) = B_0\,e^{-x/\lambda_L}$ at a planar surface. The zero-temperature London penetration depth is:

$$\lambda_L(0) = \sqrt{\frac{m^* c^2}{4\pi n_s e^2}}$$

in Gaussian CGS, where $m^*$ is the effective mass of the charge carriers, $n_s$ is the superfluid density, and $e$ is the electron charge.

The temperature dependence follows the Gorter-Casimir two-fluid model:

$$\lambda(T) = \frac{\lambda_0}{\sqrt{1 - (T/T_c)^4}}$$

This expression diverges as $T \to T_c$ (complete flux penetration at the transition) and reduces to $\lambda_0$ at $T = 0$.

**Physical interpretation.** $\lambda$ sets the length scale for the Meissner effect. A larger $\lambda$ means weaker screening and a larger volume fraction of the superconductor that is penetrated by flux. Typical values:

| Material | $\lambda_0$ (nm) | Notes |
|----------|------------------|-------|
| Al       | 16               | Type I, very short |
| Nb       | 39               | Elemental type II |
| YBCO     | 150              | Cuprate, anisotropic ($\lambda_{ab}$) |
| NbN      | 200              | Disordered, large $\lambda$ |

### When to use

- Calculating the Meissner screening length for thin-film design (film thickness vs. $\lambda$).
- Input to the GL parameter $\kappa = \lambda / \xi$ for classifying type I vs. type II behavior.
- Input to lower critical field $H_{c1}$ and depairing current $J_d$ calculations.
- Fitting $\lambda(T)$ from $\mu$SR, microwave resonator, or mutual inductance measurements.

### Implementation

`calc.superconductor.londonDepth` computes $\lambda(T)$ from $\lambda_0$ and $T_c$ using the two-fluid formula. Parameters can be supplied directly or loaded from material presets.

### References

- London, F. & London, H. "The Electromagnetic Equations of the Supraconductor," *Proc. R. Soc. Lond. A* **149**, 71 (1935). DOI: [10.1098/rspa.1935.0048](https://doi.org/10.1098/rspa.1935.0048)
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 1.2 and Ch. 2.

---

## Coherence Length

### Theory

The coherence length $\xi$ is the characteristic length scale over which the superconducting order parameter $\psi$ can vary. It has two distinct physical origins.

**Pippard (BCS) coherence length** $\xi_0$. This is the intrinsic coherence length of a clean superconductor at $T = 0$, related to the Fermi velocity $v_F$ and the energy gap:

$$\xi_0 = \frac{\hbar v_F}{\pi \Delta_0}$$

For clean elemental superconductors, $\xi_0$ can be very large (e.g., $\xi_0 \approx 1600$ nm for Al), while for dirty or high-$T_c$ materials it is much shorter ($\xi_0 \approx 1.5$ nm for YBCO).

**Ginzburg-Landau coherence length** $\xi(T)$. Near $T_c$, GL theory gives a temperature-dependent coherence length that diverges at the transition. The standard dirty-limit (Gorkov) approximation is:

$$\xi(T) = \frac{\xi_0}{\sqrt{1 - (T/T_c)^2}}$$

This divergence reflects the fact that fluctuations of the order parameter become long-ranged as the system approaches the normal state. The expression is valid in the GL regime near $T_c$ and is commonly used as an interpolation formula at lower temperatures as well.

**Physical interpretation.** The coherence length sets the minimum length scale for spatial variations of the superconducting state. It determines:
- The size of a vortex core in type-II superconductors (core radius $\sim \xi$).
- The upper critical field $H_{c2} \propto 1/\xi^2$.
- Whether a superconductor is type I or type II (through $\kappa = \lambda/\xi$).

Representative values of $\xi_0$:

| Material | $\xi_0$ (nm) | Type |
|----------|-------------|------|
| Al       | 1600        | I    |
| Sn       | 230         | I    |
| Pb       | 83          | I    |
| Nb       | 38          | II   |
| NbN      | 5           | II   |
| YBCO     | 1.5         | II   |

### When to use

- Determining whether a thin film is in the 2D limit ($d < \xi$) or 3D limit ($d \gg \xi$).
- Computing vortex core sizes for imaging experiments (STM, MFM).
- Input to $H_{c2}$ and $\kappa$ calculations.
- Estimating the minimum feature size for superconducting device fabrication (nanowires, Josephson junctions).

### Implementation

`calc.superconductor.coherenceLength` computes $\xi(T)$ from $\xi_0$ and $T_c$ using the Gorkov temperature dependence. Parameters can be loaded from material presets.

### References

- Pippard, A. B. "An Experimental and Theoretical Study of the Relation between Magnetic Field and Current in a Superconductor," *Proc. R. Soc. Lond. A* **216**, 547 (1953). DOI: [10.1098/rspa.1953.0040](https://doi.org/10.1098/rspa.1953.0040)
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 3.4 and Ch. 4.

---

## Ginzburg-Landau Parameter

### Theory

The Ginzburg-Landau parameter $\kappa$ is the ratio of the two fundamental length scales:

$$\kappa = \frac{\lambda}{\xi}$$

It classifies superconductors into two types based on the sign of the surface energy at a normal-superconducting interface:

$$\begin{cases}
\kappa < \frac{1}{\sqrt{2}} \approx 0.707 & \Longrightarrow \text{Type I: positive surface energy, complete Meissner effect} \\[6pt]
\kappa > \frac{1}{\sqrt{2}} & \Longrightarrow \text{Type II: negative surface energy, mixed state with vortices}
\end{cases}$$

**Type I** superconductors (most elemental metals: Al, Pb, In, Sn) undergo a first-order phase transition from the Meissner state directly to the normal state at $H_c$. The intermediate state (domains of normal and superconducting regions) appears in non-ellipsoidal geometries due to demagnetization.

**Type II** superconductors (Nb, alloys, all high-$T_c$ materials) have two critical fields. Between $H_{c1}$ and $H_{c2}$, magnetic flux enters as quantized Abrikosov vortices, each carrying one flux quantum $\Phi_0 = h/2e = 2.068 \times 10^{-15}$ Wb.

Since both $\lambda(T)$ and $\xi(T)$ diverge as $T \to T_c$ with the same exponent in GL theory, $\kappa$ is approximately temperature-independent (a material constant). In practice, it varies weakly with temperature, particularly in dirty-limit or anisotropic materials.

### When to use

- Classifying a newly characterized superconductor as type I or type II.
- Quick check before applying type-II-specific formulas ($H_{c1}$, $H_{c2}$, vortex physics).
- Comparing the relative importance of flux penetration vs. order parameter suppression at interfaces.

### Implementation

`calc.superconductor.glParameter` computes $\kappa$ from $\lambda$ and $\xi$, either supplied directly or calculated at temperature $T$ from material presets. It returns the type classification based on the $1/\sqrt{2}$ boundary.

### References

- Ginzburg, V. L. & Landau, L. D. "On the Theory of Superconductivity," *Zh. Eksp. Teor. Fiz.* **20**, 1064 (1950). English translation in: *Collected Papers of L.D. Landau*, ed. D. ter Haar, Pergamon, 1965.
- Abrikosov, A. A. "On the Magnetic Properties of Superconductors of the Second Group," *Sov. Phys. JETP* **5**, 1174 (1957).
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 4.5.

---

## Critical Fields

### Theory

Superconductors are characterized by critical magnetic fields above which superconductivity is destroyed.

**Thermodynamic critical field** $H_c$. This is defined by the condensation energy density (the free-energy difference between normal and superconducting states):

$$\frac{H_c^2}{8\pi} = f_n - f_s$$

in Gaussian CGS. The temperature dependence is well approximated by:

$$H_c(T) = H_{c,0}\left[1 - \left(\frac{T}{T_c}\right)^2\right]$$

For type-I superconductors, $H_c$ is the field at which superconductivity is destroyed. For type-II superconductors, $H_c$ is a thermodynamic quantity that relates to $H_{c1}$ and $H_{c2}$ but is not directly observable as a sharp transition.

**Lower critical field** $H_{c1}$ (type II only). The field at which it becomes energetically favorable for the first vortex to enter the superconductor:

$$H_{c1} = \frac{\Phi_0 \ln\kappa}{4\pi \lambda^2}$$

in Gaussian CGS, where $\Phi_0 = 2.068 \times 10^{-7}$ G$\cdot$cm$^2$ is the flux quantum and $\lambda$ is in cm. Below $H_{c1}$, the superconductor is in the complete Meissner state.

**Upper critical field** $H_{c2}$ (type II only). The field at which the vortex cores overlap and bulk superconductivity is destroyed:

$$H_{c2} = \frac{\Phi_0}{2\pi \xi^2}$$

in Gaussian CGS, where $\xi$ is in cm. This can be rewritten as:

$$H_{c2} = \sqrt{2}\,\kappa\,H_c$$

**Relations between critical fields.** For a type-II superconductor:

$$H_c = \frac{H_{c2}}{\sqrt{2}\,\kappa} = \sqrt{H_{c1} \cdot H_{c2}} \cdot \frac{1}{\sqrt{\ln\kappa}} \quad (\text{approximate})$$

The three fields satisfy $H_{c1} < H_c < H_{c2}$ for $\kappa > 1/\sqrt{2}$.

**Representative values at $T = 0$:**

| Material | Type | $H_{c,0}$ (Oe) | $H_{c1}$ (Oe) | $H_{c2}$ (Oe) |
|----------|------|----------------|----------------|----------------|
| Al       | I    | 105            | --             | --             |
| Pb       | I    | 803            | --             | --             |
| Nb       | II   | 1980           | ~1700          | ~4000          |
| NbN      | II   | --             | ~100           | ~80,000        |
| YBCO     | II   | --             | ~100           | ~1,000,000     |

### When to use

- Determining the operating field range for a superconducting device.
- Estimating $H_{c2}(0)$ from $\xi_0$ to predict the maximum field a material can withstand.
- Designing experiments: ensuring the applied field stays below $H_{c1}$ for Meissner-state measurements or above $H_{c1}$ for vortex studies.
- The parabolic $H_c(T)$ approximation is suitable for conventional superconductors. For cuprates and iron-based superconductors, $H_{c2}(T)$ may follow the Werthamer-Helfand-Hohenberg (WHH) theory instead.

### Implementation

`calc.superconductor.criticalFields` computes $H_c(T)$ from the parabolic approximation. For type-II materials, it also computes $H_{c1}$ and $H_{c2}$ using $\lambda(T)$ and $\xi(T)$ from the `londonDepth` and `coherenceLength` modules. The flux quantum uses SI ($\Phi_0$ in Wb) converted to CGS ($\Phi_0$ in G$\cdot$cm$^2$ via $1\;\text{Wb} = 10^8\;\text{G}\cdot\text{cm}^2$).

### References

- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 4.
- Orlando, T. P. & Delin, K. A. *Foundations of Applied Superconductivity*, Addison-Wesley, 1991, Ch. 7.

---

## Depairing Current

### Theory

The depairing current density $J_d$ is the maximum supercurrent a superconductor can carry before the kinetic energy of the Cooper pairs exceeds the condensation energy, destroying superconductivity. It represents the fundamental upper limit on the critical current density (real materials are limited by vortex motion, grain boundaries, and other mechanisms to $J_c \ll J_d$).

In Ginzburg-Landau theory, the depairing current density is:

$$J_d = \frac{H_c}{3\sqrt{6}\,\pi\,\lambda}$$

where $H_c$ is the thermodynamic critical field and $\lambda$ is the penetration depth, both evaluated at the measurement temperature $T$. This expression gives $J_d$ in Gaussian-CGS units (Oe/cm). The conversion to SI-practical units is:

$$J_d\;[\text{A/cm}^2] = \frac{H_c(T)\;[\text{Oe}]}{3\sqrt{6}\,\pi\,\lambda(T)\;[\text{cm}]} \times \frac{10^3}{4\pi}$$

The temperature dependence enters through both $H_c(T)$ and $\lambda(T)$:

$$J_d(T) \propto \frac{1 - (T/T_c)^2}{\left[1 - (T/T_c)^4\right]^{-1/2}} = \left[1 - \left(\frac{T}{T_c}\right)^2\right] \sqrt{1 - \left(\frac{T}{T_c}\right)^4}$$

which decreases from its maximum at $T = 0$ and vanishes at $T = T_c$.

**Practical significance.** The ratio $J_c / J_d$ quantifies how close a material operates to its theoretical limit. Typical values:

- Nb thin films: $J_d(0) \sim 30$--$50$ MA/cm$^2$
- Epitaxial YBCO films: $J_c / J_d \sim 0.1$--$0.3$ (impressive for a high-$T_c$)
- Bulk wire conductors: $J_c / J_d \sim 0.01$--$0.05$

### When to use

- Estimating the theoretical maximum current capacity of superconducting nanowires (single photon detectors, kinetic inductance devices).
- Benchmarking measured $J_c$ against the depairing limit to assess material quality.
- Designing superconducting stripline resonators where the microwave current must stay below $J_d$.

### Implementation

`calc.superconductor.depairingCurrent` obtains $H_c(T)$ from `criticalFields` and $\lambda(T)$ from `londonDepth`, then applies the GL formula with CGS-to-SI unit conversion. Output is provided in both A/cm$^2$ and MA/cm$^2$.

### References

- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 4.7.
- Kupriyanov, M. Yu. & Lukichev, V. F. "Temperature dependence of pair-breaking current in superconductors," *Sov. J. Low Temp. Phys.* **6**, 210 (1980).

---

## Bean Critical-State Model

### Theory

The Bean model (1962, 1964) provides a simple framework for extracting the critical current density $J_c$ from magnetization hysteresis loops $M(H)$ of type-II superconductors. The central assumption is that the current density in the superconductor is everywhere either zero or at the critical value $\pm J_c$, with no intermediate values. This is the critical-state hypothesis.

When an external field is applied to a type-II superconductor in the mixed state ($H > H_{c1}$), flux vortices penetrate from the surface and are pinned by defects. The resulting flux gradient produces a macroscopic current density equal to $J_c$. The magnetization hysteresis $\Delta M = M_{\uparrow} - M_{\downarrow}$ (the difference between the ascending and descending branches of the $M(H)$ loop) is directly proportional to $J_c$.

**Rectangular cross-section** (slab with cross-section $a \times b$, where $a \leq b$, in cm):

$$J_c\;[\text{A/cm}^2] = \frac{20\;\Delta M}{a\left(1 - \frac{a}{3b}\right)}$$

where $\Delta M$ is in emu and the factor of 20 encodes the CGS Gaussian unit conversion ($c / 4\pi$ in appropriate units). The geometric correction factor $(1 - a/3b)$ accounts for the non-uniform current distribution in a finite-aspect-ratio cross-section. For a square cross-section ($a = b$), this factor is $2/3$; for a thin strip ($a \ll b$), it approaches 1.

**Cylindrical cross-section** (radius $R$ in cm):

$$J_c\;[\text{A/cm}^2] = \frac{3\;\Delta M}{2R\;V}$$

where $V$ is the sample volume in cm$^3$.

**Conventions.** The $\Delta M$ used in these formulas is the full-width of the hysteresis loop, i.e., $|M_{\uparrow} - M_{\downarrow}|$ at a given field. Some references use the half-width with correspondingly different prefactors; the implementation here uses the full width with the prefactors shown above.

**Field dependence.** The Bean model yields $J_c$ at each field value. The resulting $J_c(H)$ curve is important for applications: a rapid decrease of $J_c$ with $H$ indicates weak pinning, while a slowly decreasing $J_c(H)$ indicates strong pinning (desirable for magnets and cables).

### When to use

- **DC magnetometry** (SQUID, VSM) on type-II superconducting samples: bulk pellets, single crystals, or films.
- The sample must exhibit a well-defined hysteresis loop with separated ascending and descending branches.
- Sample dimensions must be known accurately, as $J_c$ scales inversely with the cross-section dimension.
- The Bean model assumes field-independent $J_c$, which is only approximately true. For strongly field-dependent $J_c$, the result at each field point should be interpreted as a local average.
- Low-field data (below $\sim 10\%$ of the maximum applied field) are excluded because the central peak in $\Delta M$ near $H = 0$ is contaminated by flux trapping and surface barrier effects.

### Implementation

`calc.superconductor.beanJc` splits the hysteresis loop into ascending and descending branches at the field extremum, interpolates both onto a common grid, computes $\Delta M(H)$, and applies the appropriate Bean formula. The function accepts both CGS (Oe, emu) and SI (T, A$\cdot$m$^2$) units with automatic conversion.

### References

- Bean, C. P. "Magnetization of Hard Superconductors," *Phys. Rev. Lett.* **8**, 250 (1962). DOI: [10.1103/PhysRevLett.8.250](https://doi.org/10.1103/PhysRevLett.8.250)
- Bean, C. P. "Magnetization of High-Field Superconductors," *Rev. Mod. Phys.* **36**, 31 (1964). DOI: [10.1103/RevModPhys.36.31](https://doi.org/10.1103/RevModPhys.36.31)
- Gyorgy, E. M. et al. "Anisotropy of the magnetization in superconducting YBa$_2$Cu$_3$O$_7$," *J. Appl. Phys.* **61**, 3802 (1987).
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 5.

---

## Material Presets

The module includes reference parameters for eight superconductors, sourced from Tinkham (2004) and Orlando & Delin (1991):

| Material | $T_c$ (K) | $\lambda_0$ (nm) | $\xi_0$ (nm) | $H_{c,0}$ (Oe) | $\Delta_0$ (meV) | Type |
|----------|-----------|-------------------|---------------|----------------|-------------------|------|
| Nb       | 9.25      | 39                | 38            | 1980           | 1.55              | II   |
| NbN      | 16.0      | 200               | 5             | 80,000*        | 2.6               | II   |
| YBCO     | 92        | 150               | 1.5           | --             | 20                | II   |
| MgB$_2$  | 39        | 140               | 5             | --             | 7.1               | II   |
| Al       | 1.18      | 16                | 1600          | 105            | 0.172             | I    |
| Pb       | 7.19      | 37                | 83            | 803            | 1.33              | I    |
| In       | 3.41      | 24                | 440           | 282            | 0.541             | I    |
| Sn       | 3.72      | 34                | 230           | 305            | 0.592             | I    |

*NbN $H_{c,0}$ listed as approximate $H_{c2}$; the thermodynamic $H_c$ is not well characterized.

YBCO and MgB$_2$ do not have listed $H_{c,0}$ values because these extreme type-II materials have poorly defined thermodynamic critical fields. Use $H_{c2}$ from the literature instead.

These presets serve as quick references and defaults for calculations. For high-accuracy work, always use experimentally measured values for your specific sample, as parameters depend strongly on purity, stoichiometry, film thickness, and substrate strain.

---

## References

Collected bibliography in alphabetical order.

1. Abrikosov, A. A. "On the Magnetic Properties of Superconductors of the Second Group," *Sov. Phys. JETP* **5**, 1174 (1957).
2. Bardeen, J., Cooper, L. N. & Schrieffer, J. R. "Theory of Superconductivity," *Phys. Rev.* **108**, 1175 (1957).
3. Bean, C. P. "Magnetization of Hard Superconductors," *Phys. Rev. Lett.* **8**, 250 (1962).
4. Bean, C. P. "Magnetization of High-Field Superconductors," *Rev. Mod. Phys.* **36**, 31 (1964).
5. Ekin, J. W. *Experimental Techniques for Low-Temperature Measurements*, Oxford University Press, 2006.
6. Ginzburg, V. L. & Landau, L. D. "On the Theory of Superconductivity," *Zh. Eksp. Teor. Fiz.* **20**, 1064 (1950).
7. Gorter, C. J. & Casimir, H. B. G. "On Supraconductivity I," *Physica* **1**, 306 (1934).
8. Gyorgy, E. M. et al. "Anisotropy of the magnetization in superconducting YBa$_2$Cu$_3$O$_7$," *J. Appl. Phys.* **61**, 3802 (1987).
9. Kupriyanov, M. Yu. & Lukichev, V. F. "Temperature dependence of pair-breaking current in superconductors," *Sov. J. Low Temp. Phys.* **6**, 210 (1980).
10. London, F. & London, H. "The Electromagnetic Equations of the Supraconductor," *Proc. R. Soc. Lond. A* **149**, 71 (1935).
11. Muhlschlegel, B. "Die thermodynamischen Funktionen des Supraleiters," *Z. Phys.* **155**, 313 (1959).
12. Orlando, T. P. & Delin, K. A. *Foundations of Applied Superconductivity*, Addison-Wesley, 1991.
13. Pippard, A. B. "An Experimental and Theoretical Study of the Relation between Magnetic Field and Current in a Superconductor," *Proc. R. Soc. Lond. A* **216**, 547 (1953).
14. Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004.
