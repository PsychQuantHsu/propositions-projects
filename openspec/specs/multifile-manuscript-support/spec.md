# multifile-manuscript-support Specification

## Purpose

TBD - created by archiving change 'add-manuscript-onboarding'. Update Purpose after archive.

## Requirements

### Requirement: File-qualified location syntax

The ledger schema (v1.6+) SHALL accept `location` values of the form `<relpath>.tex:L<a>` or `<relpath>.tex:L<a>-L<b>`, where `<relpath>` is resolved relative to the directory containing the main file recorded in `_meta.json` `source.file`. A `location` without a file prefix SHALL keep its existing meaning: it refers to the main file itself.

#### Scenario: prefixed location resolves to an input file

- **WHEN** a prop carries `location: parts/part2-theory.tex:L123` and the main file is `05xx-2026/main_new.tex`
- **THEN** R13 anchors the prop's text at line 123 of `05xx-2026/parts/part2-theory.tex`

##### Example: backward-compatible unprefixed location

- **GIVEN** a v1.5 ledger whose props all use `location: L1317` style with `source.file: main.tex`
- **WHEN** the v1.6 validator runs Operation A on it
- **THEN** every rule (R1-R13) produces the same pass/fail results as the pre-upgrade validator

#### Scenario: prefix on an old-schema ledger fails loudly

- **WHEN** a ledger with `schema_version` lower than 1.6 contains a file-prefixed location
- **THEN** R13 reports a failure naming the prop and instructing a schema-version upgrade, rather than silently accepting or ignoring the prefix

---
### Requirement: Input-tree resolution from the main file

The validator and the location-refresh script SHALL resolve the manuscript's file set by recursively parsing `\input{...}` and `\include{...}` from the main file (appending the `.tex` extension when omitted), up to a nesting depth of 3, ignoring occurrences on commented lines.

#### Scenario: one-level input tree

- **WHEN** the main file contains `\input{parts/part1-intro}` through `\input{parts/part4-discussion}`
- **THEN** the resolved file set contains the main file plus the four part files, and R1 matches prop text against the union of these files

#### Scenario: missing input target

- **WHEN** the main file references `\input{parts/part5-missing}` and no such file exists
- **THEN** validation aborts with an error naming the missing path and the referencing file and line

#### Scenario: circular input

- **WHEN** file A inputs file B and file B inputs file A
- **THEN** resolution aborts with a cycle report instead of looping or silently truncating

---
### Requirement: Meta records the resolved parts as a non-authoritative snapshot

`_meta.json` SHALL support an optional `source.parts` string array: a snapshot of the part files of the input tree. No tool writes it; the author records and updates it by hand. The validator SHALL NOT write `_meta.json`; running it with `--meta` SHALL leave the file unchanged byte for byte (issue 146). Consumers SHALL treat the live input-tree resolution, not `source.parts`, as authoritative.

The validator SHALL compare the snapshot with the resolved tree whenever `--meta` names a readable `_meta.json` whose `source` is an object and whose `source.parts` is present and not `null`. The snapshot differs when it is not the list of part files the tree resolves, in document order, in the form the validator writes in a `location` prefix (for a tree without part files, the empty list). A difference SHALL be one warning, printed as a line that begins `[WARN] source.parts` and names every part file resolved now (or says there are none), and counted with the other warnings, so that `--strict` fails. A missing or `null` `source.parts` is no snapshot and SHALL produce no warning. A `_meta.json` that is not valid JSON SHALL stop the run as a parse error (exit 2), as the ledger loader reads it first; a `source` that is not an object SHALL produce no warning. In both cases the file SHALL be unchanged.

#### Scenario: Measuring leaves the meta file as it was

- **WHEN** the validator runs with `--meta` on a multi-file manuscript whose `source.parts` is stale
- **THEN** `_meta.json` has the same bytes after the run as before

##### Example: a stale snapshot is reported and not rewritten

- **GIVEN** a manuscript whose tree resolves `parts/part1.tex` and `parts/part2-theory.tex`, and a `_meta.json` whose `source.parts` is `["parts/part1.tex"]`
- **WHEN** the validator runs with `--jsonl`, `--meta` and `--tex`
- **THEN** `_meta.json` is unchanged byte for byte, the output has a line beginning `[WARN] source.parts` that names both files, and the run exits 0

##### Example: strict fails on a stale snapshot

- **GIVEN** the manuscript and the stale `_meta.json` of the previous example
- **WHEN** the validator runs with `--strict`
- **THEN** it exits 1 and `_meta.json` is unchanged

##### Example: a current snapshot gives no warning

- **GIVEN** a `_meta.json` whose `source.parts` is `["parts/part1.tex", "parts/part2-theory.tex"]` for the same manuscript
- **WHEN** the validator runs with `--meta`
- **THEN** no output line begins `[WARN] source.parts`

##### Example: a multi-file ledger without the key stays quiet

- **GIVEN** the same manuscript and a `_meta.json` whose `source` has no `parts`, as Operation D scaffolds it
- **WHEN** the validator runs with `--strict` and nothing else warns
- **THEN** it exits 0, no output line begins `[WARN] source.parts`, and `_meta.json` is unchanged

##### Example: a single-file ledger without the key stays quiet

- **GIVEN** a single-file manuscript and a `_meta.json` whose `source` has no `parts`
- **WHEN** the validator runs with `--meta`
- **THEN** it exits 0, no output line begins `[WARN] source.parts`, and `_meta.json` is unchanged

##### Example: a single-file ledger with leftover parts is warned

- **GIVEN** a single-file manuscript and a `_meta.json` whose `source.parts` is `["parts/old.tex"]`
- **WHEN** the validator runs with `--meta`
- **THEN** a line beginning `[WARN] source.parts` says the tree has no part files, and `_meta.json` still lists `parts/old.tex`


<!-- @trace
source: idd-146-validator-meta-read-only
updated: 2026-11-25
code:
  - plugins/propositions/.claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
  - docs/SCHEMA.md
  - plugins/propositions/scripts/validate-propositions.py
tests:
  - tests/test_multifile_support.py
-->
<!-- @trace
source: idd-146-fix1
updated: 2026-11-27
code:
  - plugins/propositions/README.md
  - docs/SCHEMA.md
  - plugins/propositions/scripts/validate-propositions.py
tests:
  - tests/test_multifile_support.py
-->

---
### Requirement: Location prefix outside the input tree fails

R13 SHALL fail a prop whose location file prefix names a file that is not in the resolved input tree.

#### Scenario: prefix to an unrelated file

- **WHEN** a prop's location is `notes/scratch.tex:L10` and `notes/scratch.tex` is not reachable from the main file's input tree
- **THEN** R13 reports the prop with reason "file not in input tree"
