# umbrella-marketplace-layout Specification

## Purpose

TBD - created by archiving change 'umbrella-marketplace-migration'. Update Purpose after archive.

## Requirements

### Requirement: Plugins monorepo layout with a single tool implementation

The repository SHALL host all plugin content under `plugins/<name>/` directories, with `plugins/propositions/` as the core plugin (validator scripts, audit chain, and the domain-general manuscript-QA skills). Each tool script SHALL have exactly one implementation, located under `plugins/propositions/scripts/`. The repository SHALL NOT ship a plugin directory that contains no skills and no scripts.

#### Scenario: Core plugin owns the toolchain

- **WHEN** a maintainer edits a validator or audit script
- **THEN** the edit occurs in exactly one file under `plugins/propositions/scripts/`
- **AND** no second copy of that script exists elsewhere in the repository except root-level shims

#### Scenario: Domain-general content stays in the core plugin

- **WHEN** a new skill, rule, or script is proposed for this repository
- **THEN** it is placed in `plugins/propositions/` unless it depends on a domain-specific toolchain (e.g. sympy substitution checking, Lean bridging)
- **AND** a separate `plugins/<domain>/` directory is created only at the moment such domain-specific content actually lands, never as an empty placeholder

---
### Requirement: Root-level CI entry shims preserve the pinned path contract

The repository SHALL keep root-level `scripts/` entries (at minimum `run-audit.sh` and `validate-propositions.py`) as forwarding shims that delegate to the implementations under `plugins/propositions/scripts/`, forwarding argv, stdout/stderr, and exit codes byte-for-byte. The root-level `tests/` invocation (`pytest tests/`) SHALL remain green.

#### Scenario: Pinned CI checkout keeps working across tags

- **WHEN** a downstream workflow checks out any tag of this repository and runs `propositions-plugin/scripts/run-audit.sh <target>`
- **THEN** the audit chain executes identically to invoking the implementation under `plugins/propositions/scripts/` directly
- **AND** the exit code and report output are unchanged by the shim layer

#### Scenario: Shim transparency verified by smoke test

- **WHEN** the test suite runs
- **THEN** a shim smoke test asserts that root-level invocation and core-plugin invocation produce identical exit codes and equivalent output for a fixture input

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
