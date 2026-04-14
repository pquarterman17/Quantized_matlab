# X-Ray Diffraction

This document covers the crystallographic and diffraction theory behind the `+calc/+crystal/` and `+utilities/` modules. It is written for researchers who need to understand *what* the toolbox computes and *why*, with enough derivation to connect textbook theory to the implementation.

All formulas use standard crystallographic conventions: wavelength $\lambda$ in angstroms, angles in degrees (converted internally to radians), lattice parameters $(a, b, c, \alpha, \beta, \gamma)$ following the International Tables for Crystallography definitions.

---

## Bragg's Law and d-Spacing

### Theory

When a monochromatic X-ray beam of wavelength $\lambda$ impinges on a set of crystallographic planes separated by distance $d$, constructive interference occurs when the path difference equals an integer number of wavelengths:

$$n\lambda = 2d\sin\theta$$

where $\theta$ is the angle between the incident beam and the diffracting planes (not the sample surface), and $n$ is the diffraction order. In practice, higher-order reflections are treated as first-order reflections from planes with spacing $d/n$, so the working form is:

$$\lambda = 2d_{hkl}\sin\theta$$

This gives the two conversions used throughout the toolbox:

$$d = \frac{\lambda}{2\sin\theta}, \qquad 2\theta = 2\arcsin\!\left(\frac{\lambda}{2d}\right)$$

A Bragg reflection is physically observable only when $\lambda/(2d) \leq 1$; otherwise no real scattering angle exists.

**Default wavelength:** Cu K$\alpha_1$ = 1.5406 A, the most common laboratory X-ray source. Other common anode lines:

| Anode | Wavelength (A) |
|-------|---------------|
| Cu K$\alpha_1$ | 1.5406 |
| Co K$\alpha_1$ | 1.7902 |
| Mo K$\alpha_1$ | 0.7107 |
| Cr K$\alpha_1$ | 2.2910 |
| Fe K$\alpha_1$ | 1.9373 |

### d-Spacing Formulas by Crystal System

The interplanar spacing $d_{hkl}$ depends on the lattice parameters and the Miller indices $(hkl)$. The toolbox uses the general triclinic formula internally but infers the crystal system from the supplied parameters for display purposes.

**Cubic** ($a = b = c$, $\alpha = \beta = \gamma = 90°$):

$$\frac{1}{d_{hkl}^2} = \frac{h^2 + k^2 + l^2}{a^2}$$

**Tetragonal** ($a = b \neq c$, $\alpha = \beta = \gamma = 90°$):

$$\frac{1}{d_{hkl}^2} = \frac{h^2 + k^2}{a^2} + \frac{l^2}{c^2}$$

**Orthorhombic** ($a \neq b \neq c$, $\alpha = \beta = \gamma = 90°$):

$$\frac{1}{d_{hkl}^2} = \frac{h^2}{a^2} + \frac{k^2}{b^2} + \frac{l^2}{c^2}$$

**Hexagonal** ($a = b \neq c$, $\alpha = \beta = 90°$, $\gamma = 120°$):

$$\frac{1}{d_{hkl}^2} = \frac{4}{3}\,\frac{h^2 + hk + k^2}{a^2} + \frac{l^2}{c^2}$$

**Monoclinic** ($a \neq b \neq c$, $\alpha = \gamma = 90°$, $\beta \neq 90°$):

$$\frac{1}{d_{hkl}^2} = \frac{1}{\sin^2\!\beta}\!\left(\frac{h^2}{a^2} + \frac{k^2\sin^2\!\beta}{b^2} + \frac{l^2}{c^2} - \frac{2hl\cos\beta}{ac}\right)$$

**Triclinic** (general case, no symmetry constraints):

$$\frac{1}{d_{hkl}^2} = \frac{1}{V^2}\bigl(h^2 b^2 c^2 \sin^2\!\alpha + k^2 a^2 c^2 \sin^2\!\beta + l^2 a^2 b^2 \sin^2\!\gamma + 2hk\,abc^2(\cos\alpha\cos\beta - \cos\gamma) + 2kl\,a^2bc(\cos\beta\cos\gamma - \cos\alpha) + 2hl\,ab^2c(\cos\alpha\cos\gamma - \cos\beta)\bigr)$$

