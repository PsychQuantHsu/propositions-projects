## 1. Pilot 與詞彙凍結

- [x] 1.1 Pilot：在 repo 以外的位置，用 proofread Mode B 的詞彙手動拆實證稿件的兩個段落（一段引言、一段 Results），記錄每個放不進現有 `claim_type`／`evidence_class` 的命題。依結果回答 design 的 Open Question（引述文獻的主張用哪個 `evidence_class`），把決定寫回 design.md 的 Open Questions，並同步更新 proofread skill 的「Schema extension for Mode B」一節，對應決策「`empirical` 是預設詞彙的超集合」。驗證：design.md 的 Open Questions 改成已決定的答案；pilot 檔案不在 repo 內（git status 沒有新檔）。
- [x] 1.2 在 `docs/SCHEMA.md` 新增 v1.7：`_meta.json` 的 `profile` 欄位、可接受值的封閉列舉、兩個 profile 的詞彙表，以及 Versioning 一節的遷移說明，對應決策「profile 寫在帳冊的 `_meta.json`，值是封閉列舉」。驗證：內容審查，詞彙表與 ledger-profiles spec 中「Profile selects the R11 and R12 vocabularies」的表格逐格相同（含 1.1 新增的值）。

## 2. Ledger profiles（validator）

- [x] 2.1 動 validator 之前，先記錄基準輸出：對 `tests/fixtures` 底下每一份帳冊，以及 Hsu 稿的帳冊（PsychQuantHsu/psychophysical_representations 的 `manuscript/propositions/main.jsonl`，本機沒有就先 clone 到 repo 外），保存 validator 的標準輸出與 exit status 到 repo 外的暫存目錄，供「Undeclared ledgers see unchanged validator output」比對。驗證：每份帳冊都有對應的基準檔，而且 exit status 有記錄。
- [x] 2.2 RED：在 `tests/test_ledger_profiles.py` 寫出 ledger-profiles spec 的每個 scenario，包括「Ledger declares its profile in metadata」、「Profile values form a closed set」、「Profile declaration requires schema version 1.7」、「Profile selects the R11 and R12 vocabularies」的範例表逐列，以及「Undeclared ledgers see unchanged validator output」的 INFO 行規則；fixture 只用合成文字。另外把 2.1 的基準 commit 成 golden（`tests/fixtures/validator-golden/`），鎖住「Regression on an existing mathematical ledger」。驗證：執行 pytest tests/test_ledger_profiles.py，描述新行為的測試 FAIL，而且失敗原因是功能尚未實作；描述既有行為的測試（default 拒收 Mode B 詞彙、pre-1.2 照舊略過、golden 輸出）一開始就通過，屬於回歸測試。
- [x] 2.3 GREEN：validator 從 `_meta.json` 讀 `profile`，依 profile 決定 R11／R12 的允許集合；未知的值，或 schema 低於 1.7 卻宣告 profile，都報錯並 exit 1，對應決策「profile 需要 schema 1.7，宣告錯誤時大聲失敗」；只有宣告了 profile 才印 INFO 行。驗證：pytest tests/test_ledger_profiles.py 全數通過；pytest tests/ 全數通過；用 2.1 的基準逐檔 diff 為空。

## 3. 共用正規化步驟表

- [x] 3.1 [P] RED：在 `tests/test_lib_normalize.py` 為「Coverage normalization is the R1 normalization」寫測試：對 `tests/fixtures` 底下每個 `.tex`，`normalize_with_map` 的字串部分與 `normalize_for_match` 的輸出逐字元相同；來源位置序列長度與字串相同、單調不遞減、不超出原文長度。驗證：pytest 執行這些測試，因為 `normalize_with_map` 還不存在而 FAIL。
- [x] 3.2 GREEN：把 `normalize_for_match` 的 regex 替換依原順序搬進 `plugins/propositions/scripts/_lib/normalize.py` 的有序步驟表，`normalize_for_match` 與 `normalize_with_map` 共用這張表，任何一道 regex 都不修改，對應決策「正規化步驟抽成單一步驟表，R1 與覆蓋檢查共用」；validator 改為從 `_lib` 匯入。驗證：3.1 的測試通過；pytest tests/ 全數通過；用 2.1 的基準逐檔 diff 為空。

