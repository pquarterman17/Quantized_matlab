# Fermion Feature Plan — Phase 4 (Analysis & Publication)

Gap analysis vs. ImageJ/Fiji, IMOD, SerialEM viewer, Gwyddion, and common
publication workflows. Focuses on quantitative analysis features and
figure-preparation tools that researchers use daily but are missing from
Phases 1-3.

> **Status: Implemented — all 20 features, 11 new +imaging/ functions, ~580 lines GUI code.**

---

## Gap Analysis Summary

| Capability gap | Reference tool | Phase 4 feature |
|---|---|---|
| Lattice fringe / spacing measurement | ImageJ (FFT + inverse), DM | 1. Live FFT Spot Masking with Lattice Overlay |
| Strain mapping from HRTEM | GPA plugin (Fiji), DM | 3. Geometric Phase Analysis (strain) |
| Publication figure builder | Fiji Montage, PowerPoint manual work | 2. Figure Panel Builder |
| Grain boundary / interface analysis | ImageJ line scan, Gwyddion | 5. Interface Width Measurement |
| SPM-style roughness / height statistics | Gwyddion (core feature) | 4. Surface Roughness Statistics |
| Tilt series alignment preview | IMOD (etomo), SerialEM | 8. Tilt Series Navigator |
| Defocus / CTF estimation | CTFFIND, IMOD ctfplotter | 9. CTF Estimation |
| Background plane subtraction (AFM/SPM) | Gwyddion (core) | 6. Plane Leveling / Background Subtraction |
| Batch measurement scripting | ImageJ macro recorder | 10. Measurement Macro Recorder |
| Calibrated text/label annotations | Fiji, DM | 7. Rich Text Labels |
| Side-by-side with synced annotations | DM, Fiji Sync Windows | 12. Synced Annotation Pairs |
| Defect density / line counting | Manual counting in ImageJ | 11. Defect Line Counter |
| Colorbar with real units | Gwyddion, DM | 14. Calibrated Colorbar |
| Quick journal figure export | Fiji, Inkscape | 15. Journal Export Presets |
| Histogram-based segmentation classes | Fiji Trainable Weka, Gwyddion | 13. Multi-class Threshold |

Features intentionally excluded from Phase 4 (too specialized or requires
external libraries): 4D-STEM virtual imaging, EELS/EDS spectrum imaging,
tomographic reconstruction, GPU-accelerated denoising (BM3D/NLM), machine
learning segmentation, live acquisition, FIB-SEM serial sectioning 3D.

---

## Tier 1 --- High-Value, Moderate Effort

### 1. Live FFT Spot Masking with Lattice Overlay

Select spots in the FFT interactively and overlay the corresponding
real-space lattice vectors on the image. Unlike the existing FFT mask +
inverse (Phase 1), this feature links selected frequency-domain spots back
to calibrated real-space periodicities. The user clicks two non-collinear
spots, and the tool draws the direct lattice cell on the image, reports
lattice parameters (a, b, angle), and optionally filters to show only
those periodicities (Bragg-filtered image).

**Reference tool:** ImageJ FFT + "Display Lattice" macro; DM DiffTools
lattice measurement; CrysTBox FreqFilt.

**Touches:**
- `Fermion.m` --- new capture mode `'lattice'` with spot-click
  interaction on the FFT axes; overlay drawing on the real-space axes;
  lattice parameter readout in the measurement table.
- `+imaging/latticeMeasure.m` (new) --- given two FFT spot positions and
  pixel calibration, compute reciprocal vectors g1/g2, invert to get
  real-space vectors a1/a2, return lattice params and overlay coordinates.

**Effort:** ~200 lines (+imaging) + ~120 lines (GUI integration).

**Implementation approach:**
1. User opens FFT display (existing), enters `'lattice'` capture mode.
2. Click on two distinct spots; record pixel positions relative to center.
3. Convert pixel offsets to reciprocal vectors using FFT pixel scale
   (`1 / (N * pixelSize)`).
4. Invert the 2x2 reciprocal matrix to get real-space lattice vectors.
5. Draw parallelogram unit cell on the image axes (periodic tiling
   clipped to viewport).
