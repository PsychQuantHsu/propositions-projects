## Problem

#75 第七輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6957940605），擋下 1 項：修正輪 6 把沒讀的被引入檔寫進鄰近紀錄的 `note`，各節的內容都在沒讀的檔裡的稿件反推沒有合規的結果。修正輪 5、6 為沒讀的被引入檔各設計了一種留在綱要裡的方式，各有一種稿件做不下去。另有範圍內 15 項。

## Root Cause

第五輪第 9 列要綱要裡看得出沒讀的檔，兩輪修正都自行設計了紀錄方式，而綱要的格式（來源指標要出現一次、每一節要有段落紀錄、`note` 只定義在段落紀錄）沒有一個位置能無例外地放它。

## Proposed Solution

維護者 2026-11-18 的決定見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6959432763：退回 `997d3d0` 的做法，反推只告訴作者哪些檔沒讀，綱要不留紀錄；各節都在沒讀的檔裡時停下並說明；第五輪第 9 列改成開放問題，記到 #51。照 spec delta 修改 article-outline 的 5 條 requirement，skill 與說明文件跟著改。**19 段指令不改。**

- 沒讀的被引入檔：不寫紀錄、來源指標、要點或 `note`；在第 2 步與第 8 步告訴作者。圖或表照舊是一筆 `carry` 紀錄。
- 反推讀得到的檔裡沒有任何段落或區塊時（段落檔會是空的），停下並說明是哪些檔沒讀；這是第 7 步第三種不能修正的情況。
- 引入指令對到清單：`\input{x}` 與 `\include{x}` 指 `x.tex`，`\input` 找不到 `x.tex` 時才指 `x`；LaTeX 從執行的目錄找，skill 不知道那是哪裡，所以先從主檔的目錄、再從根目錄找。不再寫「照 LaTeX」。
- 作者指定的檔：它的路徑是 skill 會打進指令的路徑之一（和稿件的路徑一樣，照規則 2），三份文字與規格的封閉清單都加上；為它跑的檢查不改變 `MAIN`；沒有稿件時仍會為它跑那段檢查。
- 確認紀錄寫入失敗時：可能整筆、部分或沒有寫入，分不出來；展示確認紀錄檔的檢查與狀態，說明確認不一定有記下，停下、不重試。
- 確認第 2、9 步跑狀態時先跑寫入檢查；已知限制那一段寫明第 1 與第 10 項是一定看得到的；硬規則加「作者指定的檔先過檢查才讀」。

## Non-Goals

- 指令區塊的改動；第七輪第 17 列（在第一段指令擋下 `ROOT=/`）是 Follow-up。
- 綱要要不要為沒讀的檔留下缺口：開放問題，#51。

## Success Criteria

- 19 段指令與 `aa8a63d` 逐段相同；八種組合 389 項全過。
- 一位只拿到 SKILL.md 的 agent 照反推做三份稿件：同一個被忽略的檔引入兩次（做得完、綱要裡沒有它、告訴作者）；各節都在沒讀的檔裡（停下並說明）；`\input{ch1.final}`（讀到 `ch1.final.tex`）。
- 獨立 agent 對照三份文字；改過的規則由盲讀者重答。
- 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤。

## Impact

- Affected specs: `article-outline`（修改 5 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文，指令區塊不動）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
