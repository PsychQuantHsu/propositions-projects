## 1. 指令

- [x] 1.1 寫入檢查報出重疊的替代組；三段指令只在 `replaces` 是清單時讀它，對應 Requirement「A paragraph record holds at least one point」。完成時：三種重疊、落選紀錄不擋新組、`replaces` 是物件各有驗收案例。

## 2. 文字

- [x] 2.1 選定替代的規則、revise 的去留規則，對應 Requirement「Revising keeps ids stable and never loses a source」。
- [x] 2.2 顯示規則移到兩種顯示共用的一層，對應 Requirement「Only the author's explicit statement in the current message approves」。

## 3. 驗證

- [x] 3.1 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。
