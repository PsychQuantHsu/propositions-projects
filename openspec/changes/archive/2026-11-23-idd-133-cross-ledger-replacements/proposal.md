## Why

A rewrite handles one document at a time (issue 120). When a passage moves from the main text to the supplement, the main ledger's propositions are retired, but `retired.replaced_by` could only name propositions of the same ledger, so nothing recorded where the passage went (issue 133).

## What Changes

- Schema v1.9: a `replaced_by` item may be `{"ledger": <path>, "id": <id>}`, the path relative to the ledger's directory.
- `revise retire` takes `<ledger>#<id>` and checks it in that ledger; `revise check` reads the other ledger; both take `--ledger-dir` for a copy.
- `revise redirect` does not carry a citation into another ledger, and says so.
- `write check` on a rewrite looks up such replacements of the propositions it retires, from the original ledger's directory.
- The process (maintainer's decision, 2026-11-23): two rewrites, the receiving document first.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `revise`: replacements in another ledger.
- `write`: a rewrite that retires a passage moved to another document.

## Impact

- Affected specs: `revise`, `write`
- Affected code:
  - New: Sources/PropositionsKit/ReviseOtherLedger.swift, tests/PropositionsKitTests/ReviseOtherLedgerTests.swift
  - Modified: Sources/PropositionsKit/ReviseLedger.swift, ReviseRun.swift, CLI.swift, WriteRewrite.swift, WriteParagraph.swift
  - Modified: docs/SCHEMA.md, plugins/propositions/templates/ledger/_meta.template.json, plugins/propositions/skills/prop-ledger/SKILL.md, CLAUDE.md