where $V$ is the unit cell volume (see next section). This is the formula implemented in `dSpacing.m`; it reduces to the simpler forms above for higher-symmetry systems.

### When to use

- **`dSpacing`**: You know the crystal structure and want the $d$-spacing for a specific $(hkl)$ reflection.
- **`dFromTwoTheta`**: You measured a peak at some $2\theta$ and need the corresponding $d$-spacing.
- **`twoThetaFromD`**: You know $d$ (e.g., from a database) and need to predict where the peak appears on your diffractometer.

---

## Unit Cell Volume

### Theory

The volume of a general triclinic unit cell with parameters $(a, b, c, \alpha, \beta, \gamma)$ is:

$$V = abc\sqrt{1 - \cos^2\!\alpha - \cos^2\!\beta - \cos^2\!\gamma + 2\cos\alpha\cos\beta\cos\gamma}$$

This simplifies for higher-symmetry systems:

| System | Volume |
|--------|--------|
| Cubic | $V = a^3$ |
| Tetragonal | $V = a^2 c$ |
| Orthorhombic | $V = abc$ |
| Hexagonal | $V = \frac{\sqrt{3}}{2}\,a^2 c$ |
| Monoclinic | $V = abc\sin\beta$ |
| Triclinic | General formula above |

### Derived quantities

**Atomic number density** (atoms/cm$^3$):

$$n = \frac{Z}{V}$$

where $Z$ is the number of atoms (or formula units) per unit cell and $V$ is converted from A$^3$ to cm$^3$ ($1\;\text{A}^3 = 10^{-24}\;\text{cm}^3$). For example, BCC iron has $Z = 2$ and $a = 2.8665$ A, giving $n \approx 8.49 \times 10^{22}$ atoms/cm$^3$.

**Mass density** (g/cm$^3$):

$$\rho = \frac{Z \cdot M}{N_A \cdot V}$$

where $M$ is the molar mass of the formula unit (g/mol) and $N_A = 6.022 \times 10^{23}$ mol$^{-1}$ is Avogadro's number. This is useful for verifying lattice parameters against known bulk densities, or for computing X-ray absorption and scattering length densities.

### When to use

- Checking consistency between refined lattice parameters and known density.
- Computing scattering length density for reflectometry (requires $\rho$ and composition).
- Estimating the number of formula units per cell when solving an unknown structure.

---

## Peak Profile Functions

### Theory

Bragg reflections in a powder diffractogram are not delta functions. They are broadened by both instrumental effects (beam divergence, slit width, monochromator, detector) and sample microstructure (finite crystallite size, microstrain, stacking faults). The observed peak shape is the convolution of these contributions, which is typically modeled by analytical line profiles.

#### Gaussian

$$G(x) = \exp\!\left(-4\ln 2\left(\frac{x - x_0}{\mathrm{FWHM}}\right)^{\!2}\right)$$

The Gaussian shape arises from random, independent broadening sources (central limit theorem). Instrument profiles of modern diffractometers are often approximately Gaussian.

#### Lorentzian (Cauchy)

$$L(x) = \frac{1}{1 + 4\!\left(\frac{x - x_0}{\mathrm{FWHM}}\right)^{\!2}}$$

The Lorentzian has heavier tails than the Gaussian and describes size broadening in the kinematical diffraction limit (shape transform of a finite crystal).

Both profiles are normalized here so that $G(x_0) = L(x_0) = 1$ and $G(x_0 \pm \mathrm{FWHM}/2) = L(x_0 \pm \mathrm{FWHM}/2) = 1/2$.

#### Pseudo-Voigt

The true Voigt profile is the convolution of a Gaussian and a Lorentzian, but its evaluation requires the complex error function (Faddeeva function). The **pseudo-Voigt** approximation replaces the convolution with a linear combination:

$$\mathrm{pV}(x) = H\bigl[\eta\, L(x) + (1 - \eta)\, G(x)\bigr] + \mathrm{bg}$$

where $H$ is the peak amplitude above background, and $\eta \in [0, 1]$ is the **Lorentzian mixing fraction**: $\eta = 0$ is pure Gaussian, $\eta = 1$ is pure Lorentzian. The pseudo-Voigt is computationally inexpensive and is the standard profile function in most Rietveld refinement codes.

