## Why

The `revise` commands of issue 56 are in the `propositions` binary 0.3.0, released on 2026-11-21. The plugin has to pin that release and run the commands from the extraction skill.

## What Changes

- `hooks/cli.lock` names 0.3.0.
- `/propositions:extract` gains a revision mode that runs relocate, retire, redirect, ledger-order and the gates, with a second reading of the claim types.
- Plugin version 0.15.0.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `proposition-extraction`: the revision mode.

## Impact

- Affected specs: `proposition-extraction`
- Affected code:
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/skills/extract/SKILL.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