- [x] 3.3 RED：為「Escaped percent signs are literal text in the shared normalization」寫測試：含 `\%` 的逐字 prop 通過 R1、`\\%` 之後的註解仍被剝除、覆蓋檢查看得到 `\%` 之後的文字（最後一項可先用 `normalize_with_map` 的字串驗證）。另加 pilot 發現的「同一行 `\%` 之後的句子」與反斜線奇偶數的邊界案例。驗證：pytest 執行這些測試，描述 #25 的測試（含 `\%` 的逐字 prop、同一行 `\%` 之後的句子、`\%` 之後的文字、奇數個反斜線）因 #25 而 FAIL；描述既有註解行為的測試（`\\%`、偶數個反斜線、單獨的 `%`）一開始就通過，屬於回歸測試。
- [x] 3.4 GREEN：步驟表中剝除註解的那一步改為只在 `%` 前面有偶數個反斜線時生效，對應決策「跳脫的 `\%` 是文字，不是註解」，修正 #25。驗證：3.3 的測試通過；pytest tests/ 全數通過；用 2.1 的基準比對，原文不含 `\%` 的帳冊 diff 為空，含 `\%` 的帳冊只有 R1／R13 從失敗變為通過，並逐項列在 commit message 中。

## 4. assign-prop-ids.py

- [x] 4.1 [P] RED：在 `tests/test_assign_prop_ids.py` 寫出「Temporary identifiers are replaced by UUID v7」的每個 scenario：一致替換 `id` 與 `cites`、保留既有 UUID、同一次輸出依行序嚴格遞增、未解析的暫時 cite（exit 1、無輸出）、重複的暫時 id（exit 1、無輸出）、拒絕覆寫（exit 2），以及輸出通過 validator 的 R2、R7、R8。驗證：pytest tests/test_assign_prop_ids.py 全部 FAIL。
- [x] 4.2 [P] GREEN：實作 `plugins/propositions/scripts/assign-prop-ids.py`，UUID v7 依 RFC 9562 §6.2 Method 1，以 `secrets` 取亂數，對應決策「暫時 id 由 script 換成 UUID v7，而不是讓 LLM 產生 UUID」。驗證：pytest tests/test_assign_prop_ids.py 全數通過；pytest tests/ 全數通過。

## 5. check-extraction-coverage.py

- [x] 5.1 RED：在 `tests/test_check_extraction_coverage.py` 寫出「Coverage check reports uncovered text in a line range」與「Coverage exclusions are a closed set and are reported」的每個 scenario：完全涵蓋（exit 0）、漏掉一個子句（exit 1、行號正確）、跨行的 prop、定位不到的 prop（警告）、同一行的章節標題與正文、被排除並列出的 float、--format json 的輸出形狀、多檔稿件以 --main 解析子檔前綴、不合法的範圍與輸入（exit 2）；`.tex` 只用合成文字。驗證：pytest tests/test_check_extraction_coverage.py 全部 FAIL。
- [x] 5.2 GREEN：實作 `plugins/propositions/scripts/check-extraction-coverage.py`，以 `normalize_with_map` 做字元層級的覆蓋計算，對應決策「覆蓋檢查以字元為單位，不以句子為單位」。驗證：pytest tests/test_check_extraction_coverage.py 全數通過；在 repo 外對實證稿件的一個 Results 段落執行一次，輸出列出被排除的 float，exit status 與人工判讀一致。

## 6. propositions:extract skill 與文件

