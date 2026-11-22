## MODIFIED Requirements

### Requirement: A replacement may be a proposition of another ledger

A `replaced_by` item SHALL be either a string, an id of the same ledger, or an object with exactly the keys `ledger` and `id`, each a non-empty string, naming a live proposition of another ledger; `ledger` is a path relative to the directory of the ledger that holds the retirement, not absolute (schema v1.9). Ledgers written before v1.9 need no migration.

`propositions revise retire` SHALL take such a replacement written `<ledger>#<id>` after `=` (the last `#` splits the two, so an id of this ledger that holds `#` cannot be named on the command line), record it as that object, and refuse, with exit 2 and nothing written, one whose ledger cannot be read, whose id is not exactly one live line of that ledger, whose path is absolute or empty, or whose ledger is this ledger: the same path, or the same file (device and inode after symlinks are resolved, so a hard link counts, reached directly or through a symlink). `--ledger-dir <directory>` gives the directory the paths are relative to when `--jsonl` names a copy that keeps the original's file name (a copy under another name is not recognised as this ledger); without it they are relative to the ledger's own directory.

`propositions revise check` SHALL read each ledger an object names, once, and report as a problem an object whose ledger cannot be read, whose id is not exactly one live line of that ledger, or whose ledger is this ledger, and an item that is neither a string nor such an object. It takes `--ledger-dir` as `retire` does, and so does `redirect`.

`propositions revise redirect` SHALL NOT carry a citation into another ledger, and SHALL refuse, with exit 2, an object item of a cited retirement that `check` would report (a retirement nothing cites is not judged): a citation of a retired proposition whose replacements are all in other ledgers is dropped, and the line that reports it names them; when some replacements are in this ledger, the citation follows those, and a line notes the others.

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
