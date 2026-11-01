# Mathematical manuscripts (profile `default`)

Read this when the ledger's `_meta.json` declares no profile or `"profile": "default"`. It
condenses the extraction prompt the plugin ships (`docs/EXTRACTION-PROMPT.md`); the ledger's
own pinned `EXTRACTION-PROMPT.md` is the authority for that ledger's schema version.

## Vocabulary the validator accepts

`claim_type` (R12) — exactly these twelve:

| Value | Use for |
|-------|---------|
| `axiom` | Structural starting point, boundary condition ("γ(1, s) = 1 and η(1, s) = s") |
| `definition` | A new term or object ("Let S° := S \ {0}.") |
| `hypothesis` | What a theorem or lemma assumes ("Suppose ξ admits …") |
| `claim` | A derived assertion ("Then F = id follows.") |
| `case_split` | The header of one branch of a case analysis — a structural leaf; the branch's content goes in the adjacent `claim` / `display_equation` props |
| `display_equation` | A standalone display with no surrounding prose |
| `restatement` | An equivalent reformulation of an earlier prop |
| `commentary` | Motivation and meta-text ("In what follows we focus on …") |
| `example` | A concrete instance ("For instance, take u(y) = ln y.") |
| `connective` | Clause-level only: "Hence," / "Therefore," — `asserts` must be empty (R10) |
| `reference` | Clause-level only: "(Section~\ref{…})", "\citep{…}" — `asserts` must be empty (R10) |
| `scope_qualifier` | Clause-level only: "for every $s \in S$" — cites its parent clause |

`evidence_class` (R11, optional field) — exactly these five: `verified` (proved in the paper),
`derived` (logical consequence of earlier props), `hypothesized` (assumed), `conventional`
(definitional choice), `open` (unproved / future work).

## Granularity

- **heterogeneous** — one prop per declarative sentence. A sentence ending in `:` or `,`
  that introduces a display keeps the display in the same prop.
- **clause-level** — split at `.`, `;`, `:`, and at a comma before a conjunction (and, but,
  or, hence, therefore, thus, so, then, while, where, which). Never split inside math
  (`$P_x(y) = F((u-v)/\sigma)$` is one unit), inside a list of objects ("u, v strictly
  monotonic"), or inside a citation. Expect about 2–4 times as many props as heterogeneous;
  under 1.5 means you are still splitting sentences, over 5 means you are splitting inside
  expressions.

Not propositions in either mode: section headings, `\emph{Step N (…).}` proof markers,
comments, standalone `\label{…}` lines.

## Environment boundaries

Theorem-like statements are where extraction has gone wrong before: a pilot extractor stopped
at the end of a theorem's hypothesis paragraph and dropped the case enumeration and closing
prose that sat before `\end{theorem}` — 60 lines of the statement went missing. The rule:

1. `grep -n "\\\\begin{<env>}\\|\\\\end{<env>}"` the file (or use
   `scripts/audit-theorem-boundaries.py`) and take the physical line range.
2. Put a `TARGET ENV` header naming the env, its label, and the grep-verified begin/end lines
   above the text you extract.
3. The statement ends only at `\end{<env>}`. Enumerations, `align*` blocks and prose between
   the hypothesis and `\end{…}` are part of it.
4. Extract the matching `proof` environment in a separate pass, with `containing_block`
   `<label>/proof/<step>`.

`containing_block` is the label-only form: `thm:<label>`, `lem:<label>`, `sec:<label>`.

## Curation checklist

- Every `text` is verbatim (the coverage check and R1 both pass).
- `claim_type` is not lazily `commentary`: structurally load-bearing sentences are `claim` or
  `axiom`.
- Boundary conditions sit in their own `axiom` prop, not buried inside a `claim`.
- `cites` lists only props this one logically depends on; when unsure, leave it out (an
  orphan is a warning, a wrong cite is a false dependency).
- `asserts` states the content in plain words, stripped of rhetoric ("we observe that").
