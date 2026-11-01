## Context

#26 問「已知 prop_t，prop_{t+1} 該寫什麼」。使用者在 2026-11-02 把問題定調：「你要從建構一篇完整的文章的觀點來思考這個問題」。

範例稿件是期刊版的 Cheng, Lay, Hsu, & Tsai (2021)（見 `docs/REFERENCE-MANUSCRIPTS.md`）。逐段讀完全文，下一句由三層同時決定：

1. **文章還欠讀者什麼**。引言宣告計畫（“This article is organized as follows. We first … We then … We wrap up …”），§1.1 由「We first」兌現，§4 由「We wrap up」兌現。§1.2 用問句提出研究問題，又用「In summary, the main goal of this study is …」宣告兩個目的，§3.2 與 §4 回答。§3.3 的「We now examine an alternative explanation」在同一節內兌現；§1.1 最後一句「… which we now describe」由下一節 §1.2 兌現。§1.2 鋪陳的顧慮（response bias、類別數有限），§3.3 用「mentioned in Section 1.2」回頭用上。
2. **現在在計畫的哪一節、這一節的角色是什麼**。§1.1 雖然放在 Introduction 底下，做的是形式定義；結果節報告與直接詮釋；討論節重述目的、綜合發現、限制、未來工作。
3. **和上一句的局部關係**。由連接詞標出：That is、In other words（換句話說），To illustrate（舉例），Moreover（並列），However（對立），Therefore、Accordingly、Consequently（推出），We now（開新的一條線）。

現有帳冊只記錄每句主張什麼與邏輯依賴（`cites`），三層都沒有。`verification.jsonl` 已經建立「帳冊當索引、其他資訊放附檔」的先例：附檔有自己的 validator，`validate-propositions.py` 不讀它。

利害關係人：寫稿的作者（要知道下一句該做什麼）、審稿前的自查（要知道整篇有沒有欠帳）、本 plugin 的其他 skill（extract 產生帳冊，本變更讀帳冊）。

## Goals / Non-Goals

**Goals:**

- 定義一個從整篇文章出發的建構模型，三層各有封閉詞彙：承諾（commitment）、章節角色（section role）、相鄰關係（relation）。
- 用附檔記錄模型，機械檢查它（S1–S6），並能在任一位置回報「文章此刻的狀態」，作為 prop_{t+1} 的機械答案。
- 提供 skill 兩種用法：替既有稿件標註結構（稽核），以及替寫到一半的稿件提出下一句的候選（寫作）。
- 在範例稿件期刊版上完整跑一次，用結果檢驗詞彙是否夠用。

**Non-Goals:**

- 不改 `main.jsonl` 的 schema，也不改 `validate-propositions.py` 的 R1–R13。
- 不自動寫稿：下一步模式只提出候選句，不寫進稿件或帳冊。
- 不檢查標註在語意上對不對（關係選得對不對、承諾是否真的被兌現）：validator 只檢查結構一致性，語意判斷靠人審，比照 proofread 與 validator 的分工。
- 不做段落層級的 rhetorical move 標註（Swales 式 move/step）。理由見決策「三層模型：承諾、章節角色、相鄰關係」。
- 不從大量稿件學習轉移機率；本變更只有一篇範例。
- 數學稿件的 worked example 不在本變更；詞彙設計時已涵蓋定理與證明（見決策「章節角色用單一封閉詞彙」），實測留給後續。
- 不改 `propositions:extract`。

## Decisions

### 附檔而非擴充帳冊欄位

結構資訊放在帳冊旁的兩個附檔：`structure.json`（文章層次）與 `discourse.jsonl`（每個 prop 一筆）。不在 `main.jsonl` 加欄位。

理由：(1) 帳冊是許多 skill 共用的契約，加欄位要升 schema 版本並牽動 R1–R13 的向後相容；(2) 結構標註比逐句抽取主觀，分開存放可以單獨重做而不碰帳冊；(3) 與 `verification.jsonl` 的先例一致。

考慮過的替代：在每個 prop 加 `relation`／`opens`／`discharges` 欄位。被否決，原因同上第 (1)(2) 點。

### 三層模型：承諾、章節角色、相鄰關係

prop_{t+1} 由三層決定，三層分開記錄：

- 承諾：哪些 prop 開出承諾、哪些 prop 兌現。記在 `discourse.jsonl` 的 `opens`／`discharges`。
- 章節角色：每節在全文計畫裡的功能。記在 `structure.json` 的 `sections`。
- 相鄰關係：每個 prop 和前一個 prop 的關係。記在 `discourse.jsonl` 的 `relation`。

考慮過的替代：段落層級的 rhetorical move（例如引言的「建立領域、指出缺口、佔據缺口」）。被否決：move 的功能大部分已由「章節角色＋承諾種類」表達（指出缺口通常開出 `question`，佔據缺口開出 `aim` 或 `plan`），再加一層會讓同一件事有兩種標法。若 worked example 顯示需要，另開變更。

