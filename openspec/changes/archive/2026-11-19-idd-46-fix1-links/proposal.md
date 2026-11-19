## Problem

`idd-46-fix1` 修改了三條早於「每條 requirement 要有 Example 或沒有可執行檢查的理由」這條規定的 requirement，規格連結檢查因此回報這三條沒有檢查。

## Root Cause

三條 requirement 是 `umbrella-marketplace-migration` 與發布流程那次變更寫的，當時沒有這條規定；一被修改就要補上。

## Proposed Solution

- 「Root-level CI entry shims preserve the pinned path contract」：既有的 shim 測試就是它的檢查，加一個 Example 並在 `tests/test_root_shims.py` 那個測試上加標記（只加一行註解）。
- 另外兩條各加一行沒有可執行檢查的理由。

## Non-Goals

- 改這三條 requirement 的內容。

## Success Criteria

- 規格連結檢查 `ok`；`pytest tests/test_root_shims.py` 通過。

## Impact

- Affected specs: `umbrella-marketplace-layout`（修改 2 條）、`plugin-release-flow`（修改 1 條）
- Affected code:
  - Modified: `tests/test_root_shims.py`（一行註解）
  - New: (none)
  - Removed: (none)
