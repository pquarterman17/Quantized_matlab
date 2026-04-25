# Thin Films: Deposition, Vacuum Physics, and Optics

This document covers the physics behind the `+calc/+thinFilm/`, `+calc/+vacuum/`, and `+calc/+optics/` modules. Together these three packages support the workflow of thin-film research: choosing chamber pressures and pump-down times, predicting growth rates and ion implantation profiles, estimating residual stresses and thermal effects, and computing optical reflectances/penetration depths at planar interfaces. The Kiessig-fringe and Fresnel-coefficient sections cross-link to [reflectometry.md](reflectometry.md), which covers the full Parratt recursion and SLD theory used in fitting reflectivity curves.

**Unit conventions.** SI throughout the formulas (pressure in Pa, length in m, time in s, energy in J), with explicit conversions to laboratory-friendly units (Torr, mTorr, nm, A, cm) shown alongside. A useful conversion to remember: $1\;\text{Torr} = 133.322\;\text{Pa}$, $1\;\text{mTorr} = 0.1333\;\text{Pa}$, $1\;\text{atm} = 101{,}325\;\text{Pa}$.

---

# Part I — Vacuum Physics

The vacuum environment determines what can grow on a surface and how cleanly. Three quantities dominate: the **mean free path** $\lambda$ (how far a molecule travels between collisions), the **monolayer adsorption time** $\tau_{\mathrm{ML}}$ (how long until residual gas covers the surface), and the **conductance** of the chamber (how fast you can pump). All three derive from the kinetic theory of gases.

## Mean Free Path

### Theory

In the hard-sphere kinetic-theory model, a molecule of effective collision diameter $d$ traveling through a gas of number density $n$ sweeps out a collision cylinder per unit time and collides with any other molecule whose center falls inside it. Accounting for the relative-velocity factor $\sqrt{2}$ between two Maxwell-distributed populations gives the **mean free path**:

$$\lambda = \frac{1}{\sqrt{2}\,\pi d^2 n}$$

Using the ideal-gas law $n = P/(k_B T)$:

$$\boxed{\lambda = \frac{k_B T}{\sqrt{2}\,\pi d^2 P}}$$

with $k_B = 1.381 \times 10^{-23}$ J/K. The formula in `calc.vacuum.meanFreePath` evaluates this directly with default $T = 300$ K and $d = 3.64 \times 10^{-10}$ m (N$_2$).

### Why $d$ varies by gas

The collision diameter $d$ is an effective hard-sphere parameter that absorbs all the messy details of the intermolecular potential. It is fitted to viscosity or self-diffusion data and depends weakly on temperature. Smaller, lighter gases (H$_2$, He) have smaller $d$ and therefore longer $\lambda$ at the same pressure; larger or polar gases (H$_2$O) collide more frequently.

| Gas | $d$ (A) | $\lambda$ at 1 mTorr, 300 K |
|-----|---------|---------------------------|
| H$_2$ | 2.74 | 11.3 cm |
| He | 2.18 | 17.9 cm |
| N$_2$ | 3.64 | 6.4 cm |
| Ar | 3.67 | 6.3 cm |
| O$_2$ | 3.61 | 6.5 cm |
| H$_2$O | 4.60 | 4.0 cm |

### Worked example

Argon sputter gas at 1 mTorr (0.133 Pa) and 300 K:

$$\lambda = \frac{(1.381\times 10^{-23})(300)}{\sqrt{2}\,\pi (3.67\times 10^{-10})^2 (0.133)} \approx 6.3\;\text{cm}$$

This is comparable to typical target-to-substrate distances in a sputter chamber, which is by design — it sets the boundary between "ballistic" and "thermalized" regimes for sputtered atoms.

### When to use

- Choosing chamber pressure for a deposition: a working pressure in the range where $\lambda$ is comparable to the target-substrate distance gives an intermediate-thermalization regime, often desirable for film microstructure control.
- Predicting whether contaminant gases reach the substrate ballistically (UHV) or scatter (HV).
- Input to the Knudsen number for flow-regime classification.

### References

- O'Hanlon, J. F. *A User's Guide to Vacuum Technology*, 3rd ed., Wiley, 2003, Ch. 2.
- Reif, F. *Fundamentals of Statistical and Thermal Physics*, McGraw-Hill, 1965, Ch. 12 (kinetic theory).

---

## Knudsen Number and Flow Regimes

### Theory

The Knudsen number compares the mean free path to a characteristic system length $L$ (e.g., a tube diameter or the chamber dimension):

$$\boxed{\mathrm{Kn} = \frac{\lambda}{L}}$$

Three regimes are distinguished:

| Regime | Range | Physics | Conductance scaling |
|--------|-------|---------|---------------------|
| Viscous | $\mathrm{Kn} < 0.01$ | Continuum hydrodynamics; Hagen-Poiseuille | $C \propto d^4 P$ |
| Transitional | $0.01 \leq \mathrm{Kn} \leq 1$ | Slip flow; both mechanisms matter | Approximately additive |
| Molecular | $\mathrm{Kn} > 1$ | Wall collisions dominate | $C \propto d^3$ (independent of $P$) |

The crossover at $\mathrm{Kn} \sim 1$ is the central practical fact of vacuum engineering: in the molecular regime, the conductance of pipes is *independent of pressure*, and you cannot simply "pump harder" to overcome a small-diameter restriction.

### Impact on deposition uniformity

In a sputter or evaporation chamber, the regime determines how directional the depositing flux is.

- **Molecular ($\mathrm{Kn} > 1$, typically $P \lesssim 10^{-4}$ Torr at $L \sim$ 10 cm):** atoms travel in straight lines from source to substrate. Step coverage is poor, but stoichiometry is preserved (no scattering-induced fractionation). Used for evaporation and high-vacuum sputter.
- **Transitional ($\mathrm{Kn} \sim 0.01$–1):** working regime of magnetron sputtering. Atoms thermalize partially, giving better step coverage but lower deposition rate.
- **Viscous ($\mathrm{Kn} \ll 1$):** typical of CVD and ALD. Conformal coatings on high-aspect-ratio features.

### When to use

- Classifying a chamber configuration before computing conductances.
- Diagnosing why a long, narrow tube (e.g., a load-lock viewport) is unexpectedly slow to pump out: in the molecular regime, $C \propto d^3/L$ and a 1-cm-diameter tube has 8x less conductance than a 2-cm tube.

### References

- O'Hanlon (2003), Ch. 3 (gas flow).
- Roth, A. *Vacuum Technology*, 3rd ed., North-Holland, 1990, Ch. 3.

---

## Monolayer Adsorption Time

### Theory

Residual gas in the chamber strikes every surface continuously. The **impingement rate** $Z$ (molecules per unit area per unit time) follows from the Maxwell-Boltzmann distribution of velocities:

$$Z = \frac{1}{4} n \langle v \rangle = \frac{P}{\sqrt{2\pi m k_B T}}$$

where $\langle v \rangle = \sqrt{8 k_B T / (\pi m)}$ is the mean thermal speed. The factor of $1/4$ comes from the angle-integration over molecules headed toward the surface.

Assuming **unity sticking coefficient** (every molecule that hits sticks) and a site area $A_{\mathrm{site}}$ (typically $\sim 10^{-19}$ m$^2$ — about one atomic diameter squared), the time to deposit a complete monolayer is:

$$\boxed{\tau_{\mathrm{ML}} = \frac{1}{Z \cdot A_{\mathrm{site}}} = \frac{\sqrt{2\pi m k_B T}}{P \cdot A_{\mathrm{site}}}}$$

`calc.vacuum.monolayerTime` evaluates this with defaults $m = 4.65 \times 10^{-26}$ kg (N$_2$, 28 amu) and $A_{\mathrm{site}} = 10^{-19}$ m$^2$.

### Worked example: residual H$_2$O in a deposition chamber

