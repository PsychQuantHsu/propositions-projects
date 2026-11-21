## Why

The first review of issue 49 found that `commit` could write bytes other than the ones it checked, that the structure sidecar and the files not written back were not checked, that the manuscript was compared as decoded text, and that two roles could name one file.

## What Changes

- Every file is read once in `prepare` and in `commit`; `commit` writes the bytes it checked, and refuses a missing copy before any write.
- `check` compares the manuscript as bytes, requires exactly one paragraph, accepts a ledger whose last line has no line ending, checks the added lines are JSON objects, requires the structure sidecar to only add, and requires the files not written back to stay as they were.
- `prepare` fails closed on a staging directory it cannot list, refuses roles that collide, and creates every copy as a new file; `commit` makes a new `backup/`.

## Non-Goals

- The skill mode: after the binary release.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the three commands.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/WriteParagraph.swift, tests/PropositionsKitTests/WriteParagraphTests.swift
