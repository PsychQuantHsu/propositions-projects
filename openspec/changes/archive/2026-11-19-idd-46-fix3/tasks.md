## 1. 讀 LaTeX

- [x] 1.1 測試先寫並看到失敗（3 項）：加星號的環境、換行後的 input、加星號的引入巨集，對應 Requirement「Reading order comes from each proposition's location and the input tree」。
- [x] 1.2 `ReadingOrder.swift`：指令的邊界、環境的完整名稱。

## 2. 測試

- [x] 2.1 `ReleaseScriptTests`，對應 Requirement「The binary is published only by the maintainer」的三個新 Example。
- [x] 2.2 `ParityTests`，對應 `umbrella-marketplace-layout` 的 Requirement「Plugins monorepo layout with a single tool implementation」的三個新 Example。
- [x] 2.3 `[warn]` 行與不帶子命令，對應 Requirement「The command states its interface」。

## 3. 文件

- [x] 3.1 `docs/RELEASE-FLOW.md` 的閘門、`CLAUDE.md`、規則檔的檔案數與那一列。

## 4. 驗證

- [x] 4.1 `swift test` 全過；`pytest tests/` 通過；`spectra validate` 通過；連結檢查 `ok`。