Water is the dominant residual gas in any baked or unbaked vacuum chamber. Take $m = 18$ amu $= 2.99 \times 10^{-26}$ kg, $T = 300$ K. Comparing two pressures:

| Pressure | $Z$ (mol/m$^2$/s) | $\tau_{\mathrm{ML}}$ |
|----------|-------------------|----------------------|
| $10^{-6}$ Torr ($1.33\times 10^{-4}$ Pa) | $4.8 \times 10^{18}$ | 2.1 s |
| $10^{-9}$ Torr ($1.33\times 10^{-7}$ Pa) | $4.8 \times 10^{15}$ | 35 min |
| $10^{-11}$ Torr (UHV) | $4.8 \times 10^{13}$ | 58 hours |

This is the central message of vacuum cleanliness: at high vacuum ($10^{-6}$ Torr) every freshly deposited surface is buried under a monolayer of contaminant in seconds. UHV ($\leq 10^{-9}$ Torr) is required for surface science and for any film whose growth is sensitive to residual oxygen or water.

### When to use

- Setting the base pressure target for a deposition: the rule of thumb is $\tau_{\mathrm{ML}} \gg t_{\mathrm{dep}}$, where $t_{\mathrm{dep}}$ is the time to grow one monolayer of *intentional* film material.
- Estimating contamination per second of beam-off time during MBE growth pauses.
- Diagnosing oxidation issues in reactive metal films (Ti, Al, rare earths).

### References

- Hudson, J. B. *Surface Science: An Introduction*, Wiley, 1998, Ch. 4.
- Smith, D. L. *Thin-Film Deposition: Principles and Practice*, McGraw-Hill, 1995, Ch. 4.

---

## Gas Flow and Conductance

### Theory

A pipe of diameter $d$ and length $L$ has a conductance $C$ (volume per unit time, e.g., L/s) such that the throughput is $Q = C(P_1 - P_2)$. The form of $C$ depends on the flow regime.

**Molecular conductance** (long pipe, $\mathrm{Kn} > 1$):

$$C_{\mathrm{mol}} = \frac{\pi d^3}{12 L} \sqrt{\frac{8 k_B T}{\pi m}}$$

This is the Knudsen formula. The cubic scaling with $d$ and the absence of pressure dependence are diagnostic of molecular flow. Conductances in **series** combine reciprocally:

$$\frac{1}{C_{\mathrm{tot}}} = \frac{1}{C_1} + \frac{1}{C_2} + \cdots$$

while in **parallel** they simply add. The pumping speed at the chamber, $S_{\mathrm{eff}}$, is reduced from the pump's intrinsic speed $S_p$ by any restrictions:

$$\frac{1}{S_{\mathrm{eff}}} = \frac{1}{S_p} + \frac{1}{C}$$

This is why short, wide pipes between chamber and pump are essential: a small-bore connection cripples the effective pump speed even with a large pump.

**Viscous conductance** (Hagen-Poiseuille, $\mathrm{Kn} \ll 1$):

$$C_{\mathrm{visc}} = \frac{\pi d^4}{128\,\eta\, L} \cdot \bar{P}, \qquad \bar{P} = \frac{P_1 + P_2}{2}$$

with $\eta$ the dynamic viscosity ($\eta_{\mathrm{N}_2} \approx 1.8 \times 10^{-5}$ Pa·s at 300 K). The fourth-power scaling with diameter and the linear pressure dependence distinguish viscous flow from molecular.

**Orifice limit.** A thin aperture of area $A$ (with $L \to 0$) has the molecular conductance:

$$C_{\mathrm{orifice}} = \frac{A}{4} \langle v \rangle = A \sqrt{\frac{k_B T}{2\pi m}}$$

For air at 300 K this gives $C_{\mathrm{orifice}} \approx 11.6 A$ L/s with $A$ in cm$^2$. This is the upper limit on conductance through any opening.

### When to use

- Sizing the pumping line between a turbo pump and a chamber.
- Estimating crossover from molecular to viscous flow during pump-down (the regime changes mid-process).
- Diagnosing why a load-lock or differential-pumping aperture has a particular ultimate pressure ratio.

### References

- O'Hanlon (2003), Ch. 3.
- Lewin, G. *Fundamentals of Vacuum Science and Technology*, McGraw-Hill, 1965.

---

## Pump-Down Time

### Theory

Treating a chamber of constant volume $V$ as well-mixed, the rate equation for pressure is:

$$V \frac{dP}{dt} = -S P + Q_{\mathrm{out}}$$

where $S$ is the effective pump speed and $Q_{\mathrm{out}}$ is the outgassing throughput from chamber walls. In the **ideal case** ($Q_{\mathrm{out}} = 0$, constant $S$) the solution is exponential:

$$P(t) = P_0 \exp(-t/\tau), \qquad \tau = V/S$$

so the time to pump from $P_0$ to $P_f$ is:

$$\boxed{t = \frac{V}{S} \ln\!\left(\frac{P_0}{P_f}\right)}$$

This is implemented in `calc.vacuum.pumpDownTime` with $V$ in liters and $S$ in L/s.

**Ultimate pressure.** Real chambers reach a steady state set by the balance of outgassing and pumping:

$$P_{\mathrm{ult}} = \frac{Q_{\mathrm{out}}}{S}$$

Outgassing rates for unbaked stainless steel are typically $10^{-8}$–$10^{-9}$ Torr·L/s/cm$^2$ and drop by 2–3 orders of magnitude after a 200 °C bake. This is why HV chambers reach $\sim 10^{-7}$ Torr in minutes but UHV requires hours of bake plus days of conditioning.

### Worked example

A 100 L chamber pumped by a 500 L/s turbo from atmosphere ($P_0 = 10^5$ Pa) to $P_f = 10^{-4}$ Pa, ignoring outgassing:

$$t = \frac{100}{500}\,\ln\!\left(\frac{10^5}{10^{-4}}\right) = 0.2 \times 20.7 \approx 4\;\text{s}$$

In practice this takes minutes because (i) the turbo's effective speed is much lower at high pressure (most turbos require backing < 1 mbar before they help), (ii) outgassing dominates below $10^{-4}$ Torr, and (iii) conductance to the pump throat reduces $S_{\mathrm{eff}}$. The $V/S \ln(P_0/P_f)$ formula gives a *lower bound* and is most accurate in the middle decades.

### When to use

- Estimating cycle time for a load-lock or process chamber.
- Sizing pumps for a target turn-around time and base pressure.
- Identifying outgassing-limited vs pump-speed-limited operation by comparing predicted to observed pump-down curves.

### References

- O'Hanlon (2003), Ch. 6.
- Jousten, K. (ed.) *Handbook of Vacuum Technology*, Wiley-VCH, 2008.

---

## Sputter Yield

### Theory

When energetic ions (typically Ar$^+$ at 100–1000 eV) bombard a target, they transfer momentum to surface atoms and eject some of them. The **sputter yield** $Y$ is defined as atoms ejected per incident ion. Sigmund's linear-cascade theory (1969) gives the yield in the regime where the cascade is well-developed but heat-spike effects are negligible:

$$Y(E) = \frac{3 \alpha}{4\pi^2}\,\frac{4 M_1 M_2}{(M_1 + M_2)^2}\,\frac{E}{U_s}$$

where $E$ is the ion energy, $M_1$ and $M_2$ are ion and target masses, $U_s$ is the surface binding energy of the target ($\sim$ heat of sublimation), and $\alpha$ is a dimensionless function of $M_2/M_1$ that ranges from $\sim 0.2$ (light ion on heavy target) to $\sim 1.5$ (mass-matched). Above a threshold of a few times $U_s$, the linear-with-energy regime persists until $E \gtrsim 10$ keV, where electronic stopping begins to compete.

A practical empirical fit (Yamamura & Tawara, 1996) is:

