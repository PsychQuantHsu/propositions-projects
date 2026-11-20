## Problem

#80 的第一輪驗證（Codex 單一審查）找到 8 項，3 項擋下：

- 作者選了帶 `alternative_to` 的那一筆時，落選的那一筆沒有這個鍵可以「保留」；兩筆互指、兩筆指同一筆時，status 重複計算或算不出來。
- 拆開一筆只有 `replaces` 的紀錄時 locator 會遺失；「沒有 `from` 就刪除」的兩條規則沒有跟著改；一筆的 `from` 與另一筆的 `replaces` 是同一個 locator 時，合併的規則與寫入檢查互相衝突；刪除、合併、拆開不處理指進來的 `alternative_to`。
- `replaces` 是物件時，指令仍把它的值當 locator 讀。
- 三個鍵的顯示規則只寫在「從未確認」的分支，差異顯示沒有；`edits` 沒有規定以標示過的引文顯示。

## Root Cause

第一版沒有定義「一組替代」是什麼（誰帶鍵、能不能重疊），也沒有把 `replaces` 放進所有以 `from` 判斷去留的規則。

## Proposed Solution

- 一組替代是兩筆、其中一筆帶鍵；選定前兩筆都不屬於第二組，寫入檢查報出重疊。選定後落選的那筆帶 `dropped` 與指向入選者的 `alternative_to`，必要時把鍵移過去。
- 以 `from` 判斷去留的規則都加上 `replaces`；拆開時每個 `replaces` 的 locator 至少留一次；來源與被取代的段落是同一個 locator 時不合併、問作者；動到一組替代的任何一筆之前先問作者。
- 指令只在 `replaces` 是清單時讀它的內容。
- 顯示規則移到完整顯示與差異顯示共用的一層，寫明以標示過的引文顯示，另一筆在沒顯示的節時當背景並說明不在這次確認內。

## Non-Goals

- `from` 不是清單時既有指令的讀法不變。

## Success Criteria

- 八種組合全過，含新的案例：三種重疊的寫法被報出、落選紀錄的鍵不擋新的一組、`replaces` 是物件時不列出檔案。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 3 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
