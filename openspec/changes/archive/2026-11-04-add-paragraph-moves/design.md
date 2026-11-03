## Context

格式 2.0 的附檔記了每句的 `head`、`relation`，以及承諾與章節角色；這些說明句子怎麼接，沒有說明這句在做什麼。#33 的討論定了方向：一筆可能性是一個段落類型與其步驟，依這句在做什麼來分岔，先只用 YAML，目錄沒有的走法不提示，目錄隨 plugin 發布且不含稿件文字。維護者指定的重點是看清句子與句子之間的關係。

現況的限制：plugin 腳本目前只用 Python 標準庫，repo 沒有 CI，`validate-structure.py` 不拒絕未知欄位。兩篇參考稿件（294、306 句）都已有格式 2.0 附檔，放在各自的私有 repo。

**In scope**：步驟與段落類型的詞彙、附檔欄位與 S9、讀法工具、目錄產生、量測、只標步驟的批次模式、`construct` 與 `construct-batch` 的流程、兩篇稿件全篇標註。

**Out of scope**：next 模式引用目錄、標記「不可能」的走法、對走法順序的任何檢查、#34 的 `note` 問題。

## Goals / Non-Goals

**Goals:**

- 兩篇參考稿件的每一句，都讀得出「在做什麼、掛在哪一句、什麼關係」。
- 量得出步驟標註夠不夠穩定，也量得出這一層有沒有多帶來東西。
- 既有 2.0 附檔不改也照常通過，也不需要新依賴。

**Non-Goals:**

- 預測下一句。這次只報告命中率，不設門檻。
- 把目錄當規則。作者可以寫目錄裡沒有的走法。

## Decisions

### 步驟和關係分開記，不合併

`move` 記這句在做什麼，`head`、`relation` 記它怎麼接。讀法工具把兩者合起來呈現。

替代方案是把步驟併進關係詞彙。不採用：實證稿唯一重複的序列出現在目的總結段與未來方向段，同一組連接標籤對應完全不同的工作，一個值表達不了兩件事；而且 10 個關係已經用在兩篇稿件上，改動它們要重標依存樹。

### 步驟要說明段落內的功能，不重複 `claim_type`

`claim_type` 記這句是什麼性質的主張（定義、結果、詮釋），`move` 記它在這段裡負責什麼。同一個 `claim` 可以是「指出缺口」，也可以是「提出之後的方向」。`structure-metrics.py` 報告步驟和 `claim_type` 的 Cramér's V，兩者幾乎一一對應時就代表這一層沒有多帶來東西，要回頭修訂詞彙。

### 詞彙封閉，走法開放

`vocabulary.yaml` 是封閉清單，S9 檢查值是否在清單裡，避免同一件事出現十種寫法。但步驟的順序不檢查：#33 定案目錄沒有的走法不提示。詞彙缺了就停下來回報，不選近似值，這和關係詞彙的紀律相同。

詞彙之後會隨稿件增加而長，所以新增步驟只要改 `vocabulary.yaml` 並通過測試，不必改 spec；spec 只規定檔案的形狀與檢查方式。

### 手寫的詞彙和產生的目錄是兩個檔案

`vocabulary.yaml` 手寫，定義有哪些值。目錄由工具從附檔產生，記走法的次數。

替代方案是同一個檔案裡手寫走法。不採用：次數會和附檔分岔，#33 也要求統計能重新產生。PyYAML 寫回會丟掉手寫的註解與排版，混在一起也不好維護。

產生的目錄只含 id、關係名、承諾種類、次數與標籤（`empirical`、`default`），不含文字、proposition id、段落 id 或路徑。這是公開 repo 的要求，由 spec 的 scenario 與測試把關。

### 目錄是帶類型的連結清單，不是 DAG（全篇標完後追加）

第一版目錄是 YAML（`paragraph-catalog.yaml`），只記「段落類型 → 步驟 → 下一步」。全篇標完後維護者問到要不要寫成 DAG、怎麼知道所有可能的連結。量了兩篇的標註：

- 步驟之間的走法有環：24 個步驟有 136 種相接，21 個步驟會接自己，其餘步驟裡 23 個互相連成環；15 個段落類型有 13 個有環。例如「定義 → 舉例 → 定義」是正常的寫法。硬改成 DAG 就得丟掉真實的走法。
- 具體句子只看 `head` 是無環的（每段一棵樹），`cites` 由 R3 保證無環；兩者混在一起才出現 2 到 3 句的小環。所以連結要分種類存，不能混成一張圖。
- 舊目錄漏掉段落第一句的 `head`（5）、段落之間的 `head`（134）、跨段的 `cites`（408）與承諾的兌現（46）。

所以目錄改成帶類型的連結清單：一種連結一列，`kind` 是封閉的六種（`next`、`head`、`also`、`cites`、`discharge`、`paragraph`）。它是有向圖的邊表，不要求無環。沒有巢狀以後，它就是一張表，所以改用 CSV：Python 標準庫讀得了，R 與試算表也能直接開。手寫的 `vocabulary.yaml` 有說明文字，仍用 YAML。

