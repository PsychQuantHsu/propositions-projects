## MODIFIED Requirements

### Requirement: Operation D scaffolds a ledger for a manuscript without one

The propositions skill SHALL provide an onboarding operation (Operation D) that, given a manuscript repository containing a target `.tex` main file but no propositions ledger, creates the ledger directory with: a `README.md`, a pinned copy of the canonical `SCHEMA.md`, a pinned copy of `EXTRACTION-PROMPT.md`, a populated `_meta.json`, an empty `main.jsonl`, and a `_smoke_tests/` skeleton. The pinned copies SHALL be taken from the plugin's canonical sources at scaffold time, not from a separately maintained template copy. Operation D SHALL ask the user which ledger profile the manuscript uses, offering exactly `default` and `empirical`, and the populated `_meta.json` SHALL record `schema_version` `1.7` together with the selected `profile`.

#### Scenario: scaffold on a bare manuscript repo

- **WHEN** Operation D runs against a repo whose confirmed main file is `manuscript/parametric_bootstrapping_se/05xx-2026/main_new.tex` and no `propositions/` ledger exists at the chosen placement layer
- **THEN** after user confirmation the ledger directory exists with all six scaffold artifacts, and `_meta.json` records `source.file` as the confirmed main-file path relative to the repo root together with the anchoring commit SHA of the manuscript repo's current HEAD

#### Scenario: profile recorded at scaffold time

- **WHEN** the user selects `empirical` when Operation D asks for the ledger profile and confirms the dry-run listing
- **THEN** the created `_meta.json` contains `"schema_version": "1.7"` and `"profile": "empirical"`

#### Scenario: refuse to overwrite an existing ledger

- **WHEN** Operation D runs against a placement layer that already contains a `main.jsonl` or `_meta.json`
- **THEN** the operation aborts with a message identifying the existing ledger and suggesting Operation A, Operation B or `propositions:extract` instead, and no file is written

#### Scenario: an empty ledger is ready for extraction

- **WHEN** Operation D has scaffolded a ledger and no proposition has been extracted
- **THEN** `validate-propositions.py` exits 0 on the empty `main.jsonl`, and `check-extraction-coverage.py` reports the manuscript's body as uncovered
