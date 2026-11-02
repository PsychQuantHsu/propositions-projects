## 1. 附檔格式、詞彙與測試資料

- [x] 1.1 [P] 寫 `plugins/propositions/docs/STRUCTURE.md`，定義兩個附檔的格式與三套封閉詞彙，落實決策「附檔而非擴充帳冊欄位」「三層模型：承諾、章節角色、相鄰關係」「相鄰關係詞彙以 PDTB-3 sense 為骨架」「子句層級的 prop 之間也標關係」「跨段落與跨節照常標關係」「承諾種類與兌現規則」「章節角色用單一封閉詞彙」。完成時：12 個關係、7 種承諾、9 個角色各自列成封閉列舉並寫明「不得依性質相似類推」，每個值有邊界說明與一個實例（關係與承諾的實例只用期刊版的短連接詞片段，不貼整句），關係附優先序。驗證：內容審查，逐值對照 design.md 的三張表，數量與名稱一致，且每個值都有實例。
- [x] 1.2 [P] 在 `docs/SCHEMA.md` 加一節，說明 Structure sidecars sit beside the ledger without changing it：兩個附檔放在帳冊目錄、`main.jsonl` schema 不變、`validate-propositions.py` 不讀附檔，並指向 STRUCTURE.md。驗證：`pytest tests/test_ledger_profiles.py` 的 golden 測試仍全部通過（沒有附檔的帳冊輸出逐位元相同），且 SCHEMA.md 出現這一節。
- [x] 1.3 [P] 在 `tests/fixtures/structure/` 建立合成測試資料：一份 12 個 prop 的有效帳冊（記憶研究主題，不含任何真實稿件文字）＋有效的 `structure.json` 與 `discourse.jsonl`，涵蓋全部 7 種承諾與至少 8 種關係。完成時：`validate-propositions.py` 對這份帳冊結束碼 0。驗證：用該指令實跑。

## 2. validate-structure.py（測試先行）

- [x] 2.1 寫 `tests/test_validate_structure.py` 的第一批失敗測試（RED）：Discourse records cover the ledger in reading order（spec 的 S1 範例表五列逐列一個測試，含已退役 prop 不需紀錄）、Relations form a closed vocabulary（S2 範例表七列，含大小寫不同的值被拒絕）。驗證：`pytest tests/test_validate_structure.py` 全數失敗，且失敗原因是腳本不存在或輸出不符，不是測試本身寫錯。
- [x] 2.2 補第二批失敗測試（RED）：Commitments are opened before they are discharged（先兌現後開出、自己兌現自己、兌現 `future_work`）；A complete article keeps every commitment（S4 嚴重度表七列，以及決策「未完成稿件用 partial 模式」的降級）；The section plan follows ledger order（順序錯、未列角色、第一節不從第一個 prop 開始、thesis 為空）；Announcements are kept nearby（下一節兌現通過、隔兩節給警告且不影響結束碼）；Structure validation reports per rule with fixed exit codes（只有警告時結束碼 0、第 4 行 JSON 壞掉時結束碼 2 並指出第 4 行、缺 `discourse.jsonl` 時結束碼 2 並指出檔名）。驗證：新增測試全數失敗。
- [x] 2.3 實作 `plugins/propositions/scripts/validate-structure.py`，介面與輸出照 design 的 Implementation Contract（`--jsonl`、`--structure`、`--discourse`、`--partial`、`--format text|json`；每條規則一行 PASS/FAIL/WARN；結束碼 0/1/2），讀帳冊時跳過帶 `retired` 的 prop。驗證：`pytest tests/test_validate_structure.py` 全部通過，`pytest tests/` 全套仍全綠。
- [x] 2.4 加測試確認附檔不影響既有 validator：同一份合成帳冊在有附檔與沒有附檔時，`validate-propositions.py` 的 stdout 與結束碼完全相同。驗證：`pytest tests/test_validate_structure.py -k sidecar` 通過。

