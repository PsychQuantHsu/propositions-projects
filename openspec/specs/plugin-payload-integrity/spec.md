# plugin-payload-integrity Specification

## Purpose

TBD - created by archiving change 'restore-core-plugin-tracking'. Update Purpose after archive.

## Requirements

### Requirement: Published plugin payload is version-controlled

Every file that a marketplace entry needs in order to install — the plugin manifest and every skill definition under the entry's `source` directory — SHALL be tracked by git. A file that exists only in a working directory is invisible to any consumer resolving the marketplace from the remote, and `git add` skips ignored paths silently, so absence of an error is not evidence of tracking.

#### Scenario: Manifest of a published entry is tracked

- **WHEN** the repository enumerates the `plugins` array of `.claude-plugin/marketplace.json` and resolves each entry's `source` directory
- **THEN** `<source>/.claude-plugin/plugin.json` appears in the output of `git ls-files` for every entry

#### Scenario: Every skill of a published entry is tracked

- **WHEN** the repository enumerates the `SKILL.md` files present on disk under `<source>/skills/` for a published entry
- **THEN** every one of those files appears in the output of `git ls-files`

#### Scenario: An ignore pattern shadowing published payload fails the check

- **WHEN** an ignore rule causes a manifest or skill file under a published entry to be untracked
- **THEN** the payload-tracking test fails and names the specific untracked paths

##### Example: the un-anchored pattern that caused this change

| Ignore pattern | Intended target | Also swallows | Tracked result |
| -------------- | --------------- | ------------- | -------------- |
| `propositions/` | root `propositions/` conftest shim | `plugins/propositions/` at any depth | manifest, README, all skills untracked |
| `/propositions/` | root `propositions/` conftest shim | nothing else | payload tracked |

---
### Requirement: Ignore patterns for repository-root scaffolding are anchored

An ignore pattern that exists to exclude a directory created at the repository root SHALL carry a leading slash. Without one, git matches the pattern against a directory of that name at any depth, which silently excludes unrelated source directories that happen to share the name.

#### Scenario: Root-scaffolding pattern carries a leading slash

- **WHEN** an ignore entry exists to exclude test-fixture or tooling scaffolding created at the repository root
- **THEN** the entry is written with a leading slash so it matches only the root-level directory

#### Scenario: Nested directory sharing the name stays tracked

- **WHEN** a source directory nested below the repository root shares a name with a root-scaffolding ignore entry
- **THEN** `git check-ignore` reports no match for files inside that nested directory

---
### Requirement: Published plugin ships every documented skill

The set of skills shipped under a published entry's `skills/` directory SHALL cover every skill invocation that the repository documentation instructs users to run against that plugin. A documented invocation with no corresponding skill definition is a broken promise that installation cannot satisfy.

#### Scenario: Documented invocation resolves to a shipped skill

- **WHEN** repository documentation instructs a user to invoke a skill using the `<plugin>:<skill>` form
- **THEN** a directory named `<skill>` containing `SKILL.md` exists under the plugin entry's `skills/` directory

#### Scenario: Orphaned skills outside any published entry are absent

- **WHEN** the repository is scanned for `SKILL.md` files that belong to the plugin product
- **THEN** every such file resides under a directory referenced by a marketplace entry's `source`, and none resides at a path that no manifest claims

---
### Requirement: A skill name has exactly one definition

Each skill name SHALL be defined in exactly one location in the repository. Two files defining the same skill name diverge without any mechanical signal, and consumers cannot tell which copy is authoritative.

#### Scenario: No duplicate skill names across the repository

- **WHEN** all `SKILL.md` files in the repository are collected and grouped by their declared `name` frontmatter field
- **THEN** every group contains exactly one file

#### Scenario: Duplicate definitions fail the check with both paths

- **WHEN** two `SKILL.md` files declare the same `name`
- **THEN** the duplication test fails and reports the skill name together with both file paths
