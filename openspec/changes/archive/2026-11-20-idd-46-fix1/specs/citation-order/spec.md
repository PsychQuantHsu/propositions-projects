## MODIFIED Requirements

### Requirement: A plugin session fetches the pinned binary and verifies it

The `propositions` plugin SHALL have, in its `hooks/` directory, a SessionStart hook `fetch-cli.sh`, a launcher `run-cli.sh`, and a lock file `cli.lock`. The lock file SHALL be exactly three lines, in this order: `version=` and three numbers separated by dots (the release), `sha256=` and 64 lower-case hexadecimal digits, `team=` and ten characters that are digits or upper-case letters (the signing team). A lock file of any other form, a repeated or extra line included, is unusable.

**What this guards against.** A downloaded file that is not the release the lock names, or that was altered on the way; and a skill running a binary of another version. It is no guard against a process that can already write in the user's home directory: such a process can change the skill itself.

**The hook.** The hook SHALL put the binary of the pinned release at `bin/propositions` under the plugin's data directory, the directory Claude Code names in `CLAUDE_PLUGIN_DATA`, and write nowhere else. It downloads over HTTPS from the release `propositions-cli-v<version>` of this repository, without reading the user's curl configuration, with a limit of 30 seconds and of 50 MB; the hook's entry in `hooks.json` has a timeout of 45 seconds. It SHALL install a downloaded file only when both hold: the file's SHA-256 is the one in the lock, and `codesign` verifies it against Apple's Developer ID requirement for the team in the lock.

When a regular file that can be executed and has the pinned SHA-256 is already there, the hook SHALL do nothing and print nothing. When anything else is at that path (a file of another version, a file that cannot be executed), the hook SHALL remove it before it downloads, so that a failed download or a failed check leaves nothing there. When it cannot remove what is there (a directory, for one), it SHALL say so and download nothing.

The hook SHALL do nothing at all, whatever is at that path left as it is, in these cases, which are all of them: the system is not macOS (the release is a macOS binary); `CLAUDE_PLUGIN_DATA` is not set; the last component of `CLAUDE_PLUGIN_DATA` is neither `propositions` nor a name that starts with `propositions-` (a shell can carry the data directory of another plugin, and the hook writes into no directory but its own); the lock file is unusable; `bin` under the data directory is a symbolic link. In the last two cases it prints one line that says which; in the first three it prints nothing.

The hook SHALL always exit with 0 and SHALL print at most one line, the messages of the tools it runs not shown: a session does not fail because the binary could not be fetched. It decides nothing about a ledger or an outline.

**The launcher.** `run-cli.sh <data directory> <subcommand> [arguments]` SHALL run `bin/propositions` under that data directory with the arguments it is given, and exit with what the binary exits with, only when all of these hold: the last component of the data directory is `propositions` or starts with `propositions-`; the lock file is usable; `bin` is not a symbolic link; the binary is a regular file, not a link, that can be executed; and its SHA-256 is the one in the lock. In every other case, a call without a subcommand included, it SHALL run nothing, print one line that starts with `propositions: NOT RUN (` and gives the reason, and exit with 3. The subcommands exit with 0, 1 or 2, so 3 means only that nothing ran. The launcher compares the hash each time it is called: what a session finds at its start is not what a later call relies on.

**The skill.** The skill for the mechanical gate (`/propositions:propositions`, Operation A) SHALL run `propositions cite-order` after the ledger validator, through the launcher and in no other way, with the data directory written as `${CLAUDE_PLUGIN_DATA}` in its text, which Claude Code replaces when it loads the skill (the Bash tool's environment does not hold this plugin's value). It SHALL report the citation direction as checked only when the command exits with 0, and as not checked for every other result. A warning from the command does not fail the operation. On a system or in a session without the pinned binary the citation direction is therefore not checked, and nothing else checks it.

Both scripts are tested with stand-ins for `curl`, `codesign` and `uname`; nothing is downloaded in a test. The lock file of the repository is tested for its form only: that it names a release that exists, and that release's hash, is checked by the maintainer when the lock is changed (`docs/RELEASE-FLOW.md`). Of the skill, a test checks that its text holds the one call through the launcher and no path to the binary; what a model does with that text has no test.

#### Scenario: A session on macOS gets the pinned binary

- **WHEN** a session starts with the plugin enabled, on macOS, and no binary is in the plugin's data directory
- **THEN** the hook downloads the release the lock names and installs it only if its SHA-256 and its Developer ID signature are the ones the lock asks for

#### Scenario: A binary of another version is never run

- **WHEN** the binary in the data directory is not the one the lock names, and a skill calls the launcher
- **THEN** the launcher runs nothing and exits with 3, and the skill reports the check as not run

