# ledger-order Specification

## Purpose

TBD - created by archiving change 'idd-59-ledger-order'. Update Purpose after archive.

## Requirements

### Requirement: A command puts a ledger's lines into reading order

The command-line tool SHALL have a subcommand `propositions ledger-order --jsonl <ledger> [--tex <main file>] [--write]` that says whether the lines of a ledger are in the manuscript's reading order and, with `--write`, puts them in it. Without `--write` it writes nothing.

A line of the ledger is an anchor when, with the white space around it removed, it is a JSON object that has no key `retired`. Every other line (a retired proposition, a line that starts with `//`, an empty line, a JSON value that is not an object) stays behind the anchor it followed; such lines before the first anchor stay at the head. Anchors are put in the order of where their `location` starts. Anchors that start at the same place keep the order they had, and the command reports each such place, because only a reader can tell whether that order is right. Lines are moved and never edited: each keeps its bytes, its line ending included; a last line without a line feed is given one. The count the command prints is the number of line positions that hold another line than before.

The command prints, in this order: one line for the places that hold several propositions, when there are any, with at most twenty of them; then `already in reading order`, or `<n> line(s) move`; then, after writing, `written: <the ledger as it was named>`. It exits with 0 when the ledger is in reading order or was written, with 1 for a dry run in which lines would move, and with 2, with one line on standard error that starts with `error: `, when the ledger or the main file cannot be read, a line that is neither empty nor a comment is not JSON, a location is missing or cannot be parsed or cannot be placed, or an argument is wrong. When it exits with 2 it has written nothing.

Writing replaces the ledger through a temporary file beside it, with the ledger's permissions, and leaves no other file.

#### Scenario: A ledger out of reading order is reported

- **WHEN** the command runs without `--write` on a ledger whose second proposition starts before its first
- **THEN** it prints how many lines move, exits with 1, and the ledger is unchanged

##### Example: a dry run changes nothing

- **GIVEN** a ledger with proposition `b` at `main.tex:L9` and then proposition `a` at `main.tex:L2`
- **WHEN** `propositions ledger-order --jsonl main.jsonl` runs
- **THEN** it prints `2 line(s) move`, exits with 1, and the ledger has the bytes it had

##### Example: writing moves whole lines and keeps the file's permissions

- **GIVEN** a ledger with permissions `640` and three lines: `b` at `L9`, written with two spaces before it and ending in a carriage return and a line feed; a retired proposition `r`; and `a` at `L2`, ending in a carriage return and a line feed
- **WHEN** the command runs with `--write`
- **THEN** it prints `3 line(s) move` and `written: main.jsonl`, exits with 0, the ledger holds the line of `a`, then the line of `b`, then the line of `r`, each with the bytes it had, its permissions are `640`, no other file is beside it, and a second dry run prints `already in reading order`


<!-- @trace
source: idd-59-ledger-order
updated: 2026-11-21
code:
  - Sources/PropositionsKit/CLI.swift
  - Sources/PropositionsKit/LedgerOrder.swift
  - propositions-projects.code-workspace
  - CLAUDE.md
  - tests/PropositionsKitTests/LedgerOrderTests.swift
-->

---
### Requirement: Without a main file the command orders as the Python tool does

Without `--tex`, the place of an anchor SHALL be the first line of its `location`, read as a line of the one file of the manuscript: a location that names no file, or names exactly `main.tex`. A location that names any other file SHALL be refused with exit 2 and a message that says to pass `--tex`. The places that hold several propositions are printed as the Python tool `reorder-ledger.py` prints them, `<n> TeX line(s) hold several propositions on the same line, check their order: [<line>, <line>]`.

For such a manuscript the command SHALL print on standard output what `reorder-ledger.py` prints, exit as it exits, and write the file it writes. These are the differences, all of them on input the Python tool mishandles or refuses:

- The Python tool reads and writes the ledger as text, so a ledger with carriage returns is written back without them. The command keeps every byte of a line.
- The Python tool splits a line at a form feed, a vertical tab, the three separator controls and the Unicode line and paragraph separators, when one stands unescaped in the ledger. The command splits at a line feed only.
- The Python tool ends with a traceback and exit 1 on a ledger that is not UTF-8. The command refuses it with exit 2.
- What the two write on standard error, when they refuse, differs in wording.
- The command reads JSON strictly: a line the Python tool accepts though it is not JSON by the standard (`NaN`, for one) is refused.

The Python tool stays in the plugin, unchanged, until a released binary has this command and the skill that calls the tool is changed to call the command; that change removes the Python tool.

#### Scenario: A manuscript of one file gets the answer the Python tool gives

- **WHEN** the command and the Python tool are put to the same ledger of a manuscript of one file
- **THEN** they print the same lines on standard output, exit with the same status and leave the same file

