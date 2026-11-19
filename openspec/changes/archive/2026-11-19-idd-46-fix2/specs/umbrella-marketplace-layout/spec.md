## MODIFIED Requirements

### Requirement: Plugins monorepo layout with a single tool implementation

The repository SHALL host all plugin content under `plugins/<name>/` directories, with `plugins/propositions/` as the core plugin (validator scripts, audit chain, and the domain-general manuscript-QA skills). Each tool script SHALL have exactly one implementation, located under `plugins/propositions/scripts/`. Tools written in Swift are the exception to that location: they live in the one Swift package at the repository root (`Package.swift`, `Sources/`, `tests/PropositionsKitTests/`), outside every plugin directory. While the Python validators are not ported, three things the Swift check needs are written in both languages: reading a ledger line (`id`, `cites`, a well-formed `retired` block), reading a `location`, and reading the `\input` tree with its line numbers. For the first the Swift code follows the ledger validator; for the other two it follows the tool that writes `location`, `refresh-prop-locations.py`. A change to how that tool counts lines or names files, to `parse_location_v16`, or to the validator's `retired_problem` SHALL be made in the Swift package in the same change. No other logic is written twice. The repository SHALL NOT ship a plugin directory that contains no skills and no scripts.


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
