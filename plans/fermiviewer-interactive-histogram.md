# FermiViewer Interactive Histogram

Transform the histogram panel from a static display into a DM/Photoshop/ImageJ-style
interactive contrast tool with draggable handles, auto-contrast, and precise numeric entry.

**Status:** Active
**Created:** 2026-04-15
**Updated:** 2026-04-15

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

1. **Draggable black/white point handles on histogram** — add two vertical line handles
   on `histAx` that the user can click-drag to set the contrast window, matching DM's
   interaction model. Real-time image update as the handle moves.
   - [ ] Add `ButtonDownFcn` on `histAx` to detect clicks near a handle (within ~5px)
   - [ ] Implement drag loop via `WindowButtonMotionFcn` / `WindowButtonUpFcn` on `fig`
   - [ ] Sync `sldLow`/`sldHigh` and `efLow`/`efHigh` bidirectionally during drag
   - [ ] Enforce lo < hi constraint with minimum gap (reuse existing logic from `onContrastChanged`)
   - [ ] Replace cyan/magenta marker lines with visually distinct handles (thicker lines with
         small triangular indicators, or colored fill between handles)
   - [ ] Ensure handles update position when sliders are moved externally (slider still works)
   - [ ] Use `refreshHistogramMarkers()` as the single codepath for handle visuals (refactor if needed)

2. **Shaded contrast window on histogram** — fill the region between the two handles
   with a semi-transparent overlay (like DM's bright region) so the "mapped range" is
   instantly visible.
   - [ ] Draw a `patch()` or `area()` between lo and hi with low alpha (~0.15)
   - [ ] Update fill on every handle move or slider change
   - [ ] Visually indicate clipped regions (pixels below lo or above hi) with subtle tinting

3. **Auto-contrast button** — one-click optimal contrast (0.5% tail clip, matching DM's
   "Auto Survey" behavior).
   - [ ] Add "Auto" button to the histogram section header or inside the panel
   - [ ] Compute 0.5th and 99.5th percentiles of `rawPixels` (not filtered — matches histogram reference)
   - [ ] Set `sldLow`/`sldHigh` to those values and fire `onContrastChanged`
   - [ ] Button should be small (icon-sized) to fit in the compact panel

4. **Reset / Full Range button** — snap contrast to full data range (min/max of raw pixels).
   - [ ] Add "Reset" button next to Auto
   - [ ] Set sliders to `sldLow.Limits(1)` / `sldHigh.Limits(2)` — the data extremes

---

## Tier 2 — Medium Impact

5. **Gamma / midtone handle** — a third draggable handle between the black and white
   points that controls the gamma curve (midtone adjustment), matching Photoshop's center
   triangle. This lets users brighten shadows or darken highlights without moving the
   endpoints.
   - [ ] Draw a third handle line (or triangle) constrained between lo and hi
   - [ ] Map handle position to gamma value: center = 1.0 (linear), left = >1 (brighten), right = <1 (darken)
   - [ ] Wire to `appData.gamma` which `applyContrastPipeline` already uses (step 3)
   - [ ] Sync with any future gamma slider/field if added to the contrast section
   - [ ] Show numeric gamma value as tooltip or small label near the handle

6. **Log-scale histogram toggle** — EM data often has huge dynamic range; a linear
   histogram shows one tall spike and everything else at zero. A log-scale Y-axis makes
   the full distribution visible.
   - [ ] Add a small toggle button (e.g., "Log") in the histogram section
   - [ ] When active, display `log10(counts + 1)` instead of raw counts
   - [ ] Persist the toggle state per session (not per image — it's a viewing preference)
   - [ ] Update Y-axis label or title to indicate log scale

7. **Scroll-wheel zoom on histogram** — narrow or widen the contrast window by scrolling
   on the histogram (zoom centered on the current midpoint), matching DM's scroll behavior.
   - [ ] Add `WindowScrollWheelFcn` handler scoped to `histAx` hit test
   - [ ] Each scroll tick moves lo and hi symmetrically by ~2% of the current window width
   - [ ] Respect the lo < hi and data-range constraints
   - [ ] Syncs sliders, fields, and image display

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

11. **Delete dead code `updateHistogramLines()`** — this function (lines ~4323–4354) is
    never called and was superseded by `refreshHistogramMarkers()`. Remove it to reduce
    confusion.

---

## Completed

_(none yet)_
