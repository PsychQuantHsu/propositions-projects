---
name: proofread
description: >-
  JSONL-driven per-proposition semantic walk in two modes. Mode A (derivation, L1-L5 + location): faithful decomposition, claim_type fit, cite completeness, cite validity, evidence_class consistency — for mathematics and formal proofs. Mode B (empirical, E1-E10 + location): value fidelity against analysis artifacts, computability from the dataset, figure-text agreement, figure provenance, whether the claimed contrast was actually estimated, claim strength vs test outcome, analytic vs stated sample, variable-role consistency, whether a composite claim holds for each component it names, and whether two exposures treated as separable are actually nested — for clinical cohorts, experiments, surveys and simulation studies, where claims rest on data rather than on prior propositions. Use for pre-submission polish, after a large rewrite, or to validate prop-extraction quality. The semantic-correctness axis — distinct from /propositions:propositions (mechanical R1-R13 gate) and /propositions:manuscript-audit (cross-artifact drift). Not for daily micro-edits (use the validator + sync rule).
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Proofread — Per-Proposition Semantic Walk

Where `/propositions:propositions` asks "is the JSONL mechanically well-formed", this skill asks
the semantic question a machine cannot: **is each claim true, faithfully stated, and actually
supported by what it rests on.** It is a guided per-proposition walk, not a script — the value is
the human/LLM judgment at each layer.

## Pick the mode first

What a claim *rests on* differs by genre, and the wrong mode audits nothing:

| Mode | Claims rest on | Layers | Dependency field |
|------|----------------|--------|------------------|
| **A — derivation** | other propositions | L1-L5 + location | `cites` (UUID → prop) |
| **B — empirical** | data, models, figures | E1-E10 + location | `artifacts` (path → file/line) |

**Mode A** fits mathematics, formal proofs, axiomatic systems — anywhere "P1 ∧ P2 ⊨ P3" is the
question. **Mode B** fits empirical研究 (clinical cohorts, experiments, surveys, simulation
studies) where a claim like *"the rate was 68% in group A vs 41% in group B (χ² = 11.2, p = .001)"* is not
derived from any prior proposition; it is read off an analysis artifact.

Running Mode A on an empirical manuscript produces a clean report with zero findings, because
L4 ("does the cited prop imply this one") has no referent. That is a false negative, not a pass.

**How to choose**: if `evidence_class` is dominated by `verified` / `derived` → Mode A. If props
carry `artifacts` or the manuscript has a Methods/Results/statistics structure → Mode B. Mixed
manuscripts (a theory section plus an experiment) run both, section by section.

---

## Mode A — derivation chains (L1-L5)

| Layer | Check | Difficulty |
|-------|-------|------------|
| L1 | Does `prop.text` truly claim the listed `asserts`? (atomic + faithful paraphrase) | mostly mechanical (the R1 substring match backs it) |
| L2 | Does `claim_type` match the text's semantics? (axiom non-derivable / definition has equality / commentary not derived / restatement truly re-states / case_split truly partitions) | semi-mechanical heuristic |
| L3 | Is everything cited in `prop.text` declared in the `cites` field? | **LLM-required** — load-bearing reference detection is semantic |
| L4 | Does each cited prop's asserts *logically imply* this prop's asserts? | **LLM-required** — derivation-chain verification |
| L5 | Is `evidence_class` consistent with `claim_type`? (derived needs cites; axiomatic truly an axiom; verified has an external proof) | schema-aware heuristic + judgment |
| location | Does `location.line` match the actual main.tex line range? | mechanical — the R13 check in the validator |

L1, L2, and location are backed by the bundled `/propositions:propositions` validator (R1-R13);
run it first so this walk can focus on L3/L4/L5, which no script can decide.

### Mode A ROI: where findings actually hide

From the dogfood pilots (below), finding density is very uneven, so coverage should be uneven too:

- Proof bodies / derivation chains: **~2.6%** finding rate (3 / 115 deep-walked props) — deep-walk these.
- Theorems 2-4 + Synthesis: **0%** (0 / 20 sampled) — sample.
- Commentary / Discussion: **0%** mechanical anomalies (0 / 151 heuristic) — heuristic scan only.

