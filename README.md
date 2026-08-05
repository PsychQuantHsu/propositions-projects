# propositions-projects

**Umbrella marketplace for the propositions ecosystem — author-claim infrastructure for academic LaTeX manuscripts.**

Line-addressable propositions (JSONL) extracted from `main.tex` + R1-R13 mechanical validator + audit tooling + extraction discipline. Originally developed as the "Locke project" for `PsychQuantHsu/psychophysical_representations` and packaged as a reusable Claude Code plugin.

## What it does

Solves three problems that LaTeX-heavy academic manuscripts run into:

1. **"What did I claim in §4?"** — every declarative claim has a UUID + verbatim text + line range. Grep `prop.text` is faster than re-reading.
2. **"Does my proof actually use what it cites?"** — `cites` UUID chain + R3 DAG validation surface orphans and circular references.
3. **"Did I just silently break the manuscript by reformulating Theorem 3?"** — R1 substring containment + R13 line-anchoring fire LOUD when the propositions JSONL drifts from `main.tex`.

## Install

This repo is a **self-hosted marketplace** (`propositions-projects`) with a `plugins/` monorepo layout. It currently publishes exactly one plugin: the core `propositions` plugin (validator + audit chain + manuscript-QA skills). Domain packs get their own `plugins/<domain>/` directory only when domain-specific content actually lands — never as an empty placeholder.

```bash
# Add the marketplace from GitHub
claude plugin marketplace add PsychQuantHsu/propositions-projects

# Install the core plugin
claude plugin install propositions@propositions-projects
```

## Migration notes (2026-08 rename: propositions → propositions-projects)

The repository and marketplace were renamed from `propositions` to `propositions-projects` when the umbrella layout landed. Verified behavior (probed 2026-08-01):

- **Already registered under the old name?** No action strictly required — GitHub redirects the old repo slug, and `claude plugin marketplace update` follows it (name shown updates from the manifest). Your registration's recorded Source keeps the old slug until you re-add.
- **Recommended one-time cleanup** (drops the redirect dependency):

  ```bash
  claude plugin marketplace remove propositions-projects
  claude plugin marketplace add PsychQuantHsu/propositions-projects
  ```

- **Coming from the deprecated psychquant-claude-plugins `math-tools` plugin?** The four manuscript-QA skills (clarity-audit / proofread / manuscript-audit / propositions) now live in the core `propositions` plugin here. **Remove the old plugin before or right after installing the core plugin** — running both leaves two copies of the same-named skills installed:

  ```bash
  claude plugin uninstall math-tools@psychquant-claude-plugins
  claude plugin install propositions@propositions-projects
  ```

  After migrating, invoke the skills as `propositions:<skill>` — e.g. `/propositions:proofread`, `/propositions:manuscript-audit`. **This marketplace does not publish a `math-tools` plugin**; the name is reserved for genuinely math-only content (sympy substitution verification, Lean bridging) and will only appear here once such content exists.

### Coordinated changes tracked elsewhere (#2)

| Where | What | When |
|---|---|---|
| psychquant-claude-plugins | math-tools entry → deprecation pointer to this marketplace | after core-plugin parity is announced (it is, as of this rename) |
| downstream manuscript-repo CI | workflow `repository:` ref → `PsychQuantHsu/propositions-projects` + tag pin bump | after the vNext tag that includes retired-field support (#1) |

## Quick start

```bash
# Inside your manuscript repo (with manuscript/main.tex + manuscript/propositions/main.jsonl)

/propositions:propositions       # the mechanical axis — three operations in one skill:
                                 #   A validate      R1-R13 gates
                                 #   B refresh       fix location drift (dry-run gated)
                                 #   C extract       build a new / re-extracted JSONL
/propositions:proofread          # per-prop L1-L5 semantic walk (is each claim true & faithful?)
/propositions:manuscript-audit   # cross-artifact drift across tex / jsonl / code / bib
/propositions:clarity-audit      # prose readability — can a human reader follow it?
```

## Architecture

| Layer | Lives where | Purpose |
|-------|-------------|---------|
| **Discipline** | `rules/` (this plugin) | per-commit sync + audit-time SOP |
| **Tooling** | `plugins/propositions/scripts/` (root `scripts/` = forwarding shims for the pinned CI contract) | validator + locator + audit suite |
| **Data** | `manuscript/propositions/main.jsonl` (your repo) | the actual propositions |

## Validator rules (R1-R13)

| Rule | What |
|------|------|
| R1 | every `prop.text` is a substring of `main.tex` (normalize-aware) |
| R1.5 | every `\section{}` has ≥1 prop (informational coverage) |
| R2 | every `cites` UUID resolves |
| R3 | no cite cycles + orphan detection |
| R4 | mechanical-contradiction patterns |
| R7 | UUID v7 ID format (schema v1.2+) |
| R8 | unique IDs |
| R9 | `containing_block` env line range consistency |
| R10 | `connective`/`reference` claim_types have empty `asserts` |
| R11 | `evidence_class` enum membership (schema v1.2+) |
| R12 | `claim_type` enum membership (schema v1.2+) |
| R13 | single-line `location` anchors to actual text start |

See `docs/SCHEMA.md` for the canonical schema contract.

## Project history

The infrastructure was built from 2026-05-12 onward through a marathon of 30+ issues in `PsychQuantHsu/psychophysical_representations` (#69 onward). The Locke / John Locke reference encodes the epistemological discipline behind the project: every author-level claim must be authoritatively addressable, not buried in LaTeX bytes.

See `docs/locke-project.md` in `PsychQuantHsu/psychophysical_representations` for the full origin narrative.

## Layout

```
propositions-projects/
├── .claude-plugin/
│   └── marketplace.json     # marketplace catalog (one entry: propositions)
├── plugins/
│   └── propositions/        # the published plugin — everything below ships to installers
│       ├── .claude-plugin/plugin.json
│       ├── README.md
│       ├── skills/          # user-invocable slash commands
│       │   ├── propositions/SKILL.md      # validate / refresh / extract
│       │   ├── proofread/SKILL.md         # per-prop L1-L5 semantic walk
│       │   ├── manuscript-audit/SKILL.md  # cross-artifact drift
│       │   └── clarity-audit/SKILL.md     # prose readability
│       └── scripts/         # validator + audit tooling
│           ├── validate-propositions.py
│           ├── refresh-prop-locations.py
│           ├── audit-theorem-boundaries.py
│           ├── audit-{citations,symbols,code-manuscript}.py
│           ├── run-audit.sh
│           ├── migrate-{prop-id-to-uuid,json-to-jsonl}.py
│           └── _lib/latex_env_parser.py
├── CLAUDE.md                # repo-level instructions
├── README.md                # this file
├── scripts/                 # forwarding shims into the plugin (pinned-CI entry points)
├── tests/                   # pytest test suite (142+ tests)
├── rules/                   # discipline rules
│   ├── manuscript-jsonl-sync.md
│   └── manuscript-consistency-audit.md
└── docs/                    # contract docs
    ├── SCHEMA.md
    └── EXTRACTION-PROMPT.md
```

## Compatibility

- Python 3.10+
- pytest 7+
- LaTeX manuscript with `manuscript/main.tex` + `manuscript/propositions/main.jsonl` layout (paths configurable via skill args)
- Schema versions v1.0 / v1.1 / v1.2 / v1.3

## License

MIT
