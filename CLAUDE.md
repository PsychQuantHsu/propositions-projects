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
| `/propositions:analyze` | 整篇文章的入口:從檔案判斷做到哪一步,呼叫下面的 skill 跑下一個還沒完成的步驟,最後報告(不存進度檔,重跑就接續)。預設做到讀出句子之間的關係;`proofread`、`manuscript-audit`、`clarity-audit` 要明確要求才跑。本身不寫任何檔案,寫入都在被呼叫的 skill 裡確認;不取代下面任何一個 skill(#40) |
| `/propositions:propositions` | 機械軸,四個 operation 共一個 skill:**A** 跑 R1-R13 validator 確認 jsonl ↔ tex bijection(v1.6 起 file-aware,支援 multi-file `\input` 樹)、**B** windowed locator 修 `prop.location` 行號漂移(dry-run gated)、**C** 指向 `/propositions:extract`、**D** onboard 無 ledger 的新稿(scaffold 釘版 SCHEMA/EXTRACTION-PROMPT + `_meta.json` + 空的 `main.jsonl`,dry-run gated) |
| `/propositions:extract` | 拆解軸,段落／區段／定理 → propositions:LLM 用暫時 id 寫到帳冊外暫存,`assign-prop-ids.py` 換 UUID v7,`check-extraction-coverage.py` 確認範圍內沒有漏掉的文字(只有列舉的排版指令不算文字,全由控制字組成的公式算),對合併後的副本跑 validator,確認 diff 才寫入帳冊;依帳冊 profile 載入數學或實證的 reference |
| `/propositions:proofread` | 語意軸,per-prop L1-L5 walk:分解是否忠實、claim_type 是否合身、cite 是否完整且成立、evidence_class 是否一致 |
| `/propositions:manuscript-audit` | 跨檔案軸,cross-artifact drift audit (R1 symbols / R2 citations / R3 code-manuscript / R4 prop-iso) |
| `/propositions:construct` | 建構軸,整篇文章的層次:標註承諾(研究問題、目的、假設、章節計畫、近距離承諾)、章節角色與三層依存樹(句在段內的頭、段在節內的頭、節的 parent),存成帳冊旁的 `structure.json`／`discourse.jsonl`(格式 2.0,S1–S9 檢查);寫到一半的稿件則依右邊緣與未兌現的承諾提出下一句的候選,每個候選寫出預期的 `move`,並參考連結清單的走法(提示不是規則,不改候選順序,#36);也能解釋一段裡句子之間的關係(`structure-explain.py`,#33)(#26、#30) |
| `/propositions:construct-batch` | 長稿的建構軸標註:先把帳冊排成閱讀順序(`reorder-ledger.py`,dry-run gated),再依段落切批、分給 subagent、合併回暫存附檔(`structure-batch.py`;依存樹已有時用 `--moves-only` 只標 `move`、`type`);審查與寫入仍回 `/propositions:construct` |
| `/propositions:clarity-audit` | 可讀性軸,散文層級的 stumble 掃描與改寫(不需要 JSONL) |

| Rule (shipped) | When applies |
|----------------|--------------|
| `plugins/propositions/rules/manuscript-jsonl-sync.md` | PR-time prevention: 改一邊 main.tex 該同步 jsonl |
| `plugins/propositions/rules/manuscript-consistency-audit.md` | Audit-time detection SOP + 觸發時機 |
| `plugins/propositions/rules/code-and-manuscript-sync.md` | Per-PR hook/CI discipline，manuscript-audit 的姊妹規則 |

| Doc (shipped) | What |
|---------------|------|
| `plugins/propositions/docs/EXTRACTION-PROMPT.md` | LLM extraction discipline (餵給 Claude / GPT 抽 prop 用) |
| `plugins/propositions/scripts/validate-structure.py`、`structure-state.py`、`structure-metrics.py`、`derive-paragraphs.py`、`migrate-structure-v2.py` + `docs/STRUCTURE.md` | 文章結構 sidecar（`structure.json`、`discourse.jsonl`，格式 2.0）：不改帳冊 schema，S1–S9 檢查承諾先開後兌現、完整文章不欠帳、章節與段落計畫、每段是一棵依存樹（交叉弧與帳冊沒 cite 的 `basis` 只警告）；狀態查詢列出右邊緣、等頭的子句與依緊迫程度（`--order kind|scope`）排序的未兌現承諾；量測報告樹合不合用；1.0 附檔經遷移工具轉換（#26、#30） |
| `plugins/propositions/catalog/vocabulary.yaml`、`plugins/propositions/scripts/structure-explain.py`、`build-link-catalog.py`、`structure-links.py` | 每一句「在做什麼」的封閉詞彙（手寫，帶 `move`／`type` 的附檔由 S9 檢查，需要 PyYAML）；讀法工具把一段讀成「第幾句、在做什麼、掛在第幾句、什麼關係」；`catalog/links.csv` 由工具從附檔產生：六種連結（下一句、頭、`also`、引用、承諾兌現、段落頭）一種一列，只含次數，是觀察到的走法不是規則，可以有環；`structure-links.py` 列出一句的所有連結，以及某個步驟看過與沒看過的走法（沒看過的由詞彙算出，不儲存）；`structure-batch.py --moves-only` 只標步驟不動依存樹，`structure-metrics.py --compare-moves` 報告兩份標註的 Cohen's κ（#33）|
| `plugins/propositions/scripts/validate-verification.py`、`proofread-to-verification.py` + `docs/VERIFICATION.md` | 驗證紀錄 sidecar（`verification.jsonl`）：帳冊只當索引，proofread／Lean／CAS 等方法的判定記在旁邊；轉換只認完整 proposition id（#12） |
| `plugins/propositions/catalog/obligations.yaml` + `docs/OBLIGATIONS.md` | 義務表：一列一條，寫明帳冊與附檔要對什麼（前提）、文章欠讀者什麼（義務，依原則分七組），以及驗證它的檢查；還沒有檢查的標成缺口並指到 issue。說明文件定義每一列對一個單位（一筆命題或整篇文章）的四種結果，以及「完全合理」＝每一列都是通過或不適用。現在沒有工具讀這張表，由 `tests/test_plugin_payload_tracked.py` 的 `test_obligations_` 案例守住格式與完整性（#47） |

同一個 marketplace 另有第二個 plugin `plugins/tschema-check/`（#4）：文件對外部來源的忠實度查核，validator 自帶、不 import 本 plugin（安裝後 plugin 彼此隔離）。

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
│  scripts/_lib/normalize.py          (R1 + coverage steps) │
│  scripts/assign-prop-ids.py         (tmp id → UUID v7)    │
│  scripts/check-extraction-coverage.py (no-omission gate)  │
│  scripts/validate-structure.py      (S1-S9 sidecars)      │
│  scripts/structure-state.py         (what is still owed)  │
│  scripts/structure-explain.py       (how sentences relate)│
│  scripts/structure-links.py         (every link, catalog) │
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
# 整篇一次跑 — 判斷做到哪一步、呼叫下面的 skill、最後報告(遇到寫入就停下問)
/propositions:analyze

# 0. 新稿第一次採用 — Operation D scaffold ledger(會問 profile;之後 /propositions:extract 抽取)
# 1. 拆解軸 — 段落／區段 → propositions(暫存 + 覆蓋檢查 + validator,確認後寫入)
/propositions:extract

# 1b. 機械軸 — Operation A 驗 bijection、B 修 location 漂移
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
| R11 | `evidence_class` ∈ 帳冊 profile 的詞彙(default 5 值;empirical 再加 5 值,v1.7+)(v1.2+) | LLM hallucinated value |
| R12 | `claim_type` ∈ 帳冊 profile 的詞彙(default 12 值;empirical 再加 result / interpretation,v1.7+)(v1.2+) | LLM hallucinated value |
| R13 | single-line `location` anchors to actual start | location field drift |

## Originally developed as

The "Locke project" for `PsychQuantHsu/psychophysical_representations` — a manuscript on psychophysical representation theory. The project name references John Locke's epistemological "clarity of ideas" discipline (every declarative claim must be authoritatively addressable). Packaged here as a plugin so other LaTeX-heavy manuscript projects can adopt the same prop-iso infrastructure without copying scripts repo-by-repo.

The umbrella narrative doc (philosophy + lifecycle + concrete state of the source project) lives at `docs/locke-project.md` in `PsychQuantHsu/psychophysical_representations`, not in this plugin.

## Compatibility

- Python 3.10+ (uses 3.10+ type hints + `match` statements in some scripts)
- pytest 7+ for test suite
- LaTeX manuscript with `manuscript/main.tex` + `manuscript/propositions/main.jsonl` convention(可自訂 path via skill args)
- Schema versions: v1.0 – v1.7 — validator handles all with backward-compat skip for v1.2+-only rules (R7 / R11 / R12)；v1.4 = `retired`、v1.5 = `retired.superseded_mechanism`、v1.6 = multi-file（file-qualified location + `source.parts`）、v1.7 = `_meta.json` `profile`（`default` / `empirical`，決定 R11／R12 詞彙）。完整版本史見 `docs/SCHEMA.md` §Versioning

## Hard rules for contributors

- **不修 user 的 main.jsonl 不問**:任何會 write jsonl 的 skill (e.g., refresh-locations) 必須先 dry-run + AskUserQuestion 確認再寫
- **Loud failure over silent fix**:寧可 anchor_failed 不要亂猜 line number
- **Schema 升級走 spec 流程**:不要 ad-hoc 加 enum 值;先改 `docs/SCHEMA.md` 確定新 canonical set,再更 validator + tests
- **Test 覆蓋每條 rule**:R1-R13 各自有獨立 fixture;改 normalize_for_match 等 shared helper 必跑全 R-rule test suite
- **新程式一律寫 Swift**:工具的目標是像 Akashic-Library 一樣完全用 Swift;既有 Python 只修不長,要加功能先移植那個模組。哪裡放什麼、例外與既有檔清單見 [`.claude/rules/swift-is-the-implementation-language.md`](.claude/rules/swift-is-the-implementation-language.md)

## Test suite

```bash
pytest tests/  # 期待 428+ passed
```

`tests/` 含 each rule 的 fixture + edge cases。Smoke tests live in the user's manuscript repo under `propositions/_smoke_tests/`(per-paper),不在 plugin。
