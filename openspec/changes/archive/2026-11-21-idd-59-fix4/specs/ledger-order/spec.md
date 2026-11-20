## MODIFIED Requirements

### Requirement: A command puts a ledger's lines into reading order

The command-line tool SHALL have a subcommand `propositions ledger-order --jsonl <ledger> [--tex <main file>] [--write]` that says whether the lines of a ledger are in the manuscript's reading order and, with `--write`, puts them in it. Without `--write` it writes nothing.

A line of the ledger is an anchor when, with the white space around it removed, it is a JSON object that has no key `retired`. Every other line (a retired proposition, a line that starts with `//`, an empty line, a JSON value that is not an object) stays behind the anchor it followed; such lines before the first anchor stay at the head. Anchors are put in the order of where their `location` starts. Anchors that start at the same place keep the order they had, and the command reports each such place, because only a reader can tell whether that order is right. Lines are moved and never edited: each keeps its bytes, its line ending included; when the ledger is rewritten, a last line without a line feed is given one. A ledger that is already in reading order is not rewritten, with `--write` or without, whatever its last line or the way it is named. The count the command prints is the number of line positions that hold another line than before.

The command prints, in this order: one line for the places that hold several propositions, when there are any, with at most twenty of them; then `already in reading order`, or `<n> line(s) move`; then, after writing, `written: <the ledger as it was named>`. It exits with 0 when the ledger is in reading order or was written, with 1 for a dry run in which lines would move, and with 2, with one line on standard error that starts with `error: ` (after one line for each line of the manuscript that holds an import macro the input tree does not follow, when `--tex` is given and the tree could be read), when the ledger is not a regular file or cannot be read, the main file is not a regular file, a line that is neither empty nor a comment is not JSON, a location is missing or cannot be parsed or cannot be placed, the ledger cannot be replaced, or an argument is wrong. When it exits with 2 the ledger is as it was. A path in a message is shown with its control characters escaped.

Writing replaces the ledger through a temporary file beside it that is given the ledger's permission bits (its owner, group and access-control list are those of a new file), and removes that file when it does not replace the ledger; a command that is killed can leave it. The command reads the ledger through one open file and keeps which file that was (device and inode), its permission bits and its bytes. It SHALL replace the ledger only when, at the last look before the replacement, the path is not a symbolic link, one open file there gives the same file, the same permission bits and the same bytes, that file's size, permission bits and times of modification and of change are the same before and after it is reread, and the path still names it, with those same values, afterwards. It refuses also when the new file cannot be given the ledger's permission bits exactly. A ledger named through a symbolic link is therefore refused when it would be rewritten, and so is one that was saved in the meantime (by writing into it or by putting another file with the same bytes in its place) or whose permissions were changed, all with exit 2 and the ledger as it was. A change in the moment between that look and the replacement is not caught; neither is a save into the file that leaves its size and both times as they were. The temporary file is made and removed by its path: when the directory is renamed while the command runs, the file can be left in it. The main file is looked at once before the input tree is read; a file put in its place in between is read as it then is. After the replacement the command syncs the directory; when that fails it still exits with 0, and says on standard error that the ledger was replaced and that the old one may be back after a crash.

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

##### Example: a ledger that is a link, or that changed, is not replaced

- **GIVEN** a ledger out of order that is named through a symbolic link; or one that, after the command read it, gained a line, was replaced by another file with the same bytes, had its permissions changed from `644` to `600`, or was replaced by a link to a file with the same bytes
- **WHEN** the command is to write
- **THEN** it refuses and says which of the two it met, a link or a change, the file has the bytes and the permissions it had after that change, a link still names its file, and no other file is beside it

### Requirement: Without a main file the command orders as the Python tool does

Without `--tex`, the place of an anchor SHALL be the first line of its `location`, read as a line of the one file of the manuscript: a location that names no file, or names exactly `main.tex`. A location that names any other file SHALL be refused with exit 2 and a message that says to pass `--tex`. The places that hold several propositions are printed as the Python tool `reorder-ledger.py` prints them, `<n> TeX line(s) hold several propositions on the same line, check their order: [<line>, <line>]`.

For such a manuscript, called with `--jsonl` and `--write` written in full, the command SHALL print on standard output what `reorder-ledger.py` prints, exit as it exits, and write the file it writes. These are the differences, all of them on input the Python tool mishandles or refuses:

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
| a comment whose two slashes are followed by a combining mark |
| lines with white space outside ASCII before and after |

- **WHEN** the command and `reorder-ledger.py` run on a copy each
- **THEN** standard output, the exit status and the bytes of the ledger afterwards are the same for both, and the command leaves no other file
