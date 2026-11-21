## Why

Review of issue 118 found that the comparison with banned phrasings missed text it should find, and that the write check could be made to pass over the list.

## What Changes

- Letter case is compared without regard to how a language writes it (`ß` and `SS`); white space at an end of a phrase is one space there; occurrences that overlap are each reported; a `%` followed by a combining mark is still a comment sign; the main file is reported under its own name.
- A staging directory whose `write.json` no longer names the `article.json` or the outline that prepare copied is refused.
- A rewrite whose staged manuscript includes a file that prepare did not copy is reported: such a file would be neither compared nor written.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: the comparison and what a run may not pass over.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/Phrasing.swift, Sources/PropositionsKit/WriteParagraph.swift, tests/PropositionsKitTests/PhrasingTests.swift
