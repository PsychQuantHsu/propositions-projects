## Problem

#78 第二輪驗證（Codex）：4 項擋下、6 項要修。綱要檔本身是 symbolic link 時會被讀取；單獨的代理字元被換成 U+FFFD，可能和真的 U+FFFD 相等；空行在 LF 與 CRLF 的檔處理不同；確認紀錄裡的副本缺必填的鍵也通過。另外：`\b`、`\f` 的跳脫與 jq 不同；指數前面的零被算進長度；行號有九位數的上限；不存在的日期通過；`from` 與 `replaces` 的比較沒有照解析時的空白規則；git 繼承了會讓它回答另一個 repository 的環境變數。

## Root Cause

讀檔的入口沒有套用對來源檔案的同一組條件；幾個界線用了方便的近似。

## Proposed Solution

- 三個綱要檔必須是一般檔；空行（含只有 CR 的）略過；單獨的代理字元拒絕。
- 確認紀錄的副本檢查必填的鍵，同一節不重複。
- 跳脫照 jq 的短寫法；指數去掉前面的零；行號不限位數；日期照曆法；locator 的比較用解析時的空白規則；執行 git 時清掉選 repository 的環境變數。

## Non-Goals

- 其他影響文字方向的字元的跳脫。

## Success Criteria

- `swift test` 通過，每一項有回歸測試；status 的比對仍逐行相同。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `Sources/PropositionsKit/` 的四個檔、`tests/PropositionsKitTests/OutlineTests.swift`
  - New: (none)
  - Removed: (none)