$$Y(E) = K\,s_n(\epsilon)\,\frac{1}{1 + \Gamma k_e \epsilon^{0.3}}\left[1 - \sqrt{\frac{E_{\mathrm{th}}}{E}}\right]^{2.8}$$

where $\epsilon$ is the reduced energy, $s_n$ the reduced nuclear stopping, and $E_{\mathrm{th}}$ the threshold energy (a few eV to tens of eV). `calc.vacuum.sputterYield` does not compute this expression analytically; it returns tabulated values from Yamamura & Tawara (1996) at 200, 500, 1000, and 5000 eV for Ar$^+$ on common materials, with linear interpolation between table points.

### Representative values (Ar$^+$, atoms/ion)

| Material | 200 eV | 500 eV | 1000 eV | 5000 eV |
|----------|--------|--------|---------|---------|
| Si | 0.4 | 0.9 | 1.2 | 1.4 |
| Cu | 1.5 | 3.0 | 4.0 | 4.5 |
| Au | 1.5 | 3.2 | 4.4 | 5.0 |
| W | 0.3 | 0.7 | 1.0 | 1.3 |
| Ag | 1.8 | 3.5 | 4.8 | 5.5 |

Heavy, weakly bound metals (Cu, Au, Ag) sputter several times faster than refractory metals (W, Ti, Ta) and covalent semiconductors (Si). This determines deposition rate at fixed ion current.

### When to use

- Estimating sputter deposition rate (combined with `sputterRate`).
- Predicting ion-mill etch rates for sample preparation.
- Choosing a target for a desired growth rate at a given power.

### References

- Sigmund, P. "Theory of Sputtering. I. Sputtering Yield of Amorphous and Polycrystalline Targets," *Phys. Rev.* **184**, 383 (1969).
- Yamamura, Y. & Tawara, H. "Energy Dependence of Ion-Induced Sputtering Yields from Monatomic Solids at Normal Incidence," *At. Data Nucl. Data Tables* **62**, 149 (1996).
- Behrisch, R. & Eckstein, W. (eds.) *Sputtering by Particle Bombardment*, Springer, 2007.

---

# Part II — Thin-Film Growth

## Deposition Rate from Thickness and Time

### Theory

The simplest characterization of any deposition process is the average **growth rate**:

$$r = \frac{t_f}{\Delta t}$$

with $t_f$ the deposited thickness and $\Delta t$ the deposition time. Reported in A/s or nm/min. `calc.thinFilm.depositionRate` returns both unit conventions:

$$r\;[\text{nm/min}] = r\;[\text{A/s}] \times 6$$

Calibrating $r$ against measured film thickness (from XRR Kiessig fringes, profilometry, or ellipsometry) is the foundation of process control. Once $r$ is known for a given source power and pressure, deposition time is the only parameter that needs to be set for a target thickness.

### When to use

- Calibrating a new target or evaporation source.
- Reporting growth conditions in a paper.
- Quick consistency check between QCM rate and post-growth thickness.

---

## Sputter Rate from Yield, Current, and Target Properties

### Theory

The **sputter deposition rate** at the substrate is determined by the ion flux at the target, the sputter yield, and the geometric throw. Considering only the target side (which sets an upper bound on the substrate rate):

1. Ion flux at the target: $\phi_{\mathrm{ion}} = J/e$ (ions/cm$^2$/s), with $J$ the current density and $e$ the elementary charge.
2. Atom flux from the target: $\phi_{\mathrm{atom}} = Y\,\phi_{\mathrm{ion}}$.
3. Volume removal rate: $\phi_{\mathrm{vol}} = Y\,\phi_{\mathrm{ion}} \cdot M / (\rho N_A)$ (cm/s), where $M$ is the molar mass and $\rho$ the bulk density of the target.

Combining:

$$\boxed{\dot{d}_{\mathrm{target}} = \frac{Y\,J\,M}{e\,\rho\,N_A}}$$

`calc.thinFilm.sputterRate` evaluates this with $J$ supplied in mA/cm$^2$ (converted internally to A/cm$^2$).

The substrate growth rate is lower by a geometric factor $\sim r_T^2/(r_T^2 + L^2)$ for a planar target-substrate pair (point-source approximation), times the sticking coefficient. For magnetron sputtering at typical geometries the substrate rate is 10–30% of the target erosion rate.

### Worked example

Au target ($\rho = 19.3$ g/cm$^3$, $M = 197$ g/mol), sputtered with 500 eV Ar$^+$ at $J = 1$ mA/cm$^2$. Looking up $Y_{\mathrm{Au}}(500\;\mathrm{eV}) = 3.2$:

$$\dot{d} = \frac{3.2 \cdot (1 \times 10^{-3}) \cdot 197}{(1.602 \times 10^{-19})(19.3)(6.022 \times 10^{23})} \approx 3.4 \times 10^{-7}\;\text{cm/s} \approx 3.4\;\text{nm/s}$$

at the target. Substrate rates are typically 0.5–1 nm/s under these conditions, consistent with measured Au sputter deposition.

### When to use

- Predicting deposition rate from first principles before running a calibration.
- Designing magnetron operating points for a target rate.
- Understanding why higher-yield targets (Cu, Ag) need lower power than refractory metals.

### References

- Smith (1995), Ch. 9.
- Wasa, K., Kitabatake, M. & Adachi, H. *Thin Film Materials Technology: Sputtering of Compound Materials*, Springer, 2004.

---

## Ion Implantation: Projected Range and Dose

### Theory: Lindhard-Scharff-Schiott (LSS) range

Energetic ions implanted into a solid lose energy through two competing channels:

1. **Nuclear stopping** $S_n(E)$: elastic momentum transfer to target atoms. Dominates at low energies (< few keV/amu).
2. **Electronic stopping** $S_e(E) \propto \sqrt{E}$: inelastic excitation of target electrons. Dominates at high energies.

The **projected range** is the average penetration depth along the original beam direction:

$$R_p = \int_0^{E_0} \frac{dE}{n\,[S_n(E) + S_e(E)]}$$

where $n$ is the target atomic number density. LSS theory provides analytic expressions for $S_n$ and $S_e$ in terms of a dimensionless reduced energy $\epsilon$ and the Thomas-Fermi screening length $a = 0.4685\,\mathrm{A}/\sqrt{Z_1^{2/3} + Z_2^{2/3}}$. `calc.thinFilm.projectedRange` implements the Ziegler-Biersack-Littmark (ZBL) form of $S_n$ together with the LSS velocity-proportional $S_e$, accurate to $\pm 20$–$30\%$. For higher precision, use SRIM/TRIM.

The **range straggle** (standard deviation of the depth distribution) follows the Lindhard approximation:

$$\Delta R_p \approx 0.4\,R_p\,\frac{\sqrt{M_1 M_2}}{M_1 + M_2}$$

For light ions in heavy targets (B in Si, $M_1/M_2 \approx 0.4$), $\Delta R_p / R_p \approx 0.2$; for mass-matched cases (Si in Si) it approaches 0.2 also.

### Theory: dose from beam current

The **dose** (or fluence) is the total number of ions per unit area:

$$\boxed{\Phi = \frac{I\,t}{q\,A}}$$

with $I$ the beam current, $t$ the implantation time, $q = e$ for singly-charged ions, and $A$ the implanted area. `calc.thinFilm.doseFromCurrent` evaluates this directly.

### Theory: peak concentration

Assuming a Gaussian depth profile centered at $R_p$ with standard deviation $\Delta R_p$, the depth-dependent concentration is:

$$C(z) = \frac{\Phi}{\sqrt{2\pi}\,\Delta R_p}\,\exp\!\left(-\frac{(z - R_p)^2}{2 \Delta R_p^2}\right)$$

so the **peak concentration** at $z = R_p$ is:

$$\boxed{C_{\mathrm{peak}} = \frac{\Phi}{\sqrt{2\pi}\,\Delta R_p}}$$

### Worked example: B in Si

