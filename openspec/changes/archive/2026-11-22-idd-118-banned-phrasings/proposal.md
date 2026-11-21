## Why

Issue 118: a real manuscript has a list of phrasings that must not appear again. Nothing recorded such a list, and nothing checked a paragraph against it before it was written.

## What Changes

- A new optional file `article.json`, beside the ledger (in the outline directory when a paragraph is written from an outline), holds what is true of the whole article. This change defines its `banned` key: a list of `{"phrase", "reason"}`.
- `write prepare` reads and copies it as an input that may not change; `write check` reports each banned phrasing in the text the run adds (the new lines; for a rewrite, every file of the tree) as a problem, so `write commit` refuses.
- `propositions phrasing --tex <main file> --article <file>` runs the same comparison over the whole input tree.

## Non-Goals

- The `length` and `destinations` keys of `article.json` (issues 119 and 120).
- Matching a phrasing that is worded differently; the comparison is literal.
- The construct skill telling the author about a hit (after the binary release).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the banned phrasings of `article.json`.

## Impact

- Affected specs: `write`
- Affected code:
  - New: Sources/PropositionsKit/Article.swift, Sources/PropositionsKit/Phrasing.swift, tests/PropositionsKitTests/PhrasingTests.swift
  - Modified: Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/CLI.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md
