## Context

`plugins/propositions` 有七個 skill，各自處理一層分析：`extract`、`propositions`、`proofread`、`construct`、`construct-batch`、`manuscript-audit`、`clarity-audit`。它們的前提散在各自的文件裡。#40 要一個入口，把順序與前提集中起來。

限制有兩個。`CLAUDE.md` 規定任何寫入帳冊的動作都要先 dry-run 並確認。`.claude/rules/swift-is-the-implementation-language.md` 禁止在既有 Python 上新增功能。

已用真實稿件驗證過的事實：

- `_meta.json` 是否存在，可以判斷有沒有帳冊。
- `structure-metrics.py` 的 JSON 輸出裡，沒有 `moves` 欄位表示沒有標 `move`；有這個欄位時，`proposition_share` 與 `paragraph_share` 表示標了多少，`counts` 與 `type_counts` 是各值的次數。
- `check-extraction-coverage.py` 對全篇跑時，一本已抽完的帳冊仍回 exit 1：參考稿件在 `\begin{document}` 之後有 8 段未覆蓋，一個 `\maketitle`、兩個 `\footnote{`、五段文末內容，表格則自動排除。
- Operation D 沒有建 `main.jsonl`，而驗證器、覆蓋檢查與 `extract` 都假設它存在：缺檔時前兩者 exit 2，`extract` 在 Step 2 當掉（#41）。換成空檔後全部接得上：驗證器通過，覆蓋檢查把正文全列為未覆蓋，`extract` 的 Step 2 與 Step 9 正常。

## Goals / Non-Goals

**Goals:**

- 使用者只說一次，入口判斷下一步。
- 中斷後重跑會接續，不需要進度檔。
- 不繞過任何既有的確認。
- 報告說清楚做到哪裡、發現什麼、下一步是什麼。

**Non-Goals:**

- 不合併或改寫既有的七個 skill。例外見〈Operation D 要建空的帳冊〉。
- 不新增工具、參數或 Python 行為。
- 不代替使用者確認任何寫入。
- 不評論文章好壞，不處理非 LaTeX 來源，不把 Word 或 PDF 轉成 LaTeX。
- 不把判斷進度寫成工具：確定性的狀態查詢留到 Swift 移植時再做。

## Decisions

### 進度只從檔案判斷

不另存進度檔。入口每次都從帳冊與附檔重新判斷，所以中斷、拒絕或換 session 之後再跑一次，自然從還沒完成的步驟接續。進度檔會和檔案本身不一致，而且要多處理一種失敗。

### 狀態是有順序的封閉列舉

七個狀態依序判斷，第一個成立的就是目前的狀態：`no-ledger`、`ledger-invalid`、`ledger-incomplete`、`no-structure`、`structure-invalid`、`no-moves`、`ready`。每個狀態對應一個動作。順序就是前提關係：後面的狀態都假設前面的已經成立。

### 覆蓋檢查要讀片段，不看結束碼

全篇跑覆蓋檢查時，一本已抽完的帳冊也回 exit 1。所以入口把範圍限在 `\begin{document}` 與 `\end{document}` 之間，並讀回傳的片段：只有正文的句子才算沒抽完。不帶句子的 LaTeX 指令、標題、前言、作者貢獻與利益聲明這類文末資訊、附錄的量表、參考文獻都不算。這是模型的判斷，所以報告要列出它判定為不算的片段位置，讓使用者看得到。

`construct` 的 A1 看到任何未覆蓋都會停，而 `\footnote{` 這類殘留在有註腳的稿件裡很常見（#42）。所以入口呼叫 `construct` 或 `construct-batch` 時，把這些片段一起交過去，讓它們不必重新判斷。根因由 #42 修在覆蓋工具。

### 附檔的形狀與文章欠的帳分開判斷

`validate-structure.py` 帶 `--partial` 判斷附檔的形狀；這一步失敗才是 `structure-invalid`。不帶 `--partial` 的檢查另外跑，失敗代表完整文章還欠讀者東西，例如未兌現的承諾，這是分析要找的東西，寫進報告，不算失敗。

### 長稿走 construct-batch

帳冊有 100 筆以上的命題時，結構標註走 `construct-batch`，較短的走 `construct`，與 `construct-batch` 的觸發條件相同。已有依存樹、只缺 `move` 時，不論長短都走 `construct-batch` 的 moves-only 路徑，與 `construct` A1 的規定相同：`construct` 的 annotate 模式會重畫依存樹。

### Operation D 要建空的帳冊

`no-ledger` 走完 Operation D 之後，帳冊必須進到 `ledger-incomplete`。現在它沒有 `main.jsonl`，驗證器 exit 2，入口會判成 `ledger-invalid` 而停下；就算繞過去，`extract` 也會在 Step 2 當掉。修在 Operation D 一處，下游不用動，入口也不需要特例。這是既有的 bug，所以另開 #41，用獨立的 commit 修。在這之前 scaffold 的帳冊仍然沒有 `main.jsonl`：入口停在 `ledger-invalid`，報告說明建一個空檔後重跑，不代為建立。

