# Codebase Organization Roadmap

Structural improvements for maintainability.

---

## 1. Break up monolithic GUIs

**Priority:** High — DataPlotter.m is ~17k lines
**Effort:** Large, high-risk

### DataPlotter.m decomposition targets
Current subsystems already extracted to `+dataplotter/`:
- `curveFitting.m`, `figureBuilder.m`, `graphDigitizer.m`
- `roiAnalysis.m`, `multiPanel.m`, `actionLog.m`, `datasetGroups.m`
- `applyCorrections.m`, `correctionParams.m`

Remaining candidates:
- `+dataplotter/peakAnalysis.m` — peak detection, fitting, table management (~1,500 lines)
- `+dataplotter/sessionManager.m` — save/load session (~500 lines)
- `+dataplotter/buildLayout.m` — GUI construction helpers (~2,000 lines)
- `+dataplotter/templates.m` — template save/load/apply (~300 lines)

### emViewerGUI.m (~12k lines)
Less urgent — already well-organized internally with clear section dividers.

---

## 2. Documentation refresh

- Add README.md to `+calc/` package (currently missing)
- Keep CLAUDE.md under ~200 lines (currently ~100, healthy)
- Keep per-package READMEs up to date when adding features
- Refresh in-code docstrings for older functions

---

## 3. Test organization

Tests are already in subdirectories (`parser/`, `gui/`, `imaging/`, `calc/`, `batch/`, `fitting/`). No reorganization needed — current structure is clean.
