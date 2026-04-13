# Reflectometry

Specular X-ray and neutron reflectometry measures the intensity of radiation reflected from a sample as a function of the momentum transfer $Q$ perpendicular to the surface. The technique is sensitive to the depth-dependent scattering length density (SLD) profile of thin films, multilayers, and interfaces, with sub-nanometer depth resolution. This document covers the physics implemented in the `+calc/+xrayNeutron/` and `+fitting/` packages.

---

## Scattering Vector and Geometry

### Theory

In a specular reflectometry experiment the incident beam strikes a flat surface at grazing angle $\theta$ (measured from the surface plane) and the detector captures the specularly reflected beam at the same angle. The **momentum transfer** is directed normal to the surface:

$$Q = \frac{4\pi \sin\theta}{\lambda}$$

where $\lambda$ is the radiation wavelength. This is the fundamental independent variable in reflectometry -- all reflectivity curves are plotted as $R(Q)$ to allow comparison between instruments operating at different wavelengths (lab X-rays, synchrotron, reactor neutrons, spallation neutrons).

### Connection to Bragg's law

Bragg's law for constructive interference from planes separated by spacing $d$ is

$$n\lambda = 2d\sin\theta$$

For first-order diffraction ($n = 1$) the relationship between $Q$ and $d$-spacing is

$$Q = \frac{2\pi}{d}$$

This means Kiessig fringes in a reflectivity curve with period $\Delta Q$ correspond to a film thickness

$$t = \frac{2\pi}{\Delta Q}$$

### Angle-Q conversion

Converting between angular and reciprocal-space representations requires specifying the wavelength:

$$2\theta = 2\arcsin\!\left(\frac{Q\lambda}{4\pi}\right)$$

$$Q = \frac{4\pi\sin\!\left(\theta\right)}{\lambda}$$

Values where $Q\lambda / (4\pi) > 1$ are geometrically inaccessible at that wavelength. The default wavelength in the toolbox is $\lambda = 1.5406$ A (Cu K$\alpha_1$).

### When to use

- **Q-space** is the natural representation for comparing data across instruments and wavelengths, and is required input for the Parratt recursion.
- **Angular space** ($2\theta$) is what the diffractometer or reflectometer hardware reports and is needed for alignment, slit corrections, and footprint calculations.

---

## Scattering Length Density

The scattering length density (SLD) quantifies how strongly a material scatters radiation per unit volume. X-rays and neutrons interact with matter through fundamentally different mechanisms, so a material has two distinct SLD values.

### X-ray SLD

X-rays scatter from the electron cloud. The X-ray SLD is

$$\rho_x = r_e \, \rho_e$$

where $r_e = 2.8179 \times 10^{-15}$ m $= 2.8179 \times 10^{-5}$ A is the classical electron radius (Thomson scattering length) and $\rho_e$ is the electron number density. For a compound with molecular weight $M$ (g/mol), mass density $\rho_m$ (g/cm$^3$), and total electron count per formula unit $Z_\text{tot} = \sum_i n_i Z_i$:

$$\rho_e = \frac{\rho_m \, N_A}{M} \sum_i n_i Z_i$$

$$\rho_x = r_e \cdot \frac{\rho_m \, N_A}{M} \sum_i n_i Z_i$$

Units: when $r_e$ is in angstroms and $\rho_e$ in electrons/A$^3$, the SLD is in A$^{-2}$.

**Key property:** X-ray SLD scales monotonically with atomic number $Z$. Heavy elements scatter X-rays more strongly. This means X-ray reflectometry has poor contrast between elements that are neighbors in the periodic table (e.g., Fe and Co).

### Neutron SLD

Neutrons scatter from the nucleus via the strong nuclear force. The neutron SLD is

$$\rho_n = \frac{\rho_m \, N_A}{M} \sum_i n_i b_i$$

where $b_i$ is the bound coherent neutron scattering length of element $i$ (tabulated in fm = $10^{-13}$ cm). The unit conversion to A$^{-2}$ proceeds as:

$$\text{SLD}\;[\text{cm}^{-2}] = \frac{\rho_m \, N_A}{M} \sum_i n_i b_i \times 10^{-13}$$

