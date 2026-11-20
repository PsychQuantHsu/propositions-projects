# citation-order Specification

## Purpose

The citation-order check reports every citation that points to a proposition later in reading order, and is the first check of the repository's Swift package.

## Requirements

### Requirement: A Swift package holds the command-line tools

The repository SHALL have one Swift package at its root that declares a library `PropositionsKit`, an executable `propositions`, an executable `tschema-check` and a test target that uses Swift Testing, kept in `tests/PropositionsKitTests/` (the manifest spells out that path, because the repository already has a lower-case `tests/` directory). New mechanical checks are written in this package. The package is not inside a plugin directory and does not ship with a plugin. What each executable prints and the exit code it uses, the reading of its arguments included, SHALL be decided in `PropositionsKit`, so that it can be tested without starting a process; the executables only print the result and exit.

The `tschema-check` executable SHALL, in this version, validate nothing: with `--version` it prints the version and exits with 0; with no argument or `--help` it says that validation is still done by the Python script and exits with 0; with any other argument it says the same and exits with 2, so that a caller cannot take it for a validator that passed.

#### Scenario: The package builds

- **WHEN** `swift build` runs at the repository root
- **THEN** it produces the executables `propositions` and `tschema-check`

##### Example: tschema-check validates nothing yet

- **GIVEN** the `tschema-check` executable of this version
- **WHEN** it is run with the argument `notes.md`
- **THEN** it prints nothing to standard output, says on standard error that it validates nothing yet, and exits with 2


<!-- @trace
source: idd-46-fix2
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Reading order comes from each proposition's location and the input tree

The check SHALL take a proposition's position from the first line of its `location`, never from its line in the ledger. For a manuscript of several files, the text of an included file SHALL come after the line that includes it and before the next line of the including file, at every level of nesting; when one line holds several includes, the files they name come in the order the includes are written; a file included more than once counts where it is first included.

What the check agrees with is the tool that writes `location` (`refresh-prop-locations.py`): a line number in a ledger is the number that tool counted, and a file name is the name it wrote. A `location` that writes no file is in the main file, and so is one that writes `main.tex`. No other name means the main file: the main file's own name, when it is not `main.tex`, is a name that tool neither writes nor reads, and the check reports a location that writes it as naming a file the tree does not hold. `main.tex` means the main file whatever the main file is called, because that tool writes this prefix for every proposition of the main file; an included file that is itself called `main.tex`, beside a main file of another name, can therefore not be named by a location (a known limit). An included file is named by its path from the directory of the main file, with `..` where it leaves that directory. A `location` whose file begins with `/` names a file no tree holds.

The input tree is read by these rules: `\input` and `\include` written with braces, paths taken from the directory of the main file, `.tex` added when the name does not end in it, a file reached through a symbolic link counted as the file the link leads to. A line ends at a line feed, at a carriage return, or at the two together, and at no other character: a form feed does not end a line, as it does not for the tool that writes `location`. A command inside a `%` comment is ignored, and so is a command inside one of the environments `verbatim`, `Verbatim`, `lstlisting`, `comment` and `filecontents`, starred or not. Such an environment ends only at its own `\end`, and the starred form is another environment than the unstarred one; a marker of one that is itself inside a comment begins nothing; a `%` inside one starts no comment; and what stands before or after one on the same line is read like any other text. A command is read only where its backslash is not the second half of a `\\` before it: `\\input{x}` is a line break and the word "input", and includes nothing. The macros `\subimport`, `\subfile` and `\import`, starred or not, are not followed: the check goes on, and names each line that holds one on standard error with the line `[warn] non-standard import macro skipped at <file>:<line> (\subimport/\subfile/\import unsupported)`; an `\input` on the same line is still followed. An include of an absolute path, of a file that does not exist (an empty name included), a cyclic include and nesting deeper than three levels SHALL stop the check with an error.

The check reads only what these rules state. An `\input` inside a macro definition, inside a conditional or inside `\verb` is read as an include; when the file it names does not exist the check stops, although LaTeX would compile the manuscript. This is a known limit that the Python tools share (issue 94). More limits are known, and the list is closed: an include of a file that is not a `.tex` file (`\input{figures/plot.pgf}`) is looked for with `.tex` added and stops the check when that file does not exist; text that follows an `\input` on the same line is placed at that line, before the included file; an include whose braced name stands on the line after the command is not followed; and a marker of an environment written with white space before its brace (`\begin {comment}`) is not recognised. The Python tools read the input tree in their own way, and for some manuscripts their tree and this one differ (issue 94 lists the cases known). For such a manuscript the order this check uses is the order of its own tree. A location in a file this tree lacks is reported as unreadable and a file this tree cannot find stops the check; but where both trees hold a file at different places, the check answers by its own tree and prints nothing about the difference.

