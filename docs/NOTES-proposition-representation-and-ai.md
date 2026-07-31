# Proposition ledger 的定位：AI 可讀性、Lean、與證明表徵

> 2026-07-07 設計討論筆記。起點是 PT-JSONL 提案
> (`~/Library/CloudStorage/Dropbox/che_workspace/orthogonal_projects/imports/proposition_world_model_proposal.md`)
> 對本 plugin 的改善啟發,一路收束到 proposition ledger 在「形式化光譜」上的定位。
> 性質是討論紀錄 + 定位論述,**不是 normative contract**(那是 SCHEMA.md 的工作)。
> 文末的 backlog 是候選改動,尚未立 Spectra change。

## TL;DR

1. PT-JSONL 值得進口的不是它的語義架構(那是為「可判定的世界」設計的),
   是它的工程紀律:schema 先行、predicate 先註冊才可用、不確定就 loud failure。
2. Lean 當**閱讀格式**對 AI 是失格的,但把它降級成**判真後端**、讓 JSONL
   繼續當唯一 AI-facing 表面,不透明就只是實作細節。
3. 形式化的成本分兩塊:可化約的(證明 grind,正在被機器吃掉)與不可化約的
   (陳述精確性,即主張本身)。本 plugin 佔的正是不可化約那塊。
4. 本 ledger 結構上是 sequent 帳本的雛形(Γ ⊢ φ),也是傳統邏輯
   「proposition + rule of inference」證明觀的資料化。AI 定理證明領域
   已用行動投票給這個表徵(GPT-f 選 Metamath、LeanDojo 抽 goal-state trace)。

---

## 1. PT-JSONL 對照:兩個專案的本質差異

PT-JSONL 是 AI world model 格式:命題描繪**世界**的真假,目標表徵完全形式化
(typed predicate registry、projection rule、truth condition、可執行 evaluator)。
本 plugin 是 author-claim ledger:命題記錄**文本**斷言了什麼,`text` 是 ground
truth,真假明列 out of scope。

表面上一個做自然語言、一個做數學,但形式化方向剛好相反:

- PT-JSONL 的輸入是自然語言,野心是翻譯成形式語義。「杯子在桌上」的 truth
  condition 可以寫成一個 operational evaluator,成本有限。
- 本 plugin 處理的是數學散文(自然語言 + 內嵌數式),表徵**刻意停在文字層**:
  verbatim `text`、substring-level bijection、數學內容當 opaque string。
  因為一個定理的 truth condition 就是它的證明,給數學命題做 PT-JSONL 式
  判真語義等於重新發明 Lean。

三者在光譜上的位置:

| | 領域 | 表徵深度 | 判真機制 |
|---|---|---|---|
| propositions plugin | 數學散文 | 文字錨定 + 結構 metadata | 無(text 是 ground truth) |
| PT-JSONL | 日常世界狀態 | 完全形式化 | operational evaluator / 邏輯式 |
| Lean | 數學 | 完全形式化 | proof checker |

### 值得進口的(按 ROI 排序)

1. **正式的 `proposition.schema.json`**(JSON Schema 2020-12)。目前 schema
   契約只存在於 SCHEMA.md 散文,enum 重複硬編在
   `validate-propositions.py`(R11 evidence_class、R12 claim_type 兩個
   frozenset)。單一 schema 檔之後:validator 從檔案載 enum、
   EXTRACTION-PROMPT 可引用、「Schema 升級走 spec 流程」終於有機器可讀的
   artifact 當改動對象。這是 PT-JSONL 的 L1 層。
2. **Extraction 端的 ambiguity record 紀律**。PT-JSONL 的原則:parser 不確定
   時不硬猜,輸出 ambiguity report。等於把本 repo 既有的「loud failure over
   silent fix」從 refresh-locations(anchor_failed)延伸到 extraction 端:
   claim_type / cites 拿不準時寫入 `_ambiguity.jsonl` 或 prop 上的
   `extraction_flags`,human curation 優先處理。直接攻擊已量測的 asserts
   hallucination(n=20 點估 5%,95% CI 上界 ~22%)。
3. **Per-prop provenance**(v1.4 候選欄位)。provenance 目前只在 `_meta.json`
   檔案層級,但 main.jsonl 是 Phase 1 / Phase 2 混血,無法分辨某 prop 是
   LLM 抽的還是人工 curate 過的。加 optional
   `provenance: {extractor, extracted_at, curated}`,未來 audit 可分層估計
   兩類 props 各自的 hallucination rate。
