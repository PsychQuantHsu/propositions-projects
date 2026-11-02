## 1. 格式與詞彙文件

- [x] 1.1 [P] 改寫 `plugins/propositions/docs/STRUCTURE.md` 成 2.0 格式，落實決策「三層依存樹取代相鄰關係」「段落是封閉子樹，預設由 tex 推出」「向前的關係用「頭在後面」表達」「start、shift、return 由樹推出」「cites 是疊加的依賴圖，不重新標註」「草稿用 pending 表示還沒寫出來的頭」「右邊緣作為下一句的接點」。完成時：兩個附檔的欄位表與 design Implementation Contract 一致；10 個關係列成封閉列舉並寫明「不得依性質相似類推」，`basis` 寫明方向（頭或目標提供、這一句使用）；`start`／`shift`／`return` 的推導定義、右邊緣與等頭句子的定義各有一段；原「Why no fourth layer」的理由改成樹的理由；附一個以位置編號與短連接詞表示的 §3.3 依存樹例子（不貼整句）。驗證：內容審查，逐欄對照 design 的格式表，且全文不再出現 `refers_to` 作為 2.0 欄位。
- [x] 1.2 [P] 改寫 `plugins/propositions/skills/construct/references/vocabulary.md`，依決策「關係詞彙改為九個內容關係加 basis」給出標註程序：每句先判斷是否為段根，否則在同段內選頭（可在前或在後），再依優先序選 10 個關係之一；每段選段頭與關係；每節判斷 `parent`。完成時：三張值表（關係、承諾種類、章節角色）與腳本常數一致，`basis` 的方向附正反例。驗證：`pytest tests/test_validate_structure.py -k vocabulary` 通過（值集合與 `validate-structure.py` 常數完全相同）。
- [x] 1.3 [P] 更新 `docs/SCHEMA.md` 的附檔一節：版本 2.0、`paragraphs`、`sections[].parent`、1.0 須以 `migrate-structure-v2.py` 遷移。驗證：內容審查，且 `pytest tests/test_ledger_profiles.py` 的 golden 測試仍全數通過（帳冊輸出不受影響）。

## 2. 測試資料

- [x] 2.1 [P] 擴充 `tests/structure_case.py` 的建構器，能產生 2.0 附檔：段落清單、每句的 `head`／`relation`、`pending`、`also`、章節 `parent`、`structure_version` `"2.0"`。完成時：既有測試改用新建構器後仍能表達原本的案例。驗證：3.1 的 RED 測試能用它建出各種案例，失敗原因是腳本行為不符而不是建構器錯誤。
- [x] 2.2 [P] 把現有 1.0 fixture 原封複製到 `tests/fixtures/structure-v1/`（給遷移測試當輸入），再把 `tests/fixtures/structure/` 改成手工標註的 2.0：段落依 `main.tex` 空行、每段一個根、至少一句頭在後面、一節帶 `parent`；README 更新說明。驗證：3.5 完成後 `validate-structure.py --jsonl tests/fixtures/structure/main.jsonl` 結束碼 0、S7 與 S8 無警告；`structure-v1/` 與原 1.0 fixture 逐位元相同。

## 3. validate-structure.py（測試先行）

