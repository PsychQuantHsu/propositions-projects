## Why

The second review found that a file that starts with a byte-order mark was read where the Python tool refuses it, that `./main.tex` was taken for the main file where the Python tool refuses it, and a test that could not fail.

## What Changes

- Files are decoded as strict UTF-8 with a byte-order mark kept. Only the exact name `main.tex` is the main file.
- The specification names what a paragraph start is for a ledger out of order, the carriage return in a ledger, ids that are lists, and the help text.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `paragraph-plan`: decoding, the main file's name, and the differences from the Python tool.

## Impact

- Affected specs: `paragraph-plan`
- Affected code:
  - Modified: Sources/PropositionsKit/Paragraphs.swift, tests/PropositionsKitTests/ParagraphsTests.swift
