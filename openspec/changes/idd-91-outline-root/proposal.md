## Problem

綱要的 repository root 原本取最外層的 repository，不論中間隔幾層 submodule；locator 的 `file` 相對於它寫。同一份綱要換一種 checkout 就全部解析不到：只 clone 文章 repo，或外層多登記一層 submodule，每一筆 `file` 的前綴就不同。一份實際在用的稿件（稿件 repo 是文章 repo 的 submodule、文章 repo 又在更外層的 repo 裡）因此 77 筆來源指標一筆都解析不到（#91）。

## Root Cause

root 在第一段指令就定下，從稿件所在的目錄一路往外找，不看綱要放在哪裡。

## Proposed Solution

維護者的決定（https://github.com/PsychQuantHsu/propositions-projects/issues/91#issuecomment-6981478645）：root 取綱要目錄所在的 repository，它底下的 submodule 仍可讀。

- 第一段指令不變：仍找到最外層的 repository，在那裡列帳冊與既有的綱要檔，暫存目錄建在它外面。
- 新增一段指令（SKILL.md「The root is the repository of the outline directory」）：綱要目錄決定之後，問 git 那個目錄（不存在時問它上面的目錄）屬於哪個 repository；它要在最外層之內、不是 `/`、而且包含稿件，才把暫存目錄記的 root 換成它。之後每一段指令的守門照舊比對暫存目錄記的 root，所以給舊的 root 會停下。
- 稿件檢查在新的 root 下再跑一次，`NAME=` 是 locator 寫的主檔路徑。
- 「git 是否忽略這個檔」改成問 root 的 repository（綱要的 repository），不再問最外層。
- 舊的綱要不做轉換：check 會逐筆報出解析不到的 locator，文件寫明要拿掉的前綴。

## Non-Goals

- 帳冊的 `source.file` 兩種讀法不動。
- #78 的子命令（之後照新規則寫）。

## Success Criteria

- 八種組合的驗收全過，含新指令的 17 個案例（文章 repo 當 root、只 clone 文章 repo 時同樣的 locator 解析得到、綱要在不含稿件的 repo 時停下等）。
- 既有的 19 段指令沒有改；`spectra validate` 通過；`pytest tests/` 維持 872 passed。

## Impact

- Affected specs: `article-outline`（修改 2 條 requirement，加 2 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（新增一段指令與說明）、`plugins/propositions/docs/OUTLINE.md`、`.claude/rules/swift-is-the-implementation-language.md`（例外第 4 類的清單）
  - New: (none)
  - Removed: (none)
