## Problem

#91 第二輪驗證（0 項擋下）指出修正輪 1 的兩個設計站不住：

- 「root 換過」的記號不認綱要目錄。同一個暫存目錄裡把綱要目錄換到 root 底下另一個 repository，守門照樣放行，locator 又從外層的 root 寫起。
- 舊綱要靠 `NOTE` 與提問處理：每個 session 都會再問、照新規則寫的綱要也被問、指向新 root 之外的 locator 不帶那個前綴、SKILL.md 還留著版本號。

另外：綱要目錄在沒有 checkout 的 submodule 裡時放行；綱要目錄在排成 repository 樣子的目錄底下時現在會停下而規格沒有寫；「No executable check」的理由在 #46 合併後不成立；幾處文字殘留。

## Root Cause

記號記的是「跑過」這件事，不是守門要保證的那個關係（綱要目錄的 repository 就是 root）。舊綱要的辨認沒有可靠的訊號。

## Proposed Solution

維護者的決定（2026-11-20，「照你的建議」）：

- 拿掉記號。守門每次問 git 綱要目錄（還不存在時是要放它的目錄）屬於哪個 repository，不是 root 就停；往下走到它的路上有沒 checkout 的 submodule 也停。換 root 的指令在綱要目錄改變時重跑，`ROOT` 是暫存目錄現在記的 root。
- skill 不處理舊綱要：拿掉 `NOTE` 與提問。文件寫明舊綱要的路徑從最外層寫起；check 報出解析不到的 locator 時，skill 說明怎麼手動去掉前綴；兩種不會被報出來的情形寫明留給作者。
- `M` 找不到與 `M` 不在 repository 裡分成兩個停下的訊息。
- 規格補四個情境，寫明排成 repository 樣子的目錄會讓換 root 的指令停下，並改寫「No executable check」的理由。

## Non-Goals

- 把驗收案例寫成 Swift 的測試（#78）。
- 轉換舊綱要的工具。

## Success Criteria

- 八種組合全過，含新的案例：換 root 後綱要目錄改到下層 repository 時守門停下、重跑後 root 往下移、不往上移、沒 checkout 的 submodule 停下（兩段指令都停）、`M` 找不到的訊息、排成 repository 樣子的目錄停下。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement，加 4 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/README.md`
  - New: (none)
  - Removed: (none)
