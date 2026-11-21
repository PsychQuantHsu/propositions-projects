## Why

The requirements added for destinations (issue 120) left three earlier requirements saying something that no longer holds when `article.json` names destinations: that a trace record has exactly four keys, that a rewrite lists every paragraph record and writes the trace from the map alone, and that any earlier record of a proposition stops a commit.

## What Changes

- The three requirements say what holds with destinations and point to the requirement on destinations. No behaviour changes.
- The help text of `outline status` names the line `sections that carry unread`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: the trace record.
- `write`: the rewrite and the paragraph written from an outline record.

## Impact

- Affected specs: `article-outline`, `write`
- Affected code:
  - Modified: Sources/PropositionsKit/CLI.swift