### 相鄰關係詞彙以 PDTB-3 sense 為骨架

`relation` 是 prop 和**閱讀順序上前一個 prop** 的關係。以 Penn Discourse Treebank 3 的 sense 階層為骨架，刪到範例稿件會用到的類別，再補上兩個結構性的值（`shift`、`return`）。以下是封閉列舉，**只有這 12 個值，不得依性質相似類推新值**：

| 值 | 意義 | 典型標記 | PDTB-3 |
|---|---|---|---|
| `start` | 全文第一個 prop。只能出現一次，且只能在第一筆 | — | — |
| `shift` | 開新的一條線：和前一個 prop 沒有局部關係，接的是章節計畫或某個未兌現的承諾 | 段落或章節開頭；We now turn to | — |
| `continue` | 同一條線往下講，沒有比「同一主題的下一個陳述」更具體的關係 | 無連接詞 | EntRel |
| `restatement` | 內容與前一個 prop 相同或等價，換一種說法 | That is; In other words | Expansion.Equivalence |
| `specification` | 把前一個 prop 講得更具體、更細 | Specifically; In particular | Expansion.Level-of-detail |
| `instance` | 舉例 | For example; To illustrate; e.g. | Expansion.Instantiation |
| `addition` | 同一類的另一項 | Moreover; Furthermore; In addition | Expansion.Conjunction |
| `contrast` | 對立、讓步或更正 | However; Although; Rather | Comparison.Contrast / Concession; Expansion.Substitution |
| `reason` | 說明前一個 prop 的理由或原因 | because; since; due to | Contingency.Cause.Reason |
| `consequence` | 從前一個 prop 推出的結果或結論，包括從證據下的詮釋 | Therefore; Thus; Accordingly; These results suggest | Contingency.Cause.Result（含 +Belief） |
| `sequence` | 程序或時間上的下一步 | Then; Next; First … Finally | Temporal.Asynchronous |
| `return` | 回到較早的一條線，必須以 `refers_to` 指出回指的 prop | As mentioned in Section 1.2; Recall that | — |

同時符合兩個值時依此優先序取第一個：`return` > `restatement` > `specification` > `instance` > `contrast` > `reason` > `consequence` > `sequence` > `addition` > `continue`。`shift` 只在沒有任何局部關係時使用。

考慮過的替代：(a) 從範例稿件歸納自己的詞彙，被否決，因為只看一篇容易過度貼合；(b) Rhetorical Structure Theory，被否決，因為它是樹狀結構，關係的兩端常是大段落，和「相鄰兩個 prop」的線性問題對不上。

### 子句層級的 prop 之間也標關係

一個句子被拆成兩個 prop 時，後一個子句也有 `relation`。理由：最明確的連接詞常在句中（“…; rather, …”、“That is, …”），帳冊以子句為單位，不標就漏掉最清楚的訊號。

### 跨段落與跨節照常標關係

「相鄰」指整份帳冊的閱讀順序（`main.jsonl` 的行序；多檔稿件是攤平 `\input` 後的順序）。段落或章節的第一個 prop 也標：和前一句有局部關係就照實標（例如章節結尾的 announcement 被下一節第一句兌現時，常是 `continue` 或 `specification`），沒有就標 `shift`，回到更早的線就標 `return`。

### 承諾種類與兌現規則

`opens` 列出這個 prop 開出的承諾，每個承諾有 `id` 與 `kind`；`discharges` 列出它兌現的承諾 `id`。以下是封閉列舉，**只有這 7 種，不得依性質相似類推新種類**：

| kind | 什麼算 | 什麼算兌現 | 未兌現 |
|---|---|---|---|
| `question` | 文章要回答的研究問題，包括寫成問句或「whether …」的形式 | 給出答案的 prop | 錯誤 |
| `aim` | 宣告的研究目的或要做的事（the main goal is to …; we examined whether …） | 報告做了這件事的結果 | 錯誤 |
| `hypothesis` | 提出來準備檢驗的主張或解釋 | 檢驗的結果，支持或拒絕都算 | 錯誤 |
| `plan` | 宣告的全文或一節的組織；每一項各開一個承諾 | 交付那段內容的 prop | 錯誤 |
| `announcement` | 近距離承諾（We now examine …; which we now describe; as follows:） | 緊接著交付的內容 | 錯誤 |
| `setup` | 為後文鋪陳的顧慮、條件或考量。**不含**一般定義，定義的使用已由 `cites` 記錄 | 後文第一個用上它的 prop | 警告 |
| `future_work` | 對研究領域的承諾，不在本文兌現（未來研究、延伸方向） | 不得被兌現 | 不適用 |

