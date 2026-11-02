## Context

#26 建立的文章結構模型（propositions 0.6.0）有三層：承諾、章節角色、相鄰關係。其中相鄰關係每句只記一條，對象固定是上一句；例外只有 `return` 帶一個 `refers_to`。`STRUCTURE.md` 也明寫不設段落層，理由是段落層的修辭動作已經由章節角色加承諾種類表達。

#30 指出四種記不下的關係：同段內不相鄰的前句、前幾段、預告下一句、預告下一段。範例稿件（Cheng, Lay, Hsu, & Tsai, 2021；294 句、45 個 tex 段落、11 節）的數字：

- 帳冊 `cites` 有依賴的 191 句中，只依賴上一句的 65 句（34%）；74 句的依賴全不在上一句。
- 7 句掛在下一句上（前置的理由子句、範圍片語），現在被迫標成向後的關係，真正的關係只寫在 `note`。
- 段首句只能拿上一段最後一句當關係對象（標成 shift 19、continue 7、return 7）。

第二篇稿件 `PsychQuantHsu/psychophysical_representations` 已有帳冊（306 句，default profile，數學稿件）。非相鄰的 `cites` 邊在兩篇各占 212/329 與 292/442，目標多是 definition、result、claim、axiom、case_split。

#31 量到的承諾排序：現行「依種類、同種類先開先排」在範例稿件 231 個位置命中 89 次；改成同種類後開先排只剩 46 次。兄弟項（引言依序列出的計畫）照順序兌現，巢狀項（§3 開頭另開的計畫）要先於外層的剩餘項兌現。

使用者在 #30 的 Clarity Surface 與 spectra-discuss 裁決：段落兩種都要（預設 tex 段落、可合併或切分）；預告兩層都記；所有關係都記；格式與 next 模式一起改；驗收要兩篇；採用三層依存樹；段落是封閉子樹；#31 併入並以量測把關。

## Goals / Non-Goals

**Goals:**

- 把關係層改成三層依存樹：句子在段內有頭，段落在節內有頭，章節以 `parent` 成樹。
- 讓範圍（段、節）、右邊緣（下一句能接的位置）與還在等頭的句子都能由附檔機械算出。
- 用帳冊既有的 `cites` 承接長距離依賴，讓「所有關係都記」有可檢查的下限。
- 提供量測工具，用兩篇稿件檢驗樹是否合用，並用 231 個位置決定 `scope` 排序能否成為預設。
- 遷移現有的 1.0 附檔（測試 fixture、範例稿件）。

**Non-Goals:**

- 不改帳冊 `main.jsonl` 的 schema，不改 R1–R13，不改 `propositions:extract`。
- 不做成分樹（RST 式 span 加 nucleus／satellite），不做 Swales 式段落 move 標註，不設段落角色。
- 章節之間不標頭與關係，只加 `parent`；章節的功能仍由章節角色與承諾表達。
- 不從語料學轉移機率；不自動寫稿，next 模式只提出候選。
- 不支援多檔稿件的段落推導（`\input` 樹）；兩篇驗收稿件都是單檔，多檔時 `derive-paragraphs.py` 明確拒絕。
- 不保留 1.0 的讀取路徑。

## Decisions

### 三層依存樹取代相鄰關係

**Supersedes**: add-article-construction-model / 三層模型：承諾、章節角色、相鄰關係

每一句在同段內有一個頭（`head`）與一個關係（`relation`），段根沒有頭；每一段在同節內有一個頭與一個關係，節內的根段沒有頭；章節以 `parent` 指向上一層章節。承諾與章節角色不變。

考慮過的替代方案：

| 做法 | 不採用的理由 |
|---|---|
| 每筆記錄帶邊的清單（兩兩記邊） | 沒有範圍與右邊緣的概念；兩篇約 770 條邊全要標，量最大 |
| 成分樹（RST 式） | 要劃 span 邊界、判 nucleus，標註難度高、一致性差 |
| 頭可以跨段的自由樹 | 段落只是標記，「段對段」的關係要再從句子弧推出，範圍不清楚 |

依存樹讓每句仍只選一個頭和一個關係，成本接近 1.0。

### 段落是封閉子樹，預設由 tex 推出

**Supersedes**: add-article-construction-model / 跨段落與跨節照常標關係

`structure.json` 存一份明確的段落清單（`paragraphs`），形式同 `sections`（平鋪、依閱讀順序、以 `first_prop` 起算）。句子的頭只能在同一段內；段落的頭只能在同一節內；段落不跨節，所以每一節的 `first_prop` 必須是某一段的 `first_prop`。

