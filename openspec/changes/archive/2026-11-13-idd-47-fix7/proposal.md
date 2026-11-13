## Why

修正輪 6 之後只驗那一次修正的四席驗證不通過：照維護者定的標準，1 項要修、10 項小修。第六輪的 17 項都已關掉。要修的 1 項在修正輪 6 新加的那一列：判準沒有限定是這篇稿件自己的資料，轉述別人研究結果的句子也會被算進去。維護者 2026-11-13 回覆同意貼出的兩題建議（#47 的決定紀錄）。

這個 change 改兩列的判準，並照那份驗證報告改用語。它不新增規範句，也不改守衛的程式。

## What Changes

- **兩列的判準**
  - `index.data-claims-carry-data-class`：回報這篇稿件自己的資料得出的數字或結果的命題，帶的是資料類別。轉述別人研究的句子維持 `external`；只做詮釋的句子不在這一列。
  - `index.profile-valid`：補上「照帳冊的 schema 版本」。
- **規格的用語**
  - 不再點名新列的編號與負責人，改成和文件一樣的寫法。
  - 盲驗把關的範圍縮小成它實際涵蓋的：結果與表的範圍的題目。清單上其餘的項目寫明只靠審查。
  - 掃描只涵蓋兩組拒絕案例這件事寫明；其他檢查的拒絕由手寫的案例測。
  - 說明文件那條的清單補上「第一條符合的規則決定」。
  - default 帳冊的數字：寫成「沒有任何一列拿它的數字去對產物」。
- **適用條件**：帳冊的行先去掉前後的空白再判斷是不是空的、是不是註解；一行裡有兩個 `id` 鍵時取最後一個，和驗證器的讀法一樣。
- **文件**：描述守衛的那一段寫明 `VERIFICATION.md` 的三個字句各是什麼。

## Non-Goals

- 不改任何腳本，不改守衛的程式與測試。測試還不夠嚴的地方（其他釘選、守衛的 11 處拒絕）寫成已知的缺口，留到守衛搬到 Swift 時處理（#46）。
- 不新增規範句，不新增字句檢查，不加釘選。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 四條 requirement 修改：適用條件、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`
  - New: (none)
  - Removed: (none)
- GitHub：#70 的正文（Expected 第 3 條的寫法，以及兩個欄位哪一個必填）；#46 留 note（守衛的測試缺口）；#47 記錄維護者的回覆、計畫與盲驗。
