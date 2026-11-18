## Problem

#75 的第八、九輪驗證留下一批當時沒修的列，收在 #87。其中兩處是指令的行為錯誤：列 `.tex` 的指令分大小寫，漏掉副檔名寫成 `.TEX` 的受追蹤檔；列帳冊的指令接受 jq 讀得進去但不是 JSON 的 `_meta.json`（`01`、`nan`、`Infinity`），只有它一個時 skill 不問作者就用它的目錄。另外十列是 SKILL.md、OUTLINE.md 與規格三份文字彼此不一致，或指到不存在的東西。

## Root Cause

列帳冊與比對帳冊的兩段只問「恰好一個值、是物件」，沒有用綱要檔寫入檢查那一套看原始文字的判斷。列 `.tex` 用 `find -name`，而引入規則與檔名比對的其他地方都承認另一種大小寫。文字的各列出在修正輪 7、8 改寫散文時沒有回頭對齊其他段落。

## Proposed Solution

診斷見 https://github.com/PsychQuantHsu/propositions-projects/issues/87#issuecomment-6978914621 。

- 列 `.tex` 改成不分大小寫；引入規則的「以 `.tex` 結尾」寫明不分大小寫。
- 列帳冊與比對帳冊先跑寫入檢查同一段原始文字的判斷，不是嚴格 JSON 的檔印 `not one ledger`，比對不印 `ok`。
- 十列文字各改指到的那一句：各節都沒讀時先停、不先問；只有標題的稿件指向起草；給了 `says` 的節為什麼被第 5 類報出來；「前兩種情況」；起草第 2 步改指規則 2、3；寫入失敗時不展示最後一行，改告訴作者那一行看得出來；作者指定的檔路徑含單引號時只停那個檔；不是 `.tex` 的引入歸到缺檔；規則 4 的清單點名 status 與確認第 2 步；規格情境改成 `stats/N.tex`。
- 沒有標題的摘要寫 "Abstract" 這一句補進規格與 OUTLINE.md。

## Non-Goals

- 三項要維護者拍板的選擇不改行為：摘要的標題用什麼、逐節要 `says`、確認實跑指出的四處不清楚。診斷裡各有一段 Choice Default Record。
- #87 第 15 列（沒包在環境裡的生成表格）與「`\input{manuscript/intro}` 從根目錄算」：都需要新的找檔或辨識規則，不在這次。
- 不新增指令區塊；Swift 規則〈例外〉第 4 類的清單不變。

## Success Criteria

- 八種組合的指令驗收全過，新加的 7 項在修正前的 SKILL.md 上有 6 項失敗。
- 用正式的 `propositions:outline-checker` 跑一次確認一份只有節的綱要。
- `pytest tests/` 維持 872 passed；`spectra validate` 通過。

## Impact

- Affected specs: `article-outline`（修改 4 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（兩段指令與散文）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
