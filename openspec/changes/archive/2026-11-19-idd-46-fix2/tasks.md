## 1. 對齊寫 location 的工具

- [x] 1.1 測試先寫並看到編譯失敗與失敗：行的切法、`main.tex:` 的意思、以 `/` 開頭的 `location`，對應 Requirement「Reading order comes from each proposition's location and the input tree」。
- [x] 1.2 `ReadingOrder`、`Location` 的實作。

## 2. 讀稿件與讀帳冊

- [x] 2.1 verbatim 類環境的追蹤與不追的引入巨集（同一條 Requirement 的三個新 Example）。
- [x] 2.2 `//` 行、`cites`、`retired`，對應 Requirement「A citation of a later proposition is reported as a warning」與「The check says what it could not read」。

## 3. 命令

- [x] 3.1 `PropositionsCLI`：參數解析在 library，對應 Requirement「A Swift package holds the command-line tools」與「The command states its interface」；`a wrong argument`、`the version`、`the defaults of the two paths` 三個 Example 的測試實際跑命令。

## 4. 規格的檢查與文件

- [x] 4.1 三個 repo 層級的測試：沒有 `bin/`、package 的位置、發布流程文件，對應三份規格各一條 Requirement。
- [x] 4.2 規則檔與 `docs/RELEASE-FLOW.md`。

## 5. 驗證

- [x] 5.1 `swift test` 全過；`pytest tests/` 通過；`spectra validate` 通過；連結檢查 `ok`；fixture 帳冊與 Python 的計算相同。
