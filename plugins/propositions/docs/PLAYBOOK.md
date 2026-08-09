# PLAYBOOK — 一份 .tex manuscript 採用 propositions 工作流的完整生命週期

> 這份文件回答的是「onboard 之後的日子怎麼過」。單一操作的機械細節在
> [`../skills/propositions/SKILL.md`](../skills/propositions/SKILL.md)（Operations A/B/C/D），
> schema 契約在各 ledger 自帶的 `SCHEMA.md`。全篇以 **Hsu case**
> （PsychQuantHsu/psychophysical_representations，本工作流的起源專案「Locke project」）
> 的真實事件為 worked example——每個階段都發生過，不是假想。

## 全景

```
Operation D          Operation C → A         日常節奏             送審前            大改版
┌──────────┐        ┌──────────────┐      ┌──────────────┐    ┌───────────┐    ┌─────────────┐
│ scaffold │───────▶│ 首次抽取+驗證 │─────▶│ 改tex→A→B修位 │──▶│ 三軸 audit │──▶│ re-anchor   │──▶(回日常)
│ ledger   │        │ (逐節可分批)  │      │  (每次改動)   │    │           │    │ (新base採用) │
└──────────┘        └──────────────┘      └──────────────┘    └───────────┘    └─────────────┘
                                                 │
                                                 └──▶ 通信驗證（co-author 提問時,隨時發生）
```

## 階段 0 — Onboard（Operation D，一次性）

新稿還沒有 ledger 時跑一次。產出：`propositions/`（釘版 SCHEMA.md + EXTRACTION-PROMPT.md
副本、`_meta.json`、README、`_smoke_tests/` 骨架）。要點：

- **放置層選穩定目錄**。版本目錄輪替慣例（`05xx-2026/` → 下一版換目錄）的稿，ledger
  放輪替層的上一層；版本切換是 re-anchor（階段 4），不是搬 ledger。
- **multi-file 直接支援**（schema v1.6）：`_meta.json` 記主檔，`\input` 樹自動解析；
  prop 用 `parts/part2-theory.tex:L123` 形式的 file-qualified location。

## 階段 1 — 首次抽取（Operation C → A）

依釘版 EXTRACTION-PROMPT 對主檔（或逐節分批）抽取 JSONL，**每批都以 Operation A 收尾**
——沒過 validator 的抽取不算完成。

**Worked example（Hsu case）**：全稿 Phase 1 抽出 342 條（後成長至 364）；thm:eta-s
一節另做 Phase 2 clause-level 細化（81 條）。逐節分批讓單節失敗不影響已完成的節。

## 階段 2 — 日常節奏（每次改 tex）

1. 改完 tex → **Operation A**。R1 fail = 措辭真的變了 → 更新 `prop.text`（verbatim）；
   R1 pass 但 R13 WARN 升高 = 只是行號漂移 → 2。
2. **Operation B** dry-run → 看清單 → confirm 寫入 → 重跑 A 確認 R13 歸零。
3. commit 時 tex 與 jsonl 同 commit（per-commit sync 紀律：
   [`../rules/manuscript-jsonl-sync.md`](../rules/manuscript-jsonl-sync.md)）。

## 階段 3 — 送審前（三軸 audit）

機械軸（A）之外加三軸：`/propositions:proofread`（L1–L5 語意 walk：每條 cite 是否真的
蘊涵）、`/propositions:manuscript-audit`（tex/jsonl/code/bib 跨檔案 drift）、
`/propositions:clarity-audit`（散文 stumble）。順序建議 proofread → manuscript-audit →
clarity-audit（語意錯誤先修，免得改文字又觸發前兩軸）。

## 階段 4 — 大改版 re-anchor（新 base / 章節重排）

co-author 給了重寫版、或自己大重構時，**不重抽全部**——走 re-anchor：

1. 採用新 base（tex 換成新版）。
2. **Operation B 大範圍 re-anchor**：能靠 windowed locator 自動遷移的先遷。
3. 真的改寫過的節 → **Operation C 重抽該節**；消失的段落 → prop 標 `retired`
   （v1.4+ 欄位：`mechanism` / `match` / `reason`——留 audit trail，不刪 prop）。
4. Operation A 全綠 + `_meta.json` 更新錨定 commit。

**Worked example（Hsu case #147，2026-08-02）**：採用 Hsu 的 condensed 第三版稿為
base——374 條中 299 條 relocate、60 條重抽、5 條 retired-restored、10 條刪除（審計留
git history），最終 364 條全綠。定理/引理編號在新 base 重排（pexider-sep 從 Lemma 5
變 Lemma 4），ledger 錨定讓這種重排可以機械追蹤。

## 階段 5 — 通信驗證（co-author 提問，隨時發生）

repo 層慣例，不是 skill——但它是這套基礎設施最直接的回報：co-author 對稿件內容提問時，
答案可以**逐行錨定**。

**Worked example（Hsu case #148，2026-08-01～02）**：Hsu 問「Theorem 2 是否已不用
slope-matching（由 smoothness 取代、僅 Theorem 4 用）？」流程：

1. **釘 commit**：答覆錨定明確 snapshot（`main` @ `f730c08`），行號有所指。
2. **逐行驗證**：grep + 定理邊界對映 → 發現該詞在 Thm 2 是 divided-difference 形式
   （不需微分）、Thm 4 是 first-order 形式（需可微）——「同名兩形式」正是提問者混淆
   的根源。
3. **對照表回覆**：四定理 × {slope-matching 有無、形式、smoothness 假設} 的表 + 行號，
   直接在 issue 回覆並 mention（簽名揭露 AI 協作）。
4. **措辭問題回饋稿件**：詞彙雙義開 sister issue（#149），等 co-author 表態命名偏好
   再動稿——術語決定權共享。

要點：版本先問清楚（對方讀的是哪個 snapshot）、行號永遠附 commit 錨、發現的表達層
問題回饋成稿件 issue 而不是只答完就丟。

## 反模式（Hsu case 都踩過或差點踩）

| 反模式 | 正解 |
|--------|------|
| 抽取沒過 validator 就當完成 | Operation C 的定義含 A 閘門 |
| R13 WARN 用手改行號 | Operation B（windowed locator + dry-run），手改必漂 |
| 大改版重抽全部 | re-anchor 優先（#147:299/374 靠 relocate，只重抽 60） |
| 段落停用就刪 prop | `retired` 欄位——刪除毀 audit trail |
| 答 co-author 憑記憶 | 釘 commit + 逐行驗證（#148 的教訓：連 Lemma 編號都會記錯） |
| ledger 放版本輪替目錄內 | 放穩定層；版本切換 = re-anchor 不 = 搬家 |
