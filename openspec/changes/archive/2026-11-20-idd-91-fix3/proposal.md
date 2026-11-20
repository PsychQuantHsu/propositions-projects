## Problem

#91 第三輪驗證（0 項擋下）：

- 「沒 checkout 的 submodule」的檢查有三個漏洞：綱要目錄還不存在時比對的是上一層目錄；`git ls-files` 對含雙引號或反斜線的名稱加引號，比對不到；git 失敗時當成通過。
- 舊綱要提示的觸發條件，SKILL.md 與規格不同；「不會被報出來」的第二種情形寫錯；「新的 session 一律停下」說得太滿；第四條 requirement 的「No executable check」理由漏改；已知限制 8、保證 2 的殘留。

## Root Cause

檢查用了要放綱要的目錄而不是綱要目錄本身，並且靠文字輸出的格式與 pipe 的最後一個結束碼。

## Proposed Solution

- 兩處檢查改成：`git ls-files -s -z` 寫進暫存目錄的檔，成功才用 jq 以 NUL 切開比對，比對的是綱要目錄相對於 root 的路徑。
- 換 root 的指令多確認 git 回報的 repository 真的包含綱要目錄。
- 三份文字統一：提示的觸發條件、被報出與不被報出的情形、新 session 的條件、守門是哪些指令、限制 8、保證 2。

## Non-Goals

- Swift 的測試（#78）。

## Success Criteria

- 八種組合全過，含新的案例：綱要目錄本身是沒 checkout 的 submodule 且目錄不在、名稱只是以 submodule 名稱開頭的目錄不被誤判、名稱含雙引號的 submodule。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
