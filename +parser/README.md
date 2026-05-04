# +parser/ — Data Import Package

All parsers return the same **unified data struct** via `parser.createDataStruct()` so GUI and plotting code is parser-agnostic. This document describes the canonical schema and the parser-specific metadata each function adds.

## Supported Formats (Quick Reference)

| Format | Function | Extensions | Description |
|--------|----------|------------|-------------|
| Quantum Design VSM | `importQDVSM` | `.dat` | Magnetometry; [Header]/[Data] markers |
| QD PPMS (legacy) | `importPPMS` | `.dat` | Older PPMS CSV/TSV; auto-detects delimiter |
| QD MPMS | `importMPMS` | `.dat` | SQUID magnetometry; wrapper over `importQDVSM` |
| Lake Shore | `importLakeShore` | `.dat`, `.csv` | VSM/cryostat; auto-detect header block |
| CSV / TSV / TXT | `importCSV` | `.csv`, `.tsv`, `.txt` | Generic lab data with auto-detection |
| Excel | `importExcel` | `.xlsx`, `.xls`, `.ods` | Spreadsheet with unit row support |
| Rigaku SmartLab | `importRigaku_raw` | `.raw` | Binary XRD (magic "FI") |
| PANalytical XRDML | `importXRDML` | `.xrdml` | XML XRD; 1D + 2D area-detector; Q-space |
| Bruker | `importBruker` | `.brml`, `.raw` | ZIP+XML or v3 binary (magic "RAW1.01") |
| NCNR reflectometry | `importNCNRRefl` | `.refl` | Polarized neutron R vs Q with error bars |
| NCNR PNR | `importNCNRPNR` | `.pnr` | Cross-section resolved (R+, R−) |
| NCNR fit output | `importNCNRDat` | `.datA`–`.datD` | refl1d theory + data overlay |
| refl1d output | `importRefl1dDat` | `.dat` (sniffed) | Reflectivity, SLD profile, slabs, steps |
| SIMS depth profile | `importSIMS` | `.csv` | Paired/shared-depth columns; grid merging |
| TIFF image | `importTIFF` | `.tif`, `.tiff` | 8/16/32-bit; multi-page; FEI metadata |
| RAW image | `importRawImage` | `.raw` | Headerless binary (not auto-dispatchable) |
| Gatan DM3/DM4 | `importDM3` | `.dm3`, `.dm4` | Recursive tagged binary; pixel calibration |
| Gatan DM4 | `importDM4` | `.dm4` | DM4 variant; 2D image, 1D spectrum, or 3D SI cube |
| Bruker NanoScope AFM | `importAFM` | `.spm`, `.000`, `.001`, … | ASCII header + binary image; Z-scale calibration |
| Bruker BCF (EDS) | `importBCF` | `.bcf` | SFS container; SEM image + sum EDS spectrum + XML metadata |
| Common image | `importImage` | `.jpg`, `.jpeg`, `.png`, `.bmp`, `.gif` | MATLAB `imread` wrapper; returns mean intensity per row |
| MRC2014 | `importMRC` | `.mrc`, `.mrcs` | EM image stack; first section returned as 1D mean profile |
| FEI/ThermoFisher SER | `importSER` | `.ser` | TIA binary image; mean intensity per row |

---

## Unified Data Struct

```matlab
data.time      % [N×1] x-axis / independent variable (double or datetime)
data.values    % [N×M] data matrix  (N samples, M channels)
data.labels    % {1×M} channel name strings  (e.g. 'Moment', 'Intensity')
data.units     % {1×M} unit strings  (e.g. 'emu', 'cps')
data.metadata  % struct — see Canonical Metadata Schema below
```

---

## Canonical Metadata Schema

Every parser guarantees these top-level fields:

| Field | Type | Description |
|-------|------|-------------|
| `source` | `char` | Full path to the source file |
| `importDate` | `datetime` | Timestamp of the import call |
| `parserName` | `char` | Name of the function that produced this struct |
| `xColumnName` | `char` | Human-readable name of the x-axis column |
| `xColumnUnit` | `char` | Unit string for the x-axis |
| `parserSpecific` | `struct` | Parser-specific fields — see tables below |

