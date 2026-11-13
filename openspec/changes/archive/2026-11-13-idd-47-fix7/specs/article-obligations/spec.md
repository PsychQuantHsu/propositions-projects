## MODIFIED Requirements

### Requirement: Applicability is a list of field values

`applies` is optional. When present it SHALL be a mapping whose keys come from this closed set: `profile`, `claim_type`, `evidence_class`, `cites`, `opens`, `section_role`. Each value SHALL be a non-empty list. A proposition satisfies `applies` when, for every key present, its own value is in the list:

- `profile`: the profile of its ledger;
- `claim_type`, `evidence_class`: its fields in the ledger;
- `cites`: `present` when its `cites` list is not empty, otherwise `absent`; an id in the list that names no proposition still makes it `present`;
- `opens`: it opens at least one commitment of a listed kind;
- `section_role`: the role of the section that contains it.

When the value a key needs cannot be read for a unit, the entry SHALL be `unverified` for that unit and not `not_applicable`, unless another key whose value can be read already rules the unit out. A value is read from the ledger and the sidecars themselves: no run of a validator is needed to read it, and a run that was not given a file, or that stopped before it reported anything, changes nothing about what can be read. A value can be read only under the conditions below; in every other case it cannot be read, and a condition that cannot be established counts as not holding. In these conditions a proposition is live when its ledger entry carries no `retired` key, which is the structure validator's test and is narrower than the test for a unit; and the ledger's ids are usable when each line of the ledger is a JSON object, apart from a line that is empty or starts with `//` once the white space around it is removed; every proposition in the ledger, retired or not, has an `id` that is a non-empty string, where a line that holds the `id` key twice is read with the last value, as the validators read it; and no two live propositions share an id. Two propositions that share an id leave the ids usable when at most one of them is live.

- `profile`: the ledger has no `_meta.json`, or its `_meta.json` is a JSON object without a `profile` key, and the profile is then `default`; or its `_meta.json` is a JSON object with a `profile` that the ledger validator accepts, and the profile is then the one declared. The validator rejects a `profile` key that holds `null`, a name that is not one of its profiles, and a profile declared under a schema version that does not allow one; in all three the profile cannot be read.
- `claim_type`, `evidence_class`: the field holds a value of its vocabulary for the ledger's profile; when the profile cannot be read, a value of the vocabulary of either profile can be read. A field that is left out, one that holds `null` and a misspelled value cannot be read. `SCHEMA.md` requires `claim_type` and leaves `evidence_class` optional, and no validator reports a proposition that leaves either out; issue 70 settles what a field that is left out means, and until then such a field cannot be read.
- `cites`: the field is absent, which reads as `absent`, or it holds a list.
- `opens`: all of these hold: the ledger's ids are usable; the proposition is live; the discourse sidecar exists and each of its lines that is not blank is a JSON object; exactly one of its records names the proposition; and that record has no `opens` key, or its `opens` is a list in which every item is an object whose `id` and `kind` the structure validator both accepts. The value is the kinds in that list: a record without `opens`, or with an empty list, opens nothing, and that is a value. Whether the commitments are otherwise in order, for instance an id opened twice or a commitment opened inside the abstract, is asked by other entries and does not change what is read.
- `section_role`: all of these hold: the ledger's ids are usable; the proposition is live; `structure.json` can be parsed as a JSON object and carries the structure version that the structure validator reads; and its section list is usable. The section of a proposition follows from the list and the ledger's order, so a discourse record is not needed to read `section_role`.

The section list is unusable exactly when one of these eleven holds, which are the errors that the structure validator reports under S5 about the list itself: `sections` is not a non-empty list; an item is not an object; an item's `id` is not a non-empty string; two items share an id; an item's `heading` is not a string, or is empty or holds only white space; an item's `role` is not a value of the vocabulary; an item's `first_prop` is not the id of a live proposition; an item with the role `abstract` is not the first item; an item's `first_prop` does not come after the `first_prop` of the item before it in the ledger's order; the ledger has no live proposition; the first item's `first_prop` is not the first live proposition. Nothing else that the structure validator reports under S5 makes the section list unusable: an error about the thesis, about a section's `parent`, about a commitment opened inside the abstract or about the paragraph plan.