6. Report a, b, gamma in the status bar and measurement table.
7. Optional: construct binary mask at those spots, inverse FFT, display
   Bragg-filtered image (reuse existing `butterworthFilter` for soft mask
   around each spot).

---

### 2. Figure Panel Builder (Publication Montage with Labels)

Arrange multiple images (or crops) into a labeled multi-panel figure with
shared scale bars, panel letters (a, b, c...), and uniform sizing.
Researchers spend significant time doing this manually in PowerPoint or
Illustrator. This feature produces a single composite image or
vector-friendly export ready for journal submission.

**Reference tool:** ImageJ "Make Montage"; Fiji FigureJ plugin; DM
"Layout" mode; manual PowerPoint/Illustrator assembly.

**Touches:**
- `Fermion.m` --- new menu item "Figure Builder..." opening a dialog.
  The dialog shows a grid selector (rows x cols), drag-and-drop from
  loaded image list, per-panel crop handles, shared scale bar toggle,
  panel letter overlay, border/gap controls.
- `+imaging/buildFigurePanel.m` (new) --- accepts cell array of images +
  layout spec, returns composite image with labels burned in.

**Effort:** ~250 lines (+imaging) + ~200 lines (GUI dialog).

**Implementation approach:**
1. Dialog: grid size selector, image assignment per cell (dropdown from
   loaded images), optional per-panel crop rectangle.
2. All panels resized to uniform pixel dimensions (largest panel width
   sets the reference; others padded or scaled).
3. Panel letters rendered via `insertText`-equivalent (draw chars into a
   small matrix using a bitmap font, no toolbox).
4. Shared scale bar computed from first calibrated panel.
5. Assemble via `cat`/indexing into a single output matrix.
6. Export at user-specified DPI (reuse Phase 2 resolution control).
7. Also allow vector export: open a new figure with `subplot` tiling and
   save as PDF/SVG via `plotting.saveFigure`.

---

### 3. Geometric Phase Analysis (Strain Mapping)

Compute 2D strain tensor maps from HRTEM lattice images. GPA is the
standard method: select two non-collinear Bragg spots in FFT, extract
phase maps, differentiate to get strain components (exx, eyy, exy,
rotation). Output as colormapped overlays with quantitative strain values.

This was listed as excluded in Phase 3 ("plugin-level complexity"), but it
is the single most-requested advanced analysis feature for HRTEM users
and is feasible without toolboxes --- the core math is FFT masking +
phase extraction + numerical gradient, all available via built-ins.

**Reference tool:** DM GPA plugin; Fiji GPA plugin; STEM_CELL; CrysTBox.

**Touches:**
- `+imaging/geometricPhaseAnalysis.m` (new) --- core algorithm: mask FFT
  around Bragg spot, inverse FFT, extract phase via `angle()`, unwrap
  phase (1D unwrap per row then column, or quality-guided), compute strain
  from `gradient()`.
- `Fermion.m` --- "GPA..." button opening a dialog for spot
  selection, mask radius, and strain component display. Reuses FFT display
  and lattice spot selection from Feature 1.

**Effort:** ~300 lines (+imaging) + ~150 lines (GUI).

**Implementation approach:**
1. Compute FFT of HRTEM image.
2. User selects two Bragg spots g1, g2 (share UI with Feature 1).
3. For each g, apply soft circular mask (Butterworth, reuse existing
   `butterworthFilter`), shift to origin, inverse FFT.
4. Extract phase: `P_g = angle(ifft2(masked))`.
5. Phase unwrap: MATLAB's built-in `unwrap` along rows, then columns
   (simple but sufficient for smooth strain fields; no toolbox needed).
6. Compute displacement: solve `u = [g1; g2] \ [P_g1; P_g2]` pixel-wise.
7. Strain from `[dudx, dudy] = gradient(u)`: exx, eyy, exy, rotation.
8. Display strain maps as colormapped overlays (diverging colormap
   centered at zero). Colorbar shows strain values.
9. Export strain maps as TIFF or CSV.

**Risk:** Phase unwrapping quality depends on image quality. The
row-then-column approach may produce artifacts at grain boundaries or
defects. A quality-guided unwrapper would be better but is ~200 extra
lines. Start with the simple approach and note the limitation.

