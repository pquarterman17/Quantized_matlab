# Parser Roadmap

New parser support for the `+parser/` package — all blocked on acquiring example files.

**Status:** Paused
**Created:** 2026-03
**Updated:** 2026-04-11

---

## Context

### How the pieces fit together
Parsers live in `+parser/` and are dispatched by `+parser/resolveParser.m` based on file
extension. Each parser returns a unified struct via `parser.createDataStruct()`. GUI
integration requires registration in both `resolveParser.m` and the `guiImport` section
of `BosonPlotter.m` (plus the `uigetfile` filter list).

### Data / control flow
```
File on disk → resolveParser(ext) → importXxx(filepath) → createDataStruct() → GUI/scripts
```

### Dependency map
All four parsers are independent — each can be implemented as soon as its example file arrives.

---

## Tier 1 — High Impact

1. **importRaman** — Horiba LabSpec / Renishaw ASCII (wavenumber + intensity)
   - [ ] Verify if `importCSV` already handles the format
   - [ ] Add extension dispatch in `resolveParser.m` if so
   - [ ] Register in `guiImport` + `uigetfile` filter
   - [ ] Add test in `tests/parser/`

## Tier 2 — Medium Impact

2. **importOxford** — Oxford Instruments MagLab CSV/text
   - [ ] Acquire example file
   - [ ] Implement parser
   - [ ] Dual-register (resolveParser + guiImport)
   - [ ] Add test

3. **importOpus** — Bruker OPUS FTIR binary
   - [ ] Acquire example file
   - [ ] Implement parser
   - [ ] Dual-register
   - [ ] Add test

## Tier 3 — Nice-to-Have

4. **importSPC** — GRAMS/Thermo SPC spectral format
   - [ ] Acquire example file
   - [ ] Implement parser
   - [ ] Dual-register
   - [ ] Add test

---

## Rolling policy

Support new file types as they are added to `+test_datasets/` on a rolling basis.
Each new parser must:
1. Return via `parser.createDataStruct()`
2. Register in `+parser/resolveParser.m`
3. Register in `guiImport` section of `BosonPlotter.m`
4. Update `uigetfile` filter list in `BosonPlotter.m`
5. Include a test in `tests/parser/`

---

## Completed

(none yet)
