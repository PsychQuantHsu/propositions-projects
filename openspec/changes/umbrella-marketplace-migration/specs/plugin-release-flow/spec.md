## ADDED Requirements

### Requirement: Versioned release with manifest synchronization

Every release of a plugin in this marketplace SHALL bump the plugin's `plugin.json` version, update the corresponding `marketplace.json` entry to the same version, and create a git tag, in one coherent change. A release SHALL NOT leave `marketplace.json` referring to a version that differs from the plugin manifest.

#### Scenario: Release keeps manifests in sync

- **WHEN** a maintainer publishes a new version of the core plugin
- **THEN** `plugins/propositions/.claude-plugin/plugin.json` and the `marketplace.json` entry carry the same new version
- **AND** a git tag exists for the release commit

#### Scenario: Drifted manifests block the release

- **WHEN** the release procedure detects that the marketplace entry version differs from the plugin manifest version
- **THEN** the release is not published until the mismatch is fixed

### Requirement: Documented release procedure

The repository SHALL contain a release-flow document (docs/RELEASE-FLOW.md) describing the ordered procedure: version bump, manifest sync, tag, push, and the `claude plugin marketplace update` verification step for installed users.

#### Scenario: Maintainer follows the documented flow

- **WHEN** a maintainer prepares a release
- **THEN** docs/RELEASE-FLOW.md provides the complete ordered checklist without requiring knowledge from outside this repository

### Requirement: Downstream pin bumps are deliberate and documented

Consumers that pin this repository by tag (e.g. CI workflows checking out the audit chain) SHALL be bumped deliberately: each release's notes SHALL state whether the pinned entry-point contract (root `scripts/` paths, report format, exit codes) changed, so downstream maintainers can decide when to move their pin.

#### Scenario: Release notes state entry-point compatibility

- **WHEN** a release is published
- **THEN** its notes state either "pinned entry-point contract unchanged" or enumerate the breaking changes with a migration instruction for pinned consumers
