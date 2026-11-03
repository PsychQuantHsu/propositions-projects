## MODIFIED Requirements

### Requirement: Structure validation reports per rule with fixed exit codes

`validate-structure.py` SHALL accept `--jsonl` for the ledger, optional `--structure` and `--discourse` paths defaulting to the ledger's directory, optional `--vocabulary`, `--partial`, and `--format text|json`. It SHALL print one summary line per rule (S1 to S9) marked PASS, FAIL or WARN, followed by each problem with the proposition's position and id. It SHALL exit 0 when no rule fails, 1 when any rule fails, and 2 when an input file is missing, unreadable or not valid JSON, when `structure_version` is not `"2.0"`, or when moves or types are present and the vocabulary cannot be loaded; when `structure_version` is not `"2.0"` the message SHALL name `migrate-structure-v2.py`.

#### Scenario: Warnings alone do not fail validation

- **WHEN** the only finding is an undischarged `setup` in a complete article
- **THEN** S4 is marked WARN and the exit status is 0

#### Scenario: Invalid JSON is an input error

- **WHEN** line 4 of `discourse.jsonl` is not valid JSON
- **THEN** the exit status is 2 and the message names line 4

#### Scenario: Version 1.0 sidecars are refused

- **WHEN** `structure.json` has `structure_version` set to `"1.0"`
- **THEN** the exit status is 2 and the message names `migrate-structure-v2.py`

#### Scenario: A broken vocabulary is an input error

- **WHEN** a record has `move` and the vocabulary file has a repeated id
- **THEN** the exit status is 2 and the message names the repeated id
