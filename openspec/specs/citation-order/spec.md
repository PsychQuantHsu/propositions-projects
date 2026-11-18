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

What the check agrees with is the tool that writes `location` (`refresh-prop-locations.py`): a line number in a ledger is the number that tool counted, and a file name is the name it wrote. A `location` that writes no file is in the main file, and so is one that writes `main.tex` or the main file's own name. `main.tex` means the main file whatever the main file is called, because that tool writes this prefix for every proposition of the main file; an included file that is itself called `main.tex`, beside a main file of another name, can therefore not be named by a location (a known limit). An included file is named by its path from the directory of the main file, with `..` where it leaves that directory. A `location` whose file begins with `/` is not written as the schema writes it.

The input tree is read by these rules: `\input` and `\include` written with braces, paths taken from the directory of the main file, `.tex` added when the name does not end in it, a file reached through a symbolic link counted as the file the link leads to. A line ends at a line feed, at a carriage return, or at the two together, and at no other character: a form feed does not end a line, as it does not for the tool that writes `location`. A command inside a `%` comment is ignored, and so is a command inside one of the environments `verbatim`, `Verbatim`, `lstlisting`, `comment` and `filecontents`, starred or not. Such an environment ends only at its own `\end`; a marker of one that is itself inside a comment begins nothing; a `%` inside one starts no comment; and what stands before or after one on the same line is read like any other text. The macros `\subimport`, `\subfile` and `\import` are not followed: the check goes on, and names each line that holds one on standard error (`[warn] non-standard import macro skipped at <file>:<line>`); an `\input` on the same line is still followed. An include of an absolute path, of a file that does not exist (an empty name included), a cyclic include and nesting deeper than three levels SHALL stop the check with an error.

The check reads only what these rules state. An `\input` inside a macro definition, inside a conditional or inside `\verb` is read as an include; when the file it names does not exist the check stops, although LaTeX would compile the manuscript. This is a known limit that the Python tools share (issue 94). Where those tools read the input tree less carefully than this check (issue 94 lists the cases), the check reads more files than they do; a file they leave out can hold no location they wrote, so no answer changes.

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
- **WHEN** positions are computed for `thesis.tex:L3`, for `L3` and for `main.tex:L3`
- **THEN** all three are line 3 of the main file

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


<!-- @trace
source: idd-46-fix2
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

An empty ledger line and a line that begins with `//` are skipped, as `docs/SCHEMA.md` has it. A ledger line that is not a JSON object, a proposition without a string `id`, a `cites` that is present and is not a list of strings (`null` included), and, for a proposition that is not retired, a `location` that is missing, is not written as the schema writes it (`[<file>.tex:]L<a>[-L<b>]`, with ASCII digits) or names a file the input tree does not hold, SHALL each be reported with the ledger line number, and SHALL NOT be guessed at. A retired proposition's `location` is not read. A proposition whose `cites` could not be read is still a proposition: it has no citation of its own that can be checked, and citations of it are checked. When anything was reported this way the check is incomplete: the command prints, after the count, a line that says so, and SHALL exit with 1. A ledger or a main file that does not exist and an input tree that cannot be read SHALL exit with 2, with the reason on standard error and nothing on standard output; a wrong argument SHALL exit with 2 as well.

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
source: idd-46-fix2
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The binary is published only by the maintainer

The repository SHALL hold a release script, `scripts/release-signed.sh`, that runs the package's tests, builds the `propositions` binary, signs it, submits it for notarization, and tags and publishes it only when the notarization result is `Accepted`. It is not run by a skill or by this change: publishing a signed binary is the maintainer's action. The repository SHALL NOT, in this version, hold a script that downloads the binary for a plugin, and no plugin directory holds a `bin/` directory: how a plugin obtains and verifies the binary is decided with the first release. Until a binary is released and a plugin uses it, no skill calls `propositions`, and the obligation `dependence.cites-backward` stays a gap owned by issue 46, which stays open until then.

The release script itself has no test: it acts on a release and on the maintainer's signing identity, which no test can supply. That no plugin directory holds a `bin/` directory is tested.

#### Scenario: No plugin ships an executable directory

- **WHEN** the plugin directories of the repository are listed
- **THEN** none of them holds a `bin/` directory

##### Example: no plugin ships an executable directory

- **GIVEN** the directories under `plugins/` of the repository
- **WHEN** each is looked into
- **THEN** none of them holds a `bin/` directory


<!-- @trace
source: idd-46-fix2
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The command states its interface

`propositions cite-order` SHALL take `--jsonl <path>` for the ledger and `--tex <path>` for the manuscript's main file, with the defaults `manuscript/propositions/main.jsonl` and `manuscript/main.tex`; a path that is not absolute is taken from the directory the command runs in, and a message shows a path as it was given. Without `--json` it prints one line for each item that could not be read (`UNREADABLE cite-order: …`), one line for each warning (`WARN cite-order: <id> (<location>) cites <id> (<location>), which comes later`), and then the count line; an id or a location is printed with its control and format characters written as escapes, so that text from a ledger cannot start a line of its own. With `--json` it SHALL print one JSON object with exactly the keys `checked` (a number), `forward` (a list of objects with the keys `from`, `fromLocation`, `to` and `toLocation`) and `unreadable` (a list of strings), and the exit codes are the same. Text that comes from a manuscript file is escaped the same way where a message on standard error quotes it. An argument the command does not know SHALL exit with 2, with the usage on standard error and nothing on standard output. `propositions --version` SHALL print the version of the package on standard output and exit with 0; the release script compares it with the version it was asked to release.

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

<!-- @trace
source: idd-46-fix2
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->