- [x] 3.1 寫失敗測試（RED）：Relations form a closed vocabulary（spec S2 關係表六列，含 `shift` 被拒、`refers_to` 被拒）；Propositions form a dependency tree within each paragraph（spec S2 樹表五列、頭在別段、頭在後面通過、不帶 `--partial` 時 `pending` 失敗、帶 `--partial` 且在最後一段時通過、`pending` 不在最後一段時失敗、`also` 指向自己或頭時失敗）。驗證：`pytest tests/test_validate_structure.py` 中新測試全數失敗，失敗原因是腳本仍是 1.0 行為。
- [x] 3.2 寫失敗測試（RED）：The section plan follows ledger order（`parent` 指向較晚的章節失敗、版本須為 `"2.0"`）；Paragraphs form a dependency tree within each section（段落跨節、段頭在別節、一節兩個根段、段頭成環）；Structure validation reports per rule with fixed exit codes（輸出 S1–S8 共八行、1.0 附檔結束碼 2 且訊息含 `migrate-structure-v2.py`）。驗證：新增測試全數失敗。
- [x] 3.3 寫失敗測試（RED）：Crossing arcs are reported as warnings（交叉的一對報警告且結束碼 0、巢狀不算交叉、段落弧的交叉）；Basis edges agree with the ledger's cites（`basis` 的目標不在 `cites` 時警告、在 `cites` 時無警告、`also` 的 `basis` 也檢查）。驗證：新增測試全數失敗。
- [x] 3.4 在 `plugins/propositions/scripts/validate-structure.py` 實作 2.0 的 S2 與 S5：關係詞彙 10 個、段內依存樹（每段一根、頭不出段、無環、`pending` 規則、`also` 規則）、段落計畫（遞增、不跨節、每節一個根段、段頭不成環）、章節 `parent`、版本檢查。驗證：3.1 與 3.2 的測試全部通過。
- [x] 3.5 實作 S7（交叉弧只警告並計數）與 S8（`basis` 對照帳冊 `cites`），摘要輸出擴為 S1–S8 八行，1.0 附檔以結束碼 2 拒絕並指向遷移工具。驗證：`pytest tests/test_validate_structure.py` 全部通過，`pytest tests/` 全套全綠，2.0 fixture 結束碼 0。

## 4. structure-state.py（測試先行）

- [x] 4.1 寫失敗測試（RED），涵蓋 The state query reports what the article owes at a position：spec 的三個範例（`kind` 排序的未兌現承諾、段內右邊緣為位置 4、2、1、`scope` 排序讓內層章節的計畫排前）、段根的關係輸出為 `root`、段根尚未出現時 `paragraph` 的根為 null、`pending` 的句子被列出且查詢不因 `pending` 失敗、每個承諾帶 `scope`（段落 id 與章節 id）、輸出含 `order`、未知 UUID 結束碼 2。驗證：`pytest tests/test_structure_state.py` 中新測試全數失敗。
- [x] 4.2 在 `plugins/propositions/scripts/structure-state.py` 實作右邊緣（句、段、節三層節點）、等頭的句子、承諾範圍與 `--order kind|scope`（預設 `kind`），落實決策「右邊緣作為下一句的接點」與「承諾範圍與 scope 排序以量測把關」的查詢部分。驗證：`pytest tests/test_structure_state.py` 全部通過，`pytest tests/` 全綠。

## 5. 新工具（各自測試先行）

- [x] 5.1 [P] 先寫 `tests/test_derive_paragraphs.py` 的失敗測試，再實作 `plugins/propositions/scripts/derive-paragraphs.py`，落實 Paragraph plans are derived from the TeX source：空行分段、沒有句子的段跳過、章節起點落在段中時切開、帶檔名前綴的 location 結束碼 2、對 2.0 fixture 的 `main.tex` 推出的段落與 fixture 的 `paragraphs` 起點一致。驗證：`pytest tests/test_derive_paragraphs.py` 全部通過。
- [x] 5.2 先寫 `tests/test_migrate_structure.py` 的失敗測試，再實作 `plugins/propositions/scripts/migrate-structure-v2.py`，落實 Version 1.0 sidecars are migrated, not read 與決策「升版 2.0 只遷移不並存」：以 `tests/fixtures/structure-v1/` 為輸入，輸出通過 S1–S6、複查報告列出每筆 `start`／`shift`／`return` 與被換成 `continue` 的段落、`main.jsonl` 與 1.0 附檔的 sha256 前後相同、輸入已是 2.0 時結束碼 2 且不寫任何檔。驗證：`pytest tests/test_migrate_structure.py` 全部通過。
- [x] 5.3 [P] 先寫 `tests/test_structure_metrics.py` 的失敗測試，再實作 `plugins/propositions/scripts/structure-metrics.py`，落實 Structure metrics report whether the tree fits 與決策「量測獨立成 structure-metrics.py」：spec 的交叉比例範例（0.5）、命中與未命中範例（`kind` 未命中、`scope` 命中）、右邊緣長度的中位數／平均／最大、頭在前與在後的計數、結構無效時結束碼 1、輸入錯誤結束碼 2。驗證：`pytest tests/test_structure_metrics.py` 全部通過。

