## 1. 擋下的四項

- [x] 1.1 主稿件的檢查，對應 Requirement「The outline is three files beside the ledger」「Derive and draft build an outline without inventing content」與第四輪報告第 1 列。完成時：`Resolve paths` 有一段指令檢查主稿件，通過時印出實際路徑與從根目錄算起的名稱；反推讀稿之前再跑一次。驗證：已追蹤的檔、未追蹤且未忽略的檔、經由 repo 裡的目錄連結到達的檔通過；指到 repo 外或 repo 裡的 symbolic link、不存在的檔、目錄、repo 外的檔、git 忽略的檔、`.git` 裡的檔都印 `STOP`。
- [x] 1.2 一份帳冊最多指到一個檔，對應 Requirement「The outline is three files beside the ledger」與第 2 列。完成時：先從帳冊自己的 repo 根目錄讀，再從最外層的根目錄讀，只接受落在帳冊自己的 repo 裡的一般檔。驗證：規格的三個例子仍然認得出來；submodule 與內層 repo 裡別篇稿件的帳冊、用 `..` 爬出去的帳冊、主檔不見的帳冊都不指到外層的稿件。
- [x] 1.3 交給 checker 的是計數的那個檔，對應 Requirement「A premise check runs before an outline is shown for approval」「Text from the manuscript and the author never becomes part of a command」與第 3 列。完成時：逐檔指令把檔名與實際路徑寫進清單；任務訊息只有四個路徑；checker 的定義改成讀清單。驗證：`lnin/../../outside.tex` 的清單路徑是 repo 裡的那個檔；被拒絕的檔不在清單裡。
- [x] 1.4 整份確認前展示節的順序與不在檔裡的節，對應 Requirement「Only the author's explicit statement in the current message approves」「A section stands as approved while it equals its latest approved copy」與第 4 列。完成時：狀態回報通過之後被拿掉的節；差異指令印出兩種順序與每一個這樣的節通過時的內容；展示全部的節時，確認第 4 步先展示這兩樣。驗證：對調兩節、刪掉一節、只有逐節確認、整份確認記下刪除之後不再列出，四種情況。

## 2. 其餘的指令

- [x] 2.1 第一段指令與暫存目錄，對應 Requirement「The outline skill writes only the three outline files」「Text from the manuscript and the author never becomes part of a command」與第 7、13、16 列。完成時：先測 jq 能分辨兩個長整數；git 找不到 repo 時印 `STOP`；機器的暫存目錄在 repo 裡時什麼都不建；暫存目錄記下根目錄，每一段指令都確認它。驗證：分不出兩個數字的 jq 沒有 `ok tools`；非 git 目錄有 `STOP` 行、沒有 realpath 的錯誤；上一層目錄、`/tmp`、別的 repo 的暫存目錄、別人讀得到的目錄都被拒絕。
- [x] 2.2 列帳冊與沒有稿件的起草，對應 Requirement「The outline is three files beside the ledger」與第 5、9、15、19 列。完成時：恰好一個 JSON 物件才有 `ledger` 行；沒有稿件時比對指令印 `ok` 行；有 `_meta.json` 讀不了、或請求裡的目錄與帳冊的目錄不同時問作者；skill 開頭不再說 `OUTDIR` 從請求取得。驗證：兩個值、物件後接清單的 `_meta.json` 印 `not one ledger`，比對時不指到稿件。
- [x] 2.3 確認紀錄檔的錯誤指名檔案，對應 Requirement「A section stands as approved while it equals its latest approved copy」與第 14 列。完成時：解析錯誤與形狀不對都報成指名確認紀錄檔的錯誤；狀態失敗時分三種處理。驗證：只有一個左大括號的行、`sections` 裡是數字、`sections` 是字串、沒有 `paragraphs`、沒有 `sections` 五種情況。
- [x] 2.4 git 忽略的檔與顯示，對應 Requirement「A locator names a passage by a label or by its opening words」「Derive and draft build an outline without inventing content」與第 23、25 列。完成時：來源指標的檔與被引入的 `.tex` 都要 git 列得出；檔名含控制字元或改變方向的字元時不列入、不照原樣印出；label 以 JSON 字串印出；攤平的文字用完就刪。驗證：外層、submodule、內層 repo 裡被忽略的檔都不讀；強制加入追蹤的檔與未追蹤的新檔可讀。

## 3. 句子與規則

- [x] 3.1 規格、說明文件、skill 與 checker 定義的句子，對應 Requirement「Revising keeps ids stable and never loses a source」「The explanatory document describes the outline」「Derive and draft build an outline without inventing content」與第 6、10、11、12、20、21 列。完成時：相同的段落停下並說明；沒有標題的引言自成一節；搬走最後一個要點時問作者；SCHEMA 的說法改成它寫的是哪個詞、沒定的是什麼；控制字元的規則補上鍵名；`allowed-tools` 做什麼照實寫。
- [x] 3.2 [P] Swift 規則、同步規則、`CLAUDE.md`、plugin 的 README，對應第 8、17、18、22 列。完成時：〈不適用〉第 1 類與修正輪 3 之前相同；〈例外〉第 4 類點名指令區塊，標題與退場條件一致；同步規則與硬規則回到原本的字句加一句排除；README 的 Skills 清單有 outline。驗證：`git diff main` 對〈不適用〉第 1 類沒有差異。

## 4. 驗證

- [x] 4.1 SKILL.md 的 19 段指令照寫法逐段實跑，四種組合，另加 GNU 的 `realpath`。完成時：各 324 項全部符合預期；17 項重現例子在修正前的檔案上全部失敗。
- [x] 4.2 一位獨立 agent 對照第四輪報告要處理的列，逐列回報已處理與在哪一句。完成時：沒有未處理的；有的話先修再重跑。
- [ ] 4.3 獨立 agent 只看這一輪的 diff，為每一項改動的行為找會出錯的輸入並實跑；修正之後由另一位只看修正的部分再找一次，直到一次找不到實跑得出來的缺陷。完成時：找到的都修掉或寫明不處理的理由。
  - 2026-11-17 更正（第五輪驗證第 7 列）：這一項原本打了勾，完成條件其實沒有達到。三位測試者依序實跑 675、1277、10068 次，各重現 6、5、2 項；第三位仍重現 2 項，那兩項的修正（`97a6ecc`）之後沒有再由獨立測試者實跑。由 `idd-75-fix5` 的 4.2 接續。
- [ ] 4.4 獨立讀者重讀最後的 OUTLINE.md，題組加上這一輪改過的規則。完成時：答案與預存的答案全部相同。
  - 2026-11-17 更正（第五輪驗證第 7 列）：這一項原本打了勾，完成條件其實沒有達到。讀者讀的是 `7e3a1bb` 的 OUTLINE.md，183 題裡 182 題與預存答案相同、1 題不同；之後文件又改了三次，沒有再盲讀。由 `idd-75-fix5` 的 4.4 接續。
- [x] 4.5 全套 pytest 通過；spectra validate 與 spectra analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