An entry without `applies` applies to every unit. An entry with `unit: article` SHALL use no key other than `profile`, and for the article `profile` is the profile of the manuscript's ledger. The file SHALL have no other way to state applicability: no negation and no alternative between keys. Every listed value SHALL belong to the vocabulary of its field: the accepted profiles and the claim types and evidence classes of every profile in the ledger validator, and the commitment kinds and section roles in the structure validator. The relation of a record SHALL NOT be a key: the root of a paragraph has none, and no entry's requirement differs by the relation of the other records except that a `basis` edge needs a citation, which one entry asks of every proposition. The move and the paragraph type SHALL NOT be keys: the sidecars leave them optional, so an unannotated proposition would be treated as not applicable. `opens` is optional too and is a key, which is why the table holds the precondition `index.structure-faithful`.

Every entry whose `check` is one of `proofread:E1` to `proofread:E7`, and each of the three entries whose `owner` is 57, SHALL have `applies` with exactly two keys: `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`. Those four classes mark a claim made about data. The proofread skill says that its layers E1 to E8 do not apply to an `external` proposition, which has no artifact to re-run, and the table gives the entries for E9 and E10 the same limit. `not_computable` is one of the four because it marks a quantity the data cannot produce, which the entry for E2 is there to fail. Without the `profile` key, a proposition of a ledger with the default profile that leaves `evidence_class` out would be `unverified` under those entries and not `not_applicable`; without the evidence classes, every proposition of an empirical ledger that has no artifact would stay `unverified`. A proposition of an empirical ledger that carries any other evidence class is outside these entries, also when its text interprets data. That a proposition which reports a number or a result from the manuscript's own data carries one of the four is asked by a precondition of its own, which is a gap; it asks nothing of a sentence that reports another work's result, which is `external`, or of one that only interprets a result. The layer L5 states a test for `derived` and for `verified` and none for the four (issue 57). Some criteria concern only propositions with a feature that no key selects, such as an assignment to a theorem-like block, a `basis` edge, a cited figure or a cited work; such an entry is not narrowed to those propositions: it applies to every proposition that its `applies` admits, and to every proposition when it has none. How a check reports a unit of which the criterion asks nothing belongs to issue 68.

#### Scenario: An entry applies only where every key matches

- **WHEN** an entry has `applies` with `profile: [empirical]` and `claim_type: [result]`
- **THEN** it applies to a `result` proposition in an empirical ledger and to no proposition in a ledger with the default profile

#### Scenario: A proposition without the field is not exempt

- **WHEN** an entry has `applies` with `evidence_class: [external]` and a proposition's ledger entry has no `evidence_class`
- **THEN** the entry is `unverified` for that proposition

#### Scenario: A misspelled value is not a reason to exempt a proposition

- **WHEN** an entry has `applies` with `profile: [empirical]` and `evidence_class: [measured, tested, descriptive, not_computable]`, and a proposition of an empirical ledger holds `evidence_class: Measured`
- **THEN** the value cannot be read, and the entry is `unverified` for that proposition

#### Scenario: A proposition with two records is not read from either

- **WHEN** an entry has `applies` with `opens: [hypothesis]` and the discourse sidecar holds two records for a proposition
- **THEN** the entry is `unverified` for that proposition

#### Scenario: An error outside the section list leaves the role readable

- **WHEN** one section's `parent` names a later section and the structure validator reports no other error under S5
- **THEN** the section list is usable, and an entry that applies by `section_role` is decided from the role of each proposition's section

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

### Requirement: An article is sound only when every applicable entry passes

`plugins/propositions/docs/OBLIGATIONS.md` SHALL define a sound article as one for which every entry has the outcome `passed` or `not_applicable` for every unit, and SHALL add no condition outside the table. A verdict against a proposition from a method that no entry lists SHALL count through an entry of its own, `truth.not-refuted`, which states that no method's most recent verdict on the proposition is `refuted` or `partial`, where an `unresolved` or `not_attempted` record replaces no earlier verdict; that entry SHALL be a gap owned by issue 62 until a check reports it, and how a method's records are ordered is left to that issue. The document SHALL state that an `unverified` outcome counts against soundness in the same way as `failed`, and that while any precondition entry is `failed` or `unverified` the outcomes of obligation entries are not to be trusted until the ledger, sidecars or records are corrected; those outcomes are left as computed. It SHALL state what a report names: for each outcome that is `failed` or `unverified`, the entry and the unit, and for a gap the issue in its `owner`. A report names a proposition by its id, and by its line in the ledger when the proposition has no id that is a non-empty string or shares its id with another proposition that is not retired. What else a report lists is left to issue 71.