The analytical integrated area of the pseudo-Voigt is:

$$A = H \cdot \mathrm{FWHM} \left(\eta\,\frac{\pi}{2} + (1 - \eta)\,\frac{\sqrt{\pi}}{2\sqrt{\ln 2}}\right)$$

In practice, $\eta$ typically falls between 0.3 and 0.8 for laboratory XRD data, increasing with $2\theta$ as size broadening (Lorentzian) becomes more significant relative to strain and instrumental broadening (Gaussian).

**Thompson-Cox-Hastings (TCH) parameterization.** Rather than fitting $\eta$ directly, advanced codes express the Gaussian and Lorentzian FWHM components separately as functions of $\theta$, then compute $\eta$ from their ratio. This is physically motivated but beyond the scope of the current toolbox implementation.

#### Split Pearson VII

The **Pearson VII** function generalizes the Lorentzian with a shape exponent $m$:

$$P_{\mathrm{VII}}(x) = H\left(1 + (2^{1/m} - 1)\left(\frac{x - c}{w}\right)^{\!2}\right)^{-m}$$

where $w$ is the half-width at half-maximum and $m$ controls the tail shape:
- $m = 1$: Lorentzian
- $m \to \infty$: Gaussian (the $(1 + u^2/m)^{-m}$ form converges to $e^{-u^2}$)
- $m \approx 2$--$3$: intermediate shapes common in XRD data

The **split Pearson VII** uses independent parameters on each side of the peak center:

$$y(x) = \begin{cases}
H\left(1 + (2^{1/m_L} - 1)\left(\frac{x - c}{w_L}\right)^{\!2}\right)^{-m_L} + \mathrm{bg} & x < c \\[6pt]
H\left(1 + (2^{1/m_R} - 1)\left(\frac{x - c}{w_R}\right)^{\!2}\right)^{-m_R} + \mathrm{bg} & x \geq c
\end{cases}$$

The total FWHM is $w_L + w_R$. The four shape parameters $(w_L, w_R, m_L, m_R)$ capture both asymmetric broadening and varying tail behavior, making this profile well-suited for:

- Strain-gradient broadening (one side broader than the other)
- Axial divergence aberrations at low $2\theta$ (sharp rise, extended low-angle tail)
- Defect-induced asymmetry in thin film peaks

The split Pearson VII has no simple closed-form integral for general $m$; use numerical quadrature (e.g., trapezoidal rule) for integrated intensity.

### When to use

- **Pseudo-Voigt**: General-purpose peak fitting for well-behaved, approximately symmetric Bragg peaks. Use when you need a fast, reliable profile with a single broadening parameter.
- **Split Pearson VII**: Asymmetric peaks, high-resolution diffractometer data, or when the pseudo-Voigt residuals show systematic shape mismatch. The extra parameters require more data points across the peak to constrain the fit.

### References for peak profiles

- Hall, M.M. et al., "The approximation of symmetric X-ray peaks by Pearson type-VII distributions," *J. Appl. Cryst.* **10** (1977) 66--68.
- Brown, A. & Edmonds, J.W., "The fitting of powder diffraction profiles to an analytical expression and the influence of line broadening factors," *Adv. X-Ray Anal.* **23** (1980) 361--374.
- Thompson, P., Cox, D.E., & Hastings, J.B., "Rietveld refinement of Debye-Scherrer synchrotron X-ray data from Al$_2$O$_3$," *J. Appl. Cryst.* **20** (1987) 79--83.

---

## Peak-Shape Width Parameter Conventions

The mathematical forms above use FWHM as the natural width coordinate, which is useful for comparing peaks across models. The fitting engine (`+fitting/models.m` and `+fitting/autoGuess.m`) uses a different set of width parameters — one per model — that are more convenient for the optimizer. This section documents the exact correspondence so that fit results can be interpreted correctly.

### Gaussian: $\sigma$ (standard deviation)

The implemented form is:

$$G(x;\, A, \mu, \sigma) = A \exp\!\left(-\frac{(x - \mu)^2}{2\sigma^2}\right)$$

The parameter $\sigma$ is the standard deviation of the normal distribution. The FWHM is:

$$\mathrm{FWHM}_G = 2\sqrt{2\ln 2}\;\sigma \approx 2.3548\,\sigma$$

Rearranging: $\sigma = \mathrm{FWHM}_G / 2.3548$.

The Gaussian shape is appropriate when the peak broadening arises from many independent, additive sources (central limit theorem). In XRD practice, instrumental broadening from a well-aligned modern diffractometer is approximately Gaussian, as is strain broadening arising from a distribution of lattice strains.

### Lorentzian: $\gamma$ (half-width at half-maximum)

The implemented form is:

$$L(x;\, A, x_0, \gamma) = \frac{A}{1 + \left(\dfrac{x - x_0}{\gamma}\right)^{\!2}}$$

The parameter $\gamma$ is the HWHM (half-width at half-maximum). Verify: $L(x_0 \pm \gamma) = A/2$. The FWHM is:

$$\mathrm{FWHM}_L = 2\gamma$$

Rearranging: $\gamma = \mathrm{FWHM}_L / 2$.

The Lorentzian is the natural line shape for size broadening in the kinematical limit. A crystallite of finite size $D$ acts as a slit: the diffracted intensity is proportional to the squared modulus of the shape Fourier transform, which for a parallelepiped is a sinc$^2$ function well approximated by a Lorentzian for the central portion of the peak. It also describes homogeneous (lifetime) broadening in spectroscopy. The heavier tails of the Lorentzian (falling as $1/\Delta x^2$ vs. $\exp(-\Delta x^2)$ for the Gaussian) are the key distinguishing feature.

### Pseudo-Voigt: $w$ (shared half-width)

The implemented form is:

$$\mathrm{pV}(x;\, A, x_0, w, \eta) = \eta\,\frac{A}{1 + \left(\dfrac{x - x_0}{w}\right)^{\!2}} + (1 - \eta)\,A\exp\!\left(-\frac{(x - x_0)^2}{2w^2}\right)$$

Both the Lorentzian and Gaussian sub-expressions share the single width parameter $w$, which equals the HWHM of the Lorentzian component. The Lorentzian sub-expression has FWHM $= 2w$ exactly. The Gaussian sub-expression has FWHM $= 2\sqrt{2\ln 2}\,w \approx 2.355\,w$. For the composite,

$$\mathrm{FWHM}_\mathrm{pV}(\eta) = 2w\left[\eta + (1 - \eta)\sqrt{2\ln 2}\right]$$

which equals $2w$ when $\eta = 1$ (pure Lorentzian) and $2\sqrt{2\ln 2}\,w$ when $\eta = 0$ (pure Gaussian). Because $\sqrt{2\ln 2} \approx 1.177$, the difference between the two limits is at most 18%. The initial seed $w = \mathrm{FWHM}_\mathrm{est}/2$ is therefore a reasonable approximation across the full range of $\eta$.

Note: the Thompson-Cox-Hastings (TCH) pseudo-Voigt parameterization used in Rietveld codes (Thompson et al. 1987) decomposes $w$ into separate Gaussian and Lorentzian FWHM components $(\Gamma_G, \Gamma_L)$ that are functions of $\theta$. The present implementation uses a single shared $w$ (simpler, suitable for single-peak fitting), and $\eta$ is a free parameter rather than computed from $\Gamma_G / \Gamma_L$.

### Summary table

| Model | Width parameter | Physical meaning | FWHM relation | Initial seed |
|-------|----------------|-----------------|---------------|-------------|
| Gaussian | $\sigma$ | Standard deviation | $\mathrm{FWHM} = 2\sqrt{2\ln 2}\,\sigma \approx 2.355\,\sigma$ | $\sigma = \mathrm{FWHM}/2.355$ |
| Lorentzian | $\gamma$ | HWHM | $\mathrm{FWHM} = 2\gamma$ | $\gamma = \mathrm{FWHM}/2$ |
| Pseudo-Voigt | $w$ | Lorentzian HWHM | $\mathrm{FWHM} \approx 2w$ (exact for $\eta=1$) | $w = \mathrm{FWHM}/2$ |

### Choosing a peak model

The appropriate shape model depends on the dominant broadening mechanism:

