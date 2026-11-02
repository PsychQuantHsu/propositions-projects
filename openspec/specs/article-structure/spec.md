# article-structure Specification

## Purpose

Article structure records how a manuscript is built as a whole: the commitments it makes to the reader and where it keeps them, the role of each section, and how each proposition connects to the one before it. It lives in sidecar files beside the propositions ledger so that a tool can check the structure mechanically and report, at any position, what the article still owes the reader.

## Requirements

### Requirement: Structure sidecars sit beside the ledger without changing it

Article structure SHALL be stored in two sidecar files in the ledger's directory: `structure.json` for the article level and `discourse.jsonl` for one record per proposition. Adding, changing or removing these files SHALL NOT change `main.jsonl`, and `validate-propositions.py` SHALL NOT read them.

#### Scenario: A ledger without sidecars validates as before

- **WHEN** a ledger directory has no `structure.json` and no `discourse.jsonl`
- **THEN** `validate-propositions.py` produces the same output and exit status as before this change

#### Scenario: Structure validation requires both sidecars

- **WHEN** `validate-structure.py` runs on a ledger whose directory lacks `discourse.jsonl`
- **THEN** it exits with status 2 and names the missing file

---
### Requirement: Discourse records cover the ledger in reading order

`discourse.jsonl` SHALL contain exactly one record per non-retired ledger proposition, in the same order as `main.jsonl`, identified by the full proposition UUID in `prop_id`. Rule S1 SHALL report missing, extra, duplicate and out-of-order records separately.

#### Scenario: A missing record fails S1

- **WHEN** the ledger has propositions A, B, C and `discourse.jsonl` has records for A and C only
- **THEN** S1 fails and the report names B as missing

#### Scenario: Retired propositions need no record

- **WHEN** proposition B carries a `retired` field and `discourse.jsonl` has records for A and C
- **THEN** S1 passes

##### Example: S1 outcomes

| Ledger order (non-retired) | discourse.jsonl order | S1 |
| --- | --- | --- |
| A, B, C | A, B, C | PASS |
| A, B, C | A, C | FAIL: missing B |
| A, B, C | A, B, C, D | FAIL: extra D |
| A, B, C | A, B, B, C | FAIL: duplicate B |
| A, B, C | A, C, B | FAIL: out of order |

---
### Requirement: Relations form a closed vocabulary

Each record whose `head` names a proposition SHALL carry a `relation` that is exactly one of these ten values and no other; a record whose `head` is `pending` is permitted to omit `relation`. The ten values are: `continue`, `restatement`, `specification`, `instance`, `addition`, `contrast`, `reason`, `consequence`, `sequence`, `basis`. The relation SHALL state the role of the record's proposition relative to its head. `basis` SHALL mean that the head supplies a definition, result, axiom or case that the record's proposition uses. The same ten values SHALL apply to every `also` entry and to every paragraph relation. The values `start`, `shift` and `return` SHALL NOT appear as labels, because they are derived from the tree, and no version 2.0 record SHALL carry `refers_to`. Rule S2 SHALL enforce this requirement, and values that resemble a listed value SHALL be rejected rather than mapped to it.

#### Scenario: An unlisted relation fails S2

- **WHEN** a record has `relation` set to `elaboration`
- **THEN** S2 fails and the report lists the ten permitted values

#### Scenario: A derived label is not accepted as a relation

- **WHEN** a record has `relation` set to `shift`
- **THEN** S2 fails for that record

##### Example: S2 relation outcomes

| head | relation | other fields | S2 |
| --- | --- | --- | --- |
| proposition in the same paragraph | consequence | — | PASS |
| proposition in the same paragraph | basis | — | PASS |
| proposition in the same paragraph | Consequence | — | FAIL: not a listed value |
| proposition in the same paragraph | return | — | FAIL: not a listed value |
| proposition in the same paragraph | consequence | `refers_to` present | FAIL: `refers_to` is not a version 2.0 field |
| proposition in the same paragraph | — | — | FAIL: a record with a head needs a relation |