$$\text{SLD}\;[\text{A}^{-2}] = \text{SLD}\;[\text{cm}^{-2}] \times 10^{-16}$$

**Key properties:**

- Neutron scattering lengths vary **erratically** across the periodic table (they depend on nuclear structure, not electron count). This gives neutron reflectometry sensitivity to light elements (especially hydrogen) and the ability to distinguish neighboring elements.
- Some isotopes have **negative** scattering lengths (e.g., $^1$H: $b = -3.74$ fm, Ti: $b = -3.44$ fm), leading to negative SLD. This is exploited in contrast-matching and contrast-variation experiments.
- **Isotopic substitution** -- particularly H/D exchange ($b_\text{H} = -3.74$ fm vs. $b_\text{D} = +6.67$ fm) -- is one of the most powerful tools in neutron reflectometry, enabling selective highlighting of specific layers or components.

### Reference SLD values

Commonly used materials and their SLD values (from the toolbox preset table):

| Material | Formula | X-ray SLD ($10^{-6}$ A$^{-2}$) | Neutron SLD ($10^{-6}$ A$^{-2}$) | $\rho$ (g/cm$^3$) |
|----------|---------|:-------------------------------:|:---------------------------------:|:------------------:|
| Silicon | Si | 20.07 | 2.073 | 2.33 |
| Silicon oxide | SiO$_2$ | 18.88 | 3.470 | 2.20 |
| Gold | Au | 124.5 | 4.460 | 19.32 |
| Nickel | Ni | 64.0 | 9.408 | 8.91 |
| Iron | Fe | 59.4 | 8.024 | 7.87 |
| Titanium | Ti | 30.8 | $-1.950$ | 4.51 |
| Water (H$_2$O) | H$_2$O | 9.43 | $-0.560$ | 1.00 |
| Heavy water (D$_2$O) | D$_2$O | 9.43 | 6.335 | 1.11 |
| Air / Vacuum | -- | 0 | 0 | 0 |
| Sapphire | Al$_2$O$_3$ | 24.51 | 5.726 | 3.97 |

Note that Si and SiO$_2$ have very similar X-ray SLD (~20 vs. ~19) but clearly different neutron SLD (~2.1 vs. ~3.5). Conversely, Ni and Cu are easily distinguished by X-rays (64 vs. 64.3 -- actually very close) but have very different neutron SLD (9.4 vs. 6.5). The choice of probe depends on which contrast is needed.

### When to use

- Use **X-ray SLD** for lab-based reflectometry (Cu K$\alpha$ tube sources, synchrotron).
- Use **neutron SLD** for reactor or spallation neutron reflectometry.
- When modeling a reflectivity curve, the SLD profile is the physical quantity being fitted. Knowing the SLD values of your constituent materials is essential for constructing starting models and interpreting results.

---

## Parratt Recursion

### Theory

The Parratt recursion (Parratt, 1954) is the standard method for computing specular reflectivity from a stratified medium. It is exact within the optical (dynamical) framework -- it accounts for multiple reflections and refraction at every interface, unlike the Born approximation which is only valid far from total reflection.

#### Refractive index and wavevector

In the optical treatment, each layer $j$ has a complex refractive index

$$n_j = 1 - \delta_j + i\beta_j$$

where $\delta_j = \lambda^2 \rho_j / (2\pi)$ and $\beta_j$ encodes absorption. The perpendicular component of the wavevector inside layer $j$ is

$$k_{z,j} = \sqrt{\left(\frac{Q}{2}\right)^2 - 4\pi\,\text{SLD}_j}$$

where $\text{SLD}_j = \text{SLD}_{\text{real},j} + i\,\text{SLD}_{\text{imag},j}$ is the complex scattering length density. The quantity $k_{z,j}$ is generally complex, with the imaginary part describing absorption and evanescent decay below the critical angle.

#### Critical angle and total external reflection

Total external reflection occurs when $k_{z,j}$ becomes imaginary in the top layer, which happens when

$$Q < Q_c = 4\sqrt{\pi\,\text{SLD}_\text{substrate}}$$

