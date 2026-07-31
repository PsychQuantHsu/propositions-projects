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


## Status (2026-08-01) — steps 2–4 landed

- Step 2 (layout move): done — single implementation under plugins/propositions/, root scripts/ are forwarding shims, suite 143 passed + shim smoke tests
- Step 3 (marketplace update): done — name `propositions-projects`, two ./plugins/* entries; root plugin.json removed
- Step 4 (repo rename): done — `gh repo rename` 2026-08-01; local remotes + docs updated
- **D2 probe result (rename semantics, probed 2026-08-01)**: old-slug `marketplace add` works via GitHub redirect; `claude plugin marketplace update` follows the rename (name refreshes from the manifest); registered Source keeps the old slug until a one-time remove + re-add (recommended, documented in README Migration notes)
- Step 5 (cross-repo: psychquant-claude-plugins deprecation, downstream pin bump): NOT here — coordinated via PsychQuantHsu/propositions-projects#2

### vNext release-notes draft (per docs/RELEASE-FLOW.md step 5)

> Pinned entry-point contract unchanged — root scripts/ paths, audit report format, and exit codes are identical for pinned consumers (root entries are byte-transparent forwarding shims into plugins/propositions/scripts/, guarded by tests/test_root_shims.py).
