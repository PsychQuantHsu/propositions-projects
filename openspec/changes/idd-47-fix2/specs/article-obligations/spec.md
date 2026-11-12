## MODIFIED Requirements

### Requirement: Entries are preconditions or obligations

`class` SHALL be `precondition` or `obligation`. There is no third class.

- A `precondition` entry is one whose failure is corrected in the ledger, a structure sidecar or the verification records.
- An `obligation` entry is one whose failure is corrected in the manuscript, or needs a decision by the author.

The class SHALL be written on each entry. It SHALL NOT be derived from which tool runs the check. When one check covers both a precondition and an obligation, the file SHALL hold one entry for each, naming the same check. The `id` prefix SHALL be `index` for a precondition and the group id for an obligation.

A finding that the maintainer has reviewed as information only (crossing arcs under S7, an uncited proposition under R3, a code symbol that the documents never mention under the audit's R3, and a bibliography entry that is never cited under the audit's R2) SHALL have its own entry with one of the two classes, chosen by what would be corrected if the finding were acted on, and `on_warning: info`.

#### Scenario: One check is split by what gets corrected

- **WHEN** the entries whose `check` is `structure:S5` are listed
- **THEN** one of them is an obligation stating that the structure sidecar names at least one proposition as the article's thesis, and another is a precondition stating that the section and paragraph plans are well formed

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

### Requirement: Applicability is a list of field values

`applies` is optional. When present it SHALL be a mapping whose keys come from this closed set: `profile`, `claim_type`, `evidence_class`, `cites`, `opens`, `section_role`. Each value SHALL be a non-empty list. A proposition satisfies `applies` when, for every key present, its own value is in the list:

- `profile`: the profile of its ledger;
- `claim_type`, `evidence_class`: its fields in the ledger;
- `cites`: `present` when its `cites` list is not empty, otherwise `absent`; an id in the list that names no proposition still makes it `present`;
- `opens`: it opens at least one commitment of a listed kind;
- `section_role`: the role of the section that contains it.

When the value a key needs cannot be read for a unit, the entry SHALL be `unverified` for that unit and not `not_applicable`. A value cannot be read when the ledger declares a profile that the validator rejects (a ledger that declares none has the default profile); when the proposition's ledger entry has no `claim_type` or no `evidence_class` and the key asks for that field; and, for `opens` and `section_role`, when the proposition has no record in the discourse sidecar or the section plan is missing or invalid. A proposition whose record opens nothing has a value: it opens no commitment.

An entry without `applies` applies to every unit. An entry with `unit: article` SHALL use no key other than `profile`, and for the article `profile` is the profile of the manuscript's ledger. The file SHALL have no other way to state applicability: no negation and no alternative between keys. Every listed value SHALL belong to the vocabulary of its field: the accepted profiles and the claim types and evidence classes of every profile in the ledger validator, and the commitment kinds and section roles in the structure validator. The move and the paragraph type SHALL NOT be keys: the sidecars leave them optional, so an unannotated proposition would be treated as not applicable. `opens` is optional too and is a key, which is why the table holds the precondition `index.structure-faithful`.

Every entry whose `check` is one of `proofread:E1` to `proofread:E7`, and each of the three entries whose `owner` is 57, SHALL have `applies` with exactly two keys: `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`. Those four classes mark a claim made about data. The proofread skill says that its layers E1 to E8 do not apply to an `external` proposition, which has no artifact to re-run, and the table gives the entries for E9 and E10 the same limit. `not_computable` is one of the four because it marks a quantity the data cannot produce, which the entry for E2 is there to fail. Without the profile, every proposition of a manuscript with the default profile stays `unverified` under those entries; without the evidence classes, every proposition without an artifact does. A proposition of an empirical ledger that carries any other evidence class is outside these entries, also when its text interprets data; whether its class is right is decided under the entry whose `check` is `proofread:L5`.

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

### Requirement: Each entry has one of four outcomes for a unit

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define the outcome of an entry for one unit as exactly one of `not_applicable`, `unverified`, `failed` and `passed`, decided by the first rule that fits:

1. A value that `applies` needs cannot be read for the unit: `unverified`.
2. The unit does not satisfy `applies`: `not_applicable`.
3. `check` is `gap`: `unverified`.
4. `verified_by` is `[mechanical]`. Only a run of the check made after the last change to every file it reads counts. With no such run the outcome is `unverified`. Otherwise it is `failed` when a finding that is an error counts for the unit. When a finding that is not an error counts for the unit, the outcome under `on_warning: judge` is `unverified` until a judgment of that finding is recorded, after which a judgment that the criterion is violated makes it `failed` and a judgment that it is not makes the finding stop counting; under `on_warning: info` the finding is listed as information and does not count. When no finding counts, the outcome is `passed` if the report of the run lists the unit among those the check examined, and `unverified` in every other case.
5. `verified_by` lists methods: `failed` when a record that counts is `refuted` or `partial`; `passed` when, for every listed method, a record that counts is `supported`; `unverified` in every other case.

`passed` SHALL mean that the named check examined the unit and reported nothing against it. It SHALL NOT be presented as proof that the criterion holds: a check can be weaker than the criterion it serves, and that difference is corrected in the check, not by rewording the criterion to follow the code.

A report lists a unit as examined when it names the proposition as one the check examined or, for the article, names every file of the manuscript's input tree as read. A line that says a rule passed, or that gives a count, lists no unit. No check of the inventory lists the units it examined, so no mechanical entry is `passed` for any unit until issue 68 changes what the checks report; the document SHALL say so and SHALL NOT replace this rule with a list of the cases in which a check counts as not run, because a unit that such a list misses would pass unexamined.

The document SHALL say, source by source and as a closed list, what a finding is and at which level:

- the three validators: a problem the validator reports as an error is an error, and one it reports as a warning is a finding that is not an error;
- the audit scripts: a `definite` finding is an error, and a finding of any other severity (`likely`, `suspicious` or `FYI`) is a finding that is not an error;
- the reordering dry run: its report that a number of ledger lines move is an error, and its report of manuscript lines that hold several propositions is a finding that is not an error;
- the coverage check: each run of text it reports as uncovered, and each warning it prints, is a finding that is not an error. It has no error level: a finished ledger still leaves runs uncovered (front matter, headings, the bibliography), so each run is judged, and a run judged to be text of the body that no proposition holds fails the entry.

A line that reports no problem, such as a pass line or a count of what was checked, is not a finding. The exit status of a check SHALL NOT be used to tell the levels apart, because the audit scripts end in failure on any finding and the coverage check ends in failure on a finished ledger.

The document SHALL say which entry and which unit a finding counts for, so that every finding counts for at least one unit of at least one entry:

- a finding counts for the entry whose `criterion` it concerns, also when the script itself calls the finding harmless; a finding that concerns the criterion of no entry, or for which the reader cannot decide between several entries that name the same check, counts for every entry that names its check;
- under an entry whose unit is `article`, every finding counts for the article;
- under an entry whose unit is `proposition`, a finding that names a proposition the entry applies to counts for that proposition, and every other finding counts for every unit the entry applies to: one that names nothing, or a retired proposition, a record, a section or a line, or a proposition the entry does not apply to. A cycle that the ledger validator reports is counted this way too, because the validator does not list every proposition that lies on a cycle.

The document SHALL state when a record counts. A record counts for an entry only when the record itself shows that the reading or computation that produced it performed the entry's check, and that it was made on the present version of everything that check reads: the proposition's ledger entry, the entries of the propositions it cites, the manuscript and, for the empirical layers, the artifacts. A record of today's format shows neither: it names no walk and no layer, its `checked_at` is by default the day the record was converted and not the day of the reading, it holds no version of what was read, and its `evidence_ref` points to a checklist that both walks of the proofread skill write to the same path. No record therefore counts, and every entry that lists methods is `unverified` for every unit it applies to, until issue 62 changes what a record holds; the document SHALL say so. The proofread skill has two walks, a derivation walk that lists the L layers and an empirical walk that lists the E layers, and neither includes the other, so a `supported` record from one walk does not cover a layer of the other.

