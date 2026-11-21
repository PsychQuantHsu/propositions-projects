## Why

The rewrite command of issue 115 is in the `propositions` binary 0.6.0, released on 2026-11-21. The plugin has to pin it and use it from the construct skill, which the maintainer chose on 2026-11-21 as the home of reorganizing.

## What Changes

- `hooks/cli.lock` names 0.6.0.
- `/propositions:construct` gains reorganize mode (G1 to G9).
- Plugin version 0.18.0.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-construction`: reorganize mode.

## Impact

- Affected specs: `article-construction`
- Affected code:
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/skills/construct/SKILL.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