---

### 4. Surface Roughness Statistics (Gwyddion Parity)

Compute standard surface roughness parameters from image intensity
(treated as height): Ra (arithmetic mean), Rq (RMS), Rz (max peak-to-
valley), Rsk (skewness), Rku (kurtosis), and projected surface area
ratio. These are the standard metrics for AFM/SPM images and SEM
topography-contrast images. Display results in a statistics panel and
export to CSV.

**Reference tool:** Gwyddion "Statistical Quantities" dialog; IMOD
surface analysis; NanoScope Analysis.

**Touches:**
- `+imaging/surfaceRoughness.m` (new) --- accepts 2D matrix + pixel
  calibration, returns struct with Ra, Rq, Rz, Rsk, Rku, bearing ratio
  curve.
- `Fermion.m` --- "Roughness..." button (Process section), results
  dialog, optional ROI-restricted computation (reuse ROI manager).

**Effort:** ~100 lines (+imaging) + ~80 lines (GUI).

**Implementation approach:**
1. Flatten image if requested (subtract best-fit plane via `\ ` operator
   on meshgrid coordinates --- ties into Feature 6).
2. Compute: `Ra = mean(abs(z - mean(z)))`, `Rq = std(z)`,
   `Rz = max(z) - min(z)`, skewness/kurtosis via moment formulas.
3. Bearing ratio curve: sort heights, plot cumulative distribution.
4. If pixel calibration available, compute projected surface area via
   triangulation of the height grid.
5. Display in a modal dialog with export button.

---

### 5. Interface Width Measurement (Line Scan Fitting)

Measure the width of an interface or boundary by fitting an error function
(erf) or sigmoid to a line profile across it. Common workflow: draw a
line across a heterointerface in cross-section TEM/STEM, fit the
intensity transition, report the interface width (10-90% or sigma).
Extends the existing line profile tool with quantitative fitting.

**Reference tool:** ImageJ "Analyze > Plot Profile" + manual fitting;
DM line profile with Gaussian fit; custom scripts.

**Touches:**
- `+imaging/fitInterfaceWidth.m` (new) --- fit erf/sigmoid to 1D profile
  data, return width (sigma and 10-90%), center position, R-squared.
- `Fermion.m` --- "Fit Interface" button in the line profile result
  panel. Overlays the fit curve on the profile plot. Reports width in
  calibrated units.

**Effort:** ~80 lines (+imaging) + ~60 lines (GUI).

**Implementation approach:**
1. After drawing a line profile (existing), user clicks "Fit Interface".
2. Initial guess: center = midpoint of profile, width = 1/4 of profile
   length, amplitude = max - min.
3. Fit `y = a * erf((x - x0) / (sigma * sqrt(2))) + b` using
   `fminsearch` (built-in, no toolbox).
4. Report sigma, 10-90% width (= 2.563 * sigma), and R-squared.
5. Overlay the fit curve on the profile axes.

---

## Tier 2 --- Moderate Value, Low-to-Moderate Effort

### 6. Plane Leveling / Background Subtraction

Subtract a best-fit polynomial surface (1st, 2nd, or 3rd order) from the
image. Essential preprocessing for AFM/SPM data where sample tilt produces
a large intensity gradient. Also useful for correcting uneven illumination
in SEM images.

**Reference tool:** Gwyddion "Level Data" (plane, polynomial); IMOD
"flatten"; NanoScope "Plane Fit".

**Touches:**
- `+imaging/planeLevel.m` (new) --- fit and subtract polynomial surface
  from 2D image.
- `Fermion.m` --- "Level..." button in Process section with order
  dropdown (1st/2nd/3rd). Undo-supported.

**Effort:** ~60 lines (+imaging) + ~40 lines (GUI).

**Implementation approach:**
1. Build coordinate matrices `[X, Y] = meshgrid(1:cols, 1:rows)`.
2. Flatten image and coordinates to column vectors.
3. Construct polynomial design matrix (order 1: `[1, x, y]`;
   order 2: `[1, x, y, x^2, xy, y^2]`; etc.).
