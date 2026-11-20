## Problem

#80 加了三個鍵。四輪驗證下來，`edits` 與 `replaces` 站得住；`alternative_to` 每一輪都在它和另一條既有規則的交界找到擋下的項目（選定的方向、刪除規則、確認的範圍、前提檢查、計數）。這個鍵讓一筆紀錄在不在文章裡變成有條件的，而綱要其他的規則都假設每筆紀錄的去留是確定的。

## Root Cause

「有條件的段落」是一個橫跨刪除、確認、前提檢查與計數的概念，不是加一個鍵就能表達的。

## Proposed Solution

維護者的決定（2026-11-20）：把 `alternative_to` 從這張拆出去，另開 issue 重新設計。這張只留 `edits` 與 `replaces`。

- 規格、SKILL.md、OUTLINE.md、checker 的定義移除 `alternative_to` 的鍵、檢查、status 的那一行、顯示與 revise 的規則。它回到「額外的鍵」：格式允許，檢查不看。
- 順帶修第四輪與它無關的三項：搬移區塊換到 `replaces` 有同一個 locator 的紀錄之前先問作者；規格第六類 finding 的說明加上 `replaces`；比對 locator 時不比沒有 `file` 的物件。

## Non-Goals

- `alternative_to` 的任何行為。

## Success Criteria

- SKILL.md、OUTLINE.md、checker 與主規格都不再提 `alternative_to`。
- 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 5 條 requirement，移除 1 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
