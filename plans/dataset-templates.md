# Dataset Templates — Configurable Import & Metadata Override System

User-facing system for overriding parser decisions (column roles, units, labels,
metadata) when auto-detection gets it wrong, saving those overrides as reusable
JSON templates, and auto-suggesting templates for similar files in the future.
Covers both tabular data (BosonPlotter) and image metadata (FermiViewer).

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-12
**Minimum MATLAB version:** R2022b (no toolbox dependencies)

---

## Context

### The problem

Parsers do their best to auto-detect column roles, units, and metadata from file
headers and content heuristics. But they routinely get things wrong:

- Generic CSV/TSV files have no standard header format — `importCSV` guesses
- Instrument operators forget to update sample names, so burned-in SEM metadata
  is stale (wrong sample name in TIFF tag, wrong label on data bar)
- QD `.dat` files can be VSM or PPMS — `resolveParser` uses content sniffing but
  the column layout varies by measurement type
- Users doing non-standard experiments (custom PPMS sequences, modified XRD
  protocols) get columns the parser doesn't expect

Today the user has **no recourse** inside the GUI — they must re-export from
the instrument or edit the parser source code.

### How the pieces fit together

```
+templates/
├── TemplateEngine.m          — static class: load, save, match, apply, fingerprint
├── ColumnMapper.m            — GUI dialog for tabular data (BosonPlotter)
├── MetadataEditor.m          — GUI dialog for image metadata (FermiViewer)
├── defaults/                 — shipped templates (JSON)
│   ├── qdvsm_mvsh.json
│   ├── qdvsm_mvst.json
│   ├── ppms_resistivity.json
│   ├── xrd_bragg.json
│   └── sem_fei.json
└── README.md
```

User-created templates are stored at `prefdir/boson_templates/` (per-user, not
in the repo) using the same JSON format as shipped defaults. Both pools are
searched during matching.

### Data / control flow

```
Current:
  File → resolveParser → parser → struct (best guess) → GUI renders
  (no override path)

Proposed:
  File → resolveParser → parser → struct (best guess)
      ↓
  TemplateEngine.match(struct) → confidence-scored suggestion
      ↓
  ≥ 0.8  → auto-apply template (green banner)
  0.4–0.8 → suggest template (yellow banner: [Apply] [Edit] [Ignore])
  < 0.4  → open Column Mapper / Metadata Editor
      ↓
  User edits (if needed) → corrected struct → GUI renders
      ↓
  "Save as template" → JSON to prefdir/boson_templates/
      ↓
  Next similar file → fingerprint matches → auto-apply at confidence 1.0
```

### Template JSON schema

```json
{
  "_comment": "PPMS resistivity with custom columns",
  "name": "PPMS Resistivity (4-probe)",
  "version": 1,
  "type": "tabular",
  "match": {
    "parserName": "importPPMS",
    "headerFingerprint": "a3f7c2d1",
    "columnNames": ["Temperature (K)", "Resistance Ch1 (Ohms)", "..."],
    "filePattern": "*_Resistivity_*.dat",
    "instrument": "PPMS"
  },
  "overrides": {
    "xColumn": 0,
    "yColumns": [1, 3, 5],
    "labels": {"1": "R_xx", "3": "R_xy"},
    "units": {"1": "Ω", "3": "Ω"},
    "skipColumns": [2, 4]
  },
  "created": "2026-04-12T14:30:00",
  "source": "user"
}
```

For image metadata (FermiViewer):

```json
{
  "name": "FEI Helios — correct sample name",
  "version": 1,
  "type": "image_metadata",
  "match": {
    "parserName": "importTIFF",
    "instrument": "Helios NanoLab",
    "filePattern": "*.tif"
  },
  "overrides": {
    "sampleName": "NiFe_30nm_SiO2",
    "pixelSize": 4.93e-9,
    "pixelUnit": "nm",
    "voltage": 5.0,
    "operator": "Patrick"
  },
  "created": "2026-04-12T14:30:00",
  "source": "user"
}
```

### Matching cascade (confidence scoring)

```
Step 1: Header fingerprint (exact)                    → confidence 1.0
        Hash of sorted column names + column count + parser type.
        Matches saved user templates from prior overrides.

Step 2: Fuzzy header match (Jaccard similarity)       → 0.0–1.0
        Tokenize column names, compute Jaccard index against template
        column sets. "Temperature (K)" ≈ "Temp (K)" via normalization.
        Score = |intersection| / |union| of normalized token sets.

Step 3: Parser type + instrument model                → 0.6
        metadata.parserSpecific.instrument or metadata.parserName
        matches a template's match.parserName + match.instrument.

Step 4: File name pattern                             → 0.4
        Template's match.filePattern glob tested against basename.
        Naming conventions vary so lower confidence.

Step 5: Parser type only                              → 0.3
        Generic default template for that parser type (shipped).

Winner = max(confidence) across all templates × all steps.
```

### Dependency map

- Item 1 (TemplateEngine) is the foundation — everything depends on it
- Item 2 (Column Mapper) and item 3 (MetadataEditor) are independent of each other
- Items 4–5 (auto-suggestion, integration) require items 1–3
- Items 6+ are independent enhancements

---

## Tier 1 — High Impact

1. **TemplateEngine static class** — the core load/save/match/apply engine
   - [ ] Create `+templates/TemplateEngine.m` as a static-method class
   - [ ] `loadAll()` — scan `+templates/defaults/` and `prefdir/boson_templates/`, return cell array of template structs
   - [ ] `save(template)` — write JSON to `prefdir/boson_templates/<name>.json` via `jsonencode`
   - [ ] `delete(name)` — remove a user template
   - [ ] `apply(data, template)` — return a new data struct with overrides applied (column reassignment, label/unit replacement); never mutate the input
   - [ ] `fingerprint(data)` — hash sorted column names + count + parserName into a short hex string (use `mlreportgen.utils.hash` or a simple FNV-1a)
   - [ ] `match(data)` — run the 5-step cascade, return best template + confidence score
   - [ ] `normalize(name)` — tokenize and lowercase a column name for fuzzy matching ("Temperature (K)" → {"temperature", "k"})
   - [ ] `jaccard(setA, setB)` — Jaccard index helper for fuzzy matching
   - [ ] Unit tests in `tests/templates/test_templateEngine.m`

