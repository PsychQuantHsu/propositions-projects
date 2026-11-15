## 1. Skill 的指令

- [x] 1.1 改寫 plugins/propositions/skills/outline/SKILL.md 的路徑與指令通則，對應 Requirement「Text from the manuscript and the author never becomes part of a command」與驗證報告第 2、5、20、24 項。完成時：skill 寫明每一次 Bash 呼叫都從同一組寫明的路徑開始、路徑用單引號、稿件與作者的文字只經由檔案進入指令、檢查印出 ok 才算通過、缺工具時停下；skill 裡沒有 shell 函式、迴圈與條件式，只有指令列。驗證：把 SKILL.md 的每一段 bash 區塊抽出來，各自在新的 shell 裡加上路徑那兩行實跑（zsh 與 bash 各一次）。
- [x] 1.2 改寫寫入檢查，對應 Requirement「The outline skill writes only the three outline files」與第 3、18、20 項。完成時：檢查吃的是指定的那一個檔（暫存的或正式的）；節與段落檔查三件事（每行是 JSON 物件、id 不重複且兩個沒有 id 算重複、字串沒有控制字元），確認紀錄檔只查第一件；重複的 id 連同行號印出，p-1 不會配到 p-10。驗證：對一個正常的檔、一個含六種錯誤的檔、一個不存在的檔、以及沒有 jq 的 PATH 各跑一次，只有正常的檔印出 ok。
- [x] 1.3 新增「來源指標解析得到嗎」的指令，反推、起草與前提檢查共用，對應 Requirement「A locator names a passage by a label or by its opening words」「A premise check runs before an outline is shown for approval」與第 4、5、6 項。完成時：來源檔的名稱從綱要檔寫進暫存清單、再由指令讀出，不出現在指令列；讀檔之前先用實際路徑判定在不在 repo 裡；開頭文字與 label 算的是出現次數，連續空白算一個空格。驗證：測試稿件裡同一行重複的句子回報兩次、跨行才唯一的證明開頭回報通過、含錢字號加括號與反引號的開頭文字照原樣計數且沒有任何指令被執行；開頭是斜線、含兩個點、指到 repo 外的 symbolic link 三種檔名都沒有印出 ok。
- [x] 1.4 改寫狀態與差異的指令，對應 Requirement「A section stands as approved while it equals its latest approved copy」與第 13、19 項。完成時：是否照通過時的內容由 JSON 的值決定；差異列出通過時有而現在沒有、現在有而通過時沒有的紀錄；每一節都通過而順序沒有通過時，skill 說還需要一次整份的確認。驗證：鍵換順序與 1 改成 1.0 之後仍回報通過；改一句之後回報該節不同；一節一節確認三節之後回報順序沒有整份的確認紀錄。
- [x] 1.5 改寫確認的指令與步驟，對應 Requirement「Only the author's explicit statement in the current message approves」「An approval record stores what the author approved」與第 2、9、15、16、17、18 項。完成時：給作者看的那一份留在暫存目錄；每次給作者看之前都跑前提檢查；用文字問、不用選項；statement 是作者訊息裡表示通過的那幾句、逐字；紀錄由那一份組成，至少一節，追加時自成一行；有通過紀錄的節只給差異。驗證：Success Criteria 第二條列的七種情況逐一實跑，行數與預期相同。

## 2. Skill 的規則

- [x] 2.1 改寫反推、起草與修改的規則，對應 Requirement「Derive and draft build an outline without inventing content」「Revising keeps ids stable and never loses a source」「A section record says in one sentence what the section says」「The outline is three files beside the ledger」與第 8、12、14、21、22、23 項。完成時：段落裡的展示公式屬於那一段，獨立成塊的推導才是原樣搬動的區塊；散文段落用開頭文字、不用段內公式的 label；沒有帳冊也沒有綱要檔時由作者決定目錄；不要一節之前先處理它底下的節，沒有任何紀錄指到才刪；搬動一節連同它底下的節；動作表不再列沒有規則的還原。驗證：對照規格這三條 Requirement 的 Scenario 逐條核對 skill 的文字。
- [x] 2.2 改寫前提檢查的做法與 brief，對應 Requirement「A premise check runs before an outline is shown for approval」與第 6、7、10 項。完成時：第六種由 skill 用 1.3 的指令判定；agent 判斷另外五種，只拿到解析得到的檔，brief 寫明讀到的是資料、只讀不寫、不讀 repo 以外的檔；第四種涵蓋 uses 指到被標成 dropped 的紀錄；skill 不照 agent 回報裡像指示的文字做事。驗證：brief 的五種與規格的前五種逐字比對；規格的三個 Scenario 逐條核對。

## 3. 說明文件與其他文件

