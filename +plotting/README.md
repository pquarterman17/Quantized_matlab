# +plotting/ — Plot Helper Functions

Publication-quality plotting utilities. No external toolboxes required.

---

## Functions

### Axes and Figure Formatting

| Function | Description |
|----------|-------------|
| `formatAxes(ax, theme)` | Apply a visual theme to an axes object (fonts, grid, tick direction, labels) |
| `applyTemplate(fig, ax, tmpl)` | Apply a publication template (from `styles.template`) to a figure and its axes |
| `saveFigure(fig, filepath)` | Export a figure to PNG/PDF/SVG/EPS at publication-ready resolution |

#### Example
```matlab
th = styles.default();
plotting.formatAxes(gca, th, XLabel='2\theta (°)', YLabel='Intensity (cps)');

t = styles.template('aps');
plotting.applyTemplate(fig, ax, t);
plotting.saveFigure(fig, 'figure1.pdf');
```

---

### Color Utilities

| Function | Description |
|----------|-------------|
| `lineColors(n, theme)` | Return N distinguishable RGB colours from the active theme palette |

#### Example
```matlab
cols = plotting.lineColors(5, styles.default());
for k = 1:5
    plot(x, y{k}, 'Color', cols(k,:));
end
```

---

### Specialized Plot Types

| Function | Description |
|----------|-------------|
| `boxViolinSwarm(ax, dataCell)` | Box, violin, or bee-swarm plot for grouped data |
| `colorScatterZ(ax, x, y, z)` | Scatter plot with points coloured by a third variable Z |
| `groupedPlot(ax, x, y, groups)` | Plot data automatically grouped by a categorical variable |
| `marginalHistogram(ax, x, y)` | Scatter plot with marginal histograms on X and Y axes |
| `polarPlot(theta, r)` | Polar coordinate plot for angular-dependent measurements |
| `polarContour(theta, r, Z)` | Filled contour plot on polar coordinates |
| `ternaryPlot(fractions)` | Three-component composition diagram on an equilateral triangle |
| `surface3D(data)` | Render 2D map data as a 3D surface, mesh, or filled-contour plot |

#### Example — distribution plots
```matlab
% Violin plot of coercive field across samples
plotting.boxViolinSwarm(ax, {Hc_sample1, Hc_sample2, Hc_sample3}, ...
    Style='violin', Labels={'A','B','C'});
```

#### Example — composition diagram
```matlab
% Ternary phase diagram for Fe-Co-Ni alloys
plotting.ternaryPlot(compositions, Labels={'Fe','Co','Ni'}, ColorData=satMag);
```

#### Example — polar angular measurement
```matlab
% MOKE angular dependence
plotting.polarPlot(theta_deg * pi/180, kerr_signal, Units='deg');
```

#### Example — 2D map surface
```matlab
data = parser.importXRDML('reciprocal_space_map.xrdml');
plotting.surface3D(data, Type='contourf', Colormap='viridis');
```

---

### Figure Composition

| Function | Description |
|----------|-------------|
| `composeFigure(sources)` | Arrange multiple plots into a composite multi-panel publication figure |

#### Example
```matlab
result = plotting.composeFigure({fig1, fig2, fig3}, Layout=[1 3], ...
    Width_cm=17.8, Template='aps_double');
plotting.saveFigure(result.fig, 'composite.pdf');
```

---

### Plot Templates

| Function | Description |
|----------|-------------|
| `plotTemplate(action)` | Save, load, apply, list, and delete plot style templates on disk |
| `templateDialog(ax, mode)` | Modal GUI for saving or applying plot style templates |

#### plotTemplate actions
```matlab
plotting.plotTemplate('save',  ax, 'my_xrd_style');
plotting.plotTemplate('apply', ax, 'my_xrd_style');
names = plotting.plotTemplate('list');
plotting.plotTemplate('delete', [], 'my_xrd_style');
```

#### templateDialog
```matlab
% Let user pick and apply a template interactively
result = plotting.templateDialog(ax, 'apply');
```
