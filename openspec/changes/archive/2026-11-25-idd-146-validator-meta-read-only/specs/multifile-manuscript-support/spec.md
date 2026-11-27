## MODIFIED Requirements

### Requirement: Meta records the resolved parts as a non-authoritative snapshot

`_meta.json` SHALL support an optional `source.parts` string array: the part files of the input tree, as paths relative to the main file's directory. Operation D, which creates `_meta.json` after the author confirms a dry run, MAY record it. The validator SHALL NOT write `_meta.json`; running it with `--meta` SHALL leave the file unchanged byte for byte (issue 146). Consumers SHALL treat the live input-tree resolution, not `source.parts`, as authoritative.

The validator SHALL compare the snapshot with the resolved tree whenever `--meta` names a readable `_meta.json` whose `source` is an object. The snapshot differs when the tree has parts and `source.parts` is not that list in document order, or when the tree has no parts and `source.parts` is present and not empty. A difference SHALL be one warning, printed as a line that begins `[WARN] source.parts` and names every part file resolved now (or says there are none), and counted with the other warnings, so that `--strict` fails. A `_meta.json` without `source.parts` for a single-file manuscript, or with an empty list, SHALL produce no warning. A `_meta.json` that is not valid JSON SHALL stop the run as a parse error (exit 2), as the ledger loader reads it first; a `source` that is not an object SHALL produce no warning. In both cases the file SHALL be unchanged.

#### Scenario: Measuring leaves the meta file as it was

- **WHEN** the validator runs with `--meta` on a multi-file manuscript whose `source.parts` is stale
- **THEN** `_meta.json` has the same bytes after the run as before

##### Example: a stale snapshot is reported and not rewritten

- **GIVEN** a manuscript whose tree resolves `parts/part1.tex` and `parts/part2-theory.tex`, and a `_meta.json` whose `source.parts` is `["parts/part1.tex"]`
- **WHEN** the validator runs with `--jsonl`, `--meta` and `--tex`
- **THEN** `_meta.json` is unchanged byte for byte, the output has a line beginning `[WARN] source.parts` that names both files, and the run exits 0

##### Example: strict fails on a stale snapshot

- **GIVEN** the manuscript and the stale `_meta.json` of the previous example
- **WHEN** the validator runs with `--strict`
- **THEN** it exits 1 and `_meta.json` is unchanged

##### Example: a current snapshot gives no warning

- **GIVEN** a `_meta.json` whose `source.parts` is `["parts/part1.tex", "parts/part2-theory.tex"]` for the same manuscript
- **WHEN** the validator runs with `--meta`
- **THEN** no output line begins `[WARN] source.parts`

##### Example: a single-file ledger without the key stays quiet

- **GIVEN** a single-file manuscript and a `_meta.json` whose `source` has no `parts`
- **WHEN** the validator runs with `--meta`
- **THEN** it exits 0, no output line begins `[WARN] source.parts`, and `_meta.json` is unchanged

##### Example: a single-file ledger with leftover parts is warned

- **GIVEN** a single-file manuscript and a `_meta.json` whose `source.parts` is `["parts/old.tex"]`
- **WHEN** the validator runs with `--meta`
- **THEN** a line beginning `[WARN] source.parts` says the tree has no part files, and `_meta.json` still lists `parts/old.tex`
