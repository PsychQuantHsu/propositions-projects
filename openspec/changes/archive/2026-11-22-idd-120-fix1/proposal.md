## Why

Review of issue 120 found that the parts of a rewrite were trusted from `write.json`, that two documents were treated as one where they share a main file or an id, and that kept trace records were rewritten.

## What Changes

- On a rewrite, check and commit work out the parts of the document again from the copy of `article.json` and the files of the run, and refuse a `write.json` that names other parts.
- A proposition id that the trace already names for another document does not stop a paragraph of this one.
- The trace records a rewrite keeps are kept byte for byte.
- `outline length --written` counts each part against its own ledger.
- A destination is compared by the name the file system gives the file, links followed in the order of the path; a path that holds a control character is not in the format.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: destinations.
- `article-outline`: `outline length --written`.

## Impact

- Affected specs: `write`, `article-outline`
- Affected code:
  - Modified: Sources/PropositionsKit/Article.swift, Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/WriteFromOutline.swift, Sources/PropositionsKit/WriteRewrite.swift, Sources/PropositionsKit/OutlineLength.swift, tests/PropositionsKitTests/DestinationsTests.swift
