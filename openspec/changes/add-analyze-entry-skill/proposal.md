## Why

要分析一篇文章，現在得自己記得七個 skill 的順序和前提，例如 `propositions:construct` 要求帳冊先通過檢查、範圍內沒有漏字。維護者希望「分析這篇文章」只要說一次（#40）。

合併七個 skill 不是好做法：它們的觸發條件不同，只想改一句話時不該載入整條流程，合併後同一份內容也會有兩個版本。需要的是一個入口。

## What Changes

- 新增 skill `/propositions:analyze`：判斷文章現在到哪一步，呼叫既有的 skill 跑下一個還沒完成的步驟，最後給一份報告。
- 進度從檔案判斷，不另存進度檔，所以中斷後再跑一次就會從停下的地方接續。
- 入口本身不寫入稿件、帳冊或附檔。所有寫入都留在原本的 skill 裡，由它們自己的確認把關；使用者不同意時入口就停下回報。
- 預設深度是拆命題、機械檢查、全文結構，然後讀出句子之間的關係。`proofread`、`manuscript-audit`、`clarity-audit` 要明確要求才跑。
- 帶未兌現承諾的完整文章不算壞掉：入口把它當成發現寫進報告，不當成失敗。
- 修 Operation D：scaffold 時多建一個空的 `main.jsonl`（#41）。現在新稿接 `extract` 會當掉，入口的 `no-ledger` 路徑接不下去。
- `propositions` plugin 版本升到 0.10.0。

## Non-Goals

- 不合併、不改寫既有的七個 skill，它們仍可直接呼叫。例外只有 Operation D 的 scaffold 清單（#41）。
- 不新增工具、參數或 Python 行為。
- 不做 `/idd-all` 式的一路跑到底：遇到寫入就停。
- 不評論文章好壞，也不處理非 LaTeX 來源。

## Capabilities

### New Capabilities

- `article-analysis`: 分析整篇文章的入口：判斷進度、依狀態呼叫既有 skill、遇到寫入就停、最後報告。

### Modified Capabilities

- `manuscript-onboarding`: Operation D 多建一個空的 `main.jsonl`，讓 `extract` 能從新帳冊開始。

## Impact

- Affected specs: `article-analysis`, `manuscript-onboarding`
- Affected code:
  - New: `plugins/propositions/skills/analyze/SKILL.md`
  - Modified: `plugins/propositions/README.md`、`README.md`、`CLAUDE.md`、`plugins/propositions/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`tests/test_plugin_payload_tracked.py`、`tests/test_validate_propositions.py`、`tests/test_check_extraction_coverage.py`、`plugins/propositions/skills/propositions/SKILL.md`、`plugins/propositions/templates/ledger/README.md`、`plugins/propositions/docs/PLAYBOOK.md`
  - Removed: (none)
- Python 腳本的行為不變：判斷進度只用現成的工具，符合 `.claude/rules/swift-is-the-implementation-language.md`。
