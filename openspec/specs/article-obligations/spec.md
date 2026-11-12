# article-obligations Specification

## Purpose

The article obligations table states, one entry at a time, what a manuscript's ledger and sidecars have to get right and what the article owes its reader, and names the check that verifies each entry. It exists so that "the article is sound" has a single definition that later tools and skills evaluate in the same way.

## Requirements

### Requirement: The obligations table is a closed data file

`plugins/propositions/catalog/obligations.yaml` SHALL be a YAML mapping with exactly three keys: `groups`, `entries` and `unconstrained`. Each item of `entries` SHALL be a mapping whose keys come from this closed set: `id`, `class`, `group`, `unit`, `applies`, `criterion`, `check`, `owner`, `verified_by`, `on_warning`, `external_source`. Any other top-level key or entry key SHALL be an error.

`id` SHALL have the form `<prefix>.<name>`, where both parts consist of lowercase letters, digits and hyphens, and SHALL be unique in the file. `unit` SHALL be `proposition` or `article`. A `proposition` unit is a proposition of the ledger that is not retired. A proposition is retired only when its `retired` block is well formed, so one whose block is malformed is a unit. The `article` unit is the manuscript as a whole. `criterion` SHALL be one line of at most 200 characters stating what has to hold; the definition of the check it points to stays in that check's own document. `external_source`, when present, SHALL be `true`.

#### Scenario: An unknown entry key is refused

- **WHEN** an entry has a key named `example`
- **THEN** the guard fails and its message names the entry id and the key

#### Scenario: A repeated id is refused

- **WHEN** two entries have the id `dependence.cites-backward`
- **THEN** the guard fails and its message names `dependence.cites-backward`

#### Scenario: A criterion that copies a definition is refused

- **WHEN** an entry's `criterion` spans two lines or is longer than 200 characters
- **THEN** the guard fails and its message names the entry id

#### Scenario: A mark for an outside source is true or absent

- **WHEN** an entry has `external_source: yes` written as a string, or `external_source: false`
- **THEN** the guard fails and its message names the entry id and `external_source`

##### Example: an entry key outside the closed set

- **GIVEN** a table in which the entry `index.text-in-manuscript` carries the key `example`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `index.text-in-manuscript` and `example`


<!-- @trace
source: idd-47-fix2
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Entries are preconditions or obligations

`class` SHALL be `precondition` or `obligation`. There is no third class.

- A `precondition` entry is one whose failure is corrected in the ledger, a structure sidecar or the verification records.
- An `obligation` entry is one whose failure is corrected in the manuscript, or needs a decision by the author. For this rule the manuscript includes the repository's documents and analysis code that the audit's code pass compares.

The class SHALL be written on each entry. It SHALL NOT be derived from which tool runs the check. When one check covers both a precondition and an obligation, the file SHALL hold one entry for each, naming the same check. The `id` prefix SHALL be `index` for a precondition and the group id for an obligation.

A finding that the maintainer has reviewed as information only (crossing arcs under S7, an uncited proposition under R3, a code symbol that the documents never mention under the audit's R3, and a bibliography entry that is never cited under the audit's R2) SHALL have its own entry with one of the two classes, chosen by what would be corrected if the finding were acted on, and `on_warning: info`.

#### Scenario: One check is split by what gets corrected

- **WHEN** the entries whose `check` is `structure:S5` are listed
- **THEN** one of them is an obligation stating that the article states its thesis, and another is a precondition stating that the section and paragraph plans are well formed

The table SHALL hold the precondition `index.structure-faithful`, which states that the structure sidecars record what each proposition does in the manuscript: the commitments it opens and discharges, its head and relation, and the role of its section. It is a gap owned by issue 66 until a check reports it. Without it, an entry that applies by `opens` or by `section_role` is decided from annotations that nothing has compared with the text.

The table SHALL hold the precondition `index.profile-fits-manuscript`, which states that the ledger's profile fits the manuscript: it is empirical when the manuscript reports data. It is a gap owned by issue 70 until a check reports it. Without it, an entry that applies by `profile` is decided from a declaration that nothing has compared with the manuscript.

#### Scenario: The fidelity of the sidecars is a precondition

- **WHEN** the entry `index.structure-faithful` is read
- **THEN** it is a precondition whose `check` is `gap` and whose `owner` is 66

#### Scenario: The fit of the profile is a precondition

