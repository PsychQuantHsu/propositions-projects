## Purpose

Record verdicts that external verification methods (proofread, Lean, exact certificates, CAS, cross-model re-derivation, human review) reach about individual ledger propositions, in a sidecar kept separate from the ledger, so several methods can be recorded side by side and checked mechanically.

## ADDED Requirements

### Requirement: Verification record format

A verification record SHALL be one JSON object per line in a sidecar file `verification.jsonl` placed next to the ledger's `main.jsonl`. Each record SHALL describe one verification method's verdict on one proposition. A record SHALL contain `prop_id` (a string), `method` (a string), `status` (a string), and `checked_at` (a `YYYY-MM-DD` date string). A record MAY contain `evidence_ref` (string), `evidence_snapshot` (string), `tool` (object with `name` and optional `version`), `checker` (string), and `notes` (string). The ledger schema (`main.jsonl` and `SCHEMA.md`) SHALL NOT change.

#### Scenario: Several methods on one proposition

- **WHEN** a proposition has been checked by proofread and by Lean
- **THEN** `verification.jsonl` holds two records with the same `prop_id` and different `method` values, and both are valid

#### Scenario: Ledger untouched

- **WHEN** a `verification.jsonl` file is added next to a ledger
- **THEN** `validate-propositions.py` results for that ledger are unchanged

### Requirement: Method and status vocabulary

`method` SHALL be one of `proofread`, `lean`, `exact_certificate`, `cas`, `cross_model`, `human`, or a custom value starting with `x-`. `status` SHALL be one of `supported`, `refuted`, `partial`, `unresolved`, `not_attempted`.

#### Scenario: Custom method accepted

- **WHEN** a record has `method` equal to `x-monte-carlo`
- **THEN** the validator accepts the method value

#### Scenario: Unknown method rejected

- **WHEN** a record has `method` equal to `leanprover`
- **THEN** the validator reports an error naming the record's line and the allowed values

### Requirement: Validator checks

`validate-verification.py` SHALL take the sidecar path and the ledger path and SHALL report, per record line: malformed JSON or missing required keys (V1); a `prop_id` not present in the ledger (V2); a `method` or `status` outside the vocabulary (V3); a `checked_at` that is not a valid `YYYY-MM-DD` date (V4); a record whose `status` is not `not_attempted` but has no non-empty `evidence_ref` (V5). It SHALL warn on duplicate records with the same `prop_id`, `method`, and `evidence_ref` (V6). It SHALL exit 0 when there are no errors, 1 when there is at least one error, and 2 on usage or I/O errors.

#### Scenario: Dangling proposition id

- **WHEN** a record's `prop_id` does not match any `id` in `main.jsonl`
- **THEN** the validator reports V2 for that line and exits 1

#### Scenario: Evidence required for a verdict

- **WHEN** a record has `status` `supported` and no `evidence_ref`
- **THEN** the validator reports V5 and exits 1

#### Scenario: Not attempted needs no evidence

- **WHEN** a record has `status` `not_attempted` and no `evidence_ref`
- **THEN** the validator reports no V5 finding

### Requirement: Cross-method disagreement report

The validator SHALL list every proposition for which one method's latest record is `supported` while another method's latest record is `refuted` or `partial`. For each such proposition it SHALL name the methods and statuses involved. Disagreements SHALL be reported as warnings, not errors.

#### Scenario: Lean supports, proofread finds a problem

- **WHEN** a proposition's latest `lean` record is `supported` and its latest `proofread` record is `partial`
- **THEN** the report lists that proposition with `lean=supported` and `proofread=partial`, and the exit code is not raised by this finding

#### Scenario: Latest record wins within a method

- **WHEN** a method has two records for one proposition, an older `refuted` and a newer `supported` (by `checked_at`)
- **THEN** only the newer record is used for the disagreement report

### Requirement: Proofread checklist conversion

`proofread-to-verification.py` SHALL read a `.proofread/<file>.md` checklist and the ledger, and SHALL emit one `method=proofread` record per checklist line of the form `- [<mark>] **P<seq>** \`<uuid-prefix>\` ... — "<text snippet>" ...`. The mapping SHALL be `[x]` or `[X]` to `supported`, `[~]` to `partial`, `[-]` to `not_attempted`; `[ ]` lines SHALL be skipped; any other mark SHALL cause a non-zero exit naming the line. Each walked line SHALL carry a quoted text snippet after a dash (em dash, en dash or hyphen; straight or curly quotes); a walked line without one SHALL cause a non-zero exit naming the line. A line SHALL resolve only when exactly one ledger prop has an `id` starting with `<uuid-prefix>` and a whitespace-collapsed `text` starting with the snippet. The view ordinal `P<seq>` SHALL NOT be used to resolve a line. A line with more than one candidate SHALL cause a non-zero exit naming the line with no records written. A line with no candidate SHALL do the same by default; with `--allow-unmatched` it SHALL be skipped and listed on stderr instead. `evidence_ref` SHALL be the checklist path with the line number.

#### Scenario: Clean walk becomes supported

- **WHEN** a checklist line is `- [x] **P012** \`019e2fbe\` [claim] ... — "Suppose ..."` and it resolves to one ledger id
- **THEN** the output contains a record with that full `prop_id`, `method` `proofread`, `status` `supported`, and `evidence_ref` pointing at that checklist line

#### Scenario: Shared UUIDv7 prefix resolved by snippet

- **WHEN** two ledger ids share the checklist's 8-character prefix but only one prop's text starts with the line's snippet
- **THEN** the line resolves to that prop

#### Scenario: Ambiguous line aborts

- **WHEN** two ledger props share the line's id prefix and both texts start with its snippet
- **THEN** the script exits non-zero, names the line, and writes no output, with or without `--allow-unmatched`

#### Scenario: Position never decides

- **WHEN** a line's snippet cannot be read, or two candidates remain and the line's `P<seq>` matches one of them
- **THEN** the script exits non-zero and writes no output; it does not pick a candidate by ordinal

#### Scenario: Rewritten text is skipped only on request

- **WHEN** a line's snippet matches no ledger prop because the text was rewritten after the checklist was generated
- **THEN** the script exits non-zero by default, and with `--allow-unmatched` skips that line, lists it on stderr, and writes the remaining records
