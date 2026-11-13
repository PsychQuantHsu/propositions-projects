## 1. 守衛測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛，對應 Requirement「A guard checks the table」：`entries` 是數字或布林時回報「entries is not a list」，不當掉；格式不對的檔那一組案例改成逐則訊息斷言。驗證：改守衛之前，兩個新案例以 `TypeError` 失敗。
- [x] 1.2 同一個檔案，對應 Requirement「A guard checks the table」：加一個掃描兩組拒絕案例的測試（沒改動的表不命中、改動後恰好一則訊息命中）；釘選缺口的斷言加上「gap owned by issue」，並加一個負責人被改掉的案例；兩句話的字句比對加上邊界，加一個 `E100` 的案例。驗證：`E100` 的案例在改守衛之前失敗；讓守衛不再回報「entries is not a list」時，格式不對的那個案例失敗。暫時的改動不留在檔案裡。

## 2. 義務表

- [x] 2.1 改 `plugins/propositions/catalog/obligations.yaml`，對應 Requirement「A check is named only when it is implemented」「Applicability is a list of field values」：`index.profile-valid` 的判準；加 `index.data-claims-carry-data-class`（缺口，#70）與 `index.abstract-opens-nothing`（`structure:S5`）；`abstract` 從 `unconstrained` 拿掉。驗證：守衛通過，表是 70 列（前提 36、義務 34），缺口 17 列。

## 3. 文件與規則

- [x] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Applicability is a list of field values」「An article is sound only when every applicable entry passes」：`opens` 的 `id` 與 `kind`；id 可用的三個條件；無從判斷的條件當成不成立；資料主張的類別現在有一列；default 帳冊的數字寫成範圍；退役那一列管什麼；清點涵蓋哪四組詞彙；`ledger:profile` 檢查的是什麼；`SCHEMA.md` 對兩個欄位的規定。驗證：文件裡找不到「could be called」；守衛通過。
- [x] 3.2 改 `.claude/rules/swift-is-the-implementation-language.md` 例外第 3 類對三個字句的描述。驗證：那一句寫明一個指到義務表文件、兩個限縮它自己的說法。

## 4. 其他 issue

- [x] 4.1 #70 的正文補上「建立在資料上的命題帶的是資料類別」這條檢查與表裡對應的列；#48 的 note 把列數改成現在的數目；#50 補一則 note 交代外部依據兩列的鍵由它決定、default 帳冊缺欄位的命題在這兩列是沒檢查，並更正第四輪那一句。驗證：三處都找得到。

## 5. 獨立讀者盲驗

- [ ] 5.1 題目沿用修正輪 5 的 40 題，加上這一輪改到的情形（`opens` 的 `id` 不被接受、id 是 `null`、帳冊有一行壞掉、兩列新列）。答案先存檔；派新的讀者，只給表、文件與題目。紀錄貼成 #47 上一則新的留言。驗證：全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 6. 驗收

- [ ] 6.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix6` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出三項的輸出。