- **WHEN** the entry `index.profile-fits-manuscript` is read
- **THEN** it is a precondition whose `check` is `gap` and whose `owner` is 70

#### Scenario: A third class is refused

- **WHEN** an entry has `class: information`
- **THEN** the guard fails and its message names the entry id and `information`

##### Example: the two entries for the citation graph

- **GIVEN** the ledger validator reports a cycle in `cites` as an error and an uncited proposition as a warning, both under R3
- **WHEN** the entries whose `check` is `ledger:R3` are listed
- **THEN** there are at least two: an obligation in the group `dependence` stating that citations form no cycle, with `on_warning: judge`, and an entry for the uncited proposition with `on_warning: info`


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Obligations are grouped by principle

`groups` SHALL list exactly these seven groups, in this order: `dependence`, `commitment`, `support`, `consistency`, `truth`, `placement`, `completeness`. Each group SHALL have `id`, `zh` (a Traditional Chinese label) and `does` (one English sentence saying what the group protects). `axiom` is optional and, when present, SHALL name one axiom of the che-axiom-systems plugin as `<domain>/<axiom id>`. A group SHALL name at most one axiom. The group `dependence` SHALL name `academic-writing/A1_no_forward_dependence`. The file SHALL NOT restate the text of an axiom.

Every obligation entry SHALL name one of the seven groups in `group`. A precondition entry SHALL NOT have `group`.

#### Scenario: An obligation without a group is refused

- **WHEN** an entry has `class: obligation` and no `group`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An eighth group is refused

- **WHEN** `groups` has an item with the id `style`
- **THEN** the guard fails and its message names `style`

##### Example: an eighth group

- **GIVEN** a table whose `groups` holds the seven groups and an eighth item with the id `style`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `style`


<!-- @trace
source: add-article-obligations
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Applicability is a list of field values

`applies` is optional. When present it SHALL be a mapping whose keys come from this closed set: `profile`, `claim_type`, `evidence_class`, `cites`, `opens`, `section_role`. Each value SHALL be a non-empty list. A proposition satisfies `applies` when, for every key present, its own value is in the list:

- `profile`: the profile of its ledger;
- `claim_type`, `evidence_class`: its fields in the ledger;
- `cites`: `present` when its `cites` list is not empty, otherwise `absent`; an id in the list that names no proposition still makes it `present`;
- `opens`: it opens at least one commitment of a listed kind;
- `section_role`: the role of the section that contains it.

When the value a key needs cannot be read for a unit, the entry SHALL be `unverified` for that unit and not `not_applicable`, unless another key whose value can be read already rules the unit out. A value cannot be read when the ledger declares a profile that the validator rejects (a ledger that declares none has the default profile); when the proposition's ledger entry has no `claim_type` or no `evidence_class` and the key asks for that field; when its `cites` field is present with a value that is not a list, such as `null` (a proposition without the field cites nothing); and, for `opens` and `section_role`, when the proposition has no record in the discourse sidecar, its `opens` is not a list of well-formed commitments, or the section plan is missing or invalid. A proposition whose record opens nothing has a value: it opens no commitment.

An entry without `applies` applies to every unit. An entry with `unit: article` SHALL use no key other than `profile`, and for the article `profile` is the profile of the manuscript's ledger. The file SHALL have no other way to state applicability: no negation and no alternative between keys. Every listed value SHALL belong to the vocabulary of its field: the accepted profiles and the claim types and evidence classes of every profile in the ledger validator, and the commitment kinds and section roles in the structure validator. The relation of a record SHALL NOT be a key: every record has one, and no entry's requirement differs by its value except that a `basis` edge needs a citation, which one entry asks of every proposition. The move and the paragraph type SHALL NOT be keys: the sidecars leave them optional, so an unannotated proposition would be treated as not applicable. `opens` is optional too and is a key, which is why the table holds the precondition `index.structure-faithful`.

Every entry whose `check` is one of `proofread:E1` to `proofread:E7`, and each of the three entries whose `owner` is 57, SHALL have `applies` with exactly two keys: `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`. Those four classes mark a claim made about data. The proofread skill says that its layers E1 to E8 do not apply to an `external` proposition, which has no artifact to re-run, and the table gives the entries for E9 and E10 the same limit. `not_computable` is one of the four because it marks a quantity the data cannot produce, which the entry for E2 is there to fail. Without the profile, every proposition of a manuscript with the default profile stays `unverified` under those entries; without the evidence classes, every proposition without an artifact does. A proposition of an empirical ledger that carries any other evidence class is outside these entries, also when its text interprets data; no check decides yet whether such a tag is right, because the layer L5 is not defined for these classes (issue 57). Some criteria concern only propositions with a feature that no key selects, such as an assignment to a theorem-like block, a `basis` edge or a cited figure; such an entry still applies to every proposition, and how a check reports a unit of which the criterion asks nothing belongs to issue 68.

