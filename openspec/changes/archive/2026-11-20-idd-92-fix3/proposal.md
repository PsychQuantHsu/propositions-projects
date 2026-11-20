## Problem

#92 第三輪驗證（Codex）：2 項擋下、6 項要修。revise 只在四個鍵有改動時才檢查參照，另一篇刪掉被指到的紀錄後過期的參照不會被發現；另一份綱要的目錄實際名稱帶換行或控制字元、而段落檔不是 JSON 時，jq 的錯誤訊息會把那個名稱印出來。其餘：形狀不對的物件的 id 仍算數；沒有 checkout 的 submodule 目錄擋不住；段落檔是空的時沒有說明；checker 在 `from` 仍可能把帶 `outline` 的物件當 locator；寫錯的參照的診斷沒有帶 id；`basis` 的診斷文字沒有提參照。

## Root Cause

檢查的時機綁在「哪些鍵被改」，而參照會因為另一份綱要的改動而過期；診斷沿用了 jq 的錯誤輸出。

## Proposed Solution

- revise 每次改過段落檔就跑 locator 與參照的檢查。
- 查找的指令不顯示 jq 的錯誤輸出；另一份綱要的實際路徑不得有 locator 不允許的字元；它的目錄不得在 gitlink 之下。
- 只有形狀完整的段落紀錄與 point 的 id 算數。
- 段落檔是空的時不跑，說明沒有參照可查。
- checker：帶 `outline` 的物件在任何欄位都不是 locator。
- 診斷帶上 id；`basis` 的診斷文字提到參照。

## Non-Goals

- 兩篇說法是否一致。

## Success Criteria

- 八種組合全過，含新的案例：形狀不對的 id、沒 checkout 的 submodule 目錄、乾淨的別名指到名稱帶換行的目錄、段落檔不是 JSON 時不印任何東西。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