4. Solve least-squares: `coeffs = designMatrix \ imgFlat`.
5. Subtract fitted surface from original image.
6. Push undo before applying.

---

### 7. Rich Text Labels (Calibrated Annotations)

Extend existing text annotations with font size control, bold/italic,
background box, and automatic calibrated position reporting. When placing
a label, its position in calibrated units (nm, um) is stored. Labels can
include subscripts/superscripts using TeX interpreter (MATLAB built-in
LaTeX subset).

**Reference tool:** ImageJ text tool with font options; DM annotation
text; Gwyddion text overlay.

**Touches:**
- `Fermion.m` --- enhance existing `'annotation'` capture mode with
  a font-properties mini-panel (size dropdown, bold toggle, background
  color). Store font properties in annotation struct.

**Effort:** ~80 lines (GUI only, extends existing annotation code).

**Implementation approach:**
1. When entering annotation mode, show a small inline panel: font size
   spinner (8-36), bold checkbox, background checkbox, color picker.
2. Create text object with `'Interpreter','tex'` so users can type
   `Fe_3O_4` and get subscripts.
3. Store font properties in the annotation struct alongside position and
   string.
4. Update export-with-overlays to preserve font properties when burning
   annotations into the image.

---

### 8. Tilt Series Navigator

For tomography tilt series loaded as a multi-frame TIFF or set of images:
display the tilt angle for each frame, allow sorting by angle, show a
sinogram (single row vs. tilt angle) for alignment verification, and
compute a simple back-projection preview. Bridges the gap between raw
data collection and full reconstruction in IMOD.

**Reference tool:** IMOD etomo tilt series viewer; SerialEM navigator;
Priism.

**Touches:**
- `Fermion.m` --- extend stack navigator panel with "Tilt Series"
  mode. Tilt angle input (manual entry or parse from metadata). Sinogram
  display in a side panel. Simple back-projection button.
- `+imaging/backProject.m` (new) --- filtered back-projection from a
  sinogram (single-slice) using built-in `radon`-equivalent via manual
  implementation.

**Effort:** ~180 lines (+imaging) + ~120 lines (GUI).

**Implementation approach:**
1. User enters tilt angles (comma-separated or parsed from FEI TIFF
   metadata tag if available).
2. Sort frames by tilt angle; update stack navigator to show angle label.
3. Extract a sinogram: for a user-selected row index, extract that row
   from each frame, stack into [numFrames x width] matrix.
4. Display sinogram with tilt angle on Y axis.
5. Filtered back-projection: apply ramp filter in frequency domain to
   each sinogram row, then smear each filtered row across the
   reconstruction grid at its tilt angle (accumulate via rotation and
   addition). Use `interp2` for rotation rather than `imrotate` (no
   toolbox). Output is a 2D cross-section preview.
6. This is a preview only --- full 3D reconstruction is out of scope.

---

### 9. CTF Estimation (Defocus Measurement)

Estimate the contrast transfer function from the radial power spectrum
of a cryo-EM or TEM image. Fit the Thon ring positions to determine
defocus and astigmatism. Essential for assessing TEM imaging conditions
and data quality.

**Reference tool:** CTFFIND4; IMOD ctfplotter; Gatan GMS CTF module.

**Touches:**
- `+imaging/estimateCTF.m` (new) --- compute radial power spectrum,
  fit CTF model (voltage, Cs, defocus) to ring positions.
- `Fermion.m` --- "CTF..." button in Process section, dialog showing
  power spectrum with CTF fit overlay, defocus readout.

**Effort:** ~200 lines (+imaging) + ~100 lines (GUI).

**Implementation approach:**
1. Compute 2D power spectrum (reuse `computeFFT`), then radial average
   (reuse `radialProfile`).
2. CTF model: `CTF(k) = sin(pi * lambda * k^2 * (Df - 0.5 * Cs * lambda^2 * k^2))`
   where k = spatial frequency, Df = defocus, Cs = spherical aberration,
   lambda = electron wavelength from voltage.
3. User inputs voltage (kV) and Cs (mm) --- typical defaults: 200 kV,
   1.2 mm.
