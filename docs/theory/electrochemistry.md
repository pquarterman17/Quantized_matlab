# Electrochemistry

This document covers the physics behind the five electrochemistry calculator functions in `+calc/+electrochemistry/`. The treatment spans equilibrium electrode thermodynamics (Nernst), electrode kinetics (Butler-Volmer, Tafel), the ohmic correction needed to interpret real cell data, and the electrical double layer that controls non-Faradaic charging currents.

**Unit conventions.** All formulas use SI base quantities internally:
- Potentials in volts (V), with the sign understood relative to the chosen reference electrode (SHE, Ag/AgCl, SCE, ...). The Nernst formula is reference-agnostic — the standard potential $E^\circ$ encodes the reference choice. Tafel slopes and overpotentials are reference-agnostic by construction (overpotential is a difference relative to the equilibrium potential of the same couple).
- Currents in amperes (A); current densities in A/cm$^2$ (the dominant electrochemistry convention; 1 A/m$^2 = 10^{-4}$ A/cm$^2$).
- Temperature in K (default 298.15 K = 25 °C).
- Faraday constant $F = 96{,}485.332$ C/mol.
- Gas constant $R = 8.314462$ J/(mol$\cdot$K).
- Vacuum permittivity $\varepsilon_0 = 8.854 \times 10^{-12}$ F/m.

**Sign convention.** The toolbox follows the IUPAC reduction-potential convention: half-reactions are written as reductions ($\mathrm{Ox} + n e^- \to \mathrm{Red}$) and standard potentials $E^\circ$ are tabulated for the reduction direction. Positive overpotential $\eta$ corresponds to anodic polarization (driving oxidation); positive current is anodic.

For ion-conduction context (mobility, Einstein relation, Debye screening), see the parallel discussion in [transport.md](transport.md).

---

## Nernst Equation

### Theory

Consider a half-cell reaction at equilibrium:

$$\mathrm{Ox} + n e^- \rightleftharpoons \mathrm{Red}$$

The Gibbs free energy change for the reaction at the actual (non-standard) activities of the species is

$$\Delta G = \Delta G^\circ + RT \ln Q$$

where $Q$ is the reaction quotient, evaluated as the product of activities of products raised to their stoichiometric coefficients divided by the same for reactants. For the reduction above, with activities $a_{\mathrm{Ox}}$ and $a_{\mathrm{Red}}$,

$$Q = \frac{a_{\mathrm{Red}}}{a_{\mathrm{Ox}}}$$

The link to the electrode potential comes from the relation between Gibbs energy and the work done by transferring $n$ electrons through a potential difference $E$:

$$\Delta G = -nFE \qquad \Delta G^\circ = -nFE^\circ$$

Substituting these into the thermodynamic expression for $\Delta G$ and dividing through by $-nF$:

$$\boxed{\;E = E^\circ - \frac{RT}{nF}\ln Q\;}$$

This is the **Nernst equation**. It gives the equilibrium electrode potential $E$ (often denoted $E_{\mathrm{eq}}$) at the activities specified by $Q$, relative to the same reference as $E^\circ$.

#### Conventions: reduction vs. oxidation

The IUPAC standard is to tabulate $E^\circ$ for the reduction direction. If a textbook or paper writes the reaction as an oxidation ($\mathrm{Red} \to \mathrm{Ox} + n e^-$), the sign of $E^\circ$ is flipped and $Q$ is inverted. The two forms are thermodynamically equivalent — but mixing conventions inside a single calculation is the most common source of sign errors. **The toolbox uses IUPAC reduction throughout.**

#### Decadic-log form at 25 °C

For most laboratory work it is convenient to convert from natural to common logarithm and evaluate the prefactor at 25 °C ($T = 298.15$ K):

$$\frac{RT}{F}\ln 10 \;=\; \frac{(8.314)(298.15)(2.3026)}{96485} \;\approx\; 0.0592\;\mathrm{V}$$

so

$$E = E^\circ - \frac{0.0592}{n}\,\log_{10} Q \quad (T = 25\;^\circ\mathrm{C})$$

Each factor-of-10 change in $Q$ shifts the potential by $59.2/n$ mV. The full formula scales linearly with $T$; at $T = 310$ K (body temperature) the prefactor is $0.0615$ V instead of $0.0592$ V.

### Worked example — Cu$^{2+}$/Cu at 1 mM, 25 °C

The Cu$^{2+}$/Cu couple has $E^\circ = +0.340$ V vs. SHE for $\mathrm{Cu}^{2+} + 2e^- \to \mathrm{Cu}$, with $n = 2$. Solid Cu has unit activity, so

$$Q = \frac{1}{a_{\mathrm{Cu}^{2+}}} = \frac{1}{10^{-3}} = 10^{3}$$

Using the decadic form:

$$E = 0.340 - \frac{0.0592}{2}\log_{10}(10^3) = 0.340 - 0.0888 = 0.251\;\mathrm{V}$$

The 1 mM activity shifts the equilibrium potential **downward** by $\sim$89 mV from standard. That is, at lower Cu$^{2+}$ concentration, the metal is harder to plate (less driving force for the reduction).

For comparison, the natural-log form yields

