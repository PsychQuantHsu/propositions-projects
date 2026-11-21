## Why

Issue 120: the content of one plan can go to the main text, an appendix or an online supplement, and these are often different documents. A section record says its `part`, but the write commands knew one main file and one ledger, and the trace assumed every proposition was in one ledger.

## What Changes

- `article.json` can carry `destinations`: for a part, the main file and the ledger of the document it is written into.
- `write prepare --outline` refuses a paragraph whose section goes to a part other than the document given, and `write commit` records the part in the trace.
- `write prepare --rewrite` rewrites one document: `outline-map.jsonl` lists the records whose sections go to it, and the trace records of other documents are kept.
- `outline trace` checks the records of the document whose ledger it is given and lists the others; `outline length --written` counts each part from its own document.
- Binary version 0.7.0.

## Non-Goals

- Moving content from one document to another in a rewrite (a proposition of one ledger replaced by one of another ledger).
- References between documents.
- The construct skill choosing the files from the destinations (after the binary release).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: destinations.
- `article-outline`: the `part` of a trace record, and `outline trace` and `outline length` with destinations.

## Impact

- Affected specs: `write`, `article-outline`
- Affected code:
  - New: tests/PropositionsKitTests/DestinationsTests.swift
  - Modified: Sources/PropositionsKit/Article.swift, Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/WriteFromOutline.swift, Sources/PropositionsKit/WriteRewrite.swift, Sources/PropositionsKit/OutlineLength.swift, Sources/PropositionsKit/CLI.swift, Sources/PropositionsKit/Version.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