預設清單由 `derive-paragraphs.py` 從 tex 空行與帳冊 `location` 推出；合併或切分就是直接改清單。檢查器不讀 tex。若改成在檢查時才從 tex 算段落，檢查器就要讀 tex，合併與切分也得另存覆寫檔。

### 向前的關係用「頭在後面」表達

前置子句、範圍片語這類先出現、掛在後一句上的句子，頭就是後面那一句（例如 "Because …," 的頭是它後面的主句）。關係一律記在依附的那一句上，同一條邊只有一種寫法，不需要方向欄位。跨段的預告（段末句預告下一段）用既有的承諾記錄；預告的是下一句、下一段或後面某節，由開出與兌現的位置算出。

### 關係詞彙改為九個內容關係加 basis

**Supersedes**: add-article-construction-model / 相鄰關係詞彙以 PDTB-3 sense 為骨架

詞彙是封閉的 10 個：`continue`、`restatement`、`specification`、`instance`、`addition`、`contrast`、`reason`、`consequence`、`sequence`、`basis`。前九個沿用 1.0 的定義，只是對象從「上一句」改成「頭」：關係描述的是這一句相對於頭的角色。`basis` 的方向要特別寫明：**頭（或 `also` 的目標）提供這一句用到的定義、結果、公理或分案**，所以這一句應該在帳冊 `cites` 裡 cite 目標。

新增 `basis` 的理由：兩篇稿件的非相鄰 `cites` 邊多數指向 definition、result、axiom、case_split，九個修辭關係都不是「用到前面的定義」的意思；硬塞進 specification 或 consequence 會讓關係統計失真。段落之間沿用同一組 10 個關係。

是否需要 `condition`（"Under such circumstances,"），以及「先鋪事實、下一句再解釋」的前置句該用哪個關係，由試標決定。決定若改變詞彙，用 `/spectra-ingest` 修改 spec 後再全篇標註。

### start、shift、return 由樹推出

三個值不再是標籤：`start` 是第一段的根；`shift` 是段根（不掛在段內任何一句上）；`return` 是頭在本段內、位置早於這一句、但不是上一句（沿右邊緣往上回到一條較早的線）。這些由狀態查詢與量測工具算出，標註者不標。

### cites 是疊加的依賴圖，不重新標註

不在樹上的 `cites` 邊就是邏輯依賴，不另標關係種類。另有選填的 `also: [{to, relation}]`，記樹與 `cites` 都沒有的修辭關係（例如對三段前某句的 contrast）。「所有關係都記」＝樹的邊＋`cites`＋承諾＋`also`。

S8 檢查方向一致：一條 `basis` 邊（樹上或 `also`）的目標必須在這一句的 `cites` 裡；不在就警告，指向帳冊漏了 cite。依上游優先原則，修的是帳冊，不是把 `basis` 改掉。

### 交叉弧只警告並計數

兩條同層的弧（同一段內的句子弧，或同一節內的段落弧）在位置上部分重疊、彼此不包含時，就是交叉弧。S7 對每一對交叉弧報警告，不影響結束碼；`structure-metrics.py` 報告交叉弧比例。樹是不是合用的模型，就看這個數字：任一篇超過 5% 就停下來重新檢討。

### 草稿用 pending 表示還沒寫出來的頭

寫到一半的稿件，最後幾句可能是還沒有主句的前置子句。這類記錄寫 `"head": "pending"`，只在 `--partial` 下、且只在最後一段允許。狀態查詢把它們列為「等頭的句子」，這是下一句最強的約束：下一句通常就是它們的頭。

### 右邊緣作為下一句的接點

位置 t 的右邊緣：從 t 沿著頭往上走、只保留位置不超過 t 的祖先，直到段根；接著沿段落的頭到節內的根段；再沿 `parent` 到全文。在沒有交叉弧的樹裡，下一句若掛在前面的句子上，那一句必然在右邊緣上。next 模式的每個候選都要說明它掛在右邊緣的哪個節點上，或者它是哪些等頭句子的頭。

### 承諾範圍與 scope 排序以量測把關

承諾的範圍是開出它的那一句所在的段與節。狀態查詢新增 `--order scope`：先依種類排序，同種類內依「開出承諾的章節與 t 所在章節的最近共同祖先」由深到淺，再依開出位置先開先排。這條規則在 #31 的資料上對應「巢狀項先內層、兄弟項照順序」，但預期 #209 那類交錯情形仍會排錯。

預設維持 `--order kind`（現行）。只有在範例稿件 2.0 標註上，`scope` 的命中數嚴格大於 `kind` 的命中數，才用 `/spectra-ingest` 把預設改成 `scope`；否則維持現狀，把量到的數字記在 #31。

### 升版 2.0 只遷移不並存