---

## Parser-Specific Metadata

### `importRigaku_raw` — Rigaku SmartLab binary `.raw`

```matlab
data.metadata.parserName   % 'importRigaku_raw'
data.metadata.xColumnName  % '2-Theta'
data.metadata.xColumnUnit  % 'deg'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `numPoints` | double | Number of data points |
| `startAngle` | double | Starting 2θ angle (degrees) |
| `endAngle` | double | Ending 2θ angle (degrees) |
| `stepSize` | double | Angular step size (degrees) |
| `countingTime` | double | Counting time per step (seconds) |

---

### `importXRDML` — PANalytical/Malvern Empyrean `.xrdml`

```matlab
data.metadata.parserName   % 'importXRDML'
data.metadata.xColumnName  % '2-Theta'
data.metadata.xColumnUnit  % 'deg'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `numPoints` | double | Number of data points |
| `startAngle` | double | Starting 2θ angle (degrees) |
| `endAngle` | double | Ending 2θ angle (degrees) |
| `stepSize` | double | Mean angular step size (degrees) |
| `countingTime` | double | Counting time per step (seconds) |
| `wavelength` | double | X-ray wavelength in Å (Kα₁) |
| `sampleMode` | char | e.g. `'Reflection'` |
| `measurementType` | char | e.g. `'Scan'` |
| `scanMode` | char | e.g. `'Continuous'` |
| `scanAxis` | char | e.g. `'2Theta-Omega'` |
| `anodeMaterial` | char | e.g. `'Cu'` |
| `tubeName` | char | X-ray tube name |
| `tension_kV` | double | Tube voltage (kV) |
| `current_mA` | double | Tube current (mA) |
| `detectorName` | char | Detector model |
| `sampleName` | char | Sample name from file header |
| `sampleID` | char | Sample ID |
| `instrumentID` | char | Instrument identifier |
| `softwareName` | char | Acquisition software |
| `softwareVersion` | char | Software version string |
| `spinnerPeriod_s` | double | Spinner period (seconds; NaN if not used) |
| `startTime` | datetime | Scan start time |
| `endTime` | datetime | Scan end time |
| `comments` | char | Free-text comments from file |
| `intensityTag` | char | XML tag used for intensity (e.g. `'intensities'`) |
| `schemaVersion` | char | XRDML schema version |

---

### `importBruker` — Bruker D8/D2 `.brml` (ZIP+XML) or `.raw` (binary v3)

