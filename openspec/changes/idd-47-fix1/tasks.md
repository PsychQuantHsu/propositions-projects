## 1. 守衛測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛，對應 Requirement「A check is named only when it is implemented」「Applicability is a list of field values」「Entries are preconditions or obligations」「Each entry states how it is verified」「The obligations table is a closed data file」：清單加上 `ledger:profile`（共 45 條）；`proofread:E1` 到 `proofread:E7` 與 `owner` 是 57 的列，`applies` 必須剛好是 `profile: [empirical]` 加 `evidence_class` 的四個值，只有 `profile` 的會被拒絕；`owner` 是 57 的列必須剛好是 `consistency.variable-roles`、`truth.composite-holds-per-component`、`support.exposures-separable`；`truth.not-refuted` 必須是缺口、`owner` 是 62；`index.structure-faithful` 必須是前提、缺口、`owner` 是 66；必要的 owner 加上 66。驗證：改表之前 `pytest tests/test_plugin_payload_tracked.py -k obligations` 有失敗，訊息指名是哪一列。
- [x] 1.2 同一個檔案：讀表的地方改用會拒絕重複鍵的載入方式，並加一個案例，對應 Requirement「A guard checks the table」的 Example「an entry with the same key twice」：餵它一段某一列有兩行 `check:` 的文字，載入要失敗、訊息指名 `check`。測試帶標記 `spec-example: article-obligations / an entry with the same key twice`。驗證：案例在改載入方式之前失敗、之後通過。
- [x] 1.3 同一個檔案：說明文件的守衛加上 `#63` 與 `#66`，並要求文件寫出 `suspicious`、`--partial`、`evidence_snapshot` 這三個字（對應 Requirement「The explanatory document describes the table without restating it」新增的項目，以及 Requirement「Each entry has one of four outcomes for a unit」與「An article is sound only when every applicable entry passes」要文件寫明的事）。驗證：改文件之前這個案例失敗。

## 2. 義務表

- [x] 2.1 改 `plugins/propositions/catalog/obligations.yaml`：新增 `index.profile-valid`（`ledger:profile`，整篇）與缺口 `index.structure-faithful`（前提，`owner` 66）；實證層十列的 `applies` 加上 `evidence_class` 的四個值；改寫十列的判準（`dependence.symbols-introduced`、`truth.not-refuted`、`completeness.thesis-stated`、`index.retired-text-absent`、`index.commitments-well-formed`、`index.location-anchored`、`index.records-well-formed`、`index.extraction-covers-text`、`audit:R3` 的兩列）；`unconstrained` 拿掉現在被點名的四個 `evidence_class` 值。驗證：`pytest tests/test_plugin_payload_tracked.py -k obligations` 除了文件的案例之外全部通過。

## 3. 文件

- [x] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`：單位（退役區塊格式錯的命題算單位）、適用條件（`cites`、整篇的 `profile`、實證層、數字只在實證帳冊查）、已實作的檢查與排除清單、缺口列的欄位是暫定的、哪幾列要靠外部來源、什麼算發現與算哪個單位、沒跑過的七種情況、紀錄什麼時候算數與涵蓋什麼、過不了的原因加上 #63。仍然最多引兩列當例子。驗證：1.3 的案例通過。
- [x] 3.2 改 `plugins/propositions/docs/VERIFICATION.md`：在 proofread 的 `supported` 那一段與 disagreement 那一段各加一句，說明實證閱讀的紀錄涵蓋的是 E 層、紀錄怎麼計入完全合理以 `docs/OBLIGATIONS.md` 為準、「最新一筆」只用於 disagreement 警告。不改紀錄的格式。驗證：`pytest tests/test_verification_records.py` 通過；文件裡找得到 `OBLIGATIONS.md`。
- [x] 3.3 改摘要：`plugins/propositions/README.md` 與 `CLAUDE.md` 那兩句寫成「對一個單位」與「通過或不適用」；`plugins/propositions/.claude-plugin/plugin.json` 的描述提到義務表。驗證：`pytest tests/test_marketplace_entries.py tests/test_plugin_payload_tracked.py` 通過。

## 4. 獨立讀者盲驗

- [ ] 4.1 先把答案存檔：規格的十九個範例情況、三個判定文章是否完全合理的 Scenario、R3 拆成兩列的一題，共二十三題。再派一個只讀得到資料檔、說明文件與題目的讀者。把題目、讀者的答案、相同的題數與對應的 commit 貼在 #47。有不同就改說明文件、派新的讀者重跑。驗證：二十三題全部相同，#47 有那則紀錄。

## 5. 其他 issue 上的紀錄

- [ ] 5.1 在 #50（三列缺口的欄位是暫定的、哪幾列要靠外部來源）、#55（判準改了；它若決定刪掉那條規則，缺口要換負責人）、#57（E6 是跨命題的層）、#61（那一列的欄位是暫定的）、#62（紀錄沒有記它判定的是哪個版本；`truth.not-refuted` 的判準改了；disagreement 警告算在它那一列）各留一則 note；#45 的子題清單加 #66。內文過隱私自審。驗證：五則 note 都貼出，#45 的 Children 有 #66。

## 6. 驗收

- [ ] 6.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；IDD 的 CI gate 對 head commit 通過；`spectra validate idd-47-fix1` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出四項的輸出。
