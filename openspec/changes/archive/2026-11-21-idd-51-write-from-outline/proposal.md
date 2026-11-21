## Why

Issue 51 writes text from an approved outline, paragraph by paragraph. The write commands of issue 49 could only add a paragraph after an existing proposition, and could not add a section heading; nothing stopped writing from a section the author had not approved; and nothing recorded which outline record a paragraph came from (the maintainer chose, on 2026-11-21, a new file for that).

## What Changes

- `write prepare` places the first paragraph of a draft with no proposition before `\end{document}`; `--heading` allows a heading line before the paragraph; `--outline` and `--outline-paragraph` gate the write on the record's section standing as approved and keep the outline files unchanged until the commit.
- `write commit` appends a record to `outline-trace.jsonl`.
- `propositions outline trace` lists and checks the records.
- `docs/OUTLINE.md` describes the trace file. Binary version 0.5.0.

## Non-Goals

- Rewriting a finished manuscript from a revised outline (issue 115), commitments on the outline (issue 116), gaps for unread files (issue 117), a list of phrases not to use (issue 118), length targets (issue 119), more than one destination (issue 120).
- The skill mode and the reader agent: after the binary release.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: three requirements.
- `article-outline`: the trace file and its check.

## Impact

- Affected specs: `write`, `article-outline`
- Affected code:
  - New: Sources/PropositionsKit/WriteFromOutline.swift, tests/PropositionsKitTests/WriteFromOutlineTests.swift
  - Modified: Sources/PropositionsKit/WriteParagraph.swift, Sources/PropositionsKit/CLI.swift, Sources/PropositionsKit/Version.swift, plugins/propositions/docs/OUTLINE.md, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
