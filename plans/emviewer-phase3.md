# emViewerGUI Feature Plan — Phase 3 (DM Parity)

Gap analysis vs. Gatan Digital Micrograph (GMS 3/4). Excludes live acquisition,
microscope control, EELS/EDS spectroscopy, and scripting engine — those are
instrument-tied features outside emViewerGUI's scope as an offline viewer.

---

## Tier 1 — High-Value, Moderate Effort

### 1. Radial Profile from FFT / Diffraction
Compute radial average and radial max profiles from FFT or loaded diffraction
patterns. Essential for powder diffraction / amorphous film analysis (Thon rings,
nanocrystalline grain-size estimation). Output as 1D plot (spatial frequency vs.
intensity) with export to CSV.

**DM equivalent:** Live Radial Profile (Diff or FFT), radial-max display.
**Touches:** `emViewerGUI.m` (button in Process section + callback), `+imaging/radialProfile.m` (new).
**Effort:** ~120 lines. Polar resampling via `atan2`/`hypot` binning on FFT magnitude.

### 2. d-Spacing Measurement from FFT Spots
Click on a spot in FFT display → report d-spacing (Å or nm) using pixel
calibration. Two modes: (a) single-spot distance from center, (b) two-spot
pair distance. Overlay labeled circles on measured spots. Requires calibrated
pixel size to convert px⁻¹ → real-space distance.

**DM equivalent:** DiffTools "Point and Measure"; quick d-spacing readout.
**Touches:** `emViewerGUI.m` (new capture mode `'dspacing'`), measurement table integration.
**Effort:** ~100 lines. Core math: `d = 1 / (r_px * scale_per_px)`.

### 3. Morphological Operations (Binary Masks)
Erosion, dilation, opening, closing on thresholded/binary images. Critical
preprocessing step before particle counting — separates touching particles
(complement to watershed), removes noise speckles, fills holes.

**DM equivalent:** Erosion/Dilation/Opening/Closing on binary images.
**Touches:** `emViewerGUI.m` (buttons in Process section), `+imaging/morphOp.m` (new).
**Effort:** ~80 lines. Implement via `conv2` with structuring element (no toolbox).

### 4. Log / Sqrt / Power Contrast Transforms
Currently only linear contrast mapping. Add logarithmic, square-root, and
power-law (gamma is separate — this is a display transform applied before
the contrast window). Essential for diffraction patterns and FFTs where
dynamic range spans several orders of magnitude.

**DM equivalent:** Contrast palette transform options (linear/log/etc.).
**Touches:** `emViewerGUI.m` (dropdown in Contrast section), `displayImage()` pipeline.
**Effort:** ~40 lines. Insert transform step between raw→display mapping.

### 5. Arrow Annotations
Directional arrows for pointing out features in publications. Click start
point → drag to end → arrow with optional text label. Configurable color,
line width, head size. Persisted in annotations array; burned into export.

**DM equivalent:** Arrow annotation tool.
**Touches:** `emViewerGUI.m` (new capture mode `'arrow'`, annotation struct extension).
**Effort:** ~80 lines. Use `annotation('arrow', ...)` or `quiver` on axes.

---

## Tier 2 — Moderate Value, Low-to-Moderate Effort

### 6. Image Inversion
One-click invert: `img = max(img(:)) - img`. Simple but constantly needed
(bright-field ↔ dark-field, negative contrast for publication). Add to
Process section with undo support.

**DM equivalent:** Process > Invert.
**Touches:** `emViewerGUI.m` (button + callback). ~15 lines.

### 7. Unsharp Mask / Sharpen Filter
Sharpen = original + gain × (original − blurred). Single slider for
sharpening strength. Complementary to existing Gaussian blur.

**DM equivalent:** Process > Sharpen.
**Touches:** `emViewerGUI.m` (button), `+imaging/unsharpMask.m` (new). ~40 lines.

### 8. Width-Averaged Line Profile
Current line profile is 1-pixel-wide interpolation. Add configurable width
(3–50 px) that averages perpendicular to the profile direction. Reduces
noise in profiles across lattice fringes or interfaces.

**DM equivalent:** Line profile with adjustable integration width.
**Touches:** `emViewerGUI.m` (width spinner in profile dialog), `+imaging/lineProfile.m` (modify). ~50 lines.

### 9. Ellipse ROI
Add elliptical ROI tool alongside existing rectangle ROI. Report mean/std/
min/max/area statistics. Important for analyzing circular features (pores,
particles, beam spots) that rectangle ROI poorly captures.

**DM equivalent:** Ellipse ROI in ROI toolbox.
**Touches:** `emViewerGUI.m` (new capture mode `'roiellipse'`). ~80 lines.

### 10. Image Binning (Spatial Downsampling)
Bin N×N pixel blocks by summing or averaging. Reduces noise (sum mode) or
file size (average mode). Standard preprocessing for noisy STEM images.
Options: 2×2, 4×4, 8×8.

**DM equivalent:** Process > Bin.
**Touches:** `emViewerGUI.m` (button), `+imaging/binImage.m` (new). ~30 lines.

---

## Tier 3 — Specialized / Advanced

