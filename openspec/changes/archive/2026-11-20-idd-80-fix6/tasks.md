## 1. 指令

- [x] 1.1 寫入檢查只比對形狀完整的 locator，對應 Requirement「A paragraph record holds at least one point」。

## 2. 文字

- [x] 2.1 搬移區塊換紀錄時不複製 `basis`、兩個搬移區塊不共用紀錄，對應 Requirement「Revising keeps ids stable and never loses a source」。
- [x] 2.2 checker 的查找範圍與 finding 的顯示，對應 Requirement「A premise check runs before an outline is shown for approval」；控制字元，對應 Requirement「Only the author's explicit statement in the current message approves」。

## 3. 驗證

- [x] 3.1 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。
