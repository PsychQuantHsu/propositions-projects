## Why

After a revision, a proposition whose text is gone is retired, and the propositions that replace it are recorded only in the text of `reason`, so that nothing downstream can follow them (issue 56). Citations of the retired proposition have to be pointed at its replacements by hand.

## What Changes

- Schema v1.8: `retired.replaced_by`, the ids of the live propositions that replace a retired one, empty for a deletion; optional, so older ledgers need no migration. The ledger template is v1.8.
- `propositions revise retire` writes the block; `propositions revise check` reports a `replaced_by` that names no live proposition, and is the check `ledger:replaced-by` of a new precondition `index.replacements-hold`; `propositions revise redirect` points citations of a retired proposition at its replacements that come before the citing one.

## Non-Goals

- Teaching the Python validator `replaced_by`: by the project rule it gets no new check.
- The skill mode that runs the steps together: the next change of issue 56.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `revise`: retire, check and redirect.
- `article-obligations`: the inventory gains `ledger:replaced-by`.

## Impact

- Affected specs: `revise`, `article-obligations`
- Affected code:
  - New: Sources/PropositionsKit/ReviseLedger.swift, Sources/PropositionsKit/ReviseRun.swift, tests/PropositionsKitTests/ReviseLedgerTests.swift
  - Modified: Sources/PropositionsKit/CLI.swift, docs/SCHEMA.md, plugins/propositions/templates/ledger/_meta.template.json, plugins/propositions/catalog/obligations.yaml, plugins/propositions/docs/OBLIGATIONS.md, tests/test_plugin_payload_tracked.py
