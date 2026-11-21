# manuscript-audit Specification

## Purpose

TBD - created by archiving change 'idd-69-audits'. Update Purpose after archive.

## Requirements

### Requirement: The audits read the whole manuscript

The command-line tool SHALL have two subcommands, `propositions audit symbols` and `propositions audit citations`, each taking `--manuscript-root <directory>`, `--tex <main file>` (by default `main.tex` in that directory) and `--report-format md|json` (by default `md`). They write no file. They are the successors of `audit-symbols.py` and `audit-citations.py`, which were retired on 2026-11-21 and now only say so, name the command to run instead and exit with 2, at their place in the plugin and as the root `scripts/` entry points. `run-audit.sh` runs the two commands for R1 and R2: the binary named by `PROPOSITIONS_CLI`, else the plugin's launcher with the data directory named by `PROPOSITIONS_PLUGIN_DATA`, else `propositions` on `PATH`; with none of them it stops with exit 2 and says how to get the tool. When the launcher runs nothing (exit 3, the pinned binary is not there), `run-audit.sh` stops with exit 2 and names each pass that did not run with the launcher's reason. The skill `manuscript-audit` runs it through the launcher only, with an inherited `PROPOSITIONS_CLI` dropped, and reports such a run as not run.

Both SHALL read every file of the main file's input tree, by the rules of the capability `citation-order`, and no other `.tex` file. A file is read as UTF-8; a byte-order mark is kept as the character it is. Each file is read as one stream, as TeX reads it, so that a command and its arguments may run over several lines; every finding keeps the file and line where it stands. A comment (`%` up to the end of the line, where the `%` is not escaped) is not read, and the line end it swallows does not end a word: `\cite{Doble%` followed by `Hsu2020}` cites `DobleHsu2020`. The text of `\verb` (any delimiter that is not a letter or white space, a `{` included, up to the next one on the line), of `\lstinline` (after its options, with a delimiter or braces), of the environments `verbatim`, `Verbatim`, `BVerbatim`, `lstlisting`, `minted` (after their options and the language of `minted`), `comment` and `filecontents`, starred or not, and of the braced argument of `\url`, `\path`, `\nolinkurl` and `\href` (after its options; white space and a line end may stand before the brace) is not read as source: a command written there is an example, and a `%` there is not a comment. Such a text stands in the source as one character that is neither white space nor part of a command, a key or a path, so that what is around it is not joined. White space and a comment may stand between `\begin` and its brace. A `comment` environment ends only at an `\end{comment}` that begins its line; the others end at their own `\end`, wherever it stands.

A report names each file by the manuscript directory as it was given, followed by the path from it; a file outside that directory is named by its full path. Both formats SHALL list the files that were read: the JSON report under the key `files`, after `total`; the Markdown report in a line `Files read: ` after its title. Otherwise the reports keep the layout of the Python tools: in JSON the keys `rule`, `tool`, `version`, `severity_counts` (with `definite`, `likely`, `suspicious` and `FYI`), `total` and `findings`, each finding with `rule`, `severity`, `file`, `line`, `match`, `context` and `proposed_fix`; in Markdown one section `## Definite (<n>)`, `## Likely (<n>)`, `## Suspicious (<n>)` or `## Fyi (<n>)` for each severity that has findings, which is what `run-audit.sh` reads. In the Markdown report a line of the manuscript's context that starts with `#` is written after a space, and the fence around the context is longer than any run of backticks in it, so that no line of the manuscript reads as a heading of the report or closes the fence.

An audit exits with 0 when it finds nothing, with 1 when it finds at least one thing of any severity, and with 2, with one line on standard error that starts with `error: ` (after the warnings the audit had printed before it), when the main file or a file of the tree cannot be read, the tree cannot be resolved, a declared bibliography file cannot be read, or an argument is wrong.

#### Scenario: A manuscript of several files is audited

- **WHEN** an audit runs on a manuscript whose main file reads other files
- **THEN** it reads each of them, reports a finding with the file and line where it is, and lists the files it read

##### Example: every file of the input tree is read

- **GIVEN** a main file that reads `sections/a` and `sections/b`; `sections/a` names `analysis/a.py` in `\texttt` on its line 2; `sections/b` names `analysis/commented.py` in a comment; and a file `sections/unused` that no file reads, which names `analysis/unused.py`
- **WHEN** `propositions audit symbols --manuscript-root manuscript --report-format json` runs
- **THEN** it exits with 1, its `files` are `manuscript/main.tex`, `manuscript/sections/a.tex` and `manuscript/sections/b.tex`, and its one finding is at `manuscript/sections/a.tex`, line 2


<!-- @trace
source: retire-python-ports-fix1
updated: 2026-11-21
code:
  - plugins/propositions/scripts/run-audit.sh
  - plugins/propositions/skills/construct-batch/SKILL.md
  - plugins/propositions/rules/manuscript-consistency-audit.md
  - propositions-projects.code-workspace
  - plugins/propositions/skills/manuscript-audit/SKILL.md
  - plugins/propositions/README.md