`structure_version` 改為 `"2.0"`。檢查器與狀態查詢遇到 1.0 時以結束碼 2 拒絕，訊息指向 `migrate-structure-v2.py`。現存的 1.0 只有測試 fixture 與範例稿件兩份，維持兩套讀取邏輯不划算。遷移是機械的：段落由 `derive-paragraphs.py` 推出，段內第一句當段根、其餘句的頭是上一句並沿用原關係；`start`、`shift`、`return` 與跨段的關係改寫後列入複查報告。

### 先試標再全篇標註，第二篇用 psychophysical_representations

先在範例稿件 §3.3 與 psychophysical_representations 的一節試標（在暫存區，不寫進稿件 repo），用結果決定 `condition` 與前置事實句的關係；詞彙定案後才全篇標註。第二篇選 psychophysical_representations：帳冊已經抽好，文類（數學）與範例稿件（實證）不同，能檢驗格式是否只貼合一篇。

### 量測獨立成 structure-metrics.py

交叉弧比例、右邊緣長度、兩種排序的命中數、關係與頭方向的計數，放在獨立的量測工具，不塞進檢查器。檢查器回答「格式對不對」，量測回答「模型合不合用」，兩者的結束碼語意不同。

## Implementation Contract

**資料格式（2.0）**

`discourse.jsonl` 每行一筆，每個非 retired 的帳冊 proposition 一筆，順序同帳冊：

| 欄位 | 必填 | 內容 |
|---|---|---|
| `prop_id` | ✅ | 完整 UUID |
| `head` | 段根以外 ✅ | 同段另一句的完整 UUID，或 `"pending"`（僅 `--partial`、僅最後一段）；段根不寫此欄 |
| `relation` | 有 `head` 時 ✅ | 10 個關係之一；段根不寫此欄；`head` 為 `"pending"` 時可省略 |
| `also` | — | `[{to, relation}]`；`to` 是任一非 retired 帳冊句（不是自己、不是 `head`），`relation` 為 10 個之一 |
| `opens`、`discharges`、`note` | — | 同 1.0 |

`structure.json`：

| 欄位 | 必填 | 內容 |
|---|---|---|
| `structure_version` | ✅ | `"2.0"` |
| `thesis` | ✅ | 同 1.0 |
| `sections[]` | ✅ | 同 1.0，加選填 `parent`（較早出現的章節 id；省略即頂層） |
| `paragraphs[]` | ✅ | `{id, first_prop, head?, relation?}`；`head` 是同節另一段的 id，`relation` 為 10 個之一；節內根段兩者皆省略 |

**檢查規則（`validate-structure.py`，結束碼 0／1／2 不變）**

| 規則 | 內容 | 嚴重度 |
|---|---|---|
| S1 | 同 1.0 | error |
| S2 | `relation` 與 `also[].relation` 在 10 個之內；`head` 指向同段另一句；每段恰一個根；句子的頭不成環；`pending` 只在 `--partial` 的最後一段 | error |
| S3、S4、S6 | 同 1.0 | 同 1.0 |
| S5 | 1.0 的內容，加：段落 id 唯一、`first_prop` 嚴格遞增、第一段始於第一句、每節的 `first_prop` 是某段的 `first_prop`、段落的頭在同節、每節恰一個根段、段落的頭不成環、`parent` 指向較早的章節 | error |
| S7 | 同段句子弧、同節段落弧的交叉 | warning |
| S8 | `basis` 邊的目標不在這一句的 `cites` 裡 | warning |

`structure_version` 不是 `"2.0"` 時結束碼 2，訊息含 `migrate-structure-v2.py`。

**狀態查詢（`structure-state.py`）**：在 1.0 的輸出之外，JSON 新增 `paragraph`（`id`、根的位置與 id，根尚未寫出時為 null）、`frontier`（依序的節點清單，每個節點含 `level`：`sentence`／`paragraph`／`section`，以及位置與 id）、`pending`（頭為 `pending` 或頭在 t 之後的句子）、每個未兌現承諾的 `scope`（開出句的段落 id 與章節 id）、`order`（本次使用的排序）。`relation` 對段根輸出 `root`。新增 `--order kind|scope`，預設 `kind`。先套用 S1–S3 與 S2、S5 的樹結構部分，失敗時結束碼 1。

**`derive-paragraphs.py`**：輸入 `--jsonl` 與 `--tex`，選填 `--structure`（讀取章節以對齊）。把 tex 的連續非空行視為一段，依每句 `location` 的起始行歸段，跳過沒有句子的段，章節起點落在段中時從該處切開；輸出 `paragraphs` 清單（id 為 `p-1`、`p-2`…）到 stdout 的 JSON。location 無法解析、落在段落之外，或指向主檔以外的檔案（多檔稿件；`main.tex:` 前綴視為主檔）時以結束碼 2 拒絕。

