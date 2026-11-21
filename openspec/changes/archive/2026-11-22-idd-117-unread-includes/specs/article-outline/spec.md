## ADDED Requirements

### Requirement: A section record can list the included files that were not read

A section record MAY carry `unread`, a list of one or more objects, each with a `file` and a `why` that are non-empty strings: an included file that was not read when the outline was derived, named as the include command writes it, and the reason it was not read. The entry belongs to the record of the section the include command stands in. One file MAY be listed more than once, in one record or in several: an entry is not a locator and does not have to name one place. `unread` is part of the record: a change to it means the section no longer stands as approved.

`propositions outline check` SHALL report an `unread` that is not such a list, and an entry whose `file` holds a control character. It SHALL NOT report a paragraph file that holds no record: an outline whose sections all carry `unread` and have no paragraph record passes.

`propositions outline status` SHALL print, after the line `records that carry dropped` and before `ok status`, the line `sections that carry unread`, a tab, the number of section records that carry `unread` and not `dropped`, and, when there is one, a tab and the list of their ids as JSON.

#### Scenario: The two manuscripts the earlier designs stopped on

- **WHEN** one unread file is included twice in a section, or every section holds only includes of unread files
- **THEN** the outline that records them passes `outline check`, and `outline status` counts the sections

##### Example: a file included twice, and sections with nothing else

- **GIVEN** an outline whose section `s-a` carries `"unread": [{"file": "generated/numbers", "why": "ignored by git"}, {"file": "generated/numbers", "why": "ignored by git"}]`, whose section `s-b` carries `"unread": [{"file": "../shared/methods.tex", "why": "outside the repository"}]`, and whose paragraph file is empty
- **WHEN** `propositions outline check` and `propositions outline status` run
- **THEN** the check prints `ok outline check`; the status ends with `sections that carry unread	2	["s-a","s-b"]` and `ok status`

##### Example: an unread list that is not in the format

- **GIVEN** section records that carry, one at a time, `"unread": []`, `"unread": "generated/numbers"`, `"unread": [{"file": "generated/numbers"}]`, `"unread": [{"file": "", "why": "x"}]` and `"unread": ["generated/numbers"]`
- **WHEN** `propositions outline check` runs on each
- **THEN** the first two are reported as `unread is not a list of one or more files that were not read`, and the others as `unread has an entry that is not an object with a file and a why that are non-empty strings`

##### Example: a dropped section is not counted

- **GIVEN** an outline whose only section that carries `unread` also carries `dropped`
- **WHEN** `propositions outline status` runs
- **THEN** it prints `sections that carry unread	0`