4. **R4 從 regex 升級成結構化矛盾偵測**(最貴,單獨立案)。SCHEMA.md 自列
   PATTERN-A 的 known limitations(語義改寫 miss、LaTeX 變體 miss、Unicode
   miss)。PT-JSONL §15 的配方:同 predicate + 同 arguments + context 重疊 +
   相反 polarity → conflict record。落地版:optional `logical_form` 欄位 +
   小型 manuscript 專用 predicate registry(equals / defined_as / implies /
   bounded_by,十個以內),只對 R4 實際掃的 claim_types(axiom / hypothesis /
   case_split)填,不做全量 re-extraction。這是 #71 deferred 的 R5 validator
   Path B 的具體化。守住的邊界:它形式化的是**矛盾的形狀**(同對象、同條件、
   相反斷言),不是數學語義本身;registry 一旦膨脹成一般數學 ontology,
   就是在往「用 JSON 重新發明爛版證明語言」滑。

### 不進口的

- `updates.jsonl` / append-only event sourcing:git 已提供完整歷史,
  manuscript 不是 streaming world model。
- RDF / JSON-LD / OWL / SHACL interop:沒有 consumer。
- 完整 entity / context reification:`containing_block` + `scope_qualifiers`
  對稿件已夠用。
- 通用 truth condition evaluator:見上,那是 Lean 的工作。

### 順帶記錄的既有缺口(非 PT-JSONL 來的)

- 句級 surjectivity:在已 covered 的 section 內新增一句話,Phase 1 抓不到
  (SCHEMA.md 失效情境表明列)。候選解法:git-diff-aware 的 R14,只掃
  `--since <ref>` 改動行,報 uncovered sentences(WARN 級)。
- Injectivity:兩個 props substring-match 同一段抓不到。便宜解法:R1 匹配時
  記錄 match span,span 重疊即 WARN。
- 文件漂移:`skills/` 實有 4 個 skill(proofread 未列入 CLAUDE.md 表格);
  CLAUDE.md 寫測試「142+ passed」,實際 140 passed + 3 skipped。

---

## 2. Lean 的不透明:兩層拆解

「Lean 對 AI 不透明」要拆成兩層,一層無所謂,一層是真問題。

**Proof 層不透明,無所謂。** tactic script 是命令式程式,`simp [foo]; omega`
的語義取決於執行當下的 goal state;elaborate 出的 proof term 是機器產物,
沒有閱讀價值。但這層不透明是設計的一部分:proof 的唯一工作是讓 kernel 說
yes,外包給 Lean 的就是這個 boolean,從來不需要 AI 讀懂證明。

**Statement 層 context 依賴,是真問題。** 一條 Lean 定理的意義不在文字裡,
在整個 elaboration context 裡:imports、open namespaces、notation、implicit
coercions、定義展開。這違反本 plugin 的設計美學:line-addressable、讀一條
claim 花 ~200 tokens、grep 得到、不需要 toolchain 就能檢視。

更準確的說法:**Lean 不是 data format,是 runtime**。語義活在 elaboration
與執行裡;要「讀」它得跟它互動(`#check`、goal state、LeanDojo trace)。
JSONL 則是 at-rest transparent,所見即全部。PT-JSONL §3.2 說的
「AI-readable, not just machine-readable」畫的正是這條線,Lean 站在對面:
machine-verifiable but not AI-readable at rest。

**Formalization gap 不因 Lean 而消失。** kernel 保證「這個 formal statement
有證明」,不保證「這個 formal statement 忠實翻譯了稿件那句話」。informal ↔
formal 的對應永遠是 LLM / 人工 curation 在扛,跟 asserts hallucination 是
同一形狀的信任漏洞。Lean 消掉的是「檢查」的不透明,消不掉「翻譯」的不透明。

### 設計含意:`formal` 欄位的正確形狀

若未來走 Lean 後端,裸指標(只存 declaration 名稱)是錯的,因為指過去的
東西 AI 讀不動。正確形狀是 **pointer + snapshot + status**:

```json
"formal": {
  "lean_ref": "PsychRep.eta_boundary",
  "lean_statement": "∀ s ∈ S, η 1 s = s",
  "status": "verified",
  "toolchain": "lean4:4.x + mathlib@<sha>"
}
```

