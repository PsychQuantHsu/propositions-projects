## Problem

#92 第一輪驗證（Codex）：2 項擋下、6 項要修。參照的目錄檢查同時太嚴又太鬆（repository 的根目錄被拒絕；root 底下另一個 repository 裡的綱要被接受）；一個目錄解析不到時，印不出是哪些紀錄指到它。另外：`uses` 的容器與成員沒有檢查；列舉與查找對「寫對了的參照」用不同的條件；「兩行 ok」被當成通過；新的搬移規則與既有的刪除規則衝突；checker 與 skill 對「什麼是參照」的判別不同；新的顯示欄位沒有規定原樣顯示。

## Root Cause

目錄只比路徑前綴，沒有問 git 它屬於哪個 repository；列舉只留目錄、沒留是誰指的。

## Proposed Solution

- 另一份綱要的目錄可以是 root 本身；git 回報的 repository 必須是 root。
- 列舉多印每個目錄被哪些紀錄指到；`uses` 不是清單、成員既不是 id 也不是參照時報出；列舉與查找共用同一個「寫對了」的條件。
- 文字寫明兩行 ok 只代表指令跑了；derive、draft、revise 在沒有解析不到的參照時才往下。
- 帶 `moved_to` 的紀錄不被刪除規則刪掉；作者拿回來時 `dropped` 與 `moved_to` 一起拿掉。
- 有 `outline` 的物件一律是參照、不是 locator（skill 與 checker 一致）。
- `moved_to`、`part`、參照的目錄與 id 當成取自紀錄的文字顯示。

## Non-Goals

- 指令執行中 repository 被別的程式改動的情形（文字寫明假設它不變）。

## Success Criteria

- 八種組合全過，含新的案例：根目錄的綱要解析得到、root 底下另一個 repository 的解析不到、`uses` 的三種錯誤、指到同一個目錄的紀錄被列出、寫錯的參照只報一次。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 1 條 requirement，加 1 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
