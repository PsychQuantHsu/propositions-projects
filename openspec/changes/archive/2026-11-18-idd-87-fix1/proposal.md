## Problem

#87 第一輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/87#issuecomment-6980066667）：擋下 1 項，範圍內 7 項。擋下的一項是 `idd-87-outline-followups` 為「各節都沒讀時先停、不先問」新寫的句子，條件寫成「每一節的文字都在沒讀的檔裡」，規格的 SHALL 是「讀到的檔沒有任何段落也沒有任何區塊」。主檔裡有內容在沒讀的檔裡的表時，新句子會讓原本做得完的稿件停下；一節只有標題、另一節都沒讀時，又仍然先問再停。

## Root Cause

新句子沒有照規格的條件寫，規格新加的情境也只寫了其中一種情形。其餘各列是同一次改動裡沒有對齊的相鄰文字。

## Proposed Solution

只改散文，兩段指令不動。

- 停下的條件三份文字都用規格的 SHALL，列出三種情形，寫明內容在沒讀的檔裡的圖或表仍是區塊；規格補兩個情境。
- 帳冊的句子改成寫入檢查的那個判斷，寫出非 UTF-8 位元組的例外。
- 確認紀錄寫入失敗時只展示兩段檢查的結果。
- 列帳冊的說明、已知限制的開頭、第 5 類的說法各改一句。

## Non-Goals

- 第一輪驗證列為後續的各列與診斷沒有處理的各列，收在 #89。

## Success Criteria

- 19 段指令與 `1e209fa` 逐段相同，八種組合的驗收結果仍然適用。
- `spectra validate` 通過；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
