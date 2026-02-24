# TODO

## Bugs
- [x] `dataImportGUI`: "Clear All Peaks" did not remove peak markers from the plot
      (`cla()` skips children with `HandleVisibility='off'`; fixed with `delete(ax.Children)`)
- [x] `dataImportGUI`: Peak fitter changed from Gaussian to Lorentzian for XRD data
- [ ] `Reset zoom after zoom by draw box zoom broken

## Parser (`+parser`)
- [x] `importRigaku_raw`: multi-range detection + warning; improved variable-step error message
- [x] `importPPMS`: auto-detect tab vs comma delimiter for newer PPMS TSV exports

## GUI (`dataImportGUI`)
- [ ] Multi-dataset peak analysis — currently only the active dataset's peaks are shown
- [x] Persist axis limit / correction settings between file loads — axis limits are now
      saved per-dataset in `ds.axLims`; restored when switching between datasets

## Planned packages (now implemented)
- [x] `+plotting` — `formatAxes`, `lineColors`, `saveFigure`
- [x] `+scripts`  — `batchImport` (flat + recursive directory walk)
- [x] `+styles`   — `default` theme struct (colours, line widths, font sizes)
- [x] `+utilities` — `normalize`, `smoothData`, `convertUnits`

## Python port
- [ ] `thin_film_toolkit_python` — port parsers and GUI to Python (directory exists, empty)
