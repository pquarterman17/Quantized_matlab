# +boson/ — Extracted Boson Subsystems

Functions extracted from the monolithic `Boson.m` to reduce its size and improve maintainability. Boson delegates to these functions; they can also be called independently for scripting and testing.

## Functions

| Function | Description | Called by |
|----------|-------------|-----------|
| `applyCorrections` | Core corrections pipeline (trim, offset, background, smooth, normalize, derivative) | `Boson.onApplyCorrections`, `scripts.applyAnalysisTemplate` |
| `correctionParams` | Build params struct from dataset + UI widget values | `Boson.onApplyCorrections` |
| `curveFitting` | General curve fitting dialog (15 built-in models, fminsearch) | `Boson.onOpenCurveFitDialog` |
| `graphDigitizer` | Graph digitizer: extract data from graph screenshots | `Boson.onOpenDigitizer` |
| `figureBuilder` | Advanced Figure Builder (10 figure types, journal templates) | `Boson.onAdvancedFigureBuilder` |

## Design Pattern

Each extracted function:
- Creates its own `uifigure` (for dialog functions) or is a pure function (for pipeline functions)
- Receives data/state as explicit arguments instead of accessing closure variables
- Uses callbacks (`StatusFcn`, `LoadCallback`) to communicate results back to the main GUI
- Can be tested independently of the GUI

## Usage (standalone)

```matlab
% Apply corrections programmatically
params = struct('xOff', 0, 'yOff', 0, 'bgSlope', 0, 'bgInt', 0, ...
    'xTrimMin', NaN, 'xTrimMax', NaN, ...
    'smoothEnabled', true, 'smoothWindow', 5, 'smoothMethod', 'gaussian', ...
    'normMethod', 'None', 'derivativeMode', 'None', ...
    'isNeutron', false, 'isMag', false);
corrData = boson.applyCorrections(rawData, params);
```
