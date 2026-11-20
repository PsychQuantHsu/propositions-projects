## Problem

#80 第五輪驗證（Codex，`alternative_to` 拆出之後）：1 項擋下、7 項要修。來源與被取代的段落是同一個 locator 時，作者選「被取代」會把搬移區塊唯一的 `from` 拿掉，而搬移區塊必須有來源。其餘：比對把 `label` 不是字串的物件當成沒有 label；checker 沒有豁免只改交叉引用的差異、會對 `replaces` 的段落報找不到；被整節拿掉的紀錄與前提檢查的 finding 顯示時沒有套用同樣的規則；合併規則的「every locator」字面上把 `replaces` 的 locator 也放進 `from`。

## Root Cause

衝突規則只寫了「把 locator 從另一邊拿掉」，沒有考慮帶 `carry` 的紀錄不能沒有 `from`。

## Proposed Solution

- 帶 `carry` 的紀錄保留它的 `from`：衝突時只能從另一筆的 `replaces` 拿掉，否則不合併、不搬。
- 寫入檢查不比對不是 locator 的物件。清單的成員逐一讀，不是 locator 的成員報出、其他成員照常解析。
- checker：對帶 `carry` 的紀錄豁免 `edits` 列出的與只涉及交叉引用的差異；不報 `replaces` 的任何事。
- 顯示規則適用於每一處為確認而顯示段落紀錄的地方；finding 取自報告與紀錄的文字放進 fence。
- 合併規則的措辭分開 `from` 與 `replaces`。

## Non-Goals

- `alternative_to`（#99）。

## Success Criteria

- 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 5 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`
  - New: (none)
  - Removed: (none)
