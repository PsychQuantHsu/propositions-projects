## Problem

#78 第一輪驗證（Codex）：7 項擋下、8 項要修、1 項後續。CRLF 的檔被讀成一行；指數很大的兩個不同數字被當成相同；不是 UTF-8 的位元組被換成 U+FFFD 後通過；`locators` 略過不是清單的 locator 欄位與不是物件的行；路徑與檔名用 Swift 的字串比較，兩種寫法的同一個重音字母被當成同一個；被拿掉的節依跳脫後的文字排序。另外：絕對路徑與不合理的行號通過格式檢查；不可能的時間通過；`--root` 不必是 repository 的根；FIFO 會讓讀取卡住；說明的選擇看任何一個參數。

## Root Cause

讀檔與比較沿用了 Swift 字串的預設行為（以字元切行、正規化後比較、解碼時取代），這些都和 JSON 與檔案系統的語意不同。

## Proposed Solution

- 以位元組切行；不是 UTF-8 的行不是 JSON；指數原樣保留，長到存不下的拒絕；能不能放進 double 用實際的值判斷。
- 路徑、檔名與 locator 的比較都逐碼位或逐位元組。
- `locators` 報出不是物件的行與不是清單的欄位；root 必須是 git 工作樹的頂層；檔案必須是一般檔。
- 格式檢查：locator 的 `file` 不得從 `/` 寫起；`lines` 是兩個正整數、前者不大於後者；時間的每一段在合理範圍；確認紀錄裡的段落副本要有 `id` 且 `section` 是那一節。
- 規格寫明對照的範圍（通過格式檢查的綱要）、id 的跳脫差異、工具只讀不寫、執行中假設 repository 不變。

## Non-Goals

- 寫入綱要檔的 API（另開 issue）。驗證與開檔之間檔案被換掉的情形。

## Success Criteria

- `swift test` 通過，含每一項的回歸測試；status 的比對仍逐行相同。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `Sources/PropositionsKit/` 的六個檔、`tests/PropositionsKitTests/OutlineTests.swift`
  - New: (none)
  - Removed: (none)
