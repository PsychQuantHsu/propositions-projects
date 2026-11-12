## 1. 守衛測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛，對應 Requirement「A guard checks the table」「A check is named only when it is implemented」：釘住 `dependence.cites-backward` 的 `unit` 與 `applies`，加一個把 `cites` 改成 `absent` 的拒絕案例；新增兩組案例，餵守衛不是對照表的檔與型別不對的值，確認它回報問題而不是出錯（測試帶標記 `spec-example: article-obligations / a table that is not a mapping`）。驗證：用上一個 commit 的守衛跑同樣的輸入，四種會出錯、適用條件被改掉不會被擋下。
- [x] 1.2 同一個檔案，對應 Requirement「The explanatory document describes the table without restating it」：拿掉對照表的檢查與它的常數；說明文件要寫出的 issue 加上 `#50`、`#71`；新增對 `plugins/propositions/docs/VERIFICATION.md` 的檢查（三個關鍵字句），測試帶標記 `spec-example: article-obligations / a verification document without the pointer`；檔頭的退場條件補上第二個條件。驗證：改文件之前 `pytest tests/test_plugin_payload_tracked.py -k obligations` 失敗，訊息指出文件沒有 `#71`。

## 2. 義務表

- [x] 2.1 改 `plugins/propositions/catalog/obligations.yaml`：`unconstrained` 裡 `abstract` 的說明不再寫發現算在哪一列。列數與各列的欄位不變。驗證：守衛通過，表仍是 67 列。

## 3. 文件

- [x] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Each entry has one of four outcomes for a unit」「Each entry states how it is verified」：四種結果改成定義的表；新增「What the table decides by itself」三條；拿掉發現的層級表、「Which entry a finding counts for」「Which unit a finding counts for」兩節與五條結果規則；`on_warning` 兩個值改成不靠結果規則的說法；寫明哪些規則歸 #71。驗證：文件裡找不到「rule 4」與對照表的標題。
- [x] 3.2 同一個檔案，對應 Requirement「An article is sound only when every applicable entry passes」「Applicability is a list of field values」：開頭的說明；一筆命題有兩筆附檔紀錄時讀不出來；disagreement 警告的排除理由；報告列出什麼；過不了的四個原因與指向 #71 的一句；default 帳冊與外部文獻的限制（#50）；「怎麼改表」對守衛釘了哪些列的說法。驗證：1.2 的文件案例通過。
- [x] 3.3 改 `plugins/propositions/docs/VERIFICATION.md` 指到義務表文件的兩段，不自己下規則。驗證：1.2 的案例通過；`pytest tests/test_verification_records.py` 通過。

## 4. 獨立讀者盲驗

- [ ] 4.1 題目換成留在這個 capability 的部分：規格的十五個範例情況，加上完全合理、缺口、哪些規則不在這份文件裡，答案先存檔；派新的讀者，只給表、文件與題目。把題目、答案、相同的題數與對應的 commit 貼成 #47 上一則新的留言；不覆寫修正輪 3 的盲驗紀錄，#71 指到那一則。驗證：全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 5. 驗收

- [ ] 5.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix4` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出三項的輸出。
