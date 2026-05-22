# Fermion Feature Plan — Phase 2

## Tier 1 — High-Value, Moderate Effort

- [x] **1. Live Threshold Preview** — Slider with real-time binary preview overlay; feeds into particle counting
- [x] **2. Image Arithmetic** — Subtract, divide, ratio two loaded images (background subtraction, ratiometric)
- [x] **3. Otsu Auto-Threshold** — One-click optimal threshold via histogram-based Otsu method (no toolbox)
- [x] **4. ROI Manager** — Save multiple named ROIs with properties table (mean, std, area); export to CSV
- [x] **5. Session Save/Load** — Save/restore open images, contrast, overlays, annotations, measurements to .mat

## Tier 2 — Moderate Value, Low-to-Moderate Effort

- [x] **6. Recent Files Menu** — UI dropdown showing 10 recent files with one-click reload
- [x] **7. Export Resolution Control** — DPI spinner for overlay export and clipboard copy
- [x] **8. Thumbnail Grid View** — Contact sheet of all loaded images; click tile to jump
- [x] **9. Intensity Histogram Markers** — Draggable vertical lines on histogram for Low/High contrast
- [x] **10. Batch Crop Template** — Define crop region on one image, apply to all loaded images

## Tier 3 — Specialized / Advanced

- [x] **11. Watershed Segmentation** — Split touching particles via distance-transform + watershed (no toolbox)
- [x] **12. Measurement Table Export** — Aggregate all measurements into CSV-exportable table
- [x] **13. Gamma Curve Editor** — Non-linear intensity mapping with adjustable gamma
- [x] **14. Image Montage / Stitching** — Grid-based tiled SEM stitching with overlap cross-correlation
- [x] **15. Diffraction Ring Overlay** — Calibrated d-spacing rings for TEM diffraction patterns

## Tier 4 — Quality-of-Life

- [x] **16. Minimap / Overview Window** — Inset showing full image with zoomed viewport rectangle
- [x] **17. Pixel Inspector** — NxN pixel neighborhood display with actual intensity values
- [x] **18. Preferences Dialog** — Persistent settings: default colormap, percentiles, scale bar, export format
- [x] **19. Status Bar Progress** — Progress indicator for slow operations (CLAHE, batch export, alignment)
- [x] **20. Dual-Cursor Line Profile** — Live-updating draggable-endpoint line profile