```matlab
data.metadata.parserName   % 'importBruker'
data.metadata.xColumnName  % '2-Theta'
data.metadata.xColumnUnit  % 'deg'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `formatType` | char | `'brml'` or `'raw_binary_v3'` |
| `numPoints` | double | Number of data points |
| `startAngle` | double | Starting 2θ angle (degrees) |
| `endAngle` | double | Ending 2θ angle (degrees) |
| `stepSize` | double | Mean angular step size (degrees) |
| `countingTime` | double | Counting time per step (seconds) |
| `wavelength_A` | double | X-ray wavelength in Å |
| `scanAxis` | char | Scan axis name |
| `rangeIndex` | double | Range index (1-based; multi-range files) |
| `totalRanges` | double | Total number of ranges in file |

---

### `importQDVSM` — Quantum Design VSM / DynaCool `.dat`

```matlab
data.metadata.parserName   % 'importQDVSM'
data.metadata.xColumnName  % column name matching XAxis (e.g. 'Magnetic Field')
data.metadata.xColumnUnit  % e.g. 'Oe'
```

`parserSpecific` contains the full `headerInfo` struct from the `[Header]` block:

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `title` | char | File title from header |
| `fileOpenDate` | char | Date string from header |
| `fileOpenTimeStr` | char | Time string from header |
| `app` | char | Software application name |
| `instrument` | struct | Sub-struct of instrument parameters |
| `dataTypes` | cell | List of `[Data]` block type strings |
| `startupAxisX` | char | Suggested x-axis column name |
| `startupAxisY` | char | Suggested y-axis column name |
| `allColumnNames` | cell | All column header strings |
| `allColumnUnits` | cell | All column unit strings |
| `xColumnIndex` | double | 1-based index of x-axis column |
| `yColumnIndices` | double | 1-based indices of y-axis columns |

---

### `importMPMS` — Quantum Design MPMS SQUID `.dat`

Thin wrapper around `importQDVSM` with MPMS-specific column shortcuts.

```matlab
data.metadata.parserName                       % 'importMPMS'
data.metadata.parserSpecific.instrumentType    % 'MPMS SQUID'
```

All other `parserSpecific` fields are inherited from `importQDVSM`.

---

### `importPPMS` — Quantum Design PPMS legacy CSV `.dat`

```matlab
data.metadata.parserName   % 'importPPMS'
data.metadata.xColumnName  % column name matching XAxis
data.metadata.xColumnUnit  % column unit
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `allColumnNames` | cell | All column header strings |
| `allColumnUnits` | cell | All column unit strings |
| `headerRow` | double | Line number of the column header row |
| `delimiter` | char | Auto-detected delimiter (`','` or `'\t'`) |
| `numRawRows` | double | Total lines in file |
| `xColumnIndex` | double | 1-based index of x-axis column |
| `yColumnIndices` | double | 1-based indices of y-axis columns |

---

### `importLakeShore` — Lake Shore VSM / cryostat CSV/DAT

```matlab
data.metadata.parserName                       % 'importLakeShore'
data.metadata.xColumnName                      % column name matching XAxis
data.metadata.xColumnUnit                      % column unit
data.metadata.parserSpecific.instrumentType    % 'Lake Shore VSM/Magnetometer'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `instrumentType` | char | `'Lake Shore VSM/Magnetometer'` |
| `allColumnNames` | cell | All column header strings |
| `allColumnUnits` | cell | All column unit strings |

---

### `importCSV` — Generic CSV / TSV / TXT

```matlab
data.metadata.parserName   % 'importCSV'
data.metadata.xColumnName  % name of the x-axis column
data.metadata.xColumnUnit  % unit of the x-axis column
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `delimiter` | char | Auto-detected delimiter (e.g. `','`, `'\t'`, `';'`) |
| `headerRow` | double | Line number of the column header row |
| `numRawRows` | double | Total non-blank, non-comment lines read |
| `allColumnNames` | cell | All column header strings found in file |
| `allColumnUnits` | cell | All column unit strings |

---

### `importExcel` — Excel `.xlsx` / `.xls` / `.ods`

```matlab
data.metadata.parserName   % 'importExcel'
data.metadata.xColumnName  % name of the x-axis column
data.metadata.xColumnUnit  % unit of the x-axis column
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `sheet` | double | Sheet index (1-based) |
| `sheetName` | char | Sheet name |
| `allSheets` | cell | All sheet names in the workbook |
| `headerRow` | double | Row number of the column header |
| `numRawRows` | double | Number of data rows imported |
| `allColumnNames` | cell | All column header strings |
| `allColumnUnits` | cell | All column unit strings |

---

### `importNCNRRefl` — NCNR reductus `.refl`

```matlab
data.metadata.parserName   % 'importNCNRRefl'
data.metadata.xColumnName  % 'Qz'
data.metadata.xColumnUnit  % '1/Ang'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `dataSource` | char | `'NCNR reductus'` |
| `instrument` | char | `'NCNR reflectometer'` |
| `instrument_type` | char | `'PBR (monochromatic)'` or `'CANDOR (polychromatic)'` |
| `name` | char | Dataset name from JSON header |
| `wavelength` | double | Wavelength in Å (PBR) |
| `wavelengths` | double | Wavelength array in Å (CANDOR) |
| `polarization` | char | Polarization state (if present) |

---

### `importNCNRPNR` — NCNR polarized neutron reflectometry `.pnr`

