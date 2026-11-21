## ADDED Requirements

### Requirement: Each proposition is found again in a revised manuscript

The command-line tool SHALL have a subcommand `propositions revise relocate --jsonl <ledger> --tex <main file> [--write]` that looks for the text of each proposition of the ledger that has no key `retired`, in every file of the main file's input tree (read by the rules of the capability `citation-order`, lines counted as the tool that writes `location` counts them). Without `--write` it writes nothing.

A text is first looked for as it is written. Where it stands nowhere, it is looked for with every run of white space, in the text and in the manuscript, read as one space, and the white space at its two ends left out. Each proposition SHALL come out in exactly one of these kinds:

| Kind | When |
| ---- | ---- |
| in place | its text stands at the lines its `location` names (`L5` and `main.tex:L5` are the same lines) |
| moved | its text, as written, stands elsewhere: in the file its `location` names, at the place nearest the line it names; or, when it does not stand in that file, at the one place in the manuscript it stands |
| rewrapped | its text stands only with other white space; the place is chosen as for moved |
| ambiguous | its text does not stand in the file its `location` names, and stands at two places or more elsewhere |
| missing | its text stands nowhere, with either reading |

A text that the ledger validator matches only after its normalisation (of math, macros or comments) is missing here. The command does not decide what to do with a missing proposition: retiring it is another operation.

The command SHALL print one line for each proposition that is moved (`moved <id>: <old> -> <new>`), rewrapped (`rewrapped <id>: <old> -> <new>`), ambiguous (`ambiguous <id>: <old>; its text stands at <place>, <place>`) or missing (`missing <id>: <old>`), in the order of the ledger, then the count of each kind. A new location is written `<file>:L<a>` or `<file>:L<a>-L<b>`, with `main.tex` for the main file, as the location refresh writes it.

With `--write` the command SHALL write again only the lines of the moved and rewrapped propositions: a new `location`, and for a rewrapped one a new `text` that is the manuscript's text at that place, line breaks included. Such a line is written as the Python tools write a ledger line (`json.dumps(…, ensure_ascii=False)`): a key written twice keeps its first place and its last value, and a number keeps the way it was written. Every other line keeps its bytes. The ledger is replaced as `propositions ledger-order` replaces it (the capability `ledger-order`).

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
- **THEN** it is the string `json.dumps(json.loads(line), ensure_ascii=False)` gives for it
