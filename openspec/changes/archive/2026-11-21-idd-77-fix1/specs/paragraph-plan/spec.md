## MODIFIED Requirements

### Requirement: A command proposes a paragraph plan from the TeX source

The command-line tool SHALL have a subcommand `propositions paragraphs --jsonl <ledger> --tex <main file> [--structure <structure sidecar>]` that prints the `paragraphs` list of a structure sidecar, as JSON, and writes no file. It is the Swift port of `derive-paragraphs.py`.

Each maximal run of lines of one file that are not blank is one paragraph; a line is blank when it holds nothing but white space. The command takes the propositions of the ledger that have no key `retired`, in the ledger's order. Each belongs to the paragraph that holds the first line of its `location`. A proposition starts a paragraph when the proposition before it is in another paragraph, and, with `--structure`, when it is the `first_prop` of a section, so that no paragraph crosses a section. Paragraphs that hold no proposition are skipped. The paragraphs are numbered `p-1`, `p-2` and so on in the order they start, each with the id of its first proposition as `first_prop`. The order is the ledger's order: for a plan in reading order, the ledger is put in reading order first (the capability `ledger-order`).

The list is printed as Python's `json.dumps` prints it with one space of indentation and characters outside ASCII left as they are; an empty list is `[]`. The command exits with 0 when the list was printed. It exits with 2, prints nothing on standard output and one line on standard error that starts with `error: ` (after one line for each line of the manuscript that holds an import macro the input tree does not follow, when the tree was read), when the main file, the ledger or the structure sidecar is not a regular file that can be read as UTF-8, a line of the ledger that is neither empty nor a comment is not JSON as it stands (white space that JSON does not have, a no-break space for one, is not removed first), the structure sidecar is not a JSON object or its `sections` is a number, a truth value or `null`, a proposition has no id that is a string, a location is missing, cannot be parsed, names a file that is not in the input tree, or starts on a blank line or past the end of its file, or an argument is wrong.

#### Scenario: A plan is proposed from the blank lines of the manuscript

- **WHEN** the command runs on a ledger and its manuscript
- **THEN** it prints one paragraph for each run of non-blank lines that holds the start of a proposition

##### Example: blank lines separate paragraphs

- **GIVEN** a manuscript whose lines 1 and 2 are text, line 3 is empty, line 4 is text, line 5 holds spaces only, and lines 6 and 7 are text; and a ledger with propositions `a` to `e` at lines 1, 2, 4, 6 and 7
- **WHEN** the command runs, and then again with a structure sidecar whose sections start with `a` and with `e`
- **THEN** the first run prints three paragraphs, `p-1` with `a`, `p-2` with `c` and `p-3` with `d`, each on four lines indented by one and two spaces; the second prints four, starting with `a`, `c`, `d` and `e`

### Requirement: For a manuscript of one file the command answers as the Python tool does

For a manuscript whose locations all name the main file, the command SHALL print on standard output what `derive-paragraphs.py` prints and exit as it exits. These are the differences:

- A line of the ledger that starts with `//`: the Python tool refuses it as invalid JSON. The command passes over it, as the ledger's schema has it.
- Lines. The Python tool splits the manuscript and the ledger with `str.splitlines`, which also splits at a form feed, a vertical tab, the three separator controls, the next-line control and the Unicode line and paragraph separators. The command counts the manuscript's lines as the tool that writes `location` counts them (a line ends at a line feed, at a carriage return, or at the two together), and the ledger's lines at a line feed. For a file that holds one of the other characters unescaped the answers can differ.
- Inputs the Python tool ends on with a traceback and exit 1: a file that is not UTF-8 or cannot be read; a structure sidecar that is not an object, or whose `sections` is a number, a truth value or `null`; a `first_prop` that is a list or an object; a proposition without an id, when it starts a paragraph; JSON beyond what Python's parser takes. The command refuses with exit 2, except for the `first_prop`, which it passes over as it passes over any that is not a string, and the JSON it can read.
- A proposition without an id that starts no paragraph is not noticed by the Python tool. The command refuses it.
- `sections` that is an object or a string gives no section in both.
- An id that is not a string: the Python tool prints it as the JSON value it is. The command refuses.
- The command reads JSON strictly (`NaN` is refused), refuses a line number too large for a 64-bit integer, and reads decimal digits outside ASCII with its own table of Unicode digits.
- Options: the Python tool takes an abbreviation of an option, and a value that reads as a negative number after a space (`--jsonl -1`); the command needs the option in full, and `--jsonl=-1`. A value that starts with a hyphen otherwise is written with `=` for both.
- What the two write on standard error differs in wording.

The Python tool stays in the plugin, unchanged, until a released binary has this command and the skill that calls the tool is changed to call the command.

