## Why

The second review found that the check before replacing the ledger took its baseline too late: a save that put another file with the same bytes in place while the order was worked out was overwritten, and a change of permissions was undone.

## What Changes

- The ledger is read through one open file whose identity, permission bits and bytes are kept; the last look compares all three, on one open file that is not reached through a link.
- A failed directory sync is reported. The main file has to be a regular file. The main file's name is escaped in a message.
- The specification says when a ledger is not rewritten at all, what the warnings before an error are, and three more differences from the Python tool.

## Non-Goals

- A pipe reached through `\input` inside the tree: the code that reads the tree is shared with the citation-direction check.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ledger-order`: the check before replacing the ledger.

## Impact

- Affected specs: `ledger-order`
- Affected code:
  - Modified: Sources/PropositionsKit/LedgerOrder.swift, tests/PropositionsKitTests/LedgerOrderTests.swift
