## 1. 回歸測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_structure_links.py` 加測試，釘住 `plugins/propositions/skills/construct/SKILL.md` 的 Next mode 段落：不再有 does not read 那一句；有讀取最後一句 move 的 `structure-links.py` sentence 查詢與 `--kind next` 的 catalog 查詢，且 catalog 那一行不帶 `--type`、`--label`（對應 design「查全部稿件，不加類型或標籤過濾」）；候選清單有 **Does** 一項；段落寫明依 `to` 加總、`END` 算一個走法、提示不改候選順序（對應 design「提示依下一步的 move 加總，不看列」「END 算一個走法」「提示不改候選的順序與掛點」）。驗證：`pytest tests/test_structure_links.py -k next_mode` 在改 skill 之前失敗，失敗原因是段落內容不符。
- [x] 1.2 在 `tests/test_structure_links.py` 加測試，對應 Requirement「Next mode completes without a hint」：`structure-links.py` sentence 讀帶 `head: "pending"` 的草稿最後一句時 exit 0 並回報 move；最後一句沒有標註時 `move` 是 null；catalog 在 `--catalog` 指向不存在的檔案時 exit 2；`structure-state.py` 的輸出與 `links.csv` 存不存在無關。驗證：這些測試守住現有行為，用暫時改壞輸入的方式確認它們會失敗後再還原。

## 2. Next mode 的 skill 內容

- [x] 2.1 實作 Requirement「Next mode takes a move hint from the link catalog」：在 `plugins/propositions/skills/construct/SKILL.md` 拿掉 Next mode 開頭的 does not read 句子，在 N3 之後新增 N4 — Read the move hint，原本的 N4、N5 順延為 N5、N6。新步驟用 N2 回報的 `position` 跑 sentence 查詢取得 `move`，再跑 catalog 查詢，依 `to` 加總、同分保留清單順序、`END` 算一個走法，回報前三個並說明是觀察到的走法，不是規則；寫明三種略過條件與「用一行說明後照常完成」。驗證：1.1 的測試通過；`structure-links.py` 與其他 Python 檔案沒有變動（`git diff --stat -- plugins/propositions/scripts` 為空）。
- [x] 2.2 實作修改後的 Requirement「Next mode proposes at most three candidates without writing」：N5 的候選清單新增 **Does**，寫明它是 `catalog/vocabulary.yaml` 的值，沒有合適的值時寫 `none fits` 並說明這一句要做什麼（對應 design「候選的 move 是詞彙裡的值，或寫 none fits」）；既有的第一個候選規則與 N6 的檔案指紋不動；關係仍照原方式決定，不取自 catalog 的列。驗證：1.1 的測試通過，並人工對照 spec 的情境逐條讀過一次。
- [x] 2.3 依獨立讀者的審查補齊提示的邊界：不足三個值時有幾個報幾個；`END` 不是 `move`，不寫進 **Does**，開新段的候選不受提示限制；catalog 查詢改用 `--format json`；`position` 寫明是 N2 輸出的頂層欄位。驗證：`pytest tests/test_structure_links.py -k next_mode` 在改之前失敗、改之後通過；delta spec 與 design 同步更新。

## 3. 文件與版本

- [x] 3.1 [P] 在 `plugins/propositions/docs/STRUCTURE.md`、`plugins/propositions/README.md`、`CLAUDE.md` 寫明 next 模式會參考連結清單提示 `move`，提示不是規則，也不改候選順序。驗證：三個檔案都提到這件事，且沒有任何文件還說 next 模式不讀 `links.csv`（搜尋 `links.csv` 與 next 模式逐筆確認）。
- [x] 3.2 [P] 在 `docs/REFERENCE-MANUSCRIPTS.md` 記下 #36 的量測：依位置狀態分組的命中率、跨稿件命中率、量法與限制（兩篇稿件；這兩個表由一次性量測得出，工具不重現）；不放稿件文字。驗證：表內數字與 #36 的 Note 逐格相同。
- [x] 3.3 [P] 把 `propositions` plugin 升到 0.9.0（`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json`）。驗證：`pytest tests/test_marketplace_entries.py` 通過，兩處版本相同。

## 4. 驗收

- [x] 4.1 實跑驗收：用截短的草稿讓 subagent 只讀 Next mode 段落並產出候選，三種情形各一份：結尾是帶 `pending` 的句子、結尾沒有等頭的子句、結尾沒有 `move`。逐項檢查：每個候選都有 **Does**；前三個是依 `to` 加總的結果；第一個候選的規則沒變；沒有 `move` 時略過提示並說明；檔案指紋前後相同。驗證：把結果記到 #36，不含稿件文字；有不符就修 skill 再跑。
- [x] 4.2 全套 `pytest tests/` 通過、`idd-ci-gate.sh` 對 head commit 通過、`spectra validate add-next-mode-move-hint` 通過，且 `git diff --stat main -- plugins/propositions/scripts` 為空。驗證：貼出三者的輸出。
