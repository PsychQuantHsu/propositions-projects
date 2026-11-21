## Why

The requirement on kept trace records said each keeps the line ending it had, and the code adds a line feed after a kept record that had none when a new record follows. Without it the file would not be one record per line.

## What Changes

- The requirement states the exception. No behaviour changes.
- Review round 3: the comparison uses Unicode case folding (a dotless i is not an i) and adds no space after the last line; a paragraph is counted once however many of its propositions the trace names; a `]` inside braces does not end an optional argument; a mapped proposition without a location is reported; two paths are one file only byte for byte.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: kept trace records.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/Phrasing.swift, Sources/PropositionsKit/Article.swift, Sources/PropositionsKit/OutlineLength.swift, Sources/PropositionsKit/WriteRewrite.swift, tests/PropositionsKitTests/
