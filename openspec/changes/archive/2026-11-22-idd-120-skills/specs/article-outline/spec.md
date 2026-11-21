## ADDED Requirements

### Requirement: The outline skill writes the keys for unread files, planned commitments and length targets

In derive, the outline skill SHALL record each included file that was not read, other than one whose content is a figure or a table, on the section record of the section its include command stands in (the first section record when the command stands before the first section), as one entry of `unread` for each include command, and give it no paragraph record, locator, point or note. It names each such file and its section to the author when the outline is shown and in the report. When the files read hold no paragraph and no block because the text is in such files, derive accepts an empty paragraph file; it still stops when a section whose text is all in such files gets no sentence from the author, and when the files read hold no paragraph and no block and no included file was left unread.

In revise and draft, the skill SHALL write `opens`, `discharges` and `length` only when the author asks for them; a record given `dropped` loses `opens` and `discharges` after the author says which record carries those commitments instead; a merge carries the `opens`, `discharges` and `unread` of the records it replaces. The skill does not write `article.json`.

The skill's write check SHALL report a `length` that is not a whole number from 1 to 999999999, an `unread`, `opens` or `discharges` that is not in the format, and a record that carries `dropped` with `opens` or `discharges`; its status command SHALL print the line `sections that carry unread` as `propositions outline status` does, and the skill names those sections and files to the author.

When the author asks for text to be written from the outline, the skill SHALL say that the construct skill does it.

No executable check: the actions are instructions that a model follows. The two commands of the skill that changed (the write check and status) were run by hand on a sample outline with jq 1.8: the write check reported the six malformed records and no well-formed one, and status printed `sections that carry unread	2	["s-a","s-c"]` for two sections that carry the key and are not dropped. The format itself is tested under this capability's requirements for `propositions outline check` and `status`.

#### Scenario: A manuscript whose text is in files that were not read

- **WHEN** derive reads a manuscript whose sections hold only includes of files git ignores, and the author gives a sentence for each section
- **THEN** the section records carry `unread`, the paragraph file is empty, and the skill shows the outline and names the files
