# propositions (core plugin)

Author-claim infrastructure for academic LaTeX manuscripts — the **general** layer of the propositions-projects marketplace:

- **Ledger tooling** (`scripts/`): `validate-propositions.py` (R1–R13), `refresh-prop-locations.py`, `assign-prop-ids.py` (temporary ids → UUID v7), `check-extraction-coverage.py` (every character of a line range covered by some prop), `validate-structure.py` (S1–S9 on the article-structure sidecars, format 2.0), `structure-state.py` (what the article still owes the reader at a position, and where the next proposition can attach), `structure-metrics.py` (does the dependency tree fit: crossing arcs, frontier length, commitment-order hits), `derive-paragraphs.py` (default paragraph plan from the TeX source) and `migrate-structure-v2.py` (version 1.0 sidecars → 2.0), audit chain (`run-audit.sh`, `audit-*.py`), shared LaTeX env parser and the one normalization step table R1 and the coverage check share (`scripts/_lib/`) — R9's theorem-env vocabulary is resolved from each manuscript's own `\newtheorem` declarations (whole `\input` tree), so envs named `ass` / `dfn` / `prop` / … are checked rather than silently skipped (#10); a manuscript declaring none falls back to the shipped default set
- **Moves** (`catalog/vocabulary.yaml`, `scripts/structure-explain.py`): an optional layer on the structure sidecars. A record may say what the sentence does (`move`) and a paragraph what kind it is (`type`); `structure-explain.py` reads a paragraph out as position, move, head and relation. `structure-batch.py --moves-only` labels moves without touching the tree, `build-link-catalog.py` writes every kind of link observed between moves to `catalog/links.csv` (counts only, not rules), `structure-links.py` lists every link of one sentence and the seen and unseen paths of one move, and `structure-metrics.py --compare-moves` reports Cohen's kappa between two labellings. Sidecars with these fields need PyYAML; sidecars without them do not. (#33)
- **Skills** (`skills/`): `propositions` (onboard + mechanical gate + drift refresh，Operations A/B/D), `extract` (paragraph / section / theorem → propositions, staged and gated by the validator and the coverage check; Operation C now points here), `construct` (the article as a whole: annotate commitments, section roles and the dependency tree — each proposition's head in its paragraph, each paragraph's head in its section — or say what the next sentence of a draft should do and where it attaches), `construct-batch` (long manuscripts: reorder the ledger into reading order, then annotate the tree in paragraph-safe batches), `clarity-audit`, `proofread`（雙軌：Mode A 推導鏈 L1-L5／Mode B 實證 E1-E8）, `manuscript-audit` — domain-general manuscript QA
- **Article structure** (`docs/STRUCTURE.md`): `structure.json` (thesis, section plan with `parent`, paragraph plan) and `discourse.jsonl` (each proposition's head inside its paragraph and its relation to it, commitments opened and kept) sit beside the ledger without changing it; format 2.0, three closed vocabularies (10 relations, 7 commitment kinds, 10 section roles)
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
