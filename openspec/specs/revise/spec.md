# revise Specification

## Purpose

TBD - created by archiving change 'idd-56-relocate'. Update Purpose after archive.

## Requirements

### Requirement: Each proposition is found again in a revised manuscript

The command-line tool SHALL have a subcommand `propositions revise relocate --jsonl <ledger> --tex <main file> [--write]` that looks for the text of each proposition of the ledger that has no key `retired`, in every file of the main file's input tree (read by the rules of the capability `citation-order`, lines counted as the tool that writes `location` counts them). Without `--write` it writes nothing.

A text is first looked for as it is written, Unicode scalar by scalar (a letter with an accent written as one scalar is not the letter followed by a combining accent). A place counts only when the text stands there whole and outside a `%` comment: not where its first or last character continues a word (`A is prime` does not stand in `A is primeval`), and not where any of it is commented out. Where it stands nowhere, it is looked for with every run of white space, in the text and in the manuscript, read as one space, and the white space at its two ends left out. Each proposition SHALL come out in exactly one of these kinds:

| Kind | When |
| ---- | ---- |
| in place | its text stands at the lines its `location` names (`L5` and `main.tex:L5` are the same lines) |
| moved | its text, as written, stands elsewhere: in the file its `location` names, at the one place nearest the line it names; or, when it does not stand in that file, at the one place in the manuscript it stands |
| rewrapped | its text stands only with other white space; the place is chosen as for moved |
| ambiguous | two places in the file its `location` names are equally near the line it names, or its text does not stand in that file and stands at two places or more elsewhere |
| missing | its text stands nowhere, with either reading |

A text that the ledger validator matches only after its normalisation (of math, macros or comments) is missing here. The command does not decide what to do with a missing proposition: retiring it is another operation.

The command SHALL print one line for each proposition that is moved (`moved <id>: <old> -> <new>`), rewrapped (`rewrapped <id>: <old> -> <new>`), ambiguous (`ambiguous <id>: <old>; its text stands at <place>, <place>`) or missing (`missing <id>: <old>`), in the order of the ledger, then the count of each kind. A new location is written `<file>:L<a>` or `<file>:L<a>-L<b>`, with `main.tex` for the main file, as the location refresh writes it.

With `--write` the command SHALL write again only the lines of the moved and rewrapped propositions: a new `location`, and for a rewrapped one a new `text` that is the manuscript's text at that place, line breaks included. Such a line is written as the Python tools write a ledger line (`json.dumps(…, ensure_ascii=False)`): a key written twice keeps its first place and its last value, and a number keeps the way it was written. Every other line keeps its bytes, a last line without a line feed included, and a line written again keeps the line ending it had. The ledger is replaced as `propositions ledger-order` replaces it (the capability `ledger-order`); as there, two programs that write the same ledger at the same moment are not kept apart. A location names the main file by `main.tex` or by no file at all, whatever the main file is called, as everywhere in this plugin.

It exits with 0 when every proposition is in place, or when `--write` wrote every one that was moved or rewrapped and none is ambiguous or missing; with 1 when a dry run would change something or a proposition is ambiguous or missing; with 2, and one line on standard error that starts with `error: `, when the ledger or a file of the manuscript cannot be read, a line is not JSON, a proposition has no text, or an argument is wrong. When it exits with 2 the ledger is as it was.

#### Scenario: A revision is read against the ledger

- **WHEN** the command runs on a ledger and the manuscript it was extracted from, after the manuscript was revised
- **THEN** it says for each proposition whether its text stands where the ledger says, elsewhere, with other line breaks, in several places, or nowhere

##### Example: each proposition is found in place, moved, rewrapped, ambiguous or missing

- **GIVEN** a main file that reads `sections/a`, and a ledger with: two propositions whose text stands at line 1 of the main file, one located `main.tex:L1` and one `L1`; one located at line 2 whose text now stands at line 4; one located at line 9 whose text now stands at line 1 of `sections/a`; one whose text stands at lines 5 and 6 with another line break; one located in the main file whose text stands twice in `sections/a`; one whose text stands nowhere; a retired proposition; and a comment line
- **WHEN** `propositions revise relocate` runs without `--write`
- **THEN** it prints `moved m: main.tex:L2 -> main.tex:L4`, `moved f: main.tex:L9 -> sections/a.tex:L1`, `rewrapped w: main.tex:L5 -> main.tex:L5-L6`, `ambiguous t: main.tex:L3; its text stands at sections/a.tex:L2, sections/a.tex:L3`, `missing x: main.tex:L7` and `2 in place, 2 moved, 1 rewrapped, 1 ambiguous, 1 missing`, exits with 1, and the ledger is unchanged

