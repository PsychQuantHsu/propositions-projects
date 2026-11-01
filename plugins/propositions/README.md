# propositions (core plugin)

Author-claim infrastructure for academic LaTeX manuscripts — the **general** layer of the propositions-projects marketplace:

- **Ledger tooling** (`scripts/`): `validate-propositions.py` (R1–R13), `refresh-prop-locations.py`, `assign-prop-ids.py` (temporary ids → UUID v7), `check-extraction-coverage.py` (every character of a line range covered by some prop), audit chain (`run-audit.sh`, `audit-*.py`), shared LaTeX env parser and the one normalization step table R1 and the coverage check share (`scripts/_lib/`) — R9's theorem-env vocabulary is resolved from each manuscript's own `\newtheorem` declarations (whole `\input` tree), so envs named `ass` / `dfn` / `prop` / … are checked rather than silently skipped (#10); a manuscript declaring none falls back to the shipped default set
- **Skills** (`skills/`): `propositions` (onboard + mechanical gate + drift refresh，Operations A/B/D), `extract` (paragraph / section / theorem → propositions, staged and gated by the validator and the coverage check; Operation C now points here), `clarity-audit`, `proofread`（雙軌：Mode A 推導鏈 L1-L5／Mode B 實證 E1-E8）, `manuscript-audit` — domain-general manuscript QA
- **Verification records** (`docs/VERIFICATION.md`): verdicts from proofread, Lean, certificates, CAS, cross-model or human review live in a `verification.jsonl` sidecar next to the ledger (the ledger schema is unchanged); `validate-verification.py` checks it and lists cross-method disagreements, `proofread-to-verification.py` converts a proofread checklist
- **Templates** (`templates/ledger/`): Operation D 的 scaffold 骨架（README / _meta.template.json / _smoke_tests）— SCHEMA 與 EXTRACTION-PROMPT 不放模板，scaffold 時從 canonical 現拷釘版
- Domain variation (math / psych / prose) enters as **profiles of this core**, not separate plugins: a ledger declares `profile` in `_meta.json` (schema 1.7). `default` is the mathematical vocabulary; `empirical` adds proofread Mode B's values plus `external` (#24)

The repository-root `scripts/` entries are forwarding shims into this plugin (pinned-CI entry-point contract); the pytest suite at the repository root exercises those shims end-to-end.

## Schema compatibility

Each manuscript's ledger carries its own `SCHEMA.md` (the spec travels with the data — this plugin vendors no copy). This plugin supports:

| Ledger schema | Validator behavior |
|---|---|
| v1.0 / v1.1 | Full R1–R13 run; v1.2+-only rules skipped with notice |
| v1.2 / v1.3 | Adds R7 (UUID v7 IDs), R11 (`evidence_class` enum), R12 (`claim_type` enum) — requires `--meta` pointing at the ledger's `_meta.json` |
| v1.4 | `retired` field: R1 treats `line_comment` / `removed` as expected-absent (reported as `[R1-retired]`, non-blocking; a warning if the words are live again), keeps checking `comment_env`, and grants no exemption to a malformed block (every documented format is checked); R13 skips only props R1 confirmed absent |
| v1.5 | Adds `retired.superseded_mechanism` (recorded, not validated) |
| v1.7 | `_meta.json` `profile` (`default` / `empirical`) selects the R11/R12 vocabularies; a profile on a sub-v1.7 ledger or an unknown value → error. Ledgers without the field validate exactly as before |
| v1.6 | Multi-file manuscripts: file-qualified `location` prefixes (`parts/foo.tex:L123`, resolved against the `\input`/`\include` tree), optional `_meta.json` `source.parts` snapshot; R1/R9/R13 become file-aware. Prefix on a sub-v1.6 ledger → R13 FAIL with upgrade hint |

**Supported range: up to 1.7.** Newer schema versions than this table may validate incompletely; check the release notes before bumping a ledger's schema.
