## Purpose

The article obligations table states, one entry at a time, what a manuscript's ledger and sidecars have to get right and what the article owes its reader, and names the check that verifies each entry. It exists so that "the article is sound" has a single definition that later tools and skills evaluate in the same way.

## ADDED Requirements

### Requirement: The obligations table is a closed data file

`plugins/propositions/catalog/obligations.yaml` SHALL be a YAML mapping with exactly three keys: `groups`, `entries` and `unconstrained`. Each item of `entries` SHALL be a mapping whose keys come from this closed set: `id`, `class`, `group`, `unit`, `applies`, `criterion`, `check`, `owner`, `verified_by`, `on_warning`. Any other top-level key or entry key SHALL be an error.

`id` SHALL have the form `<prefix>.<name>`, where both parts consist of lowercase letters, digits and hyphens, and SHALL be unique in the file. `unit` SHALL be `proposition` or `article`. A `proposition` unit is a proposition of the ledger that is not retired; a retired proposition is not a unit. The `article` unit is the manuscript as a whole. `criterion` SHALL be one line of at most 200 characters stating what has to hold; the definition of the check it points to stays in that check's own document.

#### Scenario: An unknown entry key is refused

- **WHEN** an entry has a key named `example`
- **THEN** the guard fails and its message names the entry id and the key

#### Scenario: A repeated id is refused

- **WHEN** two entries have the id `dependence.cites-backward`
- **THEN** the guard fails and its message names `dependence.cites-backward`

#### Scenario: A criterion that copies a definition is refused

- **WHEN** an entry's `criterion` spans two lines or is longer than 200 characters
- **THEN** the guard fails and its message names the entry id

### Requirement: Entries are preconditions or obligations

`class` SHALL be `precondition` or `obligation`. There is no third class.

- A `precondition` entry is one whose failure is corrected in the ledger, a structure sidecar or the verification records.
- An `obligation` entry is one whose failure is corrected in the manuscript, or needs a decision by the author.

The class SHALL be written on each entry. It SHALL NOT be derived from which tool runs the check. When one check covers both a precondition and an obligation, the file SHALL hold one entry for each, naming the same check. The `id` prefix SHALL be `index` for a precondition and the group id for an obligation.

A finding that the maintainer has reviewed as information only (crossing arcs under S7, an uncited proposition under R3, a code symbol that the documents never mention under the audit's R3, and a bibliography entry that is never cited under the audit's R2) SHALL have its own entry with one of the two classes, chosen by what would be corrected if the finding were acted on, and `on_warning: info`.

#### Scenario: One check is split by what gets corrected

- **WHEN** the entries whose `check` is `structure:S5` are listed
- **THEN** one of them is an obligation stating that the article names the propositions that carry its thesis, and another is a precondition stating that the section and paragraph plans are well formed

#### Scenario: A third class is refused

- **WHEN** an entry has `class: information`
- **THEN** the guard fails and its message names the entry id and `information`

##### Example: the two entries for the citation graph

- **GIVEN** the ledger validator reports a cycle in `cites` as an error and an uncited proposition as a warning, both under R3
- **WHEN** the entries whose `check` is `ledger:R3` are listed
- **THEN** there are at least two: an obligation in the group `dependence` stating that citations form no cycle, with `on_warning: judge`, and an entry for the uncited proposition with `on_warning: info`

### Requirement: Obligations are grouped by principle

`groups` SHALL list exactly these seven groups, in this order: `dependence`, `commitment`, `support`, `consistency`, `truth`, `placement`, `completeness`. Each group SHALL have `id`, `zh` (a Traditional Chinese label) and `does` (one English sentence saying what the group protects). `axiom` is optional and, when present, SHALL name one axiom of the che-axiom-systems plugin as `<domain>/<axiom id>`. A group SHALL name at most one axiom. The group `dependence` SHALL name `academic-writing/A1_no_forward_dependence`. The file SHALL NOT restate the text of an axiom.

