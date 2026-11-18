## Problem

#87 第四輪驗證沒有擋下的項目，剩 7 項範圍內的修正（1 項 MEDIUM）。維護者決定補完後直接合併，不再跑完整的一輪（https://github.com/PsychQuantHsu/propositions-projects/issues/87#issuecomment-6990536058）。

## Root Cause

修正輪 3 新加的情境「An abstract whose text was not read does not keep derive going」漏了另外兩個停下情境都有的前提；新的定義句只說了段落、圖與表；「只有標題時說起草可以從標題建綱要」那一句在規格裡不再限於停下的時候。

## Proposed Solution

只改散文，19 段指令不動。

- 那個情境的前提補上「讀到的檔沒有任何段落也沒有任何區塊」。
- 定義句三份文字都改成：段落讀到任何一部分文字就算；區塊（定理類陳述、證明、圖、表、展示的公式）讀到它的環境或界線就算，即使內容在沒讀的檔裡。
- 規格的起草提示改成只在因為這個原因停下時說。
- OUTLINE.md 的「Otherwise」改成與規格相同的寫法。

## Non-Goals

- 第四輪列為後續的四項（版本號、起草引用反推第 3 步、缺檔與存在的分辨、`NaN` 與驗證器不同）記在 #89。

## Success Criteria

- 19 段指令與 `6190431` 逐段相同；`spectra validate` 通過；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
