## 1. Package

- [x] 1.1 根目錄 `Package.swift`、四個 target、`.gitignore` 的 `.build/`，對應 Requirement「A Swift package holds the command-line tools」。完成時：`swift build` 產生 `propositions` 與 `tschema-check`；`tschema-check --version` 印版本。

## 2. 閱讀順序

- [x] 2.1 測試先寫（RED）：Requirement「Reading order comes from each proposition's location and the input tree」的三個 Example，各一個帶 `spec-example:` 標記的測試；另加循環、超過三層、絕對路徑、verbatim 裡的 `\input`、重複引入。
- [x] 2.2 `Location` 與 `ReadingOrder` 的實作（GREEN）。

## 3. 引用方向檢查

- [x] 3.1 測試先寫（RED）：Requirement「A citation of a later proposition is reported as a warning」的三個 Example 與「The check says what it could not read」的兩個 Example，各有帶標記的測試。
- [x] 3.2 `LedgerReader`、`CiteOrder` 的實作與 `propositions cite-order` 子命令（GREEN）；結束碼照 design 的表。

## 4. 殼層與文件

- [x] 4.1 `plugins/propositions/bin/propositions-wrapper.sh` 與 `scripts/release-signed.sh`，對應 Requirement「The binary is published only by the maintainer」。不執行發布。
- [x] 4.2 `CLAUDE.md`、`.claude/rules/swift-is-the-implementation-language.md`（現況、語言組成、既有檔不變）更新；本機 CI 的指令加上 `swift test`。

## 5. 驗證

- [x] 5.1 `swift test` 全過；`pytest tests/` 維持通過；`spectra validate` 通過。
