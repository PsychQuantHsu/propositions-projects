## Problem

#87 第二輪驗證判定 not clean（https://github.com/PsychQuantHsu/propositions-projects/issues/87#issuecomment-6981216173）：沒有擋下的項目，範圍內 9 項沒有修。維護者 2026-11-18 決定先修這 9 項再合併（https://github.com/PsychQuantHsu/propositions-projects/issues/87#issuecomment-6981479299）。

## Root Cause

修正輪 1 改了反推的停下條件，旁邊四句沒有跟著改；另有一句新寫的話說得太滿：「不是 `.tex` 的引入是缺的檔」把「名稱補上 `.tex`」與「補完的檔不存在」寫成一件事。

## Proposed Solution

只改散文，19 段指令不動。

- 引入名稱不以 `.tex` 結尾時：補上 `.tex`，那個檔存在而且讀得到就讀，不存在才是缺的檔。三份文字同一句，規格加一個情境。
- 停下的條件列舉成「讀到的檔只有標題」，寫明讀到的檔裡的摘要或第一個標題前的散文是段落；規格的情境補上這個前提，另加一個情境。
- 圖表的例外三份文字都寫成「讀到的檔裡的」。
- OUTLINE.md 的發問條件改成「否則，一節的文字都在沒讀的檔裡時」。
- SKILL.md 第 7 步第三種情形把「The same holds」改成寫明是停下。
- SKILL.md 列帳冊的第一句補上第三個條件；寫明 `not one ledger` 不說是哪一種、也沒有 jq 的訊息。
- 規格的「although the tool reading it accepts it」改成「even when」。

## Non-Goals

- 第二輪列為後續的六項，收在 #89。
- 列帳冊時把 jq 的錯誤訊息印出來：那要改指令、重跑八種組合，這一輪只把行為寫明。

## Success Criteria

- 19 段指令與 `c39a375` 逐段相同，八種組合的驗收結果仍然適用。
- `spectra validate` 通過；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `article-outline`（修改 2 條 requirement，加 2 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
