## Why

#12 把這個 plugin 定位成「拆解層」：把稿件拆成帶原文、位置與引用 DAG 的命題帳冊。但拆解本身（Operation C）在 propositions skill 裡只有一段指向抽取 prompt 文件的說明，四個 operation 中只有它沒有逐步流程，也沒有自己的機械檢查。validator 的 R1 只驗證「prop 的原文出現在 `.tex` 裡」，抓得到捏造，抓不到漏句；反方向的 R1.5 只檢查到 section 層級，而且只發警告。

#24 等待的觸發條件也已經成立：有一份英文實證心理學稿件（APA 格式、沒有定理環境、有 Method／Results 與統計量）需要拆成帳冊。proofread Mode B 已經定義了實證主張的詞彙（`result`、`interpretation`；`measured`、`tested`、`descriptive`、`not_computable`），但 validator 的 R11／R12 是封閉 enum，用這組詞彙寫的帳冊一定 FAIL。不先做 profile 機制，這份稿件就沒辦法進入機械把關。

## What Changes

- 新增 `propositions:extract` skill：把一個段落或區段拆成 propositions JSONL 的逐步流程。依序為：讀帳冊的 profile → 選切法 → 用 grep 確認環境邊界 → 組 per-call prompt → LLM 以暫時 id 輸出到帳冊外的暫存檔 → 換成 UUID v7 → 覆蓋檢查 → 人工 curation → 把新 prop 插進暫存區的 `main.jsonl` 副本並跑 validator → 副本通過後，經 dry-run 確認才寫入 `main.jsonl`。數學 profile 與實證 profile 各有一份 reference，寫該領域的切法與詞彙。
- 新增 `assign-prop-ids.py`：把 JSONL 裡的暫時 id（`tmp:<n>`）一致地換成 UUID v7（RFC 9562 §5.7），`id` 與 `cites` 一起換。這台機器的 Python 3.13 沒有 `uuid.uuid7()`，所以由 script 自己實作。輸出寫到 stdout 或指定的新檔，不就地改寫任何帳冊。
- 新增 `check-extraction-coverage.py`：給定 `.tex` 檔與行號範圍，列出範圍內沒有被任何 prop 涵蓋的文字片段，並附行號。結構性內容（註解、`\label`、章節標題、float 環境）不列入檢查，但會在輸出中列出被排除的區塊，不會悄悄略過。
- 修正 #25：R1 的正規化把跳脫的 `\%` 當成註解開頭，含 `\%` 的逐字 prop 會被判為失敗，`\%` 之後到行尾的文字也從比對中消失。正規化步驟抽成 R1 與覆蓋檢查共用的步驟表，並把 `%` 前面有奇數個反斜線的情況當作文字。實證稿件常寫 `95\% CI`，不修正就拆不了。
- `_meta.json` 新增 `profile` 欄位（schema v1.7）。validator 依 profile 決定 R11／R12 的 enum：`default` 與現行行為相同；`empirical` 在預設 enum 之外，再加上 proofread Mode B 的詞彙，以及 pilot 之後新增的 `external`（支持在論文以外的主張）。宣告了未知的 profile，或在 schema_version 低於 1.7 時宣告 profile，validator 一律報錯。
- Operation D（onboarding）寫入的 `_meta.json` 升到 schema 1.7 並記錄 profile。完成後的交棒對象從 Operation C 改成 `propositions:extract`。
- propositions skill 的 Operation C 改成一句話，指向 `propositions:extract`。proofread Mode B 的 schema 擴充一節改為說明「要宣告 `profile: empirical`」。

## Capabilities

### New Capabilities

- `ledger-profiles`：帳冊在 `_meta.json` 宣告的 profile，決定 validator R11／R12 接受的 `claim_type` 與 `evidence_class` 詞彙。
- `proposition-extraction`：`propositions:extract` skill，以及它的兩支機械工具（暫時 id 換成 UUID v7、段落覆蓋檢查），還有抽取完成的判準。

### Modified Capabilities

- `manuscript-onboarding`：Operation D 的 scaffold 寫入 schema 1.7 與 profile；完成後的交棒對象改成 `propositions:extract`。

## Impact

- Affected specs: `ledger-profiles`（新）、`proposition-extraction`（新）、`manuscript-onboarding`（修改）
- Affected code:
  - New:
    - plugins/propositions/skills/extract/SKILL.md
    - plugins/propositions/skills/extract/references/math.md
    - plugins/propositions/skills/extract/references/empirical.md
    - plugins/propositions/scripts/assign-prop-ids.py
    - plugins/propositions/scripts/check-extraction-coverage.py
    - plugins/propositions/scripts/_lib/normalize.py
    - tests/test_lib_normalize.py
    - tests/test_ledger_profiles.py
    - tests/test_assign_prop_ids.py
    - tests/test_check_extraction_coverage.py
  - Modified:
    - plugins/propositions/scripts/validate-propositions.py
    - docs/SCHEMA.md
    - plugins/propositions/skills/propositions/SKILL.md
    - plugins/propositions/skills/proofread/SKILL.md
    - plugins/propositions/templates/ledger/_meta.template.json
    - plugins/propositions/templates/ledger/README.md
    - plugins/propositions/docs/PLAYBOOK.md
    - plugins/propositions/README.md
    - plugins/propositions/.claude-plugin/plugin.json
    - .claude-plugin/marketplace.json
    - CLAUDE.md
  - Removed: (none)