#### Scenario: An entry applies only where every key matches

- **WHEN** an entry has `applies` with `profile: [empirical]` and `claim_type: [result]`
- **THEN** it applies to a `result` proposition in an empirical ledger and to no proposition in a ledger with the default profile

#### Scenario: A proposition without the field is not exempt

- **WHEN** an entry has `applies` with `evidence_class: [external]` and a proposition's ledger entry has no `evidence_class`
- **THEN** the entry is `unverified` for that proposition

#### Scenario: A value outside the vocabulary is refused

- **WHEN** an entry lists `claim_type: [lemma]`
- **THEN** the guard fails and its message names the entry id and `lemma`

#### Scenario: An empirical layer without the profile limit is refused

- **WHEN** an entry with `check: proofread:E3` has no `applies`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An empirical layer that reaches a proposition without data is refused

- **WHEN** an entry with `check: proofread:E3` has `applies` with `profile: [empirical]` and no `evidence_class`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An optional sidecar field is refused as a key

- **WHEN** an entry's `applies` has the key `move`
- **THEN** the guard fails and its message names the entry id and `move`

##### Example: a claim type that no profile accepts

- **GIVEN** a table in which the entry `index.text-in-manuscript` has `applies` with `claim_type: [lemma]`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `index.text-in-manuscript` and `lemma`


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A check is named only when it is implemented

`check` SHALL be either `gap` or one id from the inventory below. The inventory is closed, has 45 ids, and is the normative list; what its members have in common is that each reports findings, or leaves records, about units under an id of its own.

- `ledger:R1`, `ledger:R1.5`, `ledger:R2`, `ledger:R3`, `ledger:R4`, `ledger:R7`, `ledger:R8`, `ledger:R9`, `ledger:R10`, `ledger:R11`, `ledger:R12`, `ledger:R13`, reported by the ledger validator;
- `ledger:profile`, the ledger validator's check that the ledger's `_meta.json` declares a profile it accepts;
- `structure:S1` to `structure:S9`, reported by the structure validator;
- `records:V1` to `records:V6`, reported by the verification records validator;
- `coverage:text`, the extraction coverage check;
- `order:ledger`, the dry run of the ledger reordering tool, which reports whether the ledger's line order is the reading order;
- `audit:R1`, `audit:R2`, `audit:R3`, the three scripts of the cross-artifact audit;
- `proofread:L1` to `proofread:L5` and `proofread:E1` to `proofread:E7`, the layers listed in the per-proposition walk of the proofread skill.

The following SHALL NOT be inventory ids: the fourth pass of the cross-artifact audit (it runs the ledger validator); the theorem-boundary audit (it compares what `ledger:R9` compares; what it reports beyond R9, the environments it could not close and the propositions whose block it could not resolve, belongs to issue 68); the dry run of the location refresh (the same check as `ledger:R13`); the link catalog's currency check (its subject is a file of the plugin, not a manuscript); the checks of the `tschema-check` plugin; the stumble categories of the clarity audit, the counts in the construct skill's summary and the states of the analyze skill (none of them leaves a finding or a record for a unit under an id); the `location` layer of the proofread walk (the same check as `ledger:R13`); the verification records validator's warning that two methods disagree on a proposition (it reports part of what `truth.not-refuted` states and is read with that entry); and the proofread layers E8, E9 and E10 (defined in the layer table but absent from the walk, so a verdict does not show that they were read).

A change that implements a new check SHALL add its id to this inventory and to the guard in the same change. When `check` is `gap`, the entry SHALL have `owner`, the number of the issue in this repository that will supply the check. When `check` is an inventory id, the entry SHALL NOT have `owner`. Exactly three entries SHALL have `owner: 57`: `consistency.variable-roles` for the layer E8, `truth.composite-holds-per-component` for E9 and `support.exposures-separable` for E10. At least one entry SHALL have each of the owners 46, 49, 50, 55, 62, 66 and 70.

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