- **Lorentzian** ($\gamma$): pure crystallite-size broadening (Scherrer regime). XRD peaks from very small nanocrystals (< 20 nm) or single-domain grains are predominantly Lorentzian. Also appropriate for homogeneous lifetime broadening in spectroscopy.

- **Gaussian** ($\sigma$): pure strain broadening, or dominant instrumental broadening from a modern diffractometer. The Gaussian arises from a random distribution of lattice strains (central limit theorem) or from the convolution of many independent instrumental contributions.

- **Pseudo-Voigt** ($w$, $\eta$): combined size and strain broadening. This is the most general and most widely used choice for laboratory XRD. The mixing fraction $\eta$ adjusts automatically: $\eta \to 1$ selects Lorentzian character (size-dominated), $\eta \to 0$ selects Gaussian (strain/instrumental-dominated). For most powder diffraction data, $\eta$ falls between 0.3 and 0.8.

As a practical guide: start with pseudo-Voigt. If $\eta$ converges to 0 or 1 and the residuals are acceptable, switch to the pure Gaussian or Lorentzian for a more parsimonious model. If the peak is asymmetric, consider the split Pearson VII (see the "Peak Profile Functions" section above).

---

## Williamson-Hall Analysis

### Theory

The measured breadth $\beta$ (FWHM in radians) of a Bragg peak has contributions from both finite crystallite size and lattice microstrain. The **Scherrer equation** describes pure size broadening:

$$\beta_{\mathrm{size}}\cos\theta = \frac{K\lambda}{D}$$

where $D$ is the volume-averaged crystallite dimension along the diffraction vector and $K$ is the **Scherrer constant**. The value of $K$ depends on the assumed crystallite shape and the definition of "size":

| $K$ | Meaning |
|-----|---------|
| 0.89 | Spherical crystallites, FWHM definition |
| 0.94 | Spherical crystallites, integral breadth definition |
| 1.0 | Cube-shaped crystallites |
| 0.9 | Commonly used default (approximate sphere) |

The Scherrer equation alone is only valid when microstrain is negligible. When both size and strain contribute, the **Williamson-Hall** method separates them by exploiting their different $\theta$-dependence.

**Strain broadening** scales as:

$$\beta_{\mathrm{strain}}\cos\theta = 4\varepsilon\sin\theta$$

where $\varepsilon$ is the root-mean-square microstrain (dimensionless). Assuming the broadening components add linearly (valid for Lorentzian-dominated profiles), the total broadening is:

$$\beta\cos\theta = \frac{K\lambda}{D} + 4\varepsilon\sin\theta$$

This is a linear equation in the variable $4\sin\theta$:

$$y = mx + b, \qquad y = \beta\cos\theta, \quad x = 4\sin\theta, \quad m = \varepsilon, \quad b = \frac{K\lambda}{D}$$

A least-squares fit to data from multiple $(hkl)$ reflections gives:

- **Slope** $= \varepsilon$ (microstrain)
- **Intercept** $= K\lambda / D$ $\;\Rightarrow\;$ $D = K\lambda / \text{intercept}$

#### Instrumental broadening correction

The measured FWHM includes instrumental broadening $\beta_{\mathrm{inst}}$. For Gaussian profiles, the correction is quadrature subtraction:

$$\beta_{\mathrm{true}}^2 = \beta_{\mathrm{meas}}^2 - \beta_{\mathrm{inst}}^2$$

For Lorentzian profiles, the subtraction is linear: $\beta_{\mathrm{true}} = \beta_{\mathrm{meas}} - \beta_{\mathrm{inst}}$. The toolbox uses quadrature subtraction, which is appropriate when the instrument function is approximately Gaussian (as in most modern diffractometers). The instrumental broadening can be measured from a standard such as LaB$_6$ (NIST SRM 660).

#### Assumptions and limitations

The uniform-strain Williamson-Hall model (also called the UDM, uniform deformation model) assumes:

1. **Isotropic broadening**: all $(hkl)$ reflections broaden identically for a given $\theta$. This fails for elastically anisotropic materials, where different $(hkl)$ planes have different stiffnesses. The modified Williamson-Hall method (Ungar & Borbely, 1996) accounts for this using the contrast factor $C_{hkl}$.
2. **Linear addition of size and strain broadening**: strictly correct only for Lorentzian profiles. When the profiles have significant Gaussian character, the Williamson-Hall plot can show scatter that reduces the $R^2$ value.
3. **Single-phase, single-size distribution**: if the sample contains multiple phases or a bimodal size distribution, the analysis may give misleading average values.

A poor $R^2$ on the Williamson-Hall plot does not necessarily mean bad data; it may indicate elastic anisotropy, and the modified Williamson-Hall or Warren-Averbach methods should be considered.

### When to use

- You have at least 3--4 well-resolved Bragg peaks from a single phase.
- You want a quick estimate of crystallite size and strain without full Rietveld refinement.
- The material is reasonably isotropic (metals, simple oxides). For highly anisotropic materials (layered compounds, hexagonal systems), interpret with caution.

---

## Epitaxial Strain

### Lattice mismatch

When a crystalline thin film is deposited on a single-crystal substrate, the film's in-plane lattice parameter is constrained to match the substrate at the interface. The **lattice mismatch** quantifies the natural incompatibility:

$$f = \frac{a_f - a_s}{a_s}$$

where $a_f$ is the relaxed (bulk) in-plane lattice parameter of the film and $a_s$ is the substrate lattice parameter. The sign convention is:

- $f > 0$: the film's natural lattice is larger than the substrate $\;\Rightarrow\;$ **biaxial tension** (in-plane compression of the film by the substrate)
- $f < 0$: the film's natural lattice is smaller $\;\Rightarrow\;$ **biaxial compression**

Note: some references define $f = (a_s - a_f)/a_f$. The toolbox uses the convention above, with the substrate as the reference.

For a coherently strained (pseudomorphic) film, the in-plane strain is:

$$\varepsilon_\parallel = \frac{a_s - a_f}{a_f} = -\frac{f}{1 + f} \approx -f \quad \text{(for small } f\text{)}$$

### Poisson biaxial strain

A coherent epitaxial film is biaxially strained in-plane ($\varepsilon_{xx} = \varepsilon_{yy} = \varepsilon_\parallel$) with a free surface in the out-of-plane direction ($\sigma_{zz} = 0$). From isotropic linear elasticity with biaxial boundary conditions:

$$\varepsilon_\perp = -\frac{2\nu}{1 - \nu}\,\varepsilon_\parallel$$

where $\nu$ is the Poisson ratio of the film. This means:

- **Tensile** in-plane strain ($\varepsilon_\parallel > 0$) causes **compressive** out-of-plane strain ($\varepsilon_\perp < 0$): the $c$-axis shrinks.
- **Compressive** in-plane strain ($\varepsilon_\parallel < 0$) causes **elongation** of the $c$-axis ($\varepsilon_\perp > 0$).

This relationship is directly measurable by XRD: a symmetric $\theta$-$2\theta$ scan measures the out-of-plane lattice parameter $c$, which is related to the relaxed value $c_0$ by:

$$c = c_0(1 + \varepsilon_\perp)$$

For a cubic material where $a_0 = c_0$, measuring $c$ and knowing $\nu$ allows you to back-calculate the in-plane strain and determine whether the film is coherent, partially relaxed, or fully relaxed.

**Typical Poisson ratios** for common thin-film materials:

| Material | $\nu$ |
|----------|-------|
| Si | 0.28 |
| GaAs | 0.31 |
| SrTiO$_3$ | 0.23 |
| BaTiO$_3$ | 0.30 |
| LSMO | 0.33 |
| Metals (typical) | 0.29--0.35 |

### Tetragonal distortion

For a film that is nominally cubic in bulk, epitaxial strain induces a **tetragonal distortion** characterized by the $c/a$ ratio:

$$\frac{c}{a} = \frac{c_\text{meas}}{a_\text{relaxed}}$$

and the distortion percentage:

$$\delta = \frac{c_\text{meas} - c_\text{relaxed}}{c_\text{relaxed}} \times 100\%$$

For materials that are already tetragonal in bulk (e.g., BaTiO$_3$), the reference $c_\text{relaxed}$ differs from $a_\text{relaxed}$, and both should be specified.

### Matthews-Blakeslee critical thickness

