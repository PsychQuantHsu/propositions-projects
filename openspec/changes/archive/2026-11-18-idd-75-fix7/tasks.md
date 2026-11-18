## 1. 擋下的一項

- [x] 1.1 沒讀的被引入檔只告訴作者，對應 Requirement「Derive and draft build an outline without inventing content」「A paragraph record holds at least one point」「Revising keeps ids stable and never loses a source」與第七輪報告第 1、2、6、9、10 列。完成時：反推不為它寫任何東西；讀得到的檔裡沒有段落或區塊時停下並說明；`note` 的定義與修改規則回到一般的寫法。驗證：一位只拿到 SKILL.md 的 agent 照反推做三份稿件，結果符合 proposal 的成功條件。
  - 一位只拿到 SKILL.md 與 OUTLINE.md 的 agent 對 `a8437ad` 照反推做三份稿件：引入兩次的做到第 8 步、綱要裡沒有那個檔、告訴了作者；各節都在被忽略的檔裡的停在第 7 步第三種情況；`\input{ch1.final}` 讀到 `ch1.final.tex`。它指出的兩處不清楚改在 `7f00e4c`。

## 2. 其餘的文字

- [x] 2.1 引入指令對到清單，對應 Requirement「Derive and draft build an outline without inventing content」與第 3、4、5 列。完成時：`x.tex`、`\input` 才退到 `x`；先主檔的目錄、再根目錄；不寫「照 LaTeX」；圖表的例外回到規格。
- [x] 2.2 作者指定的檔，對應 Requirement「Text from the manuscript and the author never becomes part of a command」與第 7、8、12 列。完成時：它的路徑列入封閉清單；檢查不改變 `MAIN`；沒有稿件時仍為它跑檢查；硬規則加一條。
- [x] 2.3 確認與限制，對應 Requirement「Only the author's explicit statement in the current message approves」與第 11、14、15 列。完成時：寫入失敗時不判斷寫了多少、展示並停下；確認跑狀態時先跑寫入檢查；第 1、10 項限制一定看得到。
- [x] 2.4 issue 上的紀錄，對應第 13、16 列與第五輪第 9 列。完成時：Implementation Complete 列出第二項保證例外的放寬、封存後加的附註；#51 留一則開放問題。
  - #51 留言 6959508133；第七輪第 13、16 列列在 Implementation Complete 的「還沒有定案的事」。

## 3. 驗證

- [x] 3.1 19 段指令與 `aa8a63d` 逐段相同；八種組合重跑 389 項。
  - 19 段與 `aa8a63d` 逐段相同（封存前在 `7f00e4c` 再比一次）；八種組合 389 項全過（bfs 388 項），對 `a8437ad`。
- [x] 3.2 獨立 agent 對照規格、OUTLINE.md 與 SKILL.md。
  - 對 `a8437ad`：8 項（確認第 4 步殘留的 `note` 句、只有某一節的內容都沒讀時的 `says`、OUTLINE 的寫入失敗說法、引入指令的找法三份不一、封閉路徑清單漏了作者的綱要檔、開放問題沒有列、規格的句子順序、幾處小字），改在 `09f0eea`。
- [x] 3.3 盲讀者重答改過的規則的題目。
  - 第二十三位讀者讀 `7f00e4c` 的 OUTLINE.md，重答 18 題（這一輪改到的規則，含 6 題新題），答案都與新規則一致，沒有標兩種讀法或答不出的題。
- [x] 3.4 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
  - `pytest tests/`：872 passed、3 skipped；`spectra validate` 通過、`spectra analyze` 沒有 warning；三個目錄相對於 main 沒有變動。