-->

---
### Requirement: The symbols audit finds a working file wherever the manuscript shows a path

`propositions audit symbols` (rule R1) SHALL report each path that ends in `.py`, `.md`, `.tex`, `.sh`, `.rs`, `.swift`, `.R` or `.jl` and that the manuscript shows to its reader: in the text of `\url`, `\path`, `\nolinkurl`, the address of `\href`, `\verb`, `\lstinline`, the body of `verbatim`, `Verbatim`, `BVerbatim`, `lstlisting` and `minted`, and running text, `\texttt` and other formatted text included. Running text is read as it is printed: a command's name is not printed; `\_`, `\%`, `\&`, `\#`, `\$`, `\{` and `\}` are their character; `\ `, `\\` and `~` are a space; a brace that only groups prints nothing, so that `\texttt{analysis/{run}.py}` shows `analysis/run.py`. The body of `comment` and `filecontents` is not printed and is not read. The arguments of the commands that name a file, a package or a label for LaTeX (`\input`, `\include`, `\includegraphics`, `\bibliography`, `\addbibresource`, `\label`, `\ref` and its kin, `\usepackage`, `\documentclass` and the others the implementation lists, each with the number of arguments it takes, a `*` after white space allowed), also where they stand inside formatted text, and the keys of every citation command, are not shown text and are not read; the arguments after those, such as the text of `\hyperref[label]{text}`, and the notes of a citation, are. A path's body has no white space but one parenthesised group after a space (`note (Hsu 2024-02).tex`, which may run over two lines), and no colon, so the path of an address is read from its `//`. A `%` may stand in a path, as in a percent-encoded address. The extension ends the path: `report.py.pdf`, `tools.py/README` and `run.py~` are not reported as paths that end in `.py`. Findings are listed in the order they stand in each file.

A file name that ends in `.bib`, and the names the manuscript declares as its bibliography, are not reported. The severity is as the Python tool had it: `definite` for a path under a directory `analysis/` that ends in `.py`, under a directory `manuscript/docs/` that ends in `.md` or `.tex` (`notanalysis/` is not `analysis/`), and a working note `note (…).tex`; `likely` for another `.tex` or `.sh`; `suspicious` otherwise.

#### Scenario: A working file named in the manuscript is reported

- **WHEN** the manuscript names a script or a working note to its reader
- **THEN** the audit reports it, with its severity

##### Example: a working file named in the manuscript is reported

- **GIVEN** a main file that names, in `\texttt`, `analysis/verify\_eta\_fs.py` on line 3, `manuscript/docs/gc\_iverson\_eta\_fs.md`, the note `note (Hsu 2024-02).tex` twice and `manuscript/docs/note-2024-02-audit.md`, and that has a label `main\_thm\_ess` in `\texttt` inside a citation
- **WHEN** the symbols audit runs
- **THEN** it exits with 1 and reports those five paths, in that order, each `definite` and of rule `R1`; the first in `manuscript/main.tex`, line 3; and nothing for the label

##### Example: a path is found wherever the manuscript shows it

- **GIVEN** a main file with `analysis/run.py` in `\url` and `scripts/build.sh` in `\path` on line 1; on line 2 an address in `\href` that ends in `analysis/fit.R`, `notes/draft.md` in `\verb` and `src/a.swift` in `\lstinline`; on line 3 `analysis/model.jl` in running text and `tools/x.rs` in `\texttt` after `50\%`; `analysis/clean.py` inside a `verbatim` environment on line 5; and `analysis/hidden.py` inside a `comment` environment
- **WHEN** the symbols audit runs
- **THEN** it reports, in this order, `analysis/run.py`, `scripts/build.sh`, `//example.org/analysis/fit.R`, `notes/draft.md`, `src/a.swift`, `analysis/model.jl`, `tools/x.rs` and `analysis/clean.py`, on lines 1, 1, 2, 2, 2, 3, 3 and 5, and nothing for `analysis/hidden.py`


<!-- @trace
source: idd-69-fix2
updated: 2026-11-21
code:
  - tests/PropositionsKitTests/AuditTests.swift
  - Sources/PropositionsKit/AuditCitations.swift
  - Sources/PropositionsKit/AuditSymbols.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/AuditRun.swift
  - Sources/PropositionsKit/AuditSource.swift
  - Sources/PropositionsKit/ReadingOrder.swift
-->

---
### Requirement: The citations audit reads the declared bibliography and every citation

`propositions audit citations` (rules R2 and R2-bis) SHALL read as the bibliography the files the manuscript declares with `\bibliography` (names separated by commas; `.bib` added when it is not there), `\addbibresource`, `\bibresource`, `\addglobalbib` and `\addsectionbib`, each found from the directory of the main file. A resource with the option `location=remote` (spaces and braces around `remote` allowed) is not read, and a line on standard error says so. Only when the manuscript declares no bibliography at all, local or remote, does the audit read `refs.bib` in the manuscript directory, if there is one. A file declared twice, or through a link to a file already read, is read once. Every entry `@<type>{<key>,` or `@<type>(<key>,` counts, whatever its type, except `@string`, `@comment` and `@preamble`; each is read as a whole, braces nesting and a quoted value read as one, so that an entry written inside the body of `@comment` or inside a field is not one. A key is followed by a comma or by the end of its record; an unused entry is reported at the line of its `@`. Lines of a bibliography file end at a line feed, a carriage return, or the two together.

