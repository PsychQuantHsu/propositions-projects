## Why

The first verify round of issues 131 and 133 found that three earlier `revise` requirements still describe `replaced_by` as a list of ids of the same ledger, contradicting the requirement on replacements in another ledger; that a hard link or the staged copy of the ledger was not recognised as this ledger; that `redirect` dropped a citation in favour of another ledger's item without checking it; that the rewrite check skipped a malformed item; and that the read-once sentence promised more than the code does about included files.

## What Changes

- The three `revise` requirements say what holds for object items.
- A ledger named by path or by file (device and inode) is this ledger; the rewrite check counts the staged copy too.
- `redirect` refuses an object item `check` would report.
- The rewrite check reports a malformed item of a proposition it retires.
- The read-once sentence says that existence is still looked up on disk.
- The scaffold template stays at schema 1.8 until the plugin pins a binary that reads v1.9.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `revise`: retire, check, redirect and replacements in another ledger.
- `write`: the rewrite.

## Impact

- Affected specs: `revise`, `write`
- Affected code:
  - Modified: Sources/PropositionsKit/ReviseOtherLedger.swift, ReviseLedger.swift, ReviseRun.swift, WriteRewrite.swift, WriteParagraph.swift, CLI.swift
  - Modified: tests/PropositionsKitTests/WriteRewriteTests.swift, ReviseOtherLedgerTests.swift
  - Modified: plugins/propositions/catalog/obligations.yaml, plugins/propositions/templates/ledger/_meta.template.json, plugins/propositions/skills/prop-ledger/SKILL.md