→ **Hybrid coverage**: deep-walk proof bodies, sample mid-density sections, heuristic-scan commentary. A uniform full walk spends most of its time at 0% yield.

---

## Mode B — empirical claims (E1-E10)

An empirical proposition's dependency is not another proposition. It is a **file**: a model
object, a raw data table, a figure, a line range in an analysis script. Mode B therefore reads
an `artifacts` field (see § Schema extension) instead of `cites`, and asks eight questions that
`cites`-based L4 cannot express.

| Layer | Check | Mechanizable? |
|-------|-------|---------------|
| **E1** | **Value fidelity** — does every number in `prop.text` match the artifact it comes from? | ✅ mostly — re-run the artifact, diff the numbers |
| **E2** | **Computability** — can the claimed quantity be derived from the dataset *at all*? | ✅ — check the required columns exist |
| **E3** | **Figure-text agreement** — does the cited figure show what the text says it shows? | ⚠️ partial — extract the figure's text layer, compare |
| **E4** | **Figure provenance** — is the figure computed from a fitted model, or from literals? | ✅ — read the plotting script for hard-coded values |
| **E5** | **Contrast actually estimated** — was the comparison the text claims actually fitted, or only described? | **LLM-required** — needs the model's reference level vs the text's comparison |
| **E6** | **Claim strength vs test outcome** — does the assertion's strength match what the test returned? | **LLM-required** — title/abstract/conclusion vs Results |
| **E7** | **Analytic sample vs stated sample** — did the model actually fit the N the text claims? | ✅ — `nobs()` / `ngrps()` vs the stated cohort |
| **E8** | **Variable role consistency** — does each variable play one role, or several incompatible ones? | ⚠️ partial — grep the variable across Methods / Results / model formulas |
| **E9** | **Composite vs component** — a claim asserted of a composite group: does it hold for each component the sentence names? | **LLM-required** — compute the stratified marginal effect per component |
| **E10** | **Exposure structure** — are two variables the narrative treats as separable actually nested or collinear? | ✅ — cross-tabulate every pair of binary exposures |

### What each layer catches (de-identified)

- **E1** — a superseded value survives in a sibling file: the manuscript says `p = .04`, the
  cover letter still says `p < .001`. Placeholder sweeps miss this because `p < .001` *looks*
  like a filled-in value.
- **E1, second form** — the number is not stale, it was computed a different way. A manuscript
  reported Wald confidence intervals while its own analysis script called the software's
  default, which returns profile-likelihood intervals. Point estimates matched exactly; every
  interval differed in the second decimal. Anyone re-running the script gets numbers that do
  not appear in the paper. **Re-run the artifact rather than reading its log** — this is
  invisible to any comparison that stops at the point estimate, and the fix is usually to
  state the method, not to change the number.
- **E2** — the text reports a median **in days**, but the dataset has no date column at all;
  the quantity is not merely unverified, it is **not computable** from the data as collected.
- **E3** — the text cites a figure for `p < .001`; the figure, embedded in the same document,
  prints `p = 0.4` on its face and orders the groups the opposite way.
- **E3, second form** — a correction reaches the prose and stops there. A flow diagram still
  read *"Included in analysis (N = 100)"* after the Results section had been amended to
  disclose that only 91 patients entered the primary model — and the amendment was made
  *during the same audit*, one pass earlier. A figure is a sibling file that happens to sit
  inside the document: it does not move when you edit the sentence beside it.
- **E3, third form** — a caption promising more than the figure shows. One caption offered
  *"screening, exclusions, and final allocation"*; the figure showed only allocation, and the
  dataset held no screening or exclusion counts to draw. Read every caption as a set of
  claims about what the reader will see, and check each against the rendered figure.
- **E3, fourth form** — a *summary table* is double jeopardy: it is a sibling (fixes fail to
  reach it) **and** an aggregator (it restates numbers owned by other tables). One manuscript's
  "Summary of Key Findings" still carried the superseded confidence intervals for two rows
  after the owning table had been corrected in the same audit — so the document contradicted
  itself in the one table a reader is most likely to quote without checking the body. After
  correcting any number, grep the whole document for it, not just the table that owns it.