---
### Requirement: Commitments are opened before they are discharged

The optional `opens` field SHALL list the commitments a record opens, each with an `id` matching `^[a-z0-9][a-z0-9-]{0,63}$` and a `kind` that is exactly one of these seven and no other: `question`, `aim`, `hypothesis`, `plan`, `announcement`, `setup`, `future_work`. The optional `discharges` field SHALL list the commitment ids a record discharges. Rule S3 SHALL enforce that commitment ids are unique in the file, that every discharged id was opened by a strictly earlier record, and that no record discharges a `future_work` commitment.

#### Scenario: Discharging before opening fails S3

- **WHEN** the record at position 3 discharges `c-aim-1` and `c-aim-1` is opened at position 8
- **THEN** S3 fails for position 3

#### Scenario: A proposition cannot keep its own promise

- **WHEN** one record both opens and discharges `c-ann-1`
- **THEN** S3 fails for that record

#### Scenario: Future work is never discharged

- **WHEN** a record discharges a commitment whose kind is `future_work`
- **THEN** S3 fails for that record

---
### Requirement: A complete article keeps every commitment

Rule S4 SHALL report as an error every commitment of kind `question`, `aim`, `hypothesis`, `plan` or `announcement` that no record discharges, and as a warning every undischarged `setup`. Commitments of kind `future_work` SHALL NOT be reported. With `--partial`, S4 SHALL report undischarged commitments as information only, so that an unfinished draft can pass.

#### Scenario: An unanswered research question fails a complete article

- **WHEN** `c-q-1` of kind `question` is never discharged and the validator runs without `--partial`
- **THEN** S4 fails, the exit status is 1, and the report names `c-q-1` and the proposition that opened it

#### Scenario: A draft in progress passes with partial

- **WHEN** the same ledger is validated with `--partial`
- **THEN** S4 lists `c-q-1` as open, does not fail, and the exit status is 0 if no other rule fails

##### Example: S4 severity by kind

| kind | undischarged, complete | undischarged, `--partial` |
| --- | --- | --- |
| question | error | info |
| aim | error | info |
| hypothesis | error | info |
| plan | error | info |
| announcement | error | info |
| setup | warning | info |
| future_work | not reported | not reported |

---
### Requirement: The section plan follows ledger order

`structure.json` SHALL contain `structure_version` set to `"2.0"`, a non-empty `thesis` list of proposition UUIDs, a `paragraphs` list, and a `sections` list in reading order whose entries each have a unique `id`, a `heading`, a `role` that is exactly one of these ten and no other: `abstract`, `introduction`, `background`, `formal_setup`, `method`, `results`, `proofs`, `discussion`, `conclusion`, `appendix`, and a `first_prop` UUID. A section entry is permitted to carry `parent` naming a section that appears earlier in the list; a section without `parent` is top-level. Rule S5 SHALL enforce that every `first_prop` and `thesis` entry names a non-retired ledger proposition, that `first_prop` values strictly increase in ledger order, that the first section starts at the first non-retired proposition, and that every `parent` names an earlier section. A section with role `abstract` SHALL be the first entry, and no record inside it SHALL open a commitment. A section SHALL extend from its `first_prop` up to, not including, the next section's `first_prop`. With `--partial`, an empty `thesis` SHALL be reported as information instead of an error, because a draft in progress often has not stated its thesis yet. An error in `thesis` SHALL NOT stop S6 or the state query from using a section list that is itself valid.

#### Scenario: Sections out of order fail S5

- **WHEN** the second section's `first_prop` comes before the first section's `first_prop` in ledger order
- **THEN** S5 fails and names both sections

#### Scenario: A draft without its thesis passes with partial

- **WHEN** `thesis` is an empty list and the validator runs with `--partial`
- **THEN** S5 reports the missing thesis as information and does not fail

