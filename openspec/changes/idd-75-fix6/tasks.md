## 1. 擋下的一項

- [x] 1.1 沒讀的被引入檔改記在既有紀錄的 `note`，對應 Requirement「Derive and draft build an outline without inventing content」「A paragraph record holds at least one point」「Revising keeps ids stable and never loses a source」「Only the author's explicit statement in the current message approves」與第六輪報告第 1、5 列。完成時：反推不為它寫紀錄或來源指標；`note` 掛在哪一筆有固定順序；沒有紀錄可掛時只告訴作者；確認展示 `note`；修改時 `note` 跟著紀錄。驗證：一位只拿到 SKILL.md 的 agent 對「同一個被忽略的檔在兩段裡各被引入一次、註解裡另有一份」的稿件照反推做到第 8 步，做得完，寫入檢查與來源指標都印 `ok`。
  - 一位只拿到 SKILL.md 與 OUTLINE.md 的 agent 對 `0288fe6` 的文字照反推做到第 8 步：每一段指令都印 `ok`，兩筆段落紀錄的 `note` 各記一句，沒有停下。它指出三處不清楚（原因、檔名的寫法、註解裡的引入），改在 `af3e185`。

## 2. 其餘的文字

- [x] 2.1 狀態與確認，對應 Requirement「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」與第 2、3、9 列。完成時：狀態先跑寫入檢查；檔案打不開時說明是不見或不是可讀的一般檔；追加失敗時先檢查確認紀錄檔，沒過就停下。
- [x] 2.2 保證與限制，對應 Requirement「The outline skill writes only the three outline files」與第 6、15 列。完成時：第二項保證包括 git 目錄；第 9 項已知限制在 SKILL.md、OUTLINE.md 與規格逐項相同。
- [x] 2.3 起草、根目錄與上層目錄，對應 Requirement「The outline is three files beside the ledger」「Derive and draft build an outline without inventing content」與第 4、7、8、11 列。完成時：作者指定的檔先過主稿件的檢查；根目錄是 `/` 時不支援並寫明；最近的上層目錄要問作者；submodule 層數標成尚未決定。
- [x] 2.4 其餘的句子，對應 Requirement「A locator names a passage by a label or by its opening words」「Text from the manuscript and the author never becomes part of a command」與第 10、12、13、14 列。完成時：外層 `check-ignore` 的錯誤算沒有回答；之前寫的來源指標可能解析不了；引入指令對到清單的規則；沒有稿件時帳冊比對的條件。
- [x] 2.5 issue 上的紀錄，對應第 16 到 21 列。完成時：留言 6894490755、#75 正文 Key Decisions 那一列、#84 的 Problem、#78 留言 6955346390 的指令段清單與限制數就地更正；fix5 封存的 tasks 4.4 照第 16 列加註；第 20、21 列寫進 Implementation Complete 給 PR 審。
  - 留言 6894490755 的 Rationale 與 #78 留言 6955346390（指令段清單、10 項限制）已就地更正；#84 留言 6956865735；fix5 封存的 tasks 4.4 已加註；#75 正文那一列在 Implementation Complete 時更新。

## 3. 驗證

- [x] 3.1 19 段指令與 `aa8a63d` 逐段相同；八種組合重跑 389 項。
  - 對 `0288fe6`：19 段與 `aa8a63d` 逐段相同；八種組合 389 項全過（bfs 388 項）。之後的 commit 只改散文，封存前在 `c2af2ad` 再比一次，仍然相同。
- [x] 3.2 文字凍結之後，獨立 agent 對照規格、OUTLINE.md 與 SKILL.md。完成時：找到的都處理，記下對的 commit。
  - 對 `af3e185`：10 項（第一次確認紀錄時的追加檢查、根目錄是 `/` 與 SHALL 衝突、規格一句的位置、`note` 的定義、只由沒讀的檔組成的節、第 8 步不展示 `note`、檔名含特殊字元、狀態的錯誤去路、第 9 項限制的範圍、幾處小字），改在 `c2af2ad`。之後沒有再改指令或規格的行為。
- [x] 3.3 最後一次改 OUTLINE.md 之後盲讀，題組加上這一輪的規則與 J28。完成時：記下讀的 commit、題數與不同的題；讀者標出的句子若再改，改到的題再讀一次。
  - 第二十二位讀者讀 `c2af2ad` 的 OUTLINE.md，230 題（含這一輪的 17 題與 J28）：228 題與預存答案相同；K5 讀者答得對、預存答案寫得太死；K9 少答了一個細節。沒有標兩種讀法或答不出的題，之後 OUTLINE.md 沒有再改。
- [x] 3.4 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
  - `pytest tests/`：872 passed、3 skipped；`spectra validate` 通過、`spectra analyze` 沒有 warning；三個目錄相對於 main 沒有變動。