#### Scenario: Ledger order is not reading order

- **WHEN** the ledger lists a proposition at `L30` before a proposition at `L5`
- **THEN** the proposition at `L5` comes first in reading order

##### Example: an included file sits at the line that includes it

- **GIVEN** a main file whose line 10 is `\input{parts/a}` and a proposition `P1` at `parts/a.tex:L50`, a proposition `P2` at `L12` and a proposition `P3` at `L8`
- **WHEN** reading order is computed
- **THEN** the order is `P3`, `P1`, `P2`

##### Example: a commented include is not followed

- **GIVEN** a main file whose line 3 is `% \input{parts/gone}` and no file `parts/gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file only

##### Example: a missing include stops the check

- **GIVEN** a main file whose line 3 is `\input{parts/missing}` and no file `parts/missing.tex`
- **WHEN** the input tree is read
- **THEN** the check stops with an error that names `parts/missing.tex` and line 3

##### Example: two includes on one line keep their order

- **GIVEN** a main file whose line 1 is `\input{a}\input{b}`
- **WHEN** reading order is computed
- **THEN** line 50 of `a.tex` comes before line 1 of `b.tex`, and both come before line 2 of the main file

##### Example: an environment marker inside a comment changes nothing

- **GIVEN** a main file whose lines are `x`, `%\begin{comment}`, `\input{a}`, `%\end{comment}`, `y`, and a file `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex`

##### Example: lines are counted as the tool that writes locations counts them

- **GIVEN** a main file whose text is `one`, a form feed, `x`, a form feed, `two`, a line feed, `three`, a carriage return, `\input{a}`
- **WHEN** the input tree is read
- **THEN** the include is on line 3: the form feeds end no line, the line feed and the carriage return each end one

##### Example: the main file under another name

- **GIVEN** a main file `thesis.tex` whose line 10 is `\input{main}` and a file `main.tex` beside it
- **WHEN** positions are computed for `L3`, for `main.tex:L3` and for `thesis.tex:L3`
- **THEN** the first two are line 3 of the main file, and the third names a file the tree does not hold

##### Example: an environment ends only at its own end

- **GIVEN** a main file whose lines are `\begin{verbatim}`, `\end{comment}`, `\input{gone}`, `\end{verbatim}`, `\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file and `a.tex`

##### Example: an import macro that is not followed

- **GIVEN** a main file whose line 1 is `\subfile{x}\input{a}` and whose line 2 is `\import{dir/}{y}`, and a file `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex`, and lines 1 and 2 are named as holding a macro that was not followed

##### Example: a file reached through a symbolic link

- **GIVEN** a main file that includes `a` and then `b`, where `b.tex` is a symbolic link to `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex` only

##### Example: a starred environment ends at its starred end

- **GIVEN** a main file whose lines are `\begin{verbatim*}`, `\end{verbatim}`, `\input{gone}`, `\end{verbatim*}`, `\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file and `a.tex`

##### Example: a line break before the word input

- **GIVEN** a main file whose line 1 is `text\\input{gone}` and whose line 2 is `more\\\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** line 1 includes nothing, line 2 includes `a.tex`, and the check does not stop


<!-- @trace
source: idd-46-fix4
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A citation of a later proposition is reported as a warning

A proposition is retired when its ledger line has a well-formed `retired` block, as `docs/SCHEMA.md` defines it and the ledger validator checks it: an object whose `since` is a calendar date written `YYYY-MM-DD`, whose `mechanism` is `comment_env`, `line_comment` or `removed`, whose `match` is `exact` or `by_reading`, and whose `reason` is a string that is not blank. Any other `retired` value retires nothing: the proposition is checked like one without it. For every proposition that is not retired, and every id in its `cites` that names a proposition of the ledger that is not retired, the check SHALL report a warning when the cited proposition's position is later than the citing one's. Each proposition is judged from its own position. Two propositions at the same position are not reported. The check SHALL NOT read `claim_type`: a forward citation that is a roadmap or a promissory note is reported like any other, and the author judges it (recognising the two mechanically is open, issue 93). Warnings SHALL NOT make the command fail: with warnings only, the exit code is 0. A citation of an id the ledger does not hold is not this check's concern and is skipped. When an id is used by more than one proposition, which is another check's concern, a citation of that id is judged against the first of them in the ledger's line order that is not retired and whose position could be read.

