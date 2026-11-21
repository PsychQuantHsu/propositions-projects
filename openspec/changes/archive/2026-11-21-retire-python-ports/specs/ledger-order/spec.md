## MODIFIED Requirements

### Requirement: Without a main file the command orders as the Python tool does

Without `--tex`, the place of an anchor SHALL be the first line of its `location`, read as a line of the one file of the manuscript: a location that names no file, or names exactly `main.tex`. A location that names any other file SHALL be refused with exit 2 and a message that says to pass `--tex`. The places that hold several propositions are printed as the Python tool `reorder-ledger.py` prints them, `<n> TeX line(s) hold several propositions on the same line, check their order: [<line>, <line>]`.

For such a manuscript, called with `--jsonl` and `--write` written in full, the command SHALL print on standard output what `reorder-ledger.py` printed, exit as it exited, and write the file it wrote, as recorded from it on 2026-11-21 (`tests/fixtures/retired-python/reorder-ledger/`). These are the differences, all of them on input the Python tool mishandles or refuses:

- Line endings. The Python tool reads the ledger as text: it turns a carriage return, alone or before a line feed, into a line feed, and it splits a line at a form feed, a vertical tab, the three separator controls, the next-line control and the Unicode line and paragraph separators when one stands unescaped. For a ledger that holds any of these, where its lines end, the count it prints, its exit status and the file it writes can all differ. The command splits at a line feed only and keeps every byte of a line.
- A ledger named through a symbolic link, with `--write`: the Python tool replaces the link with a file. The command refuses.
- A ledger saved by another program between reading and writing: the Python tool overwrites it. The command refuses.
- Failures of the file system (a ledger that cannot be read, a directory that cannot be written), a ledger that is not UTF-8, and a line whose JSON is beyond what Python's parser takes (an integer of several thousand digits, very deep nesting): the Python tool ends with a traceback and exit 1. The command refuses with exit 2, or reads the line.
- A line number too large for a 64-bit integer is read by the Python tool and refused by the command. A line number written with decimal digits outside ASCII is read by each tool with its own table of Unicode digits, and the two tables can be of different Unicode versions.
- Options. The Python tool takes an abbreviation of an option (`--w` for `--write`); the command does not.
- The ledger's path. The Python tool drops a final `/.` before it looks for the file; the command hands the path to the system as it was given.
- The command reads JSON strictly: a line the Python tool accepts though it is not JSON by the standard (`NaN`, for one) is refused.
- The ledger's name after `written: ` is shown as it was given, with its control characters escaped; the Python tool drops a `.` part anywhere in it and a doubled slash, and prints a control character as it is.
- Permission bits the system does not let the new file have (set-group-id, on some systems): the Python tool replaces the ledger without them; the command refuses.
- A ledger whose name starts with a hyphen: the Python tool takes `--jsonl -1`; the command needs `--jsonl=-1`.
- A location whose line number is written with more digits than Python converts (several thousand, leading zeroes included) ends the Python tool with a traceback; the command reads the number.
- What the two write on standard error, when they refuse, differs in wording.

The Python tool was retired on 2026-11-21, when the skill that called it was changed to call this command: `reorder-ledger.py` now only says that it was retired and what to run instead, and exits with 2.

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
| a comment whose two slashes are followed by a combining mark |
| lines with white space outside ASCII before and after |

- **WHEN** the command runs on it
- **THEN** standard output, the exit status and the bytes of the ledger afterwards are what `reorder-ledger.py` gave for it, as recorded, and the command leaves no other file
