## 1. 讀取

- [x] 1.1 嚴格的 JSON 讀取與值的比較，對應 Requirement「A section stands as approved while it equals its latest approved copy」的 Example「a section compared as a JSON value」。

## 2. 檢查

- [x] 2.1 格式檢查：section 紀錄（Example「section records the format check reports」）、段落紀錄（Example「paragraph records the format check reports」、「the order of the paragraph records」）、確認紀錄（Example「approval records the format check reports」）、通過的綱要（Example「an outline that passes the format check」）。
- [x] 2.2 狀態：Example「eight changes after an approval of the whole outline」、「sections approved one at a time」、「a section removed since its approval」。
- [x] 2.3 來源指標：Example「locators that name one place and locators that do not」。

## 3. 命令列

- [x] 3.1 三個子命令與結束碼，對應 Requirement「Commands check an outline mechanically」的 Example「a missing file and a wrong argument」、「an approvals file that cannot be read」，以及「The outline is three files beside the ledger」的 Example「the three files of an outline are read from one directory」。

## 4. 驗證

- [x] 4.1 `swift test`；新的 status 與 skill 的 status 指令在同一個目錄的輸出逐行相同；`spectra validate` 與 `pytest tests/` 通過。
