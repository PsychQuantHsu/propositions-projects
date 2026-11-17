## 1. 擋下的兩項

- [ ] 1.1 讀 repo 的 git 指令都帶兩個選項，對應 Requirement「Text from the manuscript and the author never becomes part of a command」與第五輪報告第 1 列。完成時：SKILL.md 裡每一個 `rev-parse`、`ls-files`、`check-ignore` 都帶 `-c safe.bareRepository=explicit -c core.fsmonitor=false`；第一段指令在 git 低於 2.38 時印 `missing` 行、不印 `ok tools`。驗證：提交偽裝成 repo 的目錄（`HEAD`、`objects/`、`refs/`、指名一段指令的 `config`），clone 之後跑第一段、主稿件檢查、帳冊比對、列 `.tex` 檔、逐檔計數，那段指令都沒有被執行，那些目錄裡的檔不被讀；linked worktree 與 bare repo 的 worktree 照常運作；回報 2.30 的 git 沒有 `ok tools`。
- [ ] 1.2 列 `.tex` 檔不用 `-execdir`，對應 Requirement「Derive and draft build an outline without inventing content」與第 2 列。完成時：指令先列檔、再逐一問 git。驗證：`PATH` 開頭是空項目、結尾是 `.` 兩種情況下清單照常產生，repo 目錄裡名叫 `git` 的程式沒有被執行；把 `find` 換成 bfs 時清單相同。

## 2. 其餘的指令

- [ ] 2.1 第一段指令，對應 Requirement「The outline is three files beside the ledger」「Text from the manuscript and the author never becomes part of a command」與第 11 列，以及沒有被追認的「超過兩層 submodule 時停下」。完成時：開頭清掉 `TOOLS` 與 `ROOT`；submodule 不設層數上限；往上找的途中 git 失敗時印 `STOP`。驗證：環境裡有 `TOOLS=1` 而沒有 jq 時不印 `ROOT=`；環境裡有 `ROOT` 而目錄不在 git repo 時不建暫存目錄；三層 submodule 得到最外層的根目錄。
- [ ] 2.2 列帳冊，對應 Requirement「The outline is three files beside the ledger」與第 8、15、17 列。完成時：只讀清單裡的 `_meta.json`；字元檢查只看根目錄以下的那一段（列帳冊、列綱要檔、守門、列 `.tex` 檔四處）。驗證：路徑含排除字元的 `_meta.json` 沒有被開啟；repo 放在名稱含 U+202E 的目錄底下時帳冊、綱要目錄與 `.tex` 檔照常列出；被 git 忽略的目錄裡的帳冊照常列出並比對。
- [ ] 2.3 忽略的檔與檔名，對應 Requirement「A locator names a passage by a label or by its opening words」與第 4、14 列。完成時：主稿件、來源指標的檔、被引入的 `.tex` 都另外在根目錄問最外層的 repo 是否忽略；主稿件與來源指標的檔，最後一段取目錄裡實際的名稱；帳冊與稿件以「是不是同一個檔」比較。驗證：外層忽略的目錄裡的獨立 repo，檔案不讀、不進 checker 的清單，沒被忽略的目錄裡的照常；在不分大小寫的檔案系統上，打成另一種大小寫的稿件與來源指標的檔被接受，印出與交給 checker 的是磁碟上的名稱，GNU 與內建的 `realpath` 結果相同。
- [ ] 2.4 差異指令的 `added` 行，對應 Requirement「Only the author's explicit statement in the current message approves」與第 21 列。完成時：最後一次整份確認沒有的節各印一行 `added`；確認第 4 步在展示全部的節時完整展示這些節。驗證：整份確認記下刪節之後把那一節原樣加回來，狀態報它照通過時的內容，差異指令印 `added`；沒有整份確認時不印。

## 3. 句子與規則