- **GIVEN** no validator reports whether a proposition cites one that comes later
- **WHEN** the entry `dependence.cites-backward` is read
- **THEN** it has `class: obligation`, `group: dependence`, `check: gap`, `owner: 46`, `verified_by: [mechanical]` and `on_warning: judge`


<!-- @trace
source: idd-47-fix2
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Every implemented check and every vocabulary value is accounted for

Every id in the inventory SHALL be the `check` of at least one entry. For each of the fields `claim_type`, `evidence_class`, `opens` and `section_role`, every value of its vocabulary SHALL be named by at least one entry's `applies` under that key, or be listed in `unconstrained`, and never both. Each item of `unconstrained` SHALL have `field`, `value` and `why` (one line saying why no entry singles the value out).

#### Scenario: A check that no entry names is reported

- **WHEN** no entry has `check: records:V4`
- **THEN** the guard fails and its message names `records:V4`

#### Scenario: A new vocabulary value has to be placed

- **WHEN** the ledger validator accepts a claim type `conjecture` that no entry's `applies` names and `unconstrained` does not list
- **THEN** the guard fails and its message names `claim_type` and `conjecture`

#### Scenario: A value cannot be both named and unconstrained

- **WHEN** `unconstrained` lists the section role `appendix` and an entry's `applies` has `section_role: [appendix]`
- **THEN** the guard fails and its message names `appendix`

##### Example: a claim type added to the ledger validator

- **GIVEN** the vocabulary of `claim_type` with one more value, `conjecture`, that no entry names and `unconstrained` does not list
- **WHEN** the accounting check runs
- **THEN** it reports a problem that names `claim_type` and `conjecture`


<!-- @trace
source: add-article-obligations
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Each entry states how it is verified

`verified_by` SHALL be a non-empty list. It SHALL be either exactly `[mechanical]` or a list drawn from the six built-in verification methods of `plugins/propositions/docs/VERIFICATION.md` (`proofread`, `lean`, `exact_certificate`, `cas`, `cross_model`, `human`); every listed method is required.

- An entry whose `check` comes from the ledger, structure, records, coverage, order or audit sources SHALL have `[mechanical]`.
- An entry with `unit: article` SHALL have `[mechanical]`, because a verification record names a proposition.
- An entry whose `check` comes from the proofread source SHALL list `proofread`.
- Every entry that lists `proofread` SHALL also list `cross_model`: each proofread layer is read by a language model, and a judgment by a language model needs a second reading by another model.

The three kinds of verification that issue 47 names are stated on each entry as follows. A check by a script is `mechanical`. A judgment by a language model is `proofread` together with `cross_model`. A prover, a certificate, a computer-algebra system and a human review are the methods of those names. A check that has to consult a source outside the manuscript's repository is marked with `external_source: true`, whether a script or a reading decides it; the mark is a key of its own for that reason, and an entry keeps it when a gap's check is supplied. Exactly three entries SHALL carry it: `truth.references-exist`, `truth.external-support-found` and `truth.external-support-agrees`. The document SHALL say which entries carry it and why it is not a value of `verified_by`.

`on_warning` SHALL be present on every entry whose `verified_by` is `[mechanical]` and absent from every other entry. Its value SHALL be `judge` or `info`, with no third value:

- `judge`: a finding that is not an error keeps the unit from passing until a judgment of it is recorded.
- `info`: a finding that is not an error is listed in the report and does not keep the unit from passing.

Until an entry can pass at all, the setting changes no outcome; a report still lists each finding that is not an error under the entry it counts for.

`on_warning: info` SHALL appear only on entries that the maintainer has reviewed for it. The guard holds the list of those entries, each named by its `id` together with its `check`: `index.proposition-is-cited` with `ledger:R3`, `index.arcs-do-not-cross` with `structure:S7`, `consistency.code-symbols-mentioned` with `audit:R3` and `completeness.bibliography-entries-cited` with `audit:R2`. Each of them SHALL have `on_warning: info`. Every other entry SHALL have `judge`, including another entry that names one of those checks, and a listed entry whose `check` has been changed.

#### Scenario: A judgment by a language model needs a second reading

- **WHEN** an entry's `verified_by` lists `proofread` without `cross_model`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A mechanical entry without a warning rule is refused

- **WHEN** an entry with `verified_by: [mechanical]` has no `on_warning`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An unreviewed entry cannot set a warning aside

- **WHEN** the entry whose `check` is `ledger:R1.5` has `on_warning: info`
- **THEN** the guard fails and its message names the entry id

