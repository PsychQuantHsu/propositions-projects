## 1. 擋下的兩項

- [x] 1.1 稿件不在 git repo、或超過兩層 submodule 時停下並說明，對應 Requirement「The outline is three files beside the ledger」「Text from the manuscript and the author never becomes part of a command」與第三輪報告第 1、20 列。完成時：第一個指令在目錄不是從 `/` 寫起、超過兩層 submodule 時印出 STOP 與原因；skill 的說明不再請作者指定最上層的目錄；規格與說明文件寫明。驗證：非 git 目錄、相對路徑、三層 submodule 三種情況都沒有 ROOT 行。
- [x] 1.2 寫入檢查看原始文字，對應 Requirement「The outline skill writes only the three outline files」與第 2 列。完成時：字串以外的值都要是 JSON 的寫法；jq 讀成無限大的合法數字另外回報；確認紀錄檔的檢查用同一條。驗證：`nan`、`NaN`、`Infinity`、`01`、`.5` 被報出，`1e400` 報成 jq 無法保存的數字，字串裡的同樣文字不報。

## 2. 其餘的指令

- [x] 2.1 帳冊的 `source.file` 從兩個根目錄解析，對應 Requirement「The outline is three files beside the ledger」與第 3 列。完成時：兩個根目錄任一個對到稿件就算；`_meta.json` 的路徑從暫存目錄的清單讀出；文件不再說出自 SCHEMA。驗證：子模組裡寫 `main.tex`、子模組裡照 SCHEMA 範例寫外層路徑、外層帳冊，三種都認得出來。
- [x] 2.2 逐行讀確認紀錄檔，對應 Requirement「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」「Revising keeps ids stable and never loses a source」與第 4 列。完成時：狀態、差異、使用中的 id 與追加之前都逐行讀；有一行不合就失敗；追加什麼都不做並說明檔案被手動改過。驗證：多行的紀錄、同一行兩筆、只有空白的行、`nan` 四種情況。
- [x] 2.3 `.git` 的排除不分大小寫，對應 Requirement「A locator names a passage by a label or by its opening words」「A premise check runs before an outline is shown for approval」「The outline skill writes only the three outline files」與第 12 列。驗證：`.GIT/HEAD` 被擋下。

## 3. 句子與規則

- [x] 3.1 規格、說明文件與 skill 的句子，對應 Requirement「Revising keeps ids stable and never loses a source」「Derive and draft build an outline without inventing content」「The explanatory document describes the outline」與第 5、11、15、16、17、21、22 列。完成時：搬動要點時來源放進 `basis`；`uses` 不影響一節是否照通過時的內容；經由連結目錄引入的 `.tex` 不讀；第二種可以接受的空檔；checker 的定義有 `note`；Scenario 的條件；寫進指令的路徑有哪幾個。
- [x] 3.2 [P] Swift 規則、`CLAUDE.md`、`README.md`、`manuscript-jsonl-sync.md`，對應第 7、8、9、13、14 列。完成時：第 2 類的 jq 只算 SKILL.md 裡的；〈不適用〉第 1 類的接法清單；第 4 類的退場條件；硬規則與同步規則只排除綱要檔；需要 git 的不只綱要 skill。驗證：四個檔各自找得到改過的句子。

## 4. 驗證

- [x] 4.1 SKILL.md 的 18 段指令照寫法逐段實跑，四種組合。完成時：各 194 項全部符合預期。
- [x] 4.2 一位獨立 agent 對照第三輪報告要處理的列，逐列回報已處理與在哪一句。完成時：沒有未處理的；有的話先修再重跑。
- [x] 4.3 獨立讀者重讀最後的 OUTLINE.md，題組加上這一輪改過的規則。完成時：答案與預存的答案全部相同。
- [x] 4.4 全套 pytest 通過；spectra validate 與 spectra analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