#### Scenario: An unlisted role fails S5

- **WHEN** a section has `role` set to `literature`
- **THEN** S5 fails and the report lists the ten permitted roles

#### Scenario: The abstract opens no commitments

- **WHEN** the first section has role `abstract` and a record inside it opens `c-aim-1`
- **THEN** S5 fails for that record

#### Scenario: The abstract must come first

- **WHEN** a section with role `abstract` is not the first entry
- **THEN** S5 fails and names that section

#### Scenario: A parent must come earlier

- **WHEN** section `sec-3` has `parent` set to `sec-3-1`, which appears after it
- **THEN** S5 fails and names `sec-3`

---
### Requirement: Announcements are kept nearby

Rule S6 SHALL warn when an `announcement` commitment is first discharged neither in the section where it was opened nor in the section immediately after it. S6 SHALL NOT produce errors.

#### Scenario: An announcement kept in the next section passes

- **WHEN** an announcement opened by the last proposition of one section is discharged by the first proposition of the next section
- **THEN** S6 passes

#### Scenario: An announcement kept two sections later is flagged

- **WHEN** an announcement opened in section 2 is first discharged in section 4
- **THEN** S6 reports a warning and the exit status is unaffected

---
### Requirement: Structure validation reports per rule with fixed exit codes

`validate-structure.py` SHALL accept `--jsonl` for the ledger, optional `--structure` and `--discourse` paths defaulting to the ledger's directory, `--partial`, and `--format text|json`. It SHALL print one summary line per rule (S1 to S8) marked PASS, FAIL or WARN, followed by each problem with the proposition's position and id. It SHALL exit 0 when no rule fails, 1 when any rule fails, and 2 when an input file is missing, unreadable or not valid JSON, or when `structure_version` is not `"2.0"`; in the last case the message SHALL name `migrate-structure-v2.py`.

#### Scenario: Warnings alone do not fail validation

- **WHEN** the only finding is an undischarged `setup` in a complete article
- **THEN** S4 is marked WARN and the exit status is 0

#### Scenario: Invalid JSON is an input error

- **WHEN** line 4 of `discourse.jsonl` is not valid JSON
- **THEN** the exit status is 2 and the message names line 4

#### Scenario: Version 1.0 sidecars are refused

- **WHEN** `structure.json` has `structure_version` set to `"1.0"`
- **THEN** the exit status is 2 and the message names `migrate-structure-v2.py`

---
### Requirement: The state query reports what the article owes at a position

`structure-state.py` SHALL accept `--jsonl` for the ledger, `--at` with a proposition UUID or `end`, optional sidecar paths, `--order kind|scope` defaulting to `scope`, and `--format text|json`. It SHALL first apply S1 to S3 and the tree checks of S2 and S5, accepting `pending` heads as `--partial` does, and exit 1 if any fails. For position t, counting t itself, it SHALL report t's position and the total count; the section containing t with its id, heading and role; the paragraph containing t with its id and the position and id of its root, or null when the root has not appeared; t's relation, reported as `root` when t is a paragraph root; the right frontier at t; the pending records at t; every commitment opened at or before t and not discharged at or before t; the `future_work` commitments opened so far; whether any `thesis` proposition has appeared; and the ordering used. The right frontier SHALL list, in order, t and each ancestor of t reached by following heads whose position is at most t, up to the paragraph root; then the paragraph containing t and each ancestor paragraph reached by following paragraph heads, up to the section's root paragraph; then the section containing t and each ancestor section reached by following `parent`. Each frontier node SHALL give its level (`sentence`, `paragraph` or `section`) and its id, and sentence nodes also their position. The pending records SHALL be the records at or before t whose head is `pending` or lies after t. Each open commitment SHALL give its id, kind, the opening proposition's position and id, the number of propositions since it was opened, and its scope: the paragraph id and section id of the opening proposition. With `kind`, open commitments SHALL be ordered by kind as `announcement`, `hypothesis`, `plan`, `question`, `aim`, `setup`, and within a kind by the position that opened them, earliest first. With `scope`, they SHALL be ordered by kind in the same order, then by the depth of the deepest section that contains both the opening proposition and t, deepest first, then by opening position, earliest first. A section contains a proposition when the proposition lies in that section or in any section whose `parent` chain reaches it; a top-level section has depth 1, each child one more than its parent, and the depth is 0 when no section contains both. It SHALL exit 2 when the `--at` id is not a non-retired ledger proposition.

