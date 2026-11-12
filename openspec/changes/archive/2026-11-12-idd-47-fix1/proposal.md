## Why

#47 的第一輪驗證不通過。八位 reviewer 找到的問題多數是同一種：義務表的結果規則會把沒檢查到的情況算成通過（行序試跑只報數目、結構驗證器沒評估的規則、沒標註的承諾、套到沒有產物的命題的實證層、命題改寫之後的舊紀錄）。這些規則寫在 requirement 裡，所以修正要改規格。

## What Changes

- 逐個來源寫明什麼算發現、算哪一級：行序試跑的「N 行要搬」是錯誤；稽核腳本 `definite` 以外的嚴重度與覆蓋檢查的兩種輸出都是要判定的發現。
- 寫明發現算在哪個單位：指名命題的算那一筆；成環的算訊息列出的每一筆；不指名命題的算這一列適用的每個單位。
- 「檢查沒跑過」從六種變成七種：加上工具說它沒有評估、或因為別條規則的輸入無效而沒有評估。
- `cites: present` 改成「`cites` 欄不是空的」。整篇單位的 `profile` 有定義。
- 實證層（E1 到 E7 與三列缺口）的適用條件加上四個有資料支持的 `evidence_class`，不再套到 `external` 與沒有產物的命題。
- 驗證紀錄要對得上命題現在的內容才算數。
- 已實作的檢查加上帳冊的 profile 檢查（共 45 條）；排除清單加上 `proofread` 的 location 層與驗證紀錄的 disagreement 警告，各有理由。
- 表多兩列：`index.profile-valid`，以及缺口 `index.structure-faithful`（附檔忠實於稿件，#66）。十列的判準改寫。
- 缺口列的 `unit`、`verified_by`、`on_warning` 寫明是暫定的。Expected 第 2 條的「外部工具」寫明併進機械檢查，以及哪幾列要靠外部來源。
- 守衛：拒絕同一個對照表裡重複的鍵；釘住 #57 三列各對哪一層、`truth.not-refuted` 與 `index.structure-faithful` 是缺口。
- `docs/VERIFICATION.md` 加上對 `docs/OBLIGATIONS.md` 的指引。文件摘要與 `plugin.json` 的描述跟著改。
- 修完之後重跑獨立讀者，題目、答案與對應的 commit 列在 #47。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式。
- 不實作任何缺口的檢查。
- 審表的停點（第一輪第 12 項）不在這個 change 裡解決：修完之後把動過的列列給維護者確認。
- Spectra 封存時 trace 註記指到 workspace 檔的問題另案（#67）。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 九條 requirement 修改：單位、類別、適用條件、已實作的檢查、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`plugins/propositions/docs/VERIFICATION.md`、`tests/test_plugin_payload_tracked.py`、`plugins/propositions/README.md`、`CLAUDE.md`、`plugins/propositions/.claude-plugin/plugin.json`
  - New: (none)
  - Removed: (none)
- GitHub：在 #50、#55、#57、#61、#62 留 note；#45 的子題清單加 #66；#47 記錄盲驗的題目與答案。
