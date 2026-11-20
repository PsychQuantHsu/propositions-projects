## Why

The fourth review found that a change of permissions during the reread still passed the last look, and two differences from the Python tool that were not listed.

## What Changes

- The last look compares size, permission bits and both times before and after the reread, and against the path afterwards.
- The specification states what the check does not catch and lists two more differences. The test of a refused write checks the permissions in every case.

## Non-Goals

- Making and removing the temporary file through a descriptor of the directory.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ledger-order`: the check before replacing the ledger.

## Impact

- Affected specs: `ledger-order`
- Affected code:
  - Modified: Sources/PropositionsKit/LedgerOrder.swift, tests/PropositionsKitTests/LedgerOrderTests.swift
