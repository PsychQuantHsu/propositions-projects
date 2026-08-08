# propositions (core plugin)

Author-claim infrastructure for academic LaTeX manuscripts — the **general** layer of the propositions-projects marketplace:

- **Ledger tooling** (`scripts/`): `validate-propositions.py` (R1–R13), `refresh-prop-locations.py`, audit chain (`run-audit.sh`, `audit-*.py`), shared LaTeX env parser (`scripts/_lib/`)
- **Skills** (`skills/`): `propositions` (extraction + mechanical gate), `clarity-audit`, `proofread`, `manuscript-audit` — domain-general manuscript QA
- Domain variation (math / psych / prose) enters as **profiles/config of this core**, not separate plugins

The repository-root `scripts/` entries are forwarding shims into this plugin (pinned-CI entry-point contract); the pytest suite at the repository root exercises those shims end-to-end.

## Schema compatibility

Each manuscript's ledger carries its own `SCHEMA.md` (the spec travels with the data — this plugin vendors no copy). This plugin supports:

| Ledger schema | Validator behavior |
|---|---|
| v1.0 / v1.1 | Full R1–R13 run; v1.2+-only rules skipped with notice |
| v1.2 / v1.3 | Adds R7 (UUID v7 IDs), R11 (`evidence_class` enum), R12 (`claim_type` enum) — requires `--meta` pointing at the ledger's `_meta.json` |
| v1.4 | `retired` field recognized in ledger data; native validator support tracked upstream (#1, psychquant-claude-plugins#118) |
| v1.5 | Adds `retired.superseded_mechanism`; same upstream-support status as v1.4 |

**Supported range: up to 1.5.** Newer schema versions than this table may validate incompletely; check the release notes before bumping a ledger's schema.
