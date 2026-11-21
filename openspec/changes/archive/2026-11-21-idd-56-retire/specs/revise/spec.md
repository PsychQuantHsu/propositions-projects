## ADDED Requirements

### Requirement: A retirement records the propositions that replace it

The command-line tool SHALL have a subcommand `propositions revise retire --jsonl <ledger> --retire <id>[=<id>,<id>] … --since <YYYY-MM-DD> --reason <text> [--mechanism comment_env|line_comment|removed] [--match exact|by_reading] [--ref <text>] [--write]`. Each `--retire` names a live proposition and, after `=`, the ids of the live propositions that replace it, in order; with none, the passage was deleted. Without `--write` it writes nothing.

Each named proposition SHALL get a `retired` block with `since`, `mechanism` (by default `removed`), `match` (by default `exact`), `reason`, `ref` when one is given, and `replaced_by`, the list of the replacing ids, empty for a deletion (schema v1.8). The block is the last key of the line when the line had none; the line is written again as `propositions revise relocate` writes a line, and every other line keeps its bytes. The Python ledger validator reads the block as a well-formed retirement.

The command SHALL refuse, with exit 2, one line on standard error that starts with `error: ` and nothing written, when: an id names no proposition or several lines; a proposition is already retired or named twice; a replacement names no proposition, is retired, is the proposition itself, or is retired by the same run; `--since` is not a calendar date; `--mechanism` or `--match` is not one of its values; or `--reason` is blank. It prints one line for each retirement, in the order of the ledger, and exits with 1 for a dry run and with 0 when it wrote the ledger.

#### Scenario: Retirements are written with what replaces them

- **WHEN** the command retires one proposition replaced by two others and one deleted proposition
- **THEN** each gets a `retired` block whose `replaced_by` lists its replacements, or is empty

##### Example: a retirement records what replaces it

- **GIVEN** a ledger of seven propositions, among them `old`, `b`, `c` and `gone2`
- **WHEN** `propositions revise retire --retire old=b,c --retire gone2 --since 2026-11-21 --reason "revised draft"` runs, then again with `--write`
- **THEN** the dry run prints `retire old: replaced by b, c` and `retire gone2: deleted, no replacement` and exits with 1; after writing, the line of `old` ends with `"retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "revised draft", "replaced_by": ["b", "c"]}`, the line of `gone2` with the same block and `"replaced_by": []`, the five other lines are as they were, and `propositions revise check` prints `1 replaced, 1 deleted, 0 without replaced_by, 0 problem(s)`

### Requirement: Every replaced_by names live propositions

`propositions revise check --jsonl <ledger>` SHALL report, one line each with the ledger line, every `replaced_by` that is not a list, and every item of one that is not an id, names no proposition of the ledger, names a retired one, or names the retired proposition itself. It then prints the number of retirements whose `replaced_by` names live propositions only, the number whose `replaced_by` is empty, the number without `replaced_by`, and the number of problems. It writes nothing. It exits with 0 when there is no problem, with 1 when there is one, and with 2 when the ledger cannot be read or a line is not JSON. A retirement without `replaced_by` is not a problem: it was made before schema v1.8, or by hand. This check is `ledger:replaced-by` of the obligations table.

#### Scenario: A replacement that is not live is reported

- **WHEN** a retirement's `replaced_by` names an id the ledger does not hold, or a retired proposition
- **THEN** the check reports it with its line and exits with 1

##### Example: a replaced_by that names no live proposition is reported

- **GIVEN** a ledger with a live proposition `a` and retirements `r1` replaced by `a`, `r2` replaced by `nobody` and `r1`, `r3` replaced by itself, `r4` whose `replaced_by` is a string, and `r5` without `replaced_by`
- **WHEN** the check runs
- **THEN** it prints `line 3: r2 is replaced by nobody, which is no proposition of the ledger`, `line 3: r2 is replaced by r1, which is retired`, `line 4: r3 is listed as its own replacement`, `line 5: the replaced_by of r4 is not a list` and `1 replaced, 0 deleted, 1 without replaced_by, 4 problem(s)`, and exits with 1

### Requirement: Citations of a retired proposition follow its replacements

`propositions revise redirect --jsonl <ledger> --tex <main file> [--write]` SHALL replace, in the `cites` of each live proposition, each id of a retired proposition by the ids in its `replaced_by`, in their order, leaving out an id the list already holds and an id whose proposition does not come before the citing one in reading order (read by the rules of the capability `citation-order`). A cited retired proposition whose `replaced_by` is empty or absent is dropped. Every other citation is left as it is, a citation of a later live proposition included: that one is the citation-direction check's. Without `--write` it writes nothing.

It prints a line for each citation it drops (`drop <citing>: …`) and each it redirects (`redirect <citing>: <retired> -> <id>, <id>`). A citing proposition whose `location` is not in the input tree keeps its redirected citations without the check of order, and a line on standard error says so. Only the lines whose `cites` change are written again, as `propositions revise relocate` writes a line. It exits with 0 when it wrote the ledger or there is nothing to change (and prints `nothing to change`), with 1 for a dry run that would change it, and with 2 when a file cannot be read, a line is not JSON, or an argument is wrong.

#### Scenario: A citation of a retired proposition is redirected

- **WHEN** a live proposition cites a retired one that is replaced
- **THEN** it cites the replacements that come before it instead

##### Example: the citations of a retired proposition follow its replacements

- **GIVEN** the ledger of the retirement example after writing, in which `c` (line 3 of the manuscript) cites `old` and `a`, `d` (line 4) cites `gone2` and `old`, and `e` (line 1) cites `old`, where `old` is replaced by `b` (line 2) and `c`
- **WHEN** `propositions revise redirect --write` runs
- **THEN** `c` cites `b` and `a`, `d` cites `b` and `c`, `e` cites nothing, the other lines are as they were, the command prints one line for each citation dropped or redirected and `written: main.jsonl`, exits with 0, and a second dry run prints `nothing to change`
