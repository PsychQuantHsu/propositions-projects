## MODIFIED Requirements

### Requirement: Plugins monorepo layout with a single tool implementation

The repository SHALL host all plugin content under `plugins/<name>/` directories, with `plugins/propositions/` as the core plugin (validator scripts, audit chain, and the domain-general manuscript-QA skills). Each tool script SHALL have exactly one implementation, located under `plugins/propositions/scripts/`. Tools written in Swift are the exception to that location: they live in the one Swift package at the repository root (`Package.swift`, `Sources/`, `tests/PropositionsKitTests/`), outside every plugin directory. While the Python validators are not ported, the rules for reading a `location` and the `\input` tree exist once in Python and once in Swift; the two SHALL be changed together, and no other logic is written twice. The repository SHALL NOT ship a plugin directory that contains no skills and no scripts.

No executable check: where a tool lives and whether a second copy exists is a property of the whole tree that a reviewer reads; the one part a test can observe, the root shims, is checked under the next requirement.

#### Scenario: Core plugin owns the toolchain

- **WHEN** a maintainer edits a validator or audit script
- **THEN** the edit occurs in exactly one file under `plugins/propositions/scripts/`
- **AND** no second copy of that script exists elsewhere in the repository except root-level shims

#### Scenario: Domain-general content stays in the core plugin

- **WHEN** a new skill, rule, or script is proposed for this repository
- **THEN** it is placed in `plugins/propositions/` unless it depends on a domain-specific toolchain (e.g. sympy substitution checking, Lean bridging)
- **AND** a separate `plugins/<domain>/` directory is created only at the moment such domain-specific content actually lands, never as an empty placeholder

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
