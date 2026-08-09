# Proposition-iso Schema (Locke project, #69)

> "If `main.tex` says X, `propositions/main.jsonl` says X — and the bijection is
> machinable."

## Storage layout (#77 storage refactor, 2026-05-14)

Propositions live in two files per scope, **not** a single wrapper JSON:

| File | Content | Why split |
|------|---------|-----------|
| `_meta.json` (or `<stem>_meta.json` for fixtures) | `schema_version`, `source`, `coverage`, `axioms` — root-level metadata only | Read once, rarely edited |
| `main.jsonl` (or `<stem>.jsonl`) | One proposition per line, no wrapper | Line-addressable: read/write a single prop is ~200 tokens instead of ~60k tokens for a full-file rewrite |

Legacy single-file `main.json` (Phase 1) is deprecated; the validator reads
both layouts during migration via `--json` (legacy) vs `--jsonl` + `--meta`
(new). `scripts/migrate-json-to-jsonl.py` performs one-shot conversion.

Rationale: at Phase 2 scale (~600-900 props), a single JSON file approaches
200KB / 60k tokens. AI maintenance (Edit / re-extraction / schema migration)
becomes infeasible. JSONL keeps per-line edits cheap and lets schema-field
additions run as a python one-liner rather than re-extraction.

## Phase 1 → Phase 2 transition status (current state, 2026-05-17 — post Phase C merge)