Below a critical thickness $h_c$, it is energetically favorable for the film to remain coherently strained (pseudomorphic). Above $h_c$, misfit dislocations nucleate to relieve the strain. The **Matthews-Blakeslee** model balances the energy of the strain field against the energy of the dislocation:

$$h_c = \frac{b}{2\pi f}\,\frac{(1 - \nu\cos^2\!\alpha)}{(1 + \nu)\cos\lambda}\left(\ln\frac{h_c}{b} + 1\right)$$

where:
- $b = a/\sqrt{2}$ is the Burgers vector magnitude for the $\frac{1}{2}\langle 110\rangle$ slip system in FCC/zinc-blende structures
- $\alpha = 60°$ is the angle between the dislocation line and its Burgers vector (mixed character)
- $\lambda = 60°$ is the angle between the Burgers vector and the direction in the interface plane perpendicular to the dislocation line
- $f = |a_f - a_s|/a_s$ is the absolute lattice mismatch
- $\nu$ is the Poisson ratio of the film

This is a transcendental equation in $h_c$ and is solved iteratively (fixed-point iteration starting from $h_c = 1000$ A). The model predicts, for example:

| System | $f$ (%) | $h_c$ (nm) |
|--------|---------|-------------|
| In$_{0.2}$Ga$_{0.8}$As / GaAs | 1.4 | ~8 |
| LSMO / STO | 0.7 | ~20 |
| STO / LSAT | 0.9 | ~12 |

The Matthews-Blakeslee model tends to underestimate the experimentally observed critical thickness because it assumes pre-existing threading dislocations. In practice, kinetic barriers to dislocation nucleation allow metastable coherent films somewhat beyond $h_c$.

### When to use

- **`latticeMismatch`**: Planning epitaxial growth; quickly assessing film-substrate compatibility.
- **`strainFromPoisson`**: Interpreting out-of-plane XRD peak shifts in terms of in-plane strain.
- **`tetragonalDistortion`**: Quantifying the structural distortion from a symmetric $\theta$-$2\theta$ scan.
- **`criticalThickness`**: Estimating the maximum coherent film thickness for a given film-substrate pair.

---

## Phase Identification

### Theory

Qualitative phase identification matches observed Bragg peak positions against a database of known crystal structures. The algorithm in `matchPhases` works as follows:

1. **Convert observed $2\theta$ values to $d$-spacings** using Bragg's law.
2. **Enumerate reference reflections** for each database entry by computing all allowed $(hkl)$ reflections up to a maximum Miller index (default $|h|, |k|, |l| \leq 5$), applying systematic absence rules for the Bravais centering.
3. **Match** each observed $d$-spacing to the nearest reference $d$-spacing within a tolerance window (default $\Delta d = 0.03$ A).
4. **Score** each candidate phase by the fraction of observed peaks that are matched.
5. **Rank** candidates by descending score.

### Systematic absence rules

The Bravais lattice centering imposes selection rules on which $(hkl)$ reflections are allowed:

| Centering | Condition for allowed reflection |
|-----------|--------------------------------|
| P (primitive) | All $(hkl)$ allowed |
| F (face-centered) | $h, k, l$ all odd or all even |
| I (body-centered) | $h + k + l =$ even |
| A (A-centered) | $k + l =$ even |
| B (B-centered) | $h + l =$ even |
| C (C-centered) | $h + k =$ even |
| R (rhombohedral, obverse) | $h - k + l \equiv 0 \pmod{3}$ |

These are necessary but not sufficient conditions; space group symmetry can impose additional absences (glide planes, screw axes), which are not currently implemented in the toolbox.

### Phase database

The built-in database (`phaseDatabase`) contains approximately 50 entries covering common thin-film and substrate materials organized by category:

- **Substrates**: Si, sapphire, SrTiO$_3$, MgO, LaAlO$_3$, GaAs, Ge, GaN, TiO$_2$ rutile, 4H-SiC
- **Metals**: Al, Cu, Au, Ag, Pt, Pd, Ni, Fe (BCC and FCC), W, Cr, Ti, Co, Mo, Ta
- **Oxides**: ZnO, Fe$_2$O$_3$, Fe$_3$O$_4$, NiO, CoO, CuO, Cu$_2$O, TiO$_2$ (anatase), SiO$_2$ (quartz), SnO$_2$, In$_2$O$_3$, Cr$_2$O$_3$
- **Perovskites**: BaTiO$_3$, PbTiO$_3$, La$_{0.7}$Sr$_{0.3}$MnO$_3$, BiFeO$_3$, LaNiO$_3$, SrRuO$_3$
- **Semiconductors**: InAs, InP, CdTe, ZnSe, AlN
- **Standards and other**: LaB$_6$ (NIST SRM 660), CaF$_2$, NaCl, BN

Lattice parameters are room-temperature values sourced from ICSD entries where available. The database can be filtered by category to narrow the search space.

### Limitations

- The scoring is based solely on peak position matching, not intensity. A phase whose strongest reflections are absent in the data may still score well if minor reflections happen to coincide.
- The database does not include structure factors or preferred orientation effects.
- For definitive phase identification, compare against the full ICDD PDF (Powder Diffraction File) database and consider relative peak intensities.
- Mixed-phase samples may have overlapping peaks that confuse the matching.

### When to use

- Quick screening of powder or polycrystalline thin-film XRD data against common materials.
- Identifying substrate peaks and known secondary phases.
- As a starting point before detailed Rietveld refinement.

---

## Systematic Plane Spacings

The `planeSpacings` function enumerates all symmetry-allowed $(hkl)$ reflections for a given crystal structure, computes their $d$-spacings and $2\theta$ positions, and reports the multiplicity (number of symmetry-equivalent planes contributing to each powder ring).

This is useful for:

- Generating a theoretical stick pattern to overlay on experimental data
- Identifying which $(hkl)$ to expect for a given Bravais lattice type
- Computing reference peak positions for phase matching
- Teaching: visualizing how the centering rules eliminate reflections (e.g., the (100) reflection is forbidden in FCC but allowed in BCC)

The canonical representative for each group of equivalent reflections is chosen with positive Miller indices where possible, following the convention that $(hkl)$ with $h > 0$ (or $h = 0, k > 0$, etc.) is preferred.

---

## References

1. Cullity, B.D. & Stock, S.R., *Elements of X-Ray Diffraction*, 3rd ed., Prentice Hall, 2001.

2. Warren, B.E., *X-Ray Diffraction*, Dover, 1990 (reprint of 1969 edition).

3. Als-Nielsen, J. & McMorrow, D., *Elements of Modern X-ray Physics*, 2nd ed., Wiley, 2011.

4. Scherrer, P., "Bestimmung der Grosse und der inneren Struktur von Kolloidteilchen mittels Rontgenstrahlen," *Nachr. Ges. Wiss. Gottingen* **26** (1918) 98--100.

5. Williamson, G.K. & Hall, W.H., "X-ray line broadening from filed aluminium and wolfram," *Acta Metallurgica* **1** (1953) 22--31.

6. Matthews, J.W. & Blakeslee, A.E., "Defects in epitaxial multilayers: I. Misfit dislocations," *J. Crystal Growth* **27** (1974) 118--125.

7. Hall, M.M., Veeraraghavan, V.G., Rubin, H., & Winchell, P.G., "The approximation of symmetric X-ray peaks by Pearson type-VII distributions," *J. Appl. Cryst.* **10** (1977) 66--68.

8. Thompson, P., Cox, D.E., & Hastings, J.B., "Rietveld refinement of Debye-Scherrer synchrotron X-ray data from Al$_2$O$_3$," *J. Appl. Cryst.* **20** (1987) 79--83.

9. Ungar, T. & Borbely, A., "The effect of dislocation contrast on x-ray line broadening: A new approach to line profile analysis," *Appl. Phys. Lett.* **69** (1996) 3173--3175.

10. International Tables for Crystallography, Vol. A, *Space-Group Symmetry*, 6th ed., IUCr/Wiley, 2016.

11. Langford, J.I. & Wilson, A.J.C., "Scherrer after sixty years: A survey and some new results in the determination of crystallite size," *J. Appl. Cryst.* **11** (1978) 102--113.

12. Bevington, P.R. & Robinson, D.K., *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed., McGraw-Hill, 2003.
