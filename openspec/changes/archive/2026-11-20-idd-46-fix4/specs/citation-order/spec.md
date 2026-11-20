## MODIFIED Requirements

### Requirement: A plugin session fetches the pinned binary and verifies it

The `propositions` plugin SHALL have, in its `hooks/` directory, a SessionStart hook `fetch-cli.sh`, a launcher `run-cli.sh`, and a lock file `cli.lock`. The lock file SHALL be exactly three lines, in this order: `version=` and three numbers separated by dots (the release), `sha256=` and 64 lower-case hexadecimal digits, `team=` and ten characters that are digits or upper-case letters (the signing team). A lock file of any other form is unusable: a repeated line, a fourth line (an empty one included), a NUL byte anywhere in the file, a file that is missing or cannot be read. A missing newline after the third line is accepted.

**What this guards against.** A downloaded file that is not the release the lock names, or that was altered on the way; and a skill running a binary of another pin, a session of another plugin version that starts in the meantime included. It is no guard against a process that can already write in the user's home directory: such a process can change the skill itself.

**The hook.** The hook SHALL put the binary of the pinned release at `bin/propositions-<sha256>` under the plugin's data directory, the directory Claude Code names in `CLAUDE_PLUGIN_DATA`, where `<sha256>` is the hash in the lock, and write nowhere else. Each pin so has a path of its own: the hook SHALL NOT remove or replace the binary of another pin, which a session of another plugin version may be using. Binaries of earlier pins therefore stay in the data directory until the user removes them. It downloads over HTTPS from the release `propositions-cli-v<version>` of this repository, without reading the user's curl configuration, and asks curl for a limit of 30 seconds and of 50 MB (a curl older than 8.4.0 does not hold the size limit for a response of unknown length; the time limit and the hash still apply); the hook's entry in `hooks.json` has a timeout of 45 seconds. It SHALL install a downloaded file only when both hold: the file's SHA-256 is the one in the lock, and `codesign` verifies it against Apple's Developer ID requirement for the team in the lock.

When a regular file that can be executed and has the pinned SHA-256 is already there, the hook SHALL do nothing and print nothing. When anything else is at that path (a file that was cut off or altered, a file that cannot be executed), the hook SHALL remove it before it downloads, so that a failed download or a failed check leaves nothing there. When it cannot remove what is there (a directory, for one), it SHALL say so and download nothing.