#### Scenario: An open announcement comes first

- **WHEN** at position t a `question` opened at position 2 and an `announcement` opened at position t are both open
- **THEN** the announcement is listed first under either ordering

#### Scenario: Unknown position is an input error

- **WHEN** `--at` names a UUID that is not in the ledger
- **THEN** the exit status is 2 and the message names the UUID

#### Scenario: A pending record is reported

- **WHEN** the record at position 9, in the last paragraph, has `head` set to `pending` and `--at` names position 9
- **THEN** the query does not fail on the pending head, and the pending records list position 9

##### Example: Open commitments at a position

- **GIVEN** a ledger of 10 propositions where position 1 opens `c-q-1` (question), position 2 opens `c-plan-1` and `c-plan-2` (plan), position 4 discharges `c-plan-1`, position 6 opens `c-ann-1` (announcement) and `c-fw-1` (future_work)
- **WHEN** `structure-state.py --at` names position 6
- **THEN** the open commitments are, in order, `c-ann-1` (opened at 6, 0 since), `c-plan-2` (opened at 2, 4 since), `c-q-1` (opened at 1, 5 since), and `c-fw-1` appears only in the future-work list

##### Example: Right frontier inside a paragraph

- **GIVEN** a paragraph holding positions 1 to 4, where 1 is the root, 2 has head 1, 3 has head 2 and 4 has head 2
- **WHEN** `structure-state.py --at` names position 4
- **THEN** the sentence nodes of the frontier are positions 4, 2 and 1, in that order

##### Example: Scope ordering prefers the inner section

- **GIVEN** top-level sections `sec-1` and `sec-3`, section `sec-3-3` with `parent` `sec-3`, plan `c-plan-a` opened in `sec-1`, plan `c-plan-b` opened in `sec-3`, and t in `sec-3-3` with both plans open
- **WHEN** the query runs with `--order kind` and then with `--order scope`
- **THEN** `kind` lists `c-plan-a` before `c-plan-b`, and `scope` lists `c-plan-b` before `c-plan-a`

---
### Requirement: Propositions form a dependency tree within each paragraph

Every record SHALL either be the root of its paragraph, carrying neither `head` nor `relation`, or carry a `head` naming another non-retired proposition in the same paragraph, earlier or later in reading order. Each paragraph SHALL have exactly one root, and following heads from any record SHALL reach the root without revisiting a record. An `also` entry SHALL name in `to` a non-retired proposition other than the record itself and other than its head, and SHALL carry a relation from the ten values. With `--partial`, a record in the last paragraph is permitted to carry `head` set to `pending`, and in that paragraph every head chain SHALL end either at the single root or at a pending record; without `--partial`, `pending` SHALL fail. Rule S2 SHALL enforce this requirement.

#### Scenario: A head outside the paragraph fails S2

- **WHEN** the record at position 5 names as its head the proposition at position 3, and position 3 is in the previous paragraph
- **THEN** S2 fails for position 5

#### Scenario: A forward head passes

- **WHEN** the record at position 7 names as its head the proposition at position 8 in the same paragraph, and position 8 reaches the root
- **THEN** S2 passes for position 7

#### Scenario: Pending is only for drafts

- **WHEN** a record in the last paragraph has `head` set to `pending` and the validator runs without `--partial`
- **THEN** S2 fails for that record

##### Example: S2 tree outcomes for one paragraph of positions 1 to 4