#### Scenario: Another entry of a reviewed check cannot set a warning aside

- **WHEN** the obligation stating that citations form no cycle, whose `check` is `ledger:R3`, has `on_warning: info`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A warning rule on a non-mechanical entry is refused

- **WHEN** an entry with `verified_by: [proofread, cross_model]` has `on_warning: judge`
- **THEN** the guard fails and its message names the entry id

#### Scenario: The entries that need an outside source are marked

- **WHEN** the entries that carry `external_source` are listed
- **THEN** they are exactly `truth.references-exist`, `truth.external-support-found` and `truth.external-support-agrees`, and the guard fails when one of them loses the mark or another entry gains it

##### Example: the entries the maintainer reviewed

| Entry | class | on_warning |
| ----- | ----- | ---------- |
| `dependence.cites-backward` | obligation | judge |
| the entry whose `check` is `structure:S6` | obligation | judge |
| `index.arcs-do-not-cross`, `check: structure:S7` | precondition | info |
| `index.proposition-is-cited`, `check: ledger:R3` | precondition | info |
| `consistency.code-symbols-mentioned`, `check: audit:R3` | obligation | info |
| `completeness.bibliography-entries-cited`, `check: audit:R2` | obligation | info |
| the entry whose `check` is `ledger:R1.5` | precondition | judge |


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: Each entry has one of four outcomes for a unit

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define the outcome of an entry for one unit as exactly one of `not_applicable`, `unverified`, `failed` and `passed`, decided by the first rule that fits:

1. A value that `applies` needs can be read for the unit and is not in the entry's list: `not_applicable`.
2. A value that `applies` needs cannot be read for the unit: `unverified`.
3. `check` is `gap`: `unverified`.
4. `verified_by` is `[mechanical]`: `failed` when a finding that is an error counts for the unit, in a run of the check made after the last change to the files it reads; `unverified` otherwise.
5. `verified_by` lists methods: `unverified`.

No rule SHALL give `passed`. `passed` SHALL mean that the named check examined the unit and reported nothing against it, and SHALL NOT be presented as proof that the criterion holds: a check can be weaker than the criterion it serves, and that difference is corrected in the check, not by rewording the criterion to follow the code. Nothing shows today that a check examined a unit: a mechanical check does not report which units it examined (issue 68), and a verification record does not show which reading produced it or which version it read (issue 62). The condition under which an entry passes SHALL be added to this requirement and to the document by the change that implements issue 68, for mechanical entries, and by the change that implements issue 62, for entries that list methods. Until then no entry is `passed` for any unit, and the document SHALL say so and say why.

The document SHALL say, source by source and as a closed list, what a finding is and at which level:

- the three validators: a problem the validator reports as an error is an error, and one it reports as a warning is a finding that is not an error; so is each `[INFO]` line that the structure validator prints in place of an error when run with `--partial`;
- the audit scripts: a `definite` finding is an error, and a finding of any other severity (`likely`, `suspicious` or `FYI`) is a finding that is not an error;
- the reordering dry run: its report that a number of ledger lines move is an error, and its report of manuscript lines that hold several propositions is a finding that is not an error;
- the coverage check: each run of text it reports as uncovered, and each warning it prints, is a finding that is not an error. It has no error level, because a finished ledger still leaves runs uncovered (front matter and the bibliography).

A line that reports no problem, such as a pass line or a count of what was checked, is not a finding. The exit status of a check SHALL NOT be used to tell the levels apart, because the audit scripts end in failure on any finding and the coverage check ends in failure on a finished ledger.

The document SHALL say which entry a finding counts for, without leaving it to the reader. A finding counts only for entries that name the check that reported it. When one entry names that check, the finding counts for that entry. When several entries name it, the document SHALL hold a routing table that decides from what the output shows, with rows for exactly the checks that several entries name; a finding that the table does not place counts for every entry that names its check. The table SHALL place the findings as follows:

- `ledger:R1`: a finding that names a proposition whose ledger entry has a `retired` key counts for the entry on retirements, and any other for the entry on the proposition's text;
- `ledger:R3`: an error counts for the obligation on cycles, and a warning for the entry on uncited propositions;
- `structure:S4`: a finding that gives `setup` as the kind of the commitment counts for the entry on setups, and any other for the entry on commitments that have to be kept;
- `structure:S5`: a finding that says the thesis must be a non-empty list, or under `--partial` that it is not stated yet, counts for the obligation on the thesis, and any other for the precondition on the plans;
- `audit:R2`: a label inside a citation argument counts for the entry on leaked labels, a cited key with no bibliography entry for the entry on cited keys, and a bibliography entry that is never cited for the entry on uncited bibliography entries;
- `audit:R3`: a finding that says the code defines a symbol the documents never reference counts for the entry on code symbols the documents mention, and any other for the entry on references the code defines.