## 3. structure-state.py（測試先行）

- [x] 3.1 [P] 寫 `tests/test_structure_state.py` 的失敗測試（RED），涵蓋 The state query reports what the article owes at a position：spec 範例（位置 6 的未兌現承諾依序為 `c-ann-1`、`c-plan-2`、`c-q-1`，`c-fw-1` 只出現在未來研究清單）、決策「狀態查詢依緊迫程度排序未兌現承諾」的同種類依開出位置排序、t 所在的節、`--at end`、未知 UUID 結束碼 2、附檔違反 S1–S3 時結束碼 1。驗證：新增測試全數失敗。
- [x] 3.2 實作 `plugins/propositions/scripts/structure-state.py`，輸出欄位照 Implementation Contract（位置與總數、所在節的 id／標題／角色、t 的關係、排序後的未兌現承諾與間隔數、未來研究清單、thesis 是否已出現），支援 `--format json`。驗證：`pytest tests/test_structure_state.py` 全部通過，全套仍全綠。

## 4. propositions:construct skill

- [x] 4.1 [P] 寫 `plugins/propositions/skills/construct/references/vocabulary.md`：三套詞彙的標註指南（每個值怎麼判斷、優先序、範例），並加一個測試確認 vocabulary.md 列出的值集合與兩個腳本內的常數完全相同。驗證：`pytest tests/test_validate_structure.py -k vocabulary` 通過。
- [x] 4.2 寫 `plugins/propositions/skills/construct/SKILL.md` 的標註模式，落實 Annotation starts from a validated, fully covered ledger 與 Annotation writes sidecars only after validation and confirmation：先跑 `validate-propositions.py` 與 `check-extraction-coverage.py`，不通過就停下並轉介 `propositions:extract`；附檔先寫在帳冊目錄以外的暫存處，`validate-structure.py` 結束碼 0 後列出摘要（各關係數量、每個承諾的開出與兌現位置、章節與角色），使用者確認後才寫入；全程不改 `main.jsonl`。驗證：在合成帳冊上照 SKILL.md 實走一次，暫存檔在帳冊目錄外、validator 結束碼 0、`main.jsonl` 的 sha256 前後相同。
- [x] 4.3 在 SKILL.md 寫下一步模式，落實 Next mode proposes at most three candidates without writing：跑 `validate-structure.py --partial` 與 `structure-state.py --at end`，說明目前章節角色與排序後的未兌現承諾，提出至多 3 個候選下一句，每個候選寫明推進哪個承諾（或為什麼該 `shift`）、用什麼關係與連接詞、預期的 `claim_type`。驗證：把合成帳冊截到第 10 個 prop（announcement 在第 10 個開出、尚未兌現）實走一次，第一個候選兌現開著的 announcement，稿件、`main.jsonl` 與兩個附檔的 sha256 前後相同。
- [x] 4.4 寫 construct 的 description，落實 Construction requests route to the construct skill，並檢查 `propositions:extract` 與 `propositions:propositions` 的 description 沒有宣稱建構類請求。驗證：比照 add-extract-skill 的觸發測試，10 句建構類請求與 10 句抽取類請求各跑一次，記錄第一個工具呼叫，建構類命中 `propositions:construct`、抽取類命中 `propositions:extract` 的比例寫進 tasks 完成紀錄。
  - 完成紀錄（2026-11-02，claude-opus-5-5，每句 1 次，嚴格＝第 1 個工具呼叫、寬鬆＝前 4 個內；量測資料存在 repo 外）：抽取類三輪皆 10/10 命中 extract（嚴格 9–10/10），沒有一句被 construct 搶走。建構類：空目錄兩輪嚴格 0/10、1/10，寬鬆 4/10、4/10；有帳冊的專案嚴格 0/10、寬鬆 6/10（問下一句與標註結構 6/6，檢查承諾是否兌現 0/4，模型改為直接讀稿）。description 改寫一輪（先寫它回答的兩個問題、補口語說法）。已知限制：稽核類請求的觸發偏弱，使用者選擇跑 description 最佳化迴圈。
  - 最佳化迴圈（skill-creator run_loop，2026-11-02，claude-opus-5-5，20 句 × 3 次，60/40 訓練／測試，5 輪改寫）：5 個版本分數完全相同（訓練 6/12、測試 4/8）——應觸發的 10 句在所有版本的第一個工具呼叫都不是 construct（0/30），不應觸發的全對。run_loop 只認第一個工具呼叫，而在有帳冊的專案裡，模型對「我的稿件」類請求一律先看檔案，這是地板效應，description 措辭分辨不出差異。保留原 description（迴圈選出的 best 也是原版）。實際可用度以前 4 個工具呼叫內的寬鬆量測為準（6/10）。

