## Why

Binary 0.8.0 reads `replaced_by` items in another ledger (issue 133). The plugin now pins it, so the skills can use the two-step rewrite and the scaffold can write schema 1.9.

## What Changes

- `hooks/cli.lock` pins 0.8.0; the plugin is 0.21.0.
- `prop-construct`: a move between documents is two rewrites, the receiving document first; the retirements of the second write `<ledger>#<id>`, and `revise retire` and `revise check` get `--ledger-dir`.
- `prop-extract`: the revision mode's retire step says the same.
- Operation D writes schema 1.9; the onboarding requirement said 1.7 in its text and 1.8 in its scenario.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `manuscript-onboarding`: the schema version the scaffold writes.

## Impact

- Affected specs: `manuscript-onboarding`
- Affected code:
  - Modified: plugins/propositions/hooks/cli.lock, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
  - Modified: plugins/propositions/skills/prop-construct/SKILL.md, prop-extract/SKILL.md, prop-ledger/SKILL.md, plugins/propositions/templates/ledger/_meta.template.json