```matlab
data.metadata.parserName   % 'importNCNRPNR'
data.metadata.xColumnName  % 'Q'
data.metadata.xColumnUnit  % '1/Ang'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `dataSource` | char | `'NCNR reductus'` |
| `instrument` | char | `'NCNR polarized reflectometer'` |
| `variant` | char | `'NSF'`, `'SF'`, or `'combined'` |

---

### `importNCNRDat` — refl1d fit output `.datA` / `.datB` / `.datC` / `.datD`

```matlab
data.metadata.parserName   % 'importNCNRDat'
data.metadata.xColumnName  % 'Q'
data.metadata.xColumnUnit  % '1/Ang'
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `dataSource` | char | `'refl1d fitting'` |
| `instrument` | char | `'NCNR reflectometer'` |
| `polarization` | char | `'++'`, `'+-'`, `'-+'`, or `'--'` (from extension) |
| `intensity` | double | Intensity column (if present) |
| `background` | double | Background column (if present) |

---

## Microscopy / EM Parsers

These parsers return the unified struct with image data in `data.metadata.parserSpecific`. The `.time` and `.values` fields carry a 1D projection (mean intensity per row) as a lightweight fallback for the GUI; the full image matrix is in `data.metadata.parserSpecific.image` or `.cube`.

### `importAFM` — Bruker NanoScope AFM/SPM

```matlab
data = parser.importAFM('surface.spm');
data = parser.importAFM('surface.spm', Channel='Phase');
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `isImage` | logical | Always `true` |
| `image` | double | [H×W] image matrix in physical units |
| `xScale_nm` | double | Pixel size in X (nm) |
| `yScale_nm` | double | Pixel size in Y (nm) |
| `zScale_nm` | double | Z calibration factor |
| `channel` | char | Channel name extracted (e.g. `'Height'`) |
| `allChannels` | cell | All channel names present in file |

---

### `importBCF` — Bruker BCF EDS Spectral-Imaging

```matlab
data = parser.importBCF('eds_map.bcf');
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `isImage` | logical | `true` when a SEM reference image is present |
| `image` | double | [H×W] SEM reference image |
| `sumSpectrum` | double | [Nx1] spatially-summed EDS spectrum |
| `energyAxis_keV` | double | [Nx1] energy axis in keV |
| `acceleratingVoltage_kV` | double | Beam voltage |
| `pixelSize_nm` | double | Pixel size (nm) |
| `elements` | cell | Element symbols identified in file |

---

### `importImage` — Common Image Files (JPEG/PNG/BMP/GIF)

```matlab
data = parser.importImage('micrograph.png');
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `isImage` | logical | Always `true` |
| `image` | double | [H×W] or [H×W×3] image matrix |
| `width` | double | Image width (px) |
| `height` | double | Image height (px) |
| `nChannels` | double | 1 (grayscale) or 3 (RGB) |
| `colorType` | char | `'grayscale'` or `'truecolor'` |
| `bitDepth` | double | Bit depth |

---

### `importMRC` — MRC2014 Electron Microscopy Image

```matlab
data = parser.importMRC('tomo.mrc');
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `isImage` | logical | Always `true` |
| `image` | double | [H×W] first section |
| `nSections` | double | Total number of sections in stack |
| `pixelSize_A` | double | Pixel size in Å (from cell dimensions) |
| `mode` | double | MRC mode integer (0=int8, 1=int16, 2=float32, …) |
| `mapType` | char | `'image'`, `'volume'`, or `'transform'` |

---

### `importSER` — FEI/ThermoFisher TIA SER

```matlab
data = parser.importSER('image.ser');
```

| `parserSpecific` field | Type | Description |
|------------------------|------|-------------|
| `isImage` | logical | Always `true` |
| `image` | double | [H×W] image matrix |
| `pixelSize` | double | Pixel calibration value |
| `pixelUnit` | char | Pixel calibration unit |
| `dataType` | double | SER data type code |

---

### `importDM4` — Gatan DM4

