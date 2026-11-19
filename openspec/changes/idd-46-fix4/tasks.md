## 1. 對照

- [x] 1.1 `refresh-prop-locations.py` 的 `read_tex_lines`（行為不變，既有的 pytest 通過）；`ParityTests` 的數行測試載入它，對應 `umbrella-marketplace-layout` 的 Requirement「Plugins monorepo layout with a single tool implementation」。
- [x] 1.2 測試先改並看到失敗：`Location.parse` 照 `parse_location_v16`、主檔的前綴，對應 Requirement「Reading order comes from each proposition's location and the input tree」與「The check says what it could not read」。

## 2. 命令與發布腳本

- [x] 2.1 子命令的說明（測試先寫、看到失敗），對應 Requirement「The command states its interface」。
- [x] 2.2 發布腳本另外三道拒絕的測試與釘版，對應 Requirement「The binary is published only by the maintainer」。

## 3. 文件

- [x] 3.1 `ReadingOrder.swift` 的註解與規則檔。

## 4. 驗證

- [x] 4.1 `swift test` 全過；`pytest tests/` 通過；`spectra validate` 通過；連結檢查 `ok`。
