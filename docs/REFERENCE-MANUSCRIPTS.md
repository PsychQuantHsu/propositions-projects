# 參考稿件

> 性質：參考資料，不是 normative contract（那是 `SCHEMA.md` 的工作）。
> 記錄本 plugin 拿來當寫作範本與驗收對象的稿件：書目、哪一個版本算數、在本專案的用途。
> 本 repo 是公開的：這裡只放書目與結構分析，不放稿件原始碼、帳冊、本機路徑或 Overleaf 專案編號。

## 1. Can Likert scales predict choices?（實證稿件的範本）

Cheng, C., Lay, K.-L., Hsu, Y.-F., & Tsai, Y.-M. (2021). Can Likert scales predict choices? Testing the congruence between using Likert scale and comparative judgment on measuring attribution. *Methods in Psychology, 5*, Article 100081. https://doi.org/10.1016/j.metip.2021.100081

- **授權**：gold open access，CC BY-NC-ND 4.0。
- **為什麼選這篇**：第一作者（本 repo 的維護者）自評是寫過最好的一篇（2026-11-01）。
- **哪一個版本算數**：期刊版（version of record）。作者保存的 LaTeX 原始碼只到 R1 投稿（2021-08）；之後在 Word 接受稿與 Elsevier 校樣階段仍有大量改動，R1 只涵蓋期刊版約 64% 的文字（以連續 8 個詞的片段計）。作者的私有稿件 repo 已依期刊版重建原始碼。在本專案引用、抽取、分析這篇時，一律以期刊版為準，早期草稿只當歷史參考。

### 期刊版的結構

| 節 | 標題 | 這一節做什麼 |
|---|---|---|
| 1 | Introduction | 研究問題：用 Likert scale（LS）推論選擇是否站得住 |
| 1.1 | Congruence of choices inferred from LS and from CJ | 形式定義：從 LS 推論選擇的 discrepancy rule、comparative judgment（CJ）的 majority rule，以及兩者推論結果的分類（concordant、discordant、undetermined） |
| 1.2 | Present study: academic attributions | 把一般問題落到具體情境：努力與能力歸因，成功與失敗兩個情境 |
| 2 | Method | |
| 2.1 | Sampling and participants | 樣本 |
| 2.2 | Measures: academic attribution inventory | 量表與 CJ 題目（題目全文在 Appendix） |
| 3 | Results | |
| 3.1 | Psychometric properties of LS scores | 先確認 LS 本身可用（McDonald's ω 信度、相關矩陣） |
| 3.2 | Choices inferred by LS and CJ items | 主要結果：一致與不一致的比例 |
| 3.3 | The undetermined cases | 對 undetermined 個案提出對立解釋，推出可檢定的預測，檢定後修正模型 |
| 4 | Discussion | |

注意 §1.1 雖然放在 Introduction 底下，內容是方法層次的形式定義；抽取時它的 prop 多半是 `definition`，不是 `commentary`。

### 摘要的論證走向（本文件的分析）

摘要十步，每一步都只做一件事，而且下一步由上一步的類型決定：

1. 背景：人如何在多個選項之間選擇，是許多領域關心的問題。
2. 常見做法：比較各選項的 LS 同意程度，再把 LS 分數轉成偏好順序。
3. 問題：LS 的作答格式不是為了揭露偏好而設計的。
4. 目的與對照基準：檢驗從 LS 推論選擇在什麼程度上適當，以 CJ 作為選擇的直接測量。
5. 樣本與作法：929 位青少年，成功與失敗兩個情境，LS 與 CJ 都作答。
6. 發現一：LS 大致能預測 CJ 的結果。
7. 發現二：仍有 14.7%（成功）與 12.1%（失敗）的人，從 LS 與從 CJ 推論出的選擇不同。
8. 含意，並限定範圍：從 LS 推論偏好不是沒有風險，至少對這個華人文化下的青少年樣本是如此。
9. 發現三：不一致的人大多在努力與能力兩項的 LS 分數相同。
10. 檢定：以 beta-binomial 分布為動機的適合度檢定，排除「LS 平手就代表真的沒有偏好」。

第 6→7 是「大致成立 → 但有例外」，第 7→8 是「例外 → 有範圍限定的含意」，第 9→10 是「描述性發現 → 檢定對立解釋」。這種相鄰兩句之間的關係，是 #26 要表徵的東西。

### 在本專案的用途

1. **empirical profile 的範例稿件**。`add-extract-skill` 的 pilot 與 eval 是在這篇的早期草稿上跑的。2026-11-02 起，期刊版全文已有完整帳冊與結構附檔（見下一節），之後的 eval 與示範以它為準。帳冊與附檔都留在作者的私有稿件 repo。
2. **寫作轉移的 worked example**（#26：已知 prop_t，prop_{t+1} 該寫什麼）。§3.3 是「觀察 → 對立假設 → 推導出的預測 → 檢定 → 詮釋 → 修正模型」的完整示範，每一步都有連接詞標出和前一句的關係。

### 期刊版的文章結構（worked example，2026-11-02）

Spectra change `add-article-construction-model` 以期刊版全文做了一次完整的 worked example。帳冊與兩個結構附檔放在作者的私有稿件 repo，這裡只記數字。

- **帳冊**：294 個 proposition（摘要 14、第 1 節 133、第 2–4 節 147）。文末聲明與附錄問卷不屬於論證，不抽取。
- **相鄰關係**：consequence 59、specification 51、continue 50、addition 43、contrast 19、shift 19、sequence 16、instance 11、reason 10、return 10、restatement 5、start 1。12 個值全部用上。
- **承諾**：32 個。setup 4、question 3、aim 5、plan 7、announcement 7、hypothesis 2、future_work 4。研究問題、目的、假設、章節計畫、近距離承諾全部兌現，只有 4 個未來研究依設計保持開著。
- **章節**：11 節。「3. Results」開頭那段講信賴區間、檢定與軟體，角色是 `method`；§1.1 雖然在引言底下，角色是 `formal_setup`。
- **詞彙缺口**：帳冊從摘要開始，原本 9 個章節角色都不適合摘要。依設計停下來問使用者，結果是加入第 10 個角色 `abstract`：只能是第一節，節內的 proposition 不開承諾，避免和正文開出的承諾重複計算。

**下一步模式的檢驗**：把帳冊截在三個位置，用 `structure-state.py` 取「最該推進的承諾」，和期刊版實際的下一句比對。

| 切點 | 最該推進的承諾 | 實際的下一句 |
|---|---|---|
| §1.1 結尾（“which we now describe”） | 該 announcement | 下一節第一句（`shift`）就兌現它，相符 |
| §3.2 結尾 | 引言宣告的下一個章節計畫 | §3.3 第一句（`shift`）就兌現它，相符 |
| §3.3 中段（“We now examine an alternative explanation.”） | 該 announcement | 先報出相關個案的人數，兩句之後才提出那個解釋並兌現，部分相符 |

兩個章節交界處，下一節第一句做的事正好是狀態查詢排第一的事。§3.3 內部則是先鋪陳解釋所需的事實，再兌現承諾；所以下一步模式提出的候選，要容許「為開著的承諾鋪陳事實」這一類。

