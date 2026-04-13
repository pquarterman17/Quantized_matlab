# Electronic Transport

This document covers the physics behind the electrical transport and semiconductor calculator modules in `+calc/+electrical/` and `+calc/+semiconductor/`. The treatment spans metallic conduction (Drude model, Hall effect, Wiedemann-Franz law) through semiconductor carrier statistics and pn junction electrostatics. All formulas are given in SI units unless noted; the calculator functions themselves use CGS-practical units (Ohm-cm, cm^-3, cm^2/V-s) following standard semiconductor conventions.

---

## Resistivity and Conductivity

### Theory

Electrical resistivity $\rho$ is the intrinsic material property that relates the electric field $\mathbf{E}$ to the current density $\mathbf{J}$:

$$\mathbf{E} = \rho \, \mathbf{J}$$

In the Drude model, a free-electron gas with density $n$, charge $e$, and mean scattering time $\tau$ yields:

$$\rho = \frac{m^*}{n e^2 \tau}$$

where $m^*$ is the carrier effective mass. The electrical conductivity is the reciprocal:

$$\sigma = \frac{1}{\rho} = \frac{n e^2 \tau}{m^*}$$

For thin films, one frequently measures the **sheet resistance** $R_\square$ rather than the bulk resistivity. The two are related through the film thickness $t$:

$$R_\square = \frac{\rho}{t}$$

$R_\square$ has units of Ohm/square --- dimensionally identical to Ohm, but the "per square" notation reminds us that it is a property of the sheet geometry, not a bulk quantity. A four-point probe measurement on a thin film yields $R_\square$ directly (with a geometric correction factor); multiplying by the known thickness recovers $\rho$.

The **current density** through a conductor of cross-sectional area $A$ carrying current $I$ is:

$$J = \frac{I}{A}$$

### When to use

- **Resistivity/conductivity**: Convert between $R_\square$ and $\rho$ when characterizing thin film samples by four-point probe or van der Pauw measurements.
- **Sheet resistance**: Compare samples of different thickness on equal footing, or estimate resistance of a patterned thin-film device (resistance = $R_\square \times$ number of squares).

### Reference values

| Material | $\rho$ (Ohm-cm) at 300 K |
|----------|--------------------------|
| Cu       | $1.72 \times 10^{-6}$    |
| Au       | $2.44 \times 10^{-6}$    |
| Si (intrinsic) | $\sim 2.3 \times 10^{5}$ |
| Si (doped, $10^{16}$ cm$^{-3}$) | $\sim 1$  |

---

## Hall Effect

### Theory

When a current $I_x$ flows through a conductor in a magnetic field $B_z$ (perpendicular to the current), a transverse voltage $V_H$ develops. The **Hall coefficient** $R_H$ characterizes this response.

#### Single-carrier model

For a single type of carrier (electrons or holes) with concentration $n$ and charge $q$:

$$R_H = \frac{1}{nq}$$

The sign of $R_H$ identifies the carrier type:
- $R_H < 0$ : electrons (n-type)
- $R_H > 0$ : holes (p-type)

Experimentally, one measures the transverse (Hall) resistance $R_{xy}$ as a function of applied field $B$. In the single-carrier regime, $R_{xy}$ is linear in $B$:

$$R_{xy} = R_H \frac{B}{t}$$

where $t$ is the sample thickness. A linear fit to $R_{xy}(B)$ data gives the slope $dR_{xy}/dB$, from which:

$$R_H = \frac{dR_{xy}}{dB} \cdot t$$

The carrier density follows as:

$$n = \frac{1}{|R_H| \, e}$$

and the **Hall mobility** is:

$$\mu_H = |R_H| \cdot \sigma = \frac{|R_H|}{\rho}$$

#### Two-carrier model

When both electrons (concentration $n$, mobility $\mu_e$) and holes (concentration $p$, mobility $\mu_h$) contribute to conduction, the Hall coefficient becomes:

$$R_H = \frac{1}{e} \cdot \frac{p \mu_h^2 - n \mu_e^2}{(p \mu_h + n \mu_e)^2}$$

This expression reduces to $+1/(pe)$ when $n = 0$ and to $-1/(ne)$ when $p = 0$. In the two-carrier regime, the apparent carrier type from $\operatorname{sign}(R_H)$ does not necessarily reflect the majority carrier --- the carrier with higher $\mu$ has disproportionate weight because it appears squared in the numerator.