- **E4** — a forest plot is drawn from hard-coded round numbers (the plotting script's own
  comment says `placeholder`), and its highlighted intervals assert significance exactly where
  the text says the interaction was not significant.
- **E4, a trap for the auditor** — before concluding a figure is unreproducible, search the
  **whole tree**, not the pipeline directory. One figure was briefly reported as having no
  source; its generator sat beside the output in the figures directory, and the search had
  covered only `scripts/` and the top-level `*.tex`. Check the file's own metadata first
  (`pdfinfo` naming pdfTeX rather than the plotting language is a strong hint about where to
  look). What *did* survive that correction is worth its own note: the pipeline script still
  contained a differently-labelled version of the same figure with unfilled `XXX`
  placeholders — dead code that would mislead the next person to re-run it.
- **E5** — the abstract claims group A had shorter stay than group B, but the regression used
  group C as the reference and the A-vs-B contrast was never estimated: no interval, no p-value.
- **E5, second form** — the contrast was fitted, but the text read its **sign off the
  interaction coefficient** instead of computing the marginal effect. Under treatment
  contrasts the interaction term is a *difference of differences*, not the effect in the
  exposed stratum: a main effect of `-0.213` with an interaction of `+0.096` gives `-0.117`
  in the exposed group — the same direction but **attenuated**, which a paper described as a
  larger benefit. Compute the stratum-specific estimate with an explicit contrast vector (or
  `emmeans::emtrends`) and read *that*; and check the factor coding rather than assuming
  treatment contrasts.
- **E6** — the *title* asserts an effect that the Results section explicitly says did not reach
  significance; elsewhere `p = .058` is treated as established.
- **E7** — the cohort is 100, but the primary model fitted 91 and a secondary model 78, and the
  manuscript discloses neither.
- **E7, second form** — the analysis set shrank because of a **covariate**, not the outcome.
  A Methods section read *"baseline data were complete for … length of stay"* — true of the
  outcome, and the length-of-stay model still fitted 91 of 100, because it adjusted for a
  baseline marker missing in nine. The sentence is not false; it answers a different question
  than the one the reader is asking. **Never take a stated N from prose — read
  `nrow(model.frame(m))` for every model**, and list each analytic sample separately, because
  models with different adjustment sets have different Ns.
- **E9** — a claim true of a composite, false for a component it names. *"Patients with X or Y
  showed greater benefit"* held for the composite and for Y, and **reversed for X**: the
  composite estimate was driven entirely by the Y-without-X patients. Nothing was numerically
  wrong; the sentence simply distributed a composite result over two named components. For
  every claim of the form *"patients with A or B …"*, compute the estimate separately for A
  and for B before letting the sentence stand.
- **E10** — two exposures the narrative treats as separable turn out to be nested. In one
  cohort the cross-tabulation of two binary risk factors had an **empty cell**: every patient
  positive for the first was also positive for the second. Consequences: the "A or B"
  composite was numerically identical to B alone; two subgroup models presented as independent
  tests were one nested inside the other; and a coefficient labelled as the effect of A was
  really a contrast *within* B. No individual number is wrong, and no prose reading surfaces
  it — **only cross-tabulating the exposures against each other does**. Worth checking whether
  the data-cleaning code defines a category the data never populate; that is strong evidence
  the nesting is a property of the cohort rather than a processing artifact.
- **E8** — one variable is simultaneously an Outcome Measure (abstract), a baseline
  characteristic (Table 1), an adjustment covariate (a regression), and a dependent variable
  (another table). Its coefficient is then read causally in both directions.

### Mode B ROI

Inverted relative to Mode A. Mode A's yield concentrates in proof bodies; Mode B's concentrates
where **prose meets artifact**:

- Abstract + Conclusions: **highest** — the compression step is where hedges get dropped (E6).
- Results sentences carrying a number: **high** — E1/E5/E7 live here.
- Figures and their captions: **high** — E3/E4; check the *rendered* figure, not the caption,
  and re-check after every prose correction. Figures are the second place fixes go to die:
  they are siblings that live inside the document, so they escape both the prose edit and the
  sibling-file sweep.