4. Fit defocus by minimizing residual between |CTF|^2 envelope and
   radial power spectrum using `fminsearch`.
5. For astigmatism: compute power spectrum in angular sectors, fit
   defocus per sector, report Df1, Df2, astigmatism angle.
6. Overlay CTF rings on the 2D power spectrum display.

**Risk:** Accuracy depends on image quality and whether Thon rings are
visible. This is a coarse estimation tool, not a replacement for
CTFFIND4. State this in the UI tooltip.

---

### 10. Measurement Macro Recorder

Record a sequence of measurement operations (line profile, distance,
angle, ROI stats, roughness, interface fit) as a replayable script.
Enables batch application of the same measurement protocol to multiple
images without manual clicking.

**Reference tool:** ImageJ macro recorder; DM scripting; Gwyddion
"Repeat Last" and module chaining.

**Touches:**
- `Fermion.m` --- "Record" toggle button in toolbar. When active,
  each measurement callback appends a command struct to a recording list.
  "Stop" saves to `.mat`. "Play" replays on current image or batch over
  all loaded images.

**Effort:** ~150 lines (GUI, no +imaging changes).

**Implementation approach:**
1. Define a command struct: `{action, params}` where action is
   `'lineProfile'`, `'distance'`, `'roiStats'`, `'roughness'`,
   `'interfaceFit'`, etc.
2. For coordinate-based measurements, store coordinates as fractions of
   image dimensions (so the macro works on images of different sizes) or
   as absolute pixel positions (user choice).
3. Recording: wrap each measurement callback to also append to
   `appData.macroRecording` when `appData.isRecording == true`.
4. Playback: iterate the command list, call the corresponding measurement
   function programmatically, collect results into a table.
5. Export results table to CSV (one row per image x measurement).
6. Save/load macros as `.mat` files containing the command list.

---

## Tier 3 --- Specialized / Advanced

### 11. Defect Line Counter (Dislocation Density)

Semi-automated counting of linear defects (dislocations, stacking faults)
in TEM images. User draws a rectangular ROI, the tool applies directional
filtering (Gabor-like via oriented `conv2` kernels) to enhance linear
features, then counts intersections with a grid of test lines (standard
stereological method for dislocation density estimation).

**Reference tool:** Manual counting in ImageJ with Cell Counter plugin;
Ham's intersection method (textbook stereology).

**Touches:**
- `+imaging/countDefectLines.m` (new) --- directional convolution +
  intersection counting on binary image.
- `Fermion.m` --- "Defect Count..." button, ROI selection, direction
  angle input, results dialog with density estimate.

**Effort:** ~150 lines (+imaging) + ~100 lines (GUI).

**Implementation approach:**
1. User selects ROI and preferred defect orientation (or "all").
2. Apply oriented derivative kernel (`conv2` with elongated Gaussian
   derivative at specified angle) to enhance linear features.
3. Threshold enhanced image (Otsu, reuse existing).
4. Overlay horizontal and vertical test lines at regular spacing.
5. Count intersections of binary defect mask with test lines.
6. Dislocation density: `rho = 2 * N / (n_lines * line_length * t)`
   where t = foil thickness (user input or default).
7. Report density in lines/m^2 with confidence interval from counting
   statistics.

---

### 12. Synced Annotation Pairs (Before/After Display)

Enhanced compare mode where annotations, measurements, and overlays are
mirrored between the two panels. Drawing a line profile on the left
panel automatically draws the same profile on the right. Essential for
comparing the same region before and after treatment, or comparing two
imaging conditions of the same area.

**Reference tool:** Fiji "Sync Windows" with ROI sync; DM "Link
Displays".

**Touches:**
- `Fermion.m` --- extend existing compare mode with a "Sync
  Annotations" toggle. Mirror measurement callbacks to both axes.

**Effort:** ~120 lines (GUI only).

**Implementation approach:**
1. Add a "Sync" checkbox to compare mode panel.
2. When synced, each measurement callback (line profile, distance,
   angle, ROI stats) executes on both axes using the same coordinates.
3. Results displayed side-by-side: left panel values vs. right panel
   values.
4. Line profiles plotted on the same axes (two curves) for direct
   comparison.
