## 1. 指令

- [x] 1.1 寫入檢查：互指的落選紀錄、locator 的相同判定，對應 Requirement「A paragraph record holds at least one point」。
- [x] 1.2 三段 locator 指令只讀清單，對應 Requirement「A locator names a passage by a label or by its opening words」。

## 2. 文字

- [x] 2.1 保留帶 `alternative_to` 的紀錄、搬移區塊換紀錄時帶著 `edits`，對應 Requirement「Revising keeps ids stable and never loses a source」。
- [x] 2.2 checker 的定義，對應 Requirement「A premise check runs before an outline is shown for approval」。
- [x] 2.3 引文的 fence，對應 Requirement「Only the author's explicit statement in the current message approves」。

## 3. 驗證

- [x] 3.1 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。
