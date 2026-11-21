## MODIFIED Requirements

### Requirement: For a manuscript of one file the command answers as the Python tool does

For a manuscript whose locations all name the main file, the command, when it is asked for a plan, SHALL print on standard output what `derive-paragraphs.py` printed and exit as it exited, as recorded from it on 2026-11-21 (`tests/fixtures/retired-python/derive-paragraphs/`); the two printed their own text for `--help`. These are the differences:

- A line of the ledger that starts with `//`: the Python tool refuses it as invalid JSON. The command passes over it, as the ledger's schema has it.
- Lines. The Python tool splits the manuscript and the ledger with `str.splitlines`, which also splits at a form feed, a vertical tab, the three separator controls, the next-line control and the Unicode line and paragraph separators. The command counts the manuscript's lines as the tool that writes `location` counts them (a line ends at a line feed, at a carriage return, or at the two together), and the ledger's lines at a line feed, with a carriage return before it dropped; a carriage return alone, which ends a row for the Python tool, does not end one for the command. For a file that holds one of the other characters unescaped the answers can differ.
- Inputs the Python tool ends on with a traceback and exit 1: a file that is not UTF-8 or cannot be read; a structure sidecar that is not an object, or whose `sections` is a number, a truth value or `null`; a `first_prop` that is a list or an object; a proposition without an id, when it starts a paragraph; JSON beyond what Python's parser takes. The command refuses with exit 2, except for the `first_prop`, which it passes over as it passes over any that is not a string, and the JSON it can read.
- A proposition without an id that starts no paragraph is not noticed by the Python tool. The command refuses it.
- `sections` that is an object or a string gives no section in both.
- An id that is not a string: the Python tool prints it as the JSON value it is when the proposition starts a paragraph, and ends with a traceback when the id is a list or an object and the proposition does not. The command refuses.
- The command reads JSON strictly (`NaN` is refused), refuses a line number too large for a 64-bit integer, and reads decimal digits outside ASCII with its own table of Unicode digits.
- Options: the Python tool takes an abbreviation of an option, and a value that reads as a negative number after a space (`--jsonl -1`); the command needs the option in full, and `--jsonl=-1`. A value that starts with a hyphen otherwise is written with `=` for both.
- What the two write on standard error differs in wording.

The Python tool was retired on 2026-11-21, when the skill that called it was changed to call this command: `derive-paragraphs.py` now only says that it was retired and what to run instead, and exits with 2. The migration of version 1.0 sidecars keeps its own copy of the derivation.

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
| a section whose `first_prop` spells the letters of an id with a combining mark, where the id has the composed letter and is the second proposition of its paragraph |
| `sections` that is an object |
| a ledger that starts with a byte-order mark |
| a structure sidecar that starts with a byte-order mark |
| a location written `./main.tex:L1` |
| a location in another file |
| a location written from the root of the file system |
| a location on a blank line |
| a location past the end of the manuscript |
| a location that cannot be parsed |
| a proposition without a location |
| a line of the ledger that is not JSON |
| a structure sidecar that is not JSON |

- **WHEN** the command runs on it
- **THEN** standard output, byte for byte, and the exit status are what `derive-paragraphs.py` gave for it, as recorded
