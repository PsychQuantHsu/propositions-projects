## Purpose

A ledger profile names the vocabulary a propositions ledger uses for `claim_type` and `evidence_class`. It exists so that manuscripts outside mathematics (first: empirical psychology) can pass the mechanical validator without loosening the closed enums that mathematical ledgers rely on.

## ADDED Requirements

### Requirement: Ledger declares its profile in metadata

A ledger SHALL declare its profile through a top-level string field `profile` in `_meta.json`. When the field is absent, the validator SHALL treat the ledger as declaring `default`.

#### Scenario: Ledger without a profile field

- **WHEN** the validator runs against a ledger whose `_meta.json` has no `profile` field
- **THEN** R11 and R12 apply the `default` vocabulary

#### Scenario: Ledger declaring the empirical profile

- **WHEN** the validator runs against a ledger whose `_meta.json` contains `"schema_version": "1.7"` and `"profile": "empirical"`
- **THEN** R11 and R12 apply the `empirical` vocabulary

---
### Requirement: Profile values form a closed set

The accepted values of `profile` SHALL be exactly `default` and `empirical`. The validator SHALL NOT infer a profile from a value that resembles an accepted one. Adding a profile SHALL require a schema change recorded in `docs/SCHEMA.md` together with the validator change.

#### Scenario: Unknown profile value

- **WHEN** `_meta.json` declares `"profile": "psychology"`
- **THEN** the validator reports an error naming the value `psychology` and the accepted set `{default, empirical}`, and exits with status 1

---
### Requirement: Profile declaration requires schema version 1.7

A ledger that declares `profile` SHALL have `schema_version` 1.7 or later. The validator SHALL report an error and exit with status 1 when `profile` is present and `schema_version` is below 1.7, and SHALL NOT fall back to the default vocabulary in that case.

#### Scenario: Profile declared under an older schema

- **WHEN** `_meta.json` contains `"schema_version": "1.6"` and `"profile": "empirical"`
- **THEN** the validator reports that the schema version must be raised to 1.7 before declaring a profile, and exits with status 1

#### Scenario: Pre-1.2 ledgers keep skipping the enum rules

- **WHEN** `_meta.json` has `schema_version` below 1.2 or none at all, and no `profile` field
- **THEN** R11 and R12 are reported as skipped exactly as before this change

---
### Requirement: Profile selects the R11 and R12 vocabularies

R11 SHALL accept the `evidence_class` values of the declared profile, and R12 SHALL accept the `claim_type` values of the declared profile. The `default` vocabularies SHALL be the current canonical enums. The `empirical` vocabularies SHALL be the `default` vocabularies plus the empirical additions defined by the proofread skill's Mode B. Error messages SHALL list the full accepted set of the declared profile.

| Profile | `claim_type` accepted | `evidence_class` accepted |
| ------- | --------------------- | ------------------------- |
| `default` | axiom, definition, hypothesis, claim, case_split, display_equation, restatement, commentary, example, connective, reference, scope_qualifier | verified, derived, hypothesized, conventional, open |
| `empirical` | the `default` set plus result, interpretation | the `default` set plus measured, tested, descriptive, not_computable, external |

#### Scenario: Empirical vocabulary rejected under the default profile

- **WHEN** a ledger without a `profile` field contains a proposition with `claim_type` `result` and `evidence_class` `measured`
- **THEN** R12 reports `result` as non-canonical and R11 reports `measured` as non-canonical, and the validator exits with status 1

#### Scenario: Empirical vocabulary accepted under the empirical profile

- **WHEN** a ledger declaring `empirical` under schema 1.7 contains a proposition with `claim_type` `result` and `evidence_class` `measured`
- **THEN** R11 and R12 pass for that proposition

#### Scenario: Default vocabulary still accepted under the empirical profile

- **WHEN** a ledger declaring `empirical` contains a proposition with `claim_type` `definition` and `evidence_class` `conventional`
- **THEN** R11 and R12 pass for that proposition

##### Example: R11/R12 outcome by profile

| Profile declared | `claim_type` | `evidence_class` | R11 | R12 |
| ---------------- | ------------ | ---------------- | --- | --- |
| (none) | claim | derived | PASS | PASS |
| (none) | result | measured | FAIL | FAIL |
| empirical | result | measured | PASS | PASS |
| empirical | interpretation | descriptive | PASS | PASS |
| empirical | claim | external | PASS | PASS |
| (none) | claim | external | FAIL | PASS |
| empirical | finding | measured | PASS | FAIL |
| empirical | claim | strong | FAIL | PASS |

---
### Requirement: Undeclared ledgers see unchanged validator output

For a ledger whose `_meta.json` has no `profile` field and whose source files contain no escaped percent sign `\%`, the validator's standard output and exit status SHALL be identical, character for character, to its output before profiles existed. For a ledger whose source contains `\%`, the only permitted differences SHALL be R1 and R13 findings that change because escaped percent signs are no longer treated as comments. The validator SHALL print the line `[INFO] profile: <value>` only when `_meta.json` declares `profile`.

#### Scenario: Regression on an existing mathematical ledger

- **WHEN** the validator runs on an existing mathematical ledger that declares no profile and whose source contains no `\%`, before and after this change
- **THEN** the two outputs are byte-identical and the exit statuses are equal

#### Scenario: Declared profile is announced

- **WHEN** the validator runs on a ledger declaring `"profile": "empirical"` under schema 1.7
- **THEN** the output contains the line `[INFO] profile: empirical`