30 keV B$^+$ into Si. From `projectedRange('B', 'Si', 30)`: $R_p \approx 100$ nm, $\Delta R_p \approx 30$ nm. Implanting at $\Phi = 10^{15}$ cm$^{-2}$:

$$C_{\mathrm{peak}} = \frac{10^{15}}{\sqrt{2\pi}\,(3 \times 10^{-6}\;\text{cm})} \approx 1.3 \times 10^{20}\;\text{cm}^{-3}$$

This is at the solid-solubility limit of B in Si and would require a flash anneal to activate.

### When to use

- Quick estimate of implant depth before running SRIM.
- Calculating expected peak doping concentration from ion-source current readouts.
- Dose calibration for sample preparation (e.g., ion damage cascades for transmission-electron-microscopy thinning).

### References

- Lindhard, J., Scharff, M. & Schiott, H. E. "Range Concepts and Heavy Ion Ranges," *K. Dan. Vidensk. Selsk. Mat.-Fys. Medd.* **33**, no. 14 (1963).
- Ziegler, J. F., Biersack, J. P. & Littmark, U. *The Stopping and Range of Ions in Solids*, Pergamon, 1985.
- Smith (1995), Ch. 11.

---

## Thermal Diffusion Length

### Theory

A species diffusing in a solid with constant diffusivity $D$ for time $t$ spreads over a characteristic length given by the second moment of the diffusion solution:

$$L = \sqrt{D t}$$

This is the **diffusion length** as implemented in `calc.thinFilm.diffusionLength_thermal`. Some references use $L = 2\sqrt{Dt}$, which is the distance at which the impurity concentration drops to $1/e$ of the surface value for a semi-infinite half-plane source. The two conventions differ by a factor of 2; the toolbox uses the $\sqrt{Dt}$ form (the rms displacement) to match standard textbook treatments of dopant diffusion.

The diffusivity itself follows an Arrhenius form:

$$D(T) = D_0\,\exp\!\left(-\frac{E_a}{k_B T}\right)$$

with $D_0$ the prefactor and $E_a$ the activation energy. Both depend on the diffusing species and host crystal.

### Worked example: B in Si

Boron in Si has $D_0 \approx 0.76$ cm$^2$/s and $E_a \approx 3.46$ eV (substitutional diffusion). At $T = 1000$ °C $= 1273$ K, $k_B T \approx 0.110$ eV, so:

$$D(1273) \approx 0.76 \cdot \exp(-3.46/0.110) \approx 0.76 \cdot e^{-31.5} \approx 1.7 \times 10^{-14}\;\text{cm}^2/\text{s}$$

For a 1-hour anneal:

$$L = \sqrt{(1.7 \times 10^{-14})(3600)} \approx 2.5 \times 10^{-6}\;\text{cm} = 25\;\text{nm}$$

This sets the spatial resolution of any planar device fabricated by ion implantation followed by drive-in: feature sizes much smaller than $L$ will smear out during anneal.

### When to use

- Designing anneal recipes for ion-implanted dopants.
- Estimating interdiffusion in heterostructures during high-temperature processing.
- Computing the depletion-layer broadening in thermal-oxide growth.

### References

- Tu, K. N., Mayer, J. W. & Feldman, L. C. *Electronic Thin Film Science: For Electrical Engineers and Materials Scientists*, Macmillan, 1992.
- Crank, J. *The Mathematics of Diffusion*, 2nd ed., Oxford, 1975.

---

## Stoney Stress Equation

### Theory

A film deposited on a thin substrate often grows with intrinsic stress. By force balance, this stress must be compensated by an opposing curvature in the substrate; the substrate bends, with a measurable radius of curvature $R$. The **Stoney equation** relates the biaxial film stress $\sigma_f$ to this curvature:

$$\boxed{\sigma_f = \frac{E_s\,t_s^2}{6\,(1 - \nu_s)\,t_f\,R}}$$

where $E_s$ and $\nu_s$ are the substrate Young's modulus and Poisson ratio, $t_s$ is the substrate thickness, $t_f$ is the film thickness, and $R$ is the substrate radius of curvature. The factor $E_s/(1-\nu_s)$ is the substrate **biaxial modulus**.

**Sign convention.** Positive $R$ (concave up, viewed from the film side) corresponds to **tensile** film stress; negative $R$ to **compressive**. `calc.thinFilm.stoneyStress` reports stress in Pa/MPa/GPa.

### Derivation sketch

Consider a substrate of thickness $t_s$ much larger than the film thickness $t_f$. The film exerts a force per unit width $F = \sigma_f t_f$ on the substrate top surface. By beam bending, a force at distance $t_s/2$ from the substrate neutral axis produces a moment $M = F\,t_s/2$. The curvature induced is

$$\frac{1}{R} = \frac{M}{D},\qquad D = \frac{E_s t_s^3}{12(1 - \nu_s^2)}$$

(plate-bending stiffness, biaxial). Combining and noting that for biaxial loading the relevant prefactor reduces to $E_s/[6(1-\nu_s)]$ rather than $E_s/[12(1-\nu_s^2)]$ gives Stoney's result.

### Validity

The Stoney equation is exact in the limit:

- $t_f \ll t_s$ (so the film does not contribute to bending stiffness)
- The film is uniform, biaxial, and elastic
- Substrate is a thin plate (not a thick block)
- Curvature is small ($R \gg t_s$)

For typical 100-nm films on 500-µm Si wafers, $t_f/t_s \sim 2 \times 10^{-4}$ and Stoney is accurate to better than 0.1%. For thicker films ($t_f/t_s > 0.01$), the Brenner-Senderoff or Hsueh formulas apply.

### Worked example

A 100 nm film on a 500 µm Si substrate ($E_s = 130$ GPa, $\nu_s = 0.28$) bends with $R = 10$ m:

$$\sigma_f = \frac{(1.3 \times 10^{11})(5 \times 10^{-4})^2}{6\,(1 - 0.28)(10^{-7})(10)} = \frac{32.5}{4.32 \times 10^{-6}} \approx 7.5\;\text{GPa}$$

Tensile, since $R$ is positive. This is large but achievable for a refractory film on a polished Si wafer; many sputter-deposited TiN or Mo films land here.

### When to use

- Wafer-curvature stress measurement (multi-beam optical sensors, profilometry).
- Cross-checking XRD-strain measurements with mechanical-curvature data.
- Assessing whether a stack will cause substrate bow problems in lithography.

### References

- Stoney, G. G. "The Tension of Metallic Films Deposited by Electrolysis," *Proc. R. Soc. Lond. A* **82**, 172 (1909).
- Freund, L. B. & Suresh, S. *Thin Film Materials*, Cambridge, 2003, Ch. 2.

---

## Thermal Mismatch Strain

### Theory

When a film is deposited on a substrate at deposition temperature $T_d$ and cooled to room temperature $T_r$, any difference between the linear coefficients of thermal expansion (CTE) generates a thermal-mismatch strain:

$$\boxed{\varepsilon = (\alpha_f - \alpha_s)\,\Delta T,\qquad \Delta T = T_r - T_d}$$

If $\alpha_f > \alpha_s$ and $\Delta T < 0$ (cooling), then $\varepsilon < 0$ (compressive). The corresponding biaxial stress, given the film biaxial modulus $E_f/(1 - \nu_f)$:

$$\sigma = \frac{E_f}{1 - \nu_f}\,\varepsilon$$

`calc.thinFilm.thermalMismatchStrain` returns the strain and, optionally, the stress when $E_f$ is supplied.

### When thermal mismatch dominates

Total film stress has two main contributions: **intrinsic** (microstructure, density, point defects) and **thermal**. Thermal dominates when:

- Deposition temperature is high (sputter at $T_d \sim 600$ °C or epitaxy at $T_d \sim 800$ °C)
- The CTE mismatch is large (e.g., metal on Si, $\Delta\alpha \sim 14 \times 10^{-6}$ /K)
- The film microstructure is dense/relaxed (no significant intrinsic stress)

