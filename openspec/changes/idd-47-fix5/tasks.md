## 1. 守衛測試（先寫，要看到失敗）

- [ ] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛，對應 Requirement「Each entry states how it is verified」：帶 `external_source` 的列加上 `truth.cited-work-agrees`；釘住這一列是義務、缺口、負責人 50、沒有 `applies`，並加一個替它加上 `applies` 的拒絕案例。驗證：改表之前 `pytest tests/test_plugin_payload_tracked.py -k obligations` 失敗，訊息指名 `truth.cited-work-agrees`。
- [ ] 1.2 同一個檔案，對應 Requirement「A guard checks the table」：型別不對的五個案例只對格式檢查的結果下斷言，每一組字句先確認沒改動的小表不會命中（測試帶標記 `spec-example: article-obligations / a value of the wrong type`）。驗證：暫時讓守衛不再回報非字串的 `id`，這個案例失敗；還原後通過。暫時的改動不留在檔案裡。
- [ ] 1.3 同一個檔案，對應 Requirement「A guard checks the table」「The explanatory document describes the table without restating it」：文件的檢查改成整個詞比對（列編號、四種結果、issue 號），E8 到 E10 與 `owner` 改成檢查帶著那句話的字句；新增案例確認 `#210`、`E1-E8`、單獨的 owner 一字都不算數（測試帶標記 `spec-example: article-obligations / an issue number inside a longer one`）；兩處說明 `info` 的註解改成和規格一致的說法。驗證：新增的案例在改守衛之前失敗。

## 2. 義務表

- [ ] 2.1 改 `plugins/propositions/catalog/obligations.yaml`，對應 Requirement「Each entry states how it is verified」：加一列 `truth.cited-work-agrees`（義務、`truth` 組、單位是命題、沒有 `applies`、缺口、負責人 50、`proofread` 加 `cross_model`、`external_source: true`），上方的註解寫明它和 `truth.external-support-agrees` 在 empirical 帳冊裡會重疊、由 #50 決定；檔頭對 `on_warning` 的註解改成新的說法。其他列不動。驗證：1.1 的案例通過，表是 68 列。

## 3. 文件

- [ ] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Each entry has one of four outcomes for a unit」「Each entry states how it is verified」：四種結果的定義；規則要守住的七點；規則 2 是定義的結果，檢查印了什麼都一樣；`on_warning` 的兩個值與「警告」的意思；可以是 `info` 的四列在判準不成立時也能通過；拿掉「錯誤是說判準被違反」與像是對照規則的那一段。驗證：文件裡找不到「An error says that the criterion is violated」。
- [ ] 3.2 同一個檔案，對應 Requirement「Applicability is a list of field values」「A check is named only when it is implemented」「An article is sound only when every applicable entry passes」：五個鍵各自讀不出來的情形（封閉列舉）；結構驗證器怎麼算未退役；`relation`、`profile` 鍵、L5 三處理由；行號更新試跑的排除理由；要查外部來源的四列與新列為什麼沒有 `applies`；報告怎麼指名沒有自己的 id 的命題；拿掉 default 帳冊與外部文獻的限制；「怎麼改表」的列數。驗證：1.3 的文件案例通過。
- [ ] 3.3 改 `plugins/propositions/docs/VERIFICATION.md` 指到義務表文件的那一段：寫「今天沒有紀錄能讓一列通過」，拿掉實證閱讀的紀錄代表什麼那一句。驗證：`pytest tests/test_plugin_payload_tracked.py -k obligations` 與 `pytest tests/test_verification_records.py` 通過。
- [ ] 3.4 改 `.claude/rules/swift-is-the-implementation-language.md` 例外第 3 類列的詞彙，補上 `METHODS`。驗證：那一段列出四組詞彙。

## 4. 其他 issue

- [ ] 4.1 把這一輪交給 #71 的規則寫進 #71 的正文（`judge` 的警告判定前後怎麼算、哪一行輸出算在 `info` 的列、報告要不要另外列出 `refuted` 的紀錄），並在 Constraints 寫上這個 capability 定下的七點；在 #50 留 note 說明新的一列與它和既有一列的重疊。驗證：#71 的正文找得到這三件事；#50 有那則 note。

## 5. 獨立讀者盲驗

- [ ] 5.1 題目用規格的二十二個範例情況，其中包含第五輪的七個見證；允許回答「這份文件判不出來，歸 #71」。答案先存檔；派新的讀者，只給表、文件與題目。把題目、答案、相同的題數與對應的 commit 貼成 #47 上一則新的留言，不覆寫先前的盲驗紀錄。驗證：全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 6. 驗收

- [ ] 6.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix5` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出三項的輸出。