Below $Q_c$ (or equivalently below the critical angle $\theta_c$), the reflectivity is unity and the wave is evanescent in the film. For silicon ($\text{SLD}_n = 2.073 \times 10^{-6}$ A$^{-2}$):

$$Q_c = 4\sqrt{\pi \times 2.073 \times 10^{-6}} \approx 0.0102\;\text{A}^{-1}$$

#### Fresnel coefficients

The Fresnel reflection coefficient at the interface between layers $j$ and $j+1$ is

$$r_{j,j+1} = \frac{k_{z,j} - k_{z,j+1}}{k_{z,j} + k_{z,j+1}}$$

For a single sharp interface (no films), the reflectivity is simply $R = |r_{0,1}|^2$. This is the **Fresnel reflectivity**, which falls as $R \propto Q^{-4}$ at large $Q$ -- the fundamental asymptotic law for any smooth interface.

#### Recursive formula

The Parratt recursion builds the total reflectance ratio starting from the substrate (bottom layer $M$) and working upward. At the substrate there is no reflected wave from below, so

$$X_M = 0$$

Then for each interface from $j = M$ down to $j = 2$:

$$X_{j-1} = \frac{r_{j-1,j} + X_j\,\phi_j}{1 + r_{j-1,j}\,X_j\,\phi_j}$$

where $\phi_j = e^{2ik_{z,j}\,d_j}$ is the phase factor accumulated by the wave traversing layer $j$ of thickness $d_j$. For the substrate and incident medium (semi-infinite layers), $\phi = 1$.

The measured reflectivity is

$$R(Q) = |X_0|^2$$

This recursion is algebraically equivalent to the transfer-matrix (Abeles) method but is numerically more stable because it works with reflection ratios rather than $2\times 2$ matrix products that can overflow for thick absorbing layers.

#### Nevot-Croce roughness correction

Real interfaces are never atomically sharp. The most widely used roughness model multiplies each Fresnel coefficient by a Gaussian damping factor (Nevot and Croce, 1980):

$$r_{j,j+1}^\text{rough} = r_{j,j+1} \exp\!\left(-2\,k_{z,j}\,k_{z,j+1}\,\sigma_{j+1}^2\right)$$

where $\sigma_{j+1}$ is the rms roughness of interface $j+1$ (in angstroms). This is derived from the Born approximation applied to an error-function density profile at the interface. The factor involves the product $k_{z,j} \cdot k_{z,j+1}$ (wavevectors on *both* sides of the interface), which correctly reduces the effect when either medium is nearly matched.

**Physical interpretation:** Roughness causes diffuse scattering that removes intensity from the specular beam. The Nevot-Croce correction accounts for this loss. It is valid when $\sigma \ll d$ (roughness much less than layer thickness) and when the roughness can be described by a single rms parameter.

**Limitations:** The Nevot-Croce model assumes Gaussian height distributions. For correlated roughness, graded interfaces, or non-Gaussian profiles, more sophisticated approaches (e.g., the distorted-wave Born approximation, DWBA) are needed.

#### Layer convention

The layer stack is specified as an $M \times 4$ matrix:

| Row | Meaning | Thickness | SLD real | SLD imag | Roughness |
|-----|---------|-----------|----------|----------|-----------|
| 1 | Incident medium (air/vacuum) | 0 (ignored) | 0 | 0 | 0 |
| 2 | Top film layer | $d_2$ (A) | $\rho_2$ (A$^{-2}$) | $\rho_2''$ (A$^{-2}$) | $\sigma_2$ (A) |
| ... | ... | ... | ... | ... | ... |
| $M-1$ | Bottom film layer | $d_{M-1}$ | $\rho_{M-1}$ | $\rho_{M-1}''$ | $\sigma_{M-1}$ |
| $M$ | Substrate (semi-infinite) | 0 (ignored) | $\rho_M$ | $\rho_M''$ | $\sigma_M$ |

The roughness on row $j$ applies to the interface *above* layer $j$ (between layer $j-1$ and layer $j$).

#### Scale and background

Real measurements include instrumental effects:

$$R_\text{meas}(Q) = S \cdot R_\text{calc}(Q) + B$$

where $S$ is an overall scale factor (ideally 1, but accounts for beam normalization and footprint) and $B$ is a constant background (incoherent scattering, detector dark counts).

