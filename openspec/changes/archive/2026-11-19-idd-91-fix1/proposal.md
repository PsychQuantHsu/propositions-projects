## Problem

#91 第一輪驗證（7 位 reviewer，0 項擋下）找到幾個會讓照著做的人走錯的地方：

- 換 root 的指令沒有標記自己跑過，守門照舊接受最外層的 root；SKILL.md 的復原段落只說重跑第一段指令，於是新的 session 會回到 #91 之前的行為。
- 還沒有稿件時，新指令不檢查新的 root 是否包含預定的稿件目錄，可以把綱要放進只有帳冊的 submodule。
- 守門會拒絕的綱要目錄（一個檔、`.git` 裡面），新指令照樣改掉 root，之後只能從頭開始。
- 舊綱要靠「locator 解析不到」辨認，但舊路徑可能剛好指到新 root 下另一個有同樣 label 的檔；版本界線寫成 0.12.0，而這次也是 0.12.0；遷移會讓確認失效，文件沒說。
- 規格仍說列帳冊、帳冊的第二種讀法用「the repository」，而它現在指綱要的 repository；保證 2 沒有列出最外層的 `_meta.json`。

## Root Cause

第一版只在 root 決定的那一刻檢查，沒有讓後面的指令知道 root 是否已經換過，也沒有沿用守門既有的條件。

## Proposed Solution

- 新指令先照守門的條件檢查綱要目錄（含三個綱要檔不是 symbolic link），通過才改 root；改完在暫存目錄留一個標記，守門沒有標記就停。復原段落改成重跑第一段指令、換 root 的指令、稿件檢查。
- `M` 一律要給：有稿件時是 `MAIN`，沒有時是作者說稿件會在的目錄；新的 root 要包含它。
- root 往下移時印 `NOTE`，寫出舊路徑會帶的前綴；綱要檔已存在時問作者是不是這樣寫的，不靠解析結果判斷；拿掉前綴後那些節要重新確認。不寫版本號。
- 規格、SKILL.md、OUTLINE.md 把只在最外層發生的事（列帳冊、第二種讀法、別處的綱要檔）明寫成最外層；保證 2 加上最外層的 `_meta.json`；ledger-only submodule 的提議文字改寫。

## Non-Goals

- 帳冊 `source.file` 的讀法不變。
- 綱要格式不變。

## Success Criteria

- 八種組合全過，含新的案例（沒有標記時守門停下、草稿的預定目錄不在新 root 裡時停下、守門會拒絕的目錄在改 root 之前停下、`M` 空白時停下、`NOTE` 行）。
- `spectra validate` 通過；`pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement，加 2 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（換 root 的指令、守門、說明）、`plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