The document SHALL state that no article is sound yet and SHALL list the four reasons with the issue that owns each: entries whose `check` is `gap`, each owned by the issue in its `owner`; checks that do not report which units they examined (issue 68, which takes in issue 63); verification records that cannot say what they cover (issue 62), which also leaves a warning under `on_warning: judge` with no place where a judgment is recorded; and `cross_model` records, which no tool produces yet (issue 21). It SHALL state that the rules that compute an outcome from what the checks report are not written yet (issue 71).

It SHALL also state the limits that remain for some manuscripts once checks report what they examine: the reading-order check runs on single-file manuscripts only (issue 59); the symbol audit and the citation audit read the main file only, and the citation audit reads one bibliography file of a fixed name (issue 69); and the audit's code pass needs a directory of analysis code (issue 64).

It SHALL state one limit of what the table reaches. Numbers are compared with artifacts only in a ledger with the empirical profile. No entry compares the numbers of a manuscript whose ledger has the default profile with an artifact; that is the scope the maintainer accepted on 2026-11-13. Whether a ledger's profile fits its manuscript is a precondition that has no check yet (issue 70).

No executable check: soundness is a definition that the document states for readers and for later tools, and nothing in this change computes it. The guard checks that the document names the four outcomes and the issues that own the reasons no article is sound yet.

#### Scenario: A gap keeps an article from being sound

- **WHEN** one proposition is `unverified` under `dependence.cites-backward`
- **THEN** the article is not sound, and a report names that entry, that proposition and issue 46

#### Scenario: A verdict from a method that no entry lists counts inside the table

- **WHEN** the latest `lean` record for one proposition is `refuted` and no entry lists `lean` in `verified_by`
- **THEN** the verdict counts under `truth.not-refuted` and under no condition outside the table; while that entry's `check` is `gap` it is `unverified` for every proposition, with or without such a record

#### Scenario: A failed precondition is corrected first

- **WHEN** `index.text-in-manuscript` is `failed` for one proposition
- **THEN** the article is not sound, and the outcomes of the obligation entries are marked as not to be trusted

#### Scenario: A proposition without an id of its own is named by its line

- **WHEN** two propositions that are not retired share an id and an entry is `unverified` for each of them
- **THEN** a report names each of the two by its line in the ledger

### Requirement: The explanatory document describes the table without restating it

`plugins/propositions/docs/OBLIGATIONS.md` SHALL describe the keys of the data file, the two classes and how to tell them apart, the seven groups and their axioms, how applicability is stated and the cases in which a value cannot be read, which checks count as implemented and why the excluded ones are excluded, what the fields of a gap mean, which entries need an external source and why that mark is a key of its own, the two values of `on_warning`, that `info` covers only the warning an entry was reviewed for and that a unit can pass one of the four `info` entries while its criterion does not hold, the four outcomes, the seven points that the outcome rules have to keep, the three outcomes that the table decides by itself, as rules of which the first that fits decides, and that the second of them holds also when a check printed something about the unit, which rules it leaves to issue 71, why no entry passes yet, soundness, the reasons no article is sound yet, and how to add or change an entry. It SHALL NOT list the entries: it SHALL mention at most two entry ids, as examples.

No executable check for this list beyond what the guard requirement names. A search for a phrase shows that a sentence is present and not that the document explains the thing, and no such search is written for the rest of the list. An independent reader decides cases about outcomes and about the scope of the table from the data file and the document alone; the cases, the reader's answers and the commit they were decided against are recorded on issue 47. What the list asks beyond those cases is checked by review only.

`plugins/propositions/docs/VERIFICATION.md` SHALL say that its description of a `supported` proofread record is of the derivation walk, that a record does not say which walk produced it, and that its rule of taking each method's latest record is for the disagreement warning only. For how a record counts toward an article being sound it SHALL point to `OBLIGATIONS.md` and state no rule of its own. It SHALL NOT change the record format. The guard checks for the three phrases that carry these statements: `derivation walk`, `for this warning only` and `OBLIGATIONS.md`.

#### Scenario: A copy of the table in the document is refused

- **WHEN** the document mentions three or more entry ids of the data file
- **THEN** the guard fails and its message gives the number found