一個承諾可以被兌現不只一次（目的常在結果與討論各兌現一次）；狀態查詢以第一次兌現為「已兌現」。一個 prop 不能兌現自己開出的承諾。

### 章節角色用單一封閉詞彙

`structure.json` 的每節帶 `role`。以下是封閉列舉，**只有這 9 個值，不得依性質相似類推新值**；所有 profile 共用同一套：

| role | 這一節做什麼 |
|---|---|
| `introduction` | 提出問題、說明重要性與缺口、宣告目的與計畫 |
| `background` | 獨立成節的文獻與先前理論 |
| `formal_setup` | 記號、定義、推論規則（如範例稿件 §1.1） |
| `method` | 樣本、工具、程序、分析方法 |
| `results` | 報告結果與直接詮釋；數學稿件的主要定理陳述也屬此 |
| `proofs` | 數學稿件的證明 |
| `discussion` | 綜合、意義、限制、未來工作 |
| `conclusion` | 獨立成節的結論 |
| `appendix` | 附錄 |

節是扁平清單：小節（如 §1.1）是清單裡的一筆，角色可以和所屬大節不同。

考慮過的替代：依 profile 給不同角色詞彙（比照 `ledger-profiles`）。被否決：角色差異只有 `proofs` 一個值，不值得多一套 profile 對照。

### 未完成稿件用 partial 模式

寫到一半的稿件必然有未兌現的承諾。`validate-structure.py --partial` 把 S4 的「未兌現」從錯誤降為資訊，並列出清單；其餘規則照常。下一步模式一律用 `--partial`。

### 狀態查詢依緊迫程度排序未兌現承諾

`structure-state.py` 在位置 t 回報未兌現承諾，排序固定為：`announcement`（下一句幾乎必須兌現）→ `hypothesis` → `plan`（依開出順序）→ `question` → `aim` → `setup`；同種類依開出位置由早到晚。`future_work` 另列，不參與排序。這個排序就是「prop_{t+1} 該推進哪個承諾」的預設答案；skill 在它上面加判斷。

### Worked example 放在 article1 umbrella，不放 Overleaf

範例稿件的帳冊與兩個附檔放在 article1 umbrella repo 的 `propositions/` 目錄（私有 GitHub），`_meta.json` 的 `source.file` 指向 submodule 裡的 `manuscript/main.tex`。理由：`manuscript` submodule 直接接 Overleaf，放進去會變成 Overleaf 專案裡的檔案，每次同步都帶著走，專案若分享給共同作者也會被看到。本 repo（公開）只收彙總結果，不收帳冊或附檔。

### 先完成標註再做下一步建議

實作順序：附檔格式與 validator → 狀態查詢 → skill 的標註模式 → 在範例稿件上標註並修正詞彙 → skill 的下一步模式。下一步模式的品質取決於詞彙是否經過完整稿件的檢驗，所以排在 worked example 之後。

## Implementation Contract

**附檔格式**（放在帳冊同一目錄）：

`structure.json`：

```json
{
  "structure_version": "1.0",
  "thesis": ["<prop uuid>"],
  "sections": [
    {"id": "sec-1", "heading": "Introduction", "role": "introduction", "first_prop": "<prop uuid>"}
  ]
}
```

- `thesis`：至少一個，指出陳述全文主旨的 prop。
- `sections`：依閱讀順序；第一節的 `first_prop` 是帳冊第一個未退役 prop；每節涵蓋到下一節 `first_prop` 之前。

`discourse.jsonl`：每個未退役 prop 一行，順序與 `main.jsonl` 相同。

```json
{"prop_id": "<uuid>", "relation": "consequence", "opens": [{"id": "c-aim-1", "kind": "aim"}], "discharges": ["c-plan-2"], "note": "optional"}
```

- `refers_to`：`relation` 為 `return` 時必填，其他值不得出現。
- `opens`、`discharges`、`note` 可省略。承諾 `id` 符合 `^[a-z0-9][a-z0-9-]{0,63}$`，全檔唯一。

**`validate-structure.py`**（`plugins/propositions/scripts/`）：

- 介面：`--jsonl LEDGER`；`--structure` 與 `--discourse` 預設為 LEDGER 同目錄的 `structure.json`、`discourse.jsonl`；`--partial`；`--format text|json`。
- 規則：
  - S1：附檔的 `prop_id` 與帳冊未退役 prop 一一對應且順序相同；缺、多、重複、順序錯分別列出。
  - S2：`relation` 屬 12 值；`start` 恰在第一筆；`return` 的 `refers_to` 指向更早的 prop；其他關係不得有 `refers_to`。
  - S3：承諾 `id` 格式正確且唯一、`kind` 屬 7 種；每個 `discharges` 的 id 由更早的 prop 開出；`future_work` 不得被兌現。
  - S4：`future_work` 與 `setup` 以外的承諾至少被兌現一次（錯誤）；`setup` 未兌現是警告；`--partial` 時兩者都降為資訊。
  - S5：`structure.json` 形狀正確、`role` 屬 9 值、節 `id` 唯一、`first_prop` 存在且依帳冊順序嚴格遞增、第一節從第一個 prop 開始、`thesis` 非空且都存在。
  - S6：`announcement` 的第一次兌現不在開出的那一節或下一節時，給警告。
