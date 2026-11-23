## Why

The second verify round of issue 139 found several problems. Listing `claim` made the motivation obligation cover every derived sentence, which is wider than the axiom's element set. The spec's list of required owners left out 141. Reorganize mode did not carry the rule. The outline requirement had a redundant sentence and let the skill write a point the author had not given.

## What Changes

- The entry applies to `definition`, `example` and `result` again; the spec says why default-profile results are not covered (issue 141), and the guard locks `applies`.
- 141 is among the required owners, and the reverse test iterates over them.
- The construction requirement covers reorganize mode, and shows the sentences the skill wrote.
- The outline requirement asks the author for the point instead of writing it, and covers the reverse move.

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
