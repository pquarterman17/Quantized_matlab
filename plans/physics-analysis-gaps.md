# Physics Analysis Gaps

Missing analysis capabilities identified by domain-specific audit. Each item adds
a fitting model, calculator function, or analysis utility that researchers need
for common measurement workflows.

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-12

---

## Context

### How the pieces fit together

New fitting models go in `+fitting/models.m` (the model catalog). New calculator
functions go in `+calc/+<domain>/`. New analysis utilities go in `+utilities/`.
All must follow existing patterns: no external toolboxes, PascalCase functions,
argument blocks for named parameters.

### Dependency map
- All items are independent of each other
- Items 1-4 (HIGH) are the most impactful — implement first
- Items 5-10 (MEDIUM) can be parallelized freely
- Items 11-15 (LOW) are nice-to-have

---

## Tier 1 — High Impact

1. ~~**Tc extraction from R(T)**~~ — superconducting transition temperature
   - [ ] `+calc/+superconductor/extractTc.m` — midpoint, onset, derivative criteria
   - [ ] Input: temperature vector, resistance vector
   - [ ] Output: struct with Tc_midpoint, Tc_onset, Tc_offset, transition_width, RRR
   - [ ] Tests in `tests/calc/test_superconductor.m`

2. ~~**Brillouin function model**~~ — quantized M(H) for paramagnets
   - [ ] Add `Brillouin` to `+fitting/models.m` catalog
   - [ ] B_J(x) = (2J+1)/(2J) * coth((2J+1)x/(2J)) - 1/(2J) * coth(x/(2J))
   - [ ] Parameters: Ms, J, T (or g*J if T is fixed)
   - [ ] Tests with known J=1/2 (tanh) and J→∞ (Langevin) limits

3. ~~**M(T) background subtraction**~~ — diamagnetic/paramagnetic slope correction
   - [ ] `+utilities/subtractMagBackground.m`
   - [ ] Linear high-field slope fit in user-specified field range
   - [ ] Returns corrected M(T) with background subtracted
   - [ ] Option: auto-detect slope from highest-field data points

4. ~~**Bean critical-state Jc**~~ — critical current from M(H) loop width
   - [ ] `+calc/+superconductor/beanJc.m`
   - [ ] Jc = ΔM / (a * (1 - a/(3b))) for rectangular cross-section
   - [ ] Input: M(H) loop, sample dimensions
   - [ ] Output: Jc(H) curve

## Tier 2 — Medium Impact

5. ~~**Vogel-Fulcher-Tammann model**~~ — superparamagnetic/spin-glass relaxation
   - [ ] Add `VFT` to `+fitting/models.m`: τ = τ₀·exp(Ea/(kB(T-T₀)))
   - [ ] Parameters: τ₀, Ea, T₀
   - [ ] Linearized form for initial guess: ln(τ) vs 1/(T-T₀)

6. ~~**Automated Williamson-Hall analysis**~~ — size + strain from XRD peak widths
   - [ ] `+calc/+crystal/williamsonHall.m`
   - [ ] Input: peak centers (2θ) and FWHMs from peak fitting results
   - [ ] Linear regression: β·cos(θ) vs 4·sin(θ)
   - [ ] Output: grain size (intercept) and microstrain (slope)

7. ~~**Hall effect analysis**~~ — carrier density and mobility
   - [ ] `+calc/+electrical/hallAnalysis.m`
   - [ ] Single-carrier: n = 1/(R_H·e), μ = R_H·σ
   - [ ] Two-carrier model fit for mixed conduction
   - [ ] Input: R_xy(H) data, sample thickness

8. ~~**Curie-Weiss from 1/χ(T)**~~ — linear regression helper
   - [ ] `+calc/+magnetic/curieWeiss.m`
   - [ ] Linear fit on 1/χ vs T in user-specified temperature range
   - [ ] Output: θ_CW (Weiss temperature), C (Curie constant), μ_eff

9. ~~**Wiedemann-Franz thermal conductivity**~~ — from electrical resistivity
   - [ ] `+calc/+electrical/wiedemannFranz.m`
   - [ ] κ_e = L₀·T/ρ where L₀ = 2.44×10⁻⁸ W·Ω/K²
   - [ ] Input: ρ(T) data, output: κ_e(T)

10. ~~**Stoner-Wohlfarth model**~~ — coherent rotation hysteresis
    - [ ] Add to `+fitting/models.m`: single-domain switching with anisotropy
    - [ ] Angular-dependent coercivity: Hc(θ)
    - [ ] Parameters: K (anisotropy), Ms, angle

## Tier 3 — Nice-to-Have

11. ~~**BCS gap fitting**~~ — Δ(T) temperature dependence
    - [ ] Numerical solution of the BCS gap equation
    - [ ] Fit to penetration depth or tunneling data

12. ~~**Debye/Einstein phonon model**~~ — specific heat C(T)
    - [ ] C(T) = 9NkB(T/θD)³ ∫₀^(θD/T) x⁴eˣ/(eˣ-1)² dx
    - [ ] Combined Debye + Einstein model for two characteristic temperatures

13. ~~**FORC diagram**~~ — First-Order Reversal Curves
    - [ ] FORC distribution: ρ(Ha, Hb) = -∂²M/∂Ha∂Hb / 2
    - [ ] Smoothing factor selection
    - [ ] Contour plot output

14. ~~**Kissinger analysis**~~ — activation energy from thermal analysis
    - [ ] Linear fit: ln(β/Tp²) vs 1/Tp where β=heating rate
    - [ ] Output: activation energy Ea

15. ~~**Arrhenius/VFT comparison**~~ — model selection for relaxation data
    - [ ] Fit both Arrhenius and VFT to the same τ(T) data
    - [ ] Compare via AIC/BIC (existing fitCompare infrastructure)
    - [ ] Report which model is statistically preferred

---

## Completed

(none yet)
