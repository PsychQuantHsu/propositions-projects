## Why

The requirement on derive still said that an included file that was not read leaves nothing in the outline, and that derive stops when every section's text is in such files. Issue 117 changed both: the file is recorded in `unread` of its section record, and derive goes on with an empty paragraph file.

## What Changes

- The requirement on derive and its scenarios say what derive does now.
- The requirement on the explanatory document no longer says that writing from an outline is a later step.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-outline`: derive and unread files; the explanatory document.

## Impact

- Affected specs: `article-outline`
- Affected code:
  - Modified: plugins/propositions/skills/prop-outline/SKILL.md, plugins/propositions/docs/OUTLINE.md
