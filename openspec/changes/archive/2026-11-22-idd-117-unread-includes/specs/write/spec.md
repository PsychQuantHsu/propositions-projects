## ADDED Requirements

### Requirement: Prepare says which included files of the section were not read

When a paragraph is written from an outline record, `propositions write prepare` SHALL print on standard error, for each entry of `unread` of the record's section and of each section above it, one line that begins with `[unread]` and names the section, the file and the reason. For a rewrite it SHALL print one such line for each entry of every section record that is not dropped. The lines do not change the exit code.

#### Scenario: A gap of the outline is said before text is written

- **WHEN** the section a paragraph is written into carries `unread`
- **THEN** prepare stages the copies and names the file that was not read

##### Example: prepare names the unread files of the section and of the section above it

- **GIVEN** the structure fixture and an approved outline in which `s-a` carries `"unread": [{"file": "generated/numbers", "why": "ignored by git"}]`, `s-a1` is under `s-a` and holds the record `p-1`, and `s-b` carries another `unread` entry
- **WHEN** `write prepare --outline … --outline-paragraph p-1` runs
- **THEN** it exits with 0, and standard error holds exactly one `[unread]` line, `[unread] section s-a: the included file generated/numbers was not read when the outline was derived (ignored by git); the outline does not say what it holds`

##### Example: a rewrite names every unread file

- **GIVEN** an outline approved as a whole whose section carries two `unread` entries for the same file
- **WHEN** `write prepare --rewrite --outline …` runs
- **THEN** it exits with 0 and standard error holds two `[unread]` lines