5. Coordinate mapping: if images have different pixel sizes, scale
   coordinates proportionally. If same calibration, use identical pixel
   coords.

---

### 13. Multi-class Threshold Segmentation

Extend the existing binary threshold to N-class segmentation. The user
defines 2-4 intensity ranges (via histogram markers or automatic
multi-Otsu), and each class is assigned a color. Produces a labeled
segmentation map. Useful for separating phases in BSE-SEM images (e.g.,
matrix, precipitate, porosity).

**Reference tool:** ImageJ "Auto Threshold" (multi-level); Fiji Trainable
Weka Segmentation (simplified version); Gwyddion "Mark by Threshold".

**Touches:**
- `+imaging/multiOtsu.m` (new) --- N-level Otsu threshold via exhaustive
  histogram search.
- `Fermion.m` --- extend threshold panel with class count spinner
  (2-4) and per-class color pickers. Display labeled overlay.

**Effort:** ~80 lines (+imaging) + ~100 lines (GUI).

**Implementation approach:**
1. Compute image histogram (256 bins).
2. For N classes, find N-1 thresholds that maximize between-class
   variance (extend existing Otsu implementation to multi-level by
   iterating over threshold combinations --- feasible for N<=4 with 256
   bins).
3. Create label map: `labelMap(img <= t1) = 1`, etc.
4. Display as colored overlay using a discrete colormap.
5. Report area fraction per class.
6. Export label map as indexed TIFF.

---

### 14. Calibrated Colorbar with Real Units

Replace the basic MATLAB colorbar with a custom colorbar overlay that
displays intensity values in real units (counts, nm height, strain %).
The colorbar is burned into exports and its position/size is
configurable. Currently the colorbar toggle just uses MATLAB's default
which is lost on image export and shows normalized [0,1] values.

**Reference tool:** Gwyddion (always shows calibrated colorbar); DM
"Data Bar"; ImageJ calibration bar.

**Touches:**
- `Fermion.m` --- replace colorbar toggle with a configurable
  colorbar overlay. Store intensity-to-unit mapping in appData.
- `+imaging/addColorbar.m` (new) --- render a colorbar + tick labels
  into a pixel strip that can be composited onto an image.

**Effort:** ~100 lines (+imaging) + ~80 lines (GUI).

**Implementation approach:**
1. User sets intensity unit label and mapping (linear: min/max values
   in real units; or from metadata if available).
2. Render colorbar as a narrow image strip with the active colormap.
3. Add tick marks and labels using the bitmap text renderer from
   Feature 2 (or `text` objects on axes).
4. Position: right side or bottom, configurable.
5. For export: composite the colorbar strip onto the image border.
6. For on-screen display: use a MATLAB axes overlay (lightweight).

---

### 15. Journal Export Presets

One-click export with journal-specific constraints: image width (single
column = 85 mm, double column = 170 mm), DPI (300 for halftone, 600 for
line art), file format (TIFF for most, EPS/PDF for vector), and
compression settings. Presets for common journals: Nature, Science, ACS,
Elsevier, APS, IUCr, Wiley.

**Reference tool:** No direct equivalent --- researchers do this manually.
Fiji "Bio-Formats Exporter" partially addresses format but not sizing.

**Touches:**
- `Fermion.m` --- "Journal Export..." menu item with preset dropdown
  and preview of final pixel dimensions. Reuses existing
  `plotting.saveFigure` and DPI control from Phase 2.

**Effort:** ~100 lines (GUI only; reuses existing export infrastructure).

**Implementation approach:**
1. Define preset structs: `name, widthMM, dpi, format, compression`.
   E.g., `{'Nature', 89, 300, 'tiff', 'lzw'}`.
2. Compute output pixel dimensions: `widthPx = widthMM / 25.4 * dpi`.
3. Resize image to target width (maintain aspect ratio) via `interp2`.
4. Apply scale bar sized for the output resolution.
5. If format is TIFF: `imwrite` with LZW compression.
   If PDF/EPS: route through `plotting.saveFigure`.
6. Show a preview dialog with final dimensions, file size estimate,
   and a "looks good" confirmation before saving.

---

