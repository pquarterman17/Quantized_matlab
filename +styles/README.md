# +styles/ — Visual Themes and Templates

Visual theme and publication template functions. No external toolboxes required.

---

## Functions

### Themes

| Function | Description |
|----------|-------------|
| `default()` | Default visual theme (colours, line widths, font sizes) |
| `dark()` | Dark theme variant |

Themes return a struct with fields for colours, line widths, font sizes, and grid settings. Used by `plotting.formatAxes()` and the BosonPlotter GUI.

```matlab
th = styles.default();
% th.colors      — Nx3 colour palette
% th.lineWidth   — default line width
% th.fontSize    — default font size
% th.figWidth    — default figure width (cm)
% th.figHeight   — default figure height (cm)
```

---

### Publication Templates

| Function | Description |
|----------|-------------|
| `template(name)` | Return a publication-ready graph template by name |

`styles.template` extends `styles.default()` with journal-specific dimensions, fonts, and DPI. Use with `plotting.applyTemplate(fig, ax, t)` and `plotting.saveFigure`.

#### Available templates

| Name | Journal / Context | Font | Width | DPI |
|------|-------------------|------|-------|-----|
| `'aps'` | APS (PRB, PRL, PRApplied) — single column | Helvetica 9pt | 8.6 cm | 600 |
| `'aps_double'` | APS double-column | Helvetica 9pt | 17.8 cm | 600 |
| `'nature'` | Nature family — single column | Arial 7pt | 8.9 cm | 600 |
| `'nature_double'` | Nature double-column | Arial 7pt | 18.3 cm | 600 |
| `'thesis'` | Dissertation figures | Times New Roman 11pt | 15.0 cm | 300 |
| `'presentation'` | Conference slides | Arial 18pt | 25.0 cm | 150 |
| `'poster'` | Research posters | Arial 24pt | 30.0 cm | 150 |
| `'screen'` | Default screen display | Helvetica | — | 150 |

#### Template struct fields

```
.name             — template name string
.fontName         — font family
.fontSize         — axis tick/label font size (pt)
.titleFontSize    — title font size (pt)
.legendFontSize   — legend font size (pt)
.lineWidth        — primary line width (pt)
.lineWidthThin    — secondary line width (pt)
.markerSize       — marker size (pt)
.figWidth_cm      — figure width (cm)
.figHeight_cm     — figure height (cm)
.dpi              — export resolution (dpi)
.tickDir          — 'in' | 'out' | 'both'
.tickLength       — normalised tick length [major minor]
.boxOn            — logical, draw box around axes
.gridAlpha        — grid transparency (0 = off)
.legendBox        — logical, draw legend box
.legendLocation   — legend placement string
.colors           — [Nx3] colour cycle (colourblind-friendly by default)
.markerShape      — 'o' or 'auto' (cycles per dataset)
.lineStyle        — '-' or 'auto' (cycles per dataset)
.alpha            — line/marker transparency (0–1)
.minorTicks       — logical, show minor ticks
```

#### Example
```matlab
t = styles.template('aps');
fig = figure; ax = axes(fig);
plot(ax, twoTheta, intensity);
plotting.applyTemplate(fig, ax, t);
plotting.saveFigure(fig, 'figure1.pdf');
```

---

### Color Palettes

| Function | Description |
|----------|-------------|
| `palette(name)` | Return an Nx3 RGB matrix for a named colour palette; optionally resample to n stops |

Used by the Plot Style dialog's colour-cycle override. Returns `[]` for `'default'` (keeps the template's own cycle).

#### Available palettes

| Name | Description | Stops |
|------|-------------|-------|
| `'default'` | Keep template colour cycle | — |
| `'tab10'` / `'tableau10'` | Matplotlib Tab10 qualitative | 10 |
| `'viridis'` | Perceptually-uniform sequential | 11 |
| `'plasma'` | Perceptually-uniform sequential | 11 |
| `'tol_bright'` | Paul Tol bright, colour-blind safe | 7 |
| `'tol_muted'` | Paul Tol muted, colour-blind safe | 9 |
| `'okabe_ito'` | Okabe–Ito, colour-blind safe | 8 |
| `'aps'` | APS-like high-contrast | 6 |
| `'nature'` | Nature-like pastel | 6 |
| `'grayscale'` | Grey ramp for monochrome | 5 |

#### Example
```matlab
rgb = styles.palette('okabe_ito');          % 8×3, all stops
rgb = styles.palette('viridis', 12);        % interpolated to 12 stops
rgb = styles.palette('tab10', 5);           % first 5 of tab10

% Apply in a plot
cols = styles.palette('tol_bright');
for k = 1:numel(datasets)
    plot(ax, x, y{k}, 'Color', cols(mod(k-1,size(cols,1))+1,:));
end
```
