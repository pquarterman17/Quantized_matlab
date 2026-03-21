# emViewerGUI Feature Plan

## Tier 1 — High-Value, Moderate Effort

- [x] **1. Image Stack Navigator** — Z-stack / multi-page TIFF frame slider, play/pause animation, max-intensity projection (MIP)
- [x] **2. Histogram Equalization / CLAHE** — Contrast-Limited Adaptive Histogram Equalization for uneven illumination; no-toolbox implementation
- [x] **3. ROI Statistics** — Draw rectangle, get mean/std/min/max/area + mini-histogram
- [x] **4. Polyline Measurement** — Multi-point distance with total path length (double-click to finish)
- [x] **5. Angle Measurement** — Three-click: vertex + two rays, report angle in degrees

## Tier 2 — Moderate Value, Low-to-Moderate Effort

- [x] **6. Image Rotation & Flip** — 90/180/270 + horizontal/vertical flip via rot90/fliplr/flipud
- [x] **7. Pixel Calibration Override** — Manually set nm/px and unit for uncalibrated images
- [x] **8. Linked Zoom in Compare Mode** — Sync XLim/YLim between left and right panels
- [x] **9. Export with Overlays** — Burn scale bar, annotations, measurements into exported image
- [x] **10. Undo/Redo Stack** — Multi-level undo (cap ~5 entries) replacing single-level undo

## Tier 3 — Specialized / Advanced

- [x] **11. FFT Masking & Inverse FFT** — Draw masks on FFT to remove periodic noise, apply inverse
- [x] **12. Particle / Feature Counting** — Threshold + connected-component labeling + size distribution
- [x] **13. Drift Correction / Image Alignment** — Cross-correlation-based stack alignment
- [x] **14. Color Overlay / Channel Merge** — Assign colormaps to two images and blend
- [x] **15. Batch Export** — Export all loaded images with current settings to a folder

## Tier 4 — Quality-of-Life

- [x] **16. Keyboard Shortcuts** — Ctrl+O, Ctrl+S, +/- zoom, A auto-contrast, F fit, Ctrl+Z undo
- [x] **17. Drag-and-Drop** — DropFcn on uifigure for file loading
- [x] **18. Recent Files List** — Persist last 5-10 paths to MAT file
- [x] **19. Colorbar Toggle** — Show/hide calibrated colorbar
- [x] **20. Copy to Clipboard** — One-click copy current view to system clipboard