##### Example: only the moved and rewrapped lines are written again

- **GIVEN** the same ledger and manuscript
- **WHEN** the command runs with `--write`
- **THEN** the lines of the two moved propositions have their new `location`, the line of the rewrapped one its new `location` and the text with the manuscript's line break, every other line is as it was, the command prints `written: main.jsonl` and exits with 1, and a second dry run counts five in place, one ambiguous and one missing

##### Example: a line is written again as the Python tools write it

- **GIVEN** a ledger line with a quote, a backslash, a tab, control characters, a Unicode line separator, a delete character, characters outside ASCII, numbers and nested values; one with a key written twice; and an empty object
- **WHEN** it is written again
- **THEN** it is, byte for byte, the string `json.dumps(json.loads(line), ensure_ascii=False)` gives for it; a number that Python would write otherwise (`1.00`, `-0`, `1E2`) keeps the way it was written


<!-- @trace
source: idd-56-fix1
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/RelocateTests.swift
  - Sources/PropositionsKit/Revise.swift
  - Sources/PropositionsKit/ReviseLedger.swift
  - tests/PropositionsKitTests/ReviseLedgerTests.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - Sources/PropositionsKit/Relocate.swift
-->

---
### Requirement: A retirement records the propositions that replace it

The command-line tool SHALL have a subcommand `propositions revise retire --jsonl <ledger> --retire <id>[=<id>,<id>] … --since <YYYY-MM-DD> --reason <text> [--mechanism comment_env|line_comment|removed] [--match exact|by_reading] [--ref <text>] [--write]`. Each `--retire` names a live proposition and, after `=`, the ids of the live propositions that replace it, in order; the bare id says that the passage was deleted, and an empty id after `=` (`old=`, `old=b,,c`) is refused. Without `--write` it writes nothing.

Each named proposition SHALL get a `retired` block with `since`, `mechanism` (by default `removed`), `match` (by default `exact`), `reason`, `ref` when one is given, and `replaced_by`, the list of the replacing ids, empty for a deletion (schema v1.8). The block is the last key of the line when the line had none; the line is written again as `propositions revise relocate` writes a line, and every other line keeps its bytes. The Python ledger validator reads the block as a well-formed retirement.

The command SHALL refuse, with exit 2, one line on standard error that starts with `error: ` and nothing written, when: an id names no proposition or several lines; a proposition is already retired or named twice; a replacement does not name exactly one live proposition (it names none, a retired one, or the id of several lines), is the proposition itself, or is retired by the same run; a retirement already in the ledger names a proposition of this run in its `replaced_by`; `--since` is not a Gregorian calendar date, checked without a time zone; `--mechanism` or `--match` is not one of its values; or `--reason` is blank. It prints one line for each retirement, in the order of the ledger, and exits with 1 for a dry run and with 0 when it wrote the ledger.

#### Scenario: Retirements are written with what replaces them

- **WHEN** the command retires one proposition replaced by two others and one deleted proposition
- **THEN** each gets a `retired` block whose `replaced_by` lists its replacements, or is empty

##### Example: a retirement records what replaces it

- **GIVEN** a ledger of seven propositions, among them `old`, `b`, `c` and `gone2`
- **WHEN** `propositions revise retire --retire old=b,c --retire gone2 --since 2026-11-21 --reason "revised draft"` runs, then again with `--write`
- **THEN** the dry run prints `retire old: replaced by b, c` and `retire gone2: deleted, no replacement` and exits with 1; after writing, the line of `old` ends with `"retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "revised draft", "replaced_by": ["b", "c"]}`, the line of `gone2` with the same block and `"replaced_by": []`, the five other lines are as they were, and `propositions revise check` prints `1 replaced, 1 deleted, 0 without replaced_by, 0 problem(s)`