## Tier 4 --- Quality-of-Life

### 16. Image Notepad / Lab Notebook Integration

Attach free-text notes to each loaded image. Notes are persisted in the
session file and optionally embedded as a TIFF tag on export. Researchers
often need to record imaging conditions, sample ID, or observations
alongside the image. Searchable across all loaded images.

**Reference tool:** DM "Image Info" / "Tags" panel; lab notebook software
integration.

**Touches:**
- `Fermion.m` --- collapsible "Notes" text area below the image list.
  Notes stored in `appData.datasets{i}.notes`. Search box filters images
  by note content.

**Effort:** ~80 lines (GUI only).

**Implementation approach:**
1. Add a `uitextarea` below the image list panel.
2. On image switch, save current note to `appData.datasets{i}.notes`,
   load new image's note.
3. On session save, notes are included in the `.mat` file.
4. On TIFF export, write note string to TIFF tag 270 (ImageDescription)
   via `Tiff` class.
5. Search: filter dataset list by `contains(notes, query)`.

---

### 17. Quick Crop to ROI

After drawing any ROI (rectangle, ellipse bounding box, polygon bounding
box), a "Crop to ROI" button appears that immediately crops the image
to that region. Currently cropping requires entering a separate crop mode
and drawing a new rectangle. This shortcut eliminates redundant clicking.

**Reference tool:** ImageJ "Image > Crop" (crops to current selection);
DM crop to ROI.

**Touches:**
- `Fermion.m` --- add "Crop to ROI" button that appears after any
  ROI measurement completes. Reads the bounding box of the last ROI
  from `appData`.

**Effort:** ~40 lines (GUI only).

**Implementation approach:**
1. After any ROI callback finishes, if a valid bounding box exists,
   enable a "Crop to ROI" button.
2. On click: extract bounding box `[r1, r2, c1, c2]` from the last ROI.
3. Crop: `appData.rawPixels = appData.rawPixels(r1:r2, c1:c2, :)`.
4. Push undo before cropping.
5. Update calibration if propagation (Phase 3 Feature 14) is active
   (origin shifts, scale unchanged).

---

### 18. Image Comparison Flicker Mode

In compare mode, add a "Flicker" toggle that rapidly alternates between
left and right images on a single set of axes. Useful for detecting
subtle differences (drift, damage, phase changes) that are hard to see
in side-by-side layout. Adjustable flicker rate (0.5-5 Hz).

**Reference tool:** ImageJ "Image > Stacks > Animation" on a two-frame
stack; "Blink Comparator" (astronomy origin, used in EM for dose series).

**Touches:**
- `Fermion.m` --- "Flicker" toggle in compare mode panel. Uses a
  MATLAB timer to alternate `CData` on a single axes.

**Effort:** ~60 lines (GUI only).

**Implementation approach:**
1. When Flicker is toggled on in compare mode, hide the right axes and
   expand the left axes to full width.
2. Create a `timer` object with `period = 1/flickerRate`.
3. Timer callback alternates `ax.Children(1).CData` between left and
   right images.
4. If images are different sizes, resize the smaller to match (nearest
   neighbor, via indexing).
5. Stop timer and restore two-panel layout when Flicker is toggled off
   or compare mode exits.
6. Slider for flicker rate (0.5-5 Hz).

---

### 19. Persistent Measurement Overlay Toggle

All measurements (distances, angles, profiles, ROI boxes) currently
remain visible until manually cleared. Add a toggle to show/hide all
measurement overlays without deleting them, and a per-measurement
visibility checkbox in the measurement table. This lets users
declutter the view while retaining data.

**Reference tool:** ImageJ ROI Manager show/hide; DM annotation
visibility toggle; Gwyddion mask show/hide.

**Touches:**
- `Fermion.m` --- "Show Measurements" toggle button; per-row
  visibility checkbox in measurement table. Store overlay handles in
  the measurement struct.

**Effort:** ~60 lines (GUI only).

**Implementation approach:**
1. Each measurement struct gains a `.visible` field and a `.handles`
   cell array of graphics objects (lines, text, markers).