##### Example: the hook installs the binary that has the pinned hash and team

- **GIVEN** a lock file with version `9.9.9`, the SHA-256 of a stand-in file and a team, and stand-ins that serve that file and accept that team
- **WHEN** the hook runs with a data directory named `propositions-test`
- **THEN** it downloads from the release `propositions-cli-v9.9.9`, the file is at `bin/propositions` under the data directory and can be executed, the hook prints the one line that it installed version 9.9.9, exits with 0, and leaves no other file in the data directory

##### Example: the hook is silent when the pinned binary is already there

- **GIVEN** the same lock file, and the stand-in file already at `bin/propositions`, executable
- **WHEN** the hook runs
- **THEN** it prints nothing, runs no download, and exits with 0

##### Example: the hook replaces what is not the pinned binary

- **GIVEN** the same lock file, and at `bin/propositions` either a file with other content, or the stand-in file without permission to execute
- **WHEN** the hook runs
- **THEN** it downloads, and the stand-in file is at `bin/propositions` and can be executed

##### Example: a failed check leaves no binary

- **GIVEN** the same lock file and a file of another version at `bin/propositions`
- **WHEN** the hook runs and one of these holds:

| What fails | The hook's line names |
| ---------- | --------------------- |
| the downloaded file has another SHA-256 | the pinned SHA-256 |
| the downloaded file is empty | the pinned SHA-256 |
| the signature is of another team | the Developer ID signature of the pinned team |
| `codesign` does not verify the signature | the Developer ID signature of the pinned team |
| the download fails | the download |

- **THEN** nothing is at `bin/propositions`, no other file is left in the data directory, the hook prints one line, and exits with 0

##### Example: the hook does nothing outside its own data directory

- **GIVEN** the same lock file, and a file of another version at `bin/propositions`
- **WHEN** the hook runs on a system whose `uname` prints `Linux`, or with a data directory called `codex-openai-codex` or `my-propositions`
- **THEN** it prints nothing, runs no download, leaves that file as it is, writes nothing, and exits with 0

##### Example: the hook writes through no link and into no directory

- **GIVEN** the same lock file, and `bin` under the data directory a symbolic link to another directory
- **WHEN** the hook runs
- **THEN** it says that the directory is a link, runs no download, and nothing is written in the directory the link names

##### Example: an unusable lock file fetches nothing

- **GIVEN** a lock file in which one thing is wrong:

| What is wrong | The hook's line names |
| ------------- | --------------------- |
| `version=1.0;rm` | `version` |
| `version=1.0` | `version` |
| `version=1..0` | `version` |
| `version=1.0.0.0` | `version` |
| `sha256=abc` | `sha256` |
| `sha256=` and 64 hexadecimal digits in upper case | `sha256` |
| `team=` and nothing | `team` |
| `team=short` | `team` |
| two `version=` lines | the form |
| a fourth line | the form |
| the `sha256=` line first | `version` |

- **WHEN** the hook runs
- **THEN** it prints one line that says the lock has no usable part of that name, runs no download, installs nothing, and exits with 0

##### Example: the repository's lock file has the three fields

- **GIVEN** `plugins/propositions/hooks/cli.lock` of the repository
- **WHEN** it is read
- **THEN** it has exactly three lines: `version=` with three numbers, `sha256=` with 64 lower-case hexadecimal digits, and `team=6W377FS7BS`

##### Example: the launcher runs the pinned binary with the arguments it is given

- **GIVEN** the lock file of the examples above and the stand-in file at `bin/propositions`, executable
- **WHEN** the launcher is called with the data directory and `cite-order --tex "a b.tex"`
- **THEN** the stand-in file runs with those three arguments, the third unchanged, and the launcher exits with 0

##### Example: the launcher runs nothing but the pinned binary

- **GIVEN** the same lock file
- **WHEN** the launcher is called with `cite-order` and `bin/propositions` is one of these:

| At `bin/propositions` | The launcher's line says |
| --------------------- | ------------------------ |
| nothing | the tool is not installed |
| an executable file with other content | the tool installed is not v9.9.9 |
| the stand-in file without permission to execute | the tool is not installed |
| a directory | the tool is not installed |

- **THEN** nothing runs, the launcher prints one line that starts with `propositions: NOT RUN (`, and exits with 3

##### Example: the skill calls the binary only through the launcher

- **GIVEN** the text of the skill `/propositions:propositions`
- **WHEN** it is read
- **THEN** it holds the line `bash "$PLUGIN_ROOT/hooks/run-cli.sh" "${CLAUDE_PLUGIN_DATA}" cite-order --jsonl "$JSONL" --tex "$TEX"`, and holds neither `bin/propositions` nor `.claude/plugins/data`
