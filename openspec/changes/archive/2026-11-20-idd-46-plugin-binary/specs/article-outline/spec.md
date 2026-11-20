## MODIFIED Requirements

### Requirement: Commands check an outline mechanically

The command-line tool SHALL have three subcommands that read the outline files of a directory and write nothing.

`propositions outline check <directory>` SHALL report what can be decided from the three files alone, each finding with its file and line: a line that is not a JSON object; a key written twice in one object; a string with a control character (not in the approvals file, where a statement holds the author's line breaks); a number too large for a double; a missing or mistyped required key; an `id` used twice; a `role` or a `part` the format does not have; a `parent` that names no section record on an earlier line; a record that is not dropped under a dropped parent or section; a `section` that names no section record; paragraph records of one section that are not on consecutive lines, or groups that do not follow the section file; a `uses` entry that names no record or point on an earlier line, or one of a dropped record; a locator or a reference to another outline that is not written as one; and the rules of `carry`, `edits`, `replaces`, `dropped` and `moved_to`. In an approval record it also reports an `approved_at` that is not a real date and time with an offset, a section copy without `heading` and `says`, a paragraph copy without `id`, its section or its points, and two entries for one section; a `role` or a `part` of a section copy that the format does not have, and an `id` used twice within one approval; it does not hold a copy to the present outline. Two locators are the same when they name the same `file` and the same `label`, or with no `label` the same `starts`, each with runs of white space as one space. An approvals file counts as absent only when the system says there is no such file. It exits with 0 and `ok outline check` when it has nothing to report, with 1 when it reports something, and with 2 when the section file or the paragraph file cannot be read.

`propositions outline locators <directory> --root <root>` SHALL resolve every locator of the paragraph file as the requirement on locators says, and report each that does not name exactly one place with the record that names it. It also reports a line of the paragraph file that is not a JSON object, and a `from`, a `replaces` or a `basis` that is not a list of one or more entries. The root SHALL be the top directory of a git work tree; a file SHALL be a regular file. Git is run without the environment variables that make it answer for another repository. It exits with 0 and `ok locators`, with 1 when it reports something, and with 2 when a file cannot be read or the root is not such a directory. The repository is taken to stay as it is while the command runs. It does not confirm a reference to another outline.

The tool reads JSON strictly and keeps what it reads: a key written twice is reported, and two numbers are equal only when they have the same value, however long they are. A line ends at a line feed, so a file with CRLF line ends reads the same; an empty line, with either line end, is passed over; a line that is not valid UTF-8 is not JSON, and neither is one with an escape that names half of a surrogate pair. An exponent is kept exactly up to fifteen digits, and a number with a longer one is refused. Each of the three files SHALL be a regular file: one that is a symbolic link is not read. Names and ids are compared code point by code point: two spellings of one accented letter are two names. The tool only reads: it has no command that writes an outline file, and the skill writes them itself (issue 102).

The skill does not call these commands yet: the binary the plugin fetches is the one its lock file names, version 0.1.0, which does not have them (issue 102). Until it does, the skill's own commands stay as they are. For an outline that passes `propositions outline check`, `propositions outline status` SHALL print the lines the skill's status command prints, with one difference: in an id it writes the characters U+007F to U+009F, U+2028 to U+202E and U+2066 to U+2069 as escapes, so that a name cannot break or reorder a line of output; other characters that affect the direction of text are not escaped. A second difference concerns numbers alone: the tool compares them by their exact value, and `jq` cannot tell apart two numbers that differ only beyond what it keeps (an exponent of hundreds of digits' worth, such as `1e-999999999999999` and `2e-999999999999999`); for such numbers the tool's answer is the one this capability means. For files that do not pass the check the two can differ: the skill's command reads a record written across lines, and the tool does not.

##### Example: a missing file and a wrong argument

- **GIVEN** a directory with a section file and no paragraph file, and a directory whose two files hold a section record without `heading` and `says` and the line `[1]`
- **WHEN** the commands are run
- **THEN** `outline check` on the first exits with 2 and says which file it cannot read; on the second it reports three findings and exits with 1, and `outline status` exits with 2; `outline locators` without `--root`, or with a root that is not a directory, exits with 2

##### Example: an approvals file that cannot be read

- **GIVEN** an outline whose approvals file exists and cannot be read
- **WHEN** `propositions outline status` is run
- **THEN** it exits with 2 and says that it cannot read the file; it does not say that the sections were never approved

<!-- @trace
source: idd-78-fix3
updated: 2026-11-20
code:
  - propositions-projects.code-workspace
-->