## 6. propositions:construct skill

- [x] 6.1 改寫 `plugins/propositions/skills/construct/SKILL.md` 的標註模式，落實 Annotation writes sidecars only after validation and confirmation：先跑 `derive-paragraphs.py` 作為段落起點，逐段標頭與關係、段頭、章節 `parent`，暫存處驗證到結束碼 0，摘要列出各關係數量、頭在前／在後的數量、段落數、承諾的開出與兌現位置、章節與角色與 `parent`、S7 與 S8 警告、`structure-metrics.py` 的右邊緣中位長度，使用者確認後才寫入。驗證：在 2.0 fixture 的副本上照 SKILL.md 走一次，暫存檔在帳冊目錄外、validator 結束碼 0、摘要含上述各項、`main.jsonl` 的 sha256 前後相同。
- [x] 6.2 改寫 SKILL.md 的 next 模式，落實 Next mode proposes at most three candidates without writing：讀右邊緣、等頭的句子與承諾；有等頭的句子時第一個候選必須是它們的頭；每個候選寫明掛在右邊緣的哪個節點（或它是哪些等頭句子的頭、或開新段）、關係與連接詞、推進的承諾、預期的 `claim_type`。驗證：把 2.0 fixture 截短到最後一句為 `pending` 的狀態走一次，第一個候選是那一句的頭；稿件、`main.jsonl` 與兩個附檔的 sha256 前後相同。

## 7. 試標

- [x] 7.1 依決策「先試標再全篇標註，第二篇用 psychophysical_representations」，在 repo 外的暫存處試標範例稿件 §3.3 與 psychophysical_representations 的 §2（Affine, gain-control, and Falmagne's power law）：試標節逐句標頭與關係、段頭，其餘部分用機械起點補滿（範例稿件用 `migrate-structure-v2.py` 的輸出；psychophysical_representations 用段首為根、其餘頭為上一句、關係 `continue`），使暫存附檔在 `--partial` 下通過 `validate-structure.py`。完成時：試標報告記錄兩節的 S7 交叉數、需要 `condition` 的句子數、「先鋪事實、下一句再解釋」的句子數與當下選用的關係、段落關係是否夠用。驗證：兩份暫存附檔 `validate-structure.py --partial` 結束碼 0；報告的數字寫進本任務的完成紀錄（只記數字與位置編號）。
  - 完成紀錄（2026-11-02，暫存區在 repo 外）：範例稿件 §3.3 以 `migrate-structure-v2.py` 的輸出為起點（遷移本身 S1–S8 全過，複查 30 句、16 段、3 節），試標 #210–#245（36 句、5 段）：S7 交叉 0（句子弧與段落弧）；頭在後面 4 句（#211、#215、#220、#221）；需要 `condition` 的 1 句（#220）；「先鋪事實、下一句再解釋」1 處（#214／#216），事實當段根、解釋用 `reason` 即可；段根有歧義的 2 段（證據 → 結論，可反向標）；段落關係夠用（specification、consequence、sequence、addition，另有 1 個非相鄰段頭）。暫存附檔不加 `--partial` 結束碼 0。psychophysical_representations §2 在重排副本上試標（#41–#61，21 句、8 段）：S7 交叉 0；頭在後面 0；3 個「Suppose …」以段根加 `consequence` 表達，不需要 `condition`；分案 2 處（#58、#59）用 `specification`／`addition` 略嫌勉強；證明段以 `reason` 掛在敘述段上。暫存附檔 `--partial` 結束碼 0。另發現阻礙：該稿帳冊行序不是閱讀順序（364 行中 363 行重排後換位，區塊依「敘述＋附錄證明」排），全篇標註前須先決定是否把 `main.jsonl` 重排成閱讀順序（8.3）。
