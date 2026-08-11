<!-- SPECTRA:START v1.0.2 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `openspec/specs/`, change proposals in `openspec/changes/`.

## Use `/spectra-*` skills when:

- A discussion needs structure before coding → `/spectra-discuss`
- User wants to plan, propose, or design a change → `/spectra-propose`
- Tasks are ready to implement → `/spectra-apply`
- There's an in-progress change to continue → `/spectra-ingest`
- User asks about specs or how something works → `/spectra-ask`
- Implementation is done → `/spectra-archive`
- Commit only files related to a specific change → `/spectra-commit`

## Workflow

discuss? → propose → apply ⇄ ingest → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `openspec/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra-apply` and `/spectra-ingest` skills handle parked changes automatically.

<!-- SPECTRA:END -->

# propositions plugin — author-claim infrastructure for academic LaTeX manuscripts

> 「**確認你在說什麼**」— 把 `main.tex` 每一個 declarative claim 提煉成 author cognitive atom,存進 line-addressable JSONL,配 mechanical validator 確保 manuscript 與 jsonl 之間的雙向對應永遠 falsifiable。

## What this plugin provides

| Skill | What |
|-------|------|
| `/propositions:propositions` | 機械軸,四個 operation 共一個 skill:**A** 跑 R1-R13 validator 確認 jsonl ↔ tex bijection(v1.6 起 file-aware,支援 multi-file `\input` 樹)、**B** windowed locator 修 `prop.location` 行號漂移(dry-run gated)、**C** 抽取新的 / 重抽 JSONL、**D** onboard 無 ledger 的新稿(scaffold 釘版 SCHEMA/EXTRACTION-PROMPT + `_meta.json`,dry-run gated) |
| `/propositions:proofread` | 語意軸,per-prop L1-L5 walk:分解是否忠實、claim_type 是否合身、cite 是否完整且成立、evidence_class 是否一致 |
| `/propositions:manuscript-audit` | 跨檔案軸,cross-artifact drift audit (R1 symbols / R2 citations / R3 code-manuscript / R4 prop-iso) |
| `/propositions:clarity-audit` | 可讀性軸,散文層級的 stumble 掃描與改寫(不需要 JSONL) |

| Rule (shipped) | When applies |
|----------------|--------------|
| `plugins/propositions/rules/manuscript-jsonl-sync.md` | PR-time prevention: 改一邊 main.tex 該同步 jsonl |
| `plugins/propositions/rules/manuscript-consistency-audit.md` | Audit-time detection SOP + 觸發時機 |
| `plugins/propositions/rules/code-and-manuscript-sync.md` | Per-PR hook/CI discipline，manuscript-audit 的姊妹規則 |

| Doc (shipped) | What |
|---------------|------|
| `plugins/propositions/docs/EXTRACTION-PROMPT.md` | LLM extraction discipline (餵給 Claude / GPT 抽 prop 用) |

`docs/SCHEMA.md`(repo 根層)是 canonical schema contract,但**刻意不 vendor 進 plugin**——
每個 manuscript 的 ledger 自帶一份釘住自己 schema 版本的副本,spec 跟著資料走。plugin 內
任何檔案都不應該宣稱有 vendored SCHEMA.md。

## Architecture (three layers)

```
┌─ Layer 3: Discipline ─────────────────────────────────────┐
│  rules/manuscript-jsonl-sync.md       (per-commit)        │
│  rules/manuscript-consistency-audit.md (audit-time SOP)   │
│  rules/code-and-manuscript-sync.md    (per-PR hook/CI)    │
│  (all three under plugins/propositions/ — they ship)      │
└───────────────────────────────────────────────────────────┘
                      ↑ enforces
┌─ Layer 2: Validator + Tooling ────────────────────────────┐
│  scripts/validate-propositions.py   (R1-R13 gates)        │
│  scripts/refresh-prop-locations.py  (location refresh)    │
│  scripts/audit-theorem-boundaries.py (LaTeX env CI gate)  │
│  scripts/audit-{citations,symbols,code-manuscript}.py     │
│  scripts/run-audit.sh               (orchestrator)        │
│  scripts/migrate-*.py               (historical tools)    │
│  scripts/_lib/latex_env_parser.py   (shared parser)       │
└───────────────────────────────────────────────────────────┘
                      ↑ verifies
┌─ Layer 1: Data Artifacts (user's manuscript repo) ────────┐
│  manuscript/propositions/main.jsonl     (per-paper)       │
│  manuscript/propositions/_meta.json     (per-paper)       │
│  manuscript/main.tex                    (per-paper)       │
└───────────────────────────────────────────────────────────┘
```

