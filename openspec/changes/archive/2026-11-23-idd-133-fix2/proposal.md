## Why

The second verify round of issues 131 and 133 found that `revise redirect` had no `--ledger-dir`, and judged the object items of every retirement, cited or not. Run on the staged ledger of the document that gave content up, it exited 2, so that document could not be rewritten again. It also found that the `article-construction` requirement still said to stop when content moves between documents, and that a symlink to a hard link of the ledger was not recognised as this ledger.

## What Changes

- `revise redirect` takes `--ledger-dir` and judges the object items of cited retirements only.
- This ledger is recognised by its file after symlinks are resolved.
- The `article-construction` requirement describes the two runs.
- `prop-construct` G4 and `prop-extract` R4/R5 name `--ledger-dir` for `redirect` and the order of the two runs.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `revise`: replacements in another ledger.
- `article-construction`: reorganize mode with destinations.

## Impact

- Affected specs: `revise`, `article-construction`
- Affected code:
  - Modified: Sources/PropositionsKit/ReviseLedger.swift, ReviseRun.swift, ReviseOtherLedger.swift, CLI.swift
  - Modified: tests/PropositionsKitTests/ReviseOtherLedgerTests.swift
  - Modified: plugins/propositions/skills/prop-construct/SKILL.md, prop-extract/SKILL.md, CLAUDE.md
