## Why

The `propositions` binary 0.2.0, released on 2026-11-21, has the commands that replace four Python tools: `reorder-ledger.py`, `derive-paragraphs.py`, `audit-symbols.py` and `audit-citations.py`. The maintainer decided that day that the Python versions are retired, not kept, and that whoever runs one is told to use the Swift one.

## What Changes

- The plugin's lock file names 0.2.0. The skills `construct`, `construct-batch` and `manuscript-audit` call the commands through the launcher; `run-audit.sh` runs the two audit commands.
- The four Python tools, and the two root entry points that forward to the audits, say that they were retired and what to run, and exit with 2. The migration of version 1.0 sidecars keeps its own copy of the paragraph derivation.
- The Swift tests compare the commands with what the Python tools printed, recorded from them before they were retired.
- The obligations document no longer lists the limits that issues 59 and 69 removed.

## Non-Goals

- A binary for systems other than macOS.
- Retiring the other Python tools; they have no Swift version yet.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-structure`, `article-construction`, `article-obligations`, `ledger-order`, `paragraph-plan`, `manuscript-audit`: the Python tools are retired and the commands replace them.

## Impact

- Affected specs: `article-structure`, `article-construction`, `article-obligations`, `ledger-order`, `paragraph-plan`, `manuscript-audit`
- Affected code:
  - New: tests/PropositionsKitTests/RetiredPython.swift, tests/fixtures/retired-python/
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/scripts/{reorder-ledger,derive-paragraphs,audit-symbols,audit-citations,migrate-structure-v2}.py, plugins/propositions/scripts/run-audit.sh, the three skills, tests, docs
