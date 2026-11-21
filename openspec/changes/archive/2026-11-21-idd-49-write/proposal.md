## Why

The plugin can propose the next sentence of a draft but writes nothing (issue 49). Writing a paragraph changes four files: the manuscript, the ledger and the two structure sidecars, and they have to change together, after the author has seen them, and only if no one changed them in the meantime.

## What Changes

- `propositions write prepare` stages copies and records where the paragraph goes; `write check` says whether the copies differ only by a new paragraph and counts the placeholders `{PENDING: …}`; `write commit` writes the four files behind a check of their hashes, after keeping the originals.
- The obligations entry `completeness.no-placeholder` is owned by issue 81 (the maintainer decided on 2026-11-15 that the check of placeholders is another issue).
- Binary version 0.4.0.

## Non-Goals

- The skill mode that drafts the paragraph and calls these commands: after the binary release, as for the other commands.
- Paragraphs in the middle of a draft.

## Capabilities

### New Capabilities

- `write`: the commands that write a new paragraph.

### Modified Capabilities

- `article-obligations`: the owner of the placeholder entry.

## Impact

- Affected specs: `write` (new), `article-obligations`
- Affected code:
  - New: Sources/PropositionsKit/WriteParagraph.swift, tests/PropositionsKitTests/WriteParagraphTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, Sources/PropositionsKit/Version.swift, plugins/propositions/catalog/obligations.yaml, tests/test_plugin_payload_tracked.py, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
