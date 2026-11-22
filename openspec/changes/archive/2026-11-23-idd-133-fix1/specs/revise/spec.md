## MODIFIED Requirements

### Requirement: A retirement records the propositions that replace it

The command-line tool SHALL have a subcommand `propositions revise retire --jsonl <ledger> --retire <id>[=<id>,<id>] … --since <YYYY-MM-DD> --reason <text> [--mechanism comment_env|line_comment|removed] [--match exact|by_reading] [--ref <text>] [--write]`. Each `--retire` names a live proposition and, after `=`, the ids of the live propositions that replace it, in order (a replacement in another ledger is written `<ledger>#<id>`, as the requirement on replacements in another ledger says); the bare id says that the passage was deleted, and an empty id after `=` (`old=`, `old=b,,c`) is refused. Without `--write` it writes nothing.

Each named proposition SHALL get a `retired` block with `since`, `mechanism` (by default `removed`), `match` (by default `exact`), `reason`, `ref` when one is given, and `replaced_by`, the list of the replacements (an id, or from schema v1.9 a `{"ledger", "id"}` object), empty for a deletion (schema v1.8). The block is the last key of the line when the line had none; the line is written again as `propositions revise relocate` writes a line, and every other line keeps its bytes. The Python ledger validator reads the block as a well-formed retirement.

The command SHALL refuse, with exit 2, one line on standard error that starts with `error: ` and nothing written, when: an id names no proposition or several lines; a proposition is already retired or named twice; a replacement does not name exactly one live proposition (it names none, a retired one, or the id of several lines), is the proposition itself, or is retired by the same run; a retirement already in the ledger names a proposition of this run in its `replaced_by`; `--since` is not a Gregorian calendar date, checked without a time zone; `--mechanism` or `--match` is not one of its values; or `--reason` is blank. It prints one line for each retirement, in the order of the ledger, and exits with 1 for a dry run and with 0 when it wrote the ledger.

#### Scenario: Retirements are written with what replaces them

- **WHEN** the command retires one proposition replaced by two others and one deleted proposition
- **THEN** each gets a `retired` block whose `replaced_by` lists its replacements, or is empty

##### Example: a retirement records what replaces it

- **GIVEN** a ledger of seven propositions, among them `old`, `b`, `c` and `gone2`
- **WHEN** `propositions revise retire --retire old=b,c --retire gone2 --since 2026-11-21 --reason "revised draft"` runs, then again with `--write`
- **THEN** the dry run prints `retire old: replaced by b, c` and `retire gone2: deleted, no replacement` and exits with 1; after writing, the line of `old` ends with `"retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "revised draft", "replaced_by": ["b", "c"]}`, the line of `gone2` with the same block and `"replaced_by": []`, the five other lines are as they were, and `propositions revise check` prints `1 replaced, 1 deleted, 0 without replaced_by, 0 problem(s)`

### Requirement: Every replaced_by names live propositions

`propositions revise check --jsonl <ledger>` SHALL report, one line each with the ledger line, every `replaced_by` that is not a list, and every item of one that is neither an id nor a `{"ledger", "id"}` object, that names no proposition of the ledger, names a retired one, names the id of several lines, or names the retired proposition itself; an object item is judged as the requirement on replacements in another ledger says. It then prints the number of retirements whose `replaced_by` names live propositions only, the number whose `replaced_by` is empty, the number without `replaced_by`, and the number of problems. It writes nothing. It exits with 0 when there is no problem, with 1 when there is one, and with 2 when the ledger cannot be read or a line is not JSON. A retirement without `replaced_by` is not a problem: it was made before schema v1.8, or by hand. This check is `ledger:replaced-by` of the obligations table.

#### Scenario: A replacement that is not live is reported

- **WHEN** a retirement's `replaced_by` names an id the ledger does not hold, or a retired proposition
- **THEN** the check reports it with its line and exits with 1

##### Example: a replaced_by that names no live proposition is reported