方向：`next` 照閱讀順序；其他種類都從依賴的一方指向被依賴的一方，和 `head`、`cites` 的方向一致。`discharge` 的 `relation` 欄放承諾種類，因為那是這條連結的性質；`cites` 沒有關係，留空。

### 「所有可能」只分看過與沒看過

「看過的」存在目錄裡，附次數。「沒看過的」由 `structure-links.py catalog --unseen` 用詞彙算補集，不另外存：存了就會和詞彙或目錄分岔。「不可能的」不做：兩篇稿件判斷不出來，沒看過不等於不可能，而且 #33 定案目錄沒有的走法不提示。要有這一類，得由人親手標，屬於之後的決定。

### 查詢工具

`structure-links.py` 有兩個子命令。`sentence` 從帳冊與附檔讀出一句的所有連結，方向用和目錄同一套定義（`out` 是這一句在 `from` 端），所以單句的輸出可以直接對照目錄的列。`catalog` 查目錄：給一個值（`--from` 或 `--to`），列出看過的連結與次數；加 `--unseen` 時列出詞彙允許但沒看過的另一端。輸入值都要在詞彙裡，打錯字會報錯，不會安靜地回空結果。

### 讀 YAML 用 PyYAML，只在需要時載入

替代方案有兩個：自己寫 YAML 子集解析器，或同時發布一份 JSON。前者是不該自己維護的東西；後者多一份會分岔的檔案。所以 `_lib/move_vocabulary.py` 在函式內 import `yaml`，失敗時丟 `InputError` 並點名 PyYAML。沒有 `move`、`type` 的附檔走不到這段，既有使用者不受影響。

### 不升 `structure_version`

新欄位是選填，舊工具讀到也不會錯，舊附檔也不用改，所以不需要 2.0 那樣的遷移。

### 讀法工具是主要成果

`structure-explain.py` 依樹的深度縮排，每行寫「第幾句、在做什麼、掛在第幾句、白話的關係（關係名）」。關係的白話說明放在工具裡的固定對照表：

| relation | 說明 |
|---|---|
| `continue` | 接續 |
| `restatement` | 換句話說 |
| `specification` | 具體說明 |
| `instance` | 舉例說明 |
| `addition` | 補充 |
| `contrast` | 對照 |
| `reason` | 說明理由 |
| `consequence` | 推出結果 |
| `sequence` | 接著下一步 |
| `basis` | 用到 |

例如：

```text
p-19  目的總結段
#138  說目的            段根
  #139  說對照基準      具體說明 #138（specification）
  #140  說關注點        具體說明 #138（specification）
    #141  預告貢獻      接續 #140（continue）
```

### 步驟靠模型標，所以一定要量一致性

標註的是模型，不是人，看起來合理不代表穩定。先試標兩篇各一節定出慣例，全篇標完後，由另一個獨立的 subagent 只看詞彙與句子，重標兩篇各至少 15 段、合計至少 60 句，不給它第一次的結果，再算 Cohen's κ。κ 低於 0.6 就修訂詞彙或定義再量一次；第二次仍低於 0.6 就停下來回報，不宣告完成。0.6 是提議值，在 Landis 與 Koch 的常用分級裡屬於 substantial 的下限。κ 量到的是模型之間的一致，不等於人讀起來清楚，這點會寫在結果裡。

### 種子詞彙

試標前的起點。試標可以增刪，最後以 `vocabulary.yaml` 為準。

**步驟（21 個）：** `set-context`、`report-prior`、`identify-gap`、`state-goal`、`state-expectation`、`preview`、`define`、`set-assumption`、`describe-procedure`、`describe-data`、`state-result`、`derive`、`open-case`、`give-example`、`explain-why`、`rule-out`、`interpret`、`compare`、`qualify`、`conclude`、`propose-next`。

**段落類型（13 個）：** `background`、`gap`、`goal-summary`、`roadmap`、`setup`、`method`、`result-report`、`alternative-test`、`theorem-statement`、`proof`、`discussion`、`future-direction`、`remark`。

## Risks / Trade-offs

- **詞彙太細或太粗** → 太細標不一致，太粗只是換名字的關係標籤；由 κ 與 Cramér's V 把關。
- **標註成本** → 兩篇 600 句多標一層；用只標步驟的批次模式，不重做依存樹。
- **目錄偏向這兩篇** → 目錄標出每個值來自哪類稿件與次數，不當成規則；其他文類可能要新增步驟。
- **新依賴** → 用到 `move` 才需要 PyYAML，缺了明確報錯；沒有這兩個欄位的附檔不受影響。
- **「看得清楚」量不到** → κ 與覆蓋率只是必要條件；是否真的更清楚，要等維護者實際讀過讀法工具的輸出。

## Migration Plan

沒有格式遷移。兩篇稿件的附檔在暫存位置標完、通過 S1–S9，並經維護者確認後才寫入各自的 repo；`main.jsonl` 不動。要退回只需移除 `move`、`type` 兩個欄位。

## Open Questions

(none)：詞彙內容由試標決定，κ 的門檻已在上方定案，next 模式是否引用目錄屬於這個 change 之後的決定。
