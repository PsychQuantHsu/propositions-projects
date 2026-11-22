## Why

Three problems older than issues 116–120 (issue 131): the rewrite check reads the staged manuscript a second time by path, so the bytes it judges may not be the bytes `commit` writes; a key written twice inside a nested object of a ledger line is not reported; and the first `write` requirement still says that a ledger without a live proposition is refused and that the added lines hold exactly one run, which the requirements added in issue 51 contradict.

## What Changes

- `ReadingOrder` can read the tree through a function; the rewrite check builds the reading order, the paragraph starts and the commitments from the staged bytes it read once.
- The rewrite check reports a key written twice in any object of a ledger line, at any depth, with the line number.
- The first `write` requirement points to the requirements on an empty ledger and on `--heading` instead of contradicting them.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the first requirement and the rewrite.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/ReadingOrder.swift
  - Modified: Sources/PropositionsKit/WriteRewrite.swift
  - Modified: Sources/PropositionsKit/WriteParagraph.swift
  - Modified: tests/PropositionsKitTests/WriteRewriteTests.swift
