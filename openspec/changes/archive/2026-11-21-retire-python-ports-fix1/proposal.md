## Why

The review of the switch to the released binary found that the audit skill could run another binary than the pinned one through an inherited `PROPOSITIONS_CLI`, that `run-audit.sh` called a pass that did not run a failure, that `construct-batch` used `$MAIN` without setting it, and that `run-audit.sh` stopped on macOS's bash when a ledger had no `_meta.json`.

## What Changes

- The audit skill drops an inherited `PROPOSITIONS_CLI`; `run-audit.sh` names the passes that did not run.
- `construct-batch` stops when `LEDGER` or `MAIN` is not set; `run-audit.sh` runs on bash 3.2 without `_meta.json`.
- The audit rule and the plugin README say how the tool is run in a plugin session.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `manuscript-audit`: what `run-audit.sh` and the skill do when the tool did not run.

## Impact

- Affected specs: `manuscript-audit`
- Affected code:
  - Modified: plugins/propositions/scripts/run-audit.sh, plugins/propositions/skills/manuscript-audit/SKILL.md, plugins/propositions/skills/construct-batch/SKILL.md, plugins/propositions/rules/manuscript-consistency-audit.md, plugins/propositions/README.md, Sources/PropositionsKit/AuditRun.swift, Sources/PropositionsKit/LedgerOrder.swift, Sources/PropositionsKit/Paragraphs.swift, tests/PropositionsKitTests/AuditTests.swift, tests/PropositionsKitTests/LedgerOrderTests.swift, tests/PropositionsKitTests/ParagraphsTests.swift