Every obligation entry SHALL name one of the seven groups in `group`. A precondition entry SHALL NOT have `group`.

#### Scenario: An obligation without a group is refused

- **WHEN** an entry has `class: obligation` and no `group`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An eighth group is refused

- **WHEN** `groups` has an item with the id `style`
- **THEN** the guard fails and its message names `style`

### Requirement: Applicability is a list of field values

`applies` is optional. When present it SHALL be a mapping whose keys come from this closed set: `profile`, `claim_type`, `evidence_class`, `cites`, `opens`, `section_role`. Each value SHALL be a non-empty list. A proposition satisfies `applies` when, for every key present, its own value is in the list:

- `profile`: the profile of its ledger;
- `claim_type`, `evidence_class`: its fields in the ledger;
- `cites`: `present` when it cites at least one proposition, otherwise `absent`;
- `opens`: it opens at least one commitment of a listed kind;
- `section_role`: the role of the section that contains it.

An entry without `applies` applies to every unit. An entry with `unit: article` SHALL use no key other than `profile`. The file SHALL have no other way to state applicability: no negation and no alternative between keys. Every listed value SHALL belong to the vocabulary of its field: the accepted profiles and the claim types and evidence classes of every profile in the ledger validator, and the commitment kinds and section roles in the structure validator. Fields that the sidecars leave optional (the move, the paragraph type and the relation) SHALL NOT be keys, because an unannotated proposition would then be treated as not applicable.

Every entry whose `check` is one of `proofread:E1` to `proofread:E7`, and each of the three entries whose `owner` is 57, SHALL have `applies` with `profile: [empirical]`: the empirical walk of the proofread skill uses vocabulary that only the empirical profile accepts, and without this limit every proposition of a manuscript with the default profile stays `unverified` under those entries.

#### Scenario: An entry applies only where every key matches

- **WHEN** an entry has `applies` with `profile: [empirical]` and `claim_type: [result]`
- **THEN** it applies to a `result` proposition in an empirical ledger and to no proposition in a ledger with the default profile

#### Scenario: A value outside the vocabulary is refused

- **WHEN** an entry lists `claim_type: [lemma]`
- **THEN** the guard fails and its message names the entry id and `lemma`

#### Scenario: An empirical layer without the profile limit is refused

- **WHEN** an entry with `check: proofread:E3` has no `applies`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An optional sidecar field is refused as a key

- **WHEN** an entry's `applies` has the key `move`
- **THEN** the guard fails and its message names the entry id and `move`

### Requirement: A check is named only when it is implemented

`check` SHALL be either `gap` or one id from the inventory below. The inventory is closed, has 44 ids, and is the normative list; what its members have in common is that each reports a finding or leaves a record for a unit without changing any file.

- `ledger:R1`, `ledger:R1.5`, `ledger:R2`, `ledger:R3`, `ledger:R4`, `ledger:R7`, `ledger:R8`, `ledger:R9`, `ledger:R10`, `ledger:R11`, `ledger:R12`, `ledger:R13`, reported by the ledger validator;
- `structure:S1` to `structure:S9`, reported by the structure validator;
- `records:V1` to `records:V6`, reported by the verification records validator;
- `coverage:text`, the extraction coverage check;
- `order:ledger`, the dry run of the ledger reordering tool, which reports whether the ledger's line order is the reading order;
- `audit:R1`, `audit:R2`, `audit:R3`, the three scripts of the cross-artifact audit;
- `proofread:L1` to `proofread:L5` and `proofread:E1` to `proofread:E7`, the layers listed in the per-proposition walk of the proofread skill.

The following SHALL NOT be inventory ids: the fourth pass of the cross-artifact audit (it runs the ledger validator); the theorem-boundary audit and the dry run of the location refresh (the same checks as `ledger:R9` and `ledger:R13`); the link catalog's currency check (its subject is a file of the plugin, not a manuscript); the checks of the `tschema-check` plugin; the stumble categories of the clarity audit, the counts in the construct skill's summary and the states of the analyze skill (none of them leaves a finding or a record for a unit under an id); and the proofread layers E8, E9 and E10 (defined in the layer table but absent from the walk, so a verdict does not show that they were read).