- [ ] 3.1 三項保證與八項已知限制，對應 Requirement「The outline skill writes only the three outline files」「The explanatory document describes the outline」與第 2、3、16、24 列。完成時：SKILL.md、OUTLINE.md 與規格都列出三項保證與同一份八項的封閉清單，每一項寫明可能破壞哪一項保證；三份文字裡不再有「repo 裡的同名程式絕不會被執行」這類超出保證的句子；`pwd` 與 git 2.38 的代價寫明。驗證：三份清單逐項相同。
- [ ] 3.2 反推、修改、起草與錯誤的去路，對應 Requirement「Derive and draft build an outline without inventing content」「Revising keeps ids stable and never loses a source」「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」「The outline is three files beside the ledger」與第 5、9、12、13、22 列。完成時：沒讀的被引入檔留一筆 `carry` 加 `pending` 的紀錄；搬走最後一個要點有兩種合規的結果（有來源、沒有來源各一）；稿件將放的目錄還不存在時用最近的上層目錄；狀態與確認的三條錯誤去路各有走得通的處置；Scenario「Neither a ledger nor an outline exists yet」補上「請求沒有指定目錄」。驗證：節檔有一行是數字時，狀態沒有 `ok status`、寫入檢查指出那一行；段落檔不見時 jq 指名它、狀態不建檔；「展示了哪些節」的紀錄不見時不追加、jq 指名那個檔。
- [ ] 3.3 [P] checker 的定義、Swift 規則、README 與 `CLAUDE.md`，對應 Requirement「A premise check runs before an outline is shown for approval」與第 6、10、17 列。完成時：checker 的定義寫明 `label` 決定；Swift 規則〈例外〉第 4 類的工作清單涵蓋 19 段指令；plugin 的 README 把「不讀 git 忽略的檔」限於來源；兩份 README 與 `CLAUDE.md` 寫明 git 2.38。驗證：清單對 19 段指令的名稱逐段對過；`git diff main` 對 Swift 規則〈不適用〉第 1 類沒有差異。
- [ ] 3.4 fix4 封存的 tasks，對應第 7 列。完成時：`openspec/changes/archive/2026-11-17-idd-75-fix4/tasks.md` 的 4.3、4.4 取消勾選，註明當時實際做到哪裡，並指到這個 change 的 4.2、4.4；完成條件的字句不改。驗證：封存檢查與連結檢查仍然通過。

## 4. 驗證

- [ ] 4.1 SKILL.md 的 19 段指令照寫法逐段實跑，八種組合：zsh 與 bash，各配 Homebrew 的 jq、系統內建的 jq、GNU coreutils 在 `PATH` 最前面、`find` 換成 bfs。完成時：八種組合的項數相同、全部符合預期，記下項數與對的 commit；新加的檢查在 `cb5efd2` 的 SKILL.md 上失敗的項數記在這裡。
- [ ] 4.2 指令凍結之後，獨立 agent 實跑找會出錯的輸入。任務書帶三項保證、八項已知限制與分類規則：破壞三項保證、或相對 `997d3d0` 的功能退步才算重現；落在已知限制裡的記進清單、不算重現。完成時：最後一輪這兩類的重現是 0，而且那一輪之後指令沒有再改；每一輪對的 commit、實跑次數、重現數記在這裡。做不到時不勾，照實寫停在哪裡。
- [ ] 4.3 文字與規格凍結之後，獨立 agent 逐句對照規格、OUTLINE.md 與 SKILL.md 的指令。完成時：找到的不一致都處理，記下對的 commit；處理後若又改了指令或規格的行為，重做。
- [ ] 4.4 獨立讀者只拿最後的 OUTLINE.md 作答，題組加上這一輪改過的規則。完成時：記下讀的 commit、題數、與預存答案不同的題；不同的逐題處理。處理時若改了 OUTLINE.md，改到的題由另一位讀者重答；記下最後還有幾題不同。
- [ ] 4.5 全套 pytest 通過；spectra validate 與 spectra analyze 沒有錯誤；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。
- [ ] 4.6 issue 上的紀錄，對應第 10、20 列。完成時：#78 的正文與第一輪 Follow-up 留言裡「其餘」的清單與 Swift 規則的 14 項一致；逐段實跑的案例表（每一項的指令段、情境與預期）貼在 #78，不含本機路徑。