##### Example: a document that names three entries

- **GIVEN** a table with three entries and a document whose text contains the ids of all three
- **WHEN** the document check runs
- **THEN** it reports a problem that gives the number 3

##### Example: a verification document without the pointer

- **GIVEN** the text of a verification document that names neither `OBLIGATIONS.md` nor the derivation walk
- **WHEN** the check on that document runs
- **THEN** it reports a problem for each missing phrase, and one of them names `OBLIGATIONS.md`

#### Scenario: The document says why a defined layer is a gap

- **WHEN** a reader looks up why the proofread layer E9 is a gap
- **THEN** the document says that the walk of the proofread skill does not list E8, E9 and E10, so a verdict does not show that they were read

### Requirement: A guard checks the table

The repository SHALL have automated tests that fail when the data file or the document breaks one of the following: the closed keys, the two classes and their prefixes, the groups, applicability, the inventory and owners, the accounting of checks and vocabulary values, `verified_by` and `on_warning`, the entries that need an outside source, the entries the maintainer reviewed, the limit on entry ids in the document, the four outcomes, the issue numbers, the key `external_source` and the two statements that the document has to carry (why the layers E8 to E10 are gaps, and what the `owner` of a gap is), and what `docs/VERIFICATION.md` has to say. What else the requirements above ask of the document is not checked by the guard. A key that is present SHALL hold what the key requires: the guard SHALL refuse `applies` or `axiom` written with no value. When the file is not a mapping, or a value has a type its key does not allow, the guard SHALL report a problem that says so and SHALL NOT end in an unhandled error. The guard SHALL refuse a data file in which one mapping holds the same key twice, because a YAML loader keeps the last value and drops the first without a message. Each failure message SHALL name the entry, value or check concerned. The tests are cases in `tests/test_plugin_payload_tracked.py` whose names start with `test_obligations_`; a change to this capability SHALL add no test file and no script module. A change is accepted only when these cases pass; a skipped case does not count.

In the document the guard SHALL look for an entry id, an outcome, an issue number and the statement on the layers E8 to E10 as whole terms, not as parts of longer ones: `#210` does not name issue 21, `E1-E8` does not say why the layer E8 is a gap, `E100` is not the layer E10, and the word `owner` alone does not say what the `owner` of a gap is. One test SHALL sweep the cases of the guard's two lists of refusals, the format refusals and the values of the wrong type: for each case the unchanged table gives no message that holds all of the case's needles, and the changed table gives exactly one. The refusals of the guard's other checks, on the reviewed entries, on the accounting and on the document, are tested by cases written one by one and are not swept.

The guard is written in Python while the vocabularies it reads are defined in the Python validators. The project rule on the implementation language records this as an exception that ends when the Swift package of issue 46 exists and the vocabularies have a Swift source; the guard then moves to that package's test target.

#### Scenario: The guard runs with the suite

- **WHEN** the repository's test suite runs
- **THEN** the cases whose names start with `test_obligations_` run and pass on the committed data file and document

#### Scenario: The guard reads the vocabularies from their source

- **WHEN** the structure validator gains a section role
- **THEN** the guard fails until an entry names the new role or `unconstrained` lists it, without the guard itself being edited

##### Example: a table that is not a mapping

- **GIVEN** a data file that parses to nothing, to a list, or to a mapping whose `entries` is a string
- **WHEN** the guard's checks run on it
- **THEN** each returns its problems, and one of them says what is not a mapping or not a list

##### Example: a value of the wrong type

- **GIVEN** a table in which the first entry has a list as its `id`
- **WHEN** the format check runs
- **THEN** it reports a problem that names `entry 1` and says that `id` is not of the required form, and the same check reports no such problem for the unchanged table

##### Example: an issue number inside a longer one

- **GIVEN** a document that mentions `#210` and never `#21`
- **WHEN** the document check runs
- **THEN** it reports that the document does not name issue `#21`

##### Example: an entry with the same key twice

- **GIVEN** the text of a data file in which one entry has two `check:` lines
- **WHEN** the guard loads it
- **THEN** loading fails and the message names `check`

##### Example: a section role added to the structure validator

- **GIVEN** the vocabulary of `section_role` with one more value, `afterword`, that no entry names and `unconstrained` does not list
- **WHEN** the accounting check runs
- **THEN** it reports a problem that names `section_role` and `afterword`