For low-temperature evaporation ($T_d \approx T_r$) or sputter at room temperature, intrinsic stress dominates and thermal mismatch is negligible.

### Worked example

An Al film ($\alpha_f = 23 \times 10^{-6}$ /K) deposited on Si ($\alpha_s = 3 \times 10^{-6}$ /K) at $T_d = 400$ °C, cooled to room temperature ($\Delta T = -380$ K):

$$\varepsilon = (23 - 3) \times 10^{-6} \times (-380) = -7.6 \times 10^{-3}$$

i.e., 0.76% compressive. With $E_{\mathrm{Al}} \approx 70$ GPa, $\nu_f = 0.34$:

$$\sigma = \frac{70 \times 10^9}{0.66}\,(-7.6 \times 10^{-3}) \approx -800\;\text{MPa}$$

This is large enough to cause hillock formation or buckling in Al interconnects, a well-known failure mode in earlier-generation IC fabrication.

### When to use

- Predicting whether a film stack will crack on cooling from deposition temperature.
- Choosing deposition temperature to minimize residual stress.
- Decomposing measured Stoney stress into thermal and intrinsic contributions.

### References

- Freund & Suresh (2003), Ch. 2.
- Doerner, M. F. & Nix, W. D. "Stresses and Deformation Processes in Thin Films on Substrates," *CRC Crit. Rev. Solid State Mater. Sci.* **14**, 225 (1988).

---

## Multilayer Effective Thermal Conductivity

### Theory

Consider a stack of $N$ layers with thicknesses $d_i$ and bulk conductivities $\kappa_i$. The effective conductivity depends on whether heat flows perpendicular to the layers (cross-plane) or parallel to them (in-plane).

**Series (cross-plane).** Each layer is a thermal resistor in series:

$$R_{\mathrm{tot}} = \sum_i \frac{d_i}{\kappa_i}, \qquad \kappa_{\mathrm{eff}}^{\perp} = \frac{\sum_i d_i}{\sum_i d_i/\kappa_i}$$

**Parallel (in-plane).** Layers act as conductors in parallel:

$$\kappa_{\mathrm{eff}}^{\parallel} = \frac{\sum_i \kappa_i d_i}{\sum_i d_i}$$

The in-plane conductivity is always $\geq$ the cross-plane (a consequence of the AM-GM-HM inequality applied to thermal resistances). `calc.thinFilm.multilayerThermalConductivity` returns both.

### Interface conductance

The above formulas neglect **thermal boundary resistance** (Kapitza resistance) at each interface. For phonon-dominated heat transport, each interface adds $1/G_K$ to the thermal resistance, with $G_K \sim 10^7$–$10^9$ W/m$^2$/K. For thin layers (a few nm), interface resistances dominate over bulk resistance:

$$R_{\mathrm{tot}}^{\perp} = \sum_i \frac{d_i}{\kappa_i} + \sum_j \frac{1}{G_{K,j}}$$

This is why superlattices have effective thermal conductivities far below either constituent: every interface adds resistance with no compensating thickness reduction.

### When to use

- Estimating effective $\kappa$ for thermal-management design.
- Predicting temperature drop across a multilayer film during operation (e.g., laser diode active region).
- Designing thermoelectric superlattices (low cross-plane $\kappa$, high in-plane $\sigma$).

### References

- Cahill, D. G. et al. "Nanoscale thermal transport," *J. Appl. Phys.* **93**, 793 (2003).
- Swartz, E. T. & Pohl, R. O. "Thermal boundary resistance," *Rev. Mod. Phys.* **61**, 605 (1989).

---

## Kiessig Fringe Thickness

### Theory

A coherent X-ray or neutron beam reflected from a thin film of thickness $t$ produces interference fringes between the rays reflected at the top (air/film) and bottom (film/substrate) interfaces. Constructive interference at angle $\theta$ corresponds to an optical path difference equal to an integer number of wavelengths. In the kinematic (Born) approximation, neglecting refraction inside the film:

$$\frac{2 t \sin\theta_m}{\lambda} = m + \text{const}$$

so the fringe spacing in $Q = 4\pi\sin\theta/\lambda$ is

$$\Delta Q = \frac{2\pi}{t}, \qquad \boxed{t = \frac{2\pi}{\Delta Q}}$$

This is the simplest Kiessig formula. It links directly to Bragg's law (see [xrd.md](xrd.md)): for first-order diffraction $Q = 2\pi/d$, so the fringe period is the reciprocal-space "Bragg condition" of the film.

### Refraction correction

At grazing angles near the **critical edge** $Q_c = 4\sqrt{\pi\,\mathrm{SLD}}$ (see [reflectometry.md](reflectometry.md) for the SLD definition), the beam refracts into the denser film and the in-air fringe spacing is compressed relative to the in-film optical path. The corrected formula uses the refracted vertical momentum component:

$$t = \frac{2\pi}{\sqrt{\Delta Q^2 - 4 Q_c^2}}$$

`calc.thinFilm.kiessigThickness` accepts either an explicit $Q_c$ or a film SLD, computes the correction, and falls back to the kinematic value when $\Delta Q < 2 Q_c$ (where the correction would diverge). For dense films (Pt, W, Au), the correction is 10–20% near the critical edge; for low-density films and at $\Delta Q \gg Q_c$, the two formulas agree to within 1%.

### Worked example

A Kiessig fringe spacing of $\Delta Q = 0.0628$ A$^{-1}$ in an X-ray reflectivity scan corresponds to:

$$t = \frac{2\pi}{0.0628} \approx 100\;\text{A} = 10\;\text{nm}$$

If the film is platinum (SLD $\approx 6.3 \times 10^{-6}$ A$^{-2}$), $Q_c = 4\sqrt{\pi \cdot 6.3 \times 10^{-6}} \approx 0.018$ A$^{-1}$. The refraction correction is $\sim 1\%$ at this $\Delta Q$, but a 5-nm Pt film with $\Delta Q = 0.025$ A$^{-1}$ would see a 30% correction.

### When to use

- Quick thickness estimate from XRR data without running a full Parratt fit.
- Cross-check on full-fit thicknesses.
- Initial guess for `+fitting/reflFitting` parameters — see [reflectometry.md](reflectometry.md).

### References

- Kiessig, H. "Untersuchungen zur Totalreflexion von Rontgenstrahlen," *Ann. Phys. (Leipzig)* **402**, 715 (1931).
- Tolan, M. *X-Ray Scattering from Soft-Matter Thin Films*, Springer, 1999, Ch. 3.3.
- Als-Nielsen, J. & McMorrow, D. *Elements of Modern X-ray Physics*, 2nd ed., Wiley, 2011, Ch. 3.

---

# Part III — Optics and Fresnel Coefficients

The Fresnel coefficients describe what happens when light meets a flat interface between two media. They are the building blocks of every multilayer optical calculation, including the Parratt recursion in [reflectometry.md](reflectometry.md). All formulas below allow complex refractive indices, $\tilde{n} = n + i\kappa$, so that absorbing media (metals at visible frequencies, X-ray-illuminated solids near absorption edges) are handled uniformly with transparent dielectrics.

## Fresnel Coefficients

### Theory

Consider a plane wave incident from medium 1 (refractive index $\tilde{n}_1$) onto a flat interface with medium 2 ($\tilde{n}_2$) at angle $\theta_i$ measured from the surface **normal**. Snell's law (generalized to complex indices via the principal square root):

$$\tilde{n}_1 \sin\theta_i = \tilde{n}_2 \sin\theta_t, \qquad \cos\theta_t = \sqrt{1 - (\tilde{n}_1/\tilde{n}_2)^2 \sin^2\theta_i}$$

