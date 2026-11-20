## Problem

#78 第三輪驗證（Codex）：3 項擋下、5 項要修。極小指數的兩個不同數字 Swift 分得出、jq 分不出，規格卻說兩邊輸出相同；`label` 的比較沒有照空白規則；確認紀錄檔的屬性讀不到時被當成不存在。另外：git 仍可能經由 `GIT_CONFIG_*` 繼承設定；確認紀錄的副本只查必填的鍵；時間接受第 60 秒；行號寫成很大的指數時被拒絕；root 是 `/` 時每個 locator 都被判成在外面。

## Root Cause

對照的範圍寫得比實際寬；幾個邊界用了近似。

## Proposed Solution

- 規格寫明數字以精確的值為準，jq 在它存不下的範圍分不出來。
- `label` 的比較照解析時的空白規則；只有系統回報「沒有這個檔」才算沒有確認紀錄檔。
- 清掉 `GIT_CONFIG_PARAMETERS`、`GIT_CONFIG_COUNT`、`GIT_CONFIG_KEY_*`、`GIT_CONFIG_VALUE_*`；副本檢查 `role`、`part` 與同一筆確認裡重複的 id；秒不超過 59；行號不寫出尾端的零就比較；root 的前綴只帶一個斜線。

## Non-Goals

- 寫入的 API 與 skill 的替換（#102）。

## Success Criteria

- `swift test` 通過，每一項有回歸測試；status 的比對仍逐行相同。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement）
- Affected code:
  - Modified: `Sources/PropositionsKit/` 的四個檔、`tests/PropositionsKitTests/OutlineTests.swift`
  - New: (none)
  - Removed: (none)
