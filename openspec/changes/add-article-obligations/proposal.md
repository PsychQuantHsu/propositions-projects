## Why

「完全合理」現在沒有定義。判斷一篇文章合不合理的檢查已經有 44 條，分散在七個來源（三個驗證器、抽取覆蓋檢查、帳冊重排工具的試跑、跨檔案稽核、`proofread` 的逐筆流程）、用好幾套編號，沒有一處說一篇文章要滿足哪些才算合理，也分不出哪些是在檢查帳冊、哪些是在檢查文章。#45 的其他子題（#46、#49、#50、#53、#54）都需要同一份定義當驗收標準，所以這一張（#47）先做。

## What Changes

- 新增資料檔 `plugins/propositions/catalog/obligations.yaml`（下稱義務表）：一列一條，寫明類別、適用條件、判準、對應的檢查、驗證方式，以及機械檢查報警告時算什麼。
- 每一列屬於兩種類別之一：前提（沒過時要改帳冊、附檔或驗證紀錄）、義務（沒過時要改稿件，或要作者決定）。
- 以機械檢查驗的每一列都寫明警告怎麼算：要判定（判定之前算沒檢查），或只是資訊（列在報告，這一列算通過）。維護者定為只是資訊的發現（交叉弧、孤立命題）也各佔一列，不另立類別；其他列一律要判定。
- 靠模型判斷的列（`proofread` 的每一層）都要另一個模型複查才算通過；一筆通過的判定只對那次閱讀實際做過的檢查算數。
- 義務依原則分成七組（依賴、承諾、支持、一致、真實與來源、位置、完成），一組對 `che-axiom-systems` 的一條公理；這個 change 只填得出「依賴」那一組的公理，其餘由 #48 補。
- 檢查欄只填已經實作的檢查；還沒有的標成缺口，並指到負責的 issue。沒有負責 issue 的缺口在這個 change 裡開。
- 新增說明文件 `plugins/propositions/docs/OBLIGATIONS.md`：定義欄位、兩種類別、每一列對一筆命題的四種結果（通過、沒通過、沒檢查、不適用），以及驗收：每一列都是通過或不適用，才算完全合理。文件不重抄各列。
- 文件寫明現在沒有任何文章過得了驗收，以及三個原因與各自負責的 issue；多檔稿件另有一列過不了（#59）。
- 在既有的測試檔加守衛：格式、封閉的鍵與值、每條已實作的檢查都在表裡、每個詞彙值都被提到。
- `CLAUDE.md` 與兩份 README 列出義務表；`propositions` plugin 升到 0.11.0。
- 不改任何腳本，也不改帳冊、結構附檔、驗證紀錄的格式。這個 change 沒有讀義務表的工具；照表算出結果的程式留給後面的子題。

## Capabilities

### New Capabilities

- `article-obligations`: 義務表的格式與內容規則、兩種類別、七組、已實作檢查的清單與缺口、驗證方式與警告怎麼算、四種結果與驗收的定義、說明文件與守衛測試。

### Modified Capabilities

(none)

## Impact

- Affected specs: `article-obligations`（新增）
- Affected code:
  - New: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`
  - Modified: `tests/test_plugin_payload_tracked.py`、`CLAUDE.md`、`README.md`、`plugins/propositions/README.md`、`plugins/propositions/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`
  - Removed: (none)
- GitHub：為沒有負責 issue 的缺口開 issue、掛在 #45 底下；完成後在 #47 貼完成紀錄。
- Python 腳本的行為不變，符合 `.claude/rules/swift-is-the-implementation-language.md`。