$$E = 0.340 - \frac{(8.314)(298.15)}{(2)(96485)}\ln(10^3) = 0.340 - 0.0888 = 0.251\;\mathrm{V}\;\checkmark$$

### Multi-electron transfers

The Nernst prefactor scales as $1/n$, so a four-electron process is four times less sensitive to $Q$ than a one-electron process. This matters for the **oxygen evolution reaction** (OER):

$$2\,\mathrm{H}_2\mathrm{O} \to \mathrm{O}_2 + 4\mathrm{H}^+ + 4e^- \qquad E^\circ = +1.23\;\mathrm{V vs.\ SHE}$$

with $n = 4$. The pH dependence is $-0.0592/4 \times 4 = -59.2$ mV/pH (the four protons cancel the $1/n$ factor). For the **hydrogen evolution reaction** (HER, $n = 2$, two protons), the slope is also $-59.2$ mV/pH. These are the two slopes that define the "thermodynamic stability window of water" on a Pourbaix diagram.

The same logic applies to multi-step proton-coupled electron transfer in catalysis: a $1.23$ V thermodynamic OER overpotential at standard conditions is the *minimum* — actual catalysts add several hundred mV of kinetic overpotential on top, set by Butler-Volmer kinetics (next section).

### When to use

- Computing the equilibrium potential of a half-cell at non-standard activity (anything other than 1 M / 1 atm / 25 °C).
- Building Pourbaix (E vs. pH) diagrams.
- Computing the open-circuit potential of a battery cathode at a specified state of charge.
- **Not** for predicting the operating potential of an electrode under current — that requires the Butler-Volmer equation plus iR correction.

### References

- A. J. Bard and L. R. Faulkner, *Electrochemical Methods: Fundamentals and Applications*, 2nd ed., Wiley, 2001 — §2.1 (Gibbs energy and electrode potentials), §2.2 (Nernst equation derivation).
- P. Atkins and J. de Paula, *Physical Chemistry*, 11th ed., Oxford, 2018 — Ch. 6 (chemical equilibrium and electrochemistry).
- IUPAC, "Quantities, Units and Symbols in Physical Chemistry" (Green Book), 3rd ed., RSC Publishing, 2007 — §2.13 (electrochemistry conventions).

---

## Butler-Volmer Equation

### Theory

The Nernst equation gives the equilibrium potential at zero net current. Real electrodes operate away from equilibrium under an applied **overpotential** $\eta = E - E_{\mathrm{eq}}$. The **Butler-Volmer (BV) equation** describes the resulting current density $j$ as the difference between the anodic (oxidation) and cathodic (reduction) partial currents:

$$\boxed{\;j \;=\; j_0\!\left[\exp\!\left(\frac{\alpha_a F \eta}{RT}\right) - \exp\!\left(-\frac{\alpha_c F \eta}{RT}\right)\right]\;}$$

where:

- $j_0$ is the **exchange current density** — the equal anodic and cathodic partial-current magnitude at $\eta = 0$. It is a kinetic property, not a thermodynamic one. Fast electrochemistry (Pt for HER): $j_0 \sim 10^{-3}$ A/cm$^2$. Slow electrochemistry (Hg for HER): $j_0 \sim 10^{-13}$ A/cm$^2$. **Ten orders of magnitude** of variation across electrode materials is normal.
- $\alpha_a$ and $\alpha_c$ are the **anodic and cathodic transfer coefficients**, dimensionless numbers in $(0, 1)$ that describe how strongly $\eta$ accelerates each direction. Physically they measure the fraction of $F\eta$ that lowers the activation barrier for that branch.

#### Derivation sketch

For a one-step, single-electron transfer with a symmetric energy diagram, transition-state theory gives both partial currents the form $k \exp(-\Delta G^\ddagger/RT)$, with the activation free energy linearly perturbed by $\eta$:

$$\Delta G_a^\ddagger = \Delta G_a^{\ddagger,0} - \alpha_a F \eta \qquad \Delta G_c^\ddagger = \Delta G_c^{\ddagger,0} + \alpha_c F \eta$$

At equilibrium ($\eta = 0$) the rates balance and define $j_0$. For one electron transferred in a single elementary step, the constraint $\alpha_a + \alpha_c = 1$ holds. **For multi-step mechanisms this constraint breaks** — both can be much less than $0.5$, and $\alpha_a + \alpha_c \neq 1$ in general. This is why fitting BV to real data is a useful mechanistic probe.

### Limiting forms

**Low overpotential** ($|\eta| \ll RT/F \approx 25.7$ mV at 25 °C). Taylor-expand both exponentials to first order:

$$j \approx j_0 \cdot \frac{(\alpha_a + \alpha_c) F}{RT}\,\eta \;\equiv\; \frac{\eta}{R_{ct}}$$

The electrode behaves like a linear resistor with **charge-transfer resistance**

$$R_{ct} = \frac{RT}{(\alpha_a + \alpha_c) F j_0}$$

For the symmetric case $\alpha_a = \alpha_c = 0.5$ at 25 °C, $R_{ct} = 0.0257/j_0$. EIS in the low-amplitude regime measures $R_{ct}$ directly, which is the standard non-destructive way to extract $j_0$.