### 11. SER/EMI Format Import (FEI/ThermoFisher TIA)
Very common TEM data format from FEI (now ThermoFisher) microscopes. Binary
format with header + data blocks. Many university TEM labs export SER files
alongside DM3. Would significantly expand format coverage.

**DM equivalent:** Native SER/EMI import.
**Touches:** `+parser/importSER.m` (new), `+parser/resolveParser.m`, `emViewerGUI.m` file filter.
**Effort:** ~200 lines. Binary format is documented (FEI TIA specification).

### 12. MRC Format Import (Electron Tomography)
Standard format for cryo-EM and tomography data (CCP-EM, IMOD, RELION).
Simple binary header (1024 bytes) + raw data. Growing user base as cryo-EM
becomes mainstream in materials science.

**DM equivalent:** Native MRC import/export.
**Touches:** `+parser/importMRC.m` (new), dispatch registration.
**Effort:** ~150 lines. Well-documented header spec (MRC2014 standard).

### 13. Butterworth Bandpass Filter
Smooth frequency-domain filter without ringing artifacts (unlike hard FFT
masks). Parameterized by low/high cutoff radii and order. Preferred over
hard masks for lattice-fringe filtering and periodic noise removal.

**DM equivalent:** Butterworth filter for streak-free FFT.
**Touches:** `emViewerGUI.m` (dialog), `+imaging/butterworthFilter.m` (new). ~60 lines.

### 14. Calibration Propagation
Track pixel calibration through processing operations (crop, rotate, FFT,
bin). Currently calibration is lost after some transforms. Store calibration
in appData per-image and update it when operations change the spatial scale.

**DM equivalent:** Calibrations preserved through all operations.
**Touches:** `emViewerGUI.m` (all processing callbacks that change dimensions).
**Effort:** ~100 lines across many callbacks. Systematic but not complex.

### 15. Radial Integration for Powder Diffraction
Full azimuthal integration of 2D diffraction patterns to produce 1D powder
patterns (intensity vs. 2θ or d-spacing). Center-finding via symmetry.
Sector masks for partial integration. Export integrated pattern as CSV.

**DM equivalent:** Radial average with sector support; DiffTools integration.
**Touches:** `emViewerGUI.m`, `+imaging/azimuthalIntegrate.m` (new). ~150 lines.

---

## Tier 4 — Quality-of-Life

### 16. Polygon ROI
Free-form polygon ROI (click vertices, double-click to close). Statistics
computed over irregular region. Complements rectangle and ellipse ROIs for
grain boundaries, irregular features.

**Touches:** `emViewerGUI.m` (new capture mode `'roipoly'`). ~90 lines.

### 17. Line / Rectangle / Shape Annotations
Draw lines, rectangles, circles as persistent annotations (not measurements).
Configurable color, width, fill. For marking regions of interest in figures.

**DM equivalent:** Shape annotation tools.
**Touches:** `emViewerGUI.m` (annotation struct extension). ~80 lines.

### 18. Batch File Conversion (Format Transform)
Convert between formats: DM3→TIFF, TIFF→PNG, etc. with metadata preservation
where possible. Useful for archiving or sharing data with non-DM users.

**DM equivalent:** File > Batch Convert.
**Touches:** `emViewerGUI.m` (menu item), leverages existing parsers + `imwrite`. ~60 lines.

### 19. Colormap Editor / Custom LUT
Create or import custom colormaps beyond the built-in set. Important for
specific visualization needs (diverging colormaps for strain, cyclic for
phase). Simple UI: pick N color stops, interpolate between them.

**Touches:** `emViewerGUI.m` (preferences extension). ~100 lines.

### 20. Surface / 3D Visualization
Render image intensity as a 3D surface plot (`surf`/`mesh`) in a separate
figure. Useful for visualizing peak shapes, AFM-like topography, or
intensity distributions. Rotate/zoom via MATLAB's built-in 3D controls.

**DM equivalent:** Display as Surface Plot.
**Touches:** `emViewerGUI.m` (button + new figure creation). ~40 lines.

---

## Features Intentionally Excluded

These DM features are outside emViewerGUI's scope as an offline viewer:

| Feature | Reason |
|---------|--------|
| Live camera view / acquisition | Requires instrument connection |
| Microscope control (stage, lenses) | Requires instrument SDK |
| EELS / EDS spectroscopy | Requires dedicated spectrum viewer |
| 4D-STEM virtual aperture imaging | Requires 4D data cube infrastructure |
| DM scripting engine | MATLAB command line serves this role |
| Geometric Phase Analysis (GPA) | Plugin-level complexity; separate tool |
| In-situ time-series playback | Stack navigator partially covers this |
| Tomography reconstruction | Separate workflow (IMOD, ASTRA) |
| OLE embedding | Windows-specific legacy feature |

---

## Implementation Notes

- All new `+imaging/` functions must work without toolboxes (MATLAB built-ins only)
- New capture modes must be added to `finishCapture()` cleanup and `setToolsEnabled()`
- New parsers follow `createDataStruct()` contract and dual-registration rule
- Phase 3 features should be added to collapsible sections to avoid panel overflow
- Calibration propagation (Feature 14) should be implemented early — it's a prerequisite for accurate d-spacing and radial profile features
