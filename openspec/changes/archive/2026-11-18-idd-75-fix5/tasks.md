## 1. 擋下的兩項

- [x] 1.1 讀 repo 的 git 指令都帶兩個選項，對應 Requirement「Text from the manuscript and the author never becomes part of a command」與第五輪報告第 1 列。完成時：SKILL.md 裡每一個 `rev-parse`、`ls-files`、`check-ignore` 都帶 `-c safe.bareRepository=explicit -c core.fsmonitor=false`；第一段指令在 git 低於 2.38 時印 `missing` 行、不印 `ok tools`。驗證：提交偽裝成 repo 的目錄（`HEAD`、`objects/`、`refs/`、指名一段指令的 `config`），clone 之後跑第一段、主稿件檢查、帳冊比對、列 `.tex` 檔、逐檔計數，那段指令都沒有被執行，那些目錄裡的檔不被讀；linked worktree 與 bare repo 的 worktree 照常運作；回報 2.30 的 git 沒有 `ok tools`。
- [x] 1.2 列 `.tex` 檔不用 `-execdir`，對應 Requirement「Derive and draft build an outline without inventing content」與第 2 列。完成時：指令先列檔、再逐一問 git。驗證：`PATH` 開頭是空項目、結尾是 `.` 兩種情況下清單照常產生，repo 目錄裡名叫 `git` 的程式沒有被執行；把 `find` 換成 bfs 時清單相同。

## 2. 其餘的指令

- [x] 2.1 第一段指令，對應 Requirement「The outline is three files beside the ledger」「Text from the manuscript and the author never becomes part of a command」與第 11 列，以及沒有被追認的「超過兩層 submodule 時停下」。完成時：開頭清掉 `TOOLS` 與 `ROOT`；submodule 不設層數上限；往上找的途中 git 失敗時印 `STOP`。驗證：環境裡有 `TOOLS=1` 而沒有 jq 時不印 `ROOT=`；環境裡有 `ROOT` 而目錄不在 git repo 時不建暫存目錄；三層 submodule 得到最外層的根目錄。
- [x] 2.2 列帳冊，對應 Requirement「The outline is three files beside the ledger」與第 8、15、17 列。完成時：只讀清單裡的 `_meta.json`；字元檢查只看根目錄以下的那一段（列帳冊、列綱要檔、守門、列 `.tex` 檔四處）。驗證：路徑含排除字元的 `_meta.json` 沒有被開啟；repo 放在名稱含 U+202E 的目錄底下時帳冊、綱要目錄與 `.tex` 檔照常列出；被 git 忽略的目錄裡的帳冊照常列出並比對。
- [x] 2.3 忽略的檔與檔名，對應 Requirement「A locator names a passage by a label or by its opening words」與第 4、14 列。完成時：主稿件、來源指標的檔、被引入的 `.tex` 都另外在根目錄問最外層的 repo 是否忽略；主稿件與來源指標的檔，最後一段取目錄裡實際的名稱；帳冊與稿件以「是不是同一個檔」比較。驗證：外層忽略的目錄裡的獨立 repo，檔案不讀、不進 checker 的清單，沒被忽略的目錄裡的照常；在不分大小寫的檔案系統上，打成另一種大小寫的稿件與來源指標的檔被接受，目錄裡只有一個名稱指到它時，印出與交給 checker 的是磁碟上的名稱，GNU 與內建的 `realpath` 結果相同；已追蹤、在磁碟上只改了大小寫的檔算已追蹤，名稱用磁碟上的；新名稱被最外層的 repo 忽略的那一種停下；在區分大小寫的磁碟上，只差大小寫的已追蹤檔不替被忽略的檔作保。
- [x] 2.4 差異指令的 `added` 行，對應 Requirement「Only the author's explicit statement in the current message approves」與第 21 列。完成時：最後一次整份確認沒有的節各印一行 `added`；確認第 4 步在展示全部的節時完整展示這些節。驗證：整份確認記下刪節之後把那一節原樣加回來，狀態報它照通過時的內容，差異指令印 `added`；沒有整份確認時不印。

## 3. 句子與規則