**High anodic overpotential** ($\eta \gtrsim 50$ mV). The cathodic term becomes negligible:

$$j \;\approx\; j_0 \exp\!\left(\frac{\alpha_a F \eta}{RT}\right)$$

This is the **Tafel form** — the topic of the next section. The toolbox returns this as `result.jTafel` for direct comparison.

**High cathodic overpotential** ($\eta \lesssim -50$ mV):

$$j \;\approx\; -j_0 \exp\!\left(-\frac{\alpha_c F \eta}{RT}\right)$$

Note the negative sign: cathodic overpotential drives reduction current, which the convention here makes negative.

### Symmetric vs. asymmetric kinetics

The "default" $\alpha = 0.5$ (and $\alpha_a = \alpha_c = 0.5$) corresponds to a symmetric activation barrier — the saddle point between reactant and product is exactly halfway along the reaction coordinate. Asymmetry has a clean physical meaning:

- $\alpha_a > 0.5$: the transition state resembles the product (oxidized form). Anodic overpotential is more effective at accelerating the rate.
- $\alpha_a < 0.5$: the transition state resembles the reactant. The reaction is "early" along the reaction coordinate.

In multi-step mechanisms, the **observed** transfer coefficient combines the symmetry factor of the rate-limiting elementary step with the number of preceding electron transfers. The Tafel slope (next section) is the standard observable.

### Mass-transport limitation

BV assumes the surface concentration of reactant equals the bulk concentration. At sufficiently large $|\eta|$ the surface concentration depletes and the current saturates at the **diffusion-limited current density**

$$j_{\lim} = \frac{n F D c^*}{\delta}$$

where $D$ is the diffusivity, $c^*$ the bulk concentration, and $\delta$ the diffusion-layer thickness (set by stirring or rotation rate). For typical aqueous redox at a rotating disk, $j_{\lim} \sim 1$–$10$ mA/cm$^2$. Above this current, the BV equation should be replaced by a mass-transport-corrected form (Koutecký-Levich analysis); the toolbox does not apply such a correction internally.

### Worked example

Take an electrode with $j_0 = 10^{-6}$ A/cm$^2$, $\alpha = 0.5$, $T = 298.15$ K, anodic overpotential $\eta = 0.120$ V.

The dimensionless argument is

$$\frac{\alpha F \eta}{RT} = \frac{(0.5)(96485)(0.120)}{(8.314)(298.15)} = 2.336$$

so

$$j_a = 10^{-6} \exp(2.336) = 1.034 \times 10^{-5}\;\mathrm{A/cm}^2$$

$$j_c = -10^{-6} \exp(-2.336) = -9.67 \times 10^{-8}\;\mathrm{A/cm}^2$$

$$j = j_a + j_c = 1.024 \times 10^{-5}\;\mathrm{A/cm}^2 \approx 10\;\mu\mathrm{A/cm}^2$$

A $120$ mV overpotential has produced a 10× increase in current over $j_0$. Note that $|j_c| \ll j_a$ at this overpotential (factor of $\sim 100$): the Tafel approximation is already valid to about 1%.

### When to use

- Fitting steady-state polarization curves $j(\eta)$ from rotating-disk or microelectrode experiments to extract $j_0$ and $\alpha$.
- Predicting current at a single overpotential when $j_0$ and $\alpha$ are known from prior characterization.
- Computing $R_{ct}$ for comparison with low-amplitude EIS data.
- **Not** when $|\eta|$ is large enough that mass transport becomes rate-limiting — fit Tafel only to the linear region of a $\log|j|$ vs $\eta$ plot, well below the diffusion plateau.

### References

- Bard & Faulkner, *Electrochemical Methods*, 2nd ed., Ch. 3 — full treatment of BV from transition-state theory, including derivations of the limiting forms.
- R. A. Marcus, "On the theory of oxidation-reduction reactions involving electron transfer," *J. Chem. Phys.* **24**, 966–978 (1956); and "Electron transfer reactions in chemistry: Theory and experiment," *Rev. Mod. Phys.* **65**, 599 (1993). Marcus theory provides the microscopic origin of $j_0$ and the curvature of $\Delta G^\ddagger(\eta)$ at large $|\eta|$ (the inverted region).
- J. O'M. Bockris, A. K. N. Reddy, M. Gamboa-Aldeco, *Modern Electrochemistry 2A: Fundamentals of Electrodics*, 2nd ed., Springer, 2000 — Ch. 7.

---

## Tafel Analysis

### Theory

In the high-overpotential limit of the Butler-Volmer equation (anodic branch shown; cathodic is symmetric with $-\eta$ and $\alpha_c$):

$$j \;\approx\; j_0 \exp\!\left(\frac{\alpha F \eta}{RT}\right)$$

Taking the base-10 logarithm of both sides:

$$\log_{10}|j| \;=\; \log_{10}|j_0| \;+\; \frac{\alpha F}{2.303\,RT}\,\eta$$

This is **Tafel's equation**, a linear relationship between $\eta$ and $\log_{10}|j|$. Rearranged,

