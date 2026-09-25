## Purpose

Check, mechanically, the parts of a source-fidelity review that a script can check: that every recorded statement really is in the checked document, and that every quoted piece of source evidence really is in the external source it names. The judgement of how well a statement is supported stays with the reviewer.

## ADDED Requirements

### Requirement: Check record format

A tschema check SHALL be stored as JSON Lines in `tschema.jsonl`, one record per line, with a `kind` field of `claim`, `relation`, or `logic`. Record `id`s SHALL be unique within the file. A `claim` record SHALL contain `id` (UUID v7 string), `text` (verbatim from the checked document), `location` (`L<a>` or `L<a>-L<b>` with 1 ≤ a ≤ b, in the checked document), `source_support`, and `semantic_distance`; it MAY contain `drift_type`, `evidence`, `source_locator`, and `note`. A `relation` record SHALL contain `id`, `pair` (two claim ids), `source_relation`, and `rendered_relation`. A `logic` record SHALL contain `id`, `target` (a claim id), and `drift_type`.

#### Scenario: Claim record accepted

- **WHEN** a claim record has a UUID v7 `id`, verbatim `text`, `location` `L12-L13`, `source_support` `attested`, `semantic_distance` `near`, `evidence`, and `source_locator`
- **THEN** the validator reports no T1 finding for it

#### Scenario: Unknown kind rejected

- **WHEN** a record has `kind` equal to `sentence`
- **THEN** the validator reports T1 naming the line

### Requirement: Source support and locator vocabulary

`source_support` SHALL be one of `attested`, `doc`, `inferred`, `unsupported`. `semantic_distance` SHALL be one of `verbatim`, `near`, `far`. `drift_type`, when present, SHALL be one of `modality`, `abstraction`, `evaluation`, `agency`, `nominalization`, `dangling-reference`, `missing-step`, `tautology`, `irrelevance`, `overgeneralization`. `source_locator` SHALL be an object with `type` in `transcript`, `email`, `statute`, `document`, `dataset`, `other`, a non-empty string `ref`, and an optional `path` to a local source file. Relation values SHALL be one of `causal`, `conditional`, `concessive`, `sequential`, `elaboration`, `coordinate`, `none`.

#### Scenario: Evidence class is not reused

- **WHEN** a claim record uses `source_support` `verified`
- **THEN** the validator reports T1 listing the four allowed values

### Requirement: Statement containment in the checked document

For every claim record, the validator SHALL report T2 (error) when its `text` is not a substring of the checked document, and T3 (warning) when its `text` is not within the document lines named by `location`. Both comparisons SHALL apply Unicode NFKC normalization and remove all whitespace on both sides, so that line wraps inside CJK sentences do not break a match.

#### Scenario: Statement wrapped across lines still matches

- **WHEN** the checked document breaks a sentence across two lines and the claim `text` has it on one line
- **THEN** the validator reports no T2 or T3 finding for that claim

#### Scenario: Statement not in the document

- **WHEN** a claim's `text` does not occur in the checked document
- **THEN** the validator reports T2 and exits 1

### Requirement: Evidence containment in the external source

For every claim record whose `source_locator` has a `path`, the validator SHALL report T4 (error) when `evidence` is not a substring of that source file under the same normalization. When the source file ends in `.srt`, timing lines and the digits-only cue number directly above each timing line SHALL be removed before matching, so evidence spanning two cues matches while a spoken number on its own subtitle line is kept. Paths SHALL resolve relative to the `tschema.jsonl` file; an absolute `path`, a `path` containing `..`, or one that resolves outside that directory SHALL be rejected (T1 for the first two, T4 for the last). A missing, non-regular, or over-50-MB source file SHALL be reported as T4. A claim naming a source `path` with no `evidence` SHALL be reported as T4, and `evidence` shorter than 4 characters after normalization SHALL be reported as T4. When `source_locator` has no `path`, T4 SHALL NOT apply and the claim SHALL be counted as not machine-checked in the summary.

#### Scenario: Quote spans two subtitle cues

- **WHEN** a claim's `evidence` runs from the end of one `.srt` cue into the next and `source_locator.path` points at that file
- **THEN** the validator reports no T4 finding

#### Scenario: Fabricated quote

- **WHEN** a claim's `evidence` does not occur in the source file
- **THEN** the validator reports T4 and exits 1

#### Scenario: Unverifiable source is reported, not passed silently

- **WHEN** an `attested` claim has a `source_locator` without `path`
- **THEN** the summary counts it under "not machine-checked" for its source type

### Requirement: Attested claims carry their evidence

A claim with `source_support` `attested` SHALL have a non-empty `evidence` and a `source_locator`; otherwise the validator SHALL report T5 (error).

#### Scenario: Attested without evidence

- **WHEN** a claim is `attested` with no `evidence`
- **THEN** the validator reports T5 and exits 1

### Requirement: Relation and logic records point at claims

The validator SHALL report T6 (error) when a `relation` record's `pair` is not two distinct claim ids present in the file, or a `logic` record's `target` is not a claim id present in the file.

#### Scenario: Dangling relation

- **WHEN** a relation record's `pair` names an id with no claim record
- **THEN** the validator reports T6

### Requirement: Verification-failure phrases stay out of the text

The validator SHALL report T7 (warning) for each line of the checked document that contains one of 未能查得, 未能確認, 因錄音不清, 無從查證. `%` line comments SHALL be removed first only when the document is a `.tex` file.

#### Scenario: Failure state written into the document

- **WHEN** the checked document contains 「該項名稱因錄音不清未能確認」
- **THEN** the validator reports T7 for that line and the exit code is not raised by it

### Requirement: Per-source-type summary and exit codes

The validator SHALL print, per `source_locator.type`, how many claims were machine-checked by T4 and how many were not (split into no local path and no evidence), SHALL count claims with no `source_locator` under a separate "(no source named)" line, and SHALL NOT print a single merged pass rate. It SHALL exit 0 with no errors, 1 with at least one error, and 2 on usage or I/O errors.

#### Scenario: Mixed source types reported separately

- **WHEN** a file has claims from a transcript with `path` and from email without `path`
- **THEN** the summary shows the transcript and email counts on separate lines
