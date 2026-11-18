## 1. 出貨內容

- [x] 1.1 拿掉 `plugins/propositions/bin/`，對應 Requirement「The binary is published only by the maintainer」。完成時：沒有 plugin 目錄帶 `bin/`；規則檔與 `docs/RELEASE-FLOW.md` 寫明 wrapper 留到發布時決定。

## 2. 閱讀順序

- [x] 2.1 測試先寫並看到失敗（14 項）：Requirement「Reading order comes from each proposition's location and the input tree」新增的四個 Example 與主檔目錄之外的檔、空的引入名稱、舊前綴 `main.tex`。
- [x] 2.2 `ReadingOrder`、`Location` 的實作。

## 3. 檢查與命令

- [x] 3.1 測試先寫並看到編譯失敗：重複 id、`cites` 不是字串的清單、控制字元、結束碼三種、`--json` 的物件、兩個預設路徑、`tschema-check`，對應 Requirement「A citation of a later proposition is reported as a warning」「The check says what it could not read」「The command states its interface」「A Swift package holds the command-line tools」。
- [x] 3.2 `CommandRun.swift`（`CiteOrderRun`、`TschemaCheckPlaceholder`），`CiteOrder` 與 `LedgerReader` 的修正；executable 只印出與結束。

## 4. 發布腳本與文件

- [x] 4.1 `scripts/release-signed.sh`：先跑測試、確認 notarization、tag 的處理、release notes；`docs/RELEASE-FLOW.md` 的新一節，對應 `plugin-release-flow` 的 Requirement「Documented release procedure」。
- [x] 4.2 `CLAUDE.md`、Swift 規則檔（例外第 1、3、4 類的說法、語言組成）；`umbrella-marketplace-layout` 的兩條 requirement。

## 5. 驗證

- [x] 5.1 `swift test` 全過；`pytest tests/` 通過；`spectra validate` 通過；規格連結檢查 `ok`。