- `lean_statement` 是 pretty-printed 快照,讓透明性留在帳本裡。
- `status ∈ {verified, sorry, not_formalized}`,AI 只讀 checker 回傳的狀態,
  永遠不必讀 `.lean` 檔。
- snapshot 是否忠實(新的 gap)用既有 cross-model audit 紀律抽查,
  方法與 audit asserts 相同。
- 便宜的中間站:statement-only 的 `.lean` 檔(全部 `:= sorry`),等於
  typed 詞彙表,成本是完整形式化的零頭,已能抓 type error 等級的陳述錯誤。

---

## 3. 型別論與透明性:兩種膨脹

「數學系統就是型別論,不該對 AI 這麼不透明」這個直覺,對了一半,而且
錯的那半有精確的定位。

Kernel calculus 本身透明:Pi、lambda、application、universe、inductive,
全顯式的樹、無隱藏 context、type checking 是純語法操作。問題是全顯式版本
的大小。但膨脹要分兩種:

| 膨脹類型 | 例子 | 性質 |
|---------|------|------|
| **可擦除的** | `@instHAdd`、`instOfNatNat` 等 typeclass plumbing | 雜訊。pretty-printer pass 能還原,`1+1=2` 壓回 Peano 形式只要兩步展開 |
| **不可擦除的** | 定義塔:`Integrable` → Bochner 積分 → 簡單函數 → L¹ 完備化 → 拓撲 → 濾子 | 內容本身。名字就是壓縮,而這種壓縮是概念單位 |

展開到地基不是透明化:Mathlib 的實數是 Cauchy 序列等價類、有理數是互質
整數對,「π > 3」展開到 Peano 層是不可讀的巨湯,還暴露數學上無關的編碼
選擇(Cauchy vs Dedekind)。定理的意義活在抽象層的介面上。

**正確的推廣:展開到對的層,然後停。** 對的層是「這個論述自己視為原語的
那組定義」。而**每篇論文都有自己的 Peano 層**:它的 Section 1 conventions。
論文的認識結構本來就是:

- 本地公理(conventions,= `introduces` 標記的原語 + `evidence_class:
  conventional`)
- 引用進來的背景(citations,當黑箱信任)
- 導出的主張(`evidence_class: derived`,`cites` 是塔內的邊)

props 的透明性相對於論文自己的定義層成立;塔再往下是 Mathlib 或教科書的
事,論文自己也是這樣引用它們的。這解釋了為什麼 sequent-ledger 路線在稿件
尺度可行:一篇論文的本地原語只有幾十個,registry 小到可人工 curate,
不像 world model 或 Mathlib 要面對開放世界詞彙表。難的部分(塔的下層)
被論文的引用慣例天然截斷。

三難:**顯式、緊湊、自足,三者不可兼得**。自然語言數學選緊湊 + 自足
(語義在讀者腦中重建);kernel term 選顯式 + 自足(token 成本毀滅性);
Lean 表面語法選緊湊 + 顯式(要 elaborator 解壓)。差別在 Lean 的壓縮是
演算法可解壓的(elaborator 是確定性 oracle),自然語言是無條件不透明。

---

## 4. 嚴謹是否必然瑣碎:不必然

**嚴謹性住在 checker,不住在表面語法。** de Bruijn criterion 只要求:存在
一個小到可人工審計的 kernel,檢查某個全顯式的證明對象。沒要求那個對象由
人手寫。瑣碎程度是**自動化缺口**的函數,不是嚴謹性的函數。

實證光譜(四者都滿足 de Bruijn criterion,瑣碎差一個數量級):

| 系統 | 表面形態 |
|---|---|
| Metamath | 每步替換全顯式,極端瑣碎,kernel 幾百行 |
| Lean 4 / Coq | tactic script,中等瑣碎(依值型別論另有 transport / motive / def-eq 分裂的稅) |
| Isabelle + Sledgehammer | 宣告式 Isar,接近教科書,hammer 自動填縫 |
| Mizar / Naproche | 受控自然語言,最接近散文 |

Wiedijk 估的 de Bruijn factor(形式化長度比)約 4×,隨自動化持續下降。
趨勢的漸近點是 Hales 的 formal abstracts 願景:人只負責陳述,機器負責
證明或回報缺口。

