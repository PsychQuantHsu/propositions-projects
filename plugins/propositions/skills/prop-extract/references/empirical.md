# Empirical manuscripts (profile `empirical`)

Read this when the ledger's `_meta.json` declares `"profile": "empirical"` (schema 1.7+).
Empirical manuscripts — psychology papers with Method, Results and Discussion — mostly lack
theorem environments, and most of their claims rest on data or on other people's work rather
than on derivation. The `empirical` profile adds vocabulary for exactly that; everything in
the default vocabulary is still available (definitions, hypotheses, commentary, references).

## Vocabulary the validator accepts

`claim_type` (R12): the twelve default values plus

| Value | Use for |
|-------|---------|
| `result` | An empirical finding read off data or a model ("Recall was 0.62, 95\% CI [0.58, 0.66].") |
| `interpretation` | What the authors read *into* a result ("These values suggest that the delay effect is robust.") |

`evidence_class` (R11, optional field): the five default values plus

| Value | Use for |
|-------|---------|
| `measured` | A value read directly from data or model output: proportions, means, CIs, sample sizes |
| `tested` | Supported by a named test with its statistic reported (χ², t, F, with p) |
| `descriptive` | Reported without inferential support — no test was performed |
| `not_computable` | The quantity cannot be produced from the data as collected (a proofread Mode B E2 finding) |
| `external` | Support lies outside this paper: the works cited in the sentence, or, when nothing is cited, the field's common knowledge |

These values are defined together with proofread Mode B; that skill's table and this one must
agree.

## How a pilot sorted real sentences

A pilot extraction of an empirical manuscript (13 sentence-level props from an introduction
paragraph and a Results paragraph) settled these conventions. Results sentences all fit the
Mode B values; every sentence that fit nothing was a claim supported from outside the paper,
which is why `external` exists.

| Sentence shape (synthetic examples) | `claim_type` | `evidence_class` |
|-------------------------------------|--------------|------------------|
| "Memory errors are common in everyday life." (motivation) | `commentary` | — (omit) |
| "Memory has been studied in many areas of psychology." (field claim, no citation) | `claim` | `external` |
| "For example, researchers study false recall \citep{…}." | `example` | `external` |
| "A common task is the so-called free-recall paradigm (FR)." (introduces a term the field supplies) | `definition` | `external` |
| "Mean recall was 0.62, 95\% CI [0.58, 0.66]." | `result` | `measured` |
| "The null model was rejected, $\chi^2(2) = 12.4$, $p = .002$." | `result` | `tested` |
| "These values suggest that the delay effect is robust." | `interpretation` | `descriptive` (`tested` when a test backs it) |
| "We now turn to the second experiment." (signposting) | `commentary` | — (omit) |
| "We regard $R_d$ as the recall rate after the delay." (operational definition) | `definition` | `conventional` |

Whether an `external` claim carries a citation is read from its text (`\cite…` commands), not
recorded separately — so do not invent a second field for it. `cites` stays reserved for
UUIDs of propositions in this ledger (R2 rejects anything else).

Method sections were not part of the pilot. Until a ledger settles them, use: counts of
participants, items or trials → `result` + `measured` (proofread Mode B's E7 compares them
against the data); procedural description ("We used software X to fit the model") →
`commentary` with no `evidence_class`, and say in `notes` that this is a provisional choice.

## Splitting statistics-heavy sentences

- **heterogeneous**: one prop per sentence, even when the sentence reports several numbers.
- **clause-level**: split at "whereas", "while", "meanwhile" and at `;` between estimates;
  keep each estimate with its own CI in one clause. A trailing interpretation ("…, indicating
  a discrepancy") becomes its own `interpretation` clause.
- Copy `\%` exactly. Before plugin 0.5.0 the validator treated `\%` as the start of a comment
  and failed every prop containing it, and every prop after it on the same line
  (propositions-projects#25); if R1 fails only on such props, check the plugin version.

## Structure

- `containing_block`: `sec:<label>` when the section has a `\label`; APA manuscripts often
  have none, so use `sec:<slug of the heading>` (`sec:method`, `sec:results`,
  `sec:secondary-analyses`) and keep it stable across the ledger. An introduction
  whose `\section` is commented out is `sec:introduction`.
- Tables and figures are excluded by the coverage check and listed in its output. Sentences
  that report table values ("Table~\ref{tab:des} shows …") are extracted like any other
  sentence; proofread Mode B's E3 checks them against the table.
- Footnotes and the abstract are extracted only if the user asks; say which you skipped.

## Curation checklist

- Every `text` is verbatim, `\%` and `\citep{…}` included.
- Numbers are `result`, readings of numbers are `interpretation` — a sentence that does both
  is one prop in heterogeneous mode (classify by its main assertion) and two in clause-level.
- `external` is used only when the support is outside the paper; a claim supported by this
  study's data is never `external`, even if it also cites prior work.
- `evidence_class` is omitted for `commentary` and signposting rather than forced.
