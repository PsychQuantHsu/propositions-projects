## Why

#47 的第二輪驗證不通過。八位 reviewer 找到的 34 項裡，有 12 項是同一個根源：結果規則把「檢查跑過、沒有發現」算成通過，但現有的檢查不回報它實際檢查了哪些單位，所以每一條安靜略過的路徑都會讓沒被檢查的單位通過。第一輪逐條補過，第二輪又找到幾條。

第二輪之後對 45 條檢查逐支讀過程式，列出約 340 條「沒有檢查某個單位、輸出裡也看不出來」的路徑（數目與例子在 #68），並確認沒有任何一條檢查會列出它檢查過的單位。用文字列出每條檢查實際檢查什麼不可能準確，所以這一輪改的是規則的預設，不再維護清單。

## What Changes

- **通過的條件**：機械檢查的列，要檢查的報告把這個單位列為檢查過、而且沒有發現算在它身上，才算通過；其餘是沒檢查。現在沒有檢查這樣回報，所以機械檢查的列今天對任何單位都不會是通過（#68）。這不改變今天任何一篇文章的結果：有六列缺口適用於每一篇文章。
- **刪除**「檢查沒跑過」的七種情況與 R9 沒有定理類環境的特例。它們是「除此之外都算跑過」的寫法，漏一條就把沒檢查的算成通過。
- **驗證紀錄**：紀錄要自己顯示它做了這一列的檢查、而且讀的是現在的版本，才算數。現在的格式兩樣都顯示不出來，所以在 #62 之前沒有紀錄算數。刪除用日期與 `evidence_snapshot` 推斷時效、從 checklist 讀出是哪一種閱讀的規則。
- **發現一定算在某一列、某個單位**：對不到任何判準的發現算在所有指名那條檢查的列；整篇為單位的列，發現都算在整篇；指名的不是這一列適用的命題（已退役的命題、紀錄、章節、沒有指名）時，算在這一列適用的每個單位；環的錯誤也這樣算。
- **適用條件讀不出來時是沒檢查**，不是不適用：欄位不存在、profile 不合法、命題沒有附檔紀錄、章節計畫無效。
- **判定過的發現**有了分支：判定違反就是沒通過，判定沒有違反就不再算。
- **寫明通過的意思**：那條檢查檢查過這個單位、沒有回報問題；不是判準被證明成立。
- 表多一列缺口 `index.profile-fits-manuscript`（#70）；三列判準改寫（`completeness.thesis-stated`、`index.extraction-covers-text`、`index.cites-complete`）。
- 文件的幾處說明改正：引用 `proofread` 技能的那一句、檢查清單的共同性質、`not_computable` 的理由、定理邊界稽核的排除理由。過不了的原因加上 #68、#69、#70。
- **外部來源的標記**（維護者 2026-11-12 交給實作者決定）：列多一個欄位 `external_source: true`，只出現在要查稿件 repo 以外來源的三列。它不是 `verified_by` 的值，因為三列裡有一列由閱讀判斷；#50 補上檢查之後標記仍在。
- **Swift 規則的例外**（維護者 2026-11-12：「幫我改規則」）：`.claude/rules/swift-is-the-implementation-language.md` 加第 3 類例外，守衛測試在 #46 建好 package 之前可以加在既有的 pytest 檔。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式，不實作任何缺口的檢查。
- 不改寫判準去貼合程式的細節。檢查比判準弱的地方由檢查那一側修。
- 不升版：這個 change 改的內容還沒發布過，版本維持 0.11.0。
- 維護者 2026-11-12 回覆了四件事（紀錄在 #47）：審表之後動過的列全部維持；Swift 規則檔加例外；「外部工具」用獨立的欄位標記；「通過的條件」維持這個 change 的改法。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 九條 requirement 修改：資料檔的欄位、類別、適用條件、已實作的檢查、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`plugins/propositions/docs/VERIFICATION.md`、`tests/test_plugin_payload_tracked.py`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
- GitHub：新開 #68、#69、#70 並加進 #45 的子題清單；在 #49、#50、#57、#62、#66 留 note；#47 記錄盲驗的題目與答案。