Matching the tangential components of $\mathbf{E}$ and $\mathbf{H}$ across the interface gives the **amplitude reflection** and **transmission** coefficients for the two linear polarizations:

**s-polarization** (electric field perpendicular to the plane of incidence):

$$r_s = \frac{\tilde{n}_1 \cos\theta_i - \tilde{n}_2 \cos\theta_t}{\tilde{n}_1 \cos\theta_i + \tilde{n}_2 \cos\theta_t}, \qquad t_s = \frac{2\,\tilde{n}_1 \cos\theta_i}{\tilde{n}_1 \cos\theta_i + \tilde{n}_2 \cos\theta_t}$$

**p-polarization** (electric field in the plane of incidence):

$$r_p = \frac{\tilde{n}_2 \cos\theta_i - \tilde{n}_1 \cos\theta_t}{\tilde{n}_2 \cos\theta_i + \tilde{n}_1 \cos\theta_t}, \qquad t_p = \frac{2\,\tilde{n}_1 \cos\theta_i}{\tilde{n}_2 \cos\theta_i + \tilde{n}_1 \cos\theta_t}$$

The reflectances (energy fractions) follow from the squared moduli:

$$R_s = |r_s|^2, \qquad R_p = |r_p|^2$$

The transmittances must include the obliquity factor that accounts for beam-area projection and the medium impedance:

$$T_s = \frac{\mathrm{Re}(\tilde{n}_2 \cos^*\theta_t)}{\mathrm{Re}(\tilde{n}_1 \cos^*\theta_i)}\,|t_s|^2, \qquad T_p = \frac{\mathrm{Re}(\tilde{n}_2 \cos^*\theta_t)}{\mathrm{Re}(\tilde{n}_1 \cos^*\theta_i)}\,|t_p|^2$$

For lossless media ($\kappa = 0$), $R + T = 1$ exactly. For absorbing media, $R + T < 1$ and the difference equals the absorbed fraction.

### Sign conventions

The toolbox uses the convention $r_s$ as written above. Some textbooks (Hecht; older Born & Wolf editions) define $r_p$ with the opposite sign, which corresponds to choosing the reflected $H$-field rather than $E$-field as the reference. Both conventions give identical $R_p = |r_p|^2$, but matter when computing ellipsometric ratios $\rho = r_p/r_s$. When in doubt, verify that $r_p \to 0$ at Brewster's angle and $r_p \to -1$ at grazing.

### Worked example

Air ($n_1 = 1$) on glass ($n_2 = 1.5$) at $\theta_i = 0$ (normal incidence): $r_s = r_p = (1 - 1.5)/(1 + 1.5) = -0.2$, so $R_s = R_p = 0.04$, the familiar 4% loss per glass surface. At $\theta_i = 56.3°$ (Brewster, see below), $r_p = 0$ and $r_s = -0.385$, $R_s \approx 0.148$.

For air/gold at 532 nm with $\tilde{n}_2 = 0.5 + 2.4i$ and $\theta_i = 0$:

$$r = \frac{1 - (0.5 + 2.4i)}{1 + (0.5 + 2.4i)} = \frac{0.5 - 2.4i}{1.5 + 2.4i}$$

giving $|r|^2 \approx 0.74$ — gold's familiar high reflectance in the visible.

### When to use

- Single-interface reflectance/transmittance calculations.
- Sign and magnitude of $r_s, r_p$ as inputs to ellipsometry models.
- Building blocks for the multilayer Parratt recursion (see [reflectometry.md](reflectometry.md)).

### References

- Born, M. & Wolf, E. *Principles of Optics*, 7th (expanded) ed., Cambridge, 1999, Ch. 1.5.
- Hecht, E. *Optics*, 5th ed., Pearson, 2017, Ch. 4.
- Macleod, H. A. *Thin-Film Optical Filters*, 4th ed., CRC, 2010.

---

## Brewster's Angle

### Theory

For real (lossless) media, the p-polarization reflectance vanishes at a particular angle of incidence, **Brewster's angle**:

$$\boxed{\tan\theta_B = \frac{n_2}{n_1}}$$

### Derivation

Setting $r_p = 0$ in the Fresnel formula:

$$\tilde{n}_2 \cos\theta_i = \tilde{n}_1 \cos\theta_t$$

Combined with Snell's law $\tilde{n}_1 \sin\theta_i = \tilde{n}_2 \sin\theta_t$, the two conditions imply $\theta_i + \theta_t = \pi/2$ (the reflected and transmitted rays are perpendicular). Substituting back gives $\tan\theta_B = n_2/n_1$.

Physically: at Brewster's angle, the dipoles induced in medium 2 oscillate along the would-be reflection direction, and a dipole cannot radiate along its own axis. So no p-polarized reflection.

For absorbing media (complex $\tilde{n}_2$), $r_p$ does not vanish exactly but reaches a minimum near a "pseudo-Brewster" angle; the toolbox formula $\tan\theta_B = n_2/n_1$ uses real parts only and is approximate for metals.

### Worked example

| Interface | $n_1$ | $n_2$ | $\theta_B$ |
|-----------|-------|-------|------------|
| Air / glass | 1.0 | 1.5 | 56.31° |
| Glass / air | 1.5 | 1.0 | 33.69° |
| Air / water | 1.0 | 1.33 | 53.06° |
| Air / diamond | 1.0 | 2.42 | 67.51° |

Note that air-glass and glass-air Brewster angles sum to 90°, consistent with $\theta_B + \theta_t = 90°$.

### When to use

- Designing low-reflectance windows for laser cavities (Brewster windows).
- Polarizing prisms and film polarizers.
- Diagnostic check on ellipsometric measurements: a sweep of $R_p(\theta)$ should show a clean minimum at $\theta_B$ for transparent samples.

### References

- Born & Wolf (1999), Ch. 1.5.3.

---

## Critical Angle and Total Internal Reflection

### Theory

When light passes from a denser medium to a rarer one ($n_1 > n_2$), Snell's law $\sin\theta_t = (n_1/n_2)\sin\theta_i$ has no real solution above a critical angle:

$$\boxed{\sin\theta_c = \frac{n_2}{n_1}, \qquad \theta_c = \arcsin\!\left(\frac{n_2}{n_1}\right)}$$

For $\theta_i > \theta_c$, $\cos\theta_t$ is purely imaginary, the transmitted wave becomes **evanescent** (decaying exponentially into medium 2), and $|r_s| = |r_p| = 1$: total internal reflection (TIR).

### Evanescent decay length

Above $\theta_c$, the field in medium 2 decays as $E_2(z) \propto e^{-z/\xi}$ with characteristic length:

$$\xi = \frac{\lambda}{2\pi\sqrt{n_1^2 \sin^2\theta_i - n_2^2}}$$

Just above $\theta_c$, $\xi$ diverges; well above $\theta_c$, $\xi \sim \lambda/(2\pi)$ — about a wavelength. This sets the depth probed by total-internal-reflection fluorescence (TIRF) microscopy and attenuated-total-reflection (ATR) spectroscopy.

### Worked example

| Interface | $\theta_c$ | Application |
|-----------|------------|-------------|
| Glass ($n=1.5$) / air | 41.8° | Optical fibers (acceptance cone) |
| Water ($n=1.33$) / air | 48.6° | Underwater "Snell's window" |
| Diamond ($n=2.42$) / air | 24.4° | Diamond brilliance |
| Si ($n=3.5$) / SiO$_2$ ($n=1.46$) | 24.7° | Si waveguides |

`calc.optics.criticalAngle` returns NaN when $n_2 \geq n_1$ rather than throwing — TIR is impossible in that direction.

### When to use

- Designing waveguides and optical fibers (TIR confines light).
- ATR spectroscopy: probing surface chemistry within $\xi$ of an interface.
- Identifying the loss mechanism in a thin-film waveguide structure.
- For X-rays, the same physics applies but $n < 1$ for X-rays in solids, so TIR happens at the air-solid interface at grazing incidence (the critical angle for reflectometry, see [reflectometry.md](reflectometry.md)).

