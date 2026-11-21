## Why

The commands that write from an approved outline (issue 51) are in the `propositions` binary 0.5.0, released on 2026-11-21. The plugin has to pin that release and use them from the construct skill, with the reader the maintainer chose on 2026-11-21 to judge whether a paragraph says its points.

## What Changes

- `hooks/cli.lock` names 0.5.0.
- `/propositions:construct` write mode gains writing from an outline (O1 to O5).
- New agent `propositions:outline-point-reader`, Read only.
- Plugin version 0.17.0.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-construction`: writing from an outline.

## Impact

- Affected specs: `article-construction`
- Affected code:
  - New: plugins/propositions/agents/outline-point-reader.md
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/skills/construct/SKILL.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