The document SHALL say which unit a finding counts for. Under an entry whose unit is `article`, every finding counts for the article. Under an entry whose unit is `proposition`, a finding that names a proposition the entry applies to counts for that proposition; any other finding counts for the article as a whole, which is then one more unit of that entry and of which `applies` is not asked: one that names nothing, or a retired proposition, a record, a section or a line, or a proposition the entry does not apply to. A cycle, which the ledger validator reports as an error, counts for the propositions its message lists and for the article as well, because the validator does not list every proposition that lies on a cycle.

No executable check: no program evaluates the outcome rules in this change; the tool that does belongs to the Swift package of issue 46, and a test that evaluated them would be that tool written in the wrong place. An independent reader decided the worked cases below from the data file and the document alone; the cases, the reader's answers and the commit they were decided against are recorded on issue 47. The guard checks that the routing table has rows for exactly the checks that several entries name.

#### Scenario: A reader derives the same outcome from the rules

- **WHEN** a reader who has only the data file and the document is given a unit, the findings of the checks and the verification records
- **THEN** the reader reaches the outcome that the five rules give

The twenty-four worked cases. Every check was run after the last change to the files it reads, in the mode the row gives.

| Entry | Unit and evidence | Outcome |
| ----- | ----------------- | ------- |
| the entry whose `check` is `proofread:E1` | a proposition in a ledger with the default profile | `not_applicable` |
| the entry whose `check` is `proofread:E1` | a proposition whose `evidence_class` is `external`, in a ledger with the empirical profile | `not_applicable` |
| the entry whose `check` is `proofread:E1` | a proposition of a ledger with the empirical profile whose ledger entry has no `evidence_class` | `unverified` |
| the entry whose `check` is `proofread:E1` | a proposition of a ledger with the default profile whose ledger entry has no `evidence_class` | `not_applicable` |
| `dependence.cites-backward` | a proposition that cites two others | `unverified` |
| `dependence.cites-backward` | a proposition whose `cites` list is empty | `not_applicable` |
| the entry whose `check` is `ledger:R2` | a proposition whose `cites` field is `null` | `unverified` |
| the entry whose `check` is `ledger:R2` | a proposition whose `cites` list holds one id that names no proposition; the ledger validator reports the error under R2 and names this proposition | `failed` |
| the entry whose `check` is `ledger:R2` | a proposition that cites one other; the ledger validator prints a pass line for R2 and reports nothing about this proposition | `unverified` |
| the entry whose `check` is `ledger:R2` | the ledger validator reports under R2 an error that names a retired proposition; two live propositions cite others | `failed` for the article under this entry; `unverified` for the two propositions |
| the entry whose `check` is `ledger:R2` | the ledger validator reports under R2 an error that names a retired proposition; no live proposition cites anything | `failed` for the article under this entry |
| the obligation whose `check` is `ledger:R3` | the ledger validator reports, as an error, one cycle whose message lists two propositions; a third proposition cites another and is not listed | `failed` for the two listed propositions and for the article; `unverified` for the third |
| the two entries whose `check` is `ledger:R1` | the ledger validator reports under R1 an error that names a proposition whose ledger entry has a `retired` key | `failed` for the article under the entry on retirements; the entry on the proposition's text is `unverified` for every proposition |
| the entry whose `check` is `structure:S6` | S6 warns about this announcement | `unverified` |
| the entry whose `check` is `structure:S7` | the structure validator warns that two arcs of the proposition's paragraph cross | `unverified`, with the finding listed under the entry |
| the entry whose `check` is `structure:S1` | the structure validator reports as an error a record that belongs to no ledger proposition | `failed` for the article under this entry |
| the two entries whose `check` is `structure:S5` | the structure validator reports under S5, as an error, that a record inside the abstract opens a commitment | `failed` for the article under the precondition on the plans; `unverified` under the obligation on the thesis |
| the two entries whose `check` is `structure:S5` | the structure validator reports under S5, as an error, that the thesis must be a non-empty list | `failed` for the article under the obligation on the thesis; `unverified` under the precondition on the plans |
| the entry on commitments that have to be kept, whose `check` is `structure:S4` | the structure validator, run with `--partial`, prints an `[INFO]` line that a hypothesis this proposition opens is still open | `unverified` |
| the entry whose `check` is `order:ledger` | the reordering dry run reports that three ledger lines move | `failed` for the article |
| the entry whose `check` is `audit:R1` | the symbol audit reports one finding of the severity `suspicious` | `unverified` |
| the entry whose `check` is `coverage:text` | a single-file manuscript; the coverage check, run on lines 1 to 10, reports no uncovered run | `unverified` |
| the entry whose `check` is `proofread:L4` | a proposition that cites one other; `proofread` and `cross_model` records both `supported` | `unverified` |
| the entry whose `check` is `proofread:L4` | a proposition that cites one other; the latest `proofread` record is `refuted` | `unverified` |

