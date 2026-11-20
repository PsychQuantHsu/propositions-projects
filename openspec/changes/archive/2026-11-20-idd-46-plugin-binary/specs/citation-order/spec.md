## MODIFIED Requirements

### Requirement: The binary is published only by the maintainer

The repository SHALL hold a release script, `scripts/release-signed.sh`, that runs the package's tests, builds the `propositions` binary, signs it, submits it for notarization, and tags and publishes it only when the notarization result is `Accepted`. It is not run by a skill or by this change: publishing a signed binary is the maintainer's action. No plugin directory SHALL hold a `bin/` directory: a plugin that has one is not installed by claude.ai or Cowork, and what the directory holds is put on the Bash tool's `PATH`. How a plugin obtains the binary is the requirement on the session-start hook below. The release script publishes a binary and changes no plugin: a plugin keeps the version its lock file names until a plugin release changes that file.

The script SHALL refuse, before it runs any other tool, a version that differs from the package's version. Signing, notarization and publishing themselves have no test: they act on the maintainer's signing identity and on a release, which no test can supply. These are tested, with stand-ins for the tools the script runs, and no other path of the script is: the refusal of a version that is not the package's, of a missing version, of a missing signing identity, of a working tree that is not clean, of a tag that names another commit, and of a notarization that is not accepted; and the order of the steps when all of these pass. The script builds with the dependency versions that `Package.resolved` names.

#### Scenario: No plugin ships an executable directory

- **WHEN** the plugin directories of the repository are listed
- **THEN** none of them holds a `bin/` directory

##### Example: no plugin ships an executable directory

- **GIVEN** the directories under `plugins/` of the repository
- **WHEN** each is looked into
- **THEN** none of them holds a `bin/` directory

##### Example: the release script refuses a version that is not the package's

- **GIVEN** the package at version `0.1.0`
- **WHEN** the release script runs with `VERSION=9.9.9`
- **THEN** it says that the version differs from `Sources/PropositionsKit/Version.swift`, exits with 1, and has run no other tool

##### Example: a notarization that is not accepted publishes nothing

- **GIVEN** stand-ins for the tools the release script runs, with a notarization that reports `Invalid`
- **WHEN** the release script runs
- **THEN** it ran the tests before the build and the build before the notarization, says that the notarization was not accepted, exits with 1, and made no tag, pushed nothing and created no release

##### Example: an accepted notarization is tagged and published

- **GIVEN** the same stand-ins, with a notarization that reports `Accepted`
- **WHEN** the release script runs
- **THEN** it runs the tests, then the notarization, then tags `propositions-cli-v<version>`, then creates the release, in that order

##### Example: the release script refuses a tree or a tag that is not the commit it builds

- **GIVEN** stand-ins for the tools the release script runs, with a working tree that has a change, or with the release tag already at another commit
- **WHEN** the release script runs
- **THEN** it says so, exits with 1, and has tested, built and published nothing

## ADDED Requirements

### Requirement: A plugin session fetches the pinned binary and verifies it

The `propositions` plugin SHALL have a SessionStart hook, `hooks/fetch-cli.sh`, and a lock file beside it, `hooks/cli.lock`, with three lines: `version` (the release, three numbers), `sha256` (64 lower-case hexadecimal digits) and `team` (the signing team). The hook SHALL put the binary of that release at `bin/propositions` under the plugin's data directory, the directory Claude Code names in `CLAUDE_PLUGIN_DATA`, and nowhere else.

The hook SHALL install a downloaded file only when all of these hold: its SHA-256 is the one in the lock, `codesign` verifies its signature, and the signature's team is the one in the lock. It downloads over HTTPS from the release `propositions-cli-v<version>` of this repository.