| Heads | S2 |
| --- | --- |
| 1 root; 2→1; 3→2; 4→2 | PASS |
| 1 root; 2→3; 3→1; 4→3 | PASS (2 has a forward head) |
| 1 root; 2 root; 3→2; 4→1 | FAIL: two roots |
| 1 root; 2→3; 3→2; 4→1 | FAIL: 2 and 3 form a cycle |
| 1 root; 2→2; 3→1; 4→1 | FAIL: 2 names itself |

---
### Requirement: Paragraphs form a dependency tree within each section

`structure.json` SHALL contain `paragraphs`, a non-empty list in reading order whose entries each have a unique `id` and a `first_prop` naming a non-retired ledger proposition. Rule S5 SHALL enforce that `first_prop` values strictly increase in ledger order, that the first paragraph starts at the first non-retired proposition, and that every section's `first_prop` is the `first_prop` of some paragraph, so that no paragraph crosses a section boundary. A paragraph SHALL extend from its `first_prop` up to, not including, the next paragraph's `first_prop`. Each paragraph SHALL either be the root paragraph of its section, carrying neither `head` nor `relation`, or carry a `head` naming another paragraph in the same section and a `relation` from the ten values. Each section SHALL have exactly one root paragraph, and following paragraph heads SHALL reach it without revisiting a paragraph.

#### Scenario: A paragraph that crosses a section boundary fails S5

- **WHEN** a section's `first_prop` falls inside a paragraph rather than at its `first_prop`
- **THEN** S5 fails and names the section and the paragraph

#### Scenario: A paragraph head in another section fails S5

- **WHEN** paragraph `p-7` names as its head paragraph `p-5`, and `p-5` belongs to the previous section
- **THEN** S5 fails for `p-7`

---
### Requirement: Crossing arcs are reported as warnings

Rule S7 SHALL treat each record with a proposition head as an arc between the record's position and its head's position, and each paragraph with a paragraph head as an arc between the two paragraphs' indices in the paragraph list. Two arcs of the same paragraph, or two paragraph arcs of the same section, SHALL be reported as crossing when, with each arc's endpoints sorted so that a1 < b1 and a2 < b2, either a1 < a2 < b1 < b2 or a2 < a1 < b2 < b1. S7 SHALL report a warning for each crossing pair, naming both arcs, and SHALL NOT produce errors.

#### Scenario: Two crossing arcs are flagged

- **WHEN** in one paragraph the record at position 2 has head 4 and the record at position 3 has head 1
- **THEN** S7 reports a warning naming arcs (2, 4) and (1, 3), and the exit status is unaffected

#### Scenario: Nested arcs are not crossing

- **WHEN** in one paragraph the record at position 2 has head 3 and the record at position 4 has head 1
- **THEN** S7 reports no crossing

---
### Requirement: Basis edges agree with the ledger's cites

For every edge with relation `basis`, whether a record's relation to its head or an `also` entry, rule S8 SHALL check that the target appears in the `cites` list of the record's proposition in `main.jsonl`, and SHALL report a warning naming both propositions when it does not. S8 SHALL NOT produce errors.

#### Scenario: A basis edge without a cite is flagged

- **WHEN** a record's relation is `basis` to its head and the record's proposition does not cite the head in `main.jsonl`
- **THEN** S8 reports a warning naming both propositions, and the exit status is unaffected

---
### Requirement: Paragraph plans are derived from the TeX source

`derive-paragraphs.py` SHALL accept `--jsonl` and `--tex`, and optionally `--structure` to read the section list. It SHALL treat each maximal run of non-blank lines of the TeX file as one paragraph, assign each non-retired proposition to the paragraph containing the starting line of its `location`, skip paragraphs that hold no proposition, split a paragraph wherever a section's `first_prop` falls inside it, number the result `p-1`, `p-2` and so on in reading order, and print the `paragraphs` list as JSON on standard output. It SHALL exit 0 on success, and 2 when an input is missing or unreadable, when a `location` cannot be parsed or lies outside every paragraph, or when a `location` names a file other than the main file (a prefix other than `main.tex`).

