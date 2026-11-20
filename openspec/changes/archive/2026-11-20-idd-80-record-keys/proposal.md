## Problem

段落綱要第一次用在一份真實的稿件上，有三種紀錄和原稿的關係沒有位置可記（#80）：區塊是搬移的，但陳述有幾處改動；新寫的段落取代舊段落；兩筆紀錄說同一件事、作者還沒選。使用端各自加了額外的鍵，但檢查不看它們，確認時也不會標出來：作者確認一筆 `carry` 紀錄時以為陳述沒動，被取代的文字被當成來源，互為替代的兩筆被重複計算。

## Root Cause

段落紀錄只有 `from`、`carry`、`dropped` 三個鍵描述它和原稿的關係，這三種情形落在它們之間。

## Proposed Solution

維護者的決定（https://github.com/PsychQuantHsu/propositions-projects/issues/80#issuecomment-6981477928）：收進格式；只算改到陳述內容的改動；沒被選的那一筆改標 `dropped`、保留 `alternative_to`。

段落紀錄加三個選用的鍵：`edits`（非空字串，只在有 `carry` 的紀錄上）、`replaces`（locator 的清單，不是來源）、`alternative_to`（另一筆段落紀錄的 id）。

- 寫入檢查多三項：`edits` 的形狀與位置、`alternative_to` 指到另一筆段落紀錄、同一個 locator 不同時在 `from` 與 `replaces`。
- 列舉與解析 locator 的兩段指令把 `replaces` 算進去。
- status 多一行：還沒選定的替代有幾組。
- 確認時的顯示、revise 的規則（合併、拆開、不刪除有 `replaces` 的紀錄）、前提檢查的 agent 定義跟著改。

## Non-Goals

- 區塊帶改動搬移之後的實際文字（#51）。
- 長度的鍵：格式沒有，只寫明計數的規則。
- Swift 的檢查（#78）。

## Success Criteria

- 八種組合全過，含新的案例：三個鍵的合法紀錄通過寫入檢查；八種不合法的寫法各被報出；`replaces` 的 locator 被列出並解析；status 在選定前後的計數。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 6 條 requirement，加 5 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（寫入檢查、列舉與解析 locator、status 四段指令與說明）、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
