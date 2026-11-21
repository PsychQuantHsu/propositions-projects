## Why

The third review found that the last look before replacing the ledger could be passed by a save made while the ledger was being reread, and that the new file's permission bits were not checked after they were set.

## What Changes

- The last look also compares the file's size and time of change before and after the reread, and that the path still names that file.
- The new file's permission bits are read back and have to be the ledger's.
- Three more differences from the Python tool are listed; the test of a refused write checks which reason is given.

## Non-Goals

- Reading the main file through the descriptor that was checked: the code that reads the tree is shared.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ledger-order`: the check before replacing the ledger.

## Impact

- Affected specs: `ledger-order`
- Affected code:
  - Modified: Sources/PropositionsKit/LedgerOrder.swift, tests/PropositionsKitTests/LedgerOrderTests.swift
