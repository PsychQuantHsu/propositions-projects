## Why

Issue 116: the structure sidecars record which sentence opens a commitment and which discharges it, and the outline had no key for either. A paragraph written from the outline could not be told what it should open or discharge, and nothing compared the result with a plan.

## What Changes

- A paragraph record can carry `opens` (commitments, each with an id and a kind) and `discharges` (commitment ids); `outline check` checks their shape and that every discharge follows its opening.
- `write check` compares what a paragraph written from the outline opens and discharges, in the staged discourse sidecar, with what its record plans, and reports each difference as a problem; a rewrite is compared paragraph by paragraph. An outline that plans no commitment at all is not compared.

## Non-Goals

- Deriving the two keys from a finished manuscript: derive does not write them.
- Suggesting which commitments a paragraph should open.
- The outline skill and the construct skill using the keys (after the binary release).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: the keys `opens` and `discharges` of a paragraph record.
- `write`: the comparison of a written paragraph with the plan.

## Impact

- Affected specs: `article-outline`, `write`
- Affected code:
  - New: Sources/PropositionsKit/OutlineCommitments.swift, tests/PropositionsKitTests/OutlineCommitmentsTests.swift
  - Modified: Sources/PropositionsKit/OutlineCheck.swift, Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/WriteRewrite.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md
