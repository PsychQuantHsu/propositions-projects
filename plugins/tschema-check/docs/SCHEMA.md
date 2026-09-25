# tschema.jsonl format

One JSON object per line, next to the checked document (for example `minutes.md` + `tschema.jsonl`). Every record has a `kind`.

## `claim` — one statement of the checked document

| Field | Required | Meaning |
|---|---|---|
| `id` | ✅ | UUID v7 |
| `text` | ✅ | The statement, copied verbatim from the checked document (labels before a colon count as statements) |
| `location` | ✅ | `L<a>` or `L<a>-L<b>` (1 ≤ a ≤ b) in the **checked document** |
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
| `path` | Optional. The source file on this machine, relative to `tschema.jsonl` and inside its directory (absolute paths, `..`, and symlinks leading out are rejected). Needed for T4 |

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
| T1 | error | Malformed JSON, missing key, value outside a vocabulary or of the wrong type, id not a UUID v7 or used twice, bad `location` range, `path` absolute or escaping the records directory | — |
| T2 | error | Claim `text` is not in the checked document | R1 (substring) |
| T3 | warning | Claim `text` is not within the lines its `location` names, or `location` is past the end of the document | R13 (line anchoring) |
| T4 | error | `evidence` is not in the file at `source_locator.path`; that file cannot be read (missing, outside the records directory, not a regular file, over 50 MB); a `path` is named but no `evidence` quoted; or `evidence` is shorter than 4 characters after normalization | R1 generalized to an external source |
| T5 | error / warning | Error: an `attested` claim has no `evidence` or no `source_locator`. Warning: an `attested` claim whose source has no local `path`, so its evidence was never compared | — |
| T6 | error | A relation `pair` or logic `target` does not name claims in this file | — |
| T7 | warning | A document line contains 未能查得, 未能確認, 因錄音不清 or 無從查證 (`%` comments are skipped only when the document is `.tex`; in Markdown `%` is a percentage) | — |

**Matching.** Both sides are NFKC-normalized and every whitespace character is removed, so a sentence wrapped across lines still matches and full-width punctuation equals half-width. For `.srt` sources, `-->` timing lines and the cue number directly above each are removed first, so a quote spanning two cues matches; a spoken number on its own subtitle line is kept. NFKC folds full-width forms, which is the intent; it also folds CJK compatibility ideographs, a rare case where two visibly different characters compare equal. Evidence shorter than 4 characters is rejected: a quote that short is found in almost any source by chance.

**Coverage summary.** The validator prints, per source type, how many claims were checked against their source and how many were not, split into "no local path" and "no evidence"; claims with no `source_locator` at all are counted under `(no source named)`. Nothing unchecked is counted as passed, and there is never one merged pass rate. The closing line states coverage — `✓ NO ERRORS — N of M claim(s) checked against their source` — rather than a bare pass, so a run where nothing was checkable does not read like a verified one. `.vtt` sources are not special-cased; convert them to `.srt` or plain text.

Files are read as UTF-8 (a leading BOM is fine). Convert `.docx` / `.pdf` documents to text first.

Exit code: `0` no errors, `1` at least one error, `2` usage or I/O error.

## Open questions

- Exporting to verification records: how the four `source_support` levels map to `supported` / `refuted` / `partial` / `unresolved`.
- A mechanical relation rule (for example, a `conditional` source relation rendered as `none`).
