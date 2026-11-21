## Why

Review of issue 119 found inputs on which the word count and the length report were wrong.

## What Changes

- A command that takes a name skips its optional arguments and one argument, with white space before them; text in a group after that is counted. `\end {equation}` ends its environment. Punctuation of the kana block is not a word, half-width kana are, and a fraction sign is not.
- A file of the manuscript that cannot be read stops the report (exit 2) and is no longer counted as a proposition that was not found.
- A paragraph is counted once however many trace records name its proposition, and a record that does not qualify does not hide a later one that does.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: how words and written paragraphs are counted.

## Impact

- Affected specs: `article-outline`
- Affected code:
  - Modified: Sources/PropositionsKit/OutlineLength.swift, tests/PropositionsKitTests/OutlineLengthTests.swift
