## ADDED Requirements

### Requirement: A section can carry a length target, and a command reports lengths against targets and the limit

A section record MAY carry `length`, a whole number from 1 to 999999999: the target length of the section, in words, the sections under it included. `propositions outline check` SHALL report a `length` that is not such a number. `length` is part of the record: a change to it means the section no longer stands as approved.

`article.json` MAY carry `length`, an object with `limit`, a whole number from 1 to 999999999, and optionally `parts`, a list of one or more of `main`, `appendix`, `supplement`, each once; without `parts` the limit counts `main`. A file whose `length` is not in this format is not in the format of `article.json`.

A section goes to a part: its own `part`, else the part of the section it is under, else `main`.

Words are counted as follows, as an estimate: the text of a LaTeX comment, mathematics (`$…$`, `$$…$$`, `\(…\)`, `\[…\]` and the equation environments), command names, and the arguments of commands that take names (labels, references, citations, included files, environments) are not counted; in what remains, a run of letters and digits is one word, an apostrophe, a hyphen or a full stop between two of them does not end it, and each Chinese character, kana or hangul syllable is one word.

`propositions outline length <directory>` SHALL refuse (exit 2) an outline that does not pass `outline check`, and otherwise print, with tabs between the fields, and exit with 0 whatever the lengths are:

- one line for each section record that is not dropped, in file order: its id as JSON, its part, `target <n>` or `target -`; when its target is below the sum of the targets of the sections directly under it, `its subsections plan <sum>`;
- one line for each part a section goes to, `part <part>`, `targets <sum>`, where the sum takes each target that no section above it also carries;
- when `article.json` in the directory has `length`, one line `limit <n>`, the parts joined by commas, `targets <sum>` over those parts, followed by ` (over by <k>)` when the sum is above the limit;
- `ok length`.

With `--jsonl <ledger>` and `--tex <main file>` (which go together), it SHALL also count what was written: for each record of `outline-trace.jsonl` that names a paragraph record that is not dropped and exactly one live proposition of the ledger, the words of the paragraph that holds the start of that proposition (the run of lines without an empty line, a heading line not counted). Each section line then also holds `written <n>` and `<k> of <m> record(s)`, both with the sections under it included, and `over its target by <k>` when the words exceed the target; each part line holds `written <n>`; the limit line holds `written <n>`, followed by ` (over by <k>)` when above the limit. A trace record whose proposition is not found is not counted, and one line says how many there are. Without a trace file nothing is written yet.

#### Scenario: The plan and the text are both compared with the limit

- **WHEN** the targets of the sections add up to more than the limit, or the words written from a section exceed its target
- **THEN** the report marks the line and still exits with 0

##### Example: targets are reported against the limit before anything is written

- **GIVEN** an outline with sections `s-a` (`length` 300), `s-b` (`length` 500) with `s-b1` under it (`length` 600), and `s-x` (`part` `appendix`, `length` 200), and `article.json` with `{"length": {"limit": 700}}`
- **WHEN** `propositions outline length <directory>` runs
- **THEN** it prints `"s-a"	main	target 300`, `"s-b"	main	target 500	its subsections plan 600`, `"s-b1"	main	target 600`, `"s-x"	appendix	target 200`, `part main	targets 800`, `part appendix	targets 200`, `limit 700	main	targets 800 (over by 100)`, `ok length`, and exits with 0

##### Example: what was written is counted from the trace

- **GIVEN** the structure fixture, an outline of section `s-a` with `length` 5 and records `p-1` and `p-2`, and a trace that names `p-1` with the proposition that starts the fixture's last paragraph ("In addition, future studies could test whether the advantage lasts beyond one week.", 13 words)
- **WHEN** `propositions outline length <directory> --jsonl <ledger> --tex <main file>` runs
- **THEN** it prints `"s-a"	main	target 5	written 13	1 of 2 record(s)	over its target by 8`, `part main	targets 5	written 13`, `ok length`, and exits with 0

##### Example: how words are counted

- **GIVEN** the lines `The well-known effect ($d = 0.8$) isn't small~\cite{smith2020}. % not this`, `\begin{equation}` / `x = y + z` / `\end{equation}`, `\emph{Recall} was 0.62.` and `間隔複習有效`
- **WHEN** their words are counted
- **THEN** the counts are 5, 0, 3 and 6

##### Example: a length that is not in the format

- **GIVEN** a section record with `"length": 0`, with `"length": 1.5`, with `"length": "300"`; and an `article.json` with `{"length": {"limit": 0}}`, with `{"length": 700}`, and with `{"length": {"limit": 700, "parts": ["online"]}}`
- **WHEN** `propositions outline check` runs on each outline, and `propositions outline length` on a directory with each `article.json`
- **THEN** the check reports `length is not a whole number from 1 to 999999999` for each record, and `outline length` exits with 2 and names `article.json` for each file