When the binary already there has the pinned SHA-256, the hook SHALL do nothing and print nothing. When something else is at that path, the hook SHALL remove it before it downloads, so that a failed download or a failed check leaves no binary of another version for a skill to call. The hook SHALL do nothing at all, a file of another version left as it is, on a system that is not macOS (the release is a macOS binary), when `CLAUDE_PLUGIN_DATA` is not set, and when the last component of `CLAUDE_PLUGIN_DATA` is neither `propositions` nor a name that starts with `propositions-`: a shell can carry the data directory of another plugin, and the hook writes into no directory but its own. A lock file with a field that does not have the form above SHALL end the hook before any download, with a line that names the field.

The hook SHALL always exit with 0 and SHALL print at most one line: a session does not fail because the binary could not be fetched. It decides nothing about a ledger or an outline.

The skill for the mechanical gate (`/propositions:propositions`, Operation A) SHALL run `propositions cite-order` after the ledger validator when the binary is there, and SHALL report the citation direction as not checked when it is not or when the command exits with 1 or 2. A warning from the command does not fail the operation. The skill names the binary by `${CLAUDE_PLUGIN_DATA}` written in its text, which Claude Code replaces when it loads the skill; the Bash tool's environment does not hold this plugin's value.

The hook is tested with stand-ins for `curl`, `codesign` and `uname`; nothing is downloaded in a test. The lock file of the repository is tested for its form only: that it names a release that exists, and that release's hash, is checked by the maintainer when the lock is changed (`docs/RELEASE-FLOW.md`). What the skill does has no test: it is text that a model follows.

#### Scenario: A session on macOS gets the pinned binary

- **WHEN** a session starts with the plugin enabled, on macOS, and no binary is in the plugin's data directory
- **THEN** the hook downloads the release the lock names and installs it only if its SHA-256 and its signing team are the ones in the lock

##### Example: the hook installs the binary that has the pinned hash and team

- **GIVEN** a lock file with version `9.9.9`, the SHA-256 of a stand-in file and a team, and stand-ins that serve that file and report that team
- **WHEN** the hook runs with a data directory named `propositions-test`
- **THEN** it downloads from the release `propositions-cli-v9.9.9`, the file is at `bin/propositions` under the data directory, the hook says that it installed version 9.9.9, exits with 0, and leaves no other file in `bin/`

##### Example: the hook is silent when the pinned binary is already there

- **GIVEN** the same lock file, and the stand-in file already at `bin/propositions`
- **WHEN** the hook runs
- **THEN** it prints nothing, runs no download, and exits with 0

##### Example: a failed check leaves no binary

- **GIVEN** the same lock file and a file of another version at `bin/propositions`
- **WHEN** the hook runs and one of these holds:

| What fails | The hook's line names |
| ---------- | --------------------- |
| the downloaded file has another SHA-256 | the pinned SHA-256 |
| the signature's team is another one | the pinned team |
| the signature names no team | the pinned team |
| `codesign` does not verify the signature | the signature |
| the download fails | the download |

- **THEN** nothing is at `bin/propositions`, no other file is left in `bin/`, and the hook exits with 0

##### Example: the hook does nothing outside its own data directory

- **GIVEN** the same lock file
- **WHEN** the hook runs with `CLAUDE_PLUGIN_DATA` unset, or naming a directory called `codex-openai-codex`, or on a system whose `uname` prints `Linux`
- **THEN** it prints nothing, runs no download, writes nothing, and exits with 0

##### Example: an unusable lock file fetches nothing

- **GIVEN** a lock file in which one field is unusable:

| Field | Value |
| ----- | ----- |
| `version` | `1.0;rm` |
| `sha256` | `abc` |
| `sha256` | 64 hexadecimal digits in upper case |
| `team` | empty |

- **WHEN** the hook runs
- **THEN** it says that the lock has no usable field of that name, runs no download, installs nothing, and exits with 0

##### Example: the repository's lock file has the three fields

- **GIVEN** `plugins/propositions/hooks/cli.lock` of the repository
- **WHEN** it is read
- **THEN** it has exactly three lines: `version=` with three numbers, `sha256=` with 64 lower-case hexadecimal digits, and `team=6W377FS7BS`
