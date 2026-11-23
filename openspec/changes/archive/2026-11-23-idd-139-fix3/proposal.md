## Why

The third verify round of issue 139 found two wording problems. The construction requirement's first SHALL was unconditional while its next sentence allowed telling the author instead, and it could be read as leaving out plain write mode. The outline scenario still read as if the skill wrote the missing point.

## What Changes

- The construction requirement names its two allowed outcomes, covers write mode explicitly, and limits a sentence the skill writes to what the agreed paragraph already argues.
- The outline scenario matches its body: the skill asks for the point and writes none.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-construction`, `article-outline`

## Impact

- Affected specs: `article-construction`, `article-outline`
- Affected code:
  - Modified: plugins/propositions/skills/prop-construct/SKILL.md, plugins/propositions/catalog/obligations.yaml, plugins/propositions/docs/OBLIGATIONS.md, tests/test_plugin_payload_tracked.py
