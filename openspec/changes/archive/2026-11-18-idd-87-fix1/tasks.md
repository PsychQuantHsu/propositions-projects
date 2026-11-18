## 1. 文字

- [x] 1.1 停下的條件照規格寫，對應 Requirement「Derive and draft build an outline without inventing content」與第一輪第 1、6 列。完成時：SKILL.md 第 3、7 步、OUTLINE.md 與規格說同一個條件；規格有混合情形與表格情形兩個情境。
- [x] 1.2 帳冊的句子，對應 Requirement「The outline is three files beside the ledger」與第 2、4 列。完成時：三份文字都指向寫入檢查的判斷，列出擋下的四種與非 UTF-8 的例外。
- [x] 1.3 確認紀錄寫入失敗，對應 Requirement「Only the author's explicit statement in the current message approves」與第 3 列。完成時：三份文字都只說展示兩段檢查的結果。
- [x] 1.4 已知限制的開頭（第 5 列），SKILL.md 與 OUTLINE.md。

## 2. 驗證

- [x] 2.1 19 段指令與 `1e209fa` 逐段相同。
- [x] 2.2 `spectra validate` 通過；`pytest tests/` 通過；三個目錄相對於 main 沒有變動。
