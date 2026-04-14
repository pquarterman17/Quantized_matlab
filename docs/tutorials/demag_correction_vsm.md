# Correcting VSM/SQUID Hysteresis Loops for Demagnetization

## Research question

"I measured an $M(H)$ loop on my VSM, but my coercive field and saturation field look too small / the loop is suspiciously tilted. How do I correct for the sample geometry?"

The answer: you need to convert the applied field $H_\mathrm{ext}$ to the internal field $H_\mathrm{int}$ using the demagnetization factor $N$ for your sample shape.

---

## Background

A magnetometer reports magnetization as a function of the field it applies at the sample location, not the field inside the sample. For a uniformly magnetized body, the difference is the **demagnetizing field**:

$$H_\mathrm{int} = H_\mathrm{ext} - N_z M \quad \text{(SI; CGS replaces } N_z \text{ with } 4\pi N_z\text{)}$$

The sign means that a sample with significant $M$ partially opposes the applied field. Physically, surface magnetic "charges" create a return field through the sample interior that reduces the effective drive. The factor $N_z$ depends only on sample geometry, not on the material.

**When does this matter?** When $N_z M$ is a non-negligible fraction of the field range you care about. Rough test: if $N_z M_s / H_c > 0.1$, a correction is warranted. For soft magnetic films and bulk samples with $H_c \ll M_s$, it nearly always matters.

---

## Step 1: Identify your sample geometry

Choose the closest match from the table below:

| Sample | Shape string | Required parameters |
|---|---|---|
| Sphere or roughly equiaxed pellet | `'sphere'` | none |
| Thin film measured in-plane | `'thin_film'` | none ($N_{xy} = 0$; no correction) |
| Thin film measured out-of-plane | `'thin_film'` | none ($N_z = 1$) |
| Cylindrical PPMS/VSM rod, $0.1 \le L/d \le 10$ | `'cylinder'` | `L` (length), `d` (diameter) in any consistent unit |
| Flat coin-shaped pellet, $L/d < 0.1$ | `'oblate'` | `ratio = d/L` |
| Long rod or whisker crystal, $L/d > 10$ | `'prolate'` | `ratio = L/d` |

Measure $L$ and $d$ with a micrometer or caliper before mounting the sample. For a typical Quantum Design sample puck with a cylindrical pellet, $L \approx 2$--$5$ mm and $d \approx 2$--$3$ mm, giving $L/d \approx 0.7$--$2.5$, well within the Sato-Ishii valid range.

---

## Step 2: Compute $N_z$

```matlab
% Example: cylindrical pellet, 4 mm long, 3 mm diameter
r = calc.magnetic.demagFactor('cylinder', L=4e-3, d=3e-3);
Nz = r.Nz;
fprintf('N_z = %.4f,  N_xy = %.4f\n', r.Nz, r.Nxy);
% N_z = 0.1724,  N_xy = 0.4138
```

If your cylinder is outside the valid range ($L/d < 0.1$ or $L/d > 10$), MATLAB will warn you. Switch to the recommended spheroid shape:

```matlab
% Flat disk: 8 mm diameter, 0.5 mm thick (L/d = 0.0625, use oblate)
r = calc.magnetic.demagFactor('oblate', ratio=8/0.5);  % ratio = 16
fprintf('N_z = %.4f\n', r.Nz);
% N_z = 0.9196
```

---

## Step 3: Load and correct your $M(H)$ data

Assume your data are loaded as a struct `d` with fields `d.values` (columns: field in Oe, moment in emu) and you know the sample volume $V$ in cm$^3$.

```matlab
% Load data
d = parser.importAuto('NiFe_film.dat');

% Extract field and moment (CGS: Oe and emu)
H_ext = d.values(:, 1);   % Oe
m     = d.values(:, 2);   % emu

% Convert to volumetric magnetization
V  = 0.2 * 0.2 * 0.05;   % cm^3 for a 2x2 mm square, 500 nm thick film on Si
M  = m / V;               % emu/cm^3

% Get demagnetization factor (thin film out-of-plane in this example)
r  = calc.magnetic.demagFactor('thin_film');
Nz = r.Nz;   % = 1 for out-of-plane geometry

% Correct the field axis (CGS convention: H_int = H_ext - 4pi*N*M)
H_int = H_ext - 4*pi * Nz * M;

% Plot both
figure;
plot(H_ext * 1e-4, M, 'b-', 'DisplayName', 'Applied field');
hold on;
plot(H_int * 1e-4, M, 'r-', 'DisplayName', 'Internal field');
xlabel('H (T)');
ylabel('M (emu/cm^3)');
legend;
title('Hysteresis loop before and after demagnetization correction');
```