2. **Column Mapper dialog** — GUI for overriding tabular data interpretation
   - [ ] Create `+templates/ColumnMapper.m` — modal `uifigure` dialog
   - [ ] Input: data struct (from parser) + optional template (pre-populate)
   - [ ] Left panel: preview table showing first ~20 rows of raw data
   - [ ] Right panel: column role assignment
     - [ ] Dropdown per column: X-axis / Y-channel / Skip
     - [ ] Editable label field per column (pre-filled from parser)
     - [ ] Editable unit field per column (pre-filled from parser)
   - [ ] Live preview: mini plot in the dialog showing X vs selected Y columns
   - [ ] Buttons: [Apply] [Save as Template...] [Cancel]
   - [ ] "Save as Template" triggers a name dialog, then calls `TemplateEngine.save()`
   - [ ] Returns the corrected data struct (or empty on Cancel)

3. **Metadata Editor dialog** — GUI for overriding image metadata (FermiViewer)
   - [ ] Create `+templates/MetadataEditor.m` — modal `uifigure` dialog
   - [ ] Input: data struct from image parser (importTIFF, importDM3/4, importImage)
   - [ ] Editable fields: sample name, pixel size, pixel unit, voltage, operator, any string field from `metadata.parserSpecific`
   - [ ] Shows current values (from parser) alongside editable override fields
   - [ ] Buttons: [Apply] [Save as Template...] [Cancel]
   - [ ] Returns the corrected data struct

## Tier 2 — Medium Impact

4. **BosonPlotter integration** — wire Column Mapper into the import flow
   - [ ] After `guiImport()` returns, call `TemplateEngine.match(data)`
   - [ ] If confidence ≥ 0.8: auto-apply, show green status bar message "Applied template: <name>"
   - [ ] If confidence 0.4–0.8: show suggestion banner with [Apply] [Edit] [Ignore]
   - [ ] If confidence < 0.4 and parser is generic (importCSV, importExcel): auto-open Column Mapper
   - [ ] If confidence < 0.4 and parser is specific (importQDVSM, etc.): import normally (parser-specific logic is usually right)
   - [ ] Add "Edit Column Mapping..." to dataset context menu (manual trigger)
   - [ ] Add "Save as Template..." to dataset context menu

5. **FermiViewer integration** — wire Metadata Editor into the import flow
   - [ ] After image load, call `TemplateEngine.match(data)` with type='image_metadata'
   - [ ] If match found: auto-apply metadata overrides, show status message
   - [ ] Add "Edit Metadata..." button to the tools panel
   - [ ] Add "Save Metadata Template..." to the tools panel or context menu

6. **Shipped default templates** — sensible defaults for common instruments
   - [ ] `qdvsm_mvsh.json` — M vs H with field/moment columns
   - [ ] `qdvsm_mvst.json` — M vs T with temp/moment columns
   - [ ] `ppms_resistivity.json` — standard 4-probe resistivity layout
   - [ ] `ppms_acms.json` — AC susceptibility columns
   - [ ] `xrd_bragg.json` — 2theta vs intensity
   - [ ] `sem_fei.json` — FEI TIFF metadata defaults (pixel size, voltage, sample)
   - [ ] Templates are overridden by user templates (user templates searched first)

## Tier 3 — Nice-to-Have

7. **Template manager dialog** — browse, edit, delete saved templates
   - [ ] Standalone dialog listing all templates (shipped + user)
   - [ ] Preview: show match criteria + overrides
   - [ ] Edit: open in Column Mapper / Metadata Editor
   - [ ] Delete: remove user templates (shipped are read-only)
   - [ ] Import/export: share templates as standalone JSON files

8. **Fuzzy column name normalization** — improve Step 2 matching
   - [ ] Synonym table: "Temperature" ≈ "Temp" ≈ "T", "Magnetic Field" ≈ "Field" ≈ "H"
   - [ ] Unit stripping: "Temperature (K)" → "temperature" + unit "K"
   - [ ] Abbreviation expansion: "Res" → "Resistance", "Mag" → "Magnetic"

9. **Template analytics / feedback** — track which templates get used
   - [ ] Log template applications to `prefdir/boson_template_log.json`
   - [ ] Track: template name, confidence, was it auto-applied or user-selected, did user edit after
   - [ ] Summary report: "Template X was edited 5 times after auto-apply" → signal to update the default

10. **Batch template application** — apply template across multiple files
    - [ ] `scripts.batchApplyTemplate(folder, templateName)` — import all matching files with the same template
    - [ ] Integration with `scripts.batchImport` — optional template parameter

11. **Template inheritance** — compose templates from base + specialization
    - [ ] `"extends": "ppms_base"` field in template JSON
    - [ ] Base template defines common columns, child overrides/adds specifics
    - [ ] Avoids duplication across related instrument configurations

12. **Python port contract** — design document for thin_film_toolkit equivalent
    - [ ] Map `TemplateEngine.m` → Python class in `thin_film_toolkit.templates`
    - [ ] Map JSON schema 1:1 (same files readable by both MATLAB and Python)
    - [ ] Map Column Mapper → Vue 3 component with AG Grid column config
    - [ ] Map Metadata Editor → Vue 3 form component

---

## Completed

(none yet)
