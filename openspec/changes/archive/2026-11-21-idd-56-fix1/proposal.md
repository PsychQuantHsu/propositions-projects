## Why

The first review found that `redirect` read a malformed `replaced_by` as none and dropped values from `cites`; that the shared line reading gave a last line a line feed it did not have; that `relocate` took a text inside a longer word or a comment, compared letters by canonical equivalence, and chose between two equally near places by their order; and that `retire` and `check` did not require an id to name exactly one live proposition.

## What Changes

- `redirect` refuses what it cannot follow, keeps direct citations in place and adds a replacement once.
- Lines are read and written with their bytes as they are.
- `relocate` counts whole texts outside comments, scalar by scalar; a tie is ambiguous.
- `retire` refuses empty ids, ids that do not name one live proposition, and a retirement that would break another; `check` reports an id of several lines; dates are checked without a time zone.

## Non-Goals

- Two programs writing the same ledger at once; a main file not named `main.tex` in a location. Both are stated in the specification.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `revise`: the four commands.

## Impact

- Affected specs: `revise`
- Affected code:
  - Modified: Sources/PropositionsKit/Revise.swift, Sources/PropositionsKit/Relocate.swift, Sources/PropositionsKit/ReviseLedger.swift, Sources/PropositionsKit/ReviseRun.swift, tests/PropositionsKitTests/RelocateTests.swift, tests/PropositionsKitTests/ReviseLedgerTests.swift, .claude/rules/swift-is-the-implementation-language.md