2. "Show/Hide All" button sets `Visible` property on all handles.
3. Per-measurement checkbox in the table: toggling updates that
   measurement's handle visibility.
4. Measurement data is always retained regardless of visibility.

---

### 20. Contextual Right-Click Menu

Add a context menu (right-click on image) with the most common actions:
auto-contrast, copy to clipboard, save crop, measure distance, zoom to
fit, pixel inspector at cursor position. Reduces mouse travel to the
toolbar for frequent operations.

**Reference tool:** ImageJ right-click menu; DM right-click context
options; standard desktop application convention.

**Touches:**
- `Fermion.m` --- create `uicontextmenu` attached to the image
  axes. Menu items call existing callbacks.

**Effort:** ~50 lines (GUI only).

**Implementation approach:**
1. Create `uicontextmenu` with items mapped to existing callbacks.
2. Attach to the image axes via `ax.ContextMenu`.
3. Menu items: "Auto Contrast", "Copy to Clipboard", "Save Region...",
   "Measure Distance", "Line Profile Here", "Pixel Inspector",
   "Zoom to Fit", separator, "Reset View".
4. For position-dependent items ("Pixel Inspector", "Line Profile
   Here"), capture click position from `ax.CurrentPoint` before
   dispatching to the callback.

---

## Implementation Order Recommendation

The features have dependencies that suggest this build order:

1. **Feature 6** (Plane Leveling) --- standalone, prerequisite for
   roughness analysis.
2. **Feature 4** (Surface Roughness) --- uses plane leveling for
   preprocessing.
3. **Feature 5** (Interface Width) --- extends existing line profile;
   standalone.
4. **Feature 1** (Lattice Overlay) --- prerequisite for GPA.
5. **Feature 3** (GPA) --- depends on lattice spot selection from
   Feature 1.
6. **Feature 13** (Multi-class Threshold) --- extends existing threshold
   code.
7. **Feature 2** (Figure Panel Builder) --- large but standalone;
   schedule based on demand.
8. **Feature 14** (Calibrated Colorbar) --- useful with roughness/strain
   maps.
9. **Features 15-20** (Tier 4 QoL) --- implement in any order as time
   permits.
10. **Features 8-9** (Tilt Series, CTF) --- specialized; implement when
    cryo-EM users request them.

---

## Estimated Totals

| Tier | Features | New +imaging/ lines | GUI lines | Total |
|------|----------|-------------------|-----------|-------|
| Tier 1 | 5 | ~930 | ~610 | ~1540 |
| Tier 2 | 5 | ~140 | ~490 | ~630 |
| Tier 3 | 5 | ~330 | ~400 | ~730 |
| Tier 4 | 5 | 0 | ~290 | ~290 |
| **Total** | **20** | **~1400** | **~1790** | **~3190** |

Note: `Fermion.m` is currently ~8800 lines. Phase 4 GUI additions
(~1790 lines) would push it to ~10600 lines. Consider extracting
measurement callbacks or the figure-builder dialog into separate files
(e.g., `Fermion_figureBuilder.m` as a helper function) if the file
becomes unwieldy.

---

## New Files Summary

| File | Feature | Purpose |
|------|---------|---------|
| `+imaging/latticeMeasure.m` | 1 | FFT spot to real-space lattice vectors |
| `+imaging/buildFigurePanel.m` | 2 | Multi-panel figure assembly |
| `+imaging/geometricPhaseAnalysis.m` | 3 | Strain mapping from HRTEM |
| `+imaging/surfaceRoughness.m` | 4 | Ra, Rq, Rz, Rsk, Rku statistics |
| `+imaging/fitInterfaceWidth.m` | 5 | Erf/sigmoid fit for interface profiles |
| `+imaging/planeLevel.m` | 6 | Polynomial surface subtraction |
| `+imaging/backProject.m` | 8 | Filtered back-projection (preview) |
| `+imaging/estimateCTF.m` | 9 | CTF fitting from power spectrum |
| `+imaging/countDefectLines.m` | 11 | Stereological dislocation counting |
| `+imaging/multiOtsu.m` | 13 | Multi-level Otsu threshold |
| `+imaging/addColorbar.m` | 14 | Rendered colorbar strip for export |
