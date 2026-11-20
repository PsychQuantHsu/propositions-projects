## Problem

#92 第二輪驗證（Codex）：3 項擋下、6 項要修。revise 只在「指到另一份綱要」時才跑參照的檢查，`"uses": 7` 這種寫法因此不會被檢查；「同一個 repository」只比工作樹的根，working tree 設到外層 root 的另一個 repository 會通過；指令開頭的 `P` 沒有說明怎麼換成暫存檔。另外：section 紀錄的 id 被當成段落的 id；`uses` 裡的空字串通過；`from` 與 `replaces` 裡帶 `outline` 的物件仍被當成 locator；目錄讀不到時只印紀錄、不印是哪個 id；`moved_to` 只檢查 `dropped` 這個鍵在不在；差異顯示沒有參照的狀態。

## Root Cause

檢查的觸發條件依賴「先認出這是參照」；repository 的判定只用了一個訊號。

## Proposed Solution

- revise 在 `uses`、`from`、`replaces`、`basis` 有任何改動時都跑參照的檢查；沒過就不算完成。
- 另一份綱要的 git 目錄要與 root 的相同。
- 只有段落紀錄（有 `section` 與清單 `points`）與它的 point 的 id 算數；`uses` 的 id 要非空。
- 帶 `outline` 的物件在 `from`、`replaces` 裡報出，locator 的指令不讀它。
- 列舉印出每個參照的紀錄與 id。`moved_to` 要求 `dropped` 是非空字串。
- 參照的狀態與原樣顯示的規則移到完整顯示與差異顯示共用的一層；文字說明 `P` 和 locator 的指令一樣換成要檢查的檔。

## Non-Goals

- 兩篇說法是否一致。

## Success Criteria

- 八種組合全過，含新的案例：`uses` 的空字串、`from` 裡的參照、section 的 id、`dropped` 三種不合格的值。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