$$\eta = -b \log_{10}|j_0| + b \log_{10}|j| \qquad b \equiv \frac{2.303\,RT}{\alpha F}$$

The **Tafel slope** $b$ has units of V/decade. At 25 °C with $\alpha = 0.5$:

$$b = \frac{(2.303)(8.314)(298.15)}{(0.5)(96485)} = 0.1183\;\mathrm{V/dec} \approx 118\;\mathrm{mV/dec}$$

The convenient rule of thumb is **$b \approx 60/\alpha$ mV/decade at 25 °C**, so $\alpha = 0.5$ gives $\sim$120 mV/dec, $\alpha = 1$ gives $\sim$60 mV/dec, and $\alpha = 2$ (a two-electron rate-limiting step) gives $\sim$30 mV/dec.

### Extracting $j_0$ from a Tafel plot

Plot $\log_{10}|j|$ on the y-axis against $\eta$ on the x-axis. In the Tafel regime the points fall on a straight line with slope $1/b$ and intercept $\log_{10}|j_0|$ at $\eta = 0$. The intercept is found by extrapolating the linear portion back to $\eta = 0$ — *not* by reading the data point at $\eta = 0$, which is dominated by ohmic and capacitive contributions and not the Tafel slope.

Equivalently, plot $\eta$ on the y-axis vs. $\log_{10}|j|$: slope is $b$ directly, and the x-intercept is $\log_{10}|j_0|$.

### Validity range

The Tafel approximation neglects the back-reaction term, which is valid when

$$\exp(-(\alpha_c+\alpha_a) F |\eta|/RT) \ll 1 \quad\Rightarrow\quad |\eta| \gtrsim 50\;\mathrm{mV}$$

(at 25 °C, $\alpha_a + \alpha_c = 1$). Below this, the linear region of BV applies and $\log|j|$ vs. $\eta$ is curved toward the y-axis. Above several hundred mV, mass transport sets in and the Tafel plot bends over toward a horizontal $j_{\lim}$ asymptote. The **Tafel region** is the linear stretch in between, typically $\sim 60$–$300$ mV wide for an aqueous redox system.

### Tafel slope as a mechanistic fingerprint

For the **hydrogen evolution reaction** (HER) on a metal surface, three elementary steps are possible:

1. **Volmer**: $\mathrm{H}^+ + e^- \to \mathrm{H}_{\mathrm{ad}}$ (proton discharge / electroadsorption)
2. **Heyrovsky**: $\mathrm{H}_{\mathrm{ad}} + \mathrm{H}^+ + e^- \to \mathrm{H}_2$ (electrochemical desorption)
3. **Tafel**: $2\mathrm{H}_{\mathrm{ad}} \to \mathrm{H}_2$ (chemical recombination)

Each combination of "rate-limiting step" produces a characteristic Tafel slope at 25 °C with $\alpha = 0.5$:

| Rate-limiting step | $b$ (mV/dec, 25 °C) | Mechanistic interpretation |
|---|---|---|
| Volmer | $\sim 120$ | Proton discharge is rate-limiting; low H coverage |
| Heyrovsky (after fast Volmer) | $\sim 40$ | Volmer pre-equilibrium; recombination via electrochemical desorption |
| Tafel (after fast Volmer) | $\sim 30$ | Volmer pre-equilibrium; recombination via surface chemistry |

A measured slope of $\sim$30 mV/dec on Pt strongly implies a Volmer-Tafel mechanism with chemical recombination as the rate-limiting step — consistent with the high $\mathrm{H}_{\mathrm{ad}}$ coverage on Pt. A measured $\sim$120 mV/dec on Hg implies the Volmer step is rate-limiting — consistent with Hg's weak H-binding. Similar rate-limiting analyses apply to OER ($\sim$40, 60, 120 mV/dec for various mechanisms), CO$_2$RR, and ORR. **The Tafel slope is the cheapest mechanistic discriminator in heterogeneous electrocatalysis.**

### Worked example

A measured polarization curve has the following points in the Tafel region:

| $\eta$ (mV) | $j$ (mA/cm$^2$) | $\log_{10}j$ |
|---|---|---|
| 100 | 0.10  | $-1.00$ |
| 150 | 0.32  | $-0.50$ |
| 200 | 1.00  | $0.00$  |
| 250 | 3.16  | $0.50$  |

Linear fit of $\eta$ vs. $\log_{10}|j|$: slope $= 100$ mV/dec, intercept (at $\log_{10}|j| = 0$, i.e. $j = 1$ mA/cm$^2$) $= 200$ mV. Extrapolating to $\eta = 0$:

$$\log_{10}|j_0| = -\frac{200}{100} = -2.0 \;\Rightarrow\; j_0 = 10^{-2}\;\mathrm{mA/cm}^2 = 10\;\mu\mathrm{A/cm}^2$$

The transfer coefficient: $\alpha = (2.303)(8.314)(298.15) / [(96485)(0.100)] = 0.59$.

So this electrode has a moderate exchange current density ($10\,\mu$A/cm$^2$) and a slightly asymmetric kinetics ($\alpha \approx 0.6$). The slope of 100 mV/dec is intermediate between the 120 mV/dec Volmer-limited and the 60 mV/dec mixed regimes — could indicate a transition between mechanisms or a non-integer $\alpha$ from a multi-step pathway.