#### Scenario: A manuscript of one file gets the plan the Python tool gives

- **WHEN** the command and the Python tool are put to the same ledger, manuscript and structure sidecar of a manuscript of one file
- **THEN** they print the same on standard output and exit with the same status

##### Example: a manuscript of one file gets the plan the Python tool gives

- **GIVEN** each of these:

| Input |
| ----- |
| six propositions over four paragraphs, one location written with `main.tex:`, one a range |
| two propositions with paragraphs between them that hold none |
| a structure sidecar whose sections start inside a paragraph, with an entry that is not an object and a section without `first_prop` |
| a retired proposition, empty lines and a line that is a JSON array |
| a ledger that is not in reading order |
| an id with a quote, a backslash, a tab, a control character, a Unicode line separator and a delete character |
| a ledger with no proposition |
| a structure sidecar without sections |
| a manuscript whose lines end in a carriage return and a line feed |
| an `\input` of the main file, inside a test for the file, that leads to no file, with locations in the main file only |
| a row of the ledger that holds a no-break space only |
| a row of the ledger with a no-break space before its object |
| a section whose `first_prop` spells the letters of an id with a combining mark, where the id has the composed letter |
| `sections` that is an object |
| a location in another file |
| a location written from the root of the file system |
| a location on a blank line |
| a location past the end of the manuscript |
| a location that cannot be parsed |
| a proposition without a location |
| a line of the ledger that is not JSON |
| a structure sidecar that is not JSON |

- **WHEN** the command and `derive-paragraphs.py` run on it
- **THEN** standard output, byte for byte, and the exit status are the same for both

### Requirement: The command proposes a plan for a manuscript of several files

A location MAY name any file of the main file's input tree, read by the rules of the capability `citation-order`; a location that names no file, or names `main.tex`, names the main file. The tree is read only when a location names another file: a manuscript whose locations all name the main file is answered whatever its `\input` lines lead to, and a tree that cannot be read is refused with exit 2 only then. The lines of each file are grouped into paragraphs on their own: a paragraph does not run from one file into another, so a proposition in another file than the proposition before it always starts a paragraph, also when the text returns to a run of lines it had left. A location whose file is not in the tree (a file the main file does not read, a file that does not exist, a path from the root of the file system) SHALL be refused with exit 2.

The list holds `id` and `first_prop` only, as the structure sidecar's format has it; the file of a paragraph is the file in the location of its first proposition.

#### Scenario: A ledger of a manuscript of several files gets a plan

- **WHEN** the command runs on a ledger whose locations name files of the manuscript's input tree
- **THEN** it prints a paragraph plan and exits with 0

##### Example: a manuscript of several files gets a plan

- **GIVEN** a main file whose line 1 is text, line 2 reads `sections/a`, lines 3 and 4 are text, line 5 is empty and line 6 reads `sections/b`; `sections/a` with text on lines 1, 2 and 4; `sections/b` with text on lines 1 and 3; and a ledger with propositions, in this order, at main line 1, `sections/a` lines 1, 2 and 4, main lines 3 and 4, and `sections/b` lines 1 and 3
- **WHEN** the command runs
- **THEN** it prints six paragraphs and nothing else, `p-1` to `p-6`, each with `id` and `first_prop` only, which start with the propositions at main line 1, `sections/a` line 1, `sections/a` line 4, main line 3, `sections/b` line 1 and `sections/b` line 3

##### Example: a location outside the input tree is refused

- **GIVEN** the same manuscript, with a file `sections/unused` that the main file does not read, and a ledger whose second proposition is at one of these:

| Location | The message says |
| -------- | ---------------- |
| `sections/unused.tex:L1` | the file is not in the manuscript's input tree |
| `sections/none.tex:L1` | the file is not in the manuscript's input tree |
| `/abs/a.tex:L1` | the file is not in the manuscript's input tree |
| `/main.tex:L1` | the file is not in the manuscript's input tree |
| `/sections/a.tex:L1`, where the tree reads `sections/a.tex` | the file is not in the manuscript's input tree |
| `sections/a.tex:L3`, an empty line | the location is not inside a TeX paragraph |
| `sections/b.tex:L9`, past the end | the location is not inside a TeX paragraph |

- **WHEN** the command runs
- **THEN** it exits with 2, prints nothing on standard output and one line that starts with `error: ` on standard error

<!-- @trace
source: idd-77-paragraphs
updated: 2026-11-21
code:
  - CLAUDE.md
  - Sources/PropositionsKit/CLI.swift
  - tests/PropositionsKitTests/ParagraphsTests.swift
  - Sources/PropositionsKit/Paragraphs.swift
  - propositions-projects.code-workspace
-->
