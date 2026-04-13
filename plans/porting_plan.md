# Porting Plan: thin_film_toolkit — Standalone Open-Source Scientific Toolkit

> Architecture plan for porting ~63,000 lines of MATLAB to an open-source,
> multi-language package with best-in-class UI. Evaluated independently — not
> constrained by refl1d/reductus choices.

---

## 1. What We're Porting

| Module | MATLAB lines | Complexity | Notes |
|--------|-------------|------------|-------|
| `+parser/` (25 parsers) | ~54,885 | Medium | Text + binary format readers |
| `BosonPlotter.m` + `+bosonPlotter/` | ~21,000 | Very High | Main GUI: import, correct, plot, peaks, fitting, figure builder |
| `Fermion.m` | ~11,877 | Very High | EM image viewer: filters, FFT, measurements, EELS, EDS, diffraction |
| `+imaging/` | ~20,270 | High | Image processing, EELS, diffraction indexing, EDS quant |
| `DiraCulator.m` + `+calc/` | ~10,500 | Low-Medium | 18-panel calculator, pure math |
| `+fitting/` | ~1,940 | Medium | 23 models, optimizer, equation parser, batch fitting |
| `+utilities/` | ~2,000 | Low | Pure helper functions |
| `tests/` | ~49,411 | N/A | Validation suite (port as acceptance tests) |
| **Total** | **~63,000** | | |

### Architecture Properties Worth Preserving

- **Functional style** — pure functions returning structs, no deep OOP hierarchies
- **Unified data contract** — all parsers produce identical schema
- **Pipeline architecture** — parse → correct → plot, each stage independent
- **Packages don't depend on each other** — parsers, imaging, calc, fitting are independent

---

## 2. Framework Evaluation (Standalone)

### Option A: Python + Tauri (Rust shell + Web frontend)

Python backend as a managed subprocess; Tauri provides native OS window with Vue 3/TypeScript frontend.

| Dimension | Assessment |
|-----------|------------|
| **UI quality** | Excellent — full web stack (Vue 3, Plotly.js, HTML5 Canvas) in a native window |
| **Desktop feel** | Best of all options — native title bar, file dialogs, menus, system tray, auto-update |
| **Bundle size** | Small (~5-10 MB for Tauri shell vs ~150 MB for Electron) |
| **Distribution** | Single installer per platform; Tauri has built-in updater |
| **Backend** | Python with NumPy/SciPy — gold standard for scientific computing |
| **IPC** | Tauri sidecar manages Python subprocess; communicate via stdin/stdout JSON-RPC or local HTTP |
| **Complexity** | Moderate — Rust shell is thin (just window + IPC), not algorithmic |
| **Offline** | Fully offline, no browser dependency |

**Strengths:** Feels like a real desktop app. Tiny bundle. Native OS integration (file associations, drag-and-drop from Explorer). No "opening a browser tab" UX.
**Weaknesses:** Python bundling (must ship Python runtime or require user install). Tauri sidecar IPC adds a layer. Rust toolchain needed for build.

### Option B: Electron + Python backend

Similar to Tauri but uses Chromium instead of OS webview.

| Dimension | Assessment |
|-----------|------------|
| **UI quality** | Same as Tauri (same web frontend) |
| **Desktop feel** | Good — native window, but heavier than Tauri |
| **Bundle size** | Large (~150-200 MB due to bundled Chromium) |
| **Distribution** | Well-established (VS Code, Slack, etc. use Electron) |
| **Backend** | Python subprocess, same as Tauri |
| **Maturity** | Very mature ecosystem, more docs/examples than Tauri |

**Strengths:** Most battle-tested desktop web-app framework. Huge community.
**Weaknesses:** Bloated bundle. Higher memory usage. Feels overkill when Tauri exists.

### Option C: Python + Vue 3 (local web server, browser-based)

Python HTTP/WebSocket server serving a Vue 3 SPA. User opens localhost in their browser.

| Dimension | Assessment |
|-----------|------------|
| **UI quality** | Same web stack as A/B |
| **Desktop feel** | Worst — opens a browser tab, not a dedicated window |
| **Distribution** | Simplest — `pip install` + `tftk` command |
| **Bundle size** | Smallest — no shell binary at all |
| **No-install option** | Can run from `uvx` or Docker without installing |