##### Example: a manuscript of one file is ordered as the Python tool orders it

- **GIVEN** each of these ledgers, once as a dry run and once with `--write`:

| Ledger |
| ------ |
| two propositions out of order |
| three in order, two of them on one line |
| four with two lines that each hold two, out of order |
| two out of order, with ranges, the last line without a line feed |
| a comment and an empty line at the head, a retired proposition with a comment and an empty line after it, a line that is a JSON array, a proposition whose `retired` is `null` |
| ids and text outside ASCII |
| lines with white space before and after |
| a proposition whose `location` is written twice |
| a location in another file |
| a location that cannot be parsed |
| a proposition without a location |
| a line that is not JSON |
| an empty ledger |
| a ledger of comments only |

- **WHEN** the command and `reorder-ledger.py` run on a copy each
- **THEN** standard output, the exit status and the bytes of the ledger afterwards are the same for both, and the command leaves no other file


<!-- @trace
source: idd-59-ledger-order
updated: 2026-11-21
code:
  - Sources/PropositionsKit/CLI.swift
  - Sources/PropositionsKit/LedgerOrder.swift
  - propositions-projects.code-workspace
  - CLAUDE.md
  - tests/PropositionsKitTests/LedgerOrderTests.swift
-->

---
### Requirement: With a main file the command orders a manuscript of several files

With `--tex`, the place of an anchor SHALL be the position of the first line of its `location` in the manuscript's reading order, read from the main file's input tree by the rules of the capability `citation-order` (the requirement "Reading order comes from each proposition's location and the input tree"): the lines of an included file come where the main file includes it. The order across files is therefore the order in which the main file's tree reads them, and not an order listed in the ledger's `_meta.json`: a list of files does not say at which line of the main file each is read, and the citation-direction check already uses the tree.

A location whose file is not in the tree SHALL be refused with exit 2. A tree that cannot be read (a missing file, a cycle, a tree too deep) SHALL be refused with exit 2. The places that hold several propositions are printed as `<n> place(s) hold several propositions on the same line, check their order: <file>:<line>, <file>:<line>`, in reading order, with `main.tex` for the main file.

#### Scenario: A ledger of a manuscript of several files can be checked

- **WHEN** the command runs with `--tex` on a ledger whose locations name files of the manuscript's input tree
- **THEN** it says whether the ledger's lines are in the manuscript's reading order

##### Example: a manuscript of several files is ordered through its input tree

- **GIVEN** a main file of five lines that reads `sections/a` at line 2 and `sections/b` at line 4, where `sections/a` reads `sections/deep` at its line 3, and a ledger with seven propositions in this order: main line 5, `sections/a` line 4, main line 1, `sections/b` line 2, `sections/deep` line 1, main line 3, `sections/a` line 1
- **WHEN** the command runs with `--tex main.tex`, then with `--write`
- **THEN** the dry run prints `7 line(s) move` and exits with 1; after writing, the ledger's propositions are in the order main 1, `sections/a` 1, `sections/deep` 1, `sections/a` 4, main 3, `sections/b` 2, main 5, and a further dry run prints `already in reading order`

##### Example: propositions that start on the same line of the same file are reported

- **GIVEN** the same manuscript, and a ledger with two propositions that start at line 2 of `sections/a`, one at line 2 of `sections/b`, and two at line 5 of the main file, one written `main.tex:L5` and one `L5`
- **WHEN** the command runs with `--tex main.tex`
- **THEN** it prints `2 place(s) hold several propositions on the same line, check their order: sections/a.tex:2, main.tex:5`, then `already in reading order`, and exits with 0

##### Example: what cannot be ordered is refused and nothing is written

- **GIVEN** the same manuscript and a ledger of two propositions
- **WHEN** the command runs with `--write` and one of these holds:

| What holds | The message says |
| ---------- | ---------------- |
| no `--tex`, and a location in `sections/a.tex` | the location names another file; pass `--tex` |
| a location in `sections/zz.tex`, which the tree does not read | the file is not in the input tree of `main.tex` |
| a location in a file written from the root of the file system | the file is not in the input tree |
| a main file that does not exist | the main file cannot be read |
| a ledger that does not exist | the ledger was not found |
| a directory where the ledger is named | the ledger was not found |

- **THEN** it exits with 2, prints nothing on standard output and one line that starts with `error: ` on standard error, the ledger has the bytes it had, and no other file is beside it

<!-- @trace
source: idd-59-ledger-order
updated: 2026-11-21
code:
  - Sources/PropositionsKit/CLI.swift
  - Sources/PropositionsKit/LedgerOrder.swift
  - propositions-projects.code-workspace
  - CLAUDE.md
  - tests/PropositionsKitTests/LedgerOrderTests.swift
-->