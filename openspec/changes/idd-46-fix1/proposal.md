## Problem

#46 第一輪驗證（7 位 reviewer、68 項發現）指出兩項 HIGH 與多項 MEDIUM。plugin 的目錄多了 `bin/`，claude.ai 與 Cowork 會因此不安裝這個 plugin，PATH 上還多一個必定失敗的指令。命令列的契約只寫在 design，沒有寫成 requirement。讀 `\input` 樹有三個 bug。結束碼沒有測試。既有的兩份規格與發布流程文件沒有跟著改。

## Root Cause

第一版照另一個 repo 的做法放了 wrapper，沒有查 plugin 目錄裡 `bin/` 的後果，而 binary 發布之前沒有東西需要它。結束碼的判斷寫在 executable 裡，測試 target 碰不到。`\input` 樹的規則照 Python 版移植，連它的 bug 一起移了過來，另外漏了同一行多個引入、行的切法與主檔檔名三件事。

## Proposed Solution

- 拿掉 `plugins/propositions/bin/`。plugin 怎麼取得與驗證 binary，留到第一次發布時決定；規格寫明現在沒有 plugin 帶 `bin/`。
- 每個命令印什麼、用哪個結束碼，搬進 `PropositionsKit`（`CiteOrderRun`、`TschemaCheckPlaceholder`），executable 只負責印出與結束；補上結束碼的測試。
- 閱讀順序：同一行的多個引入照寫的順序；先去掉註解再判斷 verbatim 類環境，同一行開始又結束的不算；行的切法照 Python 的 `splitlines`；主檔不叫 `main.tex` 時照驗證器 R15 的規則；主檔目錄之外的檔用含 `..` 的相對路徑；symbolic link 算它指到的檔；空的引入名稱算缺檔。
- 檢查：每筆命題從自己的位置判斷（重複 id 時不借用第一筆的位置）；`cites` 不是字串的清單時回報；印出的 id 與位置把控制字元寫成跳脫。
- 發布腳本：先跑 `swift test`；notarization 的結果不是 `Accepted` 就停；tag 的錯誤不再吞掉；release notes 帶 pinned contract 的聲明。
- 規格：`citation-order` 補上命令列契約與上面各項的 Example；`umbrella-marketplace-layout` 允許根目錄的 Swift package 與發布腳本；`plugin-release-flow` 要求發布流程文件說明 binary 的發布。
- 文件：`docs/RELEASE-FLOW.md` 加一節；`CLAUDE.md`、Swift 規則檔更新；tools version 改成 6.2（測試用了 raw identifier）。

## Non-Goals

- 修 Python 的 `resolve_input_tree`（#94）。
- 分辨路線圖與預告（#93）。
- Unicode 數字的 `location`、巨集定義裡的 `\input`：寫明是限制。
- 發布 binary。

## Success Criteria

- `swift test` 全過，規格的每個 Example 有帶標記的測試，連結檢查 `ok`。
- `pytest tests/` 維持 872 passed；沒有 plugin 目錄帶 `bin/`。

## Impact

- Affected specs: `citation-order`（修改 5 條、新增 1 條）、`umbrella-marketplace-layout`（修改 2 條）、`plugin-release-flow`（修改 1 條）
- Affected code:
  - Modified: `Package.swift`、`Sources/PropositionsKit/CiteOrder.swift`、`Sources/PropositionsKit/LedgerReader.swift`、`Sources/PropositionsKit/Location.swift`、`Sources/PropositionsKit/ReadingOrder.swift`、`Sources/propositions/Propositions.swift`、`Sources/tschema-check/main.swift`、`tests/PropositionsKitTests/CiteOrderTests.swift`、`tests/PropositionsKitTests/ReadingOrderTests.swift`、`scripts/release-signed.sh`、`docs/RELEASE-FLOW.md`、`CLAUDE.md`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: `Sources/PropositionsKit/CommandRun.swift`
  - Removed: `plugins/propositions/bin/propositions-wrapper.sh`
