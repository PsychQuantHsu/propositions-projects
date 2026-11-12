## Why

#47 的四輪驗證都不通過，每一輪要修的項目多數落在同一處：從檢查的輸出算出每一列結果的規則。那是一套演算法，卻只用文字寫，沒有程式可以跑；每一輪逐字審查都找得到新的邊界情況。維護者 2026-11-13 決定拆開（#47 的決定紀錄）：這套規則移到 #71，和計算它的工具一起做，用測試守住。

這個 change 把那些規則從 `article-obligations` 規格與說明文件移走，並修掉第四輪裡留在 #47 範圍內的項目。

## What Changes

- **分界**：只靠表、帳冊與附檔就能決定的事留在這個 capability；要讀檢查的輸出或驗證紀錄才能決定的事歸 #71。
- **四種結果**改成定義。這裡就能決定的只有三條：讀得到的值不在清單裡是不適用；值讀不出來是沒檢查；缺口是沒檢查。其他的列今天不會是通過，是沒通過還是沒檢查由 #71 的規則決定。
- **移走**：每個來源什麼算發現與層級、發現算在哪一列的對照表、算在哪個單位、判定過的發現、通過的條件、靠檢查輸出的範例情況、報告列出的細節。守衛裡檢查對照表的那一段一併拿掉。
- 守衛釘住 `dependence.cites-backward` 的 `unit` 與 `applies`。
- 守衛遇到不是對照表的檔、型別不對的值時回報問題，不當掉。
- 一筆命題在附檔裡有兩筆紀錄時，`opens` 與 `section_role` 算讀不出來。
- 寫明一個限制：外部查證的兩列用 `evidence_class: external` 當適用條件，這個值只有 empirical 才有，所以 default 帳冊裡依賴外部文獻的命題沒有被涵蓋（#50）。
- `docs/VERIFICATION.md` 的兩段改成只指到 `docs/OBLIGATIONS.md`，不自己下規則；守衛檢查它帶著三個關鍵字句。
- 規格裡三處文字修正：兩個 Scenario 的前提、「其他每一列機械檢查的列」、報告列出什麼。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式，不實作任何缺口的檢查。
- 不定義怎麼從檢查的輸出算出結果，也不定義通過的條件。那是 #71 的工作，配合 #68 與 #62。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 七條 requirement 修改：適用條件、已實作的檢查、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`plugins/propositions/docs/VERIFICATION.md`、`tests/test_plugin_payload_tracked.py`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
- GitHub：新開 #71 並加進 #45 的子題清單；更正 #62、#68 上的 note；在 #50 留 note；#47 記錄維護者的決定與盲驗的題目、答案。