- Introduction / Discussion background: **low** — cites literature, not artifacts.
- Sibling files (cover letter, highlights, lay summary): **high and usually unaudited** — they
  are downstream copies that fixes fail to propagate to (E1).

- Summary / "key findings" tables: **high** — they are siblings *and* aggregators (E3 fourth
  form). Grep every corrected number across the whole document, not just its owning table.
- Any sentence of the form *"patients with A or B …"*: **high** — E9/E10 live only here, and
  neither is visible to a reading pass.

→ **Artifact-first coverage**: enumerate the analysis artifacts, walk every claim that reads
from one, then sweep sibling files for stale copies. Walking the manuscript front-to-back
spends the first several pages at ~0% yield.

→ **Watch for claims whose support is not a saved artifact.** Two shapes recur: a headline
estimate whose only trace is a *log file* (the model was fitted but never serialised, so
nothing in the repo regenerates it), and a saved model that no sentence cites (dead weight
that misleads the next person to re-run the pipeline). Both are worth listing explicitly —
the first is a reproducibility gap the authors will be asked about, the second is a cleanup.

→ **Report coverage as a number, not as a verdict.** "Is it clean?" should be answered with a
measured fraction: count the numeric tokens in the document, then say how many were recomputed
from an artifact, how many were only checked for internal arithmetic, and how many are
unverifiable in principle (no raw data in the repo). A walk that recomputed 12% and said
"looks fine" and a walk that recomputed 90% are different claims; only the number distinguishes
them, and stating it usually reveals that the untouched surface is where the errors are.

### Schema extension for Mode B

Mode B needs two additions. Both are **additive** — a Mode A ledger stays valid.

```jsonc
{
  "artifacts": [                          // replaces `cites` as the dependency edge
    { "path": "output/model_primary.rds",
      "kind": "model",                    // model | dataset | figure | script | table
      "locator": "fixef()['time:group_B']",// what inside the artifact
      "recheck": "Rscript -e '...'" }     // re-runnable command
  ],
  "claim_type":     "result",             // NEW: result | interpretation
  "evidence_class": "tested"              // NEW: measured | tested | descriptive | not_computable
}
```

New `claim_type` values:

| Value | Meaning |
|-------|---------|
| `result` | An empirical finding read off an artifact |
| `interpretation` | What the authors read *into* a result (the E6 surface) |

New `evidence_class` values — note that all five existing values (`verified`, `derived`,
`hypothesized`, `conventional`, `open`) describe **logical** provenance; none of them can say
"supported by data", which is why an empirical prop has nowhere to sit in the v1.5 enum:

| Value | Meaning |
|-------|---------|
| `measured` | A value read directly from data or model output |
| `tested` | Supported by a named test, with the statistic reported |
| `descriptive` | Reported without inferential support (no test was performed) |
| `not_computable` | The quantity cannot be produced from the dataset as collected (an E2 failure, recorded rather than silently dropped) |

`not_computable` is deliberately a first-class value: an E2 finding is the most consequential
thing this mode detects, and it should survive in the ledger rather than becoming a deletion
with no trace.

---

## Procedure

### Step 0: Prerequisite — mechanical gate, then pick the mode

```
/propositions:propositions   # R1-R13 must be green (or WARN-only) before walking
```

A walk on a JSONL that fails R1/R7/R8 wastes effort — fix mechanical drift first.

Then settle the mode (§ Pick the mode first). Announce it: *"Mode B (empirical) — claims rest
on artifacts, walking E1-E10."* Running the wrong mode yields a clean report that means nothing.

**Mode B also needs an artifact inventory before Step 1.** Enumerate what the claims can be
checked against, and confirm each is re-runnable:

```bash
ls output/*.rds analysis/*.pkl 2>/dev/null      # fitted models
ls rawdata/*.csv data/*.parquet 2>/dev/null     # datasets
ls figures/*.pdf figures/*.png 2>/dev/null      # figures
ls scripts/*.R scripts/*.py 2>/dev/null         # the code that produced them
```

If no artifact is re-runnable, Mode B degrades to a consistency check between prose and prose.
Say so rather than reporting E1 as passed.

