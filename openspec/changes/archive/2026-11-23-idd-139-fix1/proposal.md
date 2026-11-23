## Why

The first verify round of issue 139 found several problems. In a default-profile ledger a result is a `claim`, so the motivation obligation never applied to mathematical results. The guard did not pin the entry. The construction requirement's body disagreed with its scenario about when the skill may tell the author instead of writing the question first, and W8 had no item for that notice.

## What Changes

- The entry also applies to `claim`, and the guard pins it as a gap owned by issue 141.
- The construction requirement lets write mode tell the author, as its scenario does, and W8 shows the notice.
- The outline requirement names definitions too.
- `OBLIGATIONS.md` says which parts of the axiom the entry covers.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`, `article-construction`, `article-outline`

## Impact

- Affected specs: `article-obligations`, `article-construction`, `article-outline`
- Affected code:
  - Modified: plugins/propositions/catalog/obligations.yaml, plugins/propositions/docs/OBLIGATIONS.md
  - Modified: plugins/propositions/skills/prop-construct/SKILL.md, plugins/propositions/skills/prop-outline/SKILL.md
  - Modified: tests/test_plugin_payload_tracked.py