## 5. 範例稿件 worked example（私有 repo）

- [x] 5.1 依決策「Worked example 放在 article1 umbrella，不放 Overleaf」，在 article1 umbrella 的 `propositions/` 以 Operation D 建立帳冊骨架（profile `empirical`、schema 1.7、`source.file` 指向 submodule 的 `manuscript/main.tex`）。完成時：骨架在 umbrella repo，submodule（Overleaf）沒有新增任何檔案。驗證：`git -C` umbrella 的 status 只出現 `propositions/`，submodule 的 status 是乾淨的；`validate-propositions.py` 對骨架結束碼 0。
- [x] 5.2 用 `propositions:extract` 抽取摘要與第 1 節（含 1.1、1.2）。驗證：`check-extraction-coverage.py` 對這些行範圍回報 0 段未覆蓋，`validate-propositions.py` 結束碼 0。
- [x] 5.3 用 `propositions:extract` 抽取第 2、3、4 節。文末聲明（Declaration of competing interest、CRediT author statement）與附錄的問卷題目不抽取：它們不屬於論證，9 個章節角色也沒有對應值；在 `_meta.json` 的 coverage 註明排除範圍與理由。驗證：同 5.2，涵蓋到第 4 節結尾。
- [x] 5.4 依決策「先完成標註再做下一步建議」，用 construct 的標註模式替完整帳冊建立附檔。完成時：`validate-structure.py`（非 partial）結束碼 0；標註中遇到詞彙不夠用的地方逐一記錄；若需要新的詞彙值，停下來向使用者提出，不自行加值（詞彙變更等於 spec 變更）。驗證：validator 實跑結果與詞彙缺口清單。
- [x] 5.5 在三個切點（§1.1 結尾、§3.2 結尾、§3.3 中段）把帳冊截斷，跑下一步模式，將候選與期刊版實際的下一句比對（推進的承諾是否相同、關係是否相同）。驗證：比對表寫進 worked example 報告，三個切點各一列。
- [x] 5.6 把彙總寫進 `docs/REFERENCE-MANUSCRIPTS.md`：prop 數、各關係分布、各種承諾數量與是否全部兌現、三個切點的比對結果。完成時：只含數字與短的連接詞片段，沒有帳冊內容、本機路徑或 Overleaf 專案編號。驗證：隱私自審，以及 `grep` 確認沒有 `/Users/`、`~/`、`overleaf.com`。

## 6. 文件、版本與收尾

- [x] 6.1 更新 `plugins/propositions/README.md`、`plugins/propositions/docs/PLAYBOOK.md`、`CLAUDE.md`，加入 construct skill 與兩個腳本；`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json` 版本 0.5.0 → 0.6.0。驗證：新檔案 `git add` 後 `pytest tests/test_plugin_payload_tracked.py` 通過，兩個 JSON 的版本號一致。
- [x] 6.2 全面驗證並回報 #26：`pytest tests/` 全綠、`spectra validate add-article-construction-model` 通過；在 #26 留言連到本變更，並把 Clarity Surface 五列依 design 的五個決策標為 resolved。驗證：測試與 validate 的輸出、`gh issue view 26` 顯示五列都是 resolved。
