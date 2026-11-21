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
| `/propositions:prop-analyze` | 整篇文章的入口:從檔案判斷做到哪一步,呼叫下面的 skill 跑下一個還沒完成的步驟,最後報告(不存進度檔,重跑就接續)。預設做到讀出句子之間的關係;`proofread`、`manuscript-audit`、`clarity-audit` 要明確要求才跑。本身不寫任何檔案,寫入都在被呼叫的 skill 裡確認;不取代下面任何一個 skill(#40) |
| `/propositions:prop-ledger` | 機械軸,四個 operation 共一個 skill:**A** 跑 R1-R13 validator 確認 jsonl ↔ tex bijection(v1.6 起 file-aware,支援 multi-file `\input` 樹)、**B** windowed locator 修 `prop.location` 行號漂移(dry-run gated)、**C** 指向 `/propositions:prop-extract`、**D** onboard 無 ledger 的新稿(scaffold 釘版 SCHEMA/EXTRACTION-PROMPT + `_meta.json` + 空的 `main.jsonl`,dry-run gated) |
| `/propositions:prop-extract` | 拆解軸,段落／區段／定理 → propositions:LLM 用暫時 id 寫到帳冊外暫存,`assign-prop-ids.py` 換 UUID v7,`check-extraction-coverage.py` 確認範圍內沒有漏掉的文字(只有列舉的排版指令不算文字,全由控制字組成的公式算),對合併後的副本跑 validator,確認 diff 才寫入帳冊;依帳冊 profile 載入數學或實證的 reference |
| `/propositions:prop-proofread` | 語意軸,per-prop L1-L5 walk:分解是否忠實、claim_type 是否合身、cite 是否完整且成立、evidence_class 是否一致 |
| `/propositions:prop-manuscript-audit` | 跨檔案軸,cross-artifact drift audit (R1 symbols / R2 citations / R3 code-manuscript / R4 prop-iso) |
| `/propositions:prop-construct` | 建構軸,整篇文章的層次:標註承諾(研究問題、目的、假設、章節計畫、近距離承諾)、章節角色與三層依存樹(句在段內的頭、段在節內的頭、節的 parent),存成帳冊旁的 `structure.json`／`discourse.jsonl`(格式 2.0,S1–S9 檢查);寫到一半的稿件則依右邊緣與未兌現的承諾提出下一句的候選,每個候選寫出預期的 `move`,並參考連結清單的走法(提示不是規則,不改候選順序,#36);也能解釋一段裡句子之間的關係(`structure-explain.py`,#33);寫入模式在作者確認一次之後,把下一段連同它的命題與附檔紀錄寫進稿件(`propositions write`,佔位寫成 `{PENDING: …}`,#49);也能照通過確認的綱要一筆一筆寫,寫完由只有 Read 工具的 agent `propositions:outline-point-reader` 比對段落有沒有說到每一句要點,對應記在綱要目錄的 `outline-trace.jsonl`(#51);重組模式照改過、整份通過確認的綱要重寫寫完的稿件,帳冊經改版重抽跟上、附檔重建、確認一次後寫入(`write prepare --rewrite`,#115)(#26、#30) |
| `/propositions:prop-construct-batch` | 長稿的建構軸標註:先把帳冊排成閱讀順序(`propositions ledger-order`,dry-run gated),再依段落切批、分給 subagent、合併回暫存附檔(`structure-batch.py`;依存樹已有時用 `--moves-only` 只標 `move`、`type`);審查與寫入仍回 `/propositions:prop-construct` |
| `/propositions:prop-clarity-audit` | 可讀性軸,散文層級的 stumble 掃描與改寫(不需要 JSONL) |
| `/propositions:prop-outline` | 綱要軸,動筆之前的計畫:文章層每節一句、段落層每段至少一句要點,存成帳冊旁的 `outline-sections.jsonl`、`outline-paragraphs.jsonl`,作者的確認存成 `outline-approvals.jsonl`。六個動作:從寫完的稿反推、從題目起草、依作者指示修改(合併與刪除都不丟來源)、前提檢查(五類由只有 Read 工具的 agent `propositions:outline-checker` 判斷,定義在 `plugins/propositions/agents/outline-checker.md`)、記錄作者當次明說的確認、回報哪些節仍照通過時的內容。只寫這三個檔,不寫稿件與帳冊;不需要先有帳冊(#75) |

| Rule (shipped) | When applies |
|----------------|--------------|
| `plugins/propositions/rules/manuscript-jsonl-sync.md` | PR-time prevention: 改一邊 main.tex 該同步 jsonl |
| `plugins/propositions/rules/manuscript-consistency-audit.md` | Audit-time detection SOP + 觸發時機 |
| `plugins/propositions/rules/code-and-manuscript-sync.md` | Per-PR hook/CI discipline，manuscript-audit 的姊妹規則 |

| Doc (shipped) | What |
|---------------|------|
| `plugins/propositions/docs/EXTRACTION-PROMPT.md` | LLM extraction discipline (餵給 Claude / GPT 抽 prop 用) |
| `plugins/propositions/scripts/validate-structure.py`、`structure-state.py`、`structure-metrics.py`、`propositions paragraphs`、`migrate-structure-v2.py` + `docs/STRUCTURE.md` | 文章結構 sidecar（`structure.json`、`discourse.jsonl`，格式 2.0）：不改帳冊 schema，S1–S9 檢查承諾先開後兌現、完整文章不欠帳、章節與段落計畫、每段是一棵依存樹（交叉弧與帳冊沒 cite 的 `basis` 只警告）；狀態查詢列出右邊緣、等頭的子句與依緊迫程度（`--order kind|scope`）排序的未兌現承諾；量測報告樹合不合用；1.0 附檔經遷移工具轉換（#26、#30） |
| `plugins/propositions/catalog/vocabulary.yaml`、`plugins/propositions/scripts/structure-explain.py`、`build-link-catalog.py`、`structure-links.py` | 每一句「在做什麼」的封閉詞彙（手寫，帶 `move`／`type` 的附檔由 S9 檢查，需要 PyYAML）；讀法工具把一段讀成「第幾句、在做什麼、掛在第幾句、什麼關係」；`catalog/links.csv` 由工具從附檔產生：六種連結（下一句、頭、`also`、引用、承諾兌現、段落頭）一種一列，只含次數，是觀察到的走法不是規則，可以有環；`structure-links.py` 列出一句的所有連結，以及某個步驟看過與沒看過的走法（沒看過的由詞彙算出，不儲存）；`structure-batch.py --moves-only` 只標步驟不動依存樹，`structure-metrics.py --compare-moves` 報告兩份標註的 Cohen's κ（#33）|
| `plugins/propositions/scripts/validate-verification.py`、`proofread-to-verification.py` + `docs/VERIFICATION.md` | 驗證紀錄 sidecar（`verification.jsonl`）：帳冊只當索引，proofread／Lean／CAS 等方法的判定記在旁邊；轉換只認完整 proposition id（#12） |
| `plugins/propositions/catalog/obligations.yaml` + `docs/OBLIGATIONS.md` | 義務表：一列一條，寫明帳冊與附檔要對什麼（前提）、文章欠讀者什麼（義務，依原則分七組），以及驗證它的檢查；還沒有檢查的標成缺口並指到 issue。說明文件定義每一列對一個單位（一筆命題或整篇文章）的四種結果，以及「完全合理」＝每一列都是通過或不適用。現在沒有工具讀這張表，由 `tests/test_plugin_payload_tracked.py` 的 `test_obligations_` 案例守住格式與完整性（#47） |
| `plugins/propositions/docs/OUTLINE.md` | 綱要的三個檔：每一個鍵、來源指標（label 或開頭文字）、確認紀錄，以及「一節仍照通過時的內容」的判定。現在沒有驗證器（#78，等 #46），只有 skill 寫入後自己跑的幾項檢查；照綱要把文字寫進稿件是 #51（#75） |

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
Layer 2 另有一部分不在 plugin 裡：repo 根目錄的 Swift package（`Sources/PropositionsKit`：引用方向檢查，以及綱要三個檔的格式、狀態與來源指標檢查），不隨 plugin 出貨，見下方 Compatibility。
Layers 2 + 3 are this plugin (reusable across any prop-iso manuscript).

## Quick start (in a user's manuscript repo)

```bash
# 整篇一次跑 — 判斷做到哪一步、呼叫下面的 skill、最後報告(遇到寫入就停下問)
/propositions:prop-analyze

# 0. 新稿第一次採用 — Operation D scaffold ledger(會問 profile;之後 /propositions:prop-extract 抽取)
# 1. 拆解軸 — 段落／區段 → propositions(暫存 + 覆蓋檢查 + validator,確認後寫入)
/propositions:prop-extract

# 1b. 機械軸 — Operation A 驗 bijection、B 修 location 漂移
/propositions:prop-ledger

# 2. 語意軸 — per-prop L1-L5 walk(claim 是否為真、是否被 cite 蘊涵)
/propositions:prop-proofread

# 3. 跨檔案軸 — 送出前跑完整 cross-artifact drift audit
/propositions:prop-manuscript-audit

# 4. 可讀性軸 — 散文層級 stumble 掃描(不需要 JSONL)
/propositions:prop-clarity-audit
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
- Swift 6.2 以上的 toolchain，只在開發這個 repo 時需要。根目錄有一個 Swift package（`Package.swift`、`Sources/`、`tests/PropositionsKitTests/`），不在 plugin 的目錄裡、不隨 plugin 出貨：`PropositionsKit`、`propositions`、`tschema-check`。它有引用方向檢查 `propositions cite-order`（#46，規格 `citation-order`）與綱要的三個子命令 `propositions outline check`、`status`、`locators`（#78，規格 `article-outline`）；這些子命令都在 binary 0.2.0 裡。propositions plugin 在 session 開始時用 hook（`plugins/propositions/hooks/fetch-cli.sh`）把 `hooks/cli.lock` 鎖定的那一版下載到 plugin 的資料目錄，雜湊與簽章都符合才安裝，只有 macOS；`/propositions:prop-ledger` 的 Operation A 在驗證器之後經由 `hooks/run-cli.sh` 呼叫 `cite-order`（它每次執行前再比對一次雜湊，只執行鎖定的那一版），沒有那一版時回報這一項沒有檢查。綱要的三個子命令還沒有 skill 呼叫（#102）。package 另有 `propositions ledger-order`（#59，`reorder-ledger.py` 的移植，給 `--tex` 時支援多檔稿件），與 `propositions paragraphs`（#77，`derive-paragraphs.py` 的移植，location 可以指到輸入樹裡的任何檔），與兩支稽核 `propositions audit symbols`、`citations`（#69，讀整棵輸入樹與宣告的文獻檔；每個檔照 TeX 的讀法當一整串字元讀，`\verb`、`\lstinline`、verbatim 類環境與 `\url` 的內容是字面文字。這些子命令共用的輸入樹也因此不把 `\verb`、`\url` 裡的 `\input` 當成真的，並認得 `BVerbatim`、`minted`），在 binary 0.2.0（2026-11-21 發布，`cli.lock` 鎖定這一版）裡，`construct`、`construct-batch`、`manuscript-audit` 經 `run-cli.sh` 呼叫（現在鎖定 0.6.0）；`run-audit.sh` 用 `PROPOSITIONS_CLI`、`PROPOSITIONS_PLUGIN_DATA` 或 PATH 上的 `propositions`。package 另有改版重抽的 `propositions revise relocate`、`retire`、`check`、`redirect`（#56，schema v1.8 的 `retired.replaced_by`），在 binary 0.3.0 裡（`cli.lock` 鎖定這一版），由 `/propositions:prop-extract` 的「改版重抽」模式呼叫。package 另有寫入一段的 `propositions write prepare`、`check`、`commit`（#49，佔位寫成 `{PENDING: …}`），在 binary 0.4.0 裡（`cli.lock` 鎖定這一版），由 `/propositions:prop-construct` 的寫入模式呼叫。package 另有照綱要寫的部分（#51）：`write prepare` 可從空白稿件開始、加 `--heading`、加 `--outline` 與 `--outline-paragraph`（那一節要仍照通過時的內容），`write commit` 在綱要目錄追加 `outline-trace.jsonl`，`propositions outline trace` 檢查它；`write prepare --rewrite --outline` 照整份通過確認的綱要重寫整份稿件（#115，帳冊每一筆命題都要留著，只有 `location`、`cites`、`retired` 能變，`outline-map.jsonl` 列出每一筆寫出的綱要紀錄，各指到從一段開頭開始的現役命題；綱要與對照檔在 commit 時只讀一次，只寫內容變了的檔，原檔連同舊的對應紀錄備份並附 `backup/restore.jsonl`，對應紀錄整份重寫），在 binary 0.6.0 裡，由 `construct` 的重組模式呼叫；其餘在 binary 0.5.0 裡（`cli.lock` 鎖定這一版），由 `construct` 的寫入模式呼叫。package 另有全文的禁用說法（#118）：帳冊或綱要目錄的 `article.json` 的 `banned` 鍵列出不得出現的說法，`write check` 在新增的文字命中時回報並讓 `commit` 拒絕，`propositions phrasing` 對整份稿件比對；綱要的段落紀錄可以用 `opens`、`discharges` 規劃承諾（#116）：`outline check` 檢查格式與先開後兌現，`write check` 把寫出的段落在 discourse 附檔裡開啟與兌現的承諾和計畫比對，不符就讓 `commit` 拒絕（整份綱要都沒有規劃時不比對）。節紀錄可以用 `length` 記字數目標，`article.json` 的 `length` 記全文上限（#119）：`propositions outline length` 回報各節的目標、照綱要寫出的字數（由 `outline-trace.jsonl` 找段落）與各 part、全文的加總，只報告、不擋寫入。節紀錄可以用 `unread` 列出反推時沒讀的被引入檔（#117）：`outline check` 檢查格式，`outline status` 多一行 `sections that carry unread`，`write prepare` 在寫進那一節之前印出缺口。這四項都在還沒有發布的 binary 裡，skill 也還沒有呼叫。綱要的三個檔只讀一次，判斷、副本、雜湊都用同一份；commit 前再用綱要判斷一次，對應的命題要剛好一筆、從新段落開始，節標題要整行都是一個節指令。被取代的 `reorder-ledger.py`、`derive-paragraphs.py`、`audit-symbols.py`、`audit-citations.py`（含根目錄轉接層）已退役，只印出改用哪個子命令並以 2 結束。`swift test` 跑它的測試
- pytest 7+ for test suite
- `/propositions:prop-outline` 的指令另外需要 `jq` 與 `realpath`，其他 skill 不需要；它也需要 `git`，`/propositions:prop-manuscript-audit` 與 Operation D 原本就用 git（實跑過 jq 1.7.1 與 1.8.2、git 2.54 與 2.55；outline 開頭會先確認三個工具都在，jq 分得出兩個不同的長整數，1.7 之前的版本分不出來，git 是 2.38 以上，而且系統的 `pwd` 在 `/usr/bin` 或 `/bin`；少一樣就停下）
- LaTeX manuscript with `manuscript/main.tex` + `manuscript/propositions/main.jsonl` convention(可自訂 path via skill args)
- Schema versions: v1.0 – v1.8 — validator handles all with backward-compat skip for v1.2+-only rules (R7 / R11 / R12)；v1.4 = `retired`、v1.5 = `retired.superseded_mechanism`、v1.6 = multi-file（file-qualified location + `source.parts`）、v1.7 = `_meta.json` `profile`（`default` / `empirical`，決定 R11／R12 詞彙）、v1.8 = `retired.replaced_by`（改版重抽的取代句，`propositions revise` 寫入與檢查）。完整版本史見 `docs/SCHEMA.md` §Versioning

## Hard rules for contributors

- **不修 user 的 main.jsonl 不問**:任何會 write jsonl 的 skill (e.g., refresh-locations) 必須先 dry-run + AskUserQuestion 確認再寫。綱要的三個檔(`outline-*.jsonl`)除外:什麼時候寫、寫之前問什麼,照 `/propositions:prop-outline` 的 skill
- **Loud failure over silent fix**:寧可 anchor_failed 不要亂猜 line number
- **Schema 升級走 spec 流程**:不要 ad-hoc 加 enum 值;先改 `docs/SCHEMA.md` 確定新 canonical set,再更 validator + tests
- **Test 覆蓋每條 rule**:R1-R13 各自有獨立 fixture;改 normalize_for_match 等 shared helper 必跑全 R-rule test suite
- **新程式一律寫 Swift**:工具的目標是像 Akashic-Library 一樣完全用 Swift;既有 Python 只修不長,要加功能先移植那個模組。哪裡放什麼、例外與既有檔清單見 [`.claude/rules/swift-is-the-implementation-language.md`](.claude/rules/swift-is-the-implementation-language.md)

## Test suite

```bash
pytest tests/  # 期待 428+ passed
swift test     # Swift package 的測試
```

`tests/` 含 each rule 的 fixture + edge cases。Smoke tests live in the user's manuscript repo under `propositions/_smoke_tests/`(per-paper),不在 plugin。
