## Why

Issue 115: a finished manuscript is reorganised by deriving its outline, revising and approving it, and rewriting the manuscript from it. The write commands could only add one paragraph at the end; a rewrite changes, moves and drops paragraphs.

## What Changes

- `write prepare --rewrite --outline` stages a rewrite of the whole manuscript, gated on the outline standing as approved as a whole.
- `write check` on a rewrite keeps every proposition (only `location`, `cites`, `retired` may change), requires every paragraph record listed in `outline-map.jsonl`, and leaves the sidecars to the structure validator.
- `write commit` writes the changed files of the tree and appends the map to `outline-trace.jsonl`.
- Binary version 0.6.0.

## Non-Goals

- The construct mode that rewrites (after the binary release). The `prop-` prefix of skill names (issue 123).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the rewrite.

## Impact

- Affected specs: `write`
- Affected code:
  - New: Sources/PropositionsKit/WriteRewrite.swift, tests/PropositionsKitTests/WriteRewriteTests.swift
  - Modified: Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/CLI.swift, Sources/PropositionsKit/Version.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