**不可化約的殘餘 = 陳述精確性。** 量詞順序、邊界條件、n ≥ 1 還是 n ≥ 0、
除以零的約定:這些瑣碎沒有自動化能吸收,因為它們不是證明的成本,它們就是
主張的內容。數學家的非正式證明能短,是把這些外包給讀者的善意;形式系統
只是拒絕這筆外包。

分工圖:形式化成本 = 可化約(證明 grind,由機器吃)+ 不可化約(陳述
精確性,作者自己扛,瑣碎有內容價值)。**本 plugin 佔的正是不可化約那塊,
且拒絕碰可化約那塊。** Lean 4 惱人的部分幾乎全在本 ledger 永遠不需要碰的
那一半。

---

## 5. LLM 證明的文類定位:de Bruijn 心中的 informal proof

LLM 寫的證明在文類上**就是** informal proof 本尊:正確性由讀者重建承擔
(而非機器檢查)的證明。它是語料裡「數學家之間作為溝通行為的證明」的統計
蒸餾,連修辭配件(clearly / by a standard argument)都完整繼承。

關鍵錯位:de Bruijn 心中的 informal proof 背後有一顆真的 mind,每個
「clearly」原則上可 on-demand 展開,informal text 是指向理解的指標。LLM 的
informal proof 繼承文類的形式,沒有繼承文類的擔保。「clearly」在人類文類的
語用意義是「我檢查過、可以展開給你看」;在 LLM 輸出裡的生成機制是「語料
在這個位置通常接 clearly」。**佔據受信任的文類、卻沒有文類預設的 backing**,
與 asserts hallucination 是同一現象的兩個實例。

對人類公平的註腳(Lakatos, *Proofs and Refutations*):人類 informal proof
也不完全可靠,差別在失敗的形狀。人類在概念邊緣失敗且文本留線索(寫得猶豫
處通常就是弱處);LLM 以均勻流暢度在任何位置失敗,流暢度與正確性解耦,
讀者賴以偵錯的文類線索失效。

歷史反轉:de Bruijn 時代的問題是「有 mind 沒 machine」,Automath 把心中
證明翻譯給機器。現在 informal 層變得便宜、豐沛、無擔保,迫使 informal
proof 的認識論角色**從「正確性的證據」降級為「搜索的提案」**。
Draft-Sketch-Prove / AlphaProof 把這個降級制度化:LLM 出 vernacular 草稿
(扮演 mind)、formal sketch 定骨架、hammer 填縫、kernel 裁決(扮演裁判)。

量化趣味:de Bruijn factor 從此可大規模實測;formalization 失敗率成為新
指標,量「這份白話證明裡有多少是幻覺化的讀者善意」。人類數學文本 vs LLM
文本在此指標上的差距,本身是好研究問題。

---

## 6. 兩種 proof 觀點與定理 index

### Index 假說有文獻共識

「Lean 難用一半是因為沒有好的定理 index」符合自動推理圈的自我診斷:
**premise selection 是自動化的第一瓶頸**。Sledgehammer 的成功核心是
relevance filter(MePo / MaSh);Lean 端的 `exact?`、Loogle(型別 pattern)、
leansearch.net(語意搜尋)、LeanDojo 的 ReProver(retrieval-augmented
prover)全在補這個 index,且 ReProver 實驗證實檢索直接提升證明成功率。

Index 難建的原因:定理 identity 是 up-to-normalization 的,同一事實有多種
語法面貌,exact-match 索引天生失效。Mathlib 目前真正的 index 是命名慣例
(`mul_le_mul_of_nonneg_left` 這種名字就是查詢鍵),一套人肉維護的索引。

### Keyframes vs deltas

傳統邏輯的證明觀(proposition + rule of inference:證明是一串命題,每行
引用規則 + 前面的行)與 Curry-Howard 觀(proof = term = 程式)在數學上
等價,表徵性質完全不同:

> **tactic script 是 delta encoding,命題式證明是 keyframes。**
> tactic 存狀態轉移的指令(緊湊,不 replay 看不到中間狀態);命題式證明存
> 每個中間狀態本身(冗長,at rest 可讀)。