#### Scenario: A backward citation passes

- **WHEN** the proposition at `L12` cites the proposition at `L5`
- **THEN** no warning is reported

##### Example: three citations

| Citing | Cited | Result |
|---|---|---|
| `L12`, a `claim` | `L30` | warning |
| `L3`, a `restatement` | `L30` | warning |
| `L12` | `L5` | no warning |

##### Example: a retired proposition is not checked

- **GIVEN** a retired proposition at `L3` that cites the proposition at `L30`
- **WHEN** the check runs
- **THEN** no warning is reported and the citation is not counted as checked

##### Example: warnings leave the exit code at 0

- **GIVEN** a ledger with one forward citation and no other problem
- **WHEN** `propositions cite-order` runs on it
- **THEN** it prints one `WARN cite-order:` line, a last line that says `1 forward citation(s) among 1 citation(s) checked`, and exits with 0

##### Example: a second proposition with an id already used

- **GIVEN** propositions with the id `A` at `L5` and at `L35`, the second citing `B`, and a proposition `B` at `L30` that cites `A`
- **WHEN** the check runs
- **THEN** no warning is reported: the second `A` is judged from `L35`, and the citation of `A` against the first `A`, at `L5`

##### Example: a retired block that is not well formed

- **GIVEN** a proposition at `L3` whose `retired` is `true`, or an object without `since`, and which cites the proposition at `L30`
- **WHEN** the check runs
- **THEN** the citation is checked and reported as a warning


<!-- @trace
source: idd-46-fix2
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The check says what it could not read

An empty ledger line and a line that begins with `//` are skipped, as `docs/SCHEMA.md` has it. A ledger line that is not a JSON object, a proposition without a string `id`, a `cites` that is present and is not a list of strings (`null` included), and, for a proposition that is not retired, a `location` that is missing, is not written as the schema writes it (`[<file>.tex:]L<a>[-L<b>]`, read as `parse_location_v16` of the Python tools reads it) or names a file the input tree does not hold, SHALL each be reported with the ledger line number, and SHALL NOT be guessed at. A retired proposition's `location` is not read. A proposition whose `cites` could not be read is still a proposition: it has no citation of its own that can be checked, and citations of it are checked. When anything was reported this way the check is incomplete: the command prints, after the count, a line that says so, and SHALL exit with 1. A ledger or a main file that does not exist and an input tree that cannot be read SHALL exit with 2, with the reason on standard error and nothing on standard output; a wrong argument SHALL exit with 2 as well.

#### Scenario: A ledger that does not exist

- **WHEN** `propositions cite-order` is given a ledger path that names no file
- **THEN** it prints an error and exits with 2

##### Example: a location the schema does not allow

- **GIVEN** a ledger whose line 2 holds a proposition with `location` `main.tex:12`
- **WHEN** `propositions cite-order` runs on it
- **THEN** it reports line 2 as unreadable and exits with 1

##### Example: a file outside the input tree

- **GIVEN** a proposition with `location` `parts/b.tex:L4` and a main file that does not include `parts/b.tex`
- **WHEN** the check runs
- **THEN** it reports that proposition's ledger line as unreadable

##### Example: a ledger that does not exist

- **GIVEN** a ledger path that names no file
- **WHEN** `propositions cite-order` runs with it
- **THEN** it prints `cite-order: cannot read the ledger` and the path on standard error, nothing on standard output, and exits with 2

##### Example: cites that is not a list of strings

- **GIVEN** a ledger line for the proposition `A` whose `cites` is the string `B`
- **WHEN** the check runs
- **THEN** it reports that line as unreadable and checks no citation made by `A`, while a citation of `A` by another proposition is still checked

##### Example: a comment line in the ledger

- **GIVEN** a ledger whose first line is `// hand-written note`, followed by two propositions
- **WHEN** the check runs
- **THEN** nothing is reported as unreadable


<!-- @trace
source: idd-46-fix4
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
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


