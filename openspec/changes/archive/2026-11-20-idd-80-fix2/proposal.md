## Problem

#80 第二輪驗證（Codex）：2 項擋下、7 項要修。一般的「加上 `dropped`」路徑（拿掉節、移走最後一個 point）會繞過替代組的選定規則；合併與拆開沒有規定 `edits` 怎麼辦，帶改動的區塊可能又被當成原樣搬移。另外：未落選的紀錄指向已落選的紀錄時檢查不報；重疊檢查把不是清單的 `from` 也拿來比；合併衝突問完作者之後沒有可執行的下一步；已選定的替代關係確認時看不到；長度的算法依賴鍵的方向；引文沒有規定不被渲染；鍵表沒有寫交叉引用的例外。

## Root Cause

「開著的一組」沒有單一的定義，檢查、status 與 revise 的規則各用各的；`edits` 沒有放進合併與拆開的規則。

## Proposed Solution

- 一組在兩筆都沒有 `dropped` 時是開著的；寫入檢查、status 與 revise 都用這個定義。未落選的紀錄不得指向帶 `dropped` 的紀錄。
- 任何會讓開著的一組的成員得到 `dropped` 的規則，都先問作者這一組怎麼辦。
- 合併與拆開後仍代表搬移區塊的紀錄保留 `carry` 與適用的 `edits`；分不開就問作者。
- 合併衝突：作者的回答就是把 locator 從另一個清單拿掉的指示，拿掉後再合併；兩邊都要留就不合併。
- 顯示：已落選的紀錄連同它指向的入選紀錄一起顯示；取自紀錄的文字放在 code span 或 code block。
- 長度：開著的一組給範圍，不依賴鍵的方向。鍵表寫明交叉引用的例外。

## Non-Goals

- 長度的鍵。

## Success Criteria

- 八種組合全過，含新的案例：指向已落選紀錄被報出、兩筆都落選時不報、`from` 是物件時不拿來比。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