```matlab
data = parser.importDM4('spectrum.dm4');
data = parser.importDM4('image.dm4', Verbose=true);
```

Returns image, 1D spectrum, or 3D SI cube depending on file content. `parserSpecific` inherits from `importDM3`; see the DM3/DM4 row in the table above and `+parser/importDM3.m` for full metadata fields.

#### Example — load and display a DM4 spectrum image
```matlab
data = parser.importDM4('eels_map.dm4');
if isfield(data.metadata.parserSpecific, 'cube')
    cube = data.metadata.parserSpecific.cube;  % [Y × X × E]
    sumSpec = squeeze(sum(sum(cube, 1), 2));
    plot(data.time, sumSpec);
    xlabel('Energy (eV)'); ylabel('Counts');
end
```

---

## Internal Helpers

These functions implement the dispatch and calibration logic used by `importAuto` and the individual parsers. They are not typically called directly by users but are useful for extending the toolbox or writing custom parsers.

| Function | Description |
|----------|-------------|
| `resolveParser(filepath)` | Extension → parser name + metadata; single dispatch table for `importAuto` and the GUI |
| `resolveColumnShorthand(spec, colNames)` | Resolve a column spec (index, shorthand string, or full name) to a 1-based index |
| `computeQSpace(map)` | Lazily compute Qx/Qz grids for a 2D map struct when wavelength is available |
| `createDataStruct(...)` | Construct and validate the canonical unified data struct (call from all parsers) |

### `resolveParser`

```matlab
result = parser.resolveParser('scan.raw');
% result.parserName  — 'importRigaku_raw' or 'importBruker'
% result.extension   — '.raw'
% result.magicBytes  — true  (magic-byte dispatch was used)

result = parser.resolveParser('sample.dat');
% result.parserName  — 'importQDVSM' (heuristic based on [Header] marker)
```

### `resolveColumnShorthand`

```matlab
% Resolve 'moment' → column index in a QD VSM file
idx = parser.resolveColumnShorthand('moment', colNames);
idx = parser.resolveColumnShorthand(3,        colNames);  % pass-through
idx = parser.resolveColumnShorthand('Magnetic Field (Oe)', colNames);
```

### `computeQSpace`

```matlab
% Called automatically by importXRDML for 2D area-detector data
map = parser.computeQSpace(map);
% map.Qx  — [N×M] grid
% map.Qz  — [N×M] grid
```

---

## Column Shorthands

`importQDVSM`, `importMPMS`, `importPPMS`, and `importLakeShore` accept shorthand
strings for `XAxis` / `YAxis` parameters instead of full column names:

| Shorthand | Resolves to |
|-----------|-------------|
| `'field'` | Magnetic Field (Oe) |
| `'moment'` | Moment (emu) |
| `'temp'` / `'temperature'` | Temperature (K) |
| `'time'` | Time Stamp |
| `'stderr'` | M. Std. Err. |
| `'dcmoment'` | DC Moment (MPMS only) |
| `'all'` | All numeric columns except x-axis |

---

## Auto-Detection (`importAuto`)

`importAuto` selects a parser using this priority order:

1. **Magic bytes** — `.raw` files: reads first 7 bytes; `"FI"` → Rigaku, `"RAW1.01"` → Bruker
2. **Extension** — `.xrdml` → `importXRDML`; `.brml` → `importBruker`; `.refl` → `importNCNRRefl`; `.pnr` → `importNCNRPNR`; `.datA`/`.datB`/`.datC`/`.datD` → `importNCNRDat`; `.dat` → content-sniffed (see below); `.xlsx`/`.xls`/`.ods` → `importExcel`; `.csv`/`.tsv`/`.txt` → `importCSV`
3. **Content heuristic** — for `.dat`: Lake Shore → `importLakeShore`; MPMS → `importMPMS`; refl1d output → `importRefl1dDat`; otherwise `importQDVSM` (falls back to `importPPMS`)

The same logic is used by the GUI's `guiImport()` dispatcher (via `resolveParser`).