- [x] 3.1 三項保證與八項已知限制，對應 Requirement「The outline skill writes only the three outline files」「The explanatory document describes the outline」與第 2、3、16、24 列。完成時：SKILL.md、OUTLINE.md 與規格都列出三項保證與同一份八項的封閉清單，每一項寫明可能破壞哪一項保證；三份文字裡不再有「repo 裡的同名程式絕不會被執行」這類超出保證的句子；`pwd` 與 git 2.38 的代價寫明。驗證：三份清單逐項相同。
- [x] 3.2 反推、修改、起草與錯誤的去路，對應 Requirement「Derive and draft build an outline without inventing content」「A paragraph record holds at least one point」「Revising keeps ids stable and never loses a source」「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」「The outline is three files beside the ledger」與第 5、9、12、13、22 列。完成時：沒讀的被引入檔留一筆 `carry` 加 `pending` 的紀錄；搬走最後一個要點有兩種合規的結果（有來源、沒有來源各一）；稿件將放的目錄還不存在時用最近的上層目錄；狀態與確認的三條錯誤去路各有走得通的處置；Scenario「Neither a ledger nor an outline exists yet」補上「請求沒有指定目錄」。驗證：節檔有一行是數字時，狀態沒有 `ok status`、寫入檢查指出那一行；段落檔不見時 jq 指名它、狀態不建檔；「展示了哪些節」的紀錄不見時不追加、jq 指名那個檔。
- [x] 3.3 [P] checker 的定義、Swift 規則、README 與 `CLAUDE.md`，對應 Requirement「A premise check runs before an outline is shown for approval」與第 6、10、17 列。完成時：checker 的定義寫明 `label` 決定；Swift 規則〈例外〉第 4 類的工作清單涵蓋 19 段指令；plugin 的 README 把「不讀 git 忽略的檔」限於來源；兩份 README 與 `CLAUDE.md` 寫明 git 2.38。驗證：清單對 19 段指令的名稱逐段對過；`git diff main` 對 Swift 規則〈不適用〉第 1 類沒有差異。
- [x] 3.4 fix4 封存的 tasks，對應第 7 列。完成時：`openspec/changes/archive/2026-11-17-idd-75-fix4/tasks.md` 的 4.3、4.4 取消勾選，註明當時實際做到哪裡，並指到這個 change 的 4.2、4.4；完成條件的字句不改。驗證：封存檢查與連結檢查仍然通過。

## 4. 驗證

- [x] 4.1 SKILL.md 的 19 段指令照寫法逐段實跑，八種組合：zsh 與 bash，各配 Homebrew 的 jq、系統內建的 jq、GNU coreutils 在 `PATH` 最前面、`find` 換成 bfs。完成時：八種組合的項數相同、全部符合預期，記下項數與對的 commit；新加的檢查在 `cb5efd2` 的 SKILL.md 上失敗的項數記在這裡。
  - 結果：`aa8a63d` 之後指令沒有再改（之後的 commit 只改文字）。八種組合都是 389 項全部符合預期；bfs 的兩種是 388 項（攔截 `find` 參數的那一項在那裡不適用）。389 項在 `cb5efd2` 的 SKILL.md 上有 32 項失敗（zsh、系統內建的 jq）。案例表貼在 #78（留言 6955346390）。
- [x] 4.2 指令凍結之後，獨立 agent 實跑找會出錯的輸入。任務書帶三項保證、八項已知限制與分類規則：破壞三項保證、或相對 `997d3d0` 的功能退步才算重現；落在已知限制裡的記進清單、不算重現。完成時：最後一輪這兩類的重現是 0，而且那一輪之後指令沒有再改；每一輪對的 commit、實跑次數、重現數記在這裡。做不到時不勾，照實寫停在哪裡。
  - 第一輪，對 `5ccf1b9`：兩位測試者，至少 6,603 與 19,613 次。重現 2 項：查檔名的 `find -samefile` 跑在「在不在 repo 裡」的判斷之前，會去列 repo 外的目錄；只在磁碟上改了大小寫的已追蹤檔被擋。修在 `4e5690a`。
  - 第二輪，對 `4e5690a`：一位測試者，10,998 次。重現 2 項，都出在第一輪之後加的「依大小寫補問」：目錄改了大小寫時路徑帶出 `..`；含引號或處於合併衝突的已追蹤檔名被擋。修在 `aa8a63d`：補問只看 git 的結束碼，不解析它印的名稱。
  - 第三輪，對 `aa8a63d`：一位測試者。隨機比對：不分大小寫的磁碟上八種組合各 1,264 次，區分大小寫的磁碟映像檔上八種組合各約 450 次（其中四種因映像檔滿了中途停下，由我清空後照它的腳本補跑完），合計約 13,700 次。`aa8a63d` 的錯誤只有兩個種子共四筆，都是文件寫明刻意擋下的那一種（已追蹤檔在磁碟上改了大小寫，新名稱被最外層的 repo 忽略），測試者的腳本也標了 `declared`。範圍外的重現是 0，之後指令沒有再改。這位測試者在交出書面報告之前隨 session 重啟結束；結果是我讀它的實跑紀錄與比對腳本得到的，它另外寫的九支針對性腳本沒有留下判定。
