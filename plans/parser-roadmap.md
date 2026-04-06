# Parser Roadmap

Remaining parser work for the `+parser/` package.

---

## New Parsers (blocked — need example files)

**Source:** backlog.md

| Parser | Format | Status |
|--------|--------|--------|
| `importOxford.m` | Oxford Instruments MagLab CSV/text | Blocked — need example file |
| `importRaman.m` | Horiba LabSpec / Renishaw ASCII (wavenumber + intensity) | May already work via `importCSV` — verify + add dispatch |
| `importOpus.m` | Bruker OPUS FTIR binary | Blocked — need example file |
| `importSPC.m` | GRAMS/Thermo SPC spectral format | Blocked — need example file |

### Rolling policy
Support new file types as they are added to `+test_datasets/` on a rolling basis. Each new parser must:
1. Return via `parser.createDataStruct()`
2. Register in `+parser/resolveParser.m`
3. Register in `guiImport` section of `Boson.m`
4. Update `uigetfile` filter list in `Boson.m`
5. Include a test in `tests/parser/`
