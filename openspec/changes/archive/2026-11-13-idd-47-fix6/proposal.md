## Why

#47 的第六輪驗證不通過：6 項要修、11 項範圍內的小修。八席都完成，第五輪的 7 項都已關掉，這一輪的 6 項是新的。維護者 2026-11-13 回覆「都照建議」（#47 的決定紀錄），定了三件事：表的四個決定、要修的標準照 `/idd-verify` 的定義、修完之後只驗這一次的修正。

這個 change 照那份決定做。它不新增規範句：第六輪有兩項是上一輪加的規範句引出來的，所以這一輪用縮小既有的句子來修。

## What Changes

- **表的四個決定**
  - `index.profile-valid` 的判準改成：帳冊的 profile（有宣告就是宣告的那一個，沒宣告就是 `default`）是驗證器接受的。檢查清單對 `ledger:profile` 的描述跟著改。
  - 新的一列缺口 `index.data-claims-carry-data-class`（前提，負責人 #70）：建立在資料上的命題帶的是資料類別。適用於 `empirical` 的帳冊。
  - 新的一列 `index.abstract-opens-nothing`（前提，`structure:S5`）：摘要裡的命題不開出承諾。適用條件是 `section_role: [abstract]`，所以 `abstract` 從 `unconstrained` 拿掉。
  - default 帳冊裡的數字寫成表的範圍，不加列。
  - 表從 68 列變成 70 列（前提 36、義務 34）。兩列新列由通用的規則管，沒有另外寫進規格的規範句。
- **適用條件**
  - `opens`：每一項的 `id` 與 `kind` 都要被結構驗證器接受。
  - 帳冊的 id 可用：還要帳冊每一行都解析得了，而且 id 是非空字串。
  - 無從判斷的條件當成不成立。
- **規格縮小**
  - 分散在「驗證方式」與「四種結果」兩條 requirement 的五句「文件 SHALL 寫出」拿掉。文件要說明什麼，只留「說明文件」那一條的清單，並寫明這份清單由獨立讀者的盲驗把關。
  - 守衛那一條的「凡是讀文字就能判定的」改成列舉守衛真的檢查的項目。
  - 「拒絕的測試在守衛不再回報時要失敗」改成一段掃描：對兩組拒絕案例的每一個，沒改動的表不命中、改動後恰好一則訊息命中。
- **守衛**：`entries` 不是清單時回報問題，不當掉；兩個被指出的測試改成找各自的訊息；加一個釘選缺口的負責人被改掉的案例；兩句話的字句比對加上邊界。
- **文字**：拿掉「文章可以在這件事沒檢查時被稱為完全合理」；「退役那一列」管的是每一個 `retired` 鍵；清點只涵蓋四組詞彙；`SCHEMA.md` 對兩個欄位的規定。
- Swift 規則檔的例外改一句：守衛檢查 `VERIFICATION.md` 的三個字句，一個指到義務表文件，兩個限縮它自己的說法。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式，不實作任何缺口的檢查。
- 不新增規範句，不新增字句檢查。
- 不改 `index.retirements-hold` 的判準；它和單位定義的關係寫在文件裡。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 七條 requirement 修改：適用條件、已實作的檢查、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`tests/test_plugin_payload_tracked.py`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
- GitHub：#70 的正文補上資料類別那條檢查；#48 的 note 更新列數；#50 補一則 note 並更正第四輪那一句；#47 記錄維護者的回覆、計畫與盲驗。
