## Why

After a manuscript is revised, its ledger has to be brought up to it, and the plugin has no operation for it (issue 56). The first of the five steps is to find each proposition's text again: as written, or with only its line breaks changed.

## What Changes

- A subcommand `propositions revise relocate`, a dry run unless `--write`. It writes the new location of a moved proposition, and the new location and text of a rewrapped one, and reports the ambiguous and missing ones.
- A changed ledger line is written as the Python tools write one; a number now keeps the way it was written when the JSON reader reads it.

## Non-Goals

- Retiring the missing propositions, redirecting citations, the check of `replaced_by` and the skill mode: the next changes of issue 56.

## Capabilities

### New Capabilities

- `revise`: the operations that bring a ledger up to a revised manuscript.

### Modified Capabilities

(none)

## Impact

- Affected specs: `revise` (new)
- Affected code:
  - New: Sources/PropositionsKit/Revise.swift, Sources/PropositionsKit/Relocate.swift, tests/PropositionsKitTests/RelocateTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, Sources/PropositionsKit/JSONValue.swift
