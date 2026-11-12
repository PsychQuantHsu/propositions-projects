## 1. 守衛測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛，對應 Requirement「A guard checks the table」：`applies` 與 `axiom` 明寫成沒有值時拒絕，各加一個拒絕的案例；說明文件的檢查加上對照表的涵蓋範圍（「Which entry a finding counts for」那一節的表，列出的檢查要剛好是有好幾列的檢查），在既有的文件案例裡加三種情況；文件要寫出的字改成 `suspicious`、`--partial`、`external_source`。驗證：改文件之前 `pytest tests/test_plugin_payload_tracked.py -k obligations` 失敗，訊息指出文件沒有 `--partial`、沒有對照表那一節。

## 2. 義務表

- [x] 2.1 改 `plugins/propositions/catalog/obligations.yaml`，對應 Requirement「Entries are preconditions or obligations」：`completeness.thesis-stated` 的判準改成「The article states its thesis.」；檔頭對 `on_warning` 的說明改成「單位能通過之後，警告會怎樣」。驗證：守衛除了文件的案例之外全部通過。

## 3. 文件與規則檔

- [x] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Each entry has one of four outcomes for a unit」：五條規則不給出通過；新增「Why nothing passes yet」一節取代「What a report has to show」與紀錄的兩節；新增「Which entry a finding counts for」（六條檢查的對照表）與「Which unit a finding counts for」；發現的層級加上 `--partial` 的資訊行；`on_warning` 兩個值改成「單位能通過之後」的說法。驗證：1.1 的案例通過；文件裡找不到「lists the unit」。
- [x] 3.2 同一個檔案，對應 Requirement「Applicability is a list of field values」「Entries are preconditions or obligations」「An article is sound only when every applicable entry passes」：`cites` 與 `opens` 讀不出來的情形、`relation` 為什麼不是鍵、L5 那一句、判準對它沒有要求的單位、主旨那一列與 `audit:R3` 兩列的類別、完全合理的單位包含整篇、過不了的原因的說法、「怎麼改表」補上規格與守衛釘住的東西、覆蓋檢查那一句。驗證：`pytest tests/test_plugin_payload_tracked.py` 通過。
- [x] 3.3 改 `.claude/rules/swift-is-the-implementation-language.md`，對應 Requirement「A guard checks the table」：第 3 類例外改成指名的封閉清單，只列義務表這一組；加別的要另加一列並由維護者決定。驗證：第 3 類寫「這是封閉清單，目前只有一組」。

## 4. 獨立讀者盲驗

- [ ] 4.1 題目改成規格的二十四個範例情況加五題（一筆沒檢查就不合理、`lean` 的 `refuted`、前提沒通過、今天有沒有文章能通過、R3 的警告在兩列），共二十九題，答案先存檔；派新的讀者，只給表、文件與題目。把題目、答案、相同的題數與對應的 commit 更新到 #47 的盲驗紀錄。驗證：二十九題全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 5. 驗收

- [ ] 5.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix3` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出三項的輸出。
