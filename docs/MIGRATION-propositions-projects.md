# propositions-projects — umbrella/marketplace migration plan (agreed 2026-07-31)

Decision: this repo becomes the self-hosted home of the propositions ecosystem —
a Claude Code **marketplace** (`propositions-projects`) with a `plugins/` monorepo
layout, replacing the current single-plugin root layout and the script mirror in
`psychquant-claude-plugins/plugins/math-tools`.

## Target layout

```
.claude-plugin/marketplace.json      # activates the marketplace (draft below until migration)
plugins/propositions/                # core: ledger tooling + general manuscript-QA skills
plugins/math-tools/                  # thin math-only pack (depends on core)
scripts/ + tests/                    # stay at root for the CI-pinned audit-chain entry point
```

## Sequencing (run as a spectra change; nothing here is done yet except the scaffold)

1. Implement the retired-field support first (issues: this repo #1, psychquant-claude-plugins #118/#119) → tag v0.1.2 → downstream CI bumps its pin and drops the interim retired-budget gate.
2. Move root plugin content into `plugins/propositions/`; port the domain-general skills from psychquant-claude-plugins math-tools; keep root `scripts/` as the CI entry (symlink or thin shims if needed).
3. Activate `.claude-plugin/marketplace.json` (rename the draft); repo rename `propositions` → `propositions-projects` (`gh repo rename`, old URLs redirect); update downstream workflow `repository:` refs explicitly.
4. psychquant-claude-plugins: math-tools entry → deprecation pointer to this marketplace; run the /plugin-update ritual so installed users migrate.
5. Adopt the release-flow discipline here (version bump + marketplace.json sync + `claude plugin marketplace update`).

## Non-goals

- Per-domain plugins for prose/psych variants — those are core profiles/config.
- Moving manuscript-side SCHEMA.md here — the spec travels with each ledger; plugins declare a supported schema range.
