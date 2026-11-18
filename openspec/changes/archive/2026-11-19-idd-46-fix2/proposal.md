## Problem

#46 第二輪驗證：1 項擋下、9 項範圍內。擋下的一項是修正輪 1 改行的切法時引進的回歸：`location` 的行號是寫入它的工具在 LF、CR、CRLF 斷行算出來的，修正輪 1 卻把 form feed 等字元也當成斷行，稿件有 form feed 時被引入的檔的順序整個算錯，而且沒有任何回報。

## Root Cause

Python 那邊讀稿件的函式彼此不一致，Swift 版沒有先定對齊的對象：檔名照了驗證器的 R15、數行照了 `resolve_input_tree`，兩者都和寫 `location` 的工具不同。維護者決定以寫 `location` 的工具為準（https://github.com/PsychQuantHsu/propositions-projects/issues/46#issuecomment-6990536906）。

## Proposed Solution

- 行在 LF、CR、CRLF 結束，其他字元不斷行。`main.tex:` 一律指主檔；主檔自己的檔名也指主檔；以 `/` 開頭的 `location` 不合格式。
- verbatim 類環境只在它自己的 `\end` 結束；註解裡的標記不算；環境裡的 `%` 不開始註解；同一行環境前後的文字照常讀。`\subimport`、`\subfile`、`\import` 不追、在 stderr 點名，同一行的 `\input` 照常追。
- 讀帳冊：空行與 `//` 開頭的行略過；`cites` 存在而不是字串的清單（含 `null`）要回報，那筆命題仍保留；退役只認格式正確的 `retired` 區塊（照驗證器的 `retired_problem`）。
- 命令的參數解析搬進 `PropositionsKit`（`PropositionsCLI`），參數錯誤的結束碼 2、`--version`、兩個預設路徑都有測試；stderr 引用稿件文字時跳脫。
- 三處「沒有可執行檢查」換成 Example 與測試：沒有 plugin 目錄帶 `bin/`、Swift package 只在根目錄、發布流程文件點名腳本、版本檔與 tag。
- 規則檔：wrapper 的三處說法；「兩份解析要一起改」那一列改成寫明對齊的對象與三件寫了兩份的事。`docs/RELEASE-FLOW.md` 的 plugin tag 改成指名推送。

## Non-Goals

- 修 Python 的 `resolve_input_tree`（#94）。
- 發布腳本的可重現建置（清掉舊的 `.build`、釘住相依）：記到 #46 的後續。
- 發布 binary。

## Success Criteria

- `swift test` 全過；規格的每個 Example 有帶標記的測試，連結檢查 `ok`；`pytest tests/` 維持 872 passed。
- fixture 帳冊的結果與照驗證器規則的 Python 計算相同。

## Impact

- Affected specs: `citation-order`（修改 6 條）、`umbrella-marketplace-layout`（修改 1 條）、`plugin-release-flow`（修改 1 條）
- Affected code:
  - Modified: `Package.swift`、`Sources/PropositionsKit/CommandRun.swift`、`Sources/PropositionsKit/LedgerReader.swift`、`Sources/PropositionsKit/Location.swift`、`Sources/PropositionsKit/ReadingOrder.swift`、`tests/PropositionsKitTests/CiteOrderTests.swift`、`tests/PropositionsKitTests/ReadingOrderTests.swift`、`tests/PropositionsKitTests/Support.swift`、`docs/RELEASE-FLOW.md`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: `Sources/PropositionsKit/CLI.swift`、`Sources/propositions/main.swift`
  - Removed: `Sources/propositions/Propositions.swift`