### References

- Born & Wolf (1999), Ch. 1.5.4.
- Hecht (2017), Ch. 4.7.

---

## Refractive Index ↔ Dielectric Function

### Theory

The optical response of a non-magnetic medium is fully described by either the complex refractive index $\tilde{n} = n + i\kappa$ or the complex dielectric function $\tilde{\varepsilon} = \varepsilon_1 + i\varepsilon_2$. The two are related by

$$\boxed{\tilde{\varepsilon} = \tilde{n}^2}$$

Expanding:

$$\varepsilon_1 = n^2 - \kappa^2, \qquad \varepsilon_2 = 2 n \kappa$$

The inverse, taking the **physical square root** (positive $n$ and $\kappa \geq 0$):

$$n = \sqrt{\frac{|\tilde{\varepsilon}| + \varepsilon_1}{2}}, \qquad \kappa = \sqrt{\frac{|\tilde{\varepsilon}| - \varepsilon_1}{2}}, \qquad |\tilde{\varepsilon}| = \sqrt{\varepsilon_1^2 + \varepsilon_2^2}$$

`calc.optics.refractiveToDielectric` and `calc.optics.dielectricToRefractive` handle both directions; the latter chooses the physical branch automatically.

### Branch choice and metals

For a metal at frequencies below the plasma frequency, $\varepsilon_1 < 0$ and (often) $\varepsilon_2$ small. The square-root prescription gives $n \to 0$ (small) and $\kappa \to \sqrt{|\varepsilon_1|}$ (large), correctly reproducing high-reflectance metallic optics.

| Material | $\lambda$ | $n$ | $\kappa$ | $\varepsilon_1$ | $\varepsilon_2$ |
|----------|-----------|-----|----------|------------------|------------------|
| Si | 633 nm | 3.88 | 0.02 | 15.05 | 0.16 |
| Glass (BK7) | 633 nm | 1.515 | 0 | 2.295 | 0 |
| Au | 633 nm | 0.18 | 3.10 | -9.58 | 1.12 |
| Al | 633 nm | 1.36 | 7.62 | -56.2 | 20.7 |

### When to use

- Converting tabulated optical constants between databases that use different conventions.
- Building input for the Fresnel and Parratt routines (which expect $\tilde{n}$).
- Interpreting ellipsometric data fitted in $\varepsilon$-space.

### References

- Born & Wolf (1999), Ch. 14.
- Palik, E. D. *Handbook of Optical Constants of Solids*, Academic, 1985.

---

## Optical Penetration Depth

### Theory

In an absorbing medium, a plane wave decays as

$$E(z) = E_0\,e^{-z/\delta_E}, \qquad I(z) = |E(z)|^2 = I_0\,e^{-z/\delta}$$

The **intensity penetration depth** is

$$\boxed{\delta = \frac{\lambda}{4\pi\kappa}}$$

with $\lambda$ the vacuum wavelength and $\kappa$ the extinction coefficient. The corresponding absorption coefficient (intensity, Beer-Lambert form $I = I_0 e^{-\alpha z}$) is

$$\alpha = \frac{4\pi\kappa}{\lambda} = \frac{1}{\delta}$$

The **field amplitude** decay length is twice the intensity decay length, $\delta_E = 2\delta$.

### Factor-of-2 caveat

The literature has two competing conventions:

- **Intensity** $1/e$ depth: $\delta = \lambda/(4\pi\kappa)$. Used by `calc.optics.penetrationDepth`. This is the depth at which intensity drops to $1/e$.
- **Amplitude** $1/e$ depth: $\delta_E = \lambda/(2\pi\kappa)$. Twice as deep. Used by some condensed-matter texts, especially in plasmonics.

When comparing values across references, always check which convention is in force. The toolbox additionally returns an `.absLength` field equal to $1/(2\alpha) = \delta/2$, which corresponds to the depth at which intensity drops to $e^{-2}$ — useful for some photovoltaic literature conventions.

### Worked example

| Material | $\lambda$ | $\kappa$ | $\delta$ |
|----------|-----------|----------|----------|
| Si | 400 nm | 0.39 | 82 nm |
| Si | 800 nm | 0.011 | 5.8 µm |
| Si | 1.1 µm | $\sim 10^{-4}$ | 880 µm |
| Au | 532 nm | 2.9 | 14.6 nm |
| Pt | 8 keV (X-ray) | $\sim 10^{-7}$ | 1.2 µm |

The dramatic increase in $\delta$ for Si going from blue to near-IR is the basis of solar cell design: short wavelengths are absorbed in the top 100 nm (junction region), long wavelengths require the full wafer thickness.

### When to use

- Solar cell design (matching absorber thickness to $\delta$ across the solar spectrum).
- Selecting probe depth for ellipsometry, photoluminescence, and Raman.
- Sizing X-ray or VUV mirror multilayers (each layer should be $\sim \delta/4$ to act as a quarter-wave reflector).

### References

- Born & Wolf (1999), Ch. 14.
- Palik (1985).

---

## Skin Depth (Conductors)

### Theory

In a good conductor at frequency $\omega$, conduction current $\sigma E$ greatly exceeds displacement current $\omega\varepsilon_0 E$. Maxwell's equations then reduce to a diffusion equation for the field, with characteristic decay length:

$$\boxed{\delta = \sqrt{\frac{2\rho}{\omega\mu_0}} = \sqrt{\frac{2}{\sigma\mu_0\omega}}}$$

with $\rho = 1/\sigma$ the resistivity, $\mu_0 = 4\pi \times 10^{-7}$ H/m, and $\omega = 2\pi f$. `calc.optics.skinDepth` evaluates this for non-magnetic conductors (relative permeability $\mu_r = 1$); for magnetic materials, replace $\mu_0 \to \mu_r \mu_0$.

### Derivation

Take the curl of $\nabla \times \mathbf{H} = \mathbf{J} + \partial_t\mathbf{D}$ with $\mathbf{J} = \sigma\mathbf{E}$ and $\mathbf{D} = \varepsilon\mathbf{E}$. In the good-conductor limit ($\sigma \gg \omega\varepsilon$), $\nabla^2\mathbf{E} = \mu_0\sigma\,\partial_t\mathbf{E}$, a diffusion equation. A plane wave solution $\mathbf{E} \propto e^{i(kz - \omega t)}$ has $k^2 = i\mu_0\sigma\omega$, so $k = (1+i)/\delta$ with $\delta$ as above. The field decays as $e^{-z/\delta}$ and oscillates with wavelength $2\pi\delta$ inside the conductor.

### Validity

The good-conductor approximation requires $\sigma \gg \omega\varepsilon_0$, i.e., $f \ll \sigma/(2\pi\varepsilon_0)$. For copper ($\sigma = 5.96 \times 10^7$ S/m), this gives $f \ll 10^{18}$ Hz, so the formula is valid through the entire UV. At optical frequencies for noble metals, the displacement current and the bound-electron contributions matter, and one must instead use the full complex $\tilde{\varepsilon}(\omega)$ from a Drude-Lorentz model and compute $\delta$ via $\kappa$ as in the previous section.

### Worked example

| Material | Frequency | $\delta$ |
|----------|-----------|----------|
| Cu, $\rho = 1.68 \times 10^{-8}$ Ω·m | 50 Hz (mains) | 9.3 mm |
| Cu | 1 MHz (RF) | 66 µm |
| Cu | 1 GHz (microwave) | 2.1 µm |
| Cu | 1 THz | 66 nm |
| Au, $\rho = 2.44 \times 10^{-8}$ Ω·m | 1 GHz | 2.5 µm |

This rapid drop-off is why high-frequency conductors are silver-plated (only the surface skin carries current) and why microwave waveguides have polished interior walls.

### When to use

