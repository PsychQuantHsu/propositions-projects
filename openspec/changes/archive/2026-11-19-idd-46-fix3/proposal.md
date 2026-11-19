## Problem

#46 第三輪驗證沒有擋下的項目，剩 9 項範圍內的修正，其中兩個是讀 LaTeX 的程式問題：加星號的 verbatim 類環境會在不加星號的 `\end` 結束；`\\input{x}`（換行後接文字）被當成引入。其餘是測試與規格：發布腳本有不需要簽章身分的閘門卻沒有測試；Python 與 Swift 各寫一份的事沒有自動比對；repo 層級的測試不在 plugin 發布的閘門裡；規格有兩句說得太滿。維護者決定補完再驗一輪。

## Root Cause

找指令時用的是子字串比對，沒有看反斜線的邊界；環境只記了不帶星號的名稱。規格把發布腳本整支說成沒辦法測，沒有分開需要簽章身分的步驟與不需要的。

## Proposed Solution

- 指令只在它的反斜線不是前一個 `\\` 的後半時才算；環境記完整的名稱（含星號），只在同名的 `\end` 結束；`\subimport*`、`\import*` 也點名。
- 發布腳本的三個測試，用假的工具跑：版本不符就拒絕、notarization 不是 `Accepted` 就不 tag 不發布、`Accepted` 時依序測試、notarize、tag、發布。
- `ParityTests`：`location`、數行、`retired` 區塊三件事，同一組輸入餵 Python 與 Swift 比對。
- `docs/RELEASE-FLOW.md` 的發布閘門加上 `swift test`。
- 規格：兩句說得太滿的改成實際的保證；`[warn]` 行寫成實際印出的字樣並加測試；不帶子命令時印說明；另列兩項已知的限制。`umbrella-marketplace-layout` 把寫了兩份的三件事改成實際比對的三件。

## Non-Goals

- 讀帳冊與驗證器的細部差異、`--json` 輸出的跳脫、GitHub 的 Latest 標記：記到 #94 與 #46 的後續。
- 發布 binary（維護者已授權，合併後另外確認一次再執行）。

## Success Criteria

- `swift test` 全過，規格的每個 Example 有帶標記的測試，連結檢查 `ok`；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `citation-order`（修改 3 條）、`umbrella-marketplace-layout`（修改 1 條）
- Affected code:
  - Modified: `Sources/PropositionsKit/ReadingOrder.swift`、`tests/PropositionsKitTests/CiteOrderTests.swift`、`tests/PropositionsKitTests/ReadingOrderTests.swift`、`docs/RELEASE-FLOW.md`、`CLAUDE.md`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: `tests/PropositionsKitTests/ReleaseScriptTests.swift`、`tests/PropositionsKitTests/ParityTests.swift`
  - Removed: (none)
