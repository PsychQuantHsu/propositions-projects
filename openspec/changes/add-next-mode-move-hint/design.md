## Context

`propositions:construct` 的 next 模式依 `structure-state.py` 的輸出提出最多三個候選，每個候選寫明掛點、關係與連接詞、推進的承諾、預期的 `claim_type`。候選沒有寫這一句要做什麼。

#33 建立了帶類型的連結清單 `plugins/propositions/catalog/links.csv`，其中 `next` 連結記錄「這個 `move` 之後接哪個 `move`」的觀察次數，並由 `article-construction` 規定 next 模式這一版不讀它。#36 的量測與維護者 2026-11-06 的決定解除了這個限制，範圍是縮小版。

限制：`.claude/rules/swift-is-the-implementation-language.md` 禁止在既有 Python 上新增功能（新的參數、輸出欄位、檢查規則都算）。本 change 用兩個現成的查詢完成，已在截短成草稿的真實附檔上驗證過，含帶 `head: "pending"` 的情形。

## Goals / Non-Goals

**Goals:**

- 每個候選說出這一句預期的 `move`。
- 候選的 `move` 參考連結清單裡，目前這個 `move` 之後最常見的三個走法。
- 既有的候選規則不變：順序、第一個候選、掛點與關係都照舊。
- 工具查不到東西時，next 模式照常完成。

**Non-Goals:**

- 不新增工具、參數或 Python 行為。
- 不改候選的先後順序，也不用連結清單替候選打分。
- 不用連結清單決定關係：量測顯示沒有提升。
- 不把未出現過的走法標成不可能，也不對它警告（#33 的決定）。
- 不把 `move` 變成必填欄位，也不改 S1–S9。
- 不評估提示能否讓候選句子寫得更好：本 change 只量得到 `move` 的命中，句子的內容要等維護者實際使用。

## Decisions

### 提示依下一步的 move 加總，不看列

連結清單一個 `(to, relation)` 組合一列，同一個 `move` 可能佔好幾列。以 `recap` 為例，前三列是 recap、recap、compare，只有兩個 `move`；依 `to` 加總才是 recap 8、compare 2。量到的命中率是以 `move` 為單位，提示要跟它一致，所以 skill 先加總再取前三。同分時依清單裡第一次出現的順序。

### 查全部稿件，不加類型或標籤過濾

限定段落類型後樣本太小：實證稿的結果句在討論段只有 6 次觀察（2、1、1、1、1），沒有區分力。跨稿件的量測顯示，別篇、別文類的表仍有提升（43%／28%、67%／40%），所以不必依 profile 限定。

### END 算一個走法

命中率把段落結束記為 `END`，與其他 `move` 同列比較，提示也這樣算。`END` 在前三裡表示這個 `move` 之後常常換段；它讓「開新段」的候選多一個依據，但不強制。`END` 不是 `move`，不能寫進候選的 **Does**。提示描述的是同一段內的接續，所以開新段的候選自己從詞彙選 `move`，不受提示限制。

### 提示不改候選的順序與掛點

分組量測顯示，真正由規格決定第一個候選的位置只佔 9%（實證稿）與 4%（數學稿），其餘位置連結清單才有發揮空間。提示只寫進候選的 `move`，既有的「有等頭的子句」與「有未兌現的 announcement」規則不受影響，連結清單也不會把判斷帶離承諾與結構。

### 候選的 move 是詞彙裡的值，或寫 none fits

沿用 #33 的規則：不選相近的值。next 模式是提議，不是標註，所以沒有合適的值時候選仍然成立，寫 `none fits` 並說明這一句要做什麼，不中止。

## Implementation Contract

**Behavior.** next 模式在 N3 之後多一個步驟：讀最後一句的 `move`，查它之後的走法，回報前三個 `move` 與次數，並說明這是觀察到的走法，不是規則。N4 的每個候選多一項 **Does**：這一句預期的 `move`。N5 不變。

**Interface.** 兩個現成查詢，都由 skill 的指令列呼叫：

- `structure-links.py` 的 `sentence` 子命令，帶 `--jsonl`、`--at <N2 回報的 position>`、`--no-text`、`--format json`；讀 JSON 的 `move`（沒有標註時是 null）。
- `structure-links.py` 的 `catalog` 子命令，帶 `--from <move>`、`--kind next`、`--format json`，不帶 `--type`、`--label`；讀 `seen` 陣列的 `to` 與 `total`。文字輸出的欄數隨標籤而變，不適合用來加總。

**Failure modes.** 以下三種情形都略過提示、用一行說明原因，next 模式照常完成，候選仍然寫 **Does**：最後一句沒有 `move`；連結清單沒有這個 `move` 的 `next` 走法；任一查詢非零結束（例如缺 `links.csv` 或 PyYAML）。附檔本身有問題的情形由 N1 先擋下，不到這一步。

**Acceptance.**

- `tests/test_structure_links.py` 的測試確認：Next mode 段落呼叫這兩個查詢、不再寫 does not read、候選清單有 **Does**；`sentence` 在帶 `head: "pending"` 的草稿上 exit 0；`structure-state.py` 的輸出與 `links.csv` 存不存在無關。
- 全套測試通過，CI gate 通過。
- 實跑驗收：subagent 只讀 skill 的 Next mode 段落，分別處理三份草稿（結尾是帶 `pending` 的句子、結尾沒有等頭的子句、結尾沒有 `move`），檢查每個候選都有 **Does**、前三個依 `move` 加總、第一個候選的規則沒變、沒有 `move` 時略過提示、檔案指紋不變。

**Scope.** 範圍內：`construct` 的 Next mode 段落、`article-construction` spec、文件、版本號、回歸測試。範圍外：任何 Python 腳本、`links.csv` 的內容與格式、Annotate 與 Explain 模式。

## Risks / Trade-offs

- [只有兩篇稿件，一篇實證、一篇數學] → 提示明說是觀察到的走法，不設門檻、不警告。
- [命中的是 `move`，不是句子內容] → 維護者的實際體驗仍是未知數，保留為 #36 的 Residue；`propositions` 的版本說明不宣稱候選變好。
- [`move` 加總由模型做，不是工具] → 用實跑驗收檢查；確定性的加總要新增工具輸出，依 Swift 規則留到 `structure-links.py` 移植時再做。
- [候選多一項，輸出變長] → 只多一行，候選上限仍是三個。
