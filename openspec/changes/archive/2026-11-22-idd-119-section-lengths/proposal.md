## Why

Issue 119: a submission often has a limit on its length. A section record had no key for a length target, and nothing reported how long a section was written or how the total stood against the limit.

## What Changes

- A section record can carry `length`, a target in words; `outline check` checks its shape.
- `article.json` can carry `length`: the limit in words and the parts it counts.
- `propositions outline length <directory> [--jsonl <ledger> --tex <main file>]` reports each section's target and what was written from it, the totals of each part, and the totals against the limit. It only reports: no command refuses because of a length.

## Non-Goals

- Page limits: pages cannot be counted without compiling.
- Text that was not written from the outline: it has no trace record and is not counted.
- Several destination documents (issue 120): this change reads one manuscript.
- The skills calling the command (after the binary release).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: the key `length` of a section record, the key `length` of `article.json`, and `outline length`.

## Impact

- Affected specs: `article-outline`
- Affected code:
  - New: Sources/PropositionsKit/OutlineLength.swift, tests/PropositionsKitTests/OutlineLengthTests.swift
  - Modified: Sources/PropositionsKit/Article.swift, Sources/PropositionsKit/OutlineCheck.swift, Sources/PropositionsKit/CLI.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md
