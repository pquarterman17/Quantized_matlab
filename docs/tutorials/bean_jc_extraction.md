# Tutorial: Extracting $J_c$ from a VSM/SQUID Hysteresis Loop

This tutorial walks through the complete workflow for extracting the Bean critical current density $J_c(H)$ from a DC magnetization loop measured on a type-II superconductor using a VSM or SQUID magnetometer (Quantum Design PPMS, MPMS, or DynaCool).

**Research question:** You have measured $M(H)$ on a superconducting sample at a fixed temperature. How large is $J_c$, and how does it depend on applied field?

---

## 1. Physics background in 60 seconds

In a type-II superconductor above $H_{c1}$, applied flux enters as quantized Abrikosov vortices that are pinned by material defects. The pinned vortex lattice creates a gradient in flux density, $\partial B/\partial x$, that by Ampere's law equals $(4\pi/c)\,J_c$ in Gaussian CGS. Bean's 1962 hypothesis — that $J_c$ is field-independent — turns this gradient into a linear flux profile inside the sample. The consequence is a hysteresis loop $M(H)$ whose width $\Delta M = |M_\uparrow - M_\downarrow|$ is directly proportional to $J_c$. The geometry factors turn the proportionality constant into a prefactor of 20 (rectangular) or 30 (cylindrical).

