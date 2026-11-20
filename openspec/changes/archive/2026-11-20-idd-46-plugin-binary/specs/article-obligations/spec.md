## MODIFIED Requirements

### Requirement: A check is named only when it is implemented

`check` SHALL be either `gap` or one id from the inventory below. The inventory is closed, has 46 ids, and is the normative list; what its members have in common is that each reports findings, or leaves records, about units under an id of its own.

- `ledger:R1`, `ledger:R1.5`, `ledger:R2`, `ledger:R3`, `ledger:R4`, `ledger:R7`, `ledger:R8`, `ledger:R9`, `ledger:R10`, `ledger:R11`, `ledger:R12`, `ledger:R13`, reported by the ledger validator;
- `ledger:profile`, the ledger validator's check that a profile declared in the ledger's `_meta.json` is one it accepts under the ledger's schema version; it reports nothing for a ledger that declares none;
- `structure:S1` to `structure:S9`, reported by the structure validator;
- `records:V1` to `records:V6`, reported by the verification records validator;
- `coverage:text`, the extraction coverage check;
- `order:ledger`, the dry run of the ledger reordering tool, which reports whether the ledger's line order is the reading order;
- `order:cites`, the `cite-order` command of the `propositions` command-line tool, which warns about every citation of a proposition that comes later in reading order;
- `audit:R1`, `audit:R2`, `audit:R3`, the three scripts of the cross-artifact audit;
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

### Requirement: An article is sound only when every applicable entry passes

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define a sound article as one for which every entry has the outcome `passed` or `not_applicable` for every unit, and SHALL add no condition outside the table. A verdict against a proposition from a method that no entry lists SHALL count through an entry of its own, `truth.not-refuted`, which states that no method's most recent verdict on the proposition is `refuted` or `partial`, where an `unresolved` or `not_attempted` record replaces no earlier verdict; that entry SHALL be a gap owned by issue 62 until a check reports it, and how a method's records are ordered is left to that issue. The document SHALL state that an `unverified` outcome counts against soundness in the same way as `failed`, and that while any precondition entry is `failed` or `unverified` the outcomes of obligation entries are not to be trusted until the ledger, sidecars or records are corrected; those outcomes are left as computed. It SHALL state what a report names: for each outcome that is `failed` or `unverified`, the entry and the unit, and for a gap the issue in its `owner`. A report names a proposition by its id, and by its line in the ledger when the proposition has no id that is a non-empty string or shares its id with another proposition that is not retired. What else a report lists is left to issue 71.

The document SHALL state that no article is sound yet and SHALL list the four reasons with the issue that owns each: entries whose `check` is `gap`, each owned by the issue in its `owner`; checks that do not report which units they examined (issue 68, which takes in issue 63); verification records that cannot say what they cover (issue 62), which also leaves a warning under `on_warning: judge` with no place where a judgment is recorded; and `cross_model` records, which no tool produces yet (issue 21). It SHALL state that the rules that compute an outcome from what the checks report are not written yet (issue 71).

It SHALL also state the limits that remain for some manuscripts once checks report what they examine: the reading-order check runs on single-file manuscripts only (issue 59); the symbol audit and the citation audit read the main file only, and the citation audit reads one bibliography file of a fixed name (issue 69); and the audit's code pass needs a directory of analysis code (issue 64).

It SHALL state one limit of what the table reaches. Numbers are compared with artifacts only in a ledger with the empirical profile. No entry compares the numbers of a manuscript whose ledger has the default profile with an artifact; that is the scope the maintainer accepted on 2026-11-13. Whether a ledger's profile fits its manuscript is a precondition that has no check yet (issue 70).

No executable check: soundness is a definition that the document states for readers and for later tools, and nothing in this change computes it. The guard checks that the document names the four outcomes and the issues that own the reasons no article is sound yet.

#### Scenario: A gap keeps an article from being sound

- **WHEN** one proposition is `unverified` under `dependence.symbols-introduced`, a gap whose `owner` is 55
- **THEN** the article is not sound, and a report names that entry, that proposition and issue 55

#### Scenario: A verdict from a method that no entry lists counts inside the table

- **WHEN** the latest `lean` record for one proposition is `refuted` and no entry lists `lean` in `verified_by`
- **THEN** the verdict counts under `truth.not-refuted` and under no condition outside the table; while that entry's `check` is `gap` it is `unverified` for every proposition, with or without such a record

#### Scenario: A failed precondition is corrected first

- **WHEN** `index.text-in-manuscript` is `failed` for one proposition
- **THEN** the article is not sound, and the outcomes of the obligation entries are marked as not to be trusted

#### Scenario: A proposition without an id of its own is named by its line

- **WHEN** two propositions that are not retired share an id and an entry is `unverified` for each of them
- **THEN** a report names each of the two by its line in the ledger
