# Article obligations

`catalog/obligations.yaml` states, one entry at a time, what a manuscript's
ledger and sidecars have to get right and what the article owes its reader. For
each entry it names the check that verifies it. This document explains how to
read the table and how to decide, from the table and the output of the checks,
whether an article is **sound**.

No program reads the table yet. A tool or skill that reports on a manuscript
follows the rules below, so that "sound" means the same thing wherever it is
used.

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

- `proposition`: each proposition of the ledger that is not retired. A proposition is retired only when its
  `retired` block is well formed, so one whose block is malformed is a unit.
- `article`: the manuscript as a whole, once.

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
the article has a thesis whose propositions the sidecar names (an obligation).

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

The move and the paragraph type are not keys. The sidecars leave them optional,
so an entry keyed on one of them would treat an unannotated proposition as not
applicable. `opens` is optional too and is a key; that is why the table holds
the precondition on the sidecars described under [Two classes](#two-classes).

The empirical layers of the proofread skill apply with two keys:
`profile: [empirical]` and
`evidence_class: [measured, tested, descriptive, not_computable]`. Those four
classes mark a claim that rests on data. The empirical walk has no artifact to
re-run for any other proposition, and the skill says of an `external` one that
the empirical layers do not apply to it. Without the profile, every proposition
of a mathematical manuscript would stay unverified under these entries; without
the evidence classes, every proposition without an artifact would. The
derivation layers are not limited by profile, so a proposition of an empirical
ledger that rests on data has to pass both walks.

Numbers are compared with artifacts only in a ledger with the empirical
profile. A manuscript that reports data declares that profile; under the default
profile no entry checks its numbers.

`unconstrained` at the end of the table lists every value of `claim_type`,
`evidence_class`, the commitment kinds and the section roles that no entry's
`applies` names, with the reason. A value is either named by an entry or listed
there, never both, so a value added to a vocabulary cannot go unnoticed.

## Checks

`check` is `gap` or the id of an implemented check. An id carries its source,
because two sources number their rules R1, R2, R3: `ledger:R2` (a cited id
resolves) and `audit:R2` (a citation key is in the bibliography) are different
checks.

### The inventory

The inventory is closed. What its members have in common is that each reports
a finding, or leaves a record, for a unit without changing any file.

| Ids | Reported by | Defined in |
|---|---|---|
| `ledger:R1`, `R1.5`, `R2`, `R3`, `R4`, `R7` to `R13` | `validate-propositions.py` | The copy of `SCHEMA.md` pinned next to each ledger |
| `ledger:profile` | `validate-propositions.py`, its check that `_meta.json` declares a profile it accepts | The same |
| `structure:S1` to `S9` | `validate-structure.py` | `docs/STRUCTURE.md` |
| `records:V1` to `V6` | `validate-verification.py` | `docs/VERIFICATION.md` |
| `coverage:text` | `check-extraction-coverage.py` | The extract skill |
| `order:ledger` | The dry run of `reorder-ledger.py` | The construct-batch skill |
| `audit:R1`, `R2`, `R3` | `audit-symbols.py`, `audit-citations.py` and `audit-code-manuscript.py`, in that order | `rules/manuscript-consistency-audit.md` |
| `proofread:L1` to `L5`, `proofread:E1` to `E7` | The per-proposition walk of the proofread skill | The proofread skill |

### What is not in the inventory

- The fourth pass of the cross-artifact audit. It runs the ledger validator.
- The theorem-boundary audit and the dry run of the location refresh. They are
  the same checks as `ledger:R9` and `ledger:R13`.
- The link catalog's currency check. Its subject is a file of this plugin, not
  a manuscript.
- The checks of the `tschema-check` plugin. They belong to another plugin.
- The stumble categories of the clarity audit, the counts in the construct
  skill's summary and the states of the analyze skill. None of them leaves a
  finding or a record for a unit under an id.
- The `location` layer of the proofread walk. It is the same check as
  `ledger:R13`.
- The records validator's warning that two methods disagree on a proposition.
  It reports part of what the entry on verdicts against a proposition states,
  and is read with that entry.
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

Three gaps need a source outside the manuscript's repository: that the cited
works exist, that the support outside the paper can be found, and that it says
what is taken from it. Issue #50 owns them.

## How an entry is verified

### Mechanical entries

`verified_by: [mechanical]` means that a script decides, whether the script is
in this plugin or looks something up in an external source. What counts as a
finding, and at which level, is this closed list:

| Source | Error | Finding that is not an error |
|---|---|---|
| The three validators | A problem reported as an error | A problem reported as a warning |
| The audit scripts | A `definite` finding | A finding of any other severity: `likely`, `suspicious` or `FYI` |
| The reordering dry run | Its report that a number of ledger lines move | Its report of manuscript lines that hold several propositions |
| The coverage check | None | Each run of text reported as uncovered, and each warning that a proposition's text was not found in the range |

A line that reports no problem, such as a pass line or a count of what was
checked, is not a finding. The exit status of a script is not used to tell the
levels apart: the audit scripts end in failure on any finding, and the coverage
check ends in failure on a finished ledger too.

The coverage check has no error level because a finished ledger still leaves
runs uncovered: front matter, headings, the bibliography. Every run is a
finding to be judged, and a run judged to be a sentence of the body fails the
entry.

A finding counts for one entry and for one or more units:

- It counts for the entry whose `criterion` it concerns. A finding that is not
  an error concerns a criterion without yet showing that it is violated:
  whether it is violated is what a judgment decides, also when the script
  itself calls the finding harmless. When several entries name the same check,
  deciding which one a finding concerns is a judgment by the reader until
  checks report to entries.
- Within that entry, a finding that names a proposition counts for that
  proposition. A cycle that the ledger validator reports counts for every
  proposition its message lists. A finding that names no proposition counts for
  every unit the entry applies to.

`on_warning` says what a finding that is not an error does to the entry:

- `judge`: the entry is unverified until someone judges the finding. The
  judgment either passes the entry or fails it.
- `info`: the finding is listed in the report and the entry passes.

`info` is the one setting that lets a warning pass, so it is allowed only on
entries the maintainer has reviewed for it. There are four: an uncited
proposition (`ledger:R3`), crossing arcs (`structure:S7`), a code symbol that
the documents never mention (`audit:R3`) and a bibliography entry that is never
cited (`audit:R2`). Every other mechanical entry says `judge`, including an
entry whose check reports no warning today: if the check starts to report one,
the warning has to be judged.

Each kind of finding that is not an error has exactly one entry. Where a
check's warning concerns the same thing as its error, they share an entry.
Where it concerns something else, it has its own.

```yaml
- id: index.arcs-do-not-cross
  class: precondition
  unit: proposition
  criterion: "No two arcs of the proposition's paragraph, or of its section, cross."
  check: structure:S7
  verified_by: [mechanical]
  on_warning: info
```

### Entries verified by methods

Otherwise `verified_by` lists verification methods from
`docs/VERIFICATION.md`, and the entry needs every one of them. An entry that
lists `proofread` also lists `cross_model`: each proofread layer is read by a
language model, and a judgment by a language model needs a second reading by
another model. A prover, a certificate, a computer-algebra system and a human
review are the methods of those names.

## The outcome of an entry for a unit

An entry has exactly one of four outcomes for a unit: `not_applicable`,
`unverified`, `failed` or `passed`. The first rule that fits decides.

1. The unit does not satisfy `applies`: `not_applicable`.
2. `check` is `gap`: `unverified`.
3. `verified_by` is `[mechanical]`:
   - the check has not been run on the current files: `unverified`;
   - a finding that is an error counts for the unit: `failed`;
   - a finding that is not an error counts for the unit: `unverified` under
     `judge`, `passed` under `info`, with the finding listed as information;
   - no finding counts for the unit: `passed`.
4. `verified_by` lists methods. For each listed method, read its current
   records for the proposition from the latest back (the greatest `checked_at`
   first, and on the same day the later line of the file first) and stop at the
   first record that the table below stops on.

   | The record is | and covers the entry's check | and covers only other checks | and what it covers cannot be established |
   |---|---|---|---|
   | `refuted` or `partial` | stop: against the entry | pass over | stop: against the entry |
   | `supported` | stop: for the entry | pass over | pass over |
   | `unresolved` or `not_attempted` | stop: undecided | pass over | pass over |

   A method with no record that stops the reading is undecided. Then:
   - any listed method is against the entry: `failed`;
   - every listed method is for the entry: `passed`;
   - otherwise: `unverified`.

   The latest record of a method does not decide alone. The two walks of the
   proofread skill each leave a record, so the latest one covers only one of
   them.

### When a check has not been run

A check has not been run for a unit in these seven cases, and no others.

1. It was not executed after the last change to a file it reads.
2. It could not run at all and ended with a tool error, for example for a
   missing input.
3. It reports that it skipped the rule because the ledger's schema version
   predates the rule or the ledger's profile is invalid.
4. It lists the unit as one it could not examine, as the location check does
   for a proposition it cannot anchor. When it reports only how many units it
   skipped, the entry is unverified for every unit it applies to.
5. The structure validator was run with `--partial`. That mode reports what a
   half-written manuscript still owes as information.
6. For the coverage check, a part of the manuscript's body was in no range it
   was run on. The body is the main file from `\begin{document}` to
   `\end{document}`, and the whole of every other file of the `\input` tree.
7. It reports that it did not evaluate the rule, or it evaluates nothing
   because an input that another rule checks is invalid. When the structure
   validator reports an error under S5, its rules S2, S6 and S7 have not been
   run, whatever they print.

One report is not a skip. When the ledger validator says that the manuscript
has no theorem-like environment, R9 has nothing to compare: its entry passes
for a proposition that is not assigned to a theorem-like block, and is
unverified for one that is.

### When a record counts

A record counts only when it is current: the proposition's entry in the ledger,
and the entries of the propositions it cites, are the ones the record judged. A
record carries no version, so this is established from outside it. Either its
`checked_at` is later than the day of the last change to those entries in the
ledger's history, or its `evidence_snapshot` matches the entry. A record that
is not current, or for which this cannot be established, is passed over,
whatever its status.

A record covers a check when the reading or computation that produced the
record performed that check. This is established from what the record's
`evidence_ref` points to. Rule 4 says what a record does when it cannot be
established: a `supported` record then counts for nothing, and a `refuted` or
`partial` record counts against every entry of its method.

The proofread skill has two walks, and neither includes the other. The
derivation walk lists L1 to L5. The empirical walk lists E1 to E7. A record
does not name its walk, so the walk is read from the checklist that
`evidence_ref` points to. A `supported` record from the empirical walk
therefore does not cover a derivation layer, and the other way round. The
empirical walk does E6 across propositions: its record for a proposition covers
E6 when the walk compared that proposition's assertion with the places that
restate it. A second reading by another model covers the checks of the reading
it repeats.

### One limit of the records

A verification record names a proposition and a method, not an entry. A
`refuted` or `partial` record therefore fails every entry of that method whose
check it covers, preconditions and obligations alike. To learn which entry the
reading faulted, read its findings.

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
verdict. That entry is a gap today.

### Preconditions come first

While any precondition is `failed` or `unverified`, the outcomes of the
obligations are not to be trusted: they were computed from an index that is
not known to be right. Their outcomes are left as computed and marked as not
to be trusted. Correct the ledger, the sidecars or the records, run the checks
again, and read the obligations after that.

### What a report names

A report on soundness names, for every outcome that is `failed` or
`unverified`, the entry and the unit, and for a gap the issue in its `owner`.
It lists each finding that passed as information under the entry it counts
for. No format is fixed here.

### No article is sound yet

Three things keep every article from being sound today, and each has an owner.

1. **Gaps.** Each entry whose `check` is `gap` is unverified for every unit it
   applies to. Its `owner` is the issue that will supply the check.
2. **Records that cannot say what they cover.** A warning under `judge` has no
   place where the judgment is recorded, so the entry stays unverified. A
   record names neither its walk nor the version of the proposition it judged.
   Issue #62.
3. **No second reading.** No tool writes `cross_model` records, so every entry
   that needs one is unverified. Issue #21.

Three more things keep some articles from being sound.

- The reordering dry run supports single-file manuscripts only, so the entry on
  reading order is unverified for a multi-file manuscript. Issue #59.
- The ledger validator's R9 reports how many propositions it skipped, not
  which, so its entry is unverified for every proposition of a multi-file
  manuscript. Issue #63.
- The audit's code pass needs a directory of analysis code, so its two entries
  are unverified for a manuscript that has none. Issue #64.

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
check and every vocabulary value is accounted for, that the entries the
maintainer reviewed keep their values, and that this document does not turn
into a second copy of the table.
