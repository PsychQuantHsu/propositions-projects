## MODIFIED Requirements

### Requirement: Obligations are grouped by principle

`groups` SHALL list exactly these eight groups, in this order: `dependence`, `motivation`, `commitment`, `support`, `consistency`, `truth`, `placement`, `completeness`. Each group SHALL have `id`, `zh` (a Traditional Chinese label) and `does` (one English sentence saying what the group protects). `axiom` is optional and, when present, SHALL name one axiom of the che-axiom-systems plugin as `<domain>/<axiom id>`. A group SHALL name at most one axiom. The group `dependence` SHALL name `academic-writing/A1_no_forward_dependence`, and the group `motivation` SHALL name `academic-writing/A2_motivated_by_prefix` (issue 139: every example, definition or result arrives after the text before it has raised the question it answers; a property of the sequence, which no other group covers). The group `motivation` SHALL hold the obligation `motivation.called-for-by-prefix`, which applies to the claim types `definition`, `example`, `claim` and `result` (a result is a `claim` in the default profile) and whose check is a gap owned by issue 141. The file SHALL NOT restate the text of an axiom.

Every obligation entry SHALL name one of the eight groups in `group`. A precondition entry SHALL NOT have `group`.

#### Scenario: An obligation without a group is refused

- **WHEN** an entry has `class: obligation` and no `group`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A ninth group is refused

- **WHEN** `groups` has an item with the id `style`
- **THEN** the guard fails and its message names `style`

##### Example: a ninth group

- **GIVEN** a table whose `groups` holds the eight groups and a ninth item with the id `style`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `style`
