## Problem

#80 第六輪驗證（Codex）：1 項擋下、4 項要修。搬移區塊的 point 移到另一筆紀錄時，原紀錄的 `from` 被複製進 point 的 `basis`，而 checker 對 `basis` 不豁免 `edits` 列出的改動，作者記下的改動會被報成來源不支持。其餘：比對仍會比形狀不對的 locator；checker 的定義對 `replaces` 有兩句互相矛盾；兩個搬移區塊合進一筆紀錄時沒有規則；引文裡的控制字元沒有處理。

## Root Cause

「point 移走時把來源複製進 basis」是為沒有搬移區塊的情形寫的；搬移區塊換紀錄時，新紀錄已經帶著同一個 `from`。

## Proposed Solution

- 搬移區塊的 point 移到接手這個區塊的紀錄時，不複製 `from` 進 `basis`。
- 兩個搬移區塊不共用一筆紀錄：兩筆都帶 `carry` 的紀錄不合併，一個區塊的 point 不移進另一個區塊的紀錄。
- 寫入檢查只比對形狀完整的 locator。
- checker 只查 `from` 與 `basis` 的段落；查不到時的那一行是備註，不是 finding。
- 引文裡的控制字元寫成碼位；finding 的顯示規則適用於每一類。

## Non-Goals

- `alternative_to`（#99）。locator 指令遇到不是物件的行（既有行為，寫入檢查先跑）。

## Success Criteria

- 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 4 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
