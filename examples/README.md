# Examples

Runnable MATLAB scripts demonstrating common workflows. Each script is
self-contained — it resolves the project root automatically and can be run
from any working directory.

## Prerequisites

```matlab
cd G:\Onedrive\Coding\git\quantized_matlab
setupToolbox          % add packages to MATLAB path (once per session)
```

## Scripts

| Script | What it shows |
|--------|---------------|
| `example_vsm_magnetometry.m` | Import QD VSM/DynaCool `.dat` files; M vs H plot; extract Hc and Ms; unit conversion (Oe→T, emu→A·m²); multi-dataset normalised comparison |
| `example_xrd_analysis.m` | Import Rigaku `.raw` and PANalytical `.xrdml`; Gaussian smoothing; linear background removal; peak detection; Scherrer crystallite size from FWHM; CSV export; batch conversion |
| `example_rsm.m` | Import a PANalytical 2D area-detector `.xrdml` (RSM); angle-space and Q-space heatmaps; H-cut and V-cut 1D line extractions; integrated 1D fallback profile |
| `example_neutron_reflectometry.m` | Import NCNR `.refl`, `.datA/.datD` (polarised); R vs Q and R×Q⁴ plots; spin asymmetry SA = (R++ − R--) / (R++ + R--); Kiessig fringe FFT for film thickness |
| `example_generic_csv.m` | Import generic CSV/Excel with auto-detection; `utilities.normalize`, `utilities.smoothData`, `utilities.convertUnits`; round-trip verification |
| `example_batch_import.m` | `scripts.batchImport` on a mixed directory tree; filter by parser type; waterfall plot; export summary table |

## Running

```matlab
% From the project root:
run examples/example_vsm_magnetometry
run examples/example_xrd_analysis
run examples/example_rsm
run examples/example_neutron_reflectometry
run examples/example_generic_csv
run examples/example_batch_import
```

Or open any script in the MATLAB Editor and press **Run** (F5).

## Test data

Examples use files from `+test_datasets/` included in the repository:

| Directory | Contents |
|-----------|----------|
| `+test_datasets/QuantumDesign/` | Quantum Design VSM `.dat` files (M vs H) |
| `+test_datasets/rigaku/` | Rigaku SmartLab binary `.raw` files (XRD/XRR) |
| `+test_datasets/XRDML/` | PANalytical `.xrdml` files + CSV exports |
| `+test_datasets/NCNR/` | NCNR reflectometry `.refl`, `.datA/.datD`, `.pnr` files |
