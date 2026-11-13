# Article obligations

`catalog/obligations.yaml` states, one entry at a time, what a manuscript's
ledger and sidecars have to get right and what the article owes its reader. For
each entry it names the check that verifies it. This document explains how to
read the table and what it means for an article to be **sound**.

No tool computes anything from the table yet; the only program that reads it
is the guard described under [Changing the table](#changing-the-table). The
rules that compute an entry's outcome from the output of the checks are not in
this document: they are written with the
tool that applies them, where tests can hold them (issue #71). This document
holds the definitions those rules have to keep, so that "sound" means the same
thing wherever it is used.

The table is the only list of entries. This document does not repeat it: it
quotes two entries as examples and no more.

## An entry

| Key | Present | Meaning |
|---|---|---|
| `id` | always | `<prefix>.<name>`, unique. The prefix is `index` for a precondition and the group for an obligation |
| `class` | always | `precondition` or `obligation` — see [Two classes](#two-classes) |
| `group` | obligations only | One of the seven groups — see [Seven groups](#seven-groups) |
| `unit` | always | What the entry is decided for: `proposition` or `article` |
| `applies` | optional | Which units the entry applies to — see [Applicability](#applicability) |
| `criterion` | always | One line saying what has to hold. The definition of the check stays in the check's own document |
| `check` | always | `gap`, or the id of an implemented check — see [Checks](#checks) |
| `owner` | gaps only | The number of the issue that will supply the check |
| `verified_by` | always | `[mechanical]`, or the verification methods the entry needs, all of them |
| `on_warning` | mechanical entries only | `judge` or `info` — see [Mechanical entries](#mechanical-entries) |
| `external_source` | entries that need one | `true` when the check has to consult a source outside the manuscript's repository — see [Gaps](#gaps) |

```yaml
- id: dependence.cites-backward
  class: obligation
  group: dependence
  unit: proposition
  applies:
    cites: [present]
  criterion: "Every proposition this one cites comes earlier in reading order, or the forward reference is a roadmap or a promissory note."
  check: gap
  owner: 46
  verified_by: [mechanical]
  on_warning: judge
```

This entry is an obligation of the group `dependence`. It is decided for each
proposition that cites at least one other. No check verifies it yet, and issue
46 will supply one. When that check exists it will be mechanical, and a warning
from it will have to be judged before the entry passes.

### Units

A unit is what an entry is decided for.

- `proposition`: each proposition of the ledger that is not retired. A
  proposition is retired only when its `retired` key holds a block that is
  well formed by the ledger validator's test, so one whose `retired` key holds
  `null` or a malformed block is a unit.
- `article`: the manuscript as a whole, once.

A proposition is named by its id. Where a proposition has no `id` that is a
non-empty string, or two propositions that are not retired share one, the id
does not single out a unit, and such a unit is named by its line in the
ledger.

The precondition on retirements is decided for the article and covers every
`retired` key, also one that holds a malformed block: that entry is where a
malformed block is reported.

## Two classes

- A **precondition** is an entry whose failure is corrected in the ledger, a
  structure sidecar or the verification records. It asks whether those files
  are a faithful index of the manuscript.
- An **obligation** is an entry whose failure is corrected in the manuscript,
  or needs a decision by the author. It asks what the article owes its reader.

The class is written on each entry. It does not follow from which tool runs the
check: one check can cover both, and the table then holds one entry for each,
naming the same check. The structure validator's S5, for example, checks both
that the section and paragraph plans are well formed (a precondition) and that
the article states its thesis (an obligation). S5 sees only whether the
sidecar lists the propositions that carry the thesis, so an article without a
thesis and a sidecar that has not recorded it look the same to it.

The distinction matters when reading a result. "Every rule of the ledger
validator passes" says that the index is right. It says nothing yet about the
article.

One precondition has no check yet, and everything that reads the sidecars
depends on it: that the structure sidecars record what each proposition does in
the manuscript. The commitments a proposition opens and the role of its section
are annotations, and nothing compares them with the text. A proposition whose
hypothesis was never annotated opens nothing, so the entries about commitments
do not apply to it. Until a check exists (issue #66), the outcomes of the
obligations that apply by those annotations are not to be trusted.

A second precondition without a check concerns the ledger itself: that its
profile fits the manuscript. The entries on numbers, samples and figures apply
only in a ledger with the empirical profile, and nothing compares the declared
profile with what the manuscript reports. Issue #70 owns it.

For this rule the manuscript includes the repository's documents and analysis
code that the audit's code pass compares: a finding of that pass is corrected
there, which is why its two entries are obligations.

There is no third class. A finding that is reported for information only has an
entry of its own, in whichever class fits what would be corrected if someone
acted on it, and its warning rule says that it is information.

## Seven groups

Each obligation belongs to one group. A group protects one thing and answers to
at most one axiom of the `che-axiom-systems` plugin. The table names the axiom
and does not restate it.

| Group | Protects | Axiom |
|---|---|---|
| `dependence` | Every sentence depends only on what has already appeared | `academic-writing/A1_no_forward_dependence` |
| `commitment` | Every commitment made to the reader is kept | not written yet |
| `support` | Every claim is carried by the grounds given for it | not written yet |
| `consistency` | No two statements of the article conflict | not written yet |
| `truth` | What the article says is true, and its numbers and citations can be traced to a source | not written yet |
| `placement` | Content sits in the section whose role fits it | not written yet |
| `completeness` | The manuscript holds nothing left unfinished | not written yet, and possibly none |

The table is checked whether or not `che-axiom-systems` is installed: the
criteria a check can act on live here, the principles live there.

## Applicability

`applies` maps a key to a list of allowed values. A proposition satisfies it
when, for every key present, its own value is in the list. An entry without
`applies` applies to every unit.

| Key | The proposition's value |
|---|---|
| `profile` | The profile of its ledger |
| `claim_type`, `evidence_class` | Its fields in the ledger |
| `cites` | `present` when its `cites` list is not empty, otherwise `absent`. An id in the list that names no proposition still makes it `present` |
| `opens` | It opens at least one commitment of a listed kind |
| `section_role` | The role of the section that contains it |

Keys combine with "and". There is no negation and no "or" between keys: a
criterion that needs "or" is split into two entries. An entry whose unit is
`article` uses `profile` only, and for the article `profile` is the profile of
the manuscript's ledger.

When the value a key needs cannot be read for a unit, the entry is `unverified`
for that unit, not `not_applicable`, unless another key whose value can be read
already rules the unit out.

A value is read from the ledger and the sidecars themselves. No run of a
validator is needed to read it, and a run that was not given a file, or that
stopped before it reported anything, changes nothing about what can be read.
A value can be read only under the conditions below. In every other case it
cannot be read, and a condition that cannot be established counts as not
holding.

The conditions use two terms.

- A proposition is **live** when its ledger entry carries no `retired` key.
  That is the structure validator's test. It is narrower than the test for a
  unit: a proposition whose `retired` key holds `null` or a malformed block is
  a unit and is not live.
- The ledger's ids are **usable** when three things hold: each line of the
  ledger that is not blank and does not start with `//` is a JSON object;
  every proposition in the ledger, retired or not, has an `id` that is a
  non-empty string; and no two live propositions share an id. The sidecars
  refer to a proposition by its id. Two propositions that share an id
  leave the ids usable when at most one of them is live; a value that needs
  usable ids can then be read for the live one, and not for the other, which
  is not live.

| Key | Its value can be read when |
|---|---|
| `profile` | The ledger has no `_meta.json`, or its `_meta.json` is a JSON object without a `profile` key: the profile is then `default`. Or its `_meta.json` is a JSON object with a `profile` that the ledger validator accepts: the profile is then the one declared |
| `claim_type`, `evidence_class` | The field holds a value of its vocabulary for the ledger's profile. When the profile cannot be read, a value of the vocabulary of either profile can be read |
| `cites` | The field is absent, which reads as `absent`, or it holds a list |
| `opens` | All of these hold: the ledger's ids are usable; the proposition is live; the discourse sidecar exists and each of its lines that is not blank is a JSON object; exactly one of its records names the proposition; and that record has no `opens` key, or its `opens` is a list in which every item is an object whose `id` and `kind` the structure validator both accepts |
| `section_role` | All of these hold: the ledger's ids are usable; the proposition is live; `structure.json` can be parsed as a JSON object and carries the structure version that the structure validator reads; and its section list is usable |

Some cases that follow from the table, since they have been misread before:

- `profile`: the ledger validator rejects a `profile` key that holds `null`,
  a name that is not one of its profiles, and a profile declared under a
  schema version that does not allow one. In all three the profile cannot be
  read.
- `claim_type`, `evidence_class`: a field that is left out, one that holds
  `null` and a misspelled class cannot be read. A misspelled class is not a
  value outside the entry's list. The vocabularies are the ledger validator's,
  and the copy of `SCHEMA.md` pinned next to each ledger lists them. The
  evidence classes `measured`, `tested`, `descriptive`, `not_computable` and
  `external`, and the claim types `result` and `interpretation`, are values of
  the empirical profile only. `SCHEMA.md` requires `claim_type` and leaves
  `evidence_class` optional, and no validator reports a proposition that
  leaves either out. Issue #70 settles what a field that is left out means,
  also for the two preconditions that ask for a known value. Until then such
  a field cannot be read.
- `cites`: `null` and a string cannot be read. A proposition without the field
  cites nothing; whether it relies on something it does not declare is what
  the entry for the layer L3 asks.
- `opens`: the value is the kinds in the record's list. A record without
  `opens`, or with an empty list, opens nothing, and that is a value. A
  proposition with no record, or with two, has no value that can be read.
  Whether the commitments are otherwise in order, for instance an id opened
  twice or a commitment opened inside the abstract, is asked by other entries
  and does not change what is read.
- `section_role`: the list and the ledger's order place a proposition in a
  section; a discourse record is not needed for that.

The section list is unusable exactly when one of these eleven holds. They are
the errors that the structure validator reports under S5 about the list
itself.

1. `sections` is not a non-empty list;
2. an item is not an object;
3. an item's `id` is not a non-empty string;
4. two items share an id;
5. an item's `heading` is not a string, or is empty or holds only white space;
6. an item's `role` is not a value of the vocabulary;
7. an item's `first_prop` is not the id of a live proposition;
8. an item with the role `abstract` is not the first item;
9. an item's `first_prop` does not come after the `first_prop` of the item
   before it in the ledger's order;
10. the ledger has no live proposition;
11. the first item's `first_prop` is not the first live proposition.

Nothing else that the structure validator reports under S5 makes the section
list unusable. There are four kinds: about the thesis, about a section's
`parent`, about a commitment opened inside the abstract, and about the
paragraph plan.

The relation of a record is not a key. The root of a paragraph has none, and
no entry's requirement differs by the relation of the other records except
that a `basis` edge needs a citation, which one entry asks of every
proposition.

The move and the paragraph type are not keys. The sidecars leave them optional,
so an entry keyed on one of them would treat an unannotated proposition as not
applicable. `opens` is optional too and is a key; that is why the table holds
the precondition on the sidecars described under [Two classes](#two-classes).

The empirical layers of the proofread skill apply with two keys:
`profile: [empirical]` and
`evidence_class: [measured, tested, descriptive, not_computable]`. Those four
classes mark a claim made about data. The skill says that its layers E1 to E8
do not apply to an `external` proposition, which has no artifact to re-run;
the table gives the entries for E9 and E10 the same limit. `not_computable`
is one of the four because it marks a quantity the data cannot produce, and
the entry for E2 is the one that fails it. Without the `profile` key, a
proposition of a ledger with the default profile that leaves `evidence_class`
out would be unverified under these entries instead of not applicable; without
the evidence classes, every proposition of an empirical ledger that has no
artifact would stay unverified.

A proposition of an empirical ledger that carries any other evidence class is
outside these entries, also when its text interprets data. That a claim about
data carries one of the four is asked by a precondition of its own, decided
for every proposition of an empirical ledger. It is a gap (issue #70): the
layer L5 states a test for `derived` and for `verified` and none for the four
(issue #57). The derivation layers are not limited by profile, so
a proposition of an empirical ledger that rests on data has to pass both
walks.

Numbers are compared with artifacts only in a ledger with the empirical
profile. Whether a manuscript that reports data has that profile is the second
precondition described under [Two classes](#two-classes).

Some criteria concern only propositions with a feature that no key selects:
one assigned to a theorem-like block, one with a `basis` edge, one that cites a
figure, one whose text cites a work. Such an entry is not narrowed to those
propositions. It applies to every proposition that its `applies` admits, and
to every proposition when it has none. How a check reports a unit of which the
criterion asks nothing is part of issue #68.

`unconstrained` at the end of the table lists every value of `claim_type`,
`evidence_class`, the commitment kinds and the section roles that no entry's
`applies` names, with the reason. A value is either named by an entry or listed
there, never both, so a value added to one of these four vocabularies cannot
go unnoticed. The profiles and the two values of `cites` are not accounted for
in this way.

## Checks

`check` is `gap` or the id of an implemented check. An id carries its source,
because two sources number their rules R1, R2, R3: `ledger:R2` (a cited id
resolves) and `audit:R2` (the citation audit) are different checks.

### The inventory

The inventory is closed. What its members have in common is that each reports
findings, or leaves records, about units under an id of its own.

| Ids | Reported by | Defined in |
|---|---|---|
| `ledger:R1`, `R1.5`, `R2`, `R3`, `R4`, `R7` to `R13` | `validate-propositions.py` | The copy of `SCHEMA.md` pinned next to each ledger |
| `ledger:profile` | `validate-propositions.py`, its check that a profile declared in `_meta.json` is one it accepts under the ledger's schema version. It reports nothing for a ledger that declares none | The same |
| `structure:S1` to `S9` | `validate-structure.py` | `docs/STRUCTURE.md` |
| `records:V1` to `V6` | `validate-verification.py` | `docs/VERIFICATION.md` |
| `coverage:text` | `check-extraction-coverage.py` | The extract skill |
| `order:ledger` | The dry run of `reorder-ledger.py` | The construct-batch skill |
| `audit:R1`, `R2`, `R3` | `audit-symbols.py`, `audit-citations.py` and `audit-code-manuscript.py`, in that order. `audit:R2` stands for both rules of the citation script, which it labels R2 and R2-bis | `rules/manuscript-consistency-audit.md` |
| `proofread:L1` to `L5`, `proofread:E1` to `E7` | The per-proposition walk of the proofread skill | The proofread skill |

### What is not in the inventory

- The fourth pass of the cross-artifact audit. It runs the ledger validator.
- The theorem-boundary audit. It compares what `ledger:R9` compares. It also
  reports environments it could not close and propositions whose block it
  could not resolve, which R9 passes over in silence; that difference belongs
  to issue #68.
- The dry run of the location refresh. It has no rule id of its own. It
  searches the manuscript for each proposition's text and reports every
  `location` that differs from where it finds the text, which is more than
  `ledger:R13`, the check on that field, reports. What R13 passes over in
  silence belongs to issue #68.
- The link catalog's currency check. Its subject is a file of this plugin, not
  a manuscript.
- The checks of the `tschema-check` plugin. They belong to another plugin.
- The stumble categories of the clarity audit, the counts in the construct
  skill's summary and the states of the analyze skill. None of them leaves a
  finding or a record for a unit under an id.
- The `location` layer of the proofread walk. It is a spot-check of the field
  that `ledger:R13` checks, and the skill's layer table names R13 as its
  mechanical form.
- The records validator's warning that two methods disagree on a proposition.
  It has no rule id of its own. It reports part of what the entry on verdicts
  against a proposition states; where it counts is left to the outcome rules
  (issue #71).
- The proofread layers E8, E9 and E10. The layer table of the proofread skill
  defines them, but its per-proposition walk does not list them, so a verdict
  does not show that they were read. Each has an entry that is a gap.

### Gaps

An entry whose `check` is `gap` states something that has to hold and that
nothing verifies yet. Its `owner` is the issue that will supply the check. The
change that implements the check adds its id to the inventory and replaces
`gap` in the entry, in the same change.

For a gap, `unit`, `verified_by` and `on_warning` say how the entry is expected
to be verified. They are provisional: the change that supplies the check sets
them to what the check does.

Four entries need a source outside the manuscript's repository: that the cited
works exist, that the support outside the paper can be found, that it says
what is taken from it, and that each work a proposition's text cites says what
the proposition takes from it. Each carries `external_source: true`. The mark
is a key of its own because it says where the check looks, not who decides:
two of the four are decided by a script and two by a reading. All four are
gaps today, owned by issue #50, and each keeps the mark when its check is
supplied.

The last of the four has no `applies`. The two entries on support outside the
paper apply by the evidence class `external`, which only the empirical profile
has; a proposition of a ledger with the default profile that relies on a
theorem of another paper has to be asked too. In an empirical ledger, an `external`
proposition whose text cites a work falls under the last entry and under the
one before it. Whether those two are merged is for issue #50 to decide when
it supplies the checks.

The two entries on support outside the paper are keyed on the evidence class
alone, without `profile`. A proposition of a ledger with the default profile
that leaves `evidence_class` out is therefore `unverified` under them and not
`not_applicable`, although no value of that ledger's vocabulary would make
them apply. The entries are left as the maintainer reviewed them; issue #50
settles their keys together with the question of merging.

## How an entry is verified

### Mechanical entries

`verified_by: [mechanical]` means that a script decides, whether the script is
in this plugin or looks something up in an external source.

A warning, in this document, is what a check reports about a unit without
reporting it as an error, whatever the script itself calls it: a warning, an
FYI, information. The level says how the script treats what it reports, not
whether the criterion is violated. Some checks only warn, and what they warn
of is that the criterion does not hold.

`on_warning` records what the maintainer decided a warning does to the entry:

- `judge`: the unit cannot pass until someone has judged the warning.
- `info`: the warning is listed in a report. It neither keeps the unit from
  passing nor makes the entry fail for the unit.

`info` is the one setting that sets a warning aside without a judgment, so it
is allowed only on entries the maintainer has reviewed for it. There are four,
one for each of these warnings: a proposition that no other cites and whose
claim type the orphan check does not exempt (`ledger:R3`), crossing
arcs (`structure:S7`), a code symbol that the documents never mention
(`audit:R3`) and a bibliography entry that is never cited (`audit:R2`). Every
other mechanical entry says `judge`, including an entry whose check reports no
warning today: if the check starts to report one, the warning has to be
judged.

The criterion of each of the four states the condition that its warning
reports. A unit can therefore pass one of these entries while the criterion
does not hold for it. That is the maintainer's decision: the condition is
worth listing, and an article can be sound without it. The entry is in the
table so that the finding has a place there.

```yaml
- id: index.arcs-do-not-cross
  class: precondition
  unit: proposition
  criterion: "No two arcs of the proposition's paragraph, or of its section, cross."
  check: structure:S7
  verified_by: [mechanical]
  on_warning: info
```

`info` covers that one warning and nothing else that the check reports. Three
of the four checks are also named by entries that say `judge`, so the rule
that says which entry a line of output counts for has to keep the four
warnings on the four entries reviewed for them. That rule is not in this
document.

This document does not say which lines of a check's output are errors and
which are warnings, which entry a finding counts for when several entries name
its check, which unit it counts for, or what a judgment does to the outcome.
Those rules compute an outcome from what the checks print, and belong to
issue #71.

### Entries verified by methods

Otherwise `verified_by` lists verification methods from
`docs/VERIFICATION.md`, and the entry needs every one of them. An entry that
lists `proofread` also lists `cross_model`: each proofread layer is read by a
language model, and a judgment by a language model needs a second reading by
another model. A prover, a certificate, a computer-algebra system and a human
review are the methods of those names.

## The outcome of an entry for a unit

An entry has exactly one of four outcomes for a unit.

| Outcome | Meaning |
|---|---|
| `not_applicable` | The entry does not apply to the unit |
| `passed` | The entry applies to the unit and is settled in the unit's favour |
| `failed` | The entry applies to the unit and is settled against it |
| `unverified` | None of the other three is established |

What settles an entry in a unit's favour or against it, that is, what the
entry's check has to print or its verification records have to hold, is not
defined in this document. Those are the outcome rules (issue #71).

### What the outcome rules have to keep

Seven points are fixed here, whatever the rules turn out to be.

1. `unverified` is what remains. Whenever none of the other three outcomes is
   established, the outcome is `unverified`.
2. `passed` needs the entry's check to have examined the unit. It is not
   proof that the criterion holds: a check can be weaker than the criterion it
   serves, and that difference is corrected in the check, not by rewording the
   criterion to follow the code.
3. `failed` needs a finding of the entry's check, or a record of one of its
   methods, that stands against the unit. Where there is none, the outcome is
   not `failed`.
4. Under `on_warning: info`, the warning that the entry was reviewed for is no
   reason against `passed` and no reason for `failed`.
5. Under `on_warning: judge`, a warning that nobody has judged keeps the unit
   from `passed`.
6. A `supported` record counts only for the checks that its reading
   performed.
7. Today no outcome is `passed`.
   [Why nothing passes yet](#why-nothing-passes-yet) gives the reason.

### What the table decides by itself

Three outcomes follow from the table and from the manuscript's ledger and
sidecars, without the output of any check. The first rule that fits decides.

1. A value that `applies` needs can be read for the unit and is not in the
   entry's list: `not_applicable`.
2. A value that `applies` needs cannot be read for the unit: `unverified`.
3. `check` is `gap`: `unverified`.

Rule 2 follows from the definitions. When the value cannot be read, whether
the entry applies to the unit is not established, so none of the other three
outcomes is. That holds also when a check printed something about the unit.
The ledger validator, for example, reports every character of a `cites` that
is a string as an id that does not resolve; the entry on resolving ids is
still `unverified` for that proposition.

For every other entry and unit, the outcome is `passed`, `failed` or
`unverified`, and the outcome rules (issue #71) decide which: which outputs
are errors and which are warnings, which entry and which unit a finding counts
for, when a run still counts, what a judgment does, and when an entry is
`passed`. By points 3 and 7, the outcome is today `unverified` wherever no
finding and no record stands against the unit. Elsewhere it is `failed` or
`unverified`.

### Why nothing passes yet

An entry is settled in a unit's favour only by a check that examined the unit
(point 2), and nothing shows today that a check examined a unit.

- **Mechanical checks.** A check names a unit when it has a finding for it or
  sets it aside. It does not say which units it examined. A line that says a
  rule passed, a count, and a header that names an input file do not say it
  either: the ledger validator prints a pass line for R9 and for R13 while it
  passes over propositions in silence, the coverage check reads only the line
  range it is given, and the structure validator relaxes several rules when
  run with `--partial`. Reading the scripts turned up several hundred paths on
  which a check leaves a unit unexamined without saying so. Issue #68 asks
  every check to report what it examined, and takes in issue #63, which asks
  the same of R9.
- **Verification records.** A record of today's format names no walk and no
  layer of the proofread skill, its `checked_at` is by default the day it was
  converted and not the day of the reading, and it holds no version of what
  was read. Issue #62 owns the record format.

The condition under which an entry passes is therefore not written yet. It is
part of the outcome rules (issue #71), it needs what issues #68 and #62 will
supply, and it has to keep the seven points above.

## When an article is sound

An article is sound when every entry has the outcome `passed` or
`not_applicable` for every unit. Nothing outside the table is part of the
definition.

`unverified` counts against soundness exactly as `failed` does. An article
that nothing has checked is not sound.

A verdict against a proposition from a method that no entry lists, such as a
Lean refutation or a human review, counts through an entry of its own, which
says that no method's most recent verdict on the proposition is `refuted` or
`partial`, where an `unresolved` or `not_attempted` record replaces no earlier
verdict. That entry is a gap today, and how a method's records are ordered is
left to the issue that owns it.

### Preconditions come first

While any precondition is `failed` or `unverified`, the outcomes of the
obligations are not to be trusted: they were computed from an index that is
not known to be right. Their outcomes are left as computed and marked as not
to be trusted. Correct the ledger, the sidecars or the records, run the checks
again, and read the obligations after that.

### What a report names

A report on soundness names, for every outcome that is `failed` or
`unverified`, the entry and the unit, and for a gap the issue in its `owner`.
It names a proposition by its id, and by its line in the ledger when the
proposition has no id that is a non-empty string or shares its id with another
proposition that is not retired. What else a report lists, and its format, are
part of the outcome rules (issue #71). One example of what is left open: a `refuted` record of a
method that no entry lists changes no outcome while the entry on such verdicts
is a gap, so whether a report lists the record is for those rules to say.

### No article is sound yet

Four things keep every article from being sound today, and each has an owner.

1. **Gaps.** Each entry whose `check` is `gap` is unverified for every unit it
   applies to. Its `owner` is the issue that will supply the check.
2. **Checks that do not say what they examined.** No mechanical entry can
   pass until they do. Issue #68.
3. **Records that cannot say what they cover.** No entry that lists methods
   can pass until they do, and a warning under `judge` has no place where the
   judgment is recorded. Issue #62.
4. **No second reading.** No tool writes `cross_model` records, so every entry
   that needs one is unverified. Issue #21.

The rules that turn what the checks report into outcomes, the pass condition
among them, are not written either. Issue #71.

Three limits will remain for some manuscripts once checks report what they
examine.

- The reordering dry run supports single-file manuscripts only. Issue #59.
- The symbol audit and the citation audit read the main file only, and the
  citation audit reads one bibliography file of a fixed name. Issue #69.
- The audit's code pass needs a directory of analysis code. Issue #64.

One limit is about what the table reaches. Numbers are compared with artifacts
only in a ledger with the empirical profile. A ledger with the default profile
has no artifacts to compare with, and no entry asks about the numbers in its
manuscript. A manuscript that reports data is expected to have the empirical
profile; that is what the precondition on the profile asks, a gap owned by
issue #70. The maintainer accepted this scope on 2026-11-13.

## Changing the table

To add an entry:

1. State the criterion in one line. Leave the definition of the check where it
   is.
2. Choose the class by where a failure is corrected. If the answer is "both",
   write two entries.
3. For an obligation, choose the group whose one thing the entry protects, and
   start the id with the group. Start the id of a precondition with `index`.
4. Write `applies` only if the entry does not hold for every unit.
5. Name the check. If nothing implements it, write `gap` and the issue that
   will, opening one if there is none.
6. Write `verified_by`. For a mechanical entry write `on_warning: judge`.
   `info` needs the maintainer's review of that entry, and the guard's list of
   reviewed entries changes in the same commit.
7. Write `external_source: true` if the check has to consult a source outside
   the manuscript's repository. The spec and the guard name the entries that
   carry it, so both change in the same commit.

The spec and the guard also name the four entries that say `info`, several of
the entries that are gaps today, the four that carry `external_source`, the
one of them that has no `applies`, and the owners that have to appear. Changing one of them, for instance when a
gap's check is supplied, changes the spec requirement and the guard in the
same commit; the guard's message says which entry it expected.

When a check gains a new kind of warning, give that kind an entry. When a
vocabulary gains a value, name it in an entry's `applies` or list it in
`unconstrained`.

The guard is a set of test cases in the source repository of this plugin,
`tests/test_plugin_payload_tracked.py`, with names that start with
`test_obligations_`:

```bash
python3 -m pytest tests/test_plugin_payload_tracked.py -k obligations
```

It needs PyYAML. It refuses a data file in which one mapping holds the same key
twice. It checks the format of the table, that every implemented
check and every value of the four accounted vocabularies is placed, that the entries the
maintainer reviewed keep their values, that this document does not turn into
a second copy of the table, and that `docs/VERIFICATION.md` still points
here.