**`migrate-structure-v2.py`**：輸入 `--jsonl`、`--tex`、`--out-dir`；讀 1.0 附檔，把 2.0 附檔寫到 `--out-dir`，不改 `main.jsonl` 與原附檔；同時輸出複查報告，列出每筆需要人工確認的記錄（位置、id、原關係、原因）。輸入不是 1.0 時結束碼 2。

**`structure-metrics.py`**：輸入同狀態查詢；結構未通過 S1–S3 或 S2、S5 時結束碼 1。輸出：句子弧與段落弧的總數、參與交叉的弧數與比例；每個位置的句子層右邊緣長度（中位數、平均、最大）；頭在前與頭在後的計數；10 個關係的計數；S8 警告數；兩種排序各自的評估位置數與命中數。命中的定義：在位置 t，若之後有被兌現的未兌現承諾，排第一的承諾屬於「t 之後最早被兌現的那一批」就算命中。

**construct skill**：annotate 模式先跑 `derive-paragraphs.py`，逐段標頭與關係、段落的頭與關係、章節 `parent`；摘要加入段落數、S7 與 S8 的警告、右邊緣中位長度。next 模式在 N2 讀 `frontier`、`pending` 與承諾；有等頭的句子時，第一個候選必須是它們的頭；每個候選說明掛在右邊緣的哪個節點、用哪個關係，以及推進哪個承諾。

**驗收條件**

- `pytest tests/` 全部通過，包含新增的三個測試檔與改寫的兩個。
- 測試 fixture 遷移成 2.0，`validate-structure.py` 結束碼 0。
- 範例稿件與 psychophysical_representations 的 2.0 附檔在不加 `--partial` 下結束碼 0。
- `structure-metrics.py` 在兩篇上的輸出記入 `docs/REFERENCE-MANUSCRIPTS.md`（只記數字）。
- 兩篇的句子弧交叉比例都不超過 5%；超過時停在該步，回報並重新檢討模型，不繼續發佈。
- `scope` 排序的命中數嚴格大於 `kind` 時，才把預設改為 `scope`。

**範圍**

- 範圍內：附檔格式 2.0、檢查器、狀態查詢、三個新工具、construct skill 與 vocabulary.md、`STRUCTURE.md`、`SCHEMA.md` 附檔段、fixture 與測試、兩篇稿件的標註與量測、propositions 升為 0.7.0。
- 範圍外：帳冊 schema 與 R1–R13、`propositions:extract`、多檔稿件的段落推導、章節之間的頭與關係、段落角色、轉移機率、自動寫稿。

## Risks / Trade-offs

- [標註量大：兩篇共 600 句、約 90 段] → 先試標兩節；全篇標註依章節切塊；`basis` 與 `cites` 交叉檢查減少漏標。
- [文章不是樹（交叉弧多）] → S7 只警告並計數；超過 5% 停下重新檢討，而不是硬套。
- [`basis` 方向被讀反] → 規格與 vocabulary.md 寫明「目標提供、這一句使用」；S8 用 `cites` 方向機械檢查。
- [`scope` 排序比現行差] → 預設維持 `kind`，只在嚴格勝出時才改。
- [tex 推出的段落不準（浮動體、註腳、標題與內文同段）] → 推出的清單只是預設，標註者可改；S5 強制段落不跨節。
- [1.0 使用者被擋] → 0.6.0 今天才發佈；錯誤訊息直接指向遷移工具。
- [詞彙只貼合兩篇] → 兩篇文類不同；試標結果決定是否需要 `condition`。

## Migration Plan

1. 實作 2.0 格式、檢查器、狀態查詢與三個工具；遷移測試 fixture。
2. 試標範例稿件 §3.3 與 psychophysical_representations 一節；必要時用 `/spectra-ingest` 修訂詞彙。
3. 用 `migrate-structure-v2.py` 把範例稿件的 1.0 附檔轉成 2.0 起點，再逐段重新標頭與關係；全篇標註 psychophysical_representations。
4. 跑 `structure-metrics.py`；檢查交叉比例；比較兩種排序。
5. 更新文件，propositions 升為 0.7.0。

回退：0.6.0 仍在 marketplace 的 git 歷史裡；兩篇稿件的 1.0 附檔留在各自 repo 的 git 歷史裡。

## Open Questions

- 是否需要 `condition`（"Under such circumstances,"）？由試標決定。
- 「先鋪事實、下一句再解釋」的前置句（例如報人數之後才提出解釋）用哪個關係？由試標決定。
- 段落之間的關係，10 個關係是否足夠？由試標決定。