**Bijection viability is now proven** (3 pilots in #107 demonstrated full 286/286 R1 PASS at hybrid coverage). Phase 2 clause-level extraction has begun incrementally — Theorem 1 fully migrated via #96 Phase C big-bang merge 2026-05-17. Remaining sections still on Phase 1 baseline (tracked as Stage 3 — see #76 #94).

### Dual-coverage state (mixed Phase 1 / Phase 2)

| File | Props | Phase | Status |
|------|-------|-------|--------|
| `main.jsonl` | 321 | Mixed (Phase 1 baseline + Phase 2 clause-level for Theorem 1) | Theorem 1 migrated via #96 Phase C 2026-05-17; other sections await Stage 3 |
| `_stage2/theorem1.jsonl` | 81 | Phase 2 clause-level | **FROZEN historical record** — merged into main.jsonl 2026-05-17 via #96 Phase C |
| `_pilot/theorem1_statement_clause_level.jsonl` | 14 | Phase 2 clause-level | Frozen historical pilot (#77 ROI evidence) |

### Phase 1 baseline granularity (legacy, `main.jsonl` only)

| Granularity | Est. proportion |
|-------------|-----------------|
| Sentence-level (1 sentence = 1 prop) | ~50% |
| Multi-sentence compound (跨 `,`, `.` boundary) | ~22% |
| Theorem-statement level (整 theorem = 1 prop) | ~15% |
| Byte-range LaTeX fallback (35 props starting at `\]` / `\ref{}` / `\item`) | ~12% — cleanup tracked by #76 |
| Clause-level (split at `,`, `;`) | ~1% |

### Sister-issue completion inventory (#77 strategy phases 1-10)

| Step | Status | Where |
|------|--------|-------|
| 1. EXTRACTION-PROMPT.md clause-level mode | ✅ DONE | `EXTRACTION-PROMPT.md §clause-level mode` |
| 2. Theorem 1 pilot | ✅ DONE | `_pilot/theorem1_statement_clause_level.jsonl` (R1=14/14) |
| 3. ROI evaluation | ✅ DONE | `_pilot/ROI-evaluation.md` — verdict GO (2.33× expansion, 100% R1 PASS) |
| 4. GO/NO-GO decision | ✅ GO | #96 commenced Stage 2 work |
| 5. Full re-extract | ✅ Theorem 1 DONE / 🟡 Stage 3 PENDING | #96 Phase C merged 2026-05-17; rest of manuscript tracked as Stage 3 (#76 #94) |
| 6. SCHEMA.md transition status | ✅ DONE | this section, 2026-05-16 |
| 7. Validator R1 (`prop-subset-check`) | ✅ DONE | `normalize_for_match` + bijection (#83 #84 closed) |
| 8. R3 connective/reference/scope_qualifier rule | ✅ DONE | #83 `structural_leaf_types` extension |
| 9. R4 PATTERN-A framework-aware re-evaluation | ✅ DONE | #103 conditional-vs-universal detection (2026-05-16) |
| 10. 6-AI verify ensemble final confirmation | ⏳ pending | run after this section lands |

### Mechanical contract implications (unchanged from Phase 1, validated for Phase 2)

- **R1 (`prop-subset-check`)** uses `normalize_for_match` for resilient substring containment. Phase 2 clause-level props are verbatim-findable by design; Phase 1 baseline relies on the substring proxy. Both pass under current validator.
- **R1.5 surjective coverage** is checked at top-level `\section{...}` granularity only. Clause-level R1.5 calibration is deferred to #96 Phase C (sections without prop coverage WARN-only, not blocking).
- **R3 DAG** ignores `connective` / `reference` / `scope_qualifier` claim_types as structural leaves (#83); orphan threshold re-calibrated.
- **R4 PATTERN-A** detects boundary-axiom contradictions with framework-awareness — axiom prop containing literal `η(1,s)=s` substring AND framed as universal (no "imposed locally" / "framework of \citet{DobleHsu" / etc. signal phrases) → contradiction with η=f(s) hypothesis + f-extension claim. Post-#60 Path C conditional framing skips false-positive (#103).
- **Full bijection contract** holds for sections that have been migrated to Phase 2 (Theorem 1 = 81/81 R1 PASS in `main.jsonl` post Phase C merge 2026-05-17, was `_stage2/theorem1.jsonl` 42→81 during Phase B). Remaining sections in `main.jsonl` use Phase 1 substring proxy — both states coexist transparently per the dual-coverage table above.

The "Vision" section below describes the **Phase 2 in-progress architecture** — fully active for migrated sections, target state for remaining sections. Both Vision and the dual-coverage state are load-bearing; neither is purely aspirational.

## Verification status (per #71, 2026-05-16)

The validator (`scripts/validate-propositions.py`) checks `text` (R1 substring containment), `cites` (R2 resolve + R3 DAG), `location` line ranges vs theorem envs (R9), UUID format (R7), uniqueness (R8), and framework-aware boundary axioms (R4 PATTERN-A, #103). It does **NOT** check `asserts`.

The `asserts` field is **author cognitive paraphrase** — "what am I asserting here" — filled by LLM during extraction and not mechanically verified. Treat as **descriptive metadata**, not validated truth.

### Baseline audit (n=20, 2026-05-16, revised post-6-AI ensemble)

Per #71 narrowed-scope audit (`_audit/asserts_baseline_2026-05-16.md`), stratified-random sample of 20 props across top-5 claim_types. **Initial self-audit reported 0% hallucination; 6-AI verify ensemble's Devil's Advocate empirically caught a label-hallucination on Prop 18 ("Specialization I" — grep'd main.tex, 0 occurrences). Verdicts revised:**

| Verdict | Count | Rate (n=20 point estimate) |
|---------|-------|----------------------------|
| ACCURATE | 16 | 80.0% |
| PARAPHRASE-DRIFT | 2 | 10.0% |
| HALLUCINATION | 1 | **5.0%** (Prop 18, reclassified) |
| UNDECIDABLE | 1 | 5.0% |

**Statistical caveat (per Codex cross-model + DA-1 finding)**: 5% prop-level point estimate spans 38/667 assert-level entries (5.7% assert coverage). With n=20 and 1 observed hallucination, one-sided 95% upper CI bound ~22% — wide interval given sparse coverage. Headline 5% should NOT be treated as population estimate.

**Outcome**: **Borderline Path A → Path B** (threshold matrix's 1-5% range hit exactly). The single hallucination was a low-stakes label drift (not mathematical claim drift). Cross-model 6-AI ensemble caught it via independent grep — suggests **lightweight verify-time cross-model review may be a viable alternative to standalone R5 validator** (cheaper, infrastructure already exists, no schema changes).

**Auditor-bias warning + audit-self-correcting demonstration**: self-audit by Claude (LLM-extracted asserts audited by Claude itself) is structurally biased. The fact that 6-AI ensemble caught a self-audit blind spot **validates the audit methodology** — cross-model review is the bias-correction mechanism. User should treat the **revised 5% rate as more reliable than the initial 0% report** because of the ensemble correction. See audit file §Path recommendation for full discussion.

### Implications for downstream consumers

- **Third-party readers** (paper reviewers, future maintainers): treat `asserts` as **author cognitive paraphrase** suggesting interpretation of `text`, not as machine-verified atomic facts. If asserts and text disagree, text + .tex location wins.
- **AI tools** (downstream skill consumers, future Phase 2 R5 design): same caveat — when reasoning about prop semantics, prefer `text` + `.tex` context over `asserts` for ground truth.
- **Future R5 validator**: deferred (per #71 narrowed scope). New follow-up issue can cite this baseline to argue Path A (doc-only) vs Path B (R5 design) with concrete numbers.



## Vision (Phase 2 in-progress architecture)

Every declarative clause in `manuscript/main.tex` corresponds to **exactly one** proposition
in `manuscript/propositions/main.jsonl`. The two files are **isomorphic** under
the bijection enforced by `scripts/validate-propositions.py`. This makes the
manuscript's argument explicit as a DAG of cite-able atomic claims (Locke's
*Essay* atomism + Spinoza's *Ethics* geometric build-up + Wittgenstein's
*Tractatus* numbering, applied to a math paper).

## Bijection contract

> **Granularity disclaimer**: the table + edge-case rules below describe the
> **heterogeneous Phase 1** mode (the 286 props in `main.jsonl` as of 2026-05-16;
> 35 byte-range fallback subset tracked by #76).
> Phase 2 clause-level mode (#77 → ongoing migration via #96) splits at finer
> boundaries (`,` `;` `:` + conjunction-prefixed `,`) — see EXTRACTION-PROMPT.md
> §clause-level mode for the canonical rules. When the two specs conflict for
> a given .tex element, **clause-level mode supersedes** for any prop tagged
> with the Phase-2-only claim_types (`connective` / `reference` / `scope_qualifier`).
> The migrated subset (Theorem 1, 87 props
> in `main.jsonl` containing_block `thm:eta-s` post Phase C 2026-05-17, canonicalized 2026-05-18 per #113)
> follows clause-level rules; Phase 1 baseline (other theorems / sections)
> retains heterogeneous rules until Stage 3.

| .tex element | Phase 1 (heterogeneous) | Phase 2 (clause-level) |
|--------------|--------------|--------------|
| Period-terminated declarative sentence (prose) | ✅ 1 prop | Split into clauses (≥1 prop) |
| `\begin{equation}...\end{equation}` standalone (no surrounding prose) | ✅ 1 prop (claim_type: `display_equation`) | Same |
| Display equation `\[ ... \]` **immediately preceded** by prose ending in `:` or `,` | ❌ subsumed into adjacent prose prop | Separate prop (clause boundary on `:`) |
| Sentence within `\begin{theorem}{...}\end{theorem}` | ✅ each sentence = 1 prop, grouped by `containing_block` | Each clause = 1 prop |
| Sentence within proof body (`\begin{proof}...\end{proof}`) | ✅ same as theorem | Each clause = 1 prop |
| Item in `\begin{itemize}` / `\begin{enumerate}` | ✅ each item = 1 prop | Same |
| Table cell | ✅ each row of meaningful claim = 1 prop | Same |
| Footnote sentence | ✅ each = 1 prop, `containing_block: footnote-N` | Each clause = 1 prop |
| `\section{...}` / `\subsection{...}` / `\paragraph{...}` headings | ❌ structural marker | Same |
| `\emph{Step N (description).}` proof step header | ❌ structural marker (但 cite 時可作 anchor: `cites: ["P037"]` 而非 `cites: ["Step 1"]`) | Same |
| Comments `% ...` | ❌ | Same |
| `\label{...}` / `\ref{...}` / `\cite{...}` 命令本身 | ❌ (但 expression they're in 是 prop) | Phase 2 may emit `claim_type: reference` for pure cross-ref clauses |
| Linguistic connective ("Hence,", "Therefore,") | ❌ absorbed into following clause's prop | ✅ 1 prop, `claim_type: connective` (empty asserts) |
| Subordinate scope ("for every $s \\in S$") | Absorbed into parent prop's `scope_qualifiers` | ✅ separate prop, `claim_type: scope_qualifier` |

### Sentence boundary edge cases (Phase 1 heterogeneous)

- Math display inside a sentence (e.g. "Suppose ... \\[ x = y \\] holds for all ..."): the **whole sentence** including the display is 1 prop.
- 並列子句（"A holds, and B holds."）: **1 prop**(同句號內,語意連帶);若 author 想拆,改寫成兩句。Phase 2 clause-level mode splits this into 2 consecutive props — the JSONL file line order preserves the clause sequence.
- Parenthetical 補充（"Theorem 3 holds (under philandering)."）: **1 prop**(整句)。Phase 2 clause-level may split parenthetical as `scope_qualifier` clause.
- 跨段 logical chain（"From (1), it follows that ... // Therefore, ..."）: **2 props**,後句 `cites` 前句。Phase 2 may add a `connective` prop for "Therefore," in between.
- LaTeX-rendered list（`\begin{enumerate} \item ... \item ... \end{enumerate}`）: 每 item 1 prop;list intro 句若有 1 prop。Same in Phase 2; each item itself may further split into clauses.

### Versioning

`_meta.json` 含 `schema_version: "1.6"`(v1.0 = pre-#77 single-file JSON;v1.1 =
post-#77 JSONL + _meta sidecar + sentence_index/clause_index fields;v1.2 =
post-`migrate-prop-id-to-stable-uuid` UUID v7 identity contract,P/C-prefix 改
成 view-time derivation;**v1.3** = `sentence_index` / `clause_index` 移除,
proposition ordering 改用 JSONL 檔案行序;**v1.4** = `retired` 欄位新增
(Hsu case #146/#147 材料停用追蹤;v1.4/v1.5 首次出現在 Hsu ledger 的釘住副本,
本 canonical 於 add-manuscript-onboarding change 回收);**v1.5** =
`retired.superseded_mechanism` 欄位新增;**v1.6** = multi-file manuscript 支援:
`location` 允許檔名前綴(見 §Multi-file manuscripts)+ `_meta.json` 選填
`source.parts` 快照)— schema 改動要 bump version + migration note。

## File layout

```
manuscript/propositions/
├── _meta.json             # schema_version + source + coverage + axioms
├── main.jsonl             # 1 prop per line, in main.tex reading order
├── _smoke_tests/
│   ├── rollback_60.tex
│   ├── rollback_60_meta.json
│   ├── rollback_60.jsonl
│   ├── rollback_60_real.tex
│   ├── rollback_60_real_meta.json
│   └── rollback_60_real.jsonl
└── _pilot/
    ├── theorem1_statement_clause_level_meta.json
    └── theorem1_statement_clause_level.jsonl
```

## `_meta.json` schema (root metadata)

```json
{
  "schema_version": "1.6",
  "source": {
    "file": "manuscript/main.tex",
    "parts": ["parts/part1-intro.tex", "parts/part2-theory.tex"],
    "commit_sha": "abc1234",
    "extracted_at": "2026-05-14T08:00:00+08:00",
    "extractor": "claude-opus-4-7 (manual curation)"
  },
  "coverage": {
    "sections_extracted": ["sec:setup (L86-276)", "..."],
    "phase": "Phase 1 heterogeneous | Phase 2 clause-level | mixed",
    "expansion_metric": "(optional, pilot only)"
  },
  "axioms": [...]  // optional — UUID list of claim_type=axiom props for mechanical lookup
}
```

`axioms` array is derivable from `main.jsonl` via `claim_type == "axiom"` filter,
so most fixtures omit it. Keep it in `_meta.json` only when there is a curated
ordering or annotation not reproducible from the JSONL itself.

## `main.jsonl` schema (per-line propositions)

Each line is a complete proposition JSON object (no enclosing array, no
trailing comma). Empty lines and lines beginning with `//` are skipped by
the validator (allow hand-written comments in fixtures).

## Per-proposition schema

```json
{
  "id": "01910b9c-d4f0-7000-8000-0123456789ab",
  "text": "verbatim sentence from main.tex (including inline math, no LaTeX escapes touched)",
  "location": "main.tex:L214",
  "containing_block": "sec:setup / lem:affine-bijection / thm:eta-s / discussion / footnote-3 / etc.",

  "claim_type": "axiom | definition | hypothesis | claim | case_split | display_equation | restatement | commentary | example | connective | reference | scope_qualifier",

  "asserts": [
    "human-readable atomic claim",
    "atomic claim 2 (if compound sentence)"
  ],

  "mathematical_objects": ["η", "λ", "s", "γ"],
  "introduces": ["S°"],

  "cites": ["01910b9c-d4f0-7037-8000-...", "01910b9c-d4f0-7082-8000-..."],
  "cited_by_inferred": ["01910b9c-d4f0-7247-8000-...", "01910b9c-d4f0-7301-8000-..."],

  "scope_qualifiers": {
    "for_all": ["x \\in I", "s \\in S"],
    "exists": [],
    "subject_to": ["philandering hypothesis"]
  },

  "evidence_class": "verified | derived | hypothesized | conventional | open",

  "notes": "optional human note (not used by validator)"
}
```

> **v1.2+ schema note**: the `id` field is a UUID v7 string (RFC 9562 §5.7),
> not a sequential P/C-prefix. The human-readable display ordinal `P037` is
> **not** stored — it is derived at view time from the sort tuple
> `(containing_block, file-position)`. See §View-time ordinal
> derivation below.

### Field semantics

| Field | Required | Purpose |
|-------|----------|---------|
| `id` | ✅ | **UUID v7 string (v1.2+)**. Canonical 8-4-4-4-12 hex with version field `7` (e.g. `01910b9c-d4f0-7000-8000-0123456789ab`). Stable across renumber / insertion; cite references compare by UUID equality, not by sequential ordinal. Legacy v1.1 used `P001..PNNN` / `C001..CNNN` sequential strings; migration map at `manuscript/propositions/_migration/v1.1-to-v1.2-id-map.json` records the historical correspondence |
| `text` | ✅ | **Verbatim** sentence/clause — bijection ground truth(grep `.tex` confirm match) |
| `location` | ✅ | `main.tex:L<line>` — first line of sentence。**v1.6+** 文法擴為 `[<relpath>.tex:]L<a>[-L<b>]`:`<relpath>` 相對於主檔(`_meta.json` `source.file`)所在目錄,指向 `\input`/`\include` 樹內的檔案(如 `parts/part2-theory.tex:L123`);無前綴時語意不變 = 主檔本身。`schema_version < 1.6` 的 ledger 出現檔名前綴 → R13 FAIL 提示先升版(禁止 silent accept) |
| `containing_block` | ✅ | Label / section context — for grouping. **Canonical form: label-only** (`thm:<label>` / `lem:<label>` / `cor:<label>` / `sec:<label>`); typed-prefix form (`theorem:thm:<label>`) **deprecated** per #113 (2026-05-18 canonicalization). Validators (`scripts/audit-theorem-boundaries.py`, `scripts/validate-propositions.py`) normalize both forms for backward-compat with pre-2026-05-18 archive fixtures; new emissions MUST use label-only form |
| `claim_type` | ✅ | See taxonomy below |
| `asserts` | ✅ | 1+ atomic claims in machine-friendly form(plain text,no LaTeX). Connective / reference clauses may have empty asserts (clause-level mode only) |
| `mathematical_objects` | ⚠️ | Variables / functions / sets the prop refers to — for cross-prop lookup |
| `introduces` | ⚠️ | New objects defined here(definition / axiom) |
| `cites` | ⚠️ | List of prior props this prop depends on, addressed by **UUID v7** (v1.2+). v1.1 listed `P<NNN>` / `C<NNN>` strings — those are now resolved via the migration audit map |
| `cited_by_inferred` | ❌ | Auto-derived by validator(reverse `cites`)— **不**人工填 |
| `scope_qualifiers` | ⚠️ | For all / there exists / subject to — for inference |
| `evidence_class` | ⚠️ | Strength tracker |
| `retired` | ⚠️ | Present **only** when the prop's passage is no longer in the compiled paper — see [`retired` (v1.4+)](#retired-v14) |
| `notes` | ❌ | Free-form human note |

### `retired` (v1.4+)

A prop describes a passage of the manuscript. When an author disables that
passage rather than editing it, the prop is left behind: it still names a real
claim, but not one the paper makes any more. Deleting it would destroy the
audit trail, and leaving it unmarked makes the ledger silently over-claim.
`retired` is the third option — the prop stays, and says so.

```json
"retired": {
  "since": "2026-07-29",
  "mechanism": "comment_env",
  "match": "exact",
  "reason": "parked by Hsu's condensation",
  "ref": "PsychQuantHsu/psychophysical_representations#147"
}
```

| Key | Required | Meaning |
|-----|----------|---------|
| `since` | ✅ | `YYYY-MM-DD` the passage left the compiled paper |
| `mechanism` | ✅ | How it was disabled — enum below |
| `match` | ✅ | `exact` (prop text still string-matches the disabled source) or `by_reading` (located by reading, because the wording ALSO changed — a judgement, weaker evidence) |
| `reason` | ✅ | One line, human-readable |
| `ref` | ⚠️ | Issue / commit that retired it |
| `superseded_mechanism` (v1.5+) | ⚠️ | Present when a later edit changed the disabled text's status again (e.g. `comment_env` content later deleted outright → mechanism becomes `removed`); records the prior mechanism for the audit trail |

`mechanism` enum: `comment_env`(inside `\begin{comment}…\end{comment}` — R1 passes,normalize 不剝 comment 環境)/ `line_comment`(`%` 行註解 — R1 fails)/ `removed`(source 已刪 — R1 fails)。R1-visibility 不對稱是 validator artifact,正是 `retired` 記 mechanism 而非 boolean 的理由。

## Multi-file manuscripts (v1.6+)

主檔(`_meta.json` `source.file`)以 `\input{...}` / `\include{...}` 引入其他
`.tex` 檔時,validator 與 refresh 從主檔遞迴解析引入樹(自動補 `.tex` 副檔名、
跳過註解行內的巨集、深度上限 3、循環引入與缺檔 loud fail;`\subimport` /
`\subfile` 等非標準巨集不支援,遇到 warning 列出並跳過)。

**兩個座標系(刻意並存)**:

| 路徑 | 相對於 | 讀者 |
|------|--------|------|
| prop `location` 的 `<relpath>` | 主檔所在目錄 | 與 `\input{parts/part2-theory}` 的寫法直接對得上 |
| `_meta.json` `source.file` / `source.parts` | manuscript repo root | 不開 tex 也能定位稿件 |

`source.parts`(選填,字串陣列)是 validator / Operation D 每次跑時重新解析並
回寫的**非權威快照** — 權威永遠是 `\input` 樹的即時解析。location 檔名前綴指向
樹外檔案 → R13 FAIL(`file not in input tree`)。

### `claim_type` taxonomy

| Type | When | Example |
|------|------|---------|
| `axiom` | Definitional / structural starting point | "γ(1, s) = 1 and η(1, s) = s" (Iverson boundary) |
| `definition` | New term/object introduced | "Let S° := S \\ {0}." |
| `hypothesis` | Theorem / lemma 假設 | "Suppose ξ admits gain-control representation..." |
| `claim` | Derived assertion | "Then F = id_S follows from boundary condition." |
| `case_split` | One branch of case analysis — **structural leaf**, not cited as a semantic dependency (the case CONTENT in adjacent `display_equation` / `claim` is what carries semantic weight; see #112) | "Case A: ρ non-constant on S." |
| `display_equation` | Standalone equation without prose | (Rare in this paper) |
| `restatement` | Reformulation of an earlier prop | "Equivalently, u^*(y) = A σ_gc(y) + B on I." |
| `commentary` | Meta-text about the paper / motivation | "In what follows we focus on the gain-control side." |
| `example` | Concrete instance | "For instance, take u(y) = ln y." |
| `connective` (Phase 2 clause-level only) | Pure linguistic connector, no propositional content | "Hence," / "Therefore," / "In particular," |
| `reference` (Phase 2 clause-level only) | Pure cross-reference / citation | "(Section~\\ref{sec:setup})" / "\\citep{DobleHsu2020}" |
| `scope_qualifier` (Phase 2 clause-level only) | Subordinate scope/quantifier attaching to parent | "for every $s \\in S$" |

Phase 2 additions (`connective` / `reference` / `scope_qualifier`) are only
used when extraction runs in clause-level mode. Heterogeneous Phase 1 mode
absorbs these into the parent claim's text + asserts.

#### `case_split` is a STRUCTURAL LEAF — header only, never bundled (#112 / #121)

A `case_split` prop marks ONE branch of a case analysis. Its `text` MUST be
the case HEADER only — the case label plus its branch condition. The case
CONTENT (closed-form formulas, derived equalities) belongs in adjacent
`display_equation` props (pure formula) or `claim` props (formula + prose).
The header `case_split` prop carries no semantic weight of its own; it is the
cite anchor / structural glue. The content prop(s) `cites` the header.

This split keeps R3's `structural_leaf_types` exemption honest: the header is
legitimately leaf-like (no inbound cites expected), while the content prop is
the unit that carries the actual mathematical claim.

**RIGHT** — Theorem 1 (`thm:eta-s`) does this correctly. The case header and
its formula block are two separate props:

```jsonl
{"id":"...","text":"\\item \\textbf{Log-root.}","location":"main.tex:L499","containing_block":"thm:eta-s","claim_type":"case_split","asserts":["Case (A) Log-root branch: σ non-constant log-root form"],"cites":[]}
{"id":"...","text":"$u(y) = a\\, \\sqrt[q]{|(\\log y - d)/b|} + e$, ... $\\gamma(\\lambda, s) = \\lambda^{b|s+c_2|^q}$.","location":"main.tex:L501-L507","containing_block":"thm:eta-s","claim_type":"display_equation","asserts":["Case (A) closed-form: u, v, σ, ξ_s, γ"],"cites":["<header prop id>"]}
```

The `case_split` prop's `text` is just `\item \textbf{Log-root.}` — a header.
The formulas live in their own `display_equation` prop that cites the header.

**WRONG** — the old pre-#121 pattern for Theorems 2-4 bundled the case header
AND every closed-form formula into a single `case_split` prop:

```jsonl
{"id":"...","text":"\\item \\textbf{$\\sigma$-constant + log $u, v$.}\n$u = \\alpha\\ln y + a$, $v = \\beta\\ln x + b$, $\\sigma = \\sigma_0$,\n$\\xi_s = ...$, $\\eta = s - c(\\lambda)$, $g(\\lambda) = ...$.","location":"main.tex:L728-L734","claim_type":"case_split","asserts":["Case (A): σ-constant + log u,v; closed-form for u,v,σ,ξ_s,η,g"]}
```

This is wrong because the closed-form `display_equation` content is buried
inside a structural leaf. A `case_split` prop must never contain formulas — it
declares a branch, nothing more. #121 split all 13 such bundled props into
header `case_split` + content `display_equation`/`claim` pairs.

**Validator behaviour (#83)**: these 3 Phase 2 claim_types are members of
`structural_leaf_types` in `scripts/validate-propositions.py:check_dag()` —
a prop with `claim_type ∈ {connective, reference, scope_qualifier}` does
**not** trigger an R3 orphan warning when no other prop cites it (they ARE
the cite anchors / structural glue, not derived claims). Same exemption
applies to `axiom`, `definition`, `commentary`.

### `evidence_class` taxonomy

| Class | Meaning |
|-------|---------|
| `verified` | Proved within the paper (after derivation) |
| `derived` | Logical consequence of prior props |
| `hypothesized` | Assumed (theorem / lemma hypothesis) |
| `conventional` | Definitional choice (Section 1 conventions) |
| `open` | Future-work / unproved |

## Validator rules (machinable)

1. **iso-check**: tokenize `main.tex` into sentences (LaTeX-aware), and verify:
   - Every sentence has exactly 1 `prop` whose `text` matches verbatim
   - Every `prop`'s `text` appears as a sentence in `main.tex` at `location`
2. **cite-resolve** (v1.2+): every UUID v7 string in `cites` matches the `id` of some prop in the same JSONL file or, for cross-file refs from `_stage2/**/*.jsonl` into `main.jsonl`, in the Phase 1 baseline. v1.1 form `P<NNN>` / `C<NNN>` is no longer accepted by the validator
3. **DAG**: no cycles; orphan props (no `cited_by_inferred` and not in `structural_leaf_types = {axiom, definition, commentary, restatement, connective, reference, scope_qualifier, case_split}`) → warning. Phase 2 additions: `connective`/`reference`/`scope_qualifier` per #83; `restatement` per #92; `case_split` per #112 — see §claim_type taxonomy for per-type rationale.
4. **Mechanical contradiction**: paired axiom + hypothesis where boundary forces a value — flag if a downstream `case_split` violates it. Initially hard-coded for known patterns (e.g. Iverson boundary + `η=F(s)` hypothesis → F=id; case_split with non-identity F = violation).
   - **PATTERN-A** (#60 incident fingerprint, #72 generalized 2026-05-14, #80 round 1.5 hardened): boundary axiom `η(1,s)=s` + hypothesis `η(λ,s)=f(s)` + case_split "f may be any continuous map" → contradiction. Patterns are **regex** (whitespace-insensitive across `(`, `,`, `=`, etc.) supporting both ASCII (`eta`/`lambda`) and Greek (`η`/`λ`), with `\b` word boundary anchoring to prevent substring leak (e.g. `theta(1,s)=s` does NOT false-fire). **Known limitations** (deferred to Phase 2 / #77 clause-level SAT-style generalization):
     - Regex requires substring `eta(1,s)=s` / `f may be any` / `any continuous map` / `f-extended` shape in asserts — semantic rephrasings (`\eta|_{\lambda=1}=s`, `f is unconstrained`, `f arbitrary`) miss
     - LaTeX math-boundary variants — `\eta(\boldsymbol{1}, s) = s` (with `\boldsymbol{1}`), `\eta|_{\lambda=1}` (restriction notation), or pull-back forms — miss because the boundary pattern is literal `(1,...` not abstract "evaluate at λ=1"
     - Greek `η/λ` letters in math italic Unicode block (e.g. `𝜂` U+1D702 vs `η` U+03B7) miss — `\b` + ASCII codepoint comparison only
     - Coverage proof: smoke fixtures `_smoke_tests/rollback_60.{json,tex}` (synthetic, all 3 PATTERN-A trigger conditions in ASCII asserts) + `_smoke_tests/rollback_60_real.{json,tex,md}` (real pre-#60-fix wording from `manuscript@a11db6c^`). Whitespace variants (no-space `eta(1,s)=s`, extra-space `eta ( 1 , s ) = s`) verified via ad-hoc test in commit message of #80 round 1; committed fixture for boldsymbol/math-boundary variants explicitly **deferred to #77** since those require either SAT-style abstraction or clause-level granularity to detect reliably.
   - **PATTERN-B** (#68 Track A dichotomy): **RETIRED 2026-05-14 per #73 Path A**. Originally detected "Track A" without "Track B" counterpart. After #68 main.tex cleanup + #75 docs/ sync, no remaining Track A/B references in living docs → dead-code-on-arrival. Future docs/ drift (e.g. someone re-introducing Track A/B vocab) caught by docs grep at audit chain time, not validator.
   - **Regression guard**: `_smoke_tests/rollback_60.{json,tex}` (synthetic hand-crafted) + `_smoke_tests/rollback_60_real.{json,tex,md}` (real pre-#60-fix wording per #74) both trigger PATTERN-A. Adding a new mechanical pattern should ship with a synthetic smoke test fixture.
5. **Object-resolution**: every `mathematical_objects` symbol appears either in an earlier `introduces` (definition / axiom) or in earlier `mathematical_objects` (i.e. introduced through use) — orphan symbol = warning
6. **R9 env-consistency** (#100, 2026-05-18): for any prop whose `containing_block` (after type-prefix strip + sub-path normalization per #113) resolves to a known theorem-like env (`theorem` / `lemma` / `proposition` / `corollary` / `definition` / `remark` / `conjecture` declared via `\newtheorem` in `main.tex`), the prop's `location` line range MUST fall within the env's real `\begin{<env>}` … `\end{<env>}` line range. Mismatches emit `[WARN] R9` (informational baseline, exit 0). Non-theorem-like `containing_block` (`sec:*` / `discussion/*` / `abstract`) is silently skipped. Skipped entirely when `main.tex` contains no theorem-like envs. Props whose `location` cannot be parsed — a non-`main.tex` prefix, or an inverted / zero-base range — are skipped and surfaced (not silently bypassed) in a `[summary] R9` line reporting `checked` / `skipped_non_main_tex` / `skipped_malformed_loc` counts (#116).

### R9 policy: WARN-as-baseline (DP4)

R9 ships as **WARN-only** (does not fail the validator) to accommodate the 14 known main.jsonl drift props tracked in [#114](https://github.com/PsychQuantHsu/psychophysical_representations/issues/114) (Stage 1 pilot boundary drift, surfaced by #98 audit script). After #114 cleanup lands, a future PR can escalate R9 to ERROR (exit 1) via a `--strict-r9` flag or an unconditional bump. Until then:
- `_stage2/theorem1.jsonl` is the acceptance gate (0 R9 warnings expected; verified post-#97 cure)
- `main.jsonl` baseline reports 14 R9 warnings — these are the #114 cleanup targets

The R9 implementation inlines the LaTeX env parser from `scripts/audit-theorem-boundaries.py` (#98) per /idd-plan #100 DP1; #115 M-5 tracks the proper shared-module refactor.

7. **R10 claim-type-asserts** (#90, 2026-05-18): Phase 2 LLM mistag guard. For every prop whose `claim_type` is `connective` or `reference`, the `asserts` array MUST be empty (those types are pure structural glue per Stage 2 schema). `scope_qualifier` is intentionally **exempt** — those props typically carry 1 short assert documenting the scope (e.g. `"scope: for every s in S"`). Violations emit `[FAIL] R10` with exit code 1 (FAIL severity, no WARN-as-baseline policy — `main.jsonl` + `_stage2/theorem1.jsonl` baselines were clean at ship time, so any violation signals a real mistag to fix). R3's `structural_leaf_types` exemption from the orphan check is `claim_type`-keyed and runs orthogonally; R10 catches content-bearing props that would otherwise slip past R1 + R3 due to the mistag.

8. **R11 evidence-class-enum** (#119, 2026-05-18): schema enum-membership guard, symmetric to R10. Every prop's `evidence_class` MUST be a member of the canonical 5-element enum `verified | derived | hypothesized | conventional | open`. Violations emit `[FAIL] R11` with exit code 1 (FAIL severity, no WARN-as-baseline policy). Schema-gated v1.2+ (legacy v1.1 / missing `schema_version` emit `[SKIP] R11` for backward compat, same gate as R7). Before R11 the enum was defined in this file prose-only with no machine enforcement; the Phase 2 clause-level LLM extractor hallucinated out-of-enum values (`definitional`, `claim`) that slipped past R1-R10.

9. **R12 claim-type-enum** (#124, 2026-05-19): schema enum-membership guard, symmetric to R11. Every prop's `claim_type` MUST be a member of the canonical 12-element enum `axiom | definition | hypothesis | claim | case_split | display_equation | restatement | commentary | example | connective | reference | scope_qualifier`. Violations emit `[FAIL] R12` with exit code 1 (FAIL severity, no WARN-as-baseline policy). Schema-gated v1.2+ (legacy v1.1 / missing `schema_version` emit `[SKIP] R12` for backward compat, same gate as R7 + R11). Before R12 the enum was defined in this file prose-only; R3's `structural_leaf_types` exemption is `claim_type`-keyed (`p.get("claim_type", "claim")`), so a hallucinated value would silently misroute orphan detection. `main.jsonl` + `_stage2/theorem1.jsonl` baselines were 100% canonical at ship time across all 12 enum members — R12 ships as pure structural prevention against future extractor drift, no data sweep needed.

10. **R13 location line-anchoring** (#128/#139, backfilled to this canonical in add-manuscript-onboarding): single-line `location` must anchor the prop's normalized text at the declared line within `R13_START_TOLERANCE = 2` lines (span bound `R13_MAX_SPAN = 30`); un-anchorable props surface as informational, never guessed (windowed locator with degeneracy guard — loud `anchor_failed` over silent mis-write). **v1.6**: R13 is file-aware — a file-prefixed location anchors within the named file of the resolved input tree; prefix naming a file outside the tree → FAIL `file not in input tree`; prefix present but `schema_version < 1.6` → FAIL with upgrade hint. (Pre-v1.6 behavior — skip-with-count for non-main-tex prefixes per #116 — is retained only for ledgers below v1.6 without prefixes.)

## View-time ordinal derivation (v1.2+)

The schema stores **only** the UUID v7 in `id`. Human-readable ordinals like
`P037` and `C014` are derived at view time and are not persisted to disk.

### Algorithm

Given a JSONL file path and its props:

1. Sort the props by the tuple `(containing_block, file-position)`, where
   file-position is the prop's 0-based line index in the JSONL file. The JSONL
   is maintained in source-reading order, so file-position is an equivalent
   total order. Use ascending lexicographic comparison on the tuple components.
2. Assign 1-based positional ordinals to props in the sort order. The first prop
   in sort order has ordinal `1`; the second has ordinal `2`; and so on.
3. Pick the display prefix from the file path:
   - Files matching the glob `manuscript/propositions/_stage2/**` → prefix `C`
     (clause-level Phase 2 scope).
   - Any other file → prefix `P` (Phase 1 baseline scope).
4. Format display string as `<prefix><ordinal>` with the ordinal zero-padded to
   at least 3 digits. So the 37th prop in sort order in `main.jsonl` displays
   as `P037`; the 14th prop in `_stage2/theorem1.jsonl` displays as `C014`.

### Worked example

Consider a JSONL file `main.jsonl` with three props (excerpt, irrelevant fields
omitted):

| File line | UUID | containing_block |
|-----------|------|------------------|
| 0 | `01910b9c-d4f0-7042-8000-...` | sec:setup |
| 1 | `01910b9c-d4f0-7001-8000-...` | sec:setup |
| 2 | `01910b9c-d4f0-7099-8000-...` | sec:setup |

Sort by `(containing_block, file-position)` ascending — all three share the
same `containing_block`, so file order is preserved:

| Position | UUID | sort tuple |
|----------|------|------------|
| 1 | `01910b9c-d4f0-7042-8000-...` | (sec:setup, 0) |
| 2 | `01910b9c-d4f0-7001-8000-...` | (sec:setup, 1) |
| 3 | `01910b9c-d4f0-7099-8000-...` | (sec:setup, 2) |

So the prop with `id=01910b9c-d4f0-7042-8000-...` displays as `P001`, the prop
with `id=01910b9c-d4f0-7001-8000-...` displays as `P002`, and the prop with
`id=01910b9c-d4f0-7099-8000-...` displays as `P003`. The numeric value embedded
in the UUID hex is **not** significant — only the sort tuple determines display
order.

### Validator CLI helper

```bash
# Print full mapping (one "<display> <uuid>" line per prop, in sort order):
python3 scripts/validate-propositions.py view-ordinal \
  manuscript/propositions/main.jsonl

# Look up the display string for a specific UUID:
python3 scripts/validate-propositions.py view-ordinal \
  manuscript/propositions/main.jsonl \
  --uuid 01910b9c-d4f0-7037-8000-...
```

Validator diagnostic output also threads display ordinals through unresolved
cite findings:

```
P042 cites missing UUID 01910b9c-d4f0-7099-8000-0123456789ab
```

so audit reports remain human-readable.

### v1.1 → v1.2 migration map

The one-shot migration that produced v1.2 from the v1.1 sequential ids writes
its audit map to `manuscript/propositions/_migration/v1.1-to-v1.2-id-map.json`.
Schema:

```json
{
  "main.jsonl": { "P001": "01910b9c-d4f0-7000-...", "P002": "...", ... },
  "theorem1.jsonl": { "C001": "...", ... }
}
```

The map is the canonical record for any future reader who needs to chase
pre-migration P-prefix labels (e.g. references in frozen retrospectives such as
`_pilot/ROI-evaluation.md`). The migration is deterministic — re-running the
migration on the same source inputs produces identical UUIDs.

## Build / curate workflow

```bash
# Initial extraction (one-time per section)
# 1. Read .tex section (e.g., §Setup L83-262 + Lemma A L268-330)
# 2. Tokenize into candidate clauses (Phase 2) or sentences (Phase 1)
# 3. For each clause, produce a draft proposition (claim_type, asserts, cites)
# 4. Human curate — fix claim_type, cites; bypass for trivial commentary
# 5. Append to manuscript/propositions/main.jsonl (one prop per line)

# Validate (on every .tex change)
python3 scripts/validate-propositions.py \
  --jsonl manuscript/propositions/main.jsonl \
  --meta manuscript/propositions/_meta.json \
  --tex manuscript/main.tex

# Or simply (uses defaults):
python3 scripts/validate-propositions.py --tex manuscript/main.tex

# Migration helper (one-shot JSON → JSONL):
python3 scripts/migrate-json-to-jsonl.py <input.json> [--delete-input]
```

## 失效情境 + recovery (Phase 1 prop-subset-check)

> Phase 1 validator 做的是 **propositions ⊆ tex via substring proxy**(見上方 §Phase 1 → Phase 2 transition status)。下表描述目前 R1 / R1.5 真實能 catch 的失效模式。Phase 2 (#77 closed 2026-05-16) clause-level re-extract via #96 之後,完整 sentence-level / clause-level bijection 才會被 mechanically 偵測。

| 失效模式 | Phase 1 能 catch 嗎? | Recovery |
|---------|---------------------|----------|
| JSON 改了某 prop `text` 但對應 `.tex` 不再含該字串 | ✅ R1 報「`text` not found in .tex (location=…)」 | Author 確認哪邊正確;`.tex` 是 source of truth → 改回 prop 或更新 `.tex` |
| `.tex` 刪某段但 JSON 留 prop 指向該段 | ✅ R1 (normalize 後 substring miss) | Author 刪 prop + 注意 `cites: [P037]` 的 down-stream props |
| `.tex` 整個 top-level section 沒被任何 prop 覆蓋 | ✅ R1.5 報「no prop covers section (Lstart-end): title」(warning,不 fail exit) | Author 為該 section 加 ≥1 prop |
| `.tex` 加 1 句新 claim 在已 covered 的 section 內(prop 未更新)| ❌ Phase 1 miss (因 R1.5 只看 section-level coverage, R1 只看 prop⊆tex 不看 tex⊆∪props 的 sentence-level)| 等 Phase 2 clause-level surjective scan,或 author 自己人工 audit 該 section |
| 兩 props `text` 都 substring-match 同 `.tex` 段(injectivity 違反)| ❌ Phase 1 miss (R1 substring match 不 enforce injective)| 等 Phase 2 — clause-level granularity 後 substring match 等價 verbatim,injective 自動成立 |
| Connective / reference / transition 沒被 prop 標 `claim_type` | ❌ Phase 1 miss (extraction 階段未 commit 到 clause-level) | 等 Phase 2 — clause-level extraction 會強制標 |

## Out of scope (Phase 1)

- Real-time IDE integration(自動同步 .tex ↔ JSON)— future feature
- Full theorem proof formalization(那是 Lean 等級的工程)
- Auto-correcting JSON when `.tex` changes(目前是 detect + manual fix)
- Cross-paper proposition graph(假設只一篇 paper)

## See also

- AI4o `Proposition.swift` — prior-art schema (memory-system equivalent)
- MP091 LFRL — prescriptive sibling DSL
- Spinoza's *Ethics* — geometric method inspiration
- Locke's *Essay Concerning Human Understanding* — atomistic philosophy reference
