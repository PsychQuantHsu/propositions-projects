## Why

The first review found that the command refused a manuscript of one file when an `\input` of its main file led to no file, which the Python tool answers; that a location written from the root of the file system could be read as a file of the tree; and three more places where the two tools differed without the specification saying so.

## What Changes

- The input tree is read only when a location names another file.
- A location from the root of the file system is refused before its name is normalised.
- A row of the ledger is read as it stands; section starts are compared by code points; `sections` that is an object or a string gives no section.
- The list of differences is corrected. The tests compare standard output byte for byte and check the whole list that is printed.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `paragraph-plan`: when the tree is read, and the differences from the Python tool.

## Impact

- Affected specs: `paragraph-plan`
- Affected code:
  - Modified: Sources/PropositionsKit/Paragraphs.swift, tests/PropositionsKitTests/ParagraphsTests.swift
