## 1. 擋下的一項

- [ ] 1.1 沒讀的被引入檔只告訴作者，對應 Requirement「Derive and draft build an outline without inventing content」「A paragraph record holds at least one point」「Revising keeps ids stable and never loses a source」與第七輪報告第 1、2、6、9、10 列。完成時：反推不為它寫任何東西；讀得到的檔裡沒有段落或區塊時停下並說明；`note` 的定義與修改規則回到一般的寫法。驗證：一位只拿到 SKILL.md 的 agent 照反推做三份稿件，結果符合 proposal 的成功條件。

## 2. 其餘的文字

- [ ] 2.1 引入指令對到清單，對應 Requirement「Derive and draft build an outline without inventing content」與第 3、4、5 列。完成時：`x.tex`、`\input` 才退到 `x`；先主檔的目錄、再根目錄；不寫「照 LaTeX」；圖表的例外回到規格。
- [ ] 2.2 作者指定的檔，對應 Requirement「Text from the manuscript and the author never becomes part of a command」與第 7、8、12 列。完成時：它的路徑列入封閉清單；檢查不改變 `MAIN`；沒有稿件時仍為它跑檢查；硬規則加一條。
- [ ] 2.3 確認與限制，對應 Requirement「Only the author's explicit statement in the current message approves」與第 11、14、15 列。完成時：寫入失敗時不判斷寫了多少、展示並停下；確認跑狀態時先跑寫入檢查；第 1、10 項限制一定看得到。
- [ ] 2.4 issue 上的紀錄，對應第 13、16 列與第五輪第 9 列。完成時：Implementation Complete 列出第二項保證例外的放寬、封存後加的附註；#51 留一則開放問題。

## 3. 驗證

- [ ] 3.1 19 段指令與 `aa8a63d` 逐段相同；八種組合重跑 389 項。
- [ ] 3.2 獨立 agent 對照規格、OUTLINE.md 與 SKILL.md。
- [ ] 3.3 盲讀者重答改過的規則的題目。
- [ ] 3.4 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
