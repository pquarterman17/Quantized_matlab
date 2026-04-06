# +styles/ — Visual Themes

| Function | Description |
|----------|-------------|
| `default` | Default visual theme (colours, line widths, font sizes) |
| `dark` | Dark theme variant |

Themes return a struct with fields for colours, line widths, font sizes, and grid settings. Used by `plotting.formatAxes()` and the Boson GUI.

```matlab
th = styles.default();
% th.colors — Nx3 colour palette
% th.lineWidth — default line width
% th.fontSize — default font size
```