### Step 1: Generate the `.proofread/<file>.md` checklist from the JSONL

For each prop in `manuscript/propositions/main.jsonl`, emit one line, grouped by
`containing_block`:

```markdown
- [ ] **P{seq}** `{uuid_short}` [{claim_type}] @L{start}-L{end} — "{first 80 chars of text}…" (asserts: {N}, cites: {N})
```

Add a git-blame hyperlink per line for the audit trail.

### Step 2: Decide coverage (AskUserQuestion, 4 options)

| Strategy | Use case | Time |
|----------|----------|------|
| By section (e.g. Theorem 1, ~40 props) | section-cohesive review | 20-30 min |
| By claim_type | foundational props first | variable |
| By priority area (recent-change cluster) | post-PR follow-up | 25-40 min |
| Full manuscript | pre-submission gate | 2-3 h |

Default toward the hybrid ROI strategy above rather than a flat full walk.

### Step 3: Per-prop walk

**Mode A.** For each prop, present `prop.text` (raw), `prop.asserts` (atomic list), `prop.cites`
(resolve each UUID via a main.jsonl lookup), and `claim_type` / `evidence_class`. Verify:

- L1 — do the asserts faithfully decompose the text?
- L2 — does claim_type fit?
- L3 — is anything cited *in the text* but missing from the `cites` field?
- L4 — does each cited prop's asserts logically imply this prop's asserts?
- L5 — is evidence_class consistent?
- location — spot-check main.tex line N: does prop.text start there?

**Mode B.** For each prop, present `prop.text`, its `artifacts`, and `claim_type` /
`evidence_class`. Then **actually re-run the artifact** — reading the analysis log is not
enough, because a stale log is exactly what E1 is looking for:

- E1 — re-run, diff every number in the text against the output.
- E2 — does the dataset carry the columns this quantity requires? (If the claim is in days,
  is there a date column?)
- E3 — extract the figure's own text layer; does it agree with the sentence citing it?
- E4 — read the plotting script: model object, or literals?
- E5 — read the model's formula and reference level; is the text's contrast among the
  estimated terms?
- E6 — compare the assertion's strength across title / abstract / Results / Conclusions.
  Strength must not increase as you move away from the Results section.
- E7 — `nobs()` / `ngrps()` (or the framework equivalent) vs the N the text claims.
- location — same as Mode A.

Do E6 **last and across props**, not per-prop: it is the only layer whose finding lives in the
*difference* between two places in the manuscript.

Mark `[x]` (CLEAN on all six), `[~]` (finding — detail in the § Findings ledger), or `[-]`
(out of scope).

### Step 4: Findings ledger

Keep an inline § Findings table in `.proofread/<file>.md` for anything below L3-blocking
severity. Escalate to a separate `audit-finding` GitHub issue when severity ≥ L3
cite-completeness OR ≥ 10 props are affected (per the `code-and-manuscript-sync.md` cluster
discipline).

### Step 5: Ship fixes

Route each finding through `manuscript-jsonl-sync.md`:

- L1 / L3 cite-completeness → jsonl-only edit (add the missing UUID)
- L2 misclassification → fix `prop.claim_type`, then re-validate
- L4 "COMPRESS" (a camera-ready candidate: the prose is terser than the claim) → expand wording in main.tex, then sync `prop.text`
- L5 mismatch → fix `evidence_class`, verify against the schema

Mode B routes differently, because most findings are **not** ledger edits:

- E1 value drift → fix the prose to match the artifact, **and sweep every sibling file**
  (cover letter, highlights, slides, lay summary). A value fixed in one place and not the
  others is the same finding re-opened.
- E2 not computable → this is an authors' decision, not an edit. Record
  `evidence_class: not_computable`, surface it, and **do not** silently reword the claim into
  something the data does support — that substitutes your judgement for theirs.
- E3 / E4 figure findings → regenerate from the model, or withdraw the figure. Never patch the
  caption to match a figure you have not verified.
- E5 → either estimate the contrast, or restate it descriptively. Say which was done.
- E6 → weaken the assertion to the test's outcome. The title is the highest-yield surface.
- E7 → disclose the analytic N; do not quietly change the stated cohort.
- E8 → resolve what the variable *is* before touching any sentence that uses it.