### 寫入都留在原本的 skill

入口本身不寫稿件、帳冊或附檔，只呼叫 skill。這些 skill 已有 dry-run 與確認，入口不重做，也不代答。報告列出這次有哪些檔案被寫入；沒有任何確認過的寫入時，這些檔案的指紋必須和開始時相同。

### 三個步驟要明確要求才跑

`proofread` 逐筆審查，成本高；`manuscript-audit` 與 `clarity-audit` 回答的問題和結構不同。預設不跑，報告列出它們可以回答什麼。`proofread` 與 `manuscript-audit` 要帳冊通過 `validate-propositions.py`；`clarity-audit` 不需要帳冊，任何狀態都可以跑。

### 測試加在既有的 pytest 檔

Swift 規則要新測試用 Swift Testing，但 repo 還沒有 `Package.swift`，而這個 change 沒有 Swift 程式。入口是 skill 文字，測試只釘住文字，所以加進 `tests/test_plugin_payload_tracked.py`，不新建測試檔，也不為此建立 package。

## Implementation Contract

**Behavior.** 使用者說要分析一篇文章時，入口解析 `LEDGER` 與 `MAIN`（已有帳冊時以 `_meta.json` 的 `source.file` 為準），判斷狀態，回報狀態與接下來要做的事，然後呼叫對應的 skill。那個 skill 完成後重新判斷，直到 `ready`，或有確認被拒絕、或有步驟失敗。到 `ready` 時產出讀法與報告。

**Interface.**

| 狀態 | 判斷 | 動作 |
|---|---|---|
| `no-ledger` | `LEDGER/_meta.json` 不存在 | `propositions` 的 Operation D |
| `ledger-invalid` | `validate-propositions.py` 非零結束 | 停下回報，指向 `propositions` |
| `ledger-incomplete` | 覆蓋檢查回傳正文的未覆蓋片段 | `extract`，一次一節 |
| `no-structure` | `structure.json` 或 `discourse.jsonl` 不存在 | 100 筆以上 `construct-batch`，否則 `construct` |
| `structure-invalid` | `validate-structure.py --partial` 非零結束 | 停下回報，指向 `construct` |
| `no-moves` | 沒有 `moves` 欄位，或 `proposition_share`、`paragraph_share` 小於 1 | `construct-batch` 的 moves-only |
| `ready` | 以上都不成立 | 讀法與報告 |

多檔稿件的覆蓋檢查每個 `\input` 檔各跑一次。

**Failure modes.** 確認被拒絕：停下，回報目前狀態與重跑即可接續。呼叫的 skill 失敗或自己停下：停下，轉述原因，不重試、不繞過。工具本身失敗（exit 2）：停下回報。`ledger-invalid` 與 `structure-invalid` 不自動修。

**Acceptance.**

- `tests/test_plugin_payload_tracked.py` 釘住七個狀態、狀態順序、三個選用步驟、不寫入的規定、覆蓋檢查要讀片段。
- 實跑驗收：subagent 只讀這個 skill，分別判斷五份準備好的目錄（沒有 `_meta.json`、剛 scaffold 的空帳冊、有帳冊沒有附檔、有附檔沒有 `move`、完整），回報的狀態與預先寫好的答案相同，且沒有改動任何檔案。
- 路由驗收：獨立讀者只看八個 skill 的 description，把 10 句請求分給 skill，分析整篇的請求到 `analyze`，其他到原本的 skill。
- 全套測試、CI gate、`spectra validate` 通過，`plugins/propositions/scripts/` 沒有差異。

**Scope.** 範圍內：新的 skill、`article-analysis` spec、文件、版本號、釘住文字的測試。Operation D 的 scaffold 清單（#41）也在範圍內。範圍外：其餘既有 skill 的內容、任何 Python 腳本、`links.csv`、附檔格式。

## Risks / Trade-offs

- [判斷「正文的未覆蓋片段」靠模型] → 報告列出判定為不算的片段位置，由使用者看得到；用實跑驗收檢查。
- [整篇抽取與標註很長] → 一次一節，每一步都有確認；中斷後重跑會接續。
- [入口的 description 搶走其他 skill 的請求] → description 明列不處理的請求，用路由驗收檢查。
- [七個 skill 的前提改了，入口的表沒跟著改] → 入口只寫判斷與路由，不重述各 skill 的內容，測試釘住狀態表。
- [判斷進度由模型照表執行，不是工具] → 確定性的狀態查詢要新增工具輸出，依 Swift 規則留到移植時再做。
