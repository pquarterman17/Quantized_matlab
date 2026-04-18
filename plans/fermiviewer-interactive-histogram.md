# FermiViewer Interactive Histogram

Transform the histogram panel from a static display into a DM/Photoshop/ImageJ-style
interactive contrast tool with draggable handles, auto-contrast, and precise numeric entry.

**Status:** Active — Tier 3 items 8-10 remain
**Created:** 2026-04-15
**Updated:** 2026-04-17

---

## Context

### How the pieces fit together

The histogram lives in the right-hand tools panel of FermiViewer (`histAx`, a `uiaxes`
inside the collapsible "Histogram" section). It is tightly coupled to:

- **Contrast sliders** (`sldLow`, `sldHigh`) — the only way to adjust contrast today
- **Numeric edit fields** (`efLow`, `efHigh`) — synced to sliders
- **Display pipeline** — `rawPixels → filteredPixels → displayPixels → displayImg`

Key files and line ranges (approximate, will shift):

| Component | File | Lines |
|-----------|------|-------|
| Histogram axes init | `FermiViewer.m` | 713–739 |
| Contrast sliders/fields | `FermiViewer.m` | 584–616 |
| `updateHistogram()` — full rebuild on image load | `FermiViewer.m` | 4292–4329 |
| `refreshHistogramMarkers()` — fast marker update | `FermiViewer.m` | 10293–10310 |
| `updateHistogramLines()` — **dead code**, never called | `FermiViewer.m` | 4323–4354 |
| `onContrastChanged()` — slider callback | `FermiViewer.m` | 3486–3527 |
| `applyContrastPipeline()` — 4-stage display transform | `FermiViewer.m` | 10969–11012 |
| `setContrastAPI()` — programmatic contrast setter | `FermiViewer.m` | 4359–4420 |

### Data / control flow

```
User drags handle on histogram   (NEW — Tier 1)
        │
        ▼
sldLow.Value / sldHigh.Value  ◄── also set by slider drag, edit field, auto-contrast
        │
        ▼
onContrastChanged(src, ~)
  ├── enforces lo < hi
  ├── syncs efLow/efHigh
  ├── prepareDisplayBuffer() if needed
  ├── applyContrastPipeline(lo, hi)
  │     ├── contrast transform (log/sqrt/power)
  │     ├── linear stretch: (px - lo) / (hi - lo)
  │     ├── gamma correction
  │     └── invert
  └── refreshHistogramMarkers()
```

The histogram displays `rawPixels` (unfiltered) for a stable reference.
Contrast is applied to `filteredPixels` (post-filter).

### Dependency map

- Items 1, 2 are independent
- Item 3 (auto-contrast) is independent but benefits from item 1 (handle UX)
- Item 4 (gamma handle) requires item 1 (handle infrastructure)
- Item 5 (log-scale) is independent
- Item 6 (cleanup) is independent — do any time
- Item 7 (transfer ramp) requires items 1 + 4

---

## Tier 1 — High Impact

1. **Draggable black/white point handles on histogram** — ~~done~~ (2026-04-17) click histAx to drag nearest handle; cyan=low, magenta=high; shaded band between; `onHistAxesClick` + `startHistDrag` dispatcher
   - [x] Add `ButtonDownFcn` on `histAx` to detect clicks near a handle (within ~5px)
   - [ ] Implement drag loop via `WindowButtonMotionFcn` / `WindowButtonUpFcn` on `fig`
   - [ ] Sync `sldLow`/`sldHigh` and `efLow`/`efHigh` bidirectionally during drag
   - [ ] Enforce lo < hi constraint with minimum gap (reuse existing logic from `onContrastChanged`)
   - [ ] Replace cyan/magenta marker lines with visually distinct handles (thicker lines with
         small triangular indicators, or colored fill between handles)
   - [ ] Ensure handles update position when sliders are moved externally (slider still works)
   - [ ] Use `refreshHistogramMarkers()` as the single codepath for handle visuals (refactor if needed)

2. **Shaded contrast window on histogram** — ~~done~~ (2026-04-17, bundled with item 1) green patch at 12% alpha between lo/hi handles; updates on every slider change via `refreshHistogramMarkers()`

3. **Auto-contrast button** — ~~done~~ (2026-04-17) "Auto" button wired to existing `onAutoContrast` (2%/98% percentile); in histogram panel row 2 col 1

4. **Reset / Full Range button** — ~~done~~ (2026-04-17) "Reset" button wired to existing `onResetContrast`; in histogram panel row 2 col 2

---

## Tier 2 — Medium Impact

5. **Gamma / midtone handle** — ~~done~~ (2026-04-17) yellow dashed line at midtone position `lo + (hi - lo) * 0.5^(1/γ)`; click-drag computes `γ = ln(0.5)/ln(t)` where t is normalized position; wired to sldGamma and onGammaChanged

6. **Log-scale histogram toggle** — ~~done~~ (2026-04-17) "Log" toggle button in histogram panel; displays `log10(counts + 1)`; persists per session

7. **Scroll-wheel zoom on histogram** — ~~done~~ (2026-04-17) `WindowScrollCountFcn` scoped to histAx hit test; ±2% symmetric per tick; syncs sliders, fields, and display

---

## Tier 3 — Nice-to-Have

8. **Transfer function ramp overlay** — draw the input→output mapping curve on the
   histogram (diagonal line that bends with gamma), like ImageJ's ramp. Gives users
   immediate visual feedback about how pixel values map to display brightness.
   - [ ] Overlay a line on `histAx` showing the current transfer function
   - [ ] Updates on every contrast/gamma change
   - [ ] Use a secondary Y-axis or normalized overlay so it doesn't conflict with bar heights

9. **Click-drag-on-histogram for brightness/contrast** — ImageJ-style: horizontal drag
   shifts window center (brightness), vertical drag changes window width (contrast).
   - [ ] Detect drag on histogram background (not near a handle)
   - [ ] Horizontal delta → shift both lo and hi by the same amount
   - [ ] Vertical delta → widen or narrow the lo–hi gap symmetrically
   - [ ] This is powerful but not discoverable — add tooltip hint

10. **Clipping indicators** — color the histogram tails red/orange when pixels are being
    crushed (below lo or above hi), so users see at a glance how much data they're losing.
    - [ ] Overlay colored bars or tint the existing bars outside the [lo, hi] window
    - [ ] Update on every contrast change (fast path — just change bar colors, don't recompute)

11. **Delete dead code `updateHistogramLines()`** — ~~done~~ (2026-04-17, confirmed removed)

---

## Completed

- ~~**Draggable black/white point handles**~~ (2026-04-17) — click histAx to drag nearest handle; cyan=low, magenta=high; shaded band
- ~~**Shaded contrast window**~~ (2026-04-17) — green patch at 12% alpha between lo/hi handles
- ~~**Auto-contrast button**~~ (2026-04-17) — 2%/98% percentile auto
- ~~**Reset / Full Range button**~~ (2026-04-17) — wired to onResetContrast
- ~~**Gamma / midtone handle**~~ (2026-04-17) — yellow dashed line, click-drag gamma via γ = ln(0.5)/ln(t)
- ~~**Log-scale histogram toggle**~~ (2026-04-17) — log10(counts+1) toggle button
- ~~**Scroll-wheel zoom on histogram**~~ (2026-04-17) — ±2% symmetric per tick
- ~~**Delete dead code updateHistogramLines()**~~ (2026-04-17) — confirmed removed
