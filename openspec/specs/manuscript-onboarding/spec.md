# manuscript-onboarding Specification

## Purpose

TBD - created by archiving change 'add-manuscript-onboarding'. Update Purpose after archive.

## Requirements

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


<!-- @trace
source: add-analyze-entry-skill
updated: 2026-11-06
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Scaffold writes are dry-run gated

Operation D SHALL present a dry-run listing of every file it would create (with target paths) and obtain explicit user confirmation before writing anything into the user's repository.

#### Scenario: user declines at confirmation

- **WHEN** the dry-run listing is shown and the user declines
- **THEN** no file is created and the operation reports abort without error

---
### Requirement: Onboarding hands off to extraction and validation

After scaffolding, Operation D SHALL instruct the user to proceed with the `propositions:extract` skill, which ends with the Operation A validator gate, and SHALL NOT itself perform extraction.

#### Scenario: post-scaffold guidance

- **WHEN** scaffolding completes successfully
- **THEN** the completion report names `propositions:extract` as the next step, states that it ends with the Operation A validator gate, and gives the resolved `--jsonl` and `--tex` paths for this repo

---
### Requirement: Onboarding surfaces the lifecycle playbook

The plugin SHALL ship a lifecycle playbook document covering the full adoption arc (onboard, first extraction and validation, day-to-day drift maintenance, pre-submission proofread/audit cadence, new-draft re-anchoring, and line-anchored co-author correspondence as a repo-level convention), using the Hsu case as the worked example. The scaffold README written by Operation D SHALL summarize this lifecycle briefly and link to the playbook rather than copying it.

#### Scenario: scaffolded README points to the playbook

- **WHEN** Operation D completes a scaffold
- **THEN** the created ledger README contains a lifecycle summary and a reference to the plugin's playbook document, and no full playbook copy exists in the user's repository