**Strengths:** Simplest to develop and distribute. No Rust/Node toolchain.
**Weaknesses:** Browser tab UX feels unprofessional. Can't register file associations. No system tray. User might accidentally close tab.

### Option D: Python + PySide6 (Qt)

Full native desktop app with Qt widgets.

| Dimension | Assessment |
|-----------|------------|
| **UI quality** | Good for forms/tables; weak for interactive plots |
| **Plotting** | matplotlib widget (slow, non-interactive) or pyqtgraph (fast but limited) — neither matches Plotly.js |
| **Image viewer** | Qt has solid QGraphicsView for images, but building FFT masking + annotations is harder |
| **Distribution** | `pip install` works; Qt binaries ~80 MB |

**Strengths:** True native feel. No web tech complexity. Single language.
**Weaknesses:** This is what was tried before and felt "clunky." Plot interactivity can't match web-based Plotly. Complex custom widgets (figure builder, digitizer) are harder in Qt than in HTML/CSS.

### Option E: Python backend + TypeScript/React or Vue desktop via Tauri

Same as Option A but with React instead of Vue.

**Verdict:** Vue vs React is a style preference. Vue has simpler template syntax, better for a physicist-developer. React has larger ecosystem. Either works. Vue recommended for consistency and learning curve.

---

### RECOMMENDATION: Option A — Python + Tauri + Vue 3

**Rationale:**

1. **Best UX** — native desktop window with full web rendering. Users double-click an icon, get a real app. No browser tabs.
2. **Best plotting** — Plotly.js in the web frontend handles 2D, 3D, contour, heatmap, publication export. Nothing in the native widget world comes close.
3. **Best backend** — Python with NumPy/SciPy/lmfit is the gold standard for scientific computing. No compromises.
4. **Small footprint** — Tauri shell is ~5 MB vs Electron's ~150 MB.
5. **Modern** — Tauri is production-ready (v2 stable), used by real apps, actively developed.
6. **File associations** — can register `.xrdml`, `.raw`, `.dat` etc. so double-clicking a data file opens the toolkit.
7. **Auto-update** — Tauri has built-in update checking.

**The multi-language split:**
- **Rust** — thin shell only (window, menus, file dialogs, Python process management). ~500 lines.
- **Python** — all scientific computation (parsers, fitting, imaging, corrections, calculators). ~15,000 lines.
- **TypeScript/Vue 3** — all UI rendering and interaction. ~10,000 lines.

---

## 3. Architecture

### 3.1 Process Model

```
┌─────────────────────────────────────────────┐
│  Tauri Shell (Rust)                         │
│  - Native window + menus                    │
│  - Manages Python sidecar process           │
│  - File dialog / drag-drop → sends to Vue   │
│  - Auto-updater                             │
│                                             │
│  ┌─────────────────────────────────────────┐ │
│  │  Vue 3 Frontend (TypeScript)            │ │
│  │  - Plotly.js charts                     │ │
│  │  - HTML5 Canvas (EM image viewer)       │ │
│  │  - Pinia state stores                   │ │
│  │  - Communicates with Python via         │ │
│  │    JSON-RPC over localhost HTTP/WS       │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
          ↕  JSON-RPC / WebSocket
┌─────────────────────────────────────────────┐
│  Python Backend (sidecar process)           │
│  - FastAPI server on localhost:random_port  │
│  - Parsers, fitting, imaging, calc          │
│  - Holds all data in memory (datasets[])    │
│  - WebSocket for progress events            │
└─────────────────────────────────────────────┘
```

### 3.2 Communication: JSON-RPC over HTTP + WebSocket

- **HTTP POST** for request/response operations (import file, fit curve, get data)
- **WebSocket** for streaming (fit progress, batch processing updates, long operations)
- **Binary data** via msgpack or base64-encoded numpy arrays for large transfers