### When to use

- Whenever you have steady-state polarization curve over $\sim$1–3 decades of current. Tafel analysis is the standard way to extract $j_0$ from real lab data, more practical than EIS for many systems.
- For mechanistic inference (the "fingerprint" use above) — but only when supported by independent evidence (pH dependence, isotope effects, in-situ spectroscopy).

### Pitfalls

- **Don't fit the whole curve.** Restrict the linear fit to the actual Tafel region (visually identifiable as the straight-line portion of $\eta$ vs. $\log|j|$). Including the low-$\eta$ curvature or the high-$\eta$ mass-transport plateau biases the slope.
- **iR-correct first** (next section). An uncompensated 50 Ω cell at 1 mA gives a 50 mV iR drop — comparable to the entire Tafel slope. Without iR correction, the apparent slope is too steep.
- **Subtract background.** Capacitive charging and parasitic redox can dominate the current at small $\eta$. Use a sufficiently slow sweep rate (or steady-state stepping) to ensure $j$ is Faradaic.

### References

- J. Tafel, "Über die Polarisation bei kathodischer Wasserstoffentwicklung," *Z. Phys. Chem.* **50**, 641–712 (1905) — the original empirical observation, predating the BV derivation by two decades.
- B. E. Conway, *Electrochemical Supercapacitors*, Kluwer, 1999 — Ch. 4 has a clear modern treatment of the Tafel relation and its mechanistic interpretation.
- S. Trasatti, "Work function, electronegativity, and electrochemical behaviour of metals," *J. Electroanal. Chem.* **39**, 163 (1972), and the follow-on volcano-plot literature for HER.
- Bard & Faulkner, Ch. 3.4 — Tafel analysis with worked numerical examples.

---

## iR Compensation (Ohmic Drop)

### Theory

In a real electrochemical cell, the current $i$ flows from the working electrode through a finite **uncompensated resistance** $R_u$ before reaching the reference electrode. The applied potential differs from the actual interfacial potential by an ohmic drop:

$$V_{\mathrm{applied}} = V_{\mathrm{interfacial}} + i R_u$$

or equivalently,

$$\boxed{\;V_{\mathrm{IR}} = i R_u\;}$$

In the IUPAC anodic-positive sign convention, **subtract** $iR_u$ from the measured potential to recover the true interfacial potential:

$$E_{\mathrm{true}} = E_{\mathrm{measured}} - i R_u$$

$R_u$ has two contributions:

$$R_u = R_{\mathrm{soln}} + R_{\mathrm{contact}}$$

- $R_{\mathrm{soln}}$: the electrolyte resistance between the working-electrode surface and the tip of the reference (or Luggin capillary). Scales inversely with the conductivity $\kappa$ of the solution and depends on geometry.
- $R_{\mathrm{contact}}$: contact resistances at wires, connectors, and the working-electrode lead. Usually negligible (< 1 Ω) for well-built cells.

### Why it matters

The iR drop distorts every potential-controlled experiment:

- **Cyclic voltammetry**: peaks shift apart (anodic peak to higher $E$, cathodic peak to lower $E$), and the peak separation $\Delta E_p$ is overestimated. The reversibility metric $\Delta E_p \approx 59/n$ mV becomes useless.
- **Tafel plots**: apparent slope is too steep (since you are plotting $\eta_{\mathrm{measured}} = \eta_{\mathrm{true}} + iR_u$ vs. $\log|j|$, and $iR_u$ scales with $j$).
- **Chronoamperometry**: the early-time current (Cottrell decay) is suppressed because the interfacial potential takes time to charge through $R_u$ in series with the double-layer capacitance ($\tau = R_u C_{dl}$).

### Estimating $R_u$

Three standard methods:

1. **High-frequency EIS plateau.** At frequencies above $\sim 10$ kHz the double-layer capacitance is shorted ($|Z_C| = 1/\omega C \to 0$) and the impedance reduces to $R_u$. Read the real-axis intercept of the Nyquist plot.
2. **Current-interrupt.** Apply a current pulse, then break the circuit. The interfacial potential decays via the double-layer over $\tau = R_u C_{dl} \sim$ ms; the *instantaneous* potential drop at the moment of interrupt is $iR_u$.
3. **Positive-feedback compensation** (built into most potentiostats). The instrument measures $i$ and adds a correction $\beta \cdot i \cdot R_{\mathrm{set}}$ back into the applied potential. With $R_{\mathrm{set}} \approx R_u$ and $\beta$ tuned to just below the oscillation threshold, $\geq 90\%$ of the iR drop can be removed in real time.

### Worked example

A 1 mA current flows through a cell with $R_u = 200$ Ω.

$$V_{\mathrm{IR}} = (10^{-3})(200) = 0.200\;\mathrm{V} = 200\;\mathrm{mV}$$

This is enormous on the scale of an electrochemical experiment. A CV recorded at 50 mV/s would have its anodic and cathodic peaks displaced by 200 mV in opposite directions — no usable kinetic information remains. The peak shift makes a "reversible" (60 mV/n) couple look "quasi-reversible to irreversible" (260 mV/n).

