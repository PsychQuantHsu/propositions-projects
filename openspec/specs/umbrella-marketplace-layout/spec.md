# umbrella-marketplace-layout Specification

## Purpose

TBD - created by archiving change 'umbrella-marketplace-migration'. Update Purpose after archive.

## Requirements

### Requirement: Plugins monorepo layout with a single tool implementation

The repository SHALL host all plugin content under `plugins/<name>/` directories, with `plugins/propositions/` as the core plugin (validator scripts, audit chain, and the domain-general manuscript-QA skills). Each tool script SHALL have exactly one implementation, located under `plugins/propositions/scripts/`. Tools written in Swift are the exception to that location: they live in the one Swift package at the repository root (`Package.swift`, `Sources/`, `tests/PropositionsKitTests/`), outside every plugin directory. While the Python validators are not ported, three things the Swift check needs are written in both languages: deciding whether a `retired` block is well formed, reading a `location`, and counting the lines of a manuscript file. For the first the Swift code follows the ledger validator's `retired_problem`; for the second `parse_location_v16`; for the third the tool that writes `location`, `refresh-prop-locations.py`. Tests of the Swift package put the same inputs to both languages and compare the answers. The `\input` tree is read by the Swift package in its own way, stated in the citation-order specification; it is not a copy of the Python `resolve_input_tree`. A change to how that tool counts lines or names files, to `parse_location_v16`, or to the validator's `retired_problem` SHALL be made in the Swift package in the same change. No other logic is written twice. The repository SHALL NOT ship a plugin directory that contains no skills and no scripts.


#### Scenario: Core plugin owns the toolchain

- **WHEN** a maintainer edits a validator or audit script
- **THEN** the edit occurs in exactly one file under `plugins/propositions/scripts/`, and also in the Swift package when it changes one of the three things written in both languages
- **AND** no second copy of that script exists elsewhere in the repository except root-level shims

#### Scenario: Domain-general content stays in the core plugin

- **WHEN** a new skill, rule, or script is proposed for this repository
- **THEN** it is placed in `plugins/propositions/` unless it depends on a domain-specific toolchain (e.g. sympy substitution checking, Lean bridging)
- **AND** a separate `plugins/<domain>/` directory is created only at the moment such domain-specific content actually lands, never as an empty placeholder

##### Example: the Swift package is at the root and nowhere else

- **GIVEN** the repository
- **WHEN** it is searched for Swift files
- **THEN** `Package.swift` is at the root, and no directory under `plugins/` holds a Swift file

##### Example: a location is read alike in both languages

- **GIVEN** a list of location strings, some written as the schema writes them and some not
- **WHEN** each is given to `parse_location_v16` and to the Swift package
- **THEN** both refuse the same strings and give the same line numbers and file for the others

##### Example: lines are counted alike in both languages

- **GIVEN** texts that hold line feeds, carriage returns, the two together, a form feed and a line separator
- **WHEN** each is split into lines as `refresh-prop-locations.py` splits it and as the Swift package splits it
- **THEN** the lines are the same

##### Example: a retired block is judged alike in both languages

- **GIVEN** `retired` values that are well formed and values that are not
- **WHEN** each is given to the validator's `retired_problem` and to the Swift package
- **THEN** both take the same values for a block that retires its proposition


<!-- @trace
source: idd-46-fix3
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Root-level CI entry shims preserve the pinned path contract

The repository SHALL keep root-level `scripts/` entries (at minimum `run-audit.sh` and `validate-propositions.py`) as forwarding shims that delegate to the implementations under `plugins/propositions/scripts/`, forwarding argv, stdout/stderr, and exit codes byte-for-byte. The root-level `scripts/` directory MAY also hold `release-signed.sh`, the maintainer's script for releasing the Swift binary; it is not an entry point for downstream CI and forwards to nothing. The root-level `tests/` invocation (`pytest tests/`) SHALL remain green.

#### Scenario: Pinned CI checkout keeps working across tags

- **WHEN** a downstream workflow checks out any tag of this repository and runs `propositions-plugin/scripts/run-audit.sh <target>`
- **THEN** the audit chain executes identically to invoking the implementation under `plugins/propositions/scripts/` directly
- **AND** the exit code and report output are unchanged by the shim layer

#### Scenario: Shim transparency verified by smoke test

- **WHEN** the test suite runs
- **THEN** a shim smoke test asserts that root-level invocation and core-plugin invocation produce identical exit codes and equivalent output for a fixture input

##### Example: the validator shim forwards its exit code and output

- **GIVEN** the fixture ledger of the shim smoke test
- **WHEN** `scripts/validate-propositions.py` at the root and the implementation under `plugins/propositions/scripts/` are each run on it
- **THEN** both exit with the same code and print the same output


<!-- @trace
source: idd-46-fix1-links
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Umbrella marketplace manifest

The `.claude-plugin/marketplace.json` SHALL declare the marketplace name `propositions-projects` and SHALL list one entry per plugin directory that exists under `plugins/`, with `source` values pointing at `./plugins/<name>`. The manifest SHALL NOT retain the legacy single `"./"` entry, and SHALL NOT list an entry whose target directory contains no skills and no scripts.

#### Scenario: Marketplace lists the core plugin

- **WHEN** a user registers the marketplace and lists available plugins
- **THEN** `propositions` appears and is installable from its `./plugins/propositions` source
- **AND** no entry resolves to a directory without installable content

---
### Requirement: Supported ledger schema range is declared, not vendored

The core plugin SHALL declare the supported propositions-ledger schema range (currently up to 1.5) in its plugin description and in a "Schema compatibility" section of its README. The repository SHALL NOT vendor a copy of any manuscript's SCHEMA.md.

#### Scenario: User checks schema compatibility

- **WHEN** a user reads the core plugin's README or manifest description
- **THEN** the supported schema range is stated, including version-conditional validator rules (v1.2+ / v1.4+)
- **AND** no SCHEMA.md copy exists in this repository

---
### Requirement: Migration notes for installed users

The repository README SHALL contain a "Migration notes" section describing how existing users move from the legacy `propositions` single-plugin marketplace and the deprecated psychquant-claude-plugins math-tools plugin, including the uninstall-before-install guidance that prevents same-name skill collisions during the transition.

#### Scenario: Legacy marketplace registrant migrates

- **WHEN** a user who registered the marketplace under its legacy name reads the Migration notes
- **THEN** the notes state whether `claude plugin marketplace update` follows the rename, and if not, provide the exact remove/re-add command sequence

#### Scenario: math-tools user migrates without skill collisions

- **WHEN** a user with the deprecated `math-tools` plugin from the psychquant-claude-plugins marketplace installs the core propositions plugin
- **THEN** the Migration notes instruct removing the old plugin so that same-name skills do not coexist
- **AND** the notes state that `math-tools` is not re-published by this marketplace, so the skills are invoked as `propositions:<skill>` after migration