```
Frontend                              Backend (FastAPI)
   |                                      |
   |-- POST /api/import_file ----------->|  parse file, add to datasets[]
   |<--- {index, metadata, plotData} ----|
   |                                      |
   |-- POST /api/detect_peaks ---------->|  run findPeaksRobust
   |<--- {peaks: [...]} ----------------|
   |                                      |
   |-- WS: fit_all_peaks --------------->|  long-running fit
   |<--- WS: {progress: 0.3} -----------|  progress updates
   |<--- WS: {progress: 0.7} -----------|
   |<--- WS: {result: {...}} -----------|  final result
```

### 3.3 Repository Structure

```
thin-film-toolkit/
├── pyproject.toml                    # Python package config (uv)
├── src-tauri/                        # Tauri shell (Rust)
│   ├── Cargo.toml
│   ├── src/
│   │   └── main.rs                   # ~300 lines: window, menus, sidecar mgmt
│   └── tauri.conf.json               # window config, sidecar definition
│
├── src/                              # Vue 3 frontend (TypeScript)
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── src/
│       ├── main.ts
│       ├── App.vue
│       ├── router.ts                 # /plotter, /emviewer, /calculator
│       ├── api/
│       │   └── client.ts             # JSON-RPC + WebSocket client
│       ├── stores/                   # Pinia state
│       │   ├── datasets.ts
│       │   ├── emviewer.ts
│       │   └── calculator.ts
│       ├── components/
│       │   ├── common/
│       │   │   ├── PlotlyChart.vue
│       │   │   ├── DataTable.vue
│       │   │   ├── FileDropZone.vue
│       │   │   └── CollapsibleSection.vue
│       │   ├── plotter/
│       │   │   ├── PlotterView.vue
│       │   │   ├── DatasetList.vue
│       │   │   ├── CorrectionsPanel.vue
│       │   │   ├── PeakPanel.vue
│       │   │   ├── CurveFitDialog.vue
│       │   │   └── FigureBuilder.vue
│       │   ├── emviewer/
│       │   │   ├── EmViewerView.vue
│       │   │   ├── ImageCanvas.vue
│       │   │   ├── FilterPanel.vue
│       │   │   └── MeasureTools.vue
│       │   └── calculator/
│       │       ├── CalculatorView.vue
│       │       └── tabs/             # 13 calculator tab components
│       └── styles/
│           └── themes.ts
│
├── backend/                          # Python backend
│   └── thin_film_toolkit/
│       ├── __init__.py
│       ├── server.py                 # FastAPI app + WebSocket
│       ├── state.py                  # In-memory dataset store
│       ├── parsers/
│       │   ├── __init__.py           # resolve_parser() dispatch
│       │   ├── base.py               # DataStruct dataclass
│       │   ├── qdvsm.py
│       │   ├── xrdml.py
│       │   ├── bruker.py
│       │   ├── rigaku.py
│       │   ├── csv_generic.py
│       │   ├── ncnr.py
│       │   ├── sims.py
│       │   ├── dm3.py
│       │   └── ...
│       ├── corrections/
│       │   ├── pipeline.py
│       │   └── params.py
│       ├── fitting/
│       │   ├── models.py
│       │   ├── engine.py             # lmfit-based
│       │   ├── auto_guess.py
│       │   ├── peak_detect.py        # port of findPeaksRobust
│       │   ├── equation_parser.py
│       │   └── global_fit.py
│       ├── imaging/
│       │   ├── filters.py
│       │   ├── fft.py
│       │   ├── measurement.py
│       │   ├── eels.py
│       │   ├── diffraction.py
│       │   └── eds.py
│       ├── calc/
│       │   ├── crystal.py
│       │   ├── xray_neutron.py
│       │   ├── thin_film.py
│       │   ├── magnetic.py
│       │   ├── superconductor.py
│       │   ├── optics.py
│       │   ├── vacuum.py
│       │   └── electrochemistry.py
│       └── utilities/
│           ├── smooth.py
│           ├── normalize.py
│           ├── peak_find.py
│           └── export.py
│
└── tests/
    ├── backend/                      # pytest
    │   ├── test_parsers.py
    │   ├── test_fitting.py
    │   ├── test_imaging.py
    │   └── fixtures/                 # shared test data files
    └── frontend/                     # vitest
        └── components/
```

### 3.4 Unified Data Schema (Python)