Layer 1 lives in the **user's manuscript repo** (data, paper-specific).
Layers 2 + 3 are this plugin (reusable across any prop-iso manuscript).

## Quick start (in a user's manuscript repo)

```bash
# 0. 新稿第一次採用 — Operation D scaffold ledger(之後 C 抽取、A 驗證)
# 1. 機械軸 — Operation A 驗 bijection、B 修 location 漂移、C 抽取 JSONL
/propositions:propositions

# 2. 語意軸 — per-prop L1-L5 walk(claim 是否為真、是否被 cite 蘊涵)
/propositions:proofread

# 3. 跨檔案軸 — 送出前跑完整 cross-artifact drift audit
/propositions:manuscript-audit

# 4. 可讀性軸 — 散文層級 stumble 掃描(不需要 JSONL)
/propositions:clarity-audit
```

四個命令都會從 working tree 自動偵測 `manuscript/propositions/main.jsonl` + `manuscript/main.tex`(clarity-audit 只需要 tex)。layout 不同時傳明確路徑。

## Validator rules (R1-R13)

See `docs/SCHEMA.md` for the full contract. Summary:

| Rule | Invariant | Failure mode |
|------|-----------|--------------|
| R1 | `prop.text` ⊆ `main.tex` (normalize-aware) | Silent drift between jsonl and tex |
| R1.5 | each `\section{}` has ≥1 prop | Coverage gap (informational) |
| R2 | every `cites` UUID resolves | Dangling reference |
| R3 | no cite cycles + orphan detection | Circular reasoning / isolated claim |
| R4 | mechanical-contradiction patterns | Two props contradict |
| R7 | UUID v7 ID format (schema v1.2+) | Stable identity broken |
| R8 | unique IDs | Duplicate prop |
| R9 | `containing_block` ⊆ env line range（env 清單由稿件自己的 `\newtheorem` 宣告解析,非硬編碼;無宣告時 fallback 預設集）| Theorem boundary misjudged |
| R10 | `connective`/`reference` empty `asserts` | LLM claim_type mistag |
| R11 | `evidence_class` ∈ canonical 5-enum (v1.2+) | LLM hallucinated value |
| R12 | `claim_type` ∈ canonical 12-enum (v1.2+) | LLM hallucinated value |
| R13 | single-line `location` anchors to actual start | location field drift |

## Originally developed as

The "Locke project" for `PsychQuantHsu/psychophysical_representations` — a manuscript on psychophysical representation theory. The project name references John Locke's epistemological "clarity of ideas" discipline (every declarative claim must be authoritatively addressable). Packaged here as a plugin so other LaTeX-heavy manuscript projects can adopt the same prop-iso infrastructure without copying scripts repo-by-repo.

The umbrella narrative doc (philosophy + lifecycle + concrete state of the source project) lives at `docs/locke-project.md` in `PsychQuantHsu/psychophysical_representations`, not in this plugin.

## Compatibility

- Python 3.10+ (uses 3.10+ type hints + `match` statements in some scripts)
- pytest 7+ for test suite
- LaTeX manuscript with `manuscript/main.tex` + `manuscript/propositions/main.jsonl` convention(可自訂 path via skill args)
- Schema versions: v1.0 – v1.6 — validator handles all with backward-compat skip for v1.2+-only rules (R7 / R11 / R12)；v1.4 = `retired`、v1.5 = `retired.superseded_mechanism`、v1.6 = multi-file（file-qualified location + `source.parts`）。完整版本史見 `docs/SCHEMA.md` §Versioning

## Hard rules for contributors

- **不修 user 的 main.jsonl 不問**:任何會 write jsonl 的 skill (e.g., refresh-locations) 必須先 dry-run + AskUserQuestion 確認再寫
- **Loud failure over silent fix**:寧可 anchor_failed 不要亂猜 line number
- **Schema 升級走 spec 流程**:不要 ad-hoc 加 enum 值;先改 `docs/SCHEMA.md` 確定新 canonical set,再更 validator + tests
- **Test 覆蓋每條 rule**:R1-R13 各自有獨立 fixture;改 normalize_for_match 等 shared helper 必跑全 R-rule test suite

## Test suite

```bash
pytest tests/  # 期待 142+ passed
```

`tests/` 含 each rule 的 fixture + edge cases。Smoke tests live in the user's manuscript repo under `propositions/_smoke_tests/`(per-paper),不在 plugin。
