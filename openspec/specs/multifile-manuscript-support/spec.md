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

`_meta.json` SHALL support an optional `source.parts` string array. When the validator or Operation D resolves the input tree, it SHALL refresh this array to the resolved relative paths. Consumers SHALL treat the live input-tree resolution, not `source.parts`, as authoritative.

#### Scenario: parts snapshot refresh

- **WHEN** Operation A runs against a multi-file manuscript whose `source.parts` is stale or absent
- **THEN** after the run `source.parts` lists the currently resolved part files in document order

---
### Requirement: Location prefix outside the input tree fails

R13 SHALL fail a prop whose location file prefix names a file that is not in the resolved input tree.

#### Scenario: prefix to an unrelated file

- **WHEN** a prop's location is `notes/scratch.tex:L10` and `notes/scratch.tex` is not reachable from the main file's input tree
- **THEN** R13 reports the prop with reason "file not in input tree"