<!-- @trace
source: idd-46-plugin-binary
updated: 2026-11-20
code:
  - plugins/propositions/.claude-plugin/plugin.json
  - docs/RELEASE-FLOW.md
  - plugins/propositions/docs/OBLIGATIONS.md
  - plugins/propositions/hooks/hooks.json
  - .claude-plugin/marketplace.json
  - scripts/release-signed.sh
  - CLAUDE.md
  - plugins/propositions/hooks/fetch-cli.sh
  - plugins/propositions/hooks/cli.lock
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/FetchHookTests.swift
  - plugins/propositions/skills/propositions/SKILL.md
  - plugins/propositions/catalog/obligations.yaml
tests:
  - tests/test_plugin_payload_tracked.py
-->

---
### Requirement: The command states its interface

`propositions cite-order` SHALL take `--jsonl <path>` for the ledger and `--tex <path>` for the manuscript's main file, with the defaults `manuscript/propositions/main.jsonl` and `manuscript/main.tex`; a path that is not absolute is taken from the directory the command runs in, and a message shows a path as it was given. Without `--json` it prints one line for each item that could not be read (`UNREADABLE cite-order: …`), one line for each warning (`WARN cite-order: <id> (<location>) cites <id> (<location>), which comes later`), and then the count line; an id or a location is printed with its control and format characters written as escapes, so that text from a ledger cannot start a line of its own. With `--json` it SHALL print one JSON object with exactly the keys `checked` (a number), `forward` (a list of objects with the keys `from`, `fromLocation`, `to` and `toLocation`) and `unreadable` (a list of strings), and the exit codes are the same. Text that comes from a manuscript file is escaped the same way where a message on standard error quotes it. An argument the command does not know SHALL exit with 2, with the usage on standard error and nothing on standard output. `propositions` with no subcommand SHALL print its help, which names `cite-order`, on standard output and exit with 0. `propositions cite-order --help`, `propositions cite-order -h` and `propositions help cite-order` SHALL print the help of `cite-order`, which names its options and its exit codes, and exit with 0. `propositions --version` SHALL print the version of the package on standard output and exit with 0; the release script compares it with the version it was asked to release.

##### Example: the JSON object

- **GIVEN** a ledger with the proposition `A` at `L12` citing the proposition `B` at `L30`
- **WHEN** `propositions cite-order --json` runs on it
- **THEN** it prints `{"checked":1,"forward":[{"from":"A","fromLocation":"L12","to":"B","toLocation":"L30"}],"unreadable":[]}` and exits with 0

##### Example: the defaults of the two paths

- **GIVEN** a directory that holds `manuscript/propositions/main.jsonl` and `manuscript/main.tex`, and a directory that holds neither
- **WHEN** `propositions cite-order` runs with no option in each
- **THEN** in the first it checks that ledger against that main file, and in the second it says that it cannot read the ledger `manuscript/propositions/main.jsonl` and exits with 2

##### Example: a wrong argument

- **GIVEN** the argument `--bogus`
- **WHEN** `propositions cite-order --bogus` runs
- **THEN** it prints nothing on standard output, names `--bogus` on standard error and exits with 2

##### Example: the version

- **GIVEN** the package at version `0.1.0`
- **WHEN** `propositions --version` runs
- **THEN** it prints `0.1.0` on standard output and exits with 0

##### Example: the line for an import macro that is not followed

- **GIVEN** a main file whose line 1 is `\subfile{x}` and a ledger with nothing forward
- **WHEN** `propositions cite-order` runs on them
- **THEN** standard error holds the one line `[warn] non-standard import macro skipped at main.tex:1 (\subimport/\subfile/\import unsupported)` and the exit code is 0

##### Example: no subcommand

- **GIVEN** no argument
- **WHEN** `propositions` runs
- **THEN** it prints help that names `cite-order` on standard output, nothing on standard error, and exits with 0

##### Example: help for the subcommand

- **GIVEN** the arguments `cite-order --help`
- **WHEN** `propositions` runs with them
- **THEN** it prints help that names `--jsonl` and the exit codes on standard output, and exits with 0

<!-- @trace
source: idd-46-fix4
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
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

<!-- @trace
source: idd-46-fix1
updated: 2026-11-20
code:
  - docs/RELEASE-FLOW.md
  - plugins/propositions/hooks/hooks.json
  - CLAUDE.md
  - tests/PropositionsKitTests/FetchHookTests.swift
  - plugins/propositions/docs/OBLIGATIONS.md
  - plugins/propositions/hooks/fetch-cli.sh
  - plugins/propositions/hooks/run-cli.sh
  - plugins/propositions/skills/propositions/SKILL.md
  - propositions-projects.code-workspace
-->