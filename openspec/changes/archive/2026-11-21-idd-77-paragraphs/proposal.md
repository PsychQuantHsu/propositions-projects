## Why

`derive-paragraphs.py` stops when a proposition's location names a file other than the main file, so a manuscript of several files gets no paragraph plan and its paragraphs have to be listed by hand (issue 77). The Swift package already reads a manuscript's input tree.

## What Changes

- A subcommand `propositions paragraphs`, the Swift port of `derive-paragraphs.py`. For a manuscript of one file it prints and exits as the Python tool does. A location may name any file of the main file's input tree.

## Non-Goals

- Changing the skills that call the Python tool, and removing the Python tool (the migration tool for structure sidecars loads it). These wait for a released binary.
- A key for the file in the paragraph list: the structure sidecar's format has `id` and `first_prop` only.
- Paragraphs that run across an `\input` line.

## Capabilities

### New Capabilities

- `paragraph-plan`: the command that proposes a paragraph plan.

### Modified Capabilities

(none)

## Impact

- Affected specs: `paragraph-plan` (new)
- Affected code:
  - New: Sources/PropositionsKit/Paragraphs.swift, tests/PropositionsKitTests/ParagraphsTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, .claude/rules/swift-is-the-implementation-language.md, CLAUDE.md