Note: in SI, replace $4\pi N_z M$ with $N_z M$ (where $M$ is in A/m).

---

## Step 4: Interpret the corrected loop

After correction:

- **The slope at high field becomes vertical** for a magnetically saturated sample. If $M$ is truly saturated (flat) at large $|H_\mathrm{ext}|$, the corrected loop will show a steep, nearly vertical branch approaching $\pm M_s$ — this is correct and expected.
- **The apparent coercive field increases**. The corrected $H_c^\mathrm{int}$ is the intrinsic coercivity of the material. The apparent $H_c^\mathrm{ext}$ is reduced by the demagnetizing field, which acts like a self-demagnetization bias.
- **Soft magnetic samples may develop an "S-shaped" loop** after correction. This is the true single-domain switching behavior that was hidden by the demagnetizing field.

**Watch out for over-correction**: if your $M$ value at a given field is wrong (e.g., due to an incorrect sample volume or mass), the correction $N_z M$ will be wrong and the corrected loop will look unphysical (negative slope at high field). Double-check your volume and the sign convention for your instrument.

---

## Step 5: Extract corrected loop parameters

Use standard hysteresis analysis on the corrected field axis:

```matlab
% Build a corrected data struct for downstream analysis
d_corr = d;
d_corr.values(:, 1) = H_int;

% Analyse (uses corrected internal field)
params = utilities.hysteresisAnalysis(d_corr, FieldColumn=1, MomentColumn=2);
fprintf('Corrected H_c  = %.1f Oe\n', params.Hc);
fprintf('Corrected M_r  = %.4g emu\n', params.Mr);
fprintf('M_s            = %.4g emu\n', params.Ms);
fprintf('Squareness S   = %.3f\n', params.squareness);
```

---

## What if the transition is broad?

A broad, slanted high-field approach to saturation is often caused by:

1. **Paramagnetic or diamagnetic background** (substrate, sample holder). Subtract the linear high-field slope before correcting. See the Background Subtraction section in `docs/theory/magnetometry.md`.
2. **Sample not fully saturated**. The demagnetization correction assumes uniform $M = M_s$, which requires $H_\mathrm{int} \gg H_c$. If you can't saturate, the correction is only approximate.
3. **Multi-phase sample** with different $M_s$ values. The volume-averaged $M$ in the demagnetizing-field formula is no longer well-defined. Treat phases separately if their saturation fields are distinct.

## What if there is a second magnetic phase?

If the loop shows a "kink" or a two-step switching, you likely have two phases with different coercivities. The demagnetization correction applies to the total $M$, not to individual phases, so proceed as above. The FORC analysis (`calc.magnetic.forcDiagram`) will resolve the two phases in $(H_c, H_u)$ space regardless of the correction.

---

## Quick reference: CGS vs SI conventions

| Quantity | CGS | SI |
|---|---|---|
| Internal field | $H_\mathrm{int} = H_\mathrm{ext} - 4\pi N M$ | $H_\mathrm{int} = H_\mathrm{ext} - N M$ |
| Demagnetization factor | $N \in [0, 1/(4\pi)]$ (some references) or $[0, 1]$ | $N \in [0, 1]$ |
| Trace condition | $N_x + N_y + N_z = 1/(4\pi)$ or $1$ (convention-dependent) | $N_x + N_y + N_z = 1$ |

This toolbox uses the $N \in [0,1]$, trace $= 1$ SI convention throughout. When comparing to older literature (pre-1980), check whether the author uses the $4\pi N$ convention, which shifts all $N$ values by a factor of $4\pi \approx 12.57$.

---

## References

- Osborn, J.A., "Demagnetizing factors of the general ellipsoid," *Phys. Rev.* **67**, 351 (1945).
- Sato, M. & Ishii, Y., "Simple and approximate expressions of demagnetizing factors of uniformly magnetized rectangular rods and cylinders," *J. Appl. Phys.* **66**, 983 (1989).
- Chen, D.-X., Brug, J.A. & Goldfarb, R.B., "Demagnetizing factors for cylinders," *IEEE Trans. Magn.* **27**, 3601 (1991).
- Cullity, B.D. & Graham, C.D., *Introduction to Magnetic Materials*, 2nd ed., Wiley, 2009, Ch. 2.

For the full theory and formula derivations, see `docs/theory/magnetometry.md`, Demagnetization Corrections section.
