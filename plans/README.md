# Plans Index

Feature roadmaps for the quantized_matlab toolbox. Each plan uses the canonical
format defined in `claude-config/rules/plan-format.md`: header block with status/dates,
context section, Tier 1/2/3 with continuous numbering, completed section at bottom.

> **Note:** plans/ is gitignored (per-machine working notes). The tracked
> dashboard of open items is [`BACKLOG.md`](../BACKLOG.md) at the repo root.

## Active Plans

| Plan | Focus | Status |
|------|-------|--------|
| [known-bugs.md](known-bugs.md) | BosonPlotter + FermiViewer papercuts and regressions | Active |
| [bosonplotter-decomposition.md](bosonplotter-decomposition.md) | Drive BosonPlotter under 8k lines; extract subsystems | Active |
| [fermiviewer-decomposition-2026-04-16.md](fermiviewer-decomposition-2026-04-16.md) | Extract EELS/EDS from FermiViewer | Active |
| [fermiviewer-interactive-histogram.md](fermiviewer-interactive-histogram.md) | Transfer ramp, drag-for-contrast, clipping indicators | Active (T3 only) |
| [fermiviewer-measurement-polish-2026-04-17.md](fermiviewer-measurement-polish-2026-04-17.md) | Panel controls + annotation right-panel sync | Active |
| [data-workspace.md](data-workspace.md) | Shared model migration + legacy table removal | Active |
| [dataset-templates.md](dataset-templates.md) | Template analytics + Python port contract | Active (T3 only) |
| [dataworkspace-python-port.md](dataworkspace-python-port.md) | DataWorkspace → thin_film_toolkit | Active |
| [retroactive-docs.md](retroactive-docs.md) | Theory docs + tutorials | Active |
| [origin-feature-gap.md](origin-feature-gap.md) | OriginPro parity — Python ports remaining | Active |
| [software-feature-gaps.md](software-feature-gaps.md) | Provenance log, 2D histogram, label rendering | Active |
| [repo-audit-2026-04-13.md](repo-audit-2026-04-13.md) | Pre-checkpoint multi-workstream audit | Active |
| [codebase-roadmap.md](codebase-roadmap.md) | Rolling umbrella: extraction + docs | Active |
| [bug-reporting.md](bug-reporting.md) | Stage 2 — Worker relay + submit-directly | Active (Stage 2 deferred) |
| [parser-roadmap.md](parser-roadmap.md) | New parsers (Raman, Oxford, OPUS) | Paused |
| [porting_plan.md](porting_plan.md) | MATLAB → Python+Tauri architecture | Active |

## Archive

Completed plans kept for reference in [`archive/`](archive/):

| Plan | Completed | Description |
|------|-----------|-------------|
| diraculator-ux-polish-2026-04-17.md | 2026-04-17 | 17 items — sidebar, home panel, cross-tab hooks, persistence, contrast |
| fermiviewer-ux-pass-2026-04-16.md | 2026-04-16 | FermiViewer UX pass |
| materialscalc-improvements.md | 2026-04-12 | DiraCulator: 33 items — UX, backend cards, cross-tab, docs, rename |
| physics-analysis-gaps.md | 2026-04-12 | 15 items — Tc, Brillouin, Bean Jc, VFT, Williamson-Hall, Hall, Curie-Weiss, Wiedemann-Franz, Stoner-Wohlfarth, BCS, Debye/Einstein, FORC, Kissinger, Arrhenius/VFT |
| improvements-audit-2026-04-11.md | 2026-04-12 | 60/63 items — usability, perf, UI, docs; #18/#20/#63 deferred |
| bosonPlotter-roadmap.md | 2026-03 | Corrections panel, XRR fitting, macro recorder, 2D perf |
| gui-test-coverage.md | 2026-04-09 | ~100% button coverage for BosonPlotter (54/54) and FermiViewer |
| originpro-inspired-features.md | 2026-03-21 | 8 phases: curve fitting, templates, stats, batch fit, ROI, multi-panel |
| origin_feature_gaps.md | 2026-03-21 | 7 OriginPro gaps: SG filter, templates, fitting, FFT, resample, stats, ROI |
| advanced-figure-builder.md | 2026-03 | 5-tier figure builder with waterfall, multi-panel, inset zoom |
| materials-calculator.md | 2026-03 | 6-phase calculator: constants, 10 packages, GUI, 152 tests (now DiraCulator) |
| materials_calculator_plan.md | 2026-03 | Detailed architecture for materials calculator phases 1-6 (now DiraCulator) |
| emviewer-phase1.md | 2026-03 | FermiViewer Phase 1: 20 features |
| emviewer-phase2.md | 2026-03 | FermiViewer Phase 2: 20 features |
| emviewer-phase3.md | 2026-03 | FermiViewer Phase 3: 20 DM-parity features |
| emviewer-phase4.md | 2026-03 | FermiViewer Phase 4: 20 analysis features |
| emviewer-original-plan.md | — | Original 7-phase EM viewer plan (superseded) |
| proposed-features-2026-03-14.md | — | Feature proposals (open items migrated to roadmaps) |
| test-2d-xrd-checklist.md | — | Manual 2D XRD test checklist (automated tests now cover this) |
| todo-2026-03-14.md | — | Original TODO (open items migrated to roadmaps) |