- [x] 7.2 依試標報告決定詞彙：需要新增或修改關係時，用 `/spectra-ingest` 修訂 spec 與 design，再同步 `validate-structure.py` 常數、1.1 與 1.2 的文件與 3.x 的測試；不需要時在完成紀錄寫明理由。驗證：`spectra validate add-discourse-dependency-tree` 通過，`pytest tests/` 全綠。
  - 完成紀錄（2026-11-02）：不改詞彙，spec 不需修訂。理由：(1) `condition` 只出現 1 次（#220），範圍或條件片語以 `specification` 表達（它限縮頭的適用範圍），數學的「Suppose X. Then Y.」以 X 為段根、Y 用 `consequence`；(2) 先鋪事實再解釋不需要新關係，事實當段根、解釋用 `reason`；(3) 段根歧義以標註慣例解決：段根取該段第一個不掛在後一句上的命題，結論用 `consequence` 掛在證據上；(4) 分案：第一個分案用 `specification` 掛在前提上，其餘分案用 `addition`。以上寫進 vocabulary.md 與 STRUCTURE.md（含 §3.3 例子改為 #214 為根、#220 用 `specification`），design 的 Open Questions 同步記為已解決。

## 8. 全篇標註與量測

- [x] 8.1 [P] 範例稿件（在它自己的 repo）：用 `migrate-structure-v2.py` 把 1.0 附檔轉成 2.0 起點，依 construct 標註模式重新標 Abstract 到 §1.2（位置 1–147）的頭、關係與段頭。驗證：暫存附檔 `validate-structure.py --partial` 結束碼 0，複查報告中這一範圍的每筆都已處理。
- [ ] 8.2 範例稿件：標完 §2 到 §4（位置 148–294）、所有段頭與章節 `parent`，經使用者確認後寫入附檔。驗證：不加 `--partial` 時 `validate-structure.py` 結束碼 0；`main.jsonl` 的 sha256 前後相同。
- [ ] 8.3 [P] psychophysical_representations（在它自己的 repo）：依 construct 標註模式建立 `structure.json`（章節、角色、`parent`、thesis）與承諾，並標 §1 到 §2 的頭、關係與段頭。驗證：暫存附檔 `validate-structure.py --partial` 結束碼 0。
- [ ] 8.4 psychophysical_representations：標完 §3 到 §9 與所有段頭，經使用者確認後寫入附檔。驗證：不加 `--partial` 時 `validate-structure.py` 結束碼 0；`main.jsonl` 的 sha256 前後相同。
- [ ] 8.5 在兩篇上跑 `structure-metrics.py`，把交叉比例、右邊緣長度、頭的方向、關係計數與 S8 警告數記入 `docs/REFERENCE-MANUSCRIPTS.md`（只記數字）。兩篇句子弧的交叉比例都不超過 5% 才繼續；超過時停在本任務，回報並重新檢討模型。驗證：文件出現兩篇的數字，交叉比例對照 5% 的判定寫在完成紀錄。
- [x] 8.6 落實決策「承諾範圍與 scope 排序以量測把關」：比較範例稿件上 `kind` 與 `scope` 的命中數。`scope` 嚴格勝出時，用 `/spectra-ingest` 把預設改為 `scope`，同步 `structure-state.py` 與測試；否則維持 `kind`，把兩個數字以 comment 記到 #31。驗證：完成紀錄寫明兩個命中數與採用結果；`pytest tests/` 全綠。
  - 完成紀錄（2026-11-02）：範例稿件 2.0 標註上 `kind` 89／231、`scope` 94／231（承諾與章節 `parent` 決定排序，與各句的頭無關），`scope` 嚴格勝出，預設改為 `scope`。改動只有預設值一處，直接修改 spec delta、proposal、design 與 `structure-state.py`、測試、STRUCTURE.md，未另跑 `/spectra-ingest`；數字另以 comment 記到 #31。

## 9. 發佈前整理

- [ ] 9.1 更新使用者文件：`plugins/propositions/README.md`、`CLAUDE.md` 的 construct 與附檔兩列、`plugins/propositions/docs/PLAYBOOK.md` 的結構標註階段、`docs/REFERENCE-MANUSCRIPTS.md` 的範例改成依存樹。驗證：在上述檔案中搜尋 `refers_to`、`S1–S6`、`relation` 的「上一句」說法，除遷移說明外沒有殘留的 1.0 描述。
- [ ] 9.2 propositions 升為 0.7.0（`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json` 一致）。驗證：`pytest tests/` 全綠、`spectra validate add-discourse-dependency-tree` 通過、兩個 JSON 的版本號相同。
