## Why

`reorder-ledger.py` orders a ledger by the first line of each location and stops when a location names another file. A manuscript of several files therefore has no way to confirm that its ledger's line order is its reading order, which the structure checks take for granted (issue 59). The Swift package already reads a manuscript's reading order from its input tree, for the citation-direction check.

## What Changes

- A subcommand `propositions ledger-order`, the Swift port of `reorder-ledger.py`. Without `--tex` it prints, exits and writes as the Python tool does for a manuscript of one file. With `--tex` it orders through the main file's input tree, so a manuscript of several files can be checked and ordered.
- The order across files is the order of the main file's input tree.

## Non-Goals

- Changing the skill that calls the Python tool, removing the Python tool, and the sentences in the obligations document that say the check is for one file only. These wait for a released binary that has the command; the maintainer decided on 2026-11-21 to publish once after the commands for manuscripts of several files are done.
- A new binary release.

## Capabilities

### New Capabilities

- `ledger-order`: the command that puts a ledger's lines into reading order.

### Modified Capabilities

(none)

## Impact

- Affected specs: `ledger-order` (new)
- Affected code:
  - New: Sources/PropositionsKit/LedgerOrder.swift, tests/PropositionsKitTests/LedgerOrderTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, .claude/rules/swift-is-the-implementation-language.md, CLAUDE.md
