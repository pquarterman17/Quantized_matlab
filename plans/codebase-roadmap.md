# Codebase Organization Roadmap

Structural improvements for maintainability.

---

## 1. Break up monolithic GUIs

**DataPlotter.m:** reduced from ~14,836 to ~14,514 lines by extracting:
- `+dataplotter/colorMaps.m` — colormap generation (viridis, plasma, inferno + builtins)
- `+dataplotter/safeEvalMathExpr.m` — safe recursive-descent expression parser

Previously extracted subsystems in `+dataplotter/`:
- `curveFitting.m`, `figureBuilder.m`, `graphDigitizer.m`
- `roiAnalysis.m`, `multiPanel.m`, `actionLog.m`, `datasetGroups.m`
- `applyCorrections.m`, `correctionParams.m`, `reflFitting.m`

### Remaining candidates (lower priority)
- Peak detection/fitting subsystem (~2,600 lines) — deep `appData` coupling
- Session save/load (~500 lines)
- GUI layout construction (~2,000 lines)
- `drawToAxes` (~1,175 lines) — hardest to extract due to state coupling

### emViewerGUI.m (~12k lines)
Less urgent — well-organized internally with clear section dividers.

---

## 2. Documentation

- `+calc/README.md` ✅ already exists (11 sub-packages documented)
- CLAUDE.md is ~100 lines (healthy)
- Per-package READMEs exist for: `+parser/`, `+imaging/`, `+calc/`, `+utilities/`, `+scripts/`

---

## 3. Test organization

Already in clean subdirectories: `parser/`, `gui/`, `imaging/`, `calc/`, `batch/`, `fitting/`. No changes needed.