#### Scenario: Blank lines separate paragraphs

- **WHEN** propositions 1 and 2 start on lines 10 and 11 and proposition 3 starts on line 13, with line 12 blank
- **THEN** the output has two paragraphs, `p-1` starting at proposition 1 and `p-2` starting at proposition 3

#### Scenario: A section start splits a paragraph

- **WHEN** `--structure` names a section whose `first_prop` is the second proposition of a TeX paragraph
- **THEN** that paragraph is split so that a new paragraph starts at the section's `first_prop`

#### Scenario: Multi-file locations are refused

- **WHEN** a proposition's `location` is `sections/intro.tex:L5`
- **THEN** the exit status is 2 and the message names that location

---
### Requirement: Version 1.0 sidecars are migrated, not read

`migrate-structure-v2.py` SHALL accept `--jsonl`, `--tex` and `--out-dir`, read version 1.0 sidecars from the ledger's directory, and write version 2.0 `structure.json` and `discourse.jsonl` into `--out-dir` together with a review report. It SHALL NOT modify `main.jsonl` or the version 1.0 sidecars. It SHALL derive paragraphs as `derive-paragraphs.py` does; make the first record of each paragraph its root; give every other record the previous record as its head, keeping the 1.0 relation when it is one of the ten values and using `continue` otherwise; make the first paragraph of each section its root paragraph and give every other paragraph the previous paragraph as its head, with the 1.0 relation of its first record when that is one of the ten values and `continue` otherwise; set each section's `parent` from the sectioning command level found in the TeX source; and list in the review report every record whose 1.0 relation was `start`, `shift` or `return`, every paragraph whose relation was replaced by `continue`, and every section whose parent could not be determined. Its output SHALL pass S1 to S6 of `validate-structure.py`. It SHALL exit 2 when the input sidecars are not version 1.0.

#### Scenario: A return is listed for review

- **WHEN** the version 1.0 record at position 12 has `relation` `return`
- **THEN** the review report lists position 12 with its original relation

#### Scenario: The ledger is untouched

- **WHEN** the migration finishes
- **THEN** `main.jsonl` and the version 1.0 sidecars are byte-identical to before

#### Scenario: Version 2.0 input is refused

- **WHEN** the ledger's `structure.json` already has `structure_version` `"2.0"`
- **THEN** the exit status is 2 and no file is written

---
### Requirement: Structure metrics report whether the tree fits

`structure-metrics.py` SHALL accept the same inputs as the state query, exit 1 when S1 to S3 or the tree checks of S2 and S5 fail (accepting `pending` heads as `--partial` does), exit 2 on an input error, and otherwise exit 0 and report: the number of sentence arcs and paragraph arcs, the number and proportion of arcs that take part in at least one crossing, at each level; the length of the sentence part of the right frontier at every position, as median, mean and maximum; the number of records whose head comes before them and after them; the count of each relation; the number of S8 warnings; and, for each of the orderings `kind` and `scope`, the number of evaluated positions and the number of hits. A position t SHALL be evaluated when at least one commitment open at t is discharged after t; it SHALL count as a hit when the first commitment in the ordering is among the commitments first discharged at the earliest position after t at which any commitment open at t is discharged.

#### Scenario: A hit under one ordering and a miss under the other

- **WHEN** at position t plan `c-plan-a` opened in `sec-1` and plan `c-plan-b` opened in `sec-3` are open, t lies in `sec-3-3` whose parent is `sec-3`, and `c-plan-b` is discharged before `c-plan-a`
- **THEN** position t is a miss for `kind` and a hit for `scope`

##### Example: Crossing proportion

- **GIVEN** a paragraph with four arcs, two of which cross each other
- **WHEN** `structure-metrics.py` runs
- **THEN** the sentence-level crossing proportion is 0.5