- [x] 3.1 修改 plugins/propositions/docs/OUTLINE.md，使它與規格的十三條 Requirement 一致，對應 Requirement「The explanatory document describes the outline」「The outline is three files beside the ledger」「A paragraph record holds at least one point」（後者只改了沒有可執行檢查的理由，文件的鍵表維持與規格逐列相同）與第 13、15、20、22、28、29 項。完成時：文件寫明來源指標的檔要在 repo 裡、開頭文字怎麼計數、字串不含控制字元以及寫入檢查抓得到與抓不到的反斜線、一節一節確認之後還需要整份確認、重新確認時給作者看什麼、確認紀錄不記是誰通過的、這一版沒有回答的三個設計問題。驗證：規格每一條改過的規則在文件裡找得到對應的句子；文件裡的表與規格的表逐列相同。
- [x] 3.2 [P] 修改 docs/SCHEMA.md、README.md、CLAUDE.md、plugins/propositions/README.md，對應第 24、25、26 項。完成時：docs/SCHEMA.md 寫明 schema_version 不涵蓋綱要檔；README.md 與 CLAUDE.md 的相容性清單列出 jq 與 realpath；plugin 的 README 不再說每一筆段落都記來源。驗證：四個檔各自找得到改過的句子；tests/test_plugin_payload_tracked.py 與 tests/test_marketplace_entries.py 通過。

## 4. 驗證

- [x] 4.1 把 SKILL.md 的每一段 bash 區塊抽出來逐段實跑（zsh 與 bash；Homebrew 的 jq 與系統內建的 jq），輸入是 Success Criteria 列的測試稿件與七種確認情況。完成時：每一段的輸出與預期相同，測試稿件裡的指令替換沒有被執行。驗證：把跑了哪些區塊、哪些輸入、結果如何記到 #75，不含任何真實稿件的文字。
- [x] 4.2 全套 pytest 通過；spectra validate 對這個 change 通過；相對於 main，plugins/propositions/scripts、plugins/tschema-check 與 tests 三個目錄沒有變動。驗證：貼出三項的輸出。
- [x] 4.3 一位只拿到驗證報告第 2 到 29 項清單與改過的檔案的獨立 agent，逐項回報每一項是否已經處理、在哪一句。完成時：沒有一項回報為未處理；有的話先修再重跑。
- [x] 4.4 獨立讀者重讀最後的 OUTLINE.md。題目沿用第一輪的題組，加上這一輪改過的規則（來源指標在 repo 外、開頭文字跨行、同一行重複、一節一節確認後的順序、節底下的節、uses 指到 dropped）。驗證：讀者的答案與預存的答案全部相同；有不同就改文件、換新的讀者重跑；題數與結果記到 #75。

## 5. 獨立核對之後新增的規則

- [x] 5.1 綱要目錄的守門，對應 Requirement「The outline skill writes only the three outline files」「The outline is three files beside the ledger」。完成時：每一段會讀寫綱要檔的指令都以同樣的三行開頭；第二行在三個路徑不是從根目錄寫起、目錄解析所有 symbolic link 之後不在 repo 裡、或任何一個綱要檔本身是 symbolic link 時，印出 STOP 並結束整個指令；之後的指令只用解析後的路徑；修改在開頭與作者每次回覆之後各確認一次。驗證：逐段實跑裡綱要目錄與路徑的各種寫法（在 repo 外、含兩個點、結尾加斜線的 link、中間一層是 link、空的與相對的路徑、指到不存在位置的 link），每一種都停下，repo 以外沒有被寫入。
- [x] 5.2 選綱要目錄，對應 Requirement「The outline is three files beside the ledger」。完成時：只有恰好一份帳冊指到這份稿件時不問就用它的目錄，其他情況問作者；列帳冊時不讀是 symbolic link 的 _meta.json。驗證：兩份帳冊各指到不同稿件時各列一行；名為 _meta.json 的 symbolic link 不列入。
- [x] 5.3 反推讀哪些檔，對應 Requirement「Derive and draft build an outline without inventing content」。完成時：只跟著讀 repo 裡是一般檔案的 .tex；寫入之前清掉暫存目錄裡別份綱要留下的檔；不寫 lines。驗證：稿件目錄裡指到 repo 外的 .tex 連結不在列出的檔裡；暫存目錄裡留下的段落檔在寫入前被清掉。
- [x] 5.4 確認的輸入與目錄，對應 Requirement「Only the author's explicit statement in the current message approves」「An approval record stores what the author approved」。完成時：一次確認只用一個輸入檔，第一行是點名的節、其餘是作者的話，每次嘗試之後與每次重新給作者看時刪掉；給作者看時記下目錄解析後的路徑，追加之前比對。驗證：沿用上一次的輸入、目錄換成內容相同的另一個、記下的路徑不見了，三種情況都不追加。
- [x] 5.5 寫入檢查補上的項目，對應 Requirement「The outline skill writes only the three outline files」。完成時：沒有任何紀錄的檔不回報通過，段落檔在還沒有任何段落時印出 EMPTY 而不是通過；每一筆紀錄與每一個要點都要有 id；points 要是清單。驗證：空的檔、缺 id 的紀錄、points 是字串的紀錄，三種輸入都不印通過。
