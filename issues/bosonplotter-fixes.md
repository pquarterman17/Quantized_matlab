# BosonPlotter — Open Issues

**Created:** 2026-05-11
**Updated:** 2026-05-11

---

## ~~1. Legend text edits reset when switching datasets~~ (2026-05-11)

Fixed: removed `SelectionType='row'` from legend editor uitable — it cancelled in-progress cell edits on row switch.

---

## ~~2. Copy-as-image clips axis labels and title~~ (2026-05-11)

Fixed: pass figure handle to `copygraphics` instead of axes handle; added explicit 8×6 inch figure size.

---

## ~~3. CSV export is slow + needs more options~~ (2026-05-11)

Fixed with three improvements:
- Vectorized I/O: single `fprintf` call per matrix block instead of per-cell loop
- Save As dialog: `uiputfile` replaces the old fixed-path workflow
- Multi-dataset modes: active only / each as separate file / combined side-by-side

---

## ~~4. Origin COM integration broken — PutWorksheet fails~~ (2026-05-11)

Fixed three bugs: `newbook bk:=` (output binding) changed to `name:=` (name setter); sheet names truncated to Origin's 31-char limit; added `[Book]Sheet1!` fallback in PutWorksheet chain. Mock + tests updated.

---

## ~~4b. Origin COM — additional critical bugs found by audit~~ (2026-05-11)

Follow-up audit of `toOrigin.m` found 6 more bugs:
- **`option:=lsname`** made `name:=` set long name instead of short name — all range refs silently broke. Removed.
- **Column type codes wrong**: had 4/1/3 (Label/Disregard/X); corrected to 3/0/2 (X/Y/yErr)
- **`Execute()` readback**: removed `%H=` and `wks.name$=` string readback (Execute returns int, not string). Simplified to use the name we set directly.
- **Sheet name limit**: changed from 31 to 32 chars
- **`datetime` crash**: `[data.time(:), data.values]` fails on datetime; added datenum conversion
- **Empty data guard**: reject empty time/values before attempting COM calls
- **`escapeLT` incomplete**: now escapes `%`, `;`, and newlines (LabTalk injection vectors)

Added tests 9–11: empty data rejection, datetime handling, LabTalk escape sequences.