For a more typical case: $i = 100\;\mu$A through $R_u = 50$ Ω gives $V_{\mathrm{IR}} = 5$ mV, comfortably within the $< 5$ mV "negligible" guideline below.

### When to compensate — guideline

A practical rule of thumb:

| $|i R_u|$ | Action |
|---|---|
| $< 5$ mV | Negligible; no correction needed for typical CV / Tafel work |
| $5$–$50$ mV | Apply positive-feedback compensation, or post-process by subtracting $iR_u$ from each data point |
| $> 50$ mV | Hardware compensation essential; reduce $R_u$ by adding supporting electrolyte, repositioning the reference, or using a Luggin capillary |

For very fast methods (microsecond-resolved chronoamperometry, fast-scan CV at $> 1$ V/s), even a few mV of iR is significant because it compounds with the bandwidth limitation $1/(R_u C_{dl})$.

### When to use

- After every steady-state polarization measurement, before performing Tafel analysis.
- When comparing CVs across cells, electrolytes, or scan rates — always normalize with iR-correction first.
- When designing a high-current experiment (e.g., a battery cycling rig) where currents of 0.1–10 A through even modest $R_u$ produce non-trivial drops.

### References

- Bard & Faulkner, *Electrochemical Methods*, 2nd ed., §1.3.4 (uncompensated resistance) and §15.6 (positive feedback).
- D. Britz, "iR elimination in electrochemical cells," *J. Electroanal. Chem.* **88**, 309–352 (1978) — the canonical review of iR compensation methods.
- He and Faulkner, "Intelligent, automatic compensation of solution resistance," *Anal. Chem.* **58**, 517 (1986) — modern current-interrupt implementation.

---

## Electrical Double-Layer Capacitance

### Theory

When an electrode is polarized in an electrolyte, charge accumulates at the interface in two layers:

1. A **compact (Stern/Helmholtz) layer** of solvent molecules and specifically adsorbed ions in direct contact with the electrode surface, of thickness $d_H$ (typically $0.3$–$0.5$ nm — roughly one solvent diameter plus an ion radius).
2. A **diffuse (Gouy-Chapman) layer** extending into the bulk, where ion concentrations follow a Boltzmann distribution in the local potential and decay exponentially over the Debye length $\kappa^{-1}$.

The total double-layer capacitance is the series combination of the Stern and diffuse capacitances. We discuss three models in increasing realism.

#### Helmholtz (1853)

Treats the interface as a parallel-plate capacitor with electrode and solution charge separated by a fixed distance $d_H$ filled with a dielectric of relative permittivity $\varepsilon$:

$$\boxed{\;C_H = \frac{\varepsilon_0 \varepsilon}{d_H}\;}$$

For water-like $\varepsilon \approx 80$ in the inner layer (often *less* in reality due to dielectric saturation under the strong interfacial field, $\varepsilon \sim 6$–$30$) and $d_H = 0.3$ nm, $C_H \approx 24\;\mu$F/cm$^2$ — in good agreement with measured values on Hg ($\sim$20 μF/cm$^2$) and Pt ($\sim$30 μF/cm$^2$).

This model **predicts a constant capacitance**, independent of potential and concentration. That is its principal weakness: real $C_{dl}(E)$ curves are V-shaped with a minimum at the **potential of zero charge** (PZC).

The toolbox function `doubleLayerCapacitance(epsilon, d, A)` implements exactly this parallel-plate Helmholtz form, scaled by the electrode area $A$:

$$C = \frac{\varepsilon_0 \varepsilon A}{d}$$

#### Gouy-Chapman (1910–1913)

Treats the diffuse layer self-consistently: ions are point charges in a continuum dielectric obeying a Boltzmann distribution. The Poisson-Boltzmann equation gives the potential profile, and differentiation yields the small-signal capacitance per unit area:

$$C_{GC} = \sqrt{\frac{2 \varepsilon_0 \varepsilon F^2 c}{RT}} \;\cosh\!\left(\frac{zF\phi_0}{2RT}\right)$$

where $c$ is the bulk salt concentration (mol/m$^3$) and $\phi_0$ is the potential at the outer Helmholtz plane (relative to the bulk). At the PZC ($\phi_0 = 0$):

$$C_{GC,0} = \sqrt{\frac{2 \varepsilon_0 \varepsilon F^2 c}{RT}} \;=\; \frac{\varepsilon_0 \varepsilon}{\kappa^{-1}}$$

where $\kappa^{-1} = \sqrt{\varepsilon_0 \varepsilon RT / (2 F^2 c)}$ is the Debye length. So GC is morphologically a parallel-plate capacitor of plate separation $\kappa^{-1}$.

For 0.1 M ($c = 100$ mol/m$^3$) aqueous 1:1 electrolyte at 25 °C, $\kappa^{-1} \approx 0.96$ nm, giving $C_{GC,0} \approx 73\;\mu$F/cm$^2$ at the PZC. For 1 mM, $\kappa^{-1} \approx 9.6$ nm and $C_{GC,0} \approx 7.3\;\mu$F/cm$^2$.