### When to use

- **Parratt recursion** is the standard for fitting specular reflectivity from any planar stratified system: single films, multilayers, buried interfaces, polymer films at liquid interfaces.
- For films thicker than ~1 $\mu$m, the Kiessig fringes become too closely spaced to resolve, and reflectometry becomes impractical. The technique is most useful for total film thicknesses of ~10 A to ~5000 A.
- If the roughness is comparable to the layer thickness ($\sigma \gtrsim d/3$), the layer model breaks down and a free-form or microslice approach may be more appropriate.

---

## SLD Profile Construction

### Theory

The Parratt recursion treats the sample as discrete homogeneous slabs separated by sharp or rough interfaces. The corresponding real-space picture is the **SLD depth profile** $\rho(z)$, where $z$ is the depth measured from the sample surface.

#### Box model

In the simplest representation each layer is a rectangular box:

$$\rho_\text{box}(z) = \rho_j \quad \text{for } z_j \leq z < z_{j+1}$$

where $z_j = \sum_{k=2}^{j} d_k$ is the cumulative depth to the top of layer $j$ (with $z_1 = 0$ at the vacuum/film interface).

#### Error-function interfaces

Interfacial roughness smears the transition between adjacent layers. The Nevot-Croce model corresponds to an error-function grading:

$$\rho(z) = \rho_1 + \sum_{j=2}^{M} \frac{\Delta\rho_j}{2}\left[1 + \operatorname{erf}\!\left(\frac{z - z_{j-1}}{\sigma_j\sqrt{2}}\right)\right]$$

where $\Delta\rho_j = \rho_j - \rho_{j-1}$ is the SLD contrast at interface $j$, and $\sigma_j$ is the rms roughness. The error function

$$\operatorname{erf}(x) = \frac{2}{\sqrt{\pi}}\int_0^x e^{-t^2}\,dt$$

transitions smoothly from $-1$ to $+1$, so the SLD changes from $\rho_{j-1}$ to $\rho_j$ over a region of width $\sim 2\sigma_j$.

**Physical interpretation:** The error-function profile arises naturally if the interface height fluctuations follow a Gaussian distribution with standard deviation $\sigma$, which is the case for thermally roughened surfaces and many as-deposited thin films.

#### Uniqueness

An important caveat: reflectometry suffers from the **phase problem**. The measurement records $|r(Q)|^2$ but not the complex phase of the reflected amplitude. This means that multiple SLD profiles can produce identical reflectivity curves. Breaking this degeneracy requires:

- Prior knowledge of the layer structure (e.g., from deposition conditions)
- Contrast variation (measuring the same sample with different isotopic compositions in neutron reflectometry, or at different X-ray energies near an absorption edge)
- Complementary measurements (ellipsometry, XRR + NR together, TEM cross-sections)

### When to use

- Plot the SLD profile alongside every reflectivity fit to visually verify that the model is physically reasonable.
- Use the profile to check for unphysical features: negative SLD in materials that should not have it, roughness values exceeding layer thicknesses, voids, or densities far from bulk.
- When comparing models with different numbers of layers, the SLD profile is more informative than the reflectivity curve alone.

---

## Composition Conversions

### Atomic percent to weight percent

Given atomic fractions $x_i$ (at%) and atomic masses $M_i$ (g/mol):

$$\text{wt\%}_i = \frac{x_i \, M_i}{\sum_j x_j \, M_j} \times 100$$

### Weight percent to atomic percent

The inverse transformation:

$$\text{at\%}_i = \frac{w_i / M_i}{\sum_j w_j / M_j} \times 100$$

where $w_i$ is the weight fraction.

### Molecular weight

For a compound with formula $\text{A}_{n_1}\text{B}_{n_2}\ldots$:

$$M = \sum_i n_i M_i$$

where $n_i$ is the stoichiometric coefficient and $M_i$ the atomic mass of element $i$.

### When to use

- **Composition conversions** are needed when translating between how samples are prepared (often specified by weight, e.g., sputtering target compositions) and how SLD is calculated (which requires atomic fractions or stoichiometry).
- **Molecular weight** is an intermediate quantity required for both neutron and X-ray SLD calculations.