A change that implements a new check SHALL add its id to this inventory and to the guard in the same change. When `check` is `gap`, the entry SHALL have `owner`, the number of the issue in this repository that will supply the check. When `check` is an inventory id, the entry SHALL NOT have `owner`. Exactly three entries SHALL have `owner: 57`, one for each of the layers E8, E9 and E10. At least one entry SHALL have each of the owners 46, 49, 50 and 55.

#### Scenario: A layer that is defined but not walked is a gap

- **WHEN** the entries whose `owner` is 57 are listed
- **THEN** there are exactly three, each has `check: gap`, and each `verified_by` lists `proofread` and `cross_model`

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

### Requirement: Each entry states how it is verified

`verified_by` SHALL be a non-empty list. It SHALL be either exactly `[mechanical]` or a list drawn from the six built-in verification methods of `plugins/propositions/docs/VERIFICATION.md` (`proofread`, `lean`, `exact_certificate`, `cas`, `cross_model`, `human`); every listed method is required.

- An entry whose `check` comes from the ledger, structure, records, coverage, order or audit sources SHALL have `[mechanical]`.
- An entry with `unit: article` SHALL have `[mechanical]`, because a verification record names a proposition.
- An entry whose `check` comes from the proofread source SHALL list `proofread`.
- Every entry that lists `proofread` SHALL also list `cross_model`: each proofread layer is read by a language model, and a judgment by a language model needs a second reading by another model.

`on_warning` SHALL be present on every entry whose `verified_by` is `[mechanical]` and absent from every other entry. Its value SHALL be `judge` or `info`, with no third value:

- `judge`: a finding that is not an error leaves the entry unverified until someone judges it.
- `info`: a finding that is not an error is listed in the report and the entry passes.

`on_warning: info` SHALL appear only on entries that the maintainer has reviewed for it. The guard holds the list of those entries, each named by its `id` together with its `check`: `index.proposition-is-cited` with `ledger:R3`, `index.arcs-do-not-cross` with `structure:S7`, `consistency.code-symbols-mentioned` with `audit:R3` and `completeness.bibliography-entries-cited` with `audit:R2`. Each of them SHALL have `on_warning: info`. Every other entry SHALL have `judge`, including another entry that names one of those checks, and a listed entry whose `check` has been changed.

#### Scenario: A judgment by a language model needs a second reading

- **WHEN** an entry's `verified_by` lists `proofread` without `cross_model`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A mechanical entry without a warning rule is refused

- **WHEN** an entry with `verified_by: [mechanical]` has no `on_warning`
- **THEN** the guard fails and its message names the entry id

#### Scenario: An unreviewed entry cannot pass on a warning

- **WHEN** the entry whose `check` is `ledger:R1.5` has `on_warning: info`
- **THEN** the guard fails and its message names the entry id

#### Scenario: Another entry of a reviewed check cannot pass on a warning

- **WHEN** the obligation stating that citations form no cycle, whose `check` is `ledger:R3`, has `on_warning: info`
- **THEN** the guard fails and its message names the entry id

#### Scenario: A warning rule on a non-mechanical entry is refused

- **WHEN** an entry with `verified_by: [proofread, cross_model]` has `on_warning: judge`
- **THEN** the guard fails and its message names the entry id

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

### Requirement: Each entry has one of four outcomes for a unit

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define the outcome of an entry for one unit as exactly one of `not_applicable`, `unverified`, `failed` and `passed`, decided by the first rule that fits:

1. The unit does not satisfy `applies`: `not_applicable`.
2. `check` is `gap`: `unverified`.
3. `verified_by` is `[mechanical]`: `unverified` when the check has not been run on the current files; `failed` when it reports an error for the unit; when it reports a finding that is not an error, `unverified` under `on_warning: judge` and `passed` under `on_warning: info`, with the finding listed as information; `passed` when it reports nothing for the unit. The levels are the check's own. An error is an error of a validator, a `definite` finding of an audit script, or a line that the reordering dry run reports as out of place. A finding that is not an error is a warning of a validator, a `likely` or `FYI` finding of an audit script, a run of text that the coverage check reports as uncovered, or the reordering dry run's report of propositions that share a line. The coverage check has no error level: a finished ledger still leaves runs uncovered (front matter, headings, the bibliography), so each run is judged, and a run judged to be a sentence of the body fails the entry. A status line or a summary that names no unit is not a finding. The exit status of a check SHALL NOT be used to tell the two apart, because the audit scripts end in failure on any finding and the coverage check ends in failure on a finished ledger.

   A check has not been run for a unit in these six cases and no others: it was not executed after the last change to a file it reads; it ended with a tool error; it reports that it skipped the rule because the ledger's schema version predates the rule or the ledger's profile is invalid; it lists the unit as one it could not examine, or reports only how many units it skipped, in which case the entry is `unverified` for every unit it applies to; the structure validator was run with `--partial`; or, for the coverage check, a part of the manuscript's body was in no range it was run on, the body being the main file between the beginning and the end of the document and the whole of every other file of the input tree. The ledger validator's report that the manuscript has no theorem-like environment is not a skip: the entry for R9 passes for a proposition that is not assigned to a theorem-like block and is `unverified` for one that is.
4. `verified_by` lists methods: take, for each method, the latest record for the proposition as the verification records define latest. `failed` when any of them is `refuted` or `partial`; `passed` when all of them are `supported` and each of them covers the entry's check; otherwise `unverified`.

The document SHALL state what a record covers. A record covers a check when the reading that produced it performed that check. The proofread skill has two walks, a derivation walk that lists the L layers and an empirical walk that lists the E layers, and neither includes the other; a record does not name its walk, so the walk is read from the checklist that the record's `evidence_ref` points to, and a record whose walk cannot be established covers no layer.

The document SHALL also state two limits. First, a verification record names a proposition and a method and not an entry, so a `refuted` or `partial` record fails every entry verified by that method for the proposition. Second, when several entries name the same check, a finding counts for the entry whose `criterion` it violates, and deciding that is a judgment by the reader until checks report to entries.

#### Scenario: A reader derives the same outcome from the rules

- **WHEN** a reader who has only the data file and the document is given a unit, the findings of the checks and the verification records
- **THEN** the reader reaches the outcome that the four rules give

##### Example: ten units

| Entry | Unit and evidence | Outcome |
| ----- | ----------------- | ------- |
| an entry with `check: proofread:E1` and `applies` with `profile: [empirical]` | a `claim` in a ledger with the default profile | `not_applicable` |
| `dependence.cites-backward` | a proposition that cites two others | `unverified` |
| `dependence.cites-backward` | a proposition that cites nothing | `not_applicable` |
| `check: structure:S6`, `on_warning: judge` | S6 warns about this announcement | `unverified` |
| `check: structure:S6`, `on_warning: judge` | the structure validator ran and S6 reports nothing for it | `passed` |
| `check: structure:S7`, `on_warning: info` | the structure validator reports that two arcs cross | `passed`, with the finding listed as information |
| `check: proofread:L4` | latest `proofread` record `supported` from the derivation walk, no `cross_model` record | `unverified` |
| `check: proofread:L4` | `proofread` and `cross_model` records both `supported`; the checklist behind the `proofread` record is from the empirical walk | `unverified` |
| `check: proofread:L1` and `check: proofread:L4` | latest `proofread` record `partial` | `failed` for both |
| `check: proofread:L4` | `proofread` `supported`, `cross_model` `refuted` | `failed` |

#### Scenario: A warning never passes by default