The $\cosh$ factor makes $C_{GC}$ rise rapidly as the electrode is polarized away from the PZC — the diffuse layer compresses toward the electrode and looks like a thinner parallel-plate capacitor. **Pure GC overpredicts** capacitances at moderate-to-high concentrations because it ignores the ion size.

#### Stern (1924)

Combines the two: a fixed Helmholtz layer in series with the GC diffuse layer. Capacitances in series add reciprocally:

$$\boxed{\;\frac{1}{C_{\mathrm{total}}} = \frac{1}{C_H} + \frac{1}{C_{GC}}\;}$$

The smaller of the two dominates. At **high salt concentrations** ($c \gtrsim 0.1$ M), $C_{GC}$ is large and $C_{\mathrm{total}} \to C_H$ — the Helmholtz layer is the bottleneck. At **low salt concentrations** ($c \lesssim 1$ mM), $C_{GC}$ is small and $C_{\mathrm{total}} \to C_{GC}$. The transition is broad.

This is why the rule-of-thumb "$C_{dl} \approx 20\;\mu$F/cm$^2$ on a smooth metal" works in concentrated supporting electrolyte: the Stern layer pins the capacitance regardless of which ions are present.

### Specific capacitance of common interfaces

Order-of-magnitude reference values (smooth surface, 0.1 M aqueous supporting electrolyte, near PZC):

| Interface | $C_{dl}$ (μF/cm$^2$) |
|---|---|
| Hg / aqueous | $\sim$18–22 |
| Pt / aqueous (clean polycrystalline) | $\sim$20–40 |
| Au / aqueous | $\sim$20–35 |
| Glassy carbon / aqueous | $\sim$15–30 |
| Boron-doped diamond / aqueous | $\sim$3–10 |

For high-surface-area electrodes (porous carbon, RuO$_2$, etc.) the *gravimetric* capacitance (F/g) is reported instead, and is much larger than the geometric value because of the underlying surface area. Activated carbon supercapacitors achieve $\sim$100 F/g, but the per-cm$^2$ specific capacitance of the actual surface is still in the μF range.

### Frequency dispersion — the constant-phase element

Real interfaces show a dispersive impedance $Z_{CPE} = 1/[Q(j\omega)^n]$ with $n < 1$ rather than the ideal capacitor's $n = 1$. The phenomenological **constant-phase element** (CPE) absorbs surface roughness, heterogeneous adsorption, and slow dielectric relaxation. When fitting EIS data the CPE pseudo-capacitance must be converted to an effective $C_{dl}$ via, e.g., the Brug formula:

$$C_{dl} = Q^{1/n} \left(\frac{1}{R_s} + \frac{1}{R_{ct}}\right)^{(n-1)/n}$$

This is outside the scope of the toolbox's parallel-plate calculator but is essential for quantitative EIS work.

### Worked example — concentration crossover

Compare $C_{dl}$ predicted by Helmholtz, Gouy-Chapman, and Stern for an aqueous 1:1 electrolyte at the PZC, using $\varepsilon = 78$, $T = 298.15$ K, $d_H = 0.5$ nm.

**Helmholtz** (concentration-independent):

$$C_H = \frac{(8.854 \times 10^{-12})(78)}{0.5 \times 10^{-9}} = 1.38\;\mathrm{F/m}^2 = 138\;\mu\mathrm{F/cm}^2$$

This is unrealistically high because we used bulk water $\varepsilon = 78$; with dielectric saturation in the Stern layer ($\varepsilon \sim 30$), $C_H$ drops to $\sim$53 μF/cm$^2$, and with $\varepsilon \sim 6$ (heavy saturation), $\sim$11 μF/cm$^2$ — closer to measurements.

**Gouy-Chapman** (at the PZC, with $\varepsilon = 78$):

| $c$ (mol/L) | $\kappa^{-1}$ (nm) | $C_{GC,0}$ (μF/cm$^2$) |
|---|---|---|
| $10^{-4}$ | 30.4 | 2.3 |
| $10^{-3}$ | 9.6 | 7.3 |
| $10^{-2}$ | 3.0 | 23 |
| $10^{-1}$ | 0.96 | 73 |
| $1$       | 0.30 | 230 |

**Stern** (assuming $C_H = 25$ μF/cm$^2$ as a realistic Stern-layer limit):

| $c$ (mol/L) | $C_{GC,0}$ | $C_{\mathrm{total}}$ |
|---|---|---|
| $10^{-4}$ | 2.3 | 2.1 (GC-limited) |
| $10^{-2}$ | 23 | 12 (mixed) |
| $10^{-1}$ | 73 | 19 (Stern-limited) |
| $1$       | 230 | 23 (Stern-limited) |

The crossover from GC-limited to Stern-limited behavior happens around $10^{-2}$–$10^{-1}$ M. **At typical supporting-electrolyte concentrations (0.1–1 M), the Stern layer dominates and the measured $C_{dl}$ is essentially independent of bulk salt — explaining why the same interface gives nearly constant $C_{dl}$ across electrolytes.**

### When to use

