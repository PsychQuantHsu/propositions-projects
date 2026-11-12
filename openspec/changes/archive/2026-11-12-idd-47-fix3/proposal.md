## Why

#47 的第三輪驗證不通過。三輪都敗在同一類條文：描述「將來怎樣才算通過」的規則。第三輪的幾項要修的問題都是從「等 #68 或 #62 做好之後」推出來的，而那時候的報告格式與驗證紀錄格式現在都不存在，沒有東西可以對照。修正輪 2 寫的「報告要把單位列為檢查過」與「紀錄要自己顯示它讀了什麼」正是這種條文，第三輪在它們上面找到新的洞：沒有排除 `--partial`、整篇單位的定義照字面今天就會通過。

另一半的問題是今天就會決定結果的規則還要靠讀的人判斷：一項發現算在哪一列、哪個單位。

## What Changes

- **沒有任何一條規則給出通過。** 結果規則今天只給出不適用、沒檢查、沒通過。「通過」留作第四種結果，定義成原則（那條檢查檢查過這個單位、沒有回報問題），成立的條件由實作 #68 與 #62 的 change 寫進規格。這比維護者 2026-11-12 同意的做法更嚴；今天任何一篇文章的結果不變。
- **刪除**「報告要顯示什麼」、紀錄什麼時候算數的細節、結果是通過的範例情況。
- **發現算在哪一列改成查表**：只算在指名那條檢查的列；六條有好幾列的檢查各有一組對照（依輸出看得到的層級、訊息、命題有沒有 `retired` 鍵）；沒列到的算在那條檢查的每一列。守衛檢查對照表剛好涵蓋有好幾列的檢查。
- **發現算在哪個單位**：指名這一列適用的命題就算那一筆，其他的算在整篇，當成那一列多出來的一個單位。不再把沒被指名的命題算成沒通過，也不會因為沒有適用的命題而不算。
- 結構驗證器 `--partial` 的資訊行算成「不算錯誤的發現」。
- `completeness.thesis-stated` 的判準改回講文章（維護者舉的例子）；S5 回報主旨清單是空的算在這一列，其他算在計畫那一列前提。
- 適用條件：`cites` 不是清單、`opens` 格式不對時算讀不出來；說明 `relation` 為什麼不是鍵；標成其他類別的資料主張現在沒有檢查決定（#57）；判準對它沒有要求的單位交給 #68。
- 規格補上對 `docs/VERIFICATION.md` 的要求。
- 守衛：`applies`、`axiom` 明寫成沒有值時拒絕。
- Swift 規則檔的第 3 類例外改成指名的封閉清單。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式，不實作任何缺口的檢查。
- 不定義「通過」的條件。那是 #68 與 #62 的工作。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 七條 requirement 修改：類別、適用條件、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`tests/test_plugin_payload_tracked.py`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
- GitHub：在 #50、#62、#68 留 note；#45 的子題清單加 #21；#47 記錄盲驗的題目與答案。
