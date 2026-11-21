## Why

The first review found two ways for `--write` to damage a ledger: named through a symbolic link, the link was replaced by a file and its target left unsorted; saved by another program after it was read, the save was overwritten. It also found differences from the Python tool that the specification did not list.

## What Changes

- The ledger is replaced only when it is still the same regular file with the bytes that were read. A linked ledger and a changed ledger are refused.
- The ledger has to be a regular file; a comment is recognised by code points; paths in messages are escaped; the directory is synced after the replacement.
- The list of differences from the Python tool is completed.

## Non-Goals

- Two files of the input tree whose names differ only in Unicode normalisation: that is in the code that reads the tree, shared with the citation-direction check, and is recorded as an issue of its own.
- Keeping the owner, group and access-control list of the ledger.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ledger-order`: writing, refusals, and the differences from the Python tool.

## Impact

- Affected specs: `ledger-order`
- Affected code:
  - Modified: Sources/PropositionsKit/LedgerOrder.swift, tests/PropositionsKitTests/LedgerOrderTests.swift
