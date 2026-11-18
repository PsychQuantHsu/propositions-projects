## Context

第一個 Swift 變更負責建立 package（Swift 規則）。範圍由 #45 的決定與 #46 的診斷定下。

## Goals / Non-Goals

**Goals**：package 的四個 target；一條新檢查，含命令列與測試；發布用的殼層備妥。

**Non-Goals**：見 proposal。

## Decisions

### 閱讀順序由 `\input` 樹算出，不由 `source.parts` 或帳冊行序

`docs/SCHEMA.md` 把 `source.parts` 定為非權威的快照，權威是 `\input` 樹的即時解析。而且被引入的檔案的內容排在引入它的那一行之後、那個檔下一行之前，只看檔案的先後表達不了這一點。所以每一個位置的順序鍵是一串行號：主檔第 L 行是 `[L]`，主檔第 L 行引入的檔的第 k 行是 `[L, k]`，依此類推，照字典序比較。同一個檔被引入兩次時取第一次（與 Python 的 `resolve_input_tree` 相同）。

解析 `\input` 的規則照 Python 版：`\input` 與 `\include`、路徑從主檔的目錄算、沒有 `.tex` 就補上、`%` 註解與 verbatim 類環境裡的不算、絕對路徑拒絕、找不到的檔與循環與超過三層都是錯誤。這是第二份實作，測試用同樣的案例釘住。

### 位置的比較

命題的位置是它 `location` 的起始行。引用的命題位置嚴格大於引用者時報警告；同一個位置（同一行的兩筆命題）不報，因為行內的先後 `location` 表達不了。

### 結束碼

| 情形 | 結束碼 |
|---|---|
| 沒有向後的引用，或只有警告 | 0 |
| 有讀不懂的帳冊行或位置，檢查不完整 | 1 |
| 檔案不存在、`\input` 樹解析失敗、參數錯誤 | 2 |

參數錯誤用 2 而不是 swift-argument-parser 預設的 64，與既有的 Python 工具一致。

### 參數

`--jsonl`、`--tex` 與 Python 驗證器同名同預設（`manuscript/propositions/main.jsonl`、`manuscript/main.tex`）；`--json` 輸出給 skill 讀的 JSON。

### 退役與找不到的命題

有 `retired` 的命題不檢查它的引用，也不算被引用的對象。`cites` 指到帳冊裡沒有的 id 不歸這一條（R2 管），略過。

## Implementation Contract

- 行為：`propositions cite-order --jsonl <帳冊> --tex <主檔>` 對每一個指到後面的引用印一行 `WARN cite-order: <引用者 id> (<位置>) cites <被引用 id> (<位置>), which comes later`，最後一行印 `cite-order: <n> forward citation(s) among <m> citation(s) checked`。
- 資料形狀：`--json` 印一個物件，鍵為 `checked`、`forward`（物件的清單：`from`、`fromLocation`、`to`、`toLocation`）、`unreadable`（字串的清單）。
- 失敗：見結束碼表；錯誤訊息印到 stderr。
- 驗收：`swift test` 通過；規格的每個 Example 有帶標記的測試。
- 範圍：不改任何 Python 檔的行為；不改 skill。

## Risks / Trade-offs

- 兩個驗證工具並存，是 #45 接受的過渡。
- `\input` 樹的解析有 Python 與 Swift 兩份。
