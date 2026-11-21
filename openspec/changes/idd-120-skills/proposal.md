## Why

Issues 116 to 120 added, in binary 0.7.0, planned commitments, length targets, unread included files, banned phrasings and destinations. The skills did not use any of it: derive still recorded nothing for an unread file, and the construct skill did not know the new refusals and notes of the write commands.

## What Changes

- The outline skill: derive records an unread included file in `unread` of its section record and no longer stops when all text is in such files; revise and draft write `opens`, `discharges` and `length` when the author asks; the write check and the status command of the skill know the new keys.
- The construct skill, in write mode, writing from an outline and reorganize mode: reads the banned list, follows planned commitments, passes on the `[unread]` notes, chooses the document of a section's part, lists only that document's records in a rewrite, and reports lengths after a commit.
- `cli.lock` pins binary 0.7.0.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: the skill and the new keys.
- `article-construction`: write mode and reorganize mode with the article file, planned commitments, unread files and destinations.

## Impact

- Affected specs: `article-outline`, `article-construction`
- Affected code:
  - Modified: plugins/propositions/skills/prop-outline/SKILL.md, plugins/propositions/skills/prop-construct/SKILL.md, plugins/propositions/hooks/cli.lock, plugins/propositions/docs/OUTLINE.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, CLAUDE.md, .claude/rules/swift-is-the-implementation-language.md
