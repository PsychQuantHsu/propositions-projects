## Problem

#46 第四輪驗證沒有擋下的項目，剩下的集中在三處：行數的對照測試跑的是測試裡自己抄的一份 Python，不是寫 `location` 的工具；`propositions cite-order --help` 印的是上層的說明；規格與註解有兩句保證說得太滿（「兩棵樹不同時不會安靜地回答」被一份稿件推翻）。另有 Swift 拒絕而 `parse_location_v16` 接受的幾種字串、發布腳本只測了七道拒絕裡的兩道。

## Root Cause

寫 `location` 的工具把切行寫在一個內部的閉包裡，測試叫不到，所以抄了一份。Swift 讀 `location` 時加了 Python 沒有的限制（只收 ASCII 數字、拒絕 `/` 開頭、接受主檔自己的檔名），而規格同時說它照 `parse_location_v16`。

## Proposed Solution

- `refresh-prop-locations.py` 的切行抽成具名的函式 `read_tex_lines`（行為不變），對照測試載入它。
- `Location.parse` 照 `parse_location_v16` 讀：同樣的空白、任何十進位數字、同樣的檔名規則。主檔只認「沒有前綴」與 `main.tex`；主檔自己的檔名與 `/` 開頭的檔名都是樹裡沒有的檔。對照測試的清單加上這些字串。
- 子命令的說明；`ParityTests` 只在有 3.10 以上的 python3 時跑，沒有時跳過並顯示。
- 發布腳本再測三道拒絕（工作樹不乾淨、tag 指到別的 commit、沒有簽章身分），建置照 `Package.resolved` 釘版；規格逐項列出測了哪些。
- 規格：兩棵樹不同時的說法改成實際的行為；另列兩項已知的限制（大括號在下一行的引入、標記與大括號之間有空白）。

## Non-Goals

- 讓 Swift 的 `\input` 樹與 Python 的一致（#94）。
- 一行很長時的效能、發布腳本確認 commit 在預設 branch：記到 #94 與 #46 的後續。

## Success Criteria

- `swift test` 全過；連結檢查 `ok`；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `citation-order`（修改 4 條）、`umbrella-marketplace-layout`（修改 1 條）
- Affected code:
  - Modified: `plugins/propositions/scripts/refresh-prop-locations.py`（切行抽成函式，行為不變）、`Sources/PropositionsKit/CLI.swift`、`Sources/PropositionsKit/Location.swift`、`Sources/PropositionsKit/ReadingOrder.swift`、`scripts/release-signed.sh`、`tests/PropositionsKitTests/CiteOrderTests.swift`、`tests/PropositionsKitTests/ParityTests.swift`、`tests/PropositionsKitTests/ReadingOrderTests.swift`、`tests/PropositionsKitTests/ReleaseScriptTests.swift`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
