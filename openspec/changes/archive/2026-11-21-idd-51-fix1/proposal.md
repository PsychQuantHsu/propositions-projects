## Why

The first review of the write-from-outline change found that the outline was judged from other bytes than the ones copied, that the trace path could be one of the files written, that the traced proposition was not checked, that a link at the trace path was not seen, that commit trusted the plan in `write.json`, and that a heading was recognised by its first characters.

## What Changes

- The outline is read once, and judged, copied and hashed from the same bytes; commit judges it again and compares.
- The trace may not be one of the written files; a link or anything at its path is refused; the traced proposition has to be one live proposition starting in the new lines, not named by the trace yet.
- A heading is a whole line; any other line that begins a sectioning command is a problem.

## Non-Goals

- Keeping two commits on one trace apart: stated as a limit.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `write`: two requirements.

## Impact

- Affected specs: `write`
- Affected code:
  - Modified: Sources/PropositionsKit/WriteFromOutline.swift, Sources/PropositionsKit/WriteParagraph.swift, tests/PropositionsKitTests/WriteFromOutlineTests.swift
