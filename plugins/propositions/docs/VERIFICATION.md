# Verification records

The ledger (`main.jsonl`) decomposes a manuscript into propositions. It says
what the manuscript claims, not whether a claim is true. Verdicts from methods
outside the ledger are kept in a **sidecar**, `verification.jsonl`, next to it:

```
manuscript/propositions/
├── main.jsonl           # the ledger (unchanged by this format)
├── _meta.json
└── verification.jsonl   # one verdict per line
```

The ledger works as an index, and each verification method attaches to it
without changing its schema. One proposition can carry verdicts from several
methods side by side. Nothing in `validate-propositions.py` reads this file.

## Record format

One JSON object per line.

| Field | Required | Meaning |
|---|---|---|
| `prop_id` | ✅ | The ledger `id` (full UUID) this verdict is about |
| `method` | ✅ | How it was checked — see the vocabulary below |
| `status` | ✅ | The verdict — see the vocabulary below |
| `checked_at` | ✅ | `YYYY-MM-DD` date the check ran |
| `evidence_ref` | ✅ unless `not_attempted` | Where the evidence lives: a file and line, a Lean constant, a commit, a URL |
| `evidence_snapshot` | — | A short copy of the evidence (a hash, a statement) in case the reference moves |
| `tool` | — | `{"name": "...", "version": "..."}` |
| `checker` | — | Who or what ran the check |
| `notes` | — | Free text |

```json
{"prop_id": "019e2fbe-c7f3-77a7-be41-bfde9e052faf", "method": "lean", "status": "supported", "checked_at": "2026-09-25", "evidence_ref": "proofs/lean4/Proofs/FixedPoint.lean:unique_fixed_point", "tool": {"name": "lean", "version": "4.23.0"}}
{"prop_id": "019e2fbe-c7f3-77a7-be41-bfde9e052faf", "method": "proofread", "status": "partial", "checked_at": "2026-09-20", "evidence_ref": ".proofread/main.md:L42"}
```

Records are appended, not edited. Re-running a method adds a new record, and
the older one stays in the file as history.

## Vocabulary

`method`:

| Value | Meaning |
|---|---|
| `proofread` | The proofread skill's per-proposition reading (see below) |
| `lean` | A Lean 4 formal proof checked by the kernel |
| `exact_certificate` | An exact-arithmetic certificate (rational / interval computation) |
| `cas` | A computer-algebra recomputation |
| `cross_model` | An independent re-derivation by a different model |
| `human` | A human expert's review |
| `x-` prefix | Any other method, e.g. `x-monte-carlo`, before it earns a name here |

`status`:

| Value | Meaning |
|---|---|
| `supported` | The method confirms the proposition |
| `refuted` | The method shows the proposition is false |
| `partial` | Confirmed only in part, or the check found a problem short of refutation |
| `unresolved` | The method ran and could not decide |
| `not_attempted` | Deliberately not checked by this method (no evidence needed) |

### What proofread's `supported` means

A proofread `supported` means the proposition passed all six reading checks:
the asserts faithfully decompose the text, the claim type fits, nothing cited
in the text is missing from `cites`, the cited propositions imply this one, the
evidence class is consistent, and the location is right. It checks the ledger
entry and the argument's chain. **It is not a formal proof.** A disagreement
between `proofread` and `lean` is worth reading for exactly this reason.

## Validator

```bash
python3 plugins/propositions/scripts/validate-verification.py \
  --records manuscript/propositions/verification.jsonl \
  --ledger  manuscript/propositions/main.jsonl
```

| Check | Severity | Condition |
|---|---|---|
| V1 | error | Malformed JSON, not an object, or a required key missing |
| V2 | error | `prop_id` is not an `id` in the ledger |
| V3 | error | `method` or `status` outside the vocabulary |
| V4 | error | `checked_at` is not a valid `YYYY-MM-DD` date |
| V5 | error | A verdict other than `not_attempted` with no non-empty `evidence_ref` |
| V6 | warning | Same `prop_id`, `method` and `evidence_ref` recorded twice |

Exit code: `0` no errors, `1` at least one error, `2` usage or I/O error. An
empty `verification.jsonl` is valid.

### Cross-method disagreement

For each proposition, each method's **latest** record counts: the greatest
`checked_at`, and on the same day the later line in the file. When one method's
latest verdict is `supported` and another's is `refuted` or `partial`, the
validator prints

```
[WARN] disagreement 019e2fbe-…: lean=supported, proofread=partial
```

Disagreements are warnings, not errors. They show which verdicts need a human
to read them. `unresolved` and `not_attempted` never count as disagreement.

## Connecting a method

Any method connects the same way: write records in this format and run the
validator. The first converter ships with this plugin.

### proofread

```bash
python3 plugins/propositions/scripts/proofread-to-verification.py \
  --checklist .proofread/main.md \
  --ledger manuscript/propositions/main.jsonl \
  --checker "your name" >> manuscript/propositions/verification.jsonl
```

Checklist marks map to `[x]` → `supported`, `[~]` → `partial`, `[-]` →
`not_attempted`; unwalked `[ ]` lines are skipped. `evidence_ref` is the
checklist path and line. `--checked-at` defaults to today in Taipei time
(UTC+8).

Each line is resolved to one ledger proposition by narrowing: the backticked id
prefix, then the quoted text snippet, then the `P{seq}` view ordinal. The prefix
alone is not enough, because UUIDv7 ids minted in one extraction batch share
their leading timestamp characters. The snippet is always compared, so a verdict
made on text that has since been rewritten is not recorded as current.

- A line that still matches **more than one** proposition aborts the run; nothing
  is written.
- A line that matches **none** (the text was rewritten, or the ledger was
  re-extracted and the proposition got a new id) aborts by default. With
  `--allow-unmatched` it is skipped and listed on stderr, and the rest are
  written. A verdict is never moved to a new id by text alone: a re-extracted
  proposition may have different asserts and cites, so re-walk it instead.

### Other methods

Lean, exact certificates, CAS and cross-model re-derivation have no converter
yet; each will get its own. Until then, append records by hand or from your own
script. `evidence_ref` is only checked for presence, and each method's
converter can check that its own evidence exists (for example, that a Lean
constant is defined).