See [`docs/theory/superconductivity.md`](../theory/superconductivity.md#bean-critical-state-model) for the full derivation.

---

## 2. What you need

- A `.dat` file from a Quantum Design MPMS or PPMS/VSM, measured at fixed $T$ with field swept from $+H_{\max}$ to $-H_{\max}$ and back (or vice versa). The loop must include both ascending and descending field branches.
- Sample dimensions (all in **centimeters**):
  - Rectangular pellet or film: width, length, thickness
  - Disk or cylinder: radius, thickness (height)
- Knowledge of whether the sample was measured with field along the short axis (thickness direction) — typical for films — or along the length.

**Field orientation matters:** the Bean formula assumes flux penetrates through the sample cross-section perpendicular to the applied field. For a platelet with field along its thickness direction (the standard MPMS geometry for films), $a$ and $b$ are the in-plane dimensions and $t$ is the thickness.

---

## 3. Load the data

```matlab
setupToolbox   % run once to add packages to path

data = parser.importAuto('YBCO_film_MvsH_5K.dat');
% or for explicit MPMS format:
data = parser.importQDMPMS('YBCO_film_MvsH_5K.dat', ...
    'XAxis', 'field', 'YAxis', 'moment');

H = data.values(:, data.labels == "Magnetic Field (Oe)");
M = data.values(:, data.labels == "Moment (emu)");
```

Verify the loop visually before proceeding:

```matlab
figure;
plot(H, M, 'k.-');
xlabel('H (Oe)'); ylabel('M (emu)');
title('Raw M(H) loop — check for both branches');
```

A well-formed loop should show:
- Two distinct branches (ascending and descending) separated by a visible gap
- The gap should be largest at intermediate fields and narrow near $H = 0$ and near $\pm H_{\max}$
- No abrupt jumps or missing segments

---

## 4. Define sample dimensions

Measure sample dimensions with calipers or from optical microscopy. For a typical YBCO film:

```matlab
% Example: epitaxial YBCO film on 5x5 mm SrTiO3 substrate
% Dimensions in centimeters
dims.width     = 0.50;   % cm  (5 mm, in-plane)
dims.length    = 0.50;   % cm  (5 mm, in-plane)
dims.thickness = 0.015;  % cm  (150 nm film = 1.5e-4 cm; use cm)
```

For a bulk pellet (YBCO or NbN):

```matlab
% Example: bulk YBCO pellet, roughly rectangular
dims.width     = 0.30;   % cm
dims.length    = 0.45;   % cm
dims.thickness = 0.18;   % cm  (the dimension parallel to the field)
```

For a punched disk or cylindrical pellet:

```matlab
% Example: 3 mm diameter Nb disk
dims.radius    = 0.150;  % cm  (1.5 mm)
dims.thickness = 0.050;  % cm  (0.5 mm)
```

**Note on thickness for films:** The "thickness" here is the dimension along the applied field direction, which for an in-plane geometry (field perpendicular to the film normal, used for thin-film critical-state analysis) would be the film in-plane dimension. For the standard out-of-plane geometry (field along film normal, which is most common), `thickness` is the film thickness in cm.

---

## 5. Compute $J_c(H)$

```matlab
result = calc.superconductor.beanJc(H, M, dims);
% For a cylindrical sample:
% result = calc.superconductor.beanJc(H, M, dims, Geometry='cylindrical');
```

The function returns:
- `result.Jc` — critical current density in A/cm$^2$ at each field point
- `result.field` — field grid in Oe (or T if you passed `FieldUnit='T'`)
- `result.deltaM` — loop width $\Delta M$ at each field (emu)

---

## 6. Plot and interpret

```matlab
figure;
subplot(2,1,1);
plot(result.field/1e4, result.Jc/1e3, 'b-', 'LineWidth', 1.5);
xlabel('H (T)'); ylabel('J_c (kA/cm^2)');
title('Bean critical current density');
grid on;

subplot(2,1,2);
plot(result.field/1e4, result.deltaM, 'r-', 'LineWidth', 1.5);
xlabel('H (T)'); ylabel('\DeltaM (emu)');
title('Hysteresis loop width');
grid on;
```

### What to look for

**Good data:** $J_c$ is a smooth, monotonically decreasing function of $|H|$. The low-field region ($|H| < 0.1 H_{\max}$) is automatically excluded because the central peak in $\Delta M$ near $H = 0$ comes from flux trapping and surface barriers rather than bulk pinning.

**Strong pinning (good sample):** $J_c$ decreases slowly with $H$, remaining above $10^4$ A/cm$^2$ at the maximum field. Example: optimally doped YBCO film at 5 K might show $J_c(0) \sim 2 \times 10^6$ A/cm$^2$ dropping to $\sim 10^5$ A/cm$^2$ at 5 T.

**Weak pinning (poor sample or high $T$):** $J_c$ drops steeply, reaching the noise floor within $\sim 0.5$ T. This is common in granular or non-stoichiometric films.

**Typical reference values at 77 K in self-field:**

| Material | $J_c$ (A/cm$^2$) | Notes |
|---|---|---|
| YBCO epitaxial film | $10^6$--$2\times10^7$ | Best films at 4 K can reach $10^7$ |
| YBCO bulk pellet | $10^3$--$10^5$ | Grain-boundary limited |
| NbN film | $10^6$--$10^7$ | At 4 K; $\sim 10^4$ at 10 K |
| Nb bulk | $10^4$--$10^5$ | At 4 K |

---

## 7. Worked example with numbers

**Setup:** Bulk YBCO pellet, $0.30 \times 0.45 \times 0.18$ cm, measured at $T = 77$ K.

At $H = 1000$ Oe, the measured $\Delta M_\mathrm{total} = 0.060$ emu.

Volume: $V = 0.30 \times 0.45 \times 0.18 = 0.0243$ cm$^3$

$\Delta M_\mathrm{vol} = 0.060\,\mathrm{emu} / 0.0243\,\mathrm{cm^3} = 2.47$ emu/cm$^3$

Dimensions: $a = 0.30$ cm, $b = 0.45$ cm

Correction factor: $1 - a/(3b) = 1 - 0.30/(3 \times 0.45) = 1 - 0.222 = 0.778$

$$J_c = \frac{20 \times 2.47}{0.30 \times 0.778} = \frac{49.4}{0.233} = 212\;\mathrm{A/cm^2}$$

This is a typical $J_c$ for granular YBCO bulk at 77 K (well below $H_{c1}$, near the self-field limit). The same sample might show $J_c \sim 500$ A/cm$^2$ at low field ($H \ll H_{c1}$) and drop to $\sim 50$ A/cm$^2$ at $H = 1$ T.

---

## 8. Common pitfalls

### Substrate background not subtracted

**Symptom:** The loop looks unusual — perhaps the high-field slope is non-zero (linear diamagnetic background from the substrate), or $\Delta M$ increases at high field instead of decreasing.

**Fix:** Measure a bare substrate under identical conditions, or fit a linear background to the $M(H)$ data above the irreversibility field $H_\mathrm{irr}$ (where $\Delta M \to 0$). Subtract the linear diamagnetic slope:

```matlab
% Fit and subtract linear background from high-field region
Hmax = max(abs(H));
highField = abs(H) > 0.8 * Hmax;
p = polyfit(H(highField), M(highField), 1);   % linear fit
M_corrected = M - polyval(p, H);              % subtract slope

result = calc.superconductor.beanJc(H, M_corrected, dims);
```

### Wrong geometry

**Symptom:** $J_c$ values are off by a factor of 1.5--2x compared to literature.

**Fix:** Check whether your sample is truly rectangular or cylindrical. A disk punched from a film is cylindrical. A bulk pellet pressed in a die may be cylindrical. When in doubt, use the measured dimensions — if $a \approx b$, the cylindrical and square-rectangular formulas give similar results (rectangular square factor = 2/3, cylindrical factor = 2/3 for a disk).

### Half-width vs. full-width confusion

**Symptom:** $J_c$ is exactly half (or double) the expected value.

**Fix:** The `beanJc` function uses the **full-width** convention, i.e., $\Delta M = |M_\uparrow - M_\downarrow|$ (not $(M_\uparrow - M_\downarrow)/2$). If you preprocessed the data with a half-width calculation, do not divide by 2 before passing to the function.

### Loop is not a full hysteresis loop

**Symptom:** `beanJc` raises `calc:superconductor:beanJc:notALoop`.

**Fix:** The function requires $H$ to contain both increasing and decreasing field values. If your data file contains only one branch (e.g., a virgin curve or a first-quadrant sweep), you cannot apply the Bean formula — you need the complete closed loop.

### Low-field noise dominates

**Symptom:** Large scatter in $J_c$ at low fields, with $J_c$ apparently increasing below $\sim 500$ Oe.

**Fix:** The function already excludes the central 10% of the field range. If the noise is severe, consider increasing this threshold manually by pre-filtering the data, or simply truncate `result.field` and `result.Jc` to the field range where the data is clean.

### Film $J_c$ is orders of magnitude lower than expected

**Symptom:** A thin film ($t = 100$ nm) gives $J_c \sim 10^2$ A/cm$^2$ instead of $\sim 10^6$ A/cm$^2$.

**Likely cause:** The `thickness` parameter was entered in nm instead of cm. The Bean formula scales as $1/V$, so using nm instead of cm introduces a factor of $10^{21}$ error (since $V$ enters as $1/\mathrm{cm^3}$). Always convert to cm: 100 nm = $100 \times 10^{-7}$ cm = $10^{-5}$ cm.

```matlab
dims.thickness = 100e-9 * 100;   % convert nm -> cm: 1 m = 100 cm, 1 nm = 1e-9 m
% i.e.:
dims.thickness = 100 * 1e-7;     % 100 nm in cm
```

---

## 9. Temperature and field dependence workflows

### $J_c(T)$ at fixed field

Run `beanJc` on loops measured at multiple temperatures:

```matlab
temperatures = [5, 20, 40, 60, 77];  % K
Jc_selfField = zeros(1, numel(temperatures));

for k = 1:numel(temperatures)
    fname = sprintf('YBCO_MvsH_%dK.dat', temperatures(k));
    d = parser.importAuto(fname);
    H_k = d.values(:,1);
    M_k = d.values(:,2);
    r = calc.superconductor.beanJc(H_k, M_k, dims);
    % Take Jc at the lowest available field (near self-field)
    [~, iMin] = min(abs(r.field));
    Jc_selfField(k) = r.Jc(max(1, iMin));
end

figure;
plot(temperatures, Jc_selfField/1e6, 'o-');
xlabel('T (K)'); ylabel('J_c (MA/cm^2)');
title('Self-field J_c vs. temperature');
```

### Comparing pinning landscapes

If you have multiple samples (e.g., un-irradiated vs. irradiated to add columnar defects), overlay their $J_c(H)$ curves:

```matlab
r1 = calc.superconductor.beanJc(H1, M1, dims1);
r2 = calc.superconductor.beanJc(H2, M2, dims2);

figure; hold on;
plot(r1.field/1e4, r1.Jc/1e3, 'b-', 'DisplayName', 'As-grown');
plot(r2.field/1e4, r2.Jc/1e3, 'r-', 'DisplayName', 'Irradiated');
legend; xlabel('H (T)'); ylabel('J_c (kA/cm^2)');
set(gca, 'YScale', 'log');  % log scale reveals pinning exponents
```

A log-log plot of $J_c$ vs. $H$ often follows a power law $J_c \propto H^{-n}$ in the flux-flow regime. The exponent $n$ characterizes the pinning mechanism (point defects, columnar tracks, grain boundaries).

---

## 10. Quick reference: formula check

For a rectangular sample with $a = 0.3$ cm, $b = 0.5$ cm, $t = 0.02$ cm:

$$V = 0.3 \times 0.5 \times 0.02 = 0.003\;\mathrm{cm^3}$$

$$\Delta M_\mathrm{vol} = \frac{\Delta M_\mathrm{total}}{V} = \frac{0.06\;\mathrm{emu}}{0.003\;\mathrm{cm^3}} = 20\;\mathrm{emu/cm^3}$$

$$1 - \frac{a}{3b} = 1 - \frac{0.3}{1.5} = 0.80$$

$$J_c = \frac{20 \times 20}{0.3 \times 0.80} = \frac{400}{0.24} \approx 1667\;\mathrm{A/cm^2}$$

For the cylindrical case with $R = 0.15$ cm, $t = 0.02$ cm:

$$V = \pi \times 0.15^2 \times 0.02 = 1.414 \times 10^{-3}\;\mathrm{cm^3}$$

$$\Delta M_\mathrm{vol} = \frac{0.06}{1.414 \times 10^{-3}} = 42.4\;\mathrm{emu/cm^3}$$

$$J_c = \frac{30 \times 42.4}{0.15} = 8480\;\mathrm{A/cm^2}$$

---

## 11. References

- Bean, C. P. "Magnetization of Hard Superconductors," *Phys. Rev. Lett.* **8**, 250 (1962). DOI: [10.1103/PhysRevLett.8.250](https://doi.org/10.1103/PhysRevLett.8.250)
- Gyorgy, E. M. et al. "Anisotropy of the magnetization in superconducting YBa$_2$Cu$_3$O$_7$," *J. Appl. Phys.* **61**, 3802 (1987). DOI: [10.1063/1.338638](https://doi.org/10.1063/1.338638)
- Chen, D.-X. & Goldfarb, R. B. "Kim model for magnetization of type-II superconductors," *J. Appl. Phys.* **66**, 2489 (1989). DOI: [10.1063/1.344261](https://doi.org/10.1063/1.344261)
- Tinkham, M. *Introduction to Superconductivity*, 2nd ed., Dover, 2004, Ch. 5.
- Ekin, J. W. *Experimental Techniques for Low-Temperature Measurements*, Oxford University Press, 2006, Ch. 9.
