## 1. 擋下的三項

- [x] 1.1 寫入檢查依檔名分辨段落檔，對應 Requirement「The outline skill writes only the three outline files」與第二輪報告第 1 列。完成時：points 要是清單、每個要點要有 id 只查名稱以 outline-paragraphs.jsonl 結尾的檔；節的紀錄裡名為 points 的鍵不看；規格、說明文件與 skill 都寫明「points 是清單」與「節的紀錄的未定義鍵不看」。驗證：同一份壞檔以段落檔與節檔兩種名稱各跑一次，回報的列不同且都符合預期；帶 points 的節檔印出 ok。
- [x] 1.2 section 指不到任何一節的段落紀錄，對應 Requirement「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」「A paragraph record holds at least one point」與第 2 列。完成時：狀態多一行列出這種紀錄；只要有一筆，整份就不算照通過時的內容；確認的指令在給作者看的那一份有這種紀錄時不追加；approve 第 4 步先給作者看這些紀錄。驗證：加一筆 section 寫錯的紀錄，狀態列出它、確認不追加；改正之後確認追加、三個條件都通過。
- [x] 1.3 repo 是最外層的 repo，對應 Requirement「The outline is three files beside the ledger」與第 3 列。完成時：第一個指令用 git 往上找最多兩層 submodule；更多層時既不印 ROOT 也不印錯誤，skill 要作者指定；沒有登記成 submodule 的內層 repo 算它自己。驗證：兩層、一層、沒有 submodule、內層 repo、三層，五種佈局各跑一次第一個指令；submodule 裡與外層的帳冊都判定為指到這份稿件；submodule 裡稿件的來源指標解析得到，指到 submodule 的 .git 檔被擋下。

## 2. 維護者決定的兩項

- [x] 2.1 新增 plugins/propositions/agents/outline-checker.md，skill 改用它，對應 Requirement「A premise check runs before an outline is shown for approval」與第 8 列。完成時：定義的 tools 只有 Read，model 與 effort 寫明，不載入 CLAUDE.md；五種結果的定義從 skill 的 brief 搬進定義、字句不變；skill 只給它檔案路徑與要查的節；啟動不了就停下。驗證：定義的五種與規格的前五種逐字比對；pytest 的 plugin 內容追蹤檢查涵蓋新檔；在只載入這個 plugin 的 Claude Code 裡實際啟動一次，清單上的工具只有 Read，對測試綱要的回報符合預期。
- [x] 2.2 Swift 規則加〈例外〉第 4 類，對應第 9 列。完成時：指名這份 SKILL.md 的 jq 程式與串接的檢查列，寫明可做與不可做、怎麼加入清單、退場條件 #78；觸發過的實例表加一列。驗證：規則檔的「只有四類」與第 4 類的內容一致；第 4 類是指名的清單，不是性質。

## 3. 其餘的指令

- [x] 3.1 狀態、差異與使用中的 id 改用 slurpfile 讀確認紀錄檔，對應 Requirement「A section stands as approved while it equals its latest approved copy」「Revising keeps ids stable and never loses a source」與第 4、7、36 列。完成時：確認紀錄檔讀不到或不是 JSON 時三段指令都不印 ok；使用中的 id 一行一個，含 section、parent、uses 指著的 id。驗證：讀不到的確認紀錄檔讓三段都不印 ok；只剩 uses 與 parent 指著的 id 出現在清單裡。
- [x] 3.2 來源指標的指令，對應 Requirement「A locator names a passage by a label or by its opening words」「A premise check runs before an outline is shown for approval」與第 6、14、16 列。完成時：from、basis 不是清單時回報；.git 目錄底下的檔與 submodule 的 .git 檔不讀；label 的訊息寫「文字出現幾次」。驗證：物件、字串、空清單、null、數字五種寫法都被列出；.git/HEAD 不讀；註解裡的 label 讓次數變 2，大括號前有空白的 label 數到 0。
- [x] 3.3 開始、列檔與守門，對應 Requirement「Derive and draft build an outline without inventing content」「The outline skill writes only the three outline files」「Text from the manuscript and the author never becomes part of a command」與第 15、17、19、23、24、30 列。完成時：反推與起草在確認紀錄檔存在時也停下；列 .tex 與列帳冊都排除路徑含換行的檔；每次呼叫的開頭確認暫存目錄存在且在 repo 以外、綱要目錄不是一般檔案；第一個指令確認 git；列帳冊時每個 _meta.json 先印一行。驗證：Success Criteria 第一條列的對應情境逐一實跑。

## 4. 句子

- [x] 4.1 規格、說明文件與 skill 的句子，對應 Requirement「The explanatory document describes the outline」以及各列所屬的 Requirement，與第 5、10、11、12、18、25、26、27、28、29、32、36 列。完成時：目錄的比對是實際路徑；缺少的必填鍵只有作者的閱讀把關；原樣搬動區塊的要點是完整的句子；「去向」一句有反推沒有記 commit 的限制；skill 讀到的都是資料；空的段落檔只在作者給的綱要還沒有段落時；「另一份稿件」只在沒有帳冊指到這份稿件時；範例路徑從 repo 根目錄寫起；節的 label 不用在紀錄上；symbolic link 連最後一層都解析；拆開時每一筆新紀錄都帶一個原來的來源；摘要與規則一致。驗證：4.3 的對照表與 5.2 的逐列核對。
- [x] 4.2 [P] CLAUDE.md、README.md、plugins/propositions/README.md、plugins/propositions/rules/manuscript-jsonl-sync.md，對應第 20、21、36 列。完成時：CLAUDE.md 的硬規則與同步規則寫明說的是帳冊；相容性清單列出 git；兩個 README 說前提檢查的五種由只有 Read 的 agent 判斷，README 的目錄樹列出 agents。驗證：四個檔各自找得到改過的句子。
- [x] 4.3 規格對指令的對照表。完成時：一位獨立 agent 列出規格說會檢查或會擋下的每一件事對到的指令，以及指令做的每一項檢查對到的規格句子；兩個方向都沒有對不上的。驗證：對照表記到 #75 的 Implementation Complete（只寫結果與對不上的項，不貼稿件文字）。

## 5. 驗證

- [x] 5.1 SKILL.md 的 18 段指令照寫法逐段實跑，zsh 與 bash、Homebrew 的 jq 與系統內建的 jq，四種組合。完成時：四種組合都是 168 項全部符合預期。驗證：把跑了哪些情境、結果如何記到 #75，不含任何真實稿件的文字。
- [x] 5.2 一位獨立 agent 對照第二輪報告要處理的 31 列，逐列回報已處理與在哪一句。完成時：沒有一列回報為未處理；有的話先修再重跑。
- [x] 5.3 獨立讀者重讀最後的 OUTLINE.md，題目沿用第一輪修正的題組，加上這一輪改過的規則（submodule 的 repo、指不到節的段落、註解裡的 label、.git 底下的檔、節的紀錄帶 points、只剩確認紀錄檔、前提檢查的 agent）。完成時：答案與預存的答案全部相同；有不同就改文件、換新的讀者重跑。驗證：題數與結果記到 #75。
- [x] 5.4 全套 pytest 通過；spectra validate 與 spectra analyze 對這個 change 沒有錯誤；相對於 main，plugins/propositions/scripts、plugins/tschema-check 與 tests 三個目錄沒有變動。驗證：貼出三項的結果。