A citation command is a command whose name has `cite` in it, in any case (`\cite`, `\citet`, `\parencite`, `\Textcite`, `\nocite` …), except `\citestyle`, `\citeindextrue`, `\citeindexfalse`, `\citeindextype`, `\citesetup`, `\citetext`, whose argument is text in which citations are read on their own, and the commands that define or configure one, whose names begin with `declare`, `def`, `new`, `renew`, `provide` or `set` in any case (`\defcitealias`, `\DeclareCiteCommand`). A key that holds `#` is the parameter of a definition and is not a key. A `*` may follow its name after white space. It may have up to two optional arguments in `[…]` before its keys in `{…}`, keys separated by commas; a `]` inside braces does not end an optional argument. A command whose name holds `volcite` takes an optional argument, a volume in braces, another optional argument and then its keys. A command whose name ends in `s` (`\cites`, `\parencites` …) may have up to two notes in `(…)` and then several groups of optional arguments and keys. A citation may run over several lines. `\nocite{*}` cites every entry; a `*` in another citation command is a key.

The audit SHALL report: as `R2`, `likely`, each citation that has `\texttt{<label>}` in an optional argument, or right after it with nothing else in parentheses, where the label is a word with at least one underscore, braces that only group are not part of it, and white space may stand between `\texttt` and its brace; as `R2-bis`, `definite`, each cited key with no entry, at its first citation in the manuscript's reading order (a citation on the line of an `\input` comes before the included file, wherever it stands on the line); as `R2-bis`, `FYI`, each entry no citation cites, at its line of the bibliography file, once for each time the entry is written.

#### Scenario: Citations and entries are compared

- **WHEN** the citations audit runs on a manuscript and its declared bibliography
- **THEN** it reports the keys without an entry and the entries nobody cites

##### Example: a label of another document in a citation is reported

- **GIVEN** a main file with `\citet[Theorem~\texttt{main\_thm\_ess}]{DobleHsu2020}` on line 1, `\citet{DobleHsu2020} (\texttt{main\_thm\_ess})` on line 2, and on line 3 `\citep[see][\texttt{exact\_var\_2}]{DobleHsu2020}` and `\citet[Theorem~3.1]{DobleHsu2020}`, with an entry for `DobleHsu2020`
- **WHEN** the citations audit runs
- **THEN** it reports three findings, each of rule `R2` and `likely`, on lines 1, 2 and 3

##### Example: the declared bibliography is read

- **GIVEN** a main file that cites `A`, `B` and `C`, declares `\bibliography{lit/main, extra}` and a remote resource; `lit/main.bib` with `A`, `extra.bib` with `B`, and `refs.bib` with `C`
- **WHEN** the citations audit runs
- **THEN** its `files` are the main file, `lit/main.bib` and `extra.bib`; its one finding is the key `C`; and standard error says that the remote bibliography is not read

##### Example: every entry type counts but the three directives

- **GIVEN** a bibliography with entries of the types `report`, `thesis`, `dataset`, `Software`, `software-release`, `MISC` written with parentheses, and `online` without fields; a `@string`, two `@comment` and a `@preamble` written as entries would be, one `@comment` holding an entry-shaped example; and a manuscript that cites the seven entries
- **WHEN** the citations audit runs
- **THEN** it reports nothing and exits with 0

##### Example: every key of a citation is read

- **GIVEN** a manuscript with `\cite[see][p.~3]{A}`, `\cites[a][b]{B}[c][]{C}`, `\parencites(pre)(post)[x]{D}{E}`, a `\textcite` whose keys `F` and `G` are on two lines, `\citestyle{authoryear}` and `\nocite{H}`, and a bibliography with `A` to `H`
- **WHEN** the citations audit runs
- **THEN** it reports nothing and exits with 0


<!-- @trace
source: idd-69-fix1
updated: 2026-11-21
code:
  - Sources/PropositionsKit/ReadingOrder.swift
  - Sources/PropositionsKit/AuditRun.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/AuditSource.swift
  - Sources/PropositionsKit/AuditSymbols.swift
  - Sources/PropositionsKit/AuditCitations.swift
  - tests/PropositionsKitTests/AuditTests.swift
-->

<!-- @trace
source: idd-69-fix2
updated: 2026-11-21
code:
  - tests/PropositionsKitTests/AuditTests.swift
  - Sources/PropositionsKit/AuditCitations.swift
  - Sources/PropositionsKit/AuditSymbols.swift
  - propositions-projects.code-workspace
  - Sources/PropositionsKit/AuditRun.swift
  - Sources/PropositionsKit/AuditSource.swift
  - Sources/PropositionsKit/ReadingOrder.swift
-->