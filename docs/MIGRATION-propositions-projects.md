# propositions-projects — umbrella/marketplace migration plan (agreed 2026-07-31)

Decision: this repo becomes the self-hosted home of the propositions ecosystem —
a Claude Code **marketplace** (`propositions-projects`) with a `plugins/` monorepo
layout, replacing the current single-plugin root layout and the script mirror in
`psychquant-claude-plugins/plugins/math-tools`.

## Target layout

```
.claude-plugin/marketplace.json      # ALREADY ACTIVE as a single-plugin marketplace (name "propositions", source "./"); migration updates it in place
plugins/propositions/                # core: ledger tooling + general manuscript-QA skills
plugins/math-tools/                  # thin math-only pack (depends on core)
scripts/ + tests/                    # stay at root for the CI-pinned audit-chain entry point
```

## Sequencing (run as a spectra change; nothing here is done yet except the scaffold)

1. Implement the retired-field support first (issues: this repo #1, psychquant-claude-plugins #118/#119) → tag v0.1.2 → downstream CI bumps its pin and drops the interim retired-budget gate.
2. Move root plugin content into `plugins/propositions/`; port the domain-general skills from psychquant-claude-plugins math-tools; keep root `scripts/` as the CI entry (symlink or thin shims if needed).
3. Update the existing `.claude-plugin/marketplace.json` in place: marketplace name `propositions` → `propositions-projects`, replace the single `source: "./"` entry with the two `./plugins/*` entries (registered users re-run `claude plugin marketplace update`); repo rename `propositions` → `propositions-projects` (`gh repo rename`, old URLs redirect); update downstream workflow `repository:` refs explicitly.
4. psychquant-claude-plugins: math-tools entry → deprecation pointer to this marketplace; run the /plugin-update ritual so installed users migrate.
5. Adopt the release-flow discipline here (version bump + marketplace.json sync + `claude plugin marketplace update`).

## Non-goals

- Per-domain plugins for prose/psych variants — those are core profiles/config.
- Moving manuscript-side SCHEMA.md here — the spec travels with each ledger; plugins declare a supported schema range.
