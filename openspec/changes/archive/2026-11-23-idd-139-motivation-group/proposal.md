## Why

The obligations table (#47) has seven groups, each a property that can be judged one item at a time. "Each element is called for by what precedes it" is a property of the sequence, and no group covers it (issue 139). The maintainer chose, on 2026-11-23, a group of its own rather than part of `placement`.

## What Changes

- An eighth group, `motivation` (引出), comes after `dependence`, with axiom `academic-writing/A2_motivated_by_prefix` (PsychQuant/che-axiom-systems#39).
- One obligation, `motivation.called-for-by-prefix`, applies to the claim types `definition`, `example` and `result`. Its check is a gap owned by issue 141.
- The guard, `OBLIGATIONS.md`, the README and CLAUDE.md say eight groups.
- `prop-construct` (W2, O2) and `prop-outline` (draft, revise) apply the principle when they write.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: eight groups; the document describes them.
- `article-construction`: write mode orders each example after its question.
- `article-outline`: draft and revise keep each example after its question.

## Impact

- Affected specs: `article-obligations`, `article-construction`, `article-outline`
- Affected code:
  - Modified: plugins/propositions/catalog/obligations.yaml, plugins/propositions/docs/OBLIGATIONS.md, plugins/propositions/README.md, CLAUDE.md
  - Modified: plugins/propositions/skills/prop-construct/SKILL.md, plugins/propositions/skills/prop-outline/SKILL.md
  - Modified: tests/test_plugin_payload_tracked.py
