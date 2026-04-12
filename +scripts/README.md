# +scripts/ — Batch Workflows

## Functions

| Function | Description |
|----------|-------------|
| `batchImport` | Walk a directory, call `importAuto` on each supported file |
| `applyAnalysisTemplate` | Batch-apply a saved BosonPlotter template to files |
| `batchConvertXRD` | Batch-convert XRD files (.xrdml/.raw/.brml) to CSV |
| `quickPlot` | Auto-detect & plot one or more data files (type-aware defaults) |
| `batchPlot` | Apply a plot template to multiple datasets and save publication figures |
| `dataConnector` | Live file watcher — auto-reloads data when the source file changes |
| `generateReport` | Generate a formatted HTML or text analysis report from loaded datasets |

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

---

### batchPlot

Apply a publication template to every file in a directory (or a provided list) and save figures.

```matlab
% All XRD files in a folder → APS-style PDFs
results = scripts.batchPlot('measurements/', Template="aps", Format="pdf", OutputDir="figures/");

% Specific file list → PNG with 600 dpi
results = scripts.batchPlot({'scan1.xrdml','scan2.xrdml'}, DPI=600, Overwrite=true);
```

Options: `Template`, `OutputDir`, `Format` ("png"|"pdf"|"svg"|"eps"|"tiff"), `DPI`, `PlotType`, `XAxis`, `YAxis`, `FigSize`, `Prefix`, `Suffix`, `Overwrite`, `Verbose`

Returns a struct array with `.inputFile`, `.outputFile`, `.success`, `.error` per file.

---

### dataConnector

Live file watcher that auto-reloads data via `parser.importAuto` whenever the source file is modified on disk.

```matlab
% Reload and print row count each time the file changes
c = scripts.dataConnector('live_data.csv', ...
    Callback=@(d) fprintf('Reloaded: %d rows\n', size(d.values,1)));

% … instrument is acquiring …
c.stop();   % always call stop() to clean up the internal timer
```

Options: `Interval` (polling interval in seconds; default 2), `Callback` (function handle receiving the new data struct), `AutoStart` (default true)

Returns a connector struct with methods: `.start()`, `.stop()`, `.isRunning()`, and fields `.filePath`, `.lastModified`.

---

### generateReport

Generate a formatted HTML or plain-text analysis report from a cell array of data structs.

```matlab
data1 = parser.importAuto('scan.xrdml');
data2 = parser.importAuto('vsm.dat');
reportPath = scripts.generateReport({data1, data2}, ...
    Title='Sample batch', Author='J. Smith', Format='html');

% Text-only report without embedded plots
scripts.generateReport({data1}, Format='txt', IncludePlots=false, OutputPath='summary.txt');
```

Options: `OutputPath`, `Format` ("html"|"txt"), `Title`, `Author`, `Date`, `IncludePlots`, `IncludeStats`, `IncludeMetadata`, `PlotFormat`, `PlotDPI`, `CustomSections`, `TempDir`