<!-- @trace
source: idd-56-fix1
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/RelocateTests.swift
  - Sources/PropositionsKit/Revise.swift
  - Sources/PropositionsKit/ReviseLedger.swift
  - tests/PropositionsKitTests/ReviseLedgerTests.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - Sources/PropositionsKit/Relocate.swift
-->

---
### Requirement: Every replaced_by names live propositions

`propositions revise check --jsonl <ledger>` SHALL report, one line each with the ledger line, every `replaced_by` that is not a list, and every item of one that is not an id, names no proposition of the ledger, names a retired one, names the id of several lines, or names the retired proposition itself. It then prints the number of retirements whose `replaced_by` names live propositions only, the number whose `replaced_by` is empty, the number without `replaced_by`, and the number of problems. It writes nothing. It exits with 0 when there is no problem, with 1 when there is one, and with 2 when the ledger cannot be read or a line is not JSON. A retirement without `replaced_by` is not a problem: it was made before schema v1.8, or by hand. This check is `ledger:replaced-by` of the obligations table.

#### Scenario: A replacement that is not live is reported

- **WHEN** a retirement's `replaced_by` names an id the ledger does not hold, or a retired proposition
- **THEN** the check reports it with its line and exits with 1

##### Example: a replaced_by that names no live proposition is reported

- **GIVEN** a ledger with a live proposition `a` and retirements `r1` replaced by `a`, `r2` replaced by `nobody` and `r1`, `r3` replaced by itself, `r4` whose `replaced_by` is a string, and `r5` without `replaced_by`
- **WHEN** the check runs
- **THEN** it prints `line 3: r2 is replaced by nobody, which is no proposition of the ledger`, `line 3: r2 is replaced by r1, which is retired`, `line 4: r3 is listed as its own replacement`, `line 5: the replaced_by of r4 is not a list` and `1 replaced, 0 deleted, 1 without replaced_by, 4 problem(s)`, and exits with 1


<!-- @trace
source: idd-56-fix1
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/RelocateTests.swift
  - Sources/PropositionsKit/Revise.swift
  - Sources/PropositionsKit/ReviseLedger.swift
  - tests/PropositionsKitTests/ReviseLedgerTests.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - Sources/PropositionsKit/Relocate.swift
-->

---
### Requirement: Citations of a retired proposition follow its replacements

`propositions revise redirect --jsonl <ledger> --tex <main file> [--write]` SHALL replace, in the `cites` of each live proposition, each id of a retired proposition by the ids in its `replaced_by`, in their order, leaving out: an id the list cites directly or already gained, the citing proposition itself, and, when the citing proposition has a place in the reading order (read by the rules of the capability `citation-order`), an id whose proposition has none or does not come before it. A cited retired proposition whose `replaced_by` is empty or absent is dropped. Every other citation is left as it is and where it is, a citation of a later live proposition included: that one is the citation-direction check's. The command SHALL refuse, with exit 2 and nothing written, a `replaced_by` of a cited retirement that is not a list of ids each naming exactly one live proposition, and a `cites` that holds a value that is not an id. Without `--write` it writes nothing.

It prints a line for each citation it drops (`drop <citing>: …`), each it redirects (`redirect <citing>: <retired> -> <id>, <id>`), and each retired citation none of whose replacements is added. A citing proposition whose `location` is not in the input tree keeps its redirected citations without the check of order, and a line on standard error says so. Only the lines whose `cites` change are written again, as `propositions revise relocate` writes a line. It exits with 0 when it wrote the ledger or there is nothing to change (and prints `nothing to change`), with 1 for a dry run that would change it, and with 2 when a file cannot be read, a line is not JSON, or an argument is wrong.

#### Scenario: A citation of a retired proposition is redirected

- **WHEN** a live proposition cites a retired one that is replaced
- **THEN** it cites the replacements that come before it instead

##### Example: the citations of a retired proposition follow its replacements

- **GIVEN** the ledger of the retirement example after writing, in which `c` (line 3 of the manuscript) cites `old` and `a`, `d` (line 4) cites `gone2` and `old`, and `e` (line 1) cites `old`, where `old` is replaced by `b` (line 2) and `c`
- **WHEN** `propositions revise redirect --write` runs
- **THEN** `c` cites `b` and `a`, `d` cites `b` and `c`, `e` cites nothing, the other lines are as they were, the command prints one line for each citation dropped or redirected and `written: main.jsonl`, exits with 0, and a second dry run prints `nothing to change`