- [x] 4.3 文字與規格凍結之後，獨立 agent 逐句對照規格、OUTLINE.md 與 SKILL.md 的指令。完成時：找到的不一致都處理，記下對的 commit；處理後若又改了指令或規格的行為，重做。
  - 第一次，對 `5841544`：5 處（沒讀的被引入檔那筆紀錄與「只寫通過檔案說的」衝突、偽裝成 repo 的目錄、「git 答不出來」指哪個 repo、approve 少一個條件、相容性說明少了 `pwd`），改在 `4e5690a`。
  - 第二次，對 `0be4113`：5 處（偽裝目錄的說法太廣、大小寫規則少了前提、`pending` 的定義、檔名含特殊字元時 `from` 的處理、`STOP` 的原因），改在 `aa8a63d`。
  - 第三次，對 `beb4242`（`aa8a63d` 改過指令之後）：6 處（硬連結與 GNU `realpath` 時名稱不同、被拒絕的那一種只有最外層會拒、git 自己讀的設定、「整條路徑」不分大小寫、`file` 的用詞、tasks 2.3 的驗證條件），改在 `c6480af`，只改文字。
- [x] 4.4 獨立讀者只拿最後的 OUTLINE.md 作答，題組加上這一輪改過的規則。完成時：記下讀的 commit、題數、與預存答案不同的題；不同的逐題處理。處理時若改了 OUTLINE.md，改到的題由另一位讀者重答；記下最後還有幾題不同。
  - 第十九位讀者讀 `aa8a63d` 的 OUTLINE.md，213 題（加了 30 題這一輪的規則）：209 題與預存答案相同，4 題少答了一部分（G19、G45、H24、I18），沒有不同的；它標出第二項保證「不讀 repo 以外的檔」照字面也涵蓋 skill 自己的暫存檔（G55），句子在 `beb4242` 改了。第二十位讀者讀 `beb4242`，重答 7 題，全部相同。第三次對照之後 OUTLINE.md 又改了，第二十一位讀者讀 `c6480af`，重答受影響的 7 題，全部相同；它標出「keeps the name it was given」沒說是誰給的名稱（J28），句子在封存前的 commit 改明確。最後與預存答案不同的題是 0。
  - 2026-11-18 更正（第六輪驗證第 16 列）：上一句只對 `c6480af` 成立。`2bd462a` 依第二十一位讀者的意見改了 J28 那一句，之後沒有讀者重答 J28；補讀由 `idd-75-fix6` 的 3.3 做。
- [x] 4.5 全套 pytest 通過；spectra validate 與 spectra analyze 沒有錯誤；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。
  - `pytest tests/`：872 passed、3 skipped。`spectra validate` 通過；`spectra analyze` 沒有 warning。三個目錄相對於 main 沒有變動。
- [x] 4.6 issue 上的紀錄，對應第 10、20 列。完成時：#78 的正文與第一輪 Follow-up 留言裡「其餘」的清單與 Swift 規則的 14 項一致；逐段實跑的案例表（每一項的指令段、情境與預期）貼在 #78，不含本機路徑。
  - #78 的正文（`## Problem`）與留言 6848954746 已就地更正成 14 項；案例表與留給 #78 的八項已知限制貼在 #78 留言 6955346390。