The document SHALL also state one limit that remains once records count: a verification record names a proposition and a method and not an entry, so a `refuted` or `partial` record fails every entry of that method whose check the record shows it performed, preconditions and obligations alike.

No executable check: no program evaluates the outcome rules in this change; the tool that does belongs to the Swift package of issue 46, and a test that evaluated them would be that tool written in the wrong place. An independent reader decided the worked cases below from the data file and the document alone; the cases, the reader's answers and the commit they were decided against are recorded on issue 47.

#### Scenario: A reader derives the same outcome from the rules

- **WHEN** a reader who has only the data file and the document is given a unit, the findings of the checks and the verification records
- **THEN** the reader reaches the outcome that the five rules give

The twenty worked cases. Unless a row says otherwise, every check was run after the last change to the files it reads, its report is in the form the checks print today, and every record is in today's format.

| Entry | Unit and evidence | Outcome |
| ----- | ----------------- | ------- |
| the entry whose `check` is `proofread:E1` | a proposition in a ledger with the default profile | `not_applicable` |
| the entry whose `check` is `proofread:E1` | a proposition whose `evidence_class` is `external`, in a ledger with the empirical profile | `not_applicable` |
| the entry whose `check` is `proofread:E1` | a proposition of a ledger with the empirical profile whose ledger entry has no `evidence_class` | `unverified` |
| `dependence.cites-backward` | a proposition that cites two others | `unverified` |
| `dependence.cites-backward` | a proposition whose `cites` list is empty | `not_applicable` |
| the entry whose `check` is `ledger:R2` | a proposition whose `cites` list holds one id that names no proposition; the ledger validator reports the error under R2 and names this proposition | `failed` |
| the entry whose `check` is `ledger:R2` | a proposition that cites one other; the ledger validator prints a pass line for R2 and reports nothing about this proposition | `unverified` |
| the entry whose `check` is `ledger:R2` | the ledger validator reports under R2 an error that names a retired proposition | `failed` for every proposition the entry applies to |
| the obligation whose `check` is `ledger:R3` | the ledger validator reports one cycle whose message lists two propositions; the unit is a third proposition that cites another | `failed` |
| the entry whose `check` is `structure:S6` | S6 warns about this announcement | `unverified` |
| the entry whose `check` is `structure:S7` | the structure validator warns that two arcs of the proposition's paragraph cross | `unverified`, with the finding listed as information |
| the entry whose `check` is `structure:S7` | a report that lists the proposition as examined and warns that two arcs of its paragraph cross | `passed`, with the finding listed as information |
| the entry whose `check` is `structure:S1` | the structure validator reports as an error a record that belongs to no ledger proposition | `failed` for every proposition |
| the two entries whose `check` is `structure:S5` | the structure validator reports under S5, as an error, that a record inside the abstract opens a commitment | `failed` for the article under both entries |
| the entry whose `check` is `order:ledger` | the reordering dry run reports that three ledger lines move | `failed` for the article |
| the entry whose `check` is `audit:R1` | the symbol audit reports one finding of the severity `suspicious` | `unverified` |
| the two entries whose `check` is `audit:R3` | the code pass reports as `FYI` that the documents refer to a name the code does not define, which is a label of the manuscript | `unverified` for the entry on references the code does not define; the finding is not information under the other entry |
| the entry whose `check` is `ledger:R13` | a report that lists the proposition as examined and has no finding for it | `passed` |
| the entry whose `check` is `proofread:L4` | a proposition that cites one other; `proofread` and `cross_model` records both `supported` | `unverified` |
| the entry whose `check` is `proofread:L4` | a proposition that cites one other; the latest `proofread` record is `refuted` | `unverified` |

#### Scenario: A warning never passes by default

- **WHEN** an entry with `on_warning: judge` names a check that reports a warning for a unit
- **THEN** the outcome is `unverified`, whether or not the check reported warnings when the entry was written

#### Scenario: A pass line does not pass a unit

- **WHEN** the ledger validator prints a pass line for R13 and names no proposition as examined
- **THEN** every entry whose `check` is `ledger:R13` is `unverified` for every proposition for which no finding counts

