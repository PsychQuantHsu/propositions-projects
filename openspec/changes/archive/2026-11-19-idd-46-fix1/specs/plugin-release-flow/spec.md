## MODIFIED Requirements

### Requirement: Documented release procedure

The repository SHALL contain a release-flow document (docs/RELEASE-FLOW.md) describing the ordered procedure: version bump, manifest sync, tag, push, and the `claude plugin marketplace update` verification step for installed users. The same document SHALL describe the release of the command-line binary as a separate procedure: the script that performs it, the version it is checked against, its own family of tags (`propositions-cli-v<X.Y.Z>`), the contract statement its release notes carry, and that it is run by the maintainer only.

#### Scenario: Maintainer follows the documented flow

- **WHEN** a maintainer prepares a release
- **THEN** docs/RELEASE-FLOW.md provides the complete ordered checklist without requiring knowledge from outside this repository

#### Scenario: Maintainer releases the binary

- **WHEN** a maintainer wants to publish the `propositions` binary
- **THEN** docs/RELEASE-FLOW.md names the script, the version file and the tag to use, and says that no plugin downloads the binary yet
