## Why

The first review found that the audits read a file a line at a time, so that a citation, a declaration or a path that runs over two lines was missed or misread; that a command written in `\verb` was read as source; that `## FYI` did not match the `## Fyi` that `run-audit.sh` looks for; and several smaller misreadings.

## What Changes

- Each file is read as one stream with the place of every character kept. Comments swallow their line end; `\verb`, `\lstinline` and the literal environments are not source.
- Arguments are read by what each command takes; `]` inside braces does not end an optional argument; a bibliography file is read entry by entry.
- A key is placed at its first citation in reading order; `*` is every entry only in `\nocite`; an entry written twice is reported twice.
- The Markdown report writes `## Fyi`, and a line of the manuscript cannot read as a heading of the report.
- The input tree, shared with the citation-direction check, no longer follows an `\input` written in `\verb`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `manuscript-audit`: how the manuscript and the bibliography are read.
- `citation-order`: `\verb` and `\lstinline` in the input tree.

## Impact

- Affected specs: `manuscript-audit`, `citation-order`
- Affected code:
  - Modified: Sources/PropositionsKit/AuditSource.swift, Sources/PropositionsKit/AuditSymbols.swift, Sources/PropositionsKit/AuditCitations.swift, Sources/PropositionsKit/AuditRun.swift, Sources/PropositionsKit/ReadingOrder.swift, tests/PropositionsKitTests/AuditTests.swift
