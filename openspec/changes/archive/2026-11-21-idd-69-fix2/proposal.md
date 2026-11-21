## Why

The second review found that the input tree, shared with the citation-direction check, still read a `%` in an address as a comment and an `\\input` in `minted` as an include; that literal text, once removed, joined what stood around it; that `\\cite *`, `\\volcite` and the definition of citation commands were misread; that a citation before an `\\input` on its line was placed after the included file; and that a quoted value with a parenthesis cut a BibTeX record short.

## What Changes

- The input tree masks `\\verb` and `\\lstinline` with their delimiters and the arguments of `\\url` and its kin, and knows `BVerbatim` and `minted`.
- Literal text stands in the source as one opaque character. Formatted text is read as printed, braces included.
- Citations: a `*` after white space, `\\volcite`, definitions and parameters left out; reading order compared before the offset.
- BibTeX records read with quoted values; a key needs a comma or the end of its record; an unused entry is placed at its `@`.
- The warnings of the declarations come before an error; keys in messages are escaped.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `manuscript-audit`: how literal text, formatted text, citations and records are read.
- `citation-order`: the literal text the input tree does not read.

## Impact

- Affected specs: `manuscript-audit`, `citation-order`
- Affected code:
  - Modified: Sources/PropositionsKit/AuditSource.swift, Sources/PropositionsKit/AuditSymbols.swift, Sources/PropositionsKit/AuditCitations.swift, Sources/PropositionsKit/AuditRun.swift, Sources/PropositionsKit/ReadingOrder.swift, tests/PropositionsKitTests/AuditTests.swift
