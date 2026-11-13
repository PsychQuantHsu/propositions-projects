## Why

修正輪 7 之後的兩席核對不通過：1 項要修、6 項小修。要修的 1 項不在判準本身，在旁邊的說明：說明寫「轉述別人研究結果的句子，這一列不問」，少了「只」字，同時寫了自己的數字與別人數字的句子因此有兩種讀法。維護者 2026-11-13 選 A（#47 的決定紀錄）：修這幾項，派一位獨立讀者再讀一次，不再做 reviewer 的核對。

這個 change 只改說明與一條判準的寫法。它不新增規範句，也不改守衛與測試。

## What Changes

- **資料主張那一列的說明**：這一列不問的是「沒有回報自己資料的數字或結果」的句子，也就是只轉述別人研究結果的、或只做詮釋的。一句話裡自己的與別人的結果都有，照判準要帶資料類別。判準本身不動。表的註解、文件、規格一起改。
- **三句說明**：「回報」指句子把它寫成自己資料的結果，不論資料算不算得出來；自己的資料包含自己的模型與模擬的輸出；由自己的數字算出來的數字也算。
- **`index.profile-valid` 的判準**：改成直接描述驗證器怎麼定 profile。沒有宣告時是 `default`；有宣告時，名稱要是驗證器接受的，而且帳冊的 schema 版本要允許宣告。
- **規格說測試的那一句**：改成事實。那段掃描只涵蓋兩組案例；其他的拒絕有些有自己的案例、有些沒有，缺口記在 #46。
- 文件裡一處舊的說法換掉。

## Non-Goals

- 不改任何腳本，不改守衛的程式與測試。
- 不新增規範句，不新增字句檢查，不加釘選。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 兩條 requirement 修改：適用條件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`
  - New: (none)
  - Removed: (none)
- GitHub：#70 正文的 Expected 第 3 條改成同樣的寫法；#47 記錄維護者的回覆、計畫與盲驗。
