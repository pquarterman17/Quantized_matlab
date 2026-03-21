# +plotting/ — Plot Helper Functions

| Function | Description |
|----------|-------------|
| `formatAxes` | Apply theme to an axes object (fonts, grid, labels) |
| `lineColors` | Return N colours from the active theme palette |
| `saveFigure` | Export figure to PNG/PDF/SVG/EPS at set dimensions |

## Usage

```matlab
th = styles.default();
cols = plotting.lineColors(3, th);
fig = figure; plot(data.time, data.values, 'Color', cols(1,:));
plotting.formatAxes(gca, th, 'XLabel', '2\theta (°)', 'YLabel', 'Counts');
plotting.saveFigure(fig, 'scan.pdf');
```
