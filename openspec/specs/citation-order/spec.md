# citation-order Specification

## Purpose

The citation-order check reports every citation that points to a proposition later in reading order, and is the first check of the repository's Swift package.

## Requirements

### Requirement: A Swift package holds the command-line tools

The repository SHALL have one Swift package at its root that declares a library `PropositionsKit`, an executable `propositions`, an executable `tschema-check` and a test target that uses Swift Testing. New mechanical checks are written in this package. The `tschema-check` executable SHALL, in this version, only report its version and say that validation is still done by the Python script; it validates nothing.

No executable check: building the package is the check, and every test of this capability runs through it.

#### Scenario: The package builds

- **WHEN** `swift build` runs at the repository root
- **THEN** it produces the executables `propositions` and `tschema-check`


<!-- @trace
source: idd-46-swift-package
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Reading order comes from each proposition's location and the input tree

The check SHALL take a proposition's position from the first line of its `location`, never from its line in the ledger. A `location` without a file, or with the file `main.tex`, is in the main file. For a manuscript of several files, the text of an included file SHALL come after the line that includes it and before the next line of the including file, at every level of nesting; a file included more than once counts where it is first included. The input tree is read with the rules the ledger validator uses: `\input` and `\include`, paths taken from the directory of the main file, `.tex` added when the name has no such ending, commands inside a `%` comment or a verbatim-like environment ignored. An include of an absolute path, of a file that does not exist, a cyclic include and nesting deeper than three levels SHALL stop the check with an error.

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


<!-- @trace
source: idd-46-swift-package
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A citation of a later proposition is reported as a warning

For every proposition that is not retired, and every id in its `cites` that names a proposition of the ledger that is not retired, the check SHALL report a warning when the cited proposition's position is later than the citing one's. Two propositions at the same position are not reported. The check SHALL NOT read `claim_type`: a forward citation that is a roadmap or a promissory note is reported like any other, and the author judges it. Warnings SHALL NOT make the command fail: with warnings only, the exit code is 0. A citation of an id the ledger does not hold is not this check's concern and is skipped.

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


<!-- @trace
source: idd-46-swift-package
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The check says what it could not read

A ledger line that is not a JSON object, a proposition without a string `id`, a `location` that is not written as the schema writes it, and a `location` that names a file the input tree does not hold SHALL each be reported with the ledger line number, and SHALL NOT be guessed at. When anything was reported this way the check is incomplete and the command SHALL exit with 1. A ledger or a main file that does not exist, an input tree that cannot be read and a wrong argument SHALL exit with 2.

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


<!-- @trace
source: idd-46-swift-package
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The binary is published only by the maintainer

The repository SHALL hold a wrapper script that downloads the released `propositions` binary for the plugin and a release script that builds, signs and notarizes it. Neither is run by a skill or by this change: publishing a signed binary is the maintainer's action. Until a binary is released, no skill calls `propositions`, and the obligation `dependence.cites-backward` stays a gap.

No executable check: the two scripts act on a release and on the maintainer's signing identity, which no test can supply.

#### Scenario: A wrapper without a released version

- **WHEN** the wrapper runs and the plugin manifest names no binary version
- **THEN** it stops with a message and downloads nothing

<!-- @trace
source: idd-46-swift-package
updated: 2026-11-19
code:
  - propositions-projects.code-workspace
-->