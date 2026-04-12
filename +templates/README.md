# +templates — Dataset Template Engine

Configurable import overrides and metadata correction system. When a parser's
auto-detection gets column roles, units, or metadata wrong, templates let the
user fix it once and reuse the fix automatically for similar files.

## Architecture

```
+templates/
├── TemplateEngine.m    — Static class: load, save, match, apply, fingerprint
├── ColumnMapper.m      — Modal GUI for tabular column role/label/unit overrides
├── MetadataEditor.m    — Modal GUI for image metadata overrides (FermiViewer)
├── defaults/           — Shipped JSON templates (read-only)
└── README.md
```

User-created templates are stored at `prefdir/boson_templates/` as JSON files.

## Quick Start

```matlab
% Auto-match a template to imported data
data = parser.importAuto('sample.dat');
[tmpl, confidence] = templates.TemplateEngine.match(data);

% Apply a template
corrected = templates.TemplateEngine.apply(data, tmpl);

% Open the Column Mapper GUI
corrected = templates.ColumnMapper(data);

% Open the Metadata Editor GUI (for images)
corrected = templates.MetadataEditor(imageData);

% Save a custom template
tmpl = struct('name', 'My PPMS', 'type', 'tabular', ...
    'match', struct('parserName', 'importPPMS'), ...
    'overrides', struct('labels', struct('x0', 'R_xx')));
templates.TemplateEngine.save(tmpl);
```

## Matching Cascade

Templates are matched via a 5-step confidence cascade:

| Step | Method | Confidence |
|------|--------|------------|
| 1 | Header fingerprint (exact hash of column names + parser) | 1.0 |
| 2 | Fuzzy header match (Jaccard similarity of column name tokens) | 0.0–1.0 |
| 3 | Parser type + instrument model | 0.6 |
| 4 | File name pattern (glob) | 0.4 |
| 5 | Parser type only | 0.3 |

Auto-apply threshold: 0.8. Suggestion threshold: 0.4. Below 0.4 for generic
parsers (CSV/Excel): Column Mapper opens automatically.

## Template JSON Schema

```json
{
    "name": "Template Name",
    "version": 1,
    "type": "tabular|image_metadata",
    "match": {
        "headerFingerprint": "a3f7c2d1",
        "columnNames": ["Col1", "Col2"],
        "parserName": "importQDVSM",
        "instrument": "VSM",
        "filePattern": "*_MvsH_*.dat"
    },
    "overrides": { ... },
    "created": "2026-04-12T14:30:00",
    "source": "shipped|user"
}
```

## Functions

| Function | Description |
|----------|-------------|
| `TemplateEngine.loadAll()` | Load all templates (shipped + user), cached |
| `TemplateEngine.save(tmpl)` | Write template JSON to user directory |
| `TemplateEngine.delete(name)` | Remove a user template |
| `TemplateEngine.apply(data, tmpl)` | Return new struct with overrides applied |
| `TemplateEngine.fingerprint(data)` | FNV-1a hash of column layout |
| `TemplateEngine.match(data)` | Run cascade, return best template + confidence |
| `ColumnMapper(data)` | Modal dialog for column overrides |
| `MetadataEditor(data)` | Modal dialog for image metadata overrides |
