# tschema.jsonl format

One JSON object per line, next to the checked document (for example `minutes.md` + `tschema.jsonl`). Every record has a `kind`.

## `claim` — one statement of the checked document

| Field | Required | Meaning |
|---|---|---|
| `id` | ✅ | UUID v7 |
| `text` | ✅ | The statement, copied verbatim from the checked document (labels before a colon count as statements) |
| `location` | ✅ | `L<a>` or `L<a>-L<b>` in the **checked document** |
| `source_support` | ✅ | What the source gives this statement — see below |
| `semantic_distance` | ✅ | How close the wording stays to the source — see below |
| `drift_type` | — | How it drifted, if it did |
| `evidence` | ✅ if `attested` | The source passage, verbatim |
| `source_locator` | ✅ if `attested` | Where in which source: `type`, `ref`, optional local `path` |
| `note` | — | Free text |

`source_support`:

| Value | Meaning |
|---|---|
| `attested` | The source passage can be pointed at, and it was read correctly |
| `doc` | Backed by a document that is not the primary source |
| `inferred` | An inference, including anything copied from an unsourced relay document |
| `unsupported` | The source gives no basis |

`semantic_distance`: `verbatim` (almost word for word), `near` (a paraphrase with the same meaning), `far` (generalized, promoted, or evaluative). **`attested` with `far` is legal and important** — it is exactly the drift the skill exists to catch.

`drift_type`: `modality`, `abstraction`, `evaluation`, `agency`, `nominalization` (sentence level); `dangling-reference`, `missing-step`, `tautology`, `irrelevance`, `overgeneralization` (logic level).

`source_locator`:

| Key | Meaning |
|---|---|
| `type` | `transcript`, `email`, `statute`, `document`, `dataset`, `other` |
| `ref` | Where in the source: a timecode `[05:32]`, an email's date and sender, an article number |
| `path` | Optional. The source file on this machine, relative to `tschema.jsonl`. Needed for T4 |

A source file is third-party raw material (transcripts, recordings, emails). Keep it local and out of any git remote; `path` is only a local reference.

### Why `source_support` is not `evidence_class`

The propositions ledger's `evidence_class` records how the **manuscript** states a claim. `source_support` records what an **external source** gives it. They answer different questions, so they are separate fields. The four levels are also kept apart from the verdict vocabulary of verification records (`supported` / `refuted` / …): `attested` and `doc` would both become `supported`, and `unsupported` ("the source is silent") is not `refuted` ("shown false"). How to export tschema results as verification records is still open.

## `relation` — how two statements relate

| Field | Required | Meaning |
|---|---|---|
| `id` | ✅ | UUID v7 |
| `pair` | ✅ | Two distinct claim ids from this file |
| `source_relation` | ✅ | The relation in the source |
| `rendered_relation` | ✅ | The relation as the document presents it |
| `verdict`, `note` | — | Free text |

Relation values: `causal`, `conditional`, `concessive`, `sequential`, `elaboration`, `coordinate`, `none`.

## `logic` — a gap a reader cannot cross from the document alone

| Field | Required | Meaning |
|---|---|---|
| `id` | ✅ | UUID v7 |
| `target` | ✅ | A claim id from this file |
| `drift_type` | ✅ | One of the logic-level drift types |
| `note` | — | Free text |

## Validator

```bash
python3 plugins/tschema-check/scripts/validate-tschema.py --records tschema.jsonl --document minutes.md
```

| Check | Severity | Condition | Mechanism |
|---|---|---|---|
| T1 | error | Malformed JSON, missing key, value outside a vocabulary, id not a UUID v7 | — |
| T2 | error | Claim `text` is not in the checked document | R1 (substring) |
| T3 | warning | Claim `text` is not within the lines its `location` names | R13 (line anchoring) |
| T4 | error | `evidence` is not in the file at `source_locator.path`, or that file cannot be read | R1 generalized to an external source |
| T5 | error | An `attested` claim has no `evidence` or no `source_locator` | — |
| T6 | error | A relation `pair` or logic `target` does not name claims in this file | — |
| T7 | warning | A document line (outside `%` comments) contains 未能查得, 未能確認, 因錄音不清 or 無從查證 | — |

**Matching.** Both sides are NFKC-normalized and every whitespace character is removed, so a sentence wrapped across lines still matches and full-width punctuation equals half-width. For `.srt` sources, cue numbers and `-->` timing lines are removed first, so a quote spanning two cues matches.

**Coverage summary.** Claims whose `source_locator` has no `path` cannot be checked by T4. The validator never counts them as passed: it prints, per source type, how many claims were checked against their source and how many were not. It never prints one merged pass rate.

Exit code: `0` no errors, `1` at least one error, `2` usage or I/O error.

## Open questions

- Exporting to verification records: how the four `source_support` levels map to `supported` / `refuted` / `partial` / `unresolved`.
- A mechanical relation rule (for example, a `conditional` source relation rendered as `none`).
