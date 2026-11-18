## Problem

#75 第八輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6960551027），擋下 3 項，都是修正輪 7 新寫的散文相對 `817dfc9` 的退步：`\include{ch1.tex}` 引入的受追蹤章節讀不到；只有節、還沒有段落的綱要在確認第 2 步就停下；新的找檔順序要模型知道清單以外的檔存不存在，沒有任何指令印這件事，探測它會把稿件文字打進指令。

## Root Cause

修正輪 7 為了第七輪的範圍內列（第 4、5、14 列）新寫了引入規則與確認第 2 步的散文。驗收只跑指令，反推實跑的三份稿件沒有用 `\include{x.tex}`，也沒有跑確認，所以新散文沒有被執行過。

## Proposed Solution

維護者 2026-11-18 的決定見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6962418232：只修三項擋下，三處都退回 `817dfc9` 的寫法，改完先實際跑這兩條路徑，再驗第九輪。**19 段指令不改。**

- 引入規則：`\input{x}` 與 `\include{x}` 在 `x` 以 `.tex` 結尾時指 `x`，否則指 `x.tex`，從主檔的目錄算起；是清單上的一行才讀，不在別的地方找。從根目錄找的退路拿掉，「存在」不再需要探測。`817dfc9` 的「x 沒有副檔名才加 `.tex`」改成「不是 `.tex` 結尾才加」，`\input{ch1.final}` 仍指 `ch1.final.tex`；「as LaTeX does」不寫回去（第七輪第 4 列）。
- 確認第 2 步：段落檔的寫入檢查印 `EMPTY` 時不停，只有節的綱要照常走到第 3 步。

## Non-Goals

- 第八輪其餘 11 項 LOW 與第 4 列（`.TEX` 副檔名，要改指令）：記成後續。
- 修正輪 7 其他的散文不動。

## Success Criteria

- 19 段指令與 `aa8a63d` 逐段相同。
- 一位只拿到 SKILL.md 與 OUTLINE.md 的 agent 實際跑兩條路徑：反推一份用 `\include{chapters/ch1.tex}` 的稿件，讀到那個檔；確認一份只有節、段落檔是空的綱要，走到展示並記下確認。
- 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文，指令區塊不動）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