#### Scenario: Nothing passes before the pass condition is written

- **WHEN** the ledger validator prints a pass line for R13 and reports nothing about a proposition
- **THEN** every entry whose `check` is `ledger:R13` is `unverified` for that proposition

#### Scenario: A finding about a retired proposition is not lost

- **WHEN** the ledger validator reports under R7 an error that names a retired proposition
- **THEN** the entry whose `check` is `ledger:R7` is `failed` for the article, whether or not it applies to any live proposition

#### Scenario: A proposition that no finding names is not failed

- **WHEN** the ledger validator reports a cycle whose message lists two propositions
- **THEN** the obligation on cycles is `failed` for those two and for the article, and is not `failed` for any other proposition

#### Scenario: A draft run does not hide what is still owed

- **WHEN** the structure validator is run with `--partial` and prints an `[INFO]` line for a commitment that is still open
- **THEN** the line is a finding that is not an error, and it counts for the entry that the routing table gives for S4

#### Scenario: A record does not decide an outcome yet

- **WHEN** the `proofread` and `cross_model` records for a proposition are both `supported`
- **THEN** every entry that lists those methods is `unverified` for that proposition


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: An article is sound only when every applicable entry passes

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define a sound article as one for which every entry has the outcome `passed` or `not_applicable` for every unit, and SHALL add no condition outside the table. The units of an entry include the article wherever a finding counts for the article under it. A verdict against a proposition from a method that no entry lists SHALL count through an entry of its own, `truth.not-refuted`, which states that no method's most recent verdict on the proposition is `refuted` or `partial`, where an `unresolved` or `not_attempted` record replaces no earlier verdict; that entry SHALL be a gap owned by issue 62 until a check reports it. It SHALL state that an `unverified` outcome counts against soundness in the same way as `failed`, and that while any precondition entry is `failed` or `unverified` the outcomes of obligation entries are not to be trusted until the ledger, sidecars or records are corrected; those outcomes are left as computed. It SHALL state what a report names: for each outcome that is `failed` or `unverified`, the entry and the unit, and each finding that is listed as information.

The document SHALL state that no article is sound yet and SHALL list the four reasons with the issue that owns each: entries whose `check` is `gap`, each owned by the issue in its `owner`; checks that do not report which units they examined (issue 68, which takes in issue 63), so that no mechanical entry passes until that issue is implemented and the pass condition is written; verification records that cannot say what they cover (issue 62), so that no entry that lists methods passes until that issue is implemented and the pass condition is written, and a warning under `on_warning: judge` has no place where a judgment is recorded; and `cross_model` records, which no tool produces yet (issue 21). It SHALL also state the limits that remain for some manuscripts once checks report what they examine: the reading-order check runs on single-file manuscripts only (issue 59); the symbol audit and the citation audit read the main file only, and the citation audit reads one bibliography file of a fixed name (issue 69); and the audit's code pass needs a directory of analysis code (issue 64). It SHALL state that numbers are compared with artifacts only in a ledger with the empirical profile, and that whether a ledger's profile fits its manuscript is a precondition that has no check yet (issue 70).

No executable check: soundness is a definition that the document states for readers and for later tools, and nothing in this change computes it. The guard checks only that the document names the four outcomes and the issues that own the reasons no article is sound yet.

#### Scenario: A forward-citation warning keeps an article from being sound

- **WHEN** every other entry has passed and one proposition is `unverified` under `dependence.cites-backward`
- **THEN** the article is not sound, and the report names that entry and that proposition

#### Scenario: A finding listed as information is not a reason to fail

