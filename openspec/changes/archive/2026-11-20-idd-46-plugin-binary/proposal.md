## Why

The `propositions` binary is published (release `propositions-cli-v0.1.0`), but no plugin obtains it, so no skill calls `cite-order` and the obligation `dependence.cites-backward` is still a gap owned by issue 46. The maintainer decided on 2026-11-20 how a plugin obtains the binary: a SessionStart hook that downloads the pinned release and verifies it.

## What Changes

- The `propositions` plugin gets a SessionStart hook (`hooks/fetch-cli.sh`) and a lock file (`hooks/cli.lock`). The hook installs the pinned release into the plugin's data directory only when the SHA-256 and the signing team match the lock.
- Operation A of `/propositions:propositions` runs `propositions cite-order` after the ledger validator, and reports the citation direction as not checked when the binary is not there.
- The obligations table: `dependence.cites-backward` names the check `order:cites` and has no `owner`. The inventory has 46 ids. No entry is owned by issue 46.
- The requirement on the release script no longer says that no script downloads the binary.

## Non-Goals

- A binary for systems other than macOS. There the check does not run and the entry stays unverified.
- A binary with the `outline` subcommands (version 0.2.0) and the skill that would call them (issue 102). The lock names 0.1.0.
- Rules that turn what `cite-order` prints into an outcome (issue 71).
- Telling a roadmap or a promissory note from another forward citation (issue 93).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `citation-order`: how a plugin obtains the binary, and which skill calls it.
- `article-obligations`: the inventory gains `order:cites`; the forward-citation entry is no longer a gap.
- `article-outline`: one sentence on why the skill does not call the outline commands yet.

## Impact

- Affected specs: `citation-order`, `article-obligations`, `article-outline`
- Affected code:
  - New: plugins/propositions/hooks/hooks.json, plugins/propositions/hooks/fetch-cli.sh, plugins/propositions/hooks/cli.lock, tests/PropositionsKitTests/FetchHookTests.swift
  - Modified: plugins/propositions/skills/propositions/SKILL.md, plugins/propositions/catalog/obligations.yaml, plugins/propositions/docs/OBLIGATIONS.md, tests/test_plugin_payload_tracked.py, scripts/release-signed.sh, docs/RELEASE-FLOW.md, .claude/rules/swift-is-the-implementation-language.md, CLAUDE.md, plugins/propositions/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
