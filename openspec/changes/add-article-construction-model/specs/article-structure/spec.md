## Purpose

Article structure records how a manuscript is built as a whole: the commitments it makes to the reader and where it keeps them, the role of each section, and how each proposition connects to the one before it. It lives in sidecar files beside the propositions ledger so that a tool can check the structure mechanically and report, at any position, what the article still owes the reader.

## ADDED Requirements

### Requirement: Structure sidecars sit beside the ledger without changing it

Article structure SHALL be stored in two sidecar files in the ledger's directory: `structure.json` for the article level and `discourse.jsonl` for one record per proposition. Adding, changing or removing these files SHALL NOT change `main.jsonl`, and `validate-propositions.py` SHALL NOT read them.

#### Scenario: A ledger without sidecars validates as before

- **WHEN** a ledger directory has no `structure.json` and no `discourse.jsonl`
- **THEN** `validate-propositions.py` produces the same output and exit status as before this change

#### Scenario: Structure validation requires both sidecars

- **WHEN** `validate-structure.py` runs on a ledger whose directory lacks `discourse.jsonl`
- **THEN** it exits with status 2 and names the missing file

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

### Requirement: Relations form a closed vocabulary

Each record's `relation` SHALL be exactly one of these twelve values and no other: `start`, `shift`, `continue`, `restatement`, `specification`, `instance`, `addition`, `contrast`, `reason`, `consequence`, `sequence`, `return`. Rule S2 SHALL enforce that `start` appears exactly once, on the first record; that a record with `return` carries `refers_to` naming a proposition earlier in reading order; and that no other record carries `refers_to`. Values that resemble a listed value SHALL be rejected rather than mapped to it.

#### Scenario: An unlisted relation fails S2

- **WHEN** a record has `relation` set to `elaboration`
- **THEN** S2 fails and the report lists the twelve permitted values

#### Scenario: A return must point backwards

- **WHEN** the record at position 7 has `relation` `return` and `refers_to` naming the proposition at position 9
- **THEN** S2 fails for position 7

##### Example: S2 outcomes

| Position | relation | refers_to | S2 |
| --- | --- | --- | --- |
| 1 | start | — | PASS |
| 1 | continue | — | FAIL: first record must be start |
| 5 | start | — | FAIL: start only at position 1 |
| 9 | return | position 4 | PASS |
| 9 | return | — | FAIL: return needs refers_to |
| 9 | consequence | position 4 | FAIL: refers_to only with return |
| 9 | Consequence | — | FAIL: not a listed value |

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

### Requirement: The section plan follows ledger order

`structure.json` SHALL contain `structure_version`, a non-empty `thesis` list of proposition UUIDs, and a `sections` list in reading order whose entries each have a unique `id`, a `heading`, a `role` that is exactly one of these nine and no other: `introduction`, `background`, `formal_setup`, `method`, `results`, `proofs`, `discussion`, `conclusion`, `appendix`, and a `first_prop` UUID. Rule S5 SHALL enforce that every `first_prop` and `thesis` entry names a non-retired ledger proposition, that `first_prop` values strictly increase in ledger order, and that the first section starts at the first non-retired proposition. A section SHALL extend from its `first_prop` up to, not including, the next section's `first_prop`. With `--partial`, an empty `thesis` SHALL be reported as information instead of an error, because a draft in progress often has not stated its thesis yet. An error in `thesis` or `structure_version` SHALL NOT stop S6 or the state query from using a section list that is itself valid.

#### Scenario: Sections out of order fail S5

- **WHEN** the second section's `first_prop` comes before the first section's `first_prop` in ledger order
- **THEN** S5 fails and names both sections

#### Scenario: A draft without its thesis passes with partial

- **WHEN** `thesis` is an empty list and the validator runs with `--partial`
- **THEN** S5 reports the missing thesis as information and does not fail

#### Scenario: An unlisted role fails S5

- **WHEN** a section has `role` set to `literature`
- **THEN** S5 fails and the report lists the nine permitted roles

### Requirement: Announcements are kept nearby

Rule S6 SHALL warn when an `announcement` commitment is first discharged neither in the section where it was opened nor in the section immediately after it. S6 SHALL NOT produce errors.

#### Scenario: An announcement kept in the next section passes

- **WHEN** an announcement opened by the last proposition of one section is discharged by the first proposition of the next section
- **THEN** S6 passes

#### Scenario: An announcement kept two sections later is flagged

- **WHEN** an announcement opened in section 2 is first discharged in section 4
- **THEN** S6 reports a warning and the exit status is unaffected

### Requirement: Structure validation reports per rule with fixed exit codes

`validate-structure.py` SHALL accept `--jsonl` for the ledger, optional `--structure` and `--discourse` paths defaulting to the ledger's directory, `--partial`, and `--format text|json`. It SHALL print one summary line per rule (S1 to S6) marked PASS, FAIL or WARN, followed by each problem with the proposition's position and id. It SHALL exit 0 when no rule fails, 1 when any rule fails, and 2 when an input file is missing, unreadable or not valid JSON.

#### Scenario: Warnings alone do not fail validation

- **WHEN** the only finding is an undischarged `setup` in a complete article
- **THEN** S4 is marked WARN and the exit status is 0

#### Scenario: Invalid JSON is an input error

- **WHEN** line 4 of `discourse.jsonl` is not valid JSON
- **THEN** the exit status is 2 and the message names line 4

### Requirement: The state query reports what the article owes at a position

`structure-state.py` SHALL accept `--jsonl` for the ledger, `--at` with a proposition UUID or `end`, optional sidecar paths, and `--format text|json`. It SHALL first apply S1 to S3 and exit 1 if any fails. For position t, counting t itself, it SHALL report t's position and the total count, the section containing t with its id, heading and role, t's relation, every commitment opened at or before t and not discharged at or before t, the `future_work` commitments opened so far, and whether any `thesis` proposition has appeared. Open commitments SHALL be ordered by kind as `announcement`, `hypothesis`, `plan`, `question`, `aim`, `setup`, and within a kind by the position that opened them, earliest first; each entry SHALL give its id, kind, the opening proposition's position and id, and the number of propositions since it was opened. It SHALL exit 2 when the `--at` id is not a non-retired ledger proposition.

#### Scenario: An open announcement comes first

- **WHEN** at position t a `question` opened at position 2 and an `announcement` opened at position t are both open
- **THEN** the announcement is listed first

#### Scenario: Unknown position is an input error

- **WHEN** `--at` names a UUID that is not in the ledger
- **THEN** the exit status is 2 and the message names the UUID

##### Example: Open commitments at a position

- **GIVEN** a ledger of 10 propositions where position 1 opens `c-q-1` (question), position 2 opens `c-plan-1` and `c-plan-2` (plan), position 4 discharges `c-plan-1`, position 6 opens `c-ann-1` (announcement) and `c-fw-1` (future_work)
- **WHEN** `structure-state.py --at` names position 6
- **THEN** the open commitments are, in order, `c-ann-1` (opened at 6, 0 since), `c-plan-2` (opened at 2, 4 since), `c-q-1` (opened at 1, 5 since), and `c-fw-1` appears only in the future-work list