```python
from dataclasses import dataclass, field
from typing import Any
import numpy as np

@dataclass
class DataStruct:
    """Unified data container — direct port of parser.createDataStruct()."""
    time: np.ndarray               # [N] x-axis values
    values: np.ndarray             # [N, M] data matrix
    labels: list[str]              # [M] channel names
    units: list[str]               # [M] unit strings
    metadata: dict[str, Any]       # source, parser_name, x_column_name, etc.

    def to_json(self) -> dict:
        """JSON-serializable for API transport."""
        return {
            "time": self.time.tolist(),
            "values": self.values.tolist(),
            "labels": self.labels,
            "units": self.units,
            "metadata": self.metadata,
        }
```

---

## 4. Phased Porting Plan

### Phase 1: Python backend core (months 1-3)

Port the foundation with no GUI. Ship as `pip install thin-film-toolkit` for
CLI/scripting use. Validates all backend logic before building the frontend.

| Task | Effort | Deliverable |
|------|--------|-------------|
| `DataStruct` + `resolve_parser()` | 2 days | Base schema + dispatch |
| Text parsers (CSV, QDVSM, PPMS, MPMS, LakeShore, NCNR) | 2 weeks | 10+ parsers |
| XML parsers (XRDML, Bruker BRML) | 1 week | 2 parsers |
| Binary parsers (Rigaku, Bruker raw, DM3/4, MRC, SER, BCF) | 2-3 weeks | 7 parsers |
| Utilities (smooth, normalize, derivative, peak detection) | 1 week | Core utilities |
| Corrections pipeline | 1 week | trim → offset → bg → smooth → norm → deriv |
| Fitting engine (lmfit wrapper, 23 models, auto-guess) | 2 weeks | Full fitting package |
| Calculator modules (13 tabs of pure math) | 2 weeks | All calc functions |
| Test suite (pytest, fixture files from MATLAB tests) | Throughout | ≥80% coverage |

**Milestone:** `from thin_film_toolkit.parsers import auto_import; data = auto_import("scan.xrdml")` works from Python.

### Phase 2: Tauri + Vue 3 BosonPlotter (months 3-6)

Build the primary GUI. The MATLAB version continues working during this phase.

| Task | Effort | Deliverable |
|------|--------|-------------|
| Tauri shell scaffolding (window, menus, sidecar) | 1 week | App launches, Python starts |
| FastAPI server + WebSocket | 1 week | API endpoints for import/plot/correct |
| Vue 3 scaffold (Vite, router, Pinia stores) | 1 week | App structure |
| DatasetList + FileDropZone + import flow | 1 week | Load files, see them listed |
| PlotlyChart + main plot view | 2 weeks | Interactive Plotly plot with zoom/pan |
| CorrectionsPanel (offset, bg, smooth, norm, trim) | 2 weeks | Full correction pipeline in GUI |
| PeakPanel (auto-detect, fit, table, decomposition) | 2-3 weeks | Peak analysis workflow |
| CurveFitDialog (model selection, bounds, results) | 2 weeks | General curve fitting |
| Export (PNG, SVG, CSV, clipboard) | 1 week | Publication-ready output |

**Milestone:** Can replace MATLAB BosonPlotter for the core workflow: import → correct → plot → peaks → fit → export.

### Phase 3: Advanced BosonPlotter + EM Viewer (months 6-9)

| Task | Effort | Deliverable |
|------|--------|-------------|
| FigureBuilder (multi-panel, waterfall, 3D surface) | 3-4 weeks | 10 figure types |
| Graph Digitizer | 1-2 weeks | Extract data from images |
| Advanced Analysis (integration, dataset math, FFT thickness) | 2 weeks | Advanced menu features |
| Imaging backend (filters, FFT, measurements) | 2-3 weeks | Python imaging pipeline |
| EmViewerView (Canvas-based image display + pan/zoom) | 2-3 weeks | Basic image viewer |
| MeasureTools (line profile, distance, angle, scale bar) | 2-3 weeks | Measurement overlay |
| FilterPanel + FFT masking | 2 weeks | Image processing controls |

**Milestone:** EM viewer handles basic image viewing, filtering, measurements.

### Phase 4: Feature parity + polish (months 9-12)