- Rough estimation of charging current $i_c = C_{dl} A (dE/dt)$ for CV — needed to distinguish Faradaic from background current.
- Sizing decoupling capacitance for fast pulse experiments (the cell time constant $\tau = R_u C_{dl}$ sets the bandwidth limit).
- Estimating real surface area: measured $C_{dl}$ divided by a "reference" specific capacitance (typically 20 μF/cm$^2$) gives the electrochemically active surface area (ECSA).
- **Not** as a quantitative model of the interface — the parallel-plate Helmholtz form ignores the diffuse layer, dielectric saturation, ion size, and frequency dispersion. Use it for orders-of-magnitude work only.

### References

- D. C. Grahame, "The electrical double layer and the theory of electrocapillarity," *Chem. Rev.* **41**, 441–501 (1947) — the classic critical review of Hg double-layer data and the Stern-Grahame model.
- Bard & Faulkner, *Electrochemical Methods*, 2nd ed., Ch. 13 — full derivation of GC and Stern, plus extensive data tables.
- O. Stern, "Zur Theorie der elektrolytischen Doppelschicht," *Z. Elektrochem.* **30**, 508–516 (1924) — original paper combining Helmholtz and Gouy-Chapman.
- B. E. Conway, *Electrochemical Supercapacitors*, Kluwer, 1999 — modern treatment with CPE / pseudo-capacitance and high-surface-area electrodes.
- P. Debye and E. Hückel, "Zur Theorie der Elektrolyte," *Phys. Z.* **24**, 185 (1923) — origin of the screening-length concept that underpins GC. See also the analogous discussion in [transport.md](transport.md) on the semiconductor Debye length.

---

## Implementation

| Function | Equation | Key inputs (units) | Output |
|---|---|---|---|
| `nernstPotential(E0, n, Q, T=)` | $E = E^\circ - (RT/nF)\ln Q$ | $E^\circ$ (V), $n$ (—), $Q$ (—), $T$ (K, default 298.15) | `.E` (V), `.E0`, `.n`, `.Q`, `.T`, `.latex` |
| `butlerVolmer(j0, eta, alpha=, T=)` | $j = j_0[\exp(\alpha F\eta/RT) - \exp(-(1-\alpha)F\eta/RT)]$ | $j_0$ (A/cm$^2$), $\eta$ (V), $\alpha \in (0,1)$ default 0.5, $T$ (K) | `.j`, `.jAnodic`, `.jCathodic`, `.jTafel` (all A/cm$^2$), `.latex` |
| `tafelSlope(alpha, T=)` | $b = 2.303\,RT/(\alpha F)$ | $\alpha \in (0,1)$, $T$ (K) | `.b` (V/dec), `.bMv` (mV/dec), `.latex` |
| `ohmicDrop(I, R)` | $V_{\mathrm{IR}} = I R$ | $I$ (A, signed), $R \geq 0$ (Ω) | `.V` (V), `.VmV` (mV), `.latex` |
| `doubleLayerCapacitance(epsilon, d, A)` | $C = \varepsilon_0 \varepsilon A / d$ (Helmholtz / parallel-plate) | $\varepsilon$ (—), $d$ (nm), $A$ (cm$^2$) | `.C` (F), `.CuF` (μF), `.CpF` (pF), `.Cspec` (F/cm$^2$), `.latex` |

All functions use `R`, `F`, and `eps0` from `calc.constants()` for consistency and CODATA-traceable values. All return a struct with a `.latex` field for direct insertion into the DiraCulator history pane and report templates.

**Cross-references.** For diffusion coefficients and the Einstein relation that connect to mass-transport-limited currents, see [transport.md](transport.md). For impedance fitting context (CPE, equivalent-circuit fitting), the [fitting.md](fitting.md) document covers the underlying nonlinear least-squares engine used by the fitting GUI.

---

## References (consolidated)

- A. J. Bard and L. R. Faulkner, *Electrochemical Methods: Fundamentals and Applications*, 2nd ed., Wiley, 2001 — the canonical reference; cited chapters above.
- J. O'M. Bockris, A. K. N. Reddy, M. Gamboa-Aldeco, *Modern Electrochemistry 2A*, 2nd ed., Springer, 2000.
- B. E. Conway, *Electrochemical Supercapacitors: Scientific Fundamentals and Technological Applications*, Kluwer Academic / Plenum, 1999.
- P. Atkins and J. de Paula, *Physical Chemistry*, 11th ed., Oxford, 2018.
- D. C. Grahame, "The electrical double layer and the theory of electrocapillarity," *Chem. Rev.* **41**, 441–501 (1947).
- J. Tafel, "Über die Polarisation bei kathodischer Wasserstoffentwicklung," *Z. Phys. Chem.* **50**, 641–712 (1905).
- O. Stern, "Zur Theorie der elektrolytischen Doppelschicht," *Z. Elektrochem.* **30**, 508–516 (1924).
- R. A. Marcus, "Electron transfer reactions in chemistry: Theory and experiment," *Rev. Mod. Phys.* **65**, 599–610 (1993).
- D. Britz, "iR elimination in electrochemical cells," *J. Electroanal. Chem.* **88**, 309–352 (1978).
- IUPAC, *Quantities, Units and Symbols in Physical Chemistry* (Green Book), 3rd ed., RSC, 2007 — §2.13.