#### Scenario: A finding about a retired proposition is not lost

- **WHEN** the ledger validator reports under R7 an error that names a retired proposition
- **THEN** the entry whose `check` is `ledger:R7` is `failed` for every proposition it applies to

#### Scenario: A record of today's format does not count

- **WHEN** the `proofread` and `cross_model` records for a proposition are both `supported` and neither shows the walk that produced it or the version it read
- **THEN** every entry that lists those methods is `unverified` for that proposition

### Requirement: An article is sound only when every applicable entry passes

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define a sound article as one for which every entry has the outcome `passed` or `not_applicable` for every unit, and SHALL add no condition outside the table. A verdict against a proposition from a method that no entry lists SHALL count through an entry of its own, `truth.not-refuted`, which states that no method's most recent verdict on the proposition is `refuted` or `partial`, where an `unresolved` or `not_attempted` record replaces no earlier verdict; that entry SHALL be a gap owned by issue 62 until a check reports it. It SHALL state that an `unverified` outcome counts against soundness in the same way as `failed`, and that while any precondition entry is `failed` or `unverified` the outcomes of obligation entries are not to be trusted until the ledger, sidecars or records are corrected; those outcomes are left as computed. It SHALL state what a report names: for each outcome that is `failed` or `unverified`, the entry and the unit, and each finding that is listed as information.

The document SHALL state that no article is sound yet and SHALL list the four reasons with the issue that owns each: entries whose `check` is `gap`, each owned by the issue in its `owner`; checks that do not report which units they examined (issue 68, which takes in issue 63), so that no mechanical entry passes; verification records that cannot say what they cover (issue 62), namely a record, which shows neither the reading that produced it nor the version it read, and a warning under `on_warning: judge`, for which there is no place to record a judgment; and `cross_model` records, which no tool produces yet (issue 21). It SHALL also state the limits that remain for some manuscripts once checks report what they examine: the reading-order check runs on single-file manuscripts only (issue 59); the symbol audit and the citation audit read the main file only, and the citation audit reads one bibliography file of a fixed name (issue 69); and the audit's code pass needs a directory of analysis code (issue 64). It SHALL state that numbers are compared with artifacts only in a ledger with the empirical profile, and that whether a ledger's profile fits its manuscript is the gap `index.profile-fits-manuscript`.

No executable check: soundness is a definition that the document states for readers and for later tools, and nothing in this change computes it. The guard checks only that the document names the four outcomes and the issues that own the reasons no article is sound yet.

#### Scenario: A forward-citation warning keeps an article from being sound

- **WHEN** every other entry has passed and one proposition is `unverified` under `dependence.cites-backward`
- **THEN** the article is not sound, and the report names that entry and that proposition

#### Scenario: A finding listed as information does not change the result

- **WHEN** every entry is `passed` or `not_applicable` and the structure validator reports crossing arcs for the entry whose `check` is `structure:S7`
- **THEN** the article is sound

#### Scenario: A verdict from a method that no entry lists is not lost

- **WHEN** the latest `lean` record for one proposition is `refuted` and no entry lists `lean` in `verified_by`
- **THEN** the verdict counts under `truth.not-refuted`, which is `unverified` while its `check` is `gap` and `failed` for that proposition once a check reports it

#### Scenario: A failed precondition is corrected first

- **WHEN** the entry whose `check` is `ledger:R1` is `failed` for one proposition
- **THEN** the article is not sound, and the outcomes of the obligation entries are marked as not to be trusted

### Requirement: The explanatory document describes the table without restating it

`plugins/propositions/docs/OBLIGATIONS.md` SHALL describe the keys of the data file, the two classes and how to tell them apart, the seven groups and their axioms, how applicability is stated and what happens when a value cannot be read, which checks count as implemented and why the excluded ones are excluded, what the fields of a gap mean, which entries need an external source, what counts as a finding for each source and which entry and unit it counts for, what a report has to show for a unit to pass, when a record counts, the four outcomes, soundness, the reasons no article is sound yet, and how to add or change an entry. It SHALL NOT list the entries: it SHALL mention at most two entry ids, as examples.

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
