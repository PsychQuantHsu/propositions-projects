## Why

Issue 117: when an outline is derived, an included file that cannot be read (ignored by git, outside the repository, behind a symbolic link, missing) leaves no record. The outline does not show that part of the original is missing, which matters most when text is written from it. Two ways of recording it were tried under issue 75 and withdrawn: a paragraph record whose locator named the include command stopped derive when one file was included twice, and a sentence in the `note` of an existing record had no record to go to when every section held only such includes.

## What Changes

- A section record can carry `unread`: a list of `{"file", "why"}`, one entry for each include of a file that was not read in that section. It uses no locator, so a file included twice is two entries, and a section whose whole text is unread still has its section record.
- `outline check` checks the shape of `unread`; `outline status` prints one more line, `sections that carry unread`, before `ok status`.
- `write prepare --outline` prints a note for each unread file of the section the paragraph is written into and of the sections above it; `--rewrite` prints one for every section.

## Non-Goals

- The position of the include inside the section: it is not recorded.
- What the unread file holds.
- The outline skill writing `unread` in derive, and its own status command printing the new line (after the binary release).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: the key `unread` of a section record and the status line.
- `write`: the notes of `write prepare`.

## Impact

- Affected specs: `article-outline`, `write`
- Affected code:
  - New: tests/PropositionsKitTests/OutlineUnreadTests.swift
  - Modified: Sources/PropositionsKit/OutlineCheck.swift, Sources/PropositionsKit/OutlineStatus.swift, Sources/PropositionsKit/WriteFromOutline.swift, Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/WriteRewrite.swift, tests/PropositionsKitTests/OutlineTests.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md