- **WHEN** an entry with `on_warning: judge` names a check that reports a warning for a unit
- **THEN** the outcome is `unverified`, whether or not the check reported warnings when the entry was written

### Requirement: An article is sound only when every applicable entry passes

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define a sound article as one for which every entry has the outcome `passed` or `not_applicable` for every unit, and for which the latest record of no method is `refuted` or `partial` for any proposition, whether or not an entry lists that method. It SHALL state that an `unverified` outcome counts against soundness in the same way as `failed`, and that while any precondition entry is `failed` or `unverified` the outcomes of obligation entries are not to be trusted until the ledger, sidecars or records are corrected.

The document SHALL state that no article is sound yet and SHALL list the three reasons with the issue that owns each: entries whose `check` is `gap`, each owned by the issue in its `owner`; verification records that cannot say what they cover, namely a warning under `on_warning: judge`, for which there is no place to record a judgment, and a `proofread` record, which does not name its walk; and `cross_model` records, which no tool produces yet (issue 21). It SHALL also state that the reading-order check runs on single-file manuscripts only, so its entry stays `unverified` for a multi-file manuscript (issue 59), and that the audit's code pass needs a directory of analysis code, so its two entries stay `unverified` for a manuscript that has none (issue 64).

#### Scenario: A forward-citation warning keeps an article from being sound

- **WHEN** every other entry has passed and one proposition is `unverified` under `dependence.cites-backward`
- **THEN** the article is not sound, and the report names that entry and that proposition

#### Scenario: A finding listed as information does not change the result

- **WHEN** every entry is `passed` or `not_applicable` and the structure validator reports crossing arcs for the entry whose `check` is `structure:S7`
- **THEN** the article is sound

#### Scenario: A verdict against a proposition keeps an article from being sound

- **WHEN** every entry is `passed` or `not_applicable` and the latest `lean` record for one proposition is `refuted`
- **THEN** the article is not sound, and the report names that proposition and that method

#### Scenario: A failed precondition is corrected first

- **WHEN** the entry whose `check` is `ledger:R1` is `failed` for one proposition
- **THEN** the article is not sound, and the outcomes of the obligation entries are marked as not to be trusted

### Requirement: The explanatory document describes the table without restating it

`plugins/propositions/docs/OBLIGATIONS.md` SHALL describe the keys of the data file, the two classes and how to tell them apart, the seven groups and their axioms, how applicability is stated, which checks count as implemented and why the excluded ones are excluded, the four outcomes, soundness, the reasons no article is sound yet, and how to add or change an entry. It SHALL NOT list the entries: it SHALL mention at most two entry ids, as examples.

#### Scenario: A copy of the table in the document is refused

- **WHEN** the document mentions three or more entry ids of the data file
- **THEN** the guard fails and its message gives the number found

#### Scenario: The document says why a defined layer is a gap

- **WHEN** a reader looks up why the proofread layer E9 is a gap
- **THEN** the document says that the walk of the proofread skill does not list E8, E9 and E10, so a verdict does not show that they were read

### Requirement: A guard checks the table

The repository SHALL have automated tests that fail when the data file or the document breaks any requirement above that can be decided from their text: the closed keys, the two classes and their prefixes, the groups, applicability, the inventory and owners, the accounting of checks and vocabulary values, `verified_by` and `on_warning`, the entries the maintainer reviewed, and the limit on entry ids in the document. Each failure message SHALL name the entry, value or check concerned. In this change the tests are cases in `tests/test_plugin_payload_tracked.py` whose names start with `test_obligations_`; the change SHALL add no test file and no script module. The change is accepted only when these cases pass; a skipped case does not count.

#### Scenario: The guard runs with the suite

- **WHEN** the repository's test suite runs
- **THEN** the cases whose names start with `test_obligations_` run and pass on the committed data file and document

#### Scenario: The guard reads the vocabularies from their source

- **WHEN** the structure validator gains a section role
- **THEN** the guard fails until an entry names the new role or `unconstrained` lists it, without the guard itself being edited