傳統觀有現成化身:Metamath(每步是顯式替換實例,資料庫就是一本命題帳)。
歷史事實:GPT-f(Polu & Sutskever 2020,LLM 定理證明開山作)第一個目標
就選 Metamath,理由正是對模型最可讀。LeanDojo 的訓練資料是
(goal state, tactic) 對,等於先 replay 出 keyframes 再學。**AI-facing 的
格式是命題序列、不是 script,在該領域已是既成事實。** Isabelle 的 Isar 是
此觀點的人體工學版:`have <命題> by <自動化>`,中間命題顯式、規則細節
丟給 hammer。

全嚴謹 keyframes 的 verbosity 代價巨大(Metamath 的非平凡證明極長),但
承擔者可以是機器:keyframes 由 replay 生成,人與 AI 只讀不寫,verbosity
就只是磁碟空間問題,不是認知問題。

### 兩本 ledger 互補

- 好的定理 index = **Mathlib 的 propositions ledger**(statements 作為可查詢
  的一等資料,與 proof 分離)。
- 本 plugin 的 JSONL = **論文的 propositions ledger**。

而 prop DAG 本來就是傳統邏輯意義下的 proof sketch:每個 `evidence_class:
derived` 的 prop 是一行 Isar 的 `have`,`cites` 是它引用的前提行,推理規則
暫時留白。兩邊 ledger 都存在時,「形式化這篇論文」從創作問題降級成
**檢索 + 匹配問題**:對每行 derived prop 去 index 找能 discharge 它的引理
組合,找不到的行才是真正需要人力或強 prover 的地方。此即 Draft-Sketch-Prove
的架構,只是 sketch 由稿件端先做好。

誠實的但書:命題式視圖藏了 side conditions。「by Lemma 3」式的
justification 跟 clearly 一樣含讀者善意;unification 層細節(implicit /
coercion / 定義展開)沒進帳本,機器 discharge 時會在此卡住。

本 ledger 的結構定位,一句話:**在一個封閉的、作者自己定義的微型理論裡,
把 judgment 顯式化的 sequent 帳本**。`text` + `scope_qualifiers` +
`mathematical_objects` 結構上就是窮人版 Γ ⊢ φ;若未來要更形式,增量方向
是讓 props 更像 sequents(假設列表顯式化、objects 帶型別標註),把型別論
的形狀借過來、工具鏈留在後端,而不是採用 Lean 檔當格式。

---

## Backlog(候選,未立案)

| # | 項目 | 成本 | 動機章節 |
|---|------|------|---------|
| 1 | `proposition.schema.json` 單一 schema 檔,validator 載入 enum | 低 | §1 |
| 2 | Extraction ambiguity record 紀律(EXTRACTION-PROMPT + `_ambiguity.jsonl`) | 低 | §1 |
| 3 | Per-prop `provenance` 欄位(v1.4) | 低中 | §1 |
| 4 | R4 結構化矛盾偵測(`logical_form` + 微型 predicate registry) | 高,單獨立案 | §1 |
| 5 | R14 diff-aware 句級 surjectivity(WARN) | 中 | §1 缺口 |
| 6 | R1 injectivity WARN(match span 重疊) | 低 | §1 缺口 |
| 7 | `formal` 欄位(pointer + snapshot + status,Lean 後端) | 遠期 | §2 |
| 8 | props 向 sequent 靠攏(顯式假設列表、typed objects) | 遠期,與 #4 #7 合流 | §6 |

任一項動 schema 者,依 repo hard rule 先改 `docs/SCHEMA.md` + 走
`/spectra-propose`。

## 參考(informal pointers)

- PT-JSONL 提案:`orthogonal_projects/imports/proposition_world_model_proposal.md`(2026-07-03 draft)
- Wittgenstein, *Tractatus*(picture theory,PT-JSONL 的語義原則來源)
- de Bruijn / Automath;Wiedijk, "The de Bruijn factor"
- Freek Wiedijk 系統比較、Mizar / Naproche(受控自然語言證明)
- Polu & Sutskever (2020), GPT-f(arXiv:2009.03393,Metamath 目標)
- Yang et al. (2023), LeanDojo / ReProver(retrieval-augmented proving)
- Jiang et al. (2023), Draft-Sketch-Prove
- Hales, Formal Abstracts project
- Lakatos, *Proofs and Refutations*
- 本 repo:`docs/SCHEMA.md`(asserts baseline audit、R4 PATTERN-A known limitations、失效情境表)
