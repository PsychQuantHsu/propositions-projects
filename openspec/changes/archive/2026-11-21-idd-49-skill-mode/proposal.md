## Why

The `write` commands of issue 49 are in the `propositions` binary 0.4.0, released on 2026-11-21. The plugin has to pin that release and run them from the construct skill.

## What Changes

- `hooks/cli.lock` names 0.4.0.
- `/propositions:construct` gains a write mode (W1 to W9) that drafts one paragraph, its propositions and its records in the staged copies, runs the gates and writes on one confirmation.
- Plugin version 0.16.0.

## Non-Goals

- A paragraph in the middle of a draft.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-construction`: the write mode.

## Impact

- Affected specs: `article-construction`
- Affected code:
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/skills/construct/SKILL.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