- RF and microwave engineering (sizing conductor thickness; power dissipation).
- Electromagnetic shielding (target $\delta \ll$ shield thickness).
- Eddy-current sensors and induction heating.
- Predicting the AC resistance of magnet coils and superconducting wires.

### References

- Jackson, J. D. *Classical Electrodynamics*, 3rd ed., Wiley, 1999, Ch. 8.1.
- Pozar, D. M. *Microwave Engineering*, 4th ed., Wiley, 2011, Ch. 1.7.

---

# Implementation Summary

| Function | Module | One-line description | Governing equation |
|----------|--------|---------------------|--------------------|
| `depositionRate` | `+thinFilm` | Growth rate from thickness/time | $r = t_f/\Delta t$ |
| `sputterRate` | `+thinFilm` | Erosion rate from $Y$, $J$, target $\rho$, $M$ | $\dot{d} = Y J M / (e \rho N_A)$ |
| `kiessigThickness` | `+thinFilm` | Film thickness from XRR fringe spacing | $t = 2\pi/\sqrt{\Delta Q^2 - 4Q_c^2}$ |
| `stoneyStress` | `+thinFilm` | Biaxial film stress from substrate curvature | $\sigma = E_s t_s^2/[6(1-\nu_s) t_f R]$ |
| `thermalMismatchStrain` | `+thinFilm` | Strain from CTE difference and $\Delta T$ | $\varepsilon = (\alpha_f - \alpha_s)\Delta T$ |
| `multilayerThermalConductivity` | `+thinFilm` | Series/parallel effective $\kappa$ | $\kappa^{\perp} = \sum d_i / \sum (d_i/\kappa_i)$ |
| `diffusionLength_thermal` | `+thinFilm` | Thermal diffusion length | $L = \sqrt{Dt}$ |
| `doseFromCurrent` | `+thinFilm` | Implant fluence from beam current | $\Phi = It/(qA)$ |
| `doseToConcentration` | `+thinFilm` | Peak implant concentration | $C_{\mathrm{peak}} = \Phi/(\sqrt{2\pi}\,\Delta R_p)$ |
| `projectedRange` | `+thinFilm` | LSS implant range and straggle | LSS/ZBL stopping integral |
| `meanFreePath` | `+vacuum` | Gas-kinetic mean free path | $\lambda = k_B T/(\sqrt{2}\pi d^2 P)$ |
| `monolayerTime` | `+vacuum` | Surface coverage time | $\tau_{\mathrm{ML}} = \sqrt{2\pi m k_B T}/(P A_{\mathrm{site}})$ |
| `knudsenNumber` | `+vacuum` | Flow regime classifier | $\mathrm{Kn} = \lambda/L$ |
| `gasFlow` | `+vacuum` | Pipe conductance and throughput | $C_{\mathrm{mol}} = (\pi d^3/12L)\sqrt{8 k_B T/\pi m}$ |
| `pumpDownTime` | `+vacuum` | Ideal exponential pump-down | $t = (V/S)\ln(P_0/P_f)$ |
| `sputterYield` | `+vacuum` | Tabulated yields (Yamamura-Tawara) | Lookup; Sigmund cascade theory |
| `fresnelCoefficients` | `+optics` | $r_s, r_p, t_s, t_p$ at an interface | Fresnel boundary-condition formulas |
| `brewsterAngle` | `+optics` | Angle of zero p-polarization reflection | $\tan\theta_B = n_2/n_1$ |
| `criticalAngle` | `+optics` | Angle of total internal reflection | $\sin\theta_c = n_2/n_1$ |
| `dielectricToRefractive` | `+optics` | $\tilde{\varepsilon} \to \tilde{n}$ (physical branch) | $n = \sqrt{(|\varepsilon|+\varepsilon_1)/2}$ |
| `refractiveToDielectric` | `+optics` | $\tilde{n} \to \tilde{\varepsilon}$ | $\varepsilon = (n+i\kappa)^2$ |
| `penetrationDepth` | `+optics` | Optical 1/e intensity depth | $\delta = \lambda/(4\pi\kappa)$ |
| `skinDepth` | `+optics` | EM skin depth in a good conductor | $\delta = \sqrt{2\rho/(\omega\mu_0)}$ |

---

# References

1. Als-Nielsen, J. & McMorrow, D. *Elements of Modern X-ray Physics*, 2nd ed., Wiley, 2011.
2. Behrisch, R. & Eckstein, W. (eds.) *Sputtering by Particle Bombardment*, Springer, 2007.
3. Born, M. & Wolf, E. *Principles of Optics*, 7th expanded ed., Cambridge University Press, 1999.
4. Cahill, D. G. et al. "Nanoscale thermal transport," *J. Appl. Phys.* **93**, 793 (2003).
5. Crank, J. *The Mathematics of Diffusion*, 2nd ed., Oxford, 1975.
6. Doerner, M. F. & Nix, W. D. "Stresses and Deformation Processes in Thin Films on Substrates," *CRC Crit. Rev. Solid State Mater. Sci.* **14**, 225 (1988).
7. Freund, L. B. & Suresh, S. *Thin Film Materials: Stress, Defect Formation and Surface Evolution*, Cambridge, 2003.
8. Hecht, E. *Optics*, 5th ed., Pearson, 2017.
9. Hudson, J. B. *Surface Science: An Introduction*, Wiley, 1998.
10. Jackson, J. D. *Classical Electrodynamics*, 3rd ed., Wiley, 1999.
11. Jousten, K. (ed.) *Handbook of Vacuum Technology*, Wiley-VCH, 2008.
12. Kiessig, H. "Untersuchungen zur Totalreflexion von Rontgenstrahlen," *Ann. Phys. (Leipzig)* **402**, 715 (1931).
13. Lindhard, J., Scharff, M. & Schiott, H. E. "Range Concepts and Heavy Ion Ranges," *K. Dan. Vidensk. Selsk. Mat.-Fys. Medd.* **33**, no. 14 (1963).
14. Macleod, H. A. *Thin-Film Optical Filters*, 4th ed., CRC Press, 2010.
15. O'Hanlon, J. F. *A User's Guide to Vacuum Technology*, 3rd ed., Wiley, 2003.
16. Palik, E. D. *Handbook of Optical Constants of Solids*, Academic Press, 1985.
17. Pozar, D. M. *Microwave Engineering*, 4th ed., Wiley, 2011.
18. Reif, F. *Fundamentals of Statistical and Thermal Physics*, McGraw-Hill, 1965.
19. Roth, A. *Vacuum Technology*, 3rd ed., North-Holland, 1990.
20. Sigmund, P. "Theory of Sputtering. I. Sputtering Yield of Amorphous and Polycrystalline Targets," *Phys. Rev.* **184**, 383 (1969).
21. Smith, D. L. *Thin-Film Deposition: Principles and Practice*, McGraw-Hill, 1995.
22. Stoney, G. G. "The Tension of Metallic Films Deposited by Electrolysis," *Proc. R. Soc. Lond. A* **82**, 172 (1909).
23. Swartz, E. T. & Pohl, R. O. "Thermal boundary resistance," *Rev. Mod. Phys.* **61**, 605 (1989).
24. Tolan, M. *X-Ray Scattering from Soft-Matter Thin Films*, Springer, 1999.
25. Tu, K. N., Mayer, J. W. & Feldman, L. C. *Electronic Thin Film Science*, Macmillan, 1992.
26. Wasa, K., Kitabatake, M. & Adachi, H. *Thin Film Materials Technology: Sputtering of Compound Materials*, Springer, 2004.
27. Yamamura, Y. & Tawara, H. "Energy Dependence of Ion-Induced Sputtering Yields from Monatomic Solids at Normal Incidence," *At. Data Nucl. Data Tables* **62**, 149 (1996).
28. Ziegler, J. F., Biersack, J. P. & Littmark, U. *The Stopping and Range of Ions in Solids*, Pergamon, 1985.