---

## Co-deposition Flux Ratios

### Theory

When growing a multi-component film by co-deposition (e.g., molecular beam epitaxy, co-sputtering, pulsed laser deposition from multiple targets), the relative flux of each source must be controlled to achieve the desired film stoichiometry.

For a target film with formula $\text{A}_{n_A}\text{B}_{n_B}\text{O}_{n_O}$ grown from sources containing cations A and B (e.g., A metal and BO$_x$ oxide), the required molar flux ratio is

$$\frac{\Phi_A}{\Phi_B} = \frac{n_A / c_A}{n_B / c_B}$$

where $n_A$ is the number of cation A atoms per formula unit in the target, and $c_A$ is the number of cation A atoms per formula unit in source A. The oxygen is assumed to be supplied by the growth atmosphere or by the oxide sources.

### When to use

- Planning deposition of complex oxide heterostructures (perovskites, spinels) from multiple elemental or binary oxide sources.
- Estimating quartz crystal monitor (QCM) tooling factors for each source.

---

## Chemical Reaction Balancing

### Theory

Conservation of mass requires that a balanced chemical equation satisfy

$$\sum_{\text{reactants}} \nu_k \, n_{k,i} = \sum_{\text{products}} \nu_k \, n_{k,i} \quad \forall\; \text{element } i$$

where $\nu_k$ is the stoichiometric coefficient of species $k$ and $n_{k,i}$ is the number of atoms of element $i$ in species $k$. The toolbox verifies (but does not solve for) the balancing coefficients, with a tolerance of $10^{-9}$ to accommodate fractional stoichiometries.

### When to use

- Verifying proposed reaction equations for thin film growth chemistry (e.g., ALD precursor reactions, CVD decomposition pathways).
- Sanity-checking stoichiometry in sample preparation notes.

---

## References

- L. G. Parratt, "Surface Studies of Solids by Total Reflection of X-Rays," *Physical Review* **95**, 359--369 (1954). DOI: [10.1103/PhysRev.95.359](https://doi.org/10.1103/PhysRev.95.359)

- L. Nevot and P. Croce, "Caracterisation des surfaces par reflexion rasante de rayons X. Application a l'etude du polissage de quelques verres silicates," *Revue de Physique Appliquee* **15**, 761--779 (1980). DOI: [10.1051/rphysap:01980001503076100](https://doi.org/10.1051/rphysap:01980001503076100)

- J. Als-Nielsen and D. McMorrow, *Elements of Modern X-ray Physics*, 2nd ed. (Wiley, 2011). Chapters 3 (refraction and reflection) and 4 (kinematical diffraction).

- J. Daillant and A. Gibaud, eds., *X-ray and Neutron Reflectivity: Principles and Applications*, Lecture Notes in Physics 770 (Springer, 2009).

- V. F. Sears, "Neutron scattering lengths and cross sections," *Neutron News* **3**(3), 26--37 (1992). DOI: [10.1080/10448639208218770](https://doi.org/10.1080/10448639208218770) -- Standard reference for tabulated neutron scattering lengths.

- M. Born and E. Wolf, *Principles of Optics*, 7th ed. (Cambridge University Press, 1999). Chapter 1 (electromagnetic theory of reflection and refraction).

- B. E. Warren, *X-Ray Diffraction* (Dover, 1990). Chapter 2 (Bragg's law and the reciprocal lattice).

- P. R. Bevington and D. K. Robinson, *Data Reduction and Error Analysis for the Physical Sciences*, 3rd ed. (McGraw-Hill, 2003). Chapter 8 (least-squares fitting) -- relevant to reflectivity curve fitting methodology.

- C. F. Majkrzak, "Neutron reflectometry studies of thin films and multilayered materials," *Acta Physica Polonica A* **96**, 81--99 (1999). -- Practical review of neutron reflectometry technique and analysis.

- J. Penfold and R. K. Thomas, "The application of the specular reflection of neutrons to the study of surfaces and interfaces," *Journal of Physics: Condensed Matter* **2**, 1369--1412 (1990). DOI: [10.1088/0953-8984/2/6/001](https://doi.org/10.1088/0953-8984/2/6/001)
