# +scripts/ — Batch Workflows

## Functions

| Function | Description |
|----------|-------------|
| `batchImport` | Walk a directory, call `importAuto` on each supported file |
| `applyAnalysisTemplate` | Batch-apply a saved BosonPlotter template to files |
| `batchConvertXRD` | Batch-convert XRD files (.xrdml/.raw/.brml) to CSV |
| `quickPlot` | Auto-detect & plot one or more data files (type-aware defaults) |

## Usage

```matlab
% Batch import
results = scripts.batchImport('measurements/', 'Recursive', true);

% Analysis templates
results = scripts.applyAnalysisTemplate('xrd_template.mat', 'measurements/', ...
    'OutputDir', 'corrected/', 'Recursive', true);

% Batch XRD conversion
results = scripts.batchConvertXRD('measurements/', ...
    Format='standard', Intensity='both', OutputDir='csv_out/');

% Quick plot
scripts.quickPlot('scan.xrdml')
scripts.quickPlot({'vsm1.dat', 'vsm2.dat'}, 'Normalize', true)
scripts.quickPlot('refl.refl', 'SaveAs', 'reflectivity.pdf')
```

### quickPlot Options

`LogY`, `Normalize`, `SaveAs`, `Title`, `XLabel`, `YLabel`, `Layout` ('overlay'|'subplots'), `Theme`

Type-aware defaults: XRD → 2θ/Intensity, Magnetometry → Field/Moment, Reflectometry → Q/R (log), SIMS → Depth/Concentration.