**Important**: the two-carrier $R_H$ can change sign as a function of temperature (as $n$, $p$, $\mu_e$, and $\mu_h$ all vary with $T$), producing a sign reversal in $R_{xy}(T)$ that does not indicate a change in majority carrier type.

#### Sheet carrier density

For a thin film or 2D electron gas of thickness $t$ and bulk carrier concentration $n$:

$$n_s = n \cdot t$$

where $n_s$ is the sheet carrier density (cm$^{-2}$). This is the quantity directly extracted from Hall measurements on thin films when thickness is uncertain.

### When to use

- **Single-carrier Hall**: metals, heavily doped semiconductors at low temperature (extrinsic regime), 2DEGs.
- **Two-carrier Hall**: intrinsic or lightly doped semiconductors near room temperature, semimetals (e.g., Bi), narrow-gap semiconductors.
- Antisymmetrize $R_{xy}(B)$ data with respect to field to remove longitudinal magnetoresistance contamination before fitting.

### Sign convention

The calculator follows the **physics convention**: positive $R_H$ corresponds to hole carriers. This is opposite to some engineering references that define $R_H = -1/(ne)$ for electrons as positive. Always check the sign convention when comparing with literature values.

---

## Semiconductor Carrier Statistics

### Intrinsic carrier concentration

In an undoped semiconductor at thermal equilibrium, the intrinsic carrier concentration $n_i$ is determined by the bandgap $E_g$ and the effective densities of states $N_c$ (conduction band) and $N_v$ (valence band):

$$n_i = \sqrt{N_c N_v} \, \exp\!\left(-\frac{E_g}{2 k_B T}\right)$$

The effective densities of states are:

$$N_c = 2 \left(\frac{2\pi \, m_e^* \, k_B T}{h^2}\right)^{3/2}, \qquad N_v = 2 \left(\frac{2\pi \, m_h^* \, k_B T}{h^2}\right)^{3/2}$$

where $m_e^*$ and $m_h^*$ are the density-of-states effective masses for electrons and holes, and $h$ is Planck's constant. Both $N_c$ and $N_v$ scale as $T^{3/2}$.

**Reference value**: for Si at 300 K, $n_i \approx 1.5 \times 10^{10}$ cm$^{-3}$.

### Mass-action law

At thermal equilibrium, the product of electron and hole concentrations is fixed regardless of doping:

$$n \cdot p = n_i^2$$

This is the **mass-action law**. It holds in the non-degenerate regime (Fermi level more than a few $k_B T$ from either band edge).

### Extrinsic carrier concentration

For a semiconductor with donor concentration $N_d$ and acceptor concentration $N_a$:

- **n-type** ($N_d > N_a$): majority carriers are electrons, $n \approx N_d - N_a$, and $p = n_i^2 / n$.
- **p-type** ($N_a > N_d$): majority carriers are holes, $p \approx N_a - N_d$, and $n = n_i^2 / p$.
- **Intrinsic** ($|N_d - N_a| < n_i$): both carriers present at comparable concentrations, $n \approx p \approx n_i$.

These are the complete-ionization approximations, valid when $T$ is high enough that all dopants are ionized (above the freeze-out regime, typically $T > 100$ K for Si).

### Fermi level position

The Fermi level $E_F$ measured relative to the intrinsic level $E_i$ (mid-gap) is:

$$E_F - E_i = k_B T \ln\!\left(\frac{n}{n_i}\right)$$

For n-type material with $n \approx N_d - N_a$:

$$E_F - E_i = k_B T \ln\!\left(\frac{N_d - N_a}{n_i}\right)$$

For p-type material:

$$E_F - E_i = -k_B T \ln\!\left(\frac{N_a - N_d}{n_i}\right)$$

These expressions use the **Boltzmann approximation** to the Fermi-Dirac distribution, valid when $E_F$ is at least $3 k_B T$ from either band edge. For degenerate semiconductors ($n > N_c$ or so), the full Fermi-Dirac integral or the Joyce-Dixon approximation is needed:

$$E_F - E_c \approx k_B T \left[\ln\!\left(\frac{n}{N_c}\right) + \frac{1}{\sqrt{8}} \frac{n}{N_c}\right]$$

The Joyce-Dixon approximation adds a correction term to the Boltzmann result that remains accurate up to moderate degeneracy ($n/N_c \lesssim 5$).

