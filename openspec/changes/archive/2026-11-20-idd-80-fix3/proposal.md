## Problem

#80 第三輪驗證（Codex）：3 項擋下、6 項要修。選定之後落選的紀錄仍會被一般的刪除規則刪掉；兩筆都落選又互指的紀錄通過檢查；`edits` 在區塊換到另一筆紀錄（移動 point）時沒有跟著走。另外：前提檢查把開著的一組的兩筆都當成無條件的支持；code span 會被反引號提早結束；`from` 與 `basis` 不是清單時仍被讀成 locator；同一段用 label 與 label 加 starts 兩種寫法時不被認成同一個；各節小計沒有定義；一句「不改寫」沒有但書。

## Root Cause

保留與 `edits` 的規則是照動作（合併、拆開）寫的，沒有照紀錄的性質（帶 `alternative_to`、代表搬移區塊）寫。

## Proposed Solution

- 帶 `alternative_to` 的紀錄，凡是保留有 `from` 的紀錄的規則都保留它，選定前後都一樣。
- 寫入檢查多報：帶 `dropped` 的紀錄與它指向的紀錄互指；locator 是否相同看 `file` 加 `label`（沒有 label 時看 `starts`）。
- 任何讓另一筆紀錄代表搬移區塊的修改，都把 `carry`、`from` 與適用的 `edits` 帶過去。
- 三段指令對 `from`、`replaces`、`basis` 一律只讀清單。
- checker：只有開著的一組引入的東西，兩筆都在前面才算已引入，否則報出並說哪個選擇成立。
- 引文用比文字裡任何一串反引號都長的 fence；各節小計把開著的一組的紀錄當成有條件的部分。

## Non-Goals

- 依實際解析到的位置比對 locator（要讀檔，留給 #78）。

## Success Criteria

- 八種組合全過，含新的案例：互指的落選紀錄被報出、同一個 label 在兩邊被報出、`from` 是物件時不列出檔案。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 5 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