**Discipline**: E2, E5, E7 and E8 change what the paper claims. Those belong to the authors.
Produce the evidence and the options; do not decide.

Commit with a cross-link to the `.proofread` ledger entry.

## When NOT to use

- Daily micro-edit → the R1-R13 validator + sync rule is cheaper
- Pre-extraction phase (no JSONL yet) → run `/propositions:propositions` (Operation C) first
- Commentary-only sections → a heuristic scan suffices; deep-walk ROI is ~0%
- Empirical manuscript with no re-runnable analysis artifacts → Mode B cannot do E1/E4/E7;
  say so explicitly rather than reporting a clean walk

## Provenance

**Mode B** was derived from a pre-submission audit of a clinical retrospective-cohort
manuscript (2026-08, private). A Mode-A-shaped review had already passed it; the artifact-first
walk then surfaced eight distinct failure classes, one per layer — including a reported
time-to-event result that the dataset could not produce at all (no date column existed), and a
figure drawn from literals its own script labelled `placeholder`. All eight are recorded
de-identified in § What each layer catches.

Two structural lessons from that pilot, both encoded above:

1. **Sibling files are where fixes go to die.** The single highest-yield sweep was re-checking
   the cover letter and highlights after the manuscript was corrected.
2. **Every high-value finding came from a cross-model or adversarial pass, none from
   self-review.** The author-side walk reported clean each round. Budget for an independent
   reader; see `/parallel-ai-agents`.

Mode B was then run against that same manuscript after six rounds of auditing had declared it
settled. It returned three findings — one E1 (a confidence-interval method mismatch against
the manuscript's own script) and two E3 (a flow diagram contradicting a disclosure added one
pass earlier, and a caption promising content the data could not supply). The E3 pair is why
figures are called out separately in the ROI list above: **a clean prose pass is not evidence
that the figures agree with it.**

A third pass added an **adversarial** leg alongside the self-review: three independent
reviewers (statistical, provenance, hostile-peer-reviewer) run against the same manuscript,
after a full cell-by-cell recomputation of every model-derived number had already been done by
the author-side walk. The recomputation confirmed 189 model tokens and 120 arithmetic tokens
and found four disclosure gaps — but the **heaviest** finding of the round came from the
hostile reviewer: a subgroup claim whose point estimate ran the opposite way for one of the two
exposures the sentence named (E9), which the recomputation had passed over because every
individual number in it was correct. That is the second independent confirmation of lesson 2
above, and the reason E9 and E10 exist as layers at all.

Two cautions the same round produced:

3. **Verify the adversary too.** One reviewer comment asserted that denser measurement sampling
   produces a *steeper* apparent decline per measurement occasion. It is the reverse — a
   per-occasion slope is the per-day slope times the days per occasion, so denser sampling
   *flattens* it. The claim was refuted from the data before any edit was made. An adversarial
   pass raises the hit rate; it does not license accepting its output unchecked.
4. **The auditor's own fixes need auditing.** Three of the round's findings were introduced or
   missed by the *previous* audit round — a figure line written one pass earlier, a summary
   table not updated alongside the table it summarises, and a table note that became untrue the
   moment two of its nine rows were corrected. Re-audit what you just changed, in the same
   pass, against the artifact rather than against your intent.

**Mode A** methodology validated on `psychophysical_representations` #107 — 3 pilots: (1) a 23-prop
theorem file surfaced 13 location-drift findings (escalated + closed); (2) a 46-prop theorem
surfaced 2 cite-completeness + 2 compress findings (all fixed); (3) a full 286-prop walk
(hybrid: 115 deep + 20 sample + 151 heuristic) surfaced 0 additional — the ledger that froze
the ROI numbers above.

## Cross-link

- `/propositions:propositions` — the mechanical R1-R13 gate this walk assumes has passed
- `/propositions:manuscript-audit` — cross-doc R1-R4 drift
- Rule [`../../rules/manuscript-jsonl-sync.md`](../../rules/manuscript-jsonl-sync.md) — sync discipline for L1/L3/L4 fixes