The hook SHALL do nothing at all, whatever is at that path left as it is, in these cases, which are all of them: the system is not macOS (the release is a macOS binary); `CLAUDE_PLUGIN_DATA` is not set; the last component of `CLAUDE_PLUGIN_DATA` is neither `propositions` nor a name that starts with `propositions-` (a shell can carry the data directory of another plugin; this is a check of the name, which keeps the hook out of the directories it has been seen to inherit, and not a proof that the directory is this plugin's); the lock file is unusable; `bin` under the data directory is a symbolic link. In the last two cases it prints one line that says which; in the first three it prints nothing.

The hook SHALL always exit with 0 and SHALL print at most one line, the messages of the tools it runs not shown: a session does not fail because the binary could not be fetched. It decides nothing about a ledger or an outline.

**The launcher.** `run-cli.sh <data directory> <subcommand> [arguments]` SHALL run `bin/propositions-<sha256>` under that data directory, the path of the pin in the lock, with the arguments it is given, each passed on as it came, and exit with what the binary exits with, only when all of these hold: the last component of the data directory is `propositions` or starts with `propositions-`; the lock file is usable, by the same rule as for the hook, the `team` line included; `bin` is not a symbolic link; the binary is a regular file, not a link, that can be executed; and its SHA-256 is the one in the lock. In every other case, a call without a subcommand included, it SHALL run nothing, print one line that starts with `propositions: NOT RUN (` and gives the reason, and exit with 3. The subcommands exit with 0, 1 or 2, so 3 means only that nothing ran. One case falls outside this: when the file is there with the pinned hash and the system still cannot start it, the shell's own message is printed and the status is the shell's, 126 or 127; the skill reports every status but 0 as not checked. The launcher compares the hash each time it is called: what a session finds at its start is not what a later call relies on.

**The skill.** The skill for the mechanical gate (`/propositions:propositions`, Operation A) SHALL run `propositions cite-order` after the ledger validator, through the launcher and in no other way, with the data directory written as `${CLAUDE_PLUGIN_DATA}` in its text, which Claude Code replaces when it loads the skill (the Bash tool's environment does not hold this plugin's value). It writes the two paths as `--jsonl=` and `--tex=`, so that a path that starts with a hyphen is not read as an option. It SHALL report the citation direction as checked only when the command exits with 0, and as not checked for every other result. A warning from the command does not fail the operation. On a system or in a session without the pinned binary the citation direction is therefore not checked, and nothing else checks it.

Both scripts are tested under `/bin/bash` with stand-ins for `curl`, `codesign` and `uname`; nothing is downloaded in a test. The stand-in for `codesign` checks the arguments it is handed, the requirement character for character, and not a signature: that Apple's tool accepts the requirement and a release passes it is checked by hand when the lock is changed. No test starts two sessions at once: that sessions of two pins do not disturb each other rests on each pin having its own path. The lock file of the repository is tested for its form only: that it names a release that exists, and that release's hash, is checked by the maintainer when the lock is changed (`docs/RELEASE-FLOW.md`). Of the skill, a test checks that its text holds the one call through the launcher and no path to the binary; what a model does with that text has no test.

#### Scenario: A session on macOS gets the pinned binary

- **WHEN** a session starts with the plugin enabled, on macOS, and no binary is in the plugin's data directory
- **THEN** the hook downloads the release the lock names and installs it only if its SHA-256 and its Developer ID signature are the ones the lock asks for

#### Scenario: A binary of another version is never run

- **WHEN** no binary is at the path of the pin in the lock, or the file there has another hash, and a skill calls the launcher
- **THEN** the launcher runs nothing and exits with 3, and the skill reports the check as not run

##### Example: the hook installs the binary that has the pinned hash and team

- **GIVEN** a lock file with version `9.9.9`, the SHA-256 of a stand-in file and a team, and stand-ins that serve that file and accept that team
- **WHEN** the hook runs with a data directory named `propositions-test`
- **THEN** it runs one download, from the release `propositions-cli-v9.9.9`, with the options named above, redirects followed and no other option, hands `codesign` the file it downloaded and the requirement for the team in the lock, the file is at `bin/propositions-<sha256>` under the data directory and can be executed, the hook prints the one line that it installed version 9.9.9, exits with 0, and leaves no other file in the data directory

##### Example: the hook is silent when the pinned binary is already there

- **GIVEN** the same lock file, and the stand-in file already at the pinned path, executable
- **WHEN** the hook runs
- **THEN** it prints nothing, runs no download, and exits with 0

##### Example: the hook replaces what is not the pinned binary

- **GIVEN** the same lock file, and at the pinned path either a file with other content, or the stand-in file without permission to execute
- **WHEN** the hook runs
- **THEN** it downloads, and the stand-in file is at the pinned path and can be executed

##### Example: the hook leaves the binary of another pin alone

- **GIVEN** a lock file with another hash, a file at the path of the first pin, and a download that fails
- **WHEN** the hook runs
- **THEN** the file at the path of the first pin is as it was

##### Example: a failed check leaves no binary

- **GIVEN** the same lock file and a cut-off file at the pinned path
- **WHEN** the hook runs and one of these holds:

| What fails | The hook's line names |
| ---------- | --------------------- |
| the downloaded file has another SHA-256 | the pinned SHA-256 |
| the downloaded file is empty | the pinned SHA-256 |
| the signature is of another team | the Developer ID signature of the pinned team |
| `codesign` does not verify the signature | the Developer ID signature of the pinned team |
| the download fails | the download |

- **THEN** nothing is at the pinned path, no other file is left in the data directory, the hook prints one line, and exits with 0

##### Example: the hook does nothing outside its own data directory

- **GIVEN** the same lock file, and a cut-off file at the pinned path
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
| an empty fourth line | the form |
| a NUL byte after the third line | the form |
| a NUL byte inside the first line | the form |
| the `sha256=` line first | `version` |
| an empty file | `version` |
| no file | the form |
| a file that cannot be read (not tried when the tests run as root) | the form |

- **WHEN** the hook runs
- **THEN** it prints one line that says the lock has no usable part of that name, runs no download, installs nothing, and exits with 0

##### Example: the repository's lock file has the three fields

- **GIVEN** `plugins/propositions/hooks/cli.lock` of the repository
- **WHEN** it is read
- **THEN** it has exactly three lines, with or without a newline after the third: `version=` with three numbers, `sha256=` with 64 lower-case hexadecimal digits, and `team=6W377FS7BS`

##### Example: the launcher runs the pinned binary with the arguments it is given

- **GIVEN** the lock file of the examples above and the stand-in file at the pinned path, executable, set to exit with 0, 1 or 2
- **WHEN** the launcher is called with the data directory and `cite-order --tex "a b.tex"`
- **THEN** the stand-in file gets exactly three arguments, the third `a b.tex`, and the launcher exits with what the file exits with

##### Example: the launcher runs nothing but the pinned binary

- **GIVEN** the same lock file
- **WHEN** the launcher is called with `cite-order` and the pinned path is one of these:

| At the pinned path | The launcher's line says |
| ------------------ | ------------------------ |
| nothing | the tool is not installed |
| an executable file with other content | the file does not have the pinned SHA-256 |
| the stand-in file without permission to execute | the tool is not installed |
| a directory | the tool is not installed |
| a link to the stand-in file, executable | the tool is not installed |
| the stand-in file, executable, in a `bin` that is a link | the tool is not installed |

- **THEN** the file at the pinned path is not started, the launcher prints one line that starts with `propositions: NOT RUN (`, and exits with 3

##### Example: the skill calls the binary only through the launcher

- **GIVEN** the text of the skill `/propositions:propositions`
- **WHEN** it is read
- **THEN** it holds the line `bash "$PLUGIN_ROOT/hooks/run-cli.sh" "${CLAUDE_PLUGIN_DATA}" cite-order --jsonl="$JSONL" --tex="$TEX"` exactly once inside a code fence (of backticks or tildes, indented or not), no other line inside a code fence that names the launcher, `cite-order`, `CLAUDE_PLUGIN_DATA` or `bin/propositions` or that starts with `propositions`, and nowhere `.claude/plugins/data`; a text with a second call, with other spacing or by another path, is found by the same check

##### Example: the launcher runs nothing with an unusable lock

- **GIVEN** the stand-in file at the pinned path, executable, and a lock file that is unusable while its `sha256` line, where it has one, still names that file: each row of the table of unusable lock files above except the two with another `sha256` value
- **WHEN** the launcher is called with `cite-order`
- **THEN** nothing runs, the launcher prints one line that starts with `propositions: NOT RUN (` and names `cli.lock`, and exits with 3



<!-- @trace
source: idd-46-fix3
updated: 2026-11-20
code:
  - plugins/propositions/hooks/run-cli.sh
  - tests/PropositionsKitTests/FetchHookTests.swift
  - propositions-projects.code-workspace
  - plugins/propositions/hooks/fetch-cli.sh
-->