- [x] 6.1 撰寫 `plugins/propositions/skills/extract/SKILL.md`，滿足「Extraction ships as its own skill」：frontmatter `name: extract`；流程照 design 的十一步；涵蓋「Extraction stages outside the ledger and merges only after confirmation」（暫存區、對 `main.jsonl` 副本跑 validator、dry-run diff、確認後才寫入、範圍內已有 prop 就停下）與「Extraction is complete only after both gates pass」（完成報告列出使用者接受的未涵蓋片段）；對應決策「抽取先寫到帳冊外的暫存檔，併入時要確認」。驗證：逐條對照 proposition-extraction spec 的 scenario 做內容審查；pytest tests/test_plugin_payload_tracked.py 通過（skill 有出貨、名稱唯一）。
- [x] 6.2 [P] 撰寫 `plugins/propositions/skills/extract/references/math.md` 與 `plugins/propositions/skills/extract/references/empirical.md`，並在 SKILL.md 依 profile 只載入其中一份，滿足「Profile selects the extraction reference」。math.md 取自現行 EXTRACTION-PROMPT 的兩種切法與環境邊界紀律；empirical.md 取自 1.1 pilot 的結果。驗證：內容審查，empirical.md 只使用 SCHEMA.md v1.7 中 `empirical` profile 的詞彙；SKILL.md 的載入條件與 spec 的兩個 scenario 一致。
- [x] 6.3 把 propositions skill 的 Operation C 改成一句話指向 `propositions:extract`，對應決策「抽取做成獨立 skill，不擴寫 Operation C」；proofread skill 的 Mode B 一節改為說明需要宣告 `profile: empirical` 與 schema 1.7。驗證：Operation C 一節提到 `propositions:extract`，而且不再含抽取步驟；Mode B 一節提到 profile。
- [x] 6.4 更新 Operation D：詢問 profile（只提供 `default` 與 `empirical`），`plugins/propositions/templates/ledger/_meta.template.json` 改為 schema 1.7 並記錄 profile，完成報告、ledger README 範本與 `plugins/propositions/docs/PLAYBOOK.md` 的交棒對象改為 `propositions:extract`，滿足「Operation D scaffolds a ledger for a manuscript without one」與「Onboarding hands off to extraction and validation」。驗證：在暫存目錄以 `empirical` 套用範本，產生的 `_meta.json` 含 schema 1.7 與 profile，validator 對它加上一筆合成 prop 的帳冊 exit 0；grep 確認範本與 PLAYBOOK 不再把 Operation C 當作下一步。

## 7. skill-creator eval

- [x] 7.1 在 repo 外建立 eval workspace，對應決策「eval workspace 與實證稿件放在 repo 外」：evals.json 至少兩題（實證稿件的一個段落、既有數學帳冊對應 `.tex` 的一個段落），每題同時跑有 skill 與沒有 skill 的版本並記錄 timing；assertions 至少包含暫存帳冊通過 validator、check-extraction-coverage.py exit 0、每個 `text` 逐字取自原文、id 由 assign-prop-ids.py 產生；彙整 benchmark，並用 skill-creator 的 generate_review.py 產生 viewer 交給使用者審閱。驗證：viewer 已產生，使用者送出 feedback.json。
- [x] 7.2 依 feedback.json 修改 skill；再量 description 的觸發。2026-11-01 執行結果：使用者對 iteration-1 的 6 個輸出回饋全部空白，依 skill-creator 的停止條件不再迭代內容。description 的部分，使用者選擇「先量一次」（20 句各 1 次）而不是最佳化迴圈；量到 20 句觸發率皆為 0，診斷一次 `claude -p` 後確認是量測受汙染：快取裡已安裝的舊版 0.4.0 `propositions:propositions` description 寫著「extract a new JSONL」，模型先呼叫它、第 4 個工具呼叫才進新 skill，而判定規則只看第一個工具呼叫。依此修改 `propositions` skill 的 description，不再宣傳抽取並明寫「拆成 propositions 用 /propositions:extract」。驗證：feedback 全部為空；觸發率在 0.5.0 安裝後以同一組 20 句重量（紀錄在 workspace 的 description/NOTES.md）。

## 8. 版本與發布準備

- [x] 8.1 更新 `plugins/propositions/README.md` 與 `CLAUDE.md` 的 skill 表與 R11／R12 說明（加入 profile），`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json` 升到 0.5.0，description 寫明支援 schema 1.7。驗證：pytest tests/test_marketplace_entries.py 通過；pytest tests/ 全數通過。
- [x] 8.2 commit 前做隱私自查：staged diff 不含實證稿件的原文、作者姓名、Overleaf 專案 ID、本機絕對路徑。只做本機 commit，推送依 Foresay 停下來確認。驗證：對 staged diff 用 grep 搜尋上述字串，結果為空；git log 顯示本機 commit，遠端尚未更新。
