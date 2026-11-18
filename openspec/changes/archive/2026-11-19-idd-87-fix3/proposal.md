## Problem

#87 第三輪驗證（修正輪 2 之後）沒有 HIGH，Codex 判 1 項 MEDIUM，其餘是 LOW 與 INFO：規格裡寫「停下」的三個情境，前提只排除了主檔裡的摘要與區塊，沒有涵蓋其他讀到的檔；三份文字為停下條件另寫的列舉與例外，又各自和主條件對不上（摘要的內容在沒讀的檔裡、寫在前言的摘要、只有 `\maketitle` 的主檔）。

## Root Cause

這是同一段第三次出現相鄰的不一致。三份文字在主條件「讀到的檔沒有任何段落也沒有任何區塊」旁邊另寫了一份列舉（哪些稿件算）與例外（哪些不算），每一輪修一句，旁邊的句子就和它不同。列舉與主條件是兩份不會一起改的規格。

## Proposed Solution

只改散文，19 段指令不動。

- 三份文字拿掉列舉與例外，只留主條件，加一句定義：段落要讀到它的文字才算；讀到環境的圖或表即使內容在沒讀的檔裡仍是區塊。
- 規格寫「停下」的三個情境，前提直接用主條件寫；另加兩個情境（摘要在讀到的引入檔裡時繼續；摘要的內容沒讀時停下）。
- 「名稱不以 `.tex` 結尾」補上不分大小寫。
- `not one ledger` 的說明改成「沒有辦法讀成一個寫成 JSON 的物件」，涵蓋打不開的檔。
- SKILL.md 第 7 步結尾與 OUTLINE.md 發問那一句各改一處指稱。

## Non-Goals

- 非 UTF-8 位元組「只在字串裡不回報」的說法、寫在前言的摘要（apa7）、列帳冊印出的 `source.file` 沒有濾掉方向控制字元：都在 `16eb01f` 就有，記到 #89。

## Success Criteria

- 19 段指令與 `01fe1f7` 逐段相同。
- `spectra validate` 通過；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement，加 2 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
