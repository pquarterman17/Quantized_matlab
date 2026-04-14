# Overnight Claude — Autonomous Sweep Instructions

This file documents the directives the user established on 2026-04-13 for running the overnight repo-audit sweep on branch `feat/overnight-audit-sweep`. Future sessions that resume or re-run this workflow should load and honour these rules without re-asking the user to repeat them.

## Ground rules

### Scope
- **In scope:** every open item from `plans/repo-audit-2026-04-13.md` (54 items) plus any unfinished items in other `plans/` files (known-bugs, DiraCulator, theory docs, dataset templates, bug-reporting).
- **Out of scope:** merging to `main`. Work lands only on the branch. User reviews merges themselves.
- **Opportunistic scope:** if an obvious easy fix or small improvement is spotted outside the plan, **implement it and document it**. Then flag in the summary file so it gets the user's attention at restart. Large out-of-plan items go into a new "Spotted during overnight" section of the audit plan for next session.

### Test pass/fail gate
- **"Any failure at all" resets the two-round counter** — including pre-existing flakes.
- Fix known flakes *before* declaring round 1, otherwise the 2-round gate cannot close.
- Known flakes to eliminate before gate rounds: `test_layoutIntegrity` full-suite flake, `test_plotStyleDialog` full-suite flake.
- Each round = full `runAllTests(Group="all")` pass, 106/106 suites green, deterministic on repeat.

### Big features
- Three P0 features (MCMC posterior sampling, reflectometry resolution smearing, Pawley/Rietveld XRD refinement) are **scaffolded, not implemented**:
  - Minimal viable API defined
  - Failing / skip-marked tests spelling out the spec
  - Physics + fix direction documented in `docs/theory/<domain>.md`
  - Add TODO markers so they're obvious for the user to pick up
- Full implementations deferred to a future session.

### Documentation
- Every physics-touching fix gets the full `physics-docs-expert` treatment (docstring with formula/units/reference, entry in `docs/theory/<domain>.md`, tutorial if the workflow is new).
- Non-physics fixes: docstring-only is sufficient.

### Time budget
- Overnight window. If the clock is **before 06:00 local** when primary scope is complete, pick up postponed additions (the "deferred to next session" items in this file's sibling summary) and keep implementing. Keep testing after each batch.

### Parallelism & model selection
Be smart about concurrency and cost:

- **Haiku / Sonnet** for:
  - Docstring additions and theory doc write-ups (physics-docs-expert in background)
  - Small bug fixes with clear spec (code-implementer in background)
  - Test scaffolds for P0 features (test-writer in background)
  - Simple format/rename/cleanup work
- **Opus (primary thread)** for:
  - Multi-file refactors
  - Physics-formula debugging with multiple sign/unit conventions
  - Integration testing and harness changes
  - Synthesis of sub-agent outputs into commits
- **Parallel agent launches** (send a single message with multiple Agent calls) whenever the work items are genuinely independent. Prime candidates: (a) docs write-ups for different physics modules, (b) test-writer for independent modules, (c) scaffolds for multiple P0 features.

### Shutdown
- Only shut the machine down after **two successive clean full-suite runs with zero failures**.
- Any failure resets the counter and I go back to fixing.
- Before shutdown, write the summary file at `plans/overnight-sweep-summary-2026-04-13.md` with:
  - High-level outcome at the top
  - List of "spotted during overnight" implemented fixes (user attention needed)
  - Detailed breakdown of what was done per plan item
  - List of what was skipped/deferred and why
  - Test results with raw pass counts
- Shutdown command: `shutdown /s /t 0` via Bash on Windows.

### Branch hygiene
- Branch: `feat/overnight-audit-sweep`
- Rooted on tag `checkpoint-2026-04-13` (5aa62bf) — safe revert point
- Do NOT merge to `main`. Do NOT push to `origin`.
- Commit granularity: many small logical commits, not one mega-commit. Each commit should tell the story of one audit item.

### Interactions with parallel sessions
- `feat/bug-reporting` branch exists with unmerged Stage 2 work — leave it alone.
- Uncommitted state in parallel worktrees (`+bugReport/`, etc.) belongs to other sessions — don't touch.

## Global rules still apply

All global rules from `claude-config/rules/*.md` remain in force:
- `branch-before-implement.md` — already on a feature branch, good
- `commit-messages.md` — conventional commits
- `test-after-implement.md` — run relevant tests per batch
- `data-contract.md` — parsers return via `createDataStruct`
- `no-eval.md` — no eval, evalc, feval with dynamic strings
- `docs-after-physics-feature.md` — physics-docs-expert per physics item
- `dual-registration.md` — MATLAB parsers need BOTH `resolveParser.m` + `guiImport` registration
- `cross-platform.md` — test paths work on Windows and macOS
- `ask-user-question.md` — use the tool for discrete-choice questions, but the user is asleep tonight, so unless something is blocking and destructive, use best judgment

## If the user is awake and interacts mid-run

- If they ask what's happening: quick status, no long narration
- If they say stop: commit WIP on the branch with a `wip:` prefix, summarize, wait
- If they say merge: confirm via `AskUserQuestion` before merging, then merge per branch-before-implement rule
