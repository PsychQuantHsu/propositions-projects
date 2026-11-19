## MODIFIED Requirements

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