- 輸出：每條規則一行 `[PASS]`／`[FAIL]`／`[WARN]`，再列出逐筆問題（帶 prop 序號與 id）。
- 結束碼：0 沒有錯誤（可有警告）；1 有錯誤；2 輸入錯誤（檔案不存在、JSON 無法解析、帳冊讀不到）。

**`structure-state.py`**（`plugins/propositions/scripts/`）：

- 介面：`--jsonl LEDGER --at <prop uuid | end>`；`--format text|json`；附檔路徑預設同上。
- 先跑 S1–S3；有錯誤時結束碼 1，訊息指出先修結構。
- 輸出（位置 t，含 t 本身）：t 的序號與總數、t 所在的節（id、標題、角色）、t 的 `relation`、未兌現承諾（依上述緊迫排序，每項含 id、kind、開出的 prop 序號與 id、已隔幾個 prop）、`future_work` 清單、`thesis` 是否已出現。
- 結束碼：0 成功；1 結構錯誤；2 輸入錯誤或 `--at` 找不到。

**`propositions:construct` skill**：

- 標註模式：前置條件是帳冊通過 validator，且目標範圍沒有未覆蓋的文字（否則停下來，轉介 `propositions:extract`）。附檔先寫到帳冊目錄以外的暫存處，跑 `validate-structure.py` 修到沒有錯誤，再列出摘要（各關係數量、全部承諾的開出與兌現位置、章節清單），使用者確認後才寫入帳冊目錄。不修改 `main.jsonl`。
- 下一步模式：跑 `validate-structure.py --partial` 與 `structure-state.py --at end`，說明目前章節角色與未兌現承諾，提出至多 3 個候選下一句；每個候選寫明它推進哪個承諾（或為什麼該 `shift`）、用什麼關係與連接詞接上、預期的 `claim_type`。不寫入稿件或帳冊。

**驗收**：

- `tests/test_validate_structure.py` 對 S1–S6 每條規則至少一個通過與一個失敗的 fixture；`--partial` 的降級；結束碼 0／1／2。
- `tests/test_structure_state.py` 驗證緊迫排序、節的歸屬、`--at end`、找不到 id 時結束碼 2。
- 既有測試全部通過（目前 428 passed）。
- 範例稿件：完整帳冊通過 `validate-propositions.py`；附檔通過 `validate-structure.py`（非 partial）；彙總寫進 `docs/REFERENCE-MANUSCRIPTS.md`。

**範圍**：在範圍內的是上列兩個腳本、兩個附檔格式、一個 skill、文件與版本號。不在範圍內：`main.jsonl` schema、`validate-propositions.py`、`propositions:extract`、語意稽核、統計模型。

## Risks / Trade-offs

- [關係與承諾的標註有主觀成分，兩個人可能標得不同] → 封閉詞彙＋優先序規則降低歧異；validator 只管結構一致性。在 `STRUCTURE.md` 為每個值附範例稿件的實例。
- [帳冊增刪 prop 後附檔失效] → S1 會抓到缺漏與順序錯誤；自動同步工具不在本變更。
- [詞彙只用一篇實證稿件檢驗，數學稿件可能不夠用] → 角色詞彙已含 `proofs`、`results`（含定理陳述）；數學稿件的實測留給後續，屆時以新變更擴充詞彙。
- [範例稿件的完整抽取耗時] → 依章節拆成三個任務，各自可獨立完成與驗證。
- [範例稿件是 CC BY-NC-ND 的已發表論文，帳冊含逐字句] → 帳冊與附檔只放在私有 umbrella repo；本 repo 只放彙總數字與短的連接詞片段。

## Migration Plan

純新增：既有帳冊不需要任何改動，沒有附檔的帳冊不受影響（`validate-propositions.py` 不讀附檔）。plugin 版本 0.5.0 → 0.6.0，marketplace 同步。回復方式：刪除兩個腳本與 skill 目錄，退回 0.5.0。

## Open Questions

（無。#26 Clarity Surface 的五個疑點已分別由「跨段落與跨節照常標關係」「子句層級的 prop 之間也標關係」「先完成標註再做下一步建議」「相鄰關係詞彙以 PDTB-3 sense 為骨架」「Worked example 放在 article1 umbrella，不放 Overleaf」五個決策定案。）