- **WHEN** the structure validator reports crossing arcs for the entry whose `check` is `structure:S7`
- **THEN** the finding is listed under that entry and the entry is not `failed` because of it

#### Scenario: A verdict from a method that no entry lists is not lost

- **WHEN** the latest `lean` record for one proposition is `refuted` and no entry lists `lean` in `verified_by`
- **THEN** the verdict counts under `truth.not-refuted`, which is `unverified` while its `check` is `gap` and `failed` for that proposition once a check reports it

#### Scenario: A failed precondition is corrected first

- **WHEN** the entry whose `check` is `ledger:R1` is `failed` for one proposition
- **THEN** the article is not sound, and the outcomes of the obligation entries are marked as not to be trusted


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: The explanatory document describes the table without restating it

`plugins/propositions/docs/OBLIGATIONS.md` SHALL describe the keys of the data file, the two classes and how to tell them apart, the seven groups and their axioms, how applicability is stated and what happens when a value cannot be read, which checks count as implemented and why the excluded ones are excluded, what the fields of a gap mean, which entries need an external source, what counts as a finding for each source, which entry it counts for (with the routing table for the checks that several entries name) and which unit, the four outcomes, why no entry passes yet, soundness, the reasons no article is sound yet, and how to add or change an entry. It SHALL NOT list the entries: it SHALL mention at most two entry ids, as examples.

`plugins/propositions/docs/VERIFICATION.md` SHALL say that its description of a `supported` proofread record is of the derivation walk, that a record does not say which walk produced it, that whether a record counts toward an article being sound is decided by `plugins/propositions/docs/OBLIGATIONS.md`, and that its rule of taking each method's latest record serves the disagreement warning only. It SHALL NOT change the record format.

#### Scenario: A copy of the table in the document is refused

- **WHEN** the document mentions three or more entry ids of the data file
- **THEN** the guard fails and its message gives the number found

##### Example: a document that names three entries

- **GIVEN** a table with three entries and a document whose text contains the ids of all three
- **WHEN** the document check runs
- **THEN** it reports a problem that gives the number 3

#### Scenario: The document says why a defined layer is a gap

- **WHEN** a reader looks up why the proofread layer E9 is a gap
- **THEN** the document says that the walk of the proofread skill does not list E8, E9 and E10, so a verdict does not show that they were read


<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->

---
### Requirement: A guard checks the table

The repository SHALL have automated tests that fail when the data file or the document breaks any requirement above that can be decided from their text: the closed keys, the two classes and their prefixes, the groups, applicability, the inventory and owners, the accounting of checks and vocabulary values, `verified_by` and `on_warning`, the entries that need an outside source, the entries the maintainer reviewed, the limit on entry ids in the document, and that the document's routing table has rows for exactly the checks that several entries name. A key that is present SHALL hold what the key requires: the guard SHALL refuse `applies` or `axiom` written with no value. The guard SHALL refuse a data file in which one mapping holds the same key twice, because a YAML loader keeps the last value and drops the first without a message. Each failure message SHALL name the entry, value or check concerned. The tests are cases in `tests/test_plugin_payload_tracked.py` whose names start with `test_obligations_`; a change to this capability SHALL add no test file and no script module. A change is accepted only when these cases pass; a skipped case does not count.

The guard is written in Python while the vocabularies it reads are defined in the Python validators. The project rule on the implementation language records this as an exception that ends when the Swift package of issue 46 exists and the vocabularies have a Swift source; the guard then moves to that package's test target.

#### Scenario: The guard runs with the suite

- **WHEN** the repository's test suite runs
- **THEN** the cases whose names start with `test_obligations_` run and pass on the committed data file and document

#### Scenario: The guard reads the vocabularies from their source

- **WHEN** the structure validator gains a section role
- **THEN** the guard fails until an entry names the new role or `unconstrained` lists it, without the guard itself being edited

##### Example: an entry with the same key twice

- **GIVEN** the text of a data file in which one entry has two `check:` lines
- **WHEN** the guard loads it
- **THEN** loading fails and the message names `check`

##### Example: a section role added to the structure validator

- **GIVEN** the vocabulary of `section_role` with one more value, `afterword`, that no entry names and `unconstrained` does not list
- **WHEN** the accounting check runs
- **THEN** it reports a problem that names `section_role` and `afterword`

<!-- @trace
source: idd-47-fix3
updated: 2026-11-12
code:
  - propositions-projects.code-workspace
-->