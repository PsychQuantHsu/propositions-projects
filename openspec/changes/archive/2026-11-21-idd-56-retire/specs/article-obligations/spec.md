## MODIFIED Requirements

### Requirement: A check is named only when it is implemented

`check` SHALL be either `gap` or one id from the inventory below. The inventory is closed, has 47 ids, and is the normative list; what its members have in common is that each reports findings, or leaves records, about units under an id of its own.

- `ledger:R1`, `ledger:R1.5`, `ledger:R2`, `ledger:R3`, `ledger:R4`, `ledger:R7`, `ledger:R8`, `ledger:R9`, `ledger:R10`, `ledger:R11`, `ledger:R12`, `ledger:R13`, reported by the ledger validator;
- `ledger:profile`, the ledger validator's check that a profile declared in the ledger's `_meta.json` is one it accepts under the ledger's schema version; it reports nothing for a ledger that declares none;
- `structure:S1` to `structure:S9`, reported by the structure validator;
- `records:V1` to `records:V6`, reported by the verification records validator;
- `coverage:text`, the extraction coverage check;
- `order:ledger`, the dry run of `propositions ledger-order`, which reports whether the ledger's line order is the reading order;
- `ledger:replaced-by`, the `revise check` command of the `propositions` command-line tool, which reports each `retired.replaced_by` that does not name a live proposition;
- `order:cites`, the `cite-order` command of the `propositions` command-line tool, which warns about every citation of a proposition that comes later in reading order;
- `audit:R1`, `audit:R2`, `audit:R3`, the three passes of the cross-artifact audit (`propositions audit symbols`, `propositions audit citations` and `audit-code-manuscript.py`);
- `proofread:L1` to `proofread:L5` and `proofread:E1` to `proofread:E7`, the layers listed in the per-proposition walk of the proofread skill.

The following SHALL NOT be inventory ids: the fourth pass of the cross-artifact audit (it runs the ledger validator); the theorem-boundary audit (it compares what `ledger:R9` compares; what it reports beyond R9, the environments it could not close and the propositions whose block it could not resolve, belongs to issue 68); the dry run of the location refresh (it has no rule id of its own; it searches the manuscript for each proposition's text and reports every `location` that differs from where it finds the text, which is more than `ledger:R13`, the check on that field, reports; what R13 passes over in silence belongs to issue 68); the link catalog's currency check (its subject is a file of the plugin, not a manuscript); the checks of the `tschema-check` plugin; the stumble categories of the clarity audit, the counts in the construct skill's summary and the states of the analyze skill (none of them leaves a finding or a record for a unit under an id); the `location` layer of the proofread walk (a spot-check of the field that `ledger:R13` checks; the skill's layer table names R13 as its mechanical form); the verification records validator's warning that two methods disagree on a proposition (it has no rule id of its own; it reports part of what `truth.not-refuted` states, and where it counts is left to the outcome rules of issue 71); and the proofread layers E8, E9 and E10 (defined in the layer table but absent from the walk, so a verdict does not show that they were read).

A change that implements a new check SHALL add its id to this inventory and to the guard in the same change. When `check` is `gap`, the entry SHALL have `owner`, the number of the issue in this repository that will supply the check. When `check` is an inventory id, the entry SHALL NOT have `owner`. Exactly three entries SHALL have `owner: 57`: `consistency.variable-roles` for the layer E8, `truth.composite-holds-per-component` for E9 and `support.exposures-separable` for E10. At least one entry SHALL have each of the owners 49, 50, 55, 62, 66 and 70.

For a gap, `unit`, `verified_by` and `on_warning` say how the entry is expected to be verified. They are provisional: the change that supplies the check SHALL set them to what the check does.

#### Scenario: A layer that is defined but not walked is a gap

- **WHEN** the entries whose `owner` is 57 are listed
- **THEN** they are exactly the three entries named for E8, E9 and E10, each has `check: gap`, and each `verified_by` lists `proofread` and `cross_model`

#### Scenario: A gap without an owner is refused

- **WHEN** an entry has `check: gap` and no `owner`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An id outside the inventory is refused

- **WHEN** an entry has `check: ledger:R6`
- **THEN** the guard fails and its message names the entry id and `ledger:R6`

##### Example: the forward-citation obligation

- **GIVEN** the `cite-order` command reports each citation of a proposition that comes later
- **WHEN** the entry `dependence.cites-backward` is read
- **THEN** it has `class: obligation`, `group: dependence`, `unit: proposition`, `applies` with `cites: [present]` and no other key, `check: order:cites`, no `owner`, `verified_by: [mechanical]` and `on_warning: judge`