<!-- @trace
source: idd-56-retire
updated: 2026-11-21
code:
  - plugins/propositions/docs/OBLIGATIONS.md
  - Sources/PropositionsKit/Relocate.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - tests/PropositionsKitTests/RelocateTests.swift
  - tests/PropositionsKitTests/ReviseLedgerTests.swift
  - plugins/propositions/catalog/obligations.yaml
  - plugins/propositions/skills/prop-ledger/SKILL.md
  - Sources/PropositionsKit/JSONValue.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/ReviseLedger.swift
  - plugins/propositions/templates/ledger/_meta.template.json
  - Sources/PropositionsKit/CLI.swift
  - Sources/PropositionsKit/Revise.swift
  - CLAUDE.md
  - docs/SCHEMA.md
tests:
  - tests/test_plugin_payload_tracked.py
-->

<!-- @trace
source: idd-56-fix1
updated: 2026-11-21
code:
  - propositions-projects.code-workspace
  - tests/PropositionsKitTests/RelocateTests.swift
  - Sources/PropositionsKit/Revise.swift
  - Sources/PropositionsKit/ReviseLedger.swift
  - tests/PropositionsKitTests/ReviseLedgerTests.swift
  - Sources/PropositionsKit/ReviseRun.swift
  - Sources/PropositionsKit/Relocate.swift
-->

---
### Requirement: A replacement may be a proposition of another ledger

A `replaced_by` item SHALL be either a string, an id of the same ledger, or an object with exactly the keys `ledger` and `id`, each a non-empty string, naming a live proposition of another ledger; `ledger` is a path relative to the directory of the ledger that holds the retirement, not absolute (schema v1.9). Ledgers written before v1.9 need no migration.

`propositions revise retire` SHALL take such a replacement written `<ledger>#<id>` after `=` (the last `#` splits the two), record it as that object, and refuse, with exit 2 and nothing written, one whose ledger cannot be read, whose id is not exactly one live line of that ledger, whose path is absolute or empty, or whose ledger is this ledger. `--ledger-dir <directory>` gives the directory the paths are relative to when `--jsonl` names a copy; without it they are relative to the ledger's own directory.

`propositions revise check` SHALL read each ledger an object names, once, and report as a problem an object whose ledger cannot be read, whose id is not exactly one live line of that ledger, or whose ledger is this ledger, and an item that is neither a string nor such an object. It takes `--ledger-dir` as `retire` does.

`propositions revise redirect` SHALL NOT carry a citation into another ledger: a citation of a retired proposition whose replacements are all in other ledgers is dropped, and the line that reports it names them; when some replacements are in this ledger, the citation follows those, and a line notes the others.

#### Scenario: A passage moved to another document

- **WHEN** a proposition is retired with a replacement in the supplement's ledger
- **THEN** the retirement records the ledger and the id, `check` finds the proposition there, and `redirect` does not cite it

##### Example: a retirement names a proposition of another ledger

- **GIVEN** the ledger of the retirement example, and `supp/supp.jsonl` holding the live proposition `s1`
- **WHEN** `revise retire --retire old=b,supp/supp.jsonl#s1 --write` runs, and then `revise check`
- **THEN** `retire` prints `retire old: replaced by b, supp/supp.jsonl#s1`, the line of `old` ends with `"replaced_by": ["b", {"ledger": "supp/supp.jsonl", "id": "s1"}]}}`, and `check` prints `1 replaced, 0 deleted, 0 without replaced_by, 0 problem(s)` and exits with 0

##### Example: a citation is not carried into another ledger

- **GIVEN** the same ledgers, `old` retired with the only replacement `supp/supp.jsonl#s1`, and `c` citing `old`
- **WHEN** `revise redirect` runs
- **THEN** it prints `drop c: old is replaced only in another ledger (supp/supp.jsonl#s1), which a citation cannot cross` and exits with 1

<!-- @trace
source: idd-133-cross-ledger-replacements
updated: 2026-11-23
code:
  - propositions-projects.code-workspace
-->