### DOS effective mass

The density-of-states effective mass $m^*$ that enters $N_c$ and $N_v$ is not the same as the band-structure effective mass along a single direction. For a semiconductor with multiple equivalent conduction band minima (e.g., Si has 6 equivalent valleys), the DOS effective mass includes the valley degeneracy $g_v$:

$$m_e^* = g_v^{2/3} \left(m_l \, m_t^2\right)^{1/3}$$

where $m_l$ and $m_t$ are the longitudinal and transverse effective masses. The calculator provides tabulated $m_e^*$ and $m_h^*$ for common materials (Si, Ge, GaAs, InP, GaN, SiC).

### Material presets

The calculator includes the following material parameters at 300 K:

| Material | $E_g$ (eV) | $\varepsilon_r$ | $m_e^*/m_0$ | $m_h^*/m_0$ |
|----------|------------|-----------------|-------------|-------------|
| Si       | 1.12       | 11.7            | 1.08        | 0.81        |
| Ge       | 0.66       | 16.0            | 0.55        | 0.37        |
| GaAs     | 1.42       | 12.9            | 0.067       | 0.45        |
| InP      | 1.35       | 12.5            | 0.08        | 0.60        |
| GaN      | 3.40       | 8.9             | 0.20        | 1.40        |
| 4H-SiC   | 3.26       | 9.7             | 0.37        | 1.00        |
| SiO$_2$  | 9.0        | 3.9             | 0.50        | ---         |
| Al$_2$O$_3$ | 8.8     | 9.0             | 0.40        | ---         |

---

## pn Junction Electrostatics

### Built-in potential

When a p-type and n-type region are brought into contact, diffusion of majority carriers creates a space-charge region. The resulting electrostatic potential difference is the **built-in potential**:

$$V_{bi} = \frac{k_B T}{e} \ln\!\left(\frac{N_a N_d}{n_i^2}\right)$$

For a Si pn junction with $N_a = 10^{16}$ cm$^{-3}$ and $N_d = 10^{17}$ cm$^{-3}$ at 300 K, $V_{bi} \approx 0.76$ V.

### Depletion width

The total depletion width $W$ under the **abrupt junction, full depletion approximation** is:

$$W = \sqrt{\frac{2 \varepsilon_0 \varepsilon_r}{e} \left(\frac{1}{N_a} + \frac{1}{N_d}\right) V_{bi}}$$

where $\varepsilon_0$ is the permittivity of free space and $\varepsilon_r$ is the relative permittivity of the semiconductor. The depletion region extends into each side inversely proportional to the doping:

$$x_n = W \frac{N_a}{N_a + N_d}, \qquad x_p = W \frac{N_d}{N_a + N_d}$$

The more lightly doped side bears the larger fraction of the depletion width.

Under applied bias $V_a$ (forward bias positive), replace $V_{bi}$ with $(V_{bi} - V_a)$ in the expression for $W$. The **junction capacitance per unit area** is:

$$C_j = \frac{\varepsilon_0 \varepsilon_r}{W}$$

This $1/\sqrt{V_{bi} - V_a}$ dependence of $C_j$ is the basis of capacitance-voltage (C-V) profiling, where plotting $1/C^2$ vs. $V_a$ yields a straight line whose slope gives the doping concentration.

### When to use

- Estimating $V_{bi}$ for diode threshold or Schottky barrier analysis.
- Calculating depletion width to ensure a thin film is fully depleted (important for thin-film transistors and photodetectors).
- Designing C-V measurements: the depletion width sets the probed depth.

---

## Carrier Transport Properties

### Drude mobility

The carrier mobility $\mu$ connects drift velocity to applied field ($v_d = \mu E$) and is related to the resistivity by:

$$\mu = \frac{1}{n e \rho}$$

where $n$ is the carrier concentration and $\rho$ is the resistivity (both in consistent units). Mobility is the primary figure of merit for semiconductor material quality and is limited by scattering from lattice vibrations (phonons), ionized impurities, and defects.

### Caughey-Thomas mobility model

For silicon, the empirical **Caughey-Thomas** model describes how mobility depends on total impurity concentration $N_I = N_d + N_a$:

$$\mu(N_I) = \mu_{\min} + \frac{\mu_{\max} - \mu_{\min}}{1 + \left(\dfrac{N_I}{N_{\text{ref}}}\right)^\alpha}$$

with parameters for Si at 300 K:

| Parameter | Electrons | Holes |
|-----------|-----------|-------|
| $\mu_{\min}$ (cm$^2$/V-s) | 88   | 54    |
| $\mu_{\max}$ (cm$^2$/V-s) | 1252 | 407   |
| $N_{\text{ref}}$ (cm$^{-3}$) | $1.26 \times 10^{17}$ | $2.35 \times 10^{17}$ |
| $\alpha$ | 0.88 | 0.88 |

At low doping ($N_I \ll N_{\text{ref}}$), $\mu \to \mu_{\max}$ (phonon-limited). At high doping ($N_I \gg N_{\text{ref}}$), $\mu \to \mu_{\min}$ (ionized impurity-limited).

Temperature dependence is modeled as a power law:

$$\mu(T) = \mu(300\,\text{K}) \cdot \left(\frac{T}{300}\right)^\beta$$

with $\beta = -2.4$ for electrons and $\beta = -2.2$ for holes in Si (Sze empirical values). The negative exponent reflects the increase in phonon scattering at higher temperatures.

### Einstein relation

The diffusion coefficient $D$ and mobility $\mu$ are related by the **Einstein relation** (also called the Einstein-Smoluchowski relation):

$$D = \frac{\mu \, k_B T}{e}$$

This is a consequence of the fluctuation-dissipation theorem and holds in the non-degenerate regime. At 300 K, the thermal voltage $k_B T / e \approx 25.9$ mV, so:

$$D \approx \mu \times 0.0259 \;\text{V}$$

For Si electrons with $\mu_e = 1400$ cm$^2$/V-s, this gives $D_e \approx 36$ cm$^2$/s.

### Diffusion length

The minority-carrier **diffusion length** $L$ is the characteristic distance a carrier diffuses before recombining:

$$L = \sqrt{D \tau}$$

where $\tau$ is the minority-carrier lifetime. This length scale is critical for:
- **Solar cells**: $L$ must exceed the absorption depth for efficient collection.
- **Bipolar transistors**: $L$ in the base determines the transport factor.
- **pn junctions**: $L$ sets the spatial extent of minority carrier injection.

Typical values: for high-quality Si with $\tau \sim 1$ ms and $D \sim 36$ cm$^2$/s, $L \sim 0.6$ mm.

### Thermal velocity

The thermal velocity of carriers is:

$$v_{th} = \sqrt{\frac{3 k_B T}{m^*}}$$

This is the root-mean-square speed from the Maxwell-Boltzmann distribution (the factor of 3 comes from three degrees of freedom). For Si electrons ($m_e^* = 0.26\,m_0$ for conductivity mass) at 300 K, $v_{th} \approx 2.3 \times 10^7$ cm/s.

The thermal velocity enters expressions for thermionic emission current, recombination rates ($R = \sigma_n v_{th} n N_t$ for Shockley-Read-Hall), and mean free path estimation ($\ell = v_{th} \tau$).

### Debye screening length

In a semiconductor, free carriers screen electric fields over a characteristic distance --- the **Debye length**:

$$L_D = \sqrt{\frac{\varepsilon_0 \varepsilon_r \, k_B T}{e^2 \, n}}$$

where $n$ is the free carrier concentration. For Si doped at $10^{16}$ cm$^{-3}$ and $T = 300$ K, $L_D \approx 40$ nm.

The Debye length sets the scale for:
- Band bending at surfaces and interfaces.
- The spatial extent of charge redistribution in response to a perturbation.
- Validity of the depletion approximation: the depletion edge is not truly abrupt but transitions over a distance $\sim L_D$.

---

## Wiedemann-Franz Law

### Theory

In metals, the same electrons that carry charge also carry heat. The **Wiedemann-Franz law** states that the ratio of electronic thermal conductivity $\kappa_e$ to electrical conductivity $\sigma$ is proportional to temperature:

$$\frac{\kappa_e}{\sigma} = L_0 \, T$$

where $L_0$ is the **Lorenz number**. The Sommerfeld (free-electron) value is:

$$L_0 = \frac{\pi^2}{3} \left(\frac{k_B}{e}\right)^2 = 2.44 \times 10^{-8} \;\text{W}\cdot\Omega/\text{K}^2$$

Equivalently, using $\sigma = 1/\rho$:

$$\kappa_e = \frac{L_0 \, T}{\rho}$$

### Validity

The Wiedemann-Franz law holds well in two regimes:
1. **High temperature** ($T \gg \Theta_D$): all phonon modes are excited, and electron-phonon scattering is approximately elastic (large-angle scattering dominates).
2. **Very low temperature** ($T \ll \Theta_D$): only impurity and boundary scattering remain, both of which are elastic.

At **intermediate temperatures** ($T \sim \Theta_D / 5$), inelastic small-angle electron-phonon scattering degrades heat transport more than charge transport, causing $\kappa_e/(\sigma T)$ to fall below $L_0$. This is the regime where the Wiedemann-Franz law is least reliable.

### When to use

- Estimating the electronic contribution to thermal conductivity when only electrical resistivity data are available.
- Separating electronic ($\kappa_e$) and lattice ($\kappa_L$) contributions to total thermal conductivity: $\kappa_{total} = \kappa_e + \kappa_L$, where $\kappa_e = L_0 T / \rho$.
- Quick estimates for metal thin films where direct thermal measurements are difficult.

### Reference value

For Cu at 300 K: $\rho = 1.72 \times 10^{-6}$ Ohm-cm, giving $\kappa_e = L_0 \times 300 / (1.72 \times 10^{-6}) \approx 4.3$ W/(cm-K), consistent with the measured total thermal conductivity of 4.0 W/(cm-K) (the small difference reflects a minor lattice contribution and the $\sim$5% accuracy of the Wiedemann-Franz estimate at room temperature).

---

## Common Pitfalls

1. **Unit mismatches**: The calculator uses CGS-practical units (Ohm-cm, cm$^{-3}$, cm$^2$/V-s). When comparing with papers that use SI (Ohm-m, m$^{-3}$, m$^2$/V-s), note that $1\;\text{Ohm-cm} = 10^{-2}\;\text{Ohm-m}$ and $1\;\text{cm}^{-3} = 10^6\;\text{m}^{-3}$.

2. **Hall coefficient units**: $R_H$ is in cm$^3$/C. Some references report in m$^3$/C (factor of $10^{-6}$) or use the Hall constant $R_H / t$ with units of Ohm/T.

3. **Hall scattering factor**: The true carrier concentration differs from the Hall concentration by a factor $r_H = \langle \tau^2 \rangle / \langle \tau \rangle^2$, which depends on the scattering mechanism. For acoustic phonon scattering in a parabolic band, $r_H = 3\pi/8 \approx 1.18$. The single-carrier model implemented here assumes $r_H = 1$.

4. **Two-carrier sign reversal**: The two-carrier Hall coefficient can have the opposite sign from what the majority carrier would predict, especially when the minority carrier has much higher mobility (e.g., in InSb or Bi).

5. **Degenerate semiconductors**: The Boltzmann approximation for $E_F$ breaks down when the Fermi level enters the band (heavy doping, $n > N_c$). Use the Joyce-Dixon correction or the full Fermi-Dirac integral in that regime.

6. **Temperature-dependent bandgap**: The material presets use 300 K values of $E_g$. For calculations at significantly different temperatures, the Varshni relation should be applied:
   $$E_g(T) = E_g(0) - \frac{\alpha T^2}{T + \beta}$$

---

## References

- S. M. Sze and K. K. Ng, *Physics of Semiconductor Devices*, 3rd ed., Wiley, 2007.
- N. W. Ashcroft and N. D. Mermin, *Solid State Physics*, Holt, Rinehart and Winston, 1976.
- C. Kittel, *Introduction to Solid State Physics*, 8th ed., Wiley, 2005.
- J. M. Ziman, *Principles of the Theory of Solids*, 2nd ed., Cambridge University Press, 1972.
- D. M. Caughey and R. E. Thomas, "Carrier mobilities in silicon empirically related to doping and field," *Proc. IEEE* **55**, 2192--2193 (1967). DOI: [10.1109/PROC.1967.6123](https://doi.org/10.1109/PROC.1967.6123)
- W. B. Joyce and R. W. Dixon, "Analytic approximations for the Fermi energy of an ideal Fermi gas," *Appl. Phys. Lett.* **31**, 354--356 (1977). DOI: [10.1063/1.89697](https://doi.org/10.1063/1.89697)
- P. R. Bevington and D. K. Robinson, *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed., McGraw-Hill, 2003.