- **GIVEN** a ledger with a live proposition `a` and retirements `r1` replaced by `a`, `r2` replaced by `nobody` and `r1`, `r3` replaced by itself, `r4` whose `replaced_by` is a string, and `r5` without `replaced_by`
- **WHEN** the check runs
- **THEN** it prints `line 3: r2 is replaced by nobody, which is no proposition of the ledger`, `line 3: r2 is replaced by r1, which is retired`, `line 4: r3 is listed as its own replacement`, `line 5: the replaced_by of r4 is not a list` and `1 replaced, 0 deleted, 1 without replaced_by, 4 problem(s)`, and exits with 1

### Requirement: Citations of a retired proposition follow its replacements

`propositions revise redirect --jsonl <ledger> --tex <main file> [--write]` SHALL replace, in the `cites` of each live proposition, each id of a retired proposition by the ids of this ledger in its `replaced_by`, in their order, leaving out: an id the list cites directly or already gained, the citing proposition itself, and, when the citing proposition has a place in the reading order (read by the rules of the capability `citation-order`), an id whose proposition has none or does not come before it. A cited retired proposition whose `replaced_by` is empty or absent, or names propositions of other ledgers only, is dropped. Every other citation is left as it is and where it is, a citation of a later live proposition included: that one is the citation-direction check's. The command SHALL refuse, with exit 2 and nothing written, a `replaced_by` of a cited retirement that is not a list of items each naming exactly one live proposition (of this ledger, or of the ledger an object item names), and a `cites` that holds a value that is not an id. Without `--write` it writes nothing.

It prints a line for each citation it drops (`drop <citing>: …`), each it redirects (`redirect <citing>: <retired> -> <id>, <id>`), and each retired citation none of whose replacements is added. A citing proposition whose `location` is not in the input tree keeps its redirected citations without the check of order, and a line on standard error says so. Only the lines whose `cites` change are written again, as `propositions revise relocate` writes a line. It exits with 0 when it wrote the ledger or there is nothing to change (and prints `nothing to change`), with 1 for a dry run that would change it, and with 2 when a file cannot be read, a line is not JSON, or an argument is wrong.

#### Scenario: A citation of a retired proposition is redirected

- **WHEN** a live proposition cites a retired one that is replaced
- **THEN** it cites the replacements that come before it instead

##### Example: the citations of a retired proposition follow its replacements

- **GIVEN** the ledger of the retirement example after writing, in which `c` (line 3 of the manuscript) cites `old` and `a`, `d` (line 4) cites `gone2` and `old`, and `e` (line 1) cites `old`, where `old` is replaced by `b` (line 2) and `c`
- **WHEN** `propositions revise redirect --write` runs
- **THEN** `c` cites `b` and `a`, `d` cites `b` and `c`, `e` cites nothing, the other lines are as they were, the command prints one line for each citation dropped or redirected and `written: main.jsonl`, exits with 0, and a second dry run prints `nothing to change`

### Requirement: A replacement may be a proposition of another ledger

A `replaced_by` item SHALL be either a string, an id of the same ledger, or an object with exactly the keys `ledger` and `id`, each a non-empty string, naming a live proposition of another ledger; `ledger` is a path relative to the directory of the ledger that holds the retirement, not absolute (schema v1.9). Ledgers written before v1.9 need no migration.

`propositions revise retire` SHALL take such a replacement written `<ledger>#<id>` after `=` (the last `#` splits the two, so an id of this ledger that holds `#` cannot be named on the command line), record it as that object, and refuse, with exit 2 and nothing written, one whose ledger cannot be read, whose id is not exactly one live line of that ledger, whose path is absolute or empty, or whose ledger is this ledger: the same path, or the same file (device and inode, so a hard link counts). `--ledger-dir <directory>` gives the directory the paths are relative to when `--jsonl` names a copy that keeps the original's file name (a copy under another name is not recognised as this ledger); without it they are relative to the ledger's own directory.

`propositions revise check` SHALL read each ledger an object names, once, and report as a problem an object whose ledger cannot be read, whose id is not exactly one live line of that ledger, or whose ledger is this ledger, and an item that is neither a string nor such an object. It takes `--ledger-dir` as `retire` does.

`propositions revise redirect` SHALL NOT carry a citation into another ledger, and SHALL refuse, with exit 2, an object item of a cited retirement that `check` would report: a citation of a retired proposition whose replacements are all in other ledgers is dropped, and the line that reports it names them; when some replacements are in this ledger, the citation follows those, and a line notes the others.

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
