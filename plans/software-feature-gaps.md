# Software Feature Gaps

UX and analysis features identified by comparing against OriginPro, Igor Pro,
lmfit, Fityk, and Mantid. Focus on interaction patterns and capabilities that
affect real research productivity.

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-12 (Tier 1-2 complete, Tier 3 items 9-10 done)

---

## Context

### How the pieces fit together

These features span BosonPlotter (plotting/interaction), `+fitting/` (curve fitting),
`+utilities/` (signal processing), and the GUI layer. Most are independent of each
other and can be implemented in parallel.

### Dependency map
- All items are independent except item 7 (batch fit dialog) which benefits from item 4
- Items touching BosonPlotter.m must use the branch-before-implement rule
- Items adding to `+fitting/models.m` should coordinate to avoid merge conflicts

---

## Tier 1 — High Impact

1. ~~**Signal processing GUI dialog**~~ — interactive FFT filter with live preview
   - [ ] Create `+bosonPlotter/signalProcessingDialog.m`
   - [ ] FFT filter: low-pass, high-pass, band-pass, notch with cutoff frequency sliders
   - [ ] Live preview: original data + filtered overlay updating as sliders move
   - [ ] Apply: write filtered data back to dataset (via corrections pipeline)
   - [ ] Also expose: Welch PSD, cross-correlation visualization
   - [ ] Wire from BosonPlotter Advanced Tools menu

2. ~~**Cursor-driven fit region**~~ — drag cursors to define fit range
   - [ ] Two vertical draggable cursors on the plot axes
   - [ ] Fit only data between the cursors
   - [ ] Cursors update fit region in real-time as dragged
   - [ ] Replace typed X-range values in the curve fitting dialog
   - [ ] Wire into `+bosonPlotter/curveFitting.m`

3. ~~**Background anchor-point spline**~~ — Fityk-style user-defined background
   - [ ] Click on plot to place anchor points
   - [ ] Cubic spline interpolation through anchors = background
   - [ ] Subtract spline from data
   - [ ] Add/remove/drag anchor points interactively
   - [ ] Wire into peak analysis or corrections pipeline

4. ~~**Parameter constraints as expressions**~~ — lmfit-style inter-parameter links
   - [ ] In curve fitting dialog: constraint field per parameter
   - [ ] Syntax: `2 * p1`, `p1 + p2`, `p3 / 2`
   - [ ] Evaluated during fitting (constrained parameter not free)
   - [ ] Uses parseEquation engine (no eval)

## Tier 2 — Medium Impact

5. ~~**Batch fit dialog**~~ — end-to-end GUI for fitting multiple datasets
   - [ ] Select datasets → pick model → click "Batch Fit"
   - [ ] Results table: parameters per dataset
   - [ ] Parameter evolution plot (param vs dataset index or metadata value)
   - [ ] Export results to CSV/Excel
   - [ ] Reuse existing `fitting.batchFit` + `fitting.trackPeak` backend

6. ~~**Double-click-to-edit plot elements**~~ — Origin-style direct editing
   - [ ] Double-click axis label → open label edit dialog
   - [ ] Double-click legend → edit legend entries
   - [ ] Double-click data series → open style/color dialog
   - [ ] Wire via ButtonDownFcn on axes text and line objects

7. ~~**Right-click context menus on plot objects**~~ — micro-interactions
   - [ ] Right-click data trace: "Go to dataset", "Hide", "Change color", "Copy data"
   - [ ] Right-click axes: "Set limits", "Toggle log", "Add reference line"
   - [ ] Right-click legend: "Edit entry", "Move location"

8. ~~**Persistent cursor readout panel**~~ — Igor-style docked cursor
   - [ ] Docked panel showing cursor coordinates (not disappearing tooltip)
   - [ ] Updates live as cursor moves
   - [ ] Cursor-to-cursor delta always visible
   - [ ] Separate from the existing click-based data cursor

## Tier 3 — Nice-to-Have

9. ~~**Inset graph**~~ — interactive linked inset axes
   - [ ] Draw rectangle on plot → creates inset axes showing that region
   - [ ] Inset auto-updates when main plot data changes
   - [ ] Draggable/resizable inset box

10. ~~**Axis break**~~ — split axis with // marks for multi-scale data
    - [ ] Break at user-specified value
    - [ ] Adjustable gap ratio
    - [ ] Works with both linear and log scales

11. **Analysis provenance log** — Mantid-style operation history
    - [ ] Every analysis operation logged: {timestamp, function, parameters, result_hash}
    - [ ] Exportable as reproducible MATLAB script
    - [ ] "Replay" capability for reproducibility

12. **2D histogram / density plot** — scatter density visualization
    - [ ] For large datasets where scatter plots become unreadable
    - [ ] Hexbin or square binning
    - [ ] Colormap by point density

---

## Completed

- ~~**Signal processing GUI dialog**~~ (2026-04-12) — FFT filter (LP/HP/BP/notch), smoothing, Welch PSD with live preview; 9 tests
- ~~**Cursor-driven fit region**~~ (2026-04-12) — draggable vertical cursors wired into curveFitting dialog; 10 tests
- ~~**Background anchor-point spline**~~ (2026-04-12) — click-to-place anchors, cubic spline preview, apply subtraction
- ~~**Parameter constraints as expressions**~~ (2026-04-12) — `2*p1`, `p1+p2` syntax in curveFit; 17 tests
- ~~**Batch fit dialog**~~ (2026-04-12) — dataset checklist, model picker, parameter evolution plot, CSV export
- ~~**Double-click-to-edit plot elements**~~ (2026-04-12) — axis labels, title, data series color via ButtonDownFcn
- ~~**Right-click context menus on plot objects**~~ (2026-04-12) — trace (go-to/hide/color/copy), axes (limits/log/grid/refline)
- ~~**Persistent cursor readout panel**~~ (2026-04-12) — docked 20px strip with live X/Y/ΔX/ΔY + dataset name
- ~~**Inset graph**~~ (2026-04-12) — interactive linked inset, draggable, auto-cleanup; 14 tests
- ~~**Axis break**~~ (2026-04-12) — zigzag/slash/gap styles, Y and X break support; 8 tests