| Task | Effort | Deliverable |
|------|--------|-------------|
| EELS, EDS, diffraction analysis panels | 4-6 weeks | Advanced EM analysis |
| Calculator GUI (13 tabbed forms) | 2-3 weeks | Materials calculator |
| Session save/load (JSON-based) | 1 week | Persist state |
| Publication templates (APS, Nature, ACS styling) | 1-2 weeks | Journal-ready plots |
| Installer + auto-update | 1-2 weeks | Platform installers |
| Documentation | 2 weeks | User guide + API docs |

**Milestone:** Full feature parity. Archive MATLAB version.

---

## 5. Key Decisions

### Decision 1: Tauri over Electron

Tauri v2 is production-ready, uses the OS webview (no bundled Chromium), produces
~5 MB binaries vs Electron's ~150 MB, and has built-in auto-update, file
associations, and native dialogs. The only downside is needing the Rust toolchain
for builds, but the Rust code is ~300 lines of boilerplate.

### Decision 2: FastAPI over Flask/bumps

FastAPI provides async support, automatic OpenAPI docs, WebSocket support, and
type validation via Pydantic — all out of the box. It's the most popular modern
Python web framework and has excellent documentation. No coupling to any other
project.

### Decision 3: lmfit for fitting

`lmfit` wraps scipy.optimize and adds bounded parameters, error bars, composite
models, and a model registry. It matches the MATLAB fitting engine's feature set
without reimplementing it.

### Decision 4: Server-side image processing

EM images can be 4096×4096 × 16-bit (32 MB). All filtering/analysis stays on
the Python backend; the frontend receives display-resolution tiles only. This
matches professional image viewers (OMERO, QuPath) and avoids shipping OpenCV
WASM (~40 MB).

### Decision 5: Parsers as standalone package

Ship `thin-film-parsers` as an independent `pip install` package early in Phase 1.
This is immediately useful for scripting even if the GUI port stalls, and it
de-risks the project — the hardest backend work ships first.

---

## 6. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| EM Viewer interaction fidelity | High | HTML5 Canvas + SVG overlays; server-side analysis; accept some UX differences |
| Binary parser correctness | High | Byte-level roundtrip tests against MATLAB fixture files |
| Solo developer capacity | High | Parsers ship standalone; each phase is independently useful |
| Plotly vs MATLAB figure fidelity | Medium | Match data accuracy, not pixel-identical styling |
| Python bundling with Tauri | Medium | PyInstaller or embedded Python; or require `uv`/`pip` install |
| Tauri v2 maturity | Low | Tauri v2 is stable; fallback to Electron is straightforward (same frontend) |

---

## 7. Python Library Mapping

| MATLAB | Python |
|--------|--------|
| `fread()` / binary I/O | `struct.unpack()`, `numpy.fromfile()` |
| `textscan()` / `readtable()` | `pandas.read_csv()`, `numpy.loadtxt()` |
| `xmlread()` | `lxml.etree` or `xml.etree.ElementTree` |
| `fminsearch()` | `scipy.optimize.minimize(method='Nelder-Mead')` |
| `lsqcurvefit()` | `lmfit.minimize()` or `scipy.optimize.curve_fit()` |
| `conv2()` | `scipy.ndimage.convolve()` |
| `fft2()` / `fftshift()` | `numpy.fft.fft2()` / `numpy.fft.fftshift()` |
| `imread()` / `imwrite()` | `imageio.v3` or `PIL` |
| `uifigure` / `uiaxes` | Vue 3 components + Plotly.js |
| `uitable` | HTML table or AG Grid |
| `containers.Map` | Python `dict` |

## 8. Dependencies

```toml
# Python backend
[project.dependencies]
numpy = ">=1.24"
scipy = ">=1.10"
lmfit = ">=1.2"
pandas = ">=2.0"
openpyxl = ">=3.1"
lxml = ">=4.9"
imageio = ">=2.31"
scikit-image = ">=0.21"
fastapi = ">=0.100"
uvicorn = ">=0.23"
websockets = ">=11.0"

# Frontend
# vue@3, plotly.js, pinia, vue-router, vite, typescript

# Tauri shell
# tauri-cli v2, @tauri-apps/api
```
