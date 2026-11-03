## 1. 詞彙與檢查

- [x] 1.1 在 tests/test_move_vocabulary.py 先寫失敗測試：合法詞彙可載入；未知欄位、重複 id、id 格式不符、缺 `does` 或 `zh` 都要報錯並點名該值；沒裝 PyYAML 時丟出點名 PyYAML 的 `InputError`（以 sys.modules 遮蔽 `yaml` 模擬）（Requirement: A closed vocabulary defines moves and paragraph types；設計：詞彙封閉，走法開放、讀 YAML 用 PyYAML，只在需要時載入）
- [x] 1.2 實作 plugins/propositions/scripts/_lib/move_vocabulary.py，並寫 plugins/propositions/catalog/vocabulary.yaml 的種子詞彙（21 個步驟、13 個段落類型，每個都有 `does` 與 `zh`）；1.1 的測試全過
- [x] 1.3 在 tests/test_validate_structure.py 先寫失敗測試：未知 `move` 與未知 `type` 使 S9 FAIL 且 exit 1；沒有這兩個欄位時不載入詞彙、S9 PASS；走法順序再怪也不報；`--vocabulary` 可覆寫路徑；詞彙壞掉時 exit 2（Requirement: Records name a move and paragraphs name a type、Requirement: Structure validation reports per rule with fixed exit codes；設計：不升 `structure_version`）
- [x] 1.4 在 plugins/propositions/scripts/validate-structure.py 加上規則 S9 與 `--vocabulary`，摘要改為 S1 到 S9；tests/fixtures/structure 原樣通過，1.3 的測試全過

## 2. 讀法工具

- [x] 2.1 在 tests/test_structure_explain.py 先寫失敗測試，對應 spec 的五個 scenario：一行寫出步驟標籤、頭、白話關係與關係名；深度以縮排呈現；未標者顯示 `未標`；`--no-text` 不含帳冊文字；不存在的段落 exit 2 並點名；另測 `also` 列出目標位置、段落行寫出類型與頭段落（Requirement: The explain tool reads out how sentences relate；設計：讀法工具是主要成果）
- [x] 2.2 實作 plugins/propositions/scripts/structure-explain.py（`--paragraph`、`--section`、`--all`，text 與 json），design 表列的 10 個關係都有白話說明；2.1 的測試全過，且確認工具不寫任何檔案

## 3. 標註流程

- [x] 3.1 [P] 在 tests/test_structure_tools.py 先寫失敗測試：`--moves-only` 的輸入帶頭與關係；merge 只改 `move`、`type`，移除這兩欄後與暫存內容相同；少答一筆則 exit 2 且不寫檔。然後在 plugins/propositions/scripts/structure-batch.py 實作（Requirement: Moves are batch-annotated without touching the tree；設計：步驟和關係分開記，不合併）
- [x] 3.2 [P] 改 plugins/propositions/skills/construct/SKILL.md：標註流程要標 `move`、`type`，摘要列出次數，缺值時停下回報；新增 explain 用法（只讀、沒有附檔就說明並提議標註）；description 加上句子關係的請求；next 模式不讀目錄。同步 plugins/propositions/skills/construct/references/vocabulary.md 的判定程序與 plugins/propositions/skills/construct-batch/SKILL.md 的只標步驟流程（Requirement: Annotation writes sidecars only after validation and confirmation、Requirement: Construction requests route to the construct skill、Requirement: Explain mode reads out how sentences relate、Requirement: Next mode does not consult the paragraph catalog）
- [x] 3.3 [P] 改 plugins/propositions/docs/STRUCTURE.md（新欄位、S9、詞彙與目錄的關係、explain 的用法）與 docs/SCHEMA.md 的附檔節；確認沒有任何檔案宣稱 next 模式會讀目錄

## 4. 試標與全篇標註

- [x] 4.1 兩篇稿件各試標一節（暫存位置，用只標步驟的批次模式）：讀 `structure-explain.py` 的輸出逐段檢查，增刪 plugins/propositions/catalog/vocabulary.yaml，並把慣例寫進 plugins/propositions/skills/construct/references/vocabulary.md；每次改詞彙後重跑 tests/test_move_vocabulary.py（設計：步驟要說明段落內的功能，不重複 `claim_type`）
- [x] 4.2 兩篇全篇標註：用 `structure-batch.py --moves-only` 切批、分給 subagent、合併到暫存副本；`validate-structure.py` S1 到 S9 都過，且 `move` 與 `type` 的覆蓋率都是 100%；移除這兩欄後與現有附檔內容相同
- [x] 4.3 一致性：獨立的 subagent 只看詞彙與句子，重標兩篇各至少 15 段、合計至少 60 句（不給第一次的結果），用 `structure-metrics.py --compare-moves` 算 κ。低於 0.6 就修訂詞彙或定義、重標並再量一次；第二次仍低於 0.6 就停下回報，不宣告完成（設計：步驟靠模型標，所以一定要量一致性）

## 5. 目錄與量測

- [x] 5.1 [P] 在 tests/test_build_paragraph_catalog.py 先寫失敗測試：轉移依標籤計數；未標者列入 `excluded`；輸出不含文字、proposition id、段落 id 與路徑；同樣輸入得到相同位元組；`--check` 過期時 exit 1 且不改檔。然後實作 plugins/propositions/scripts/build-paragraph-catalog.py（Requirement: The paragraph catalog is generated from annotated sidecars；設計：手寫的詞彙和產生的目錄是兩個檔案）
- [x] 5.2 [P] 在 tests/test_structure_metrics.py 先寫失敗測試：覆蓋率、Cramér's V、留一段的命中率、`--compare-moves` 的 κ（8／10 一致時 raw agreement 0.80 且 n=10）；沒有步驟時報告不變。然後改 plugins/propositions/scripts/structure-metrics.py（Requirement: Metrics report whether moves add anything）
- [x] 5.3 從兩篇暫存附檔產生 plugins/propositions/catalog/paragraph-catalog.yaml（標籤 `empirical`、`default`），`--check` 通過；grep 確認檔內沒有稿件文字、proposition id 與本機路徑
- [x] 5.4 把結果寫進 docs/REFERENCE-MANUSCRIPTS.md：κ、Cramér's V、留一段命中率（和 #33 的基準 55%／77%、59%／81% 比較）、步驟與類型的分布；同時寫明 κ 量到的是模型之間的一致

## 6. 收尾

- [x] 6.1 用兩篇暫存附檔跑 `structure-explain.py`，各挑 3 段給維護者看讀法輸出，取得確認後才把附檔寫進各自 repo 並 commit；`main.jsonl` 的 sha256 不變
- [x] 6.2 更新 plugins/propositions/README.md、plugins/propositions/docs/PLAYBOOK.md、CLAUDE.md；版本升到 0.8.0（plugins/propositions/.claude-plugin/plugin.json 與 .claude-plugin/marketplace.json）；README 註明用到 `move` 時需要 PyYAML
- [x] 6.3 總驗證：`pytest tests/` 全過（含 tests/test_plugin_payload_tracked.py，確認 catalog 兩個檔案有進 git）、`spectra validate add-paragraph-moves` 通過；對 `/propositions:construct` 試 5 句「這段句子之間是什麼關係」的請求，確認會觸發 explain 用法；把結果留言到 #33

## 7. 連結清單與查詢（全篇標完後追加）

- [x] 7.1 在 tests/test_build_link_catalog.py 先寫失敗測試：spec 的五個 scenario（閱讀順序與依賴分開記、跨節引用的 scope、兌現帶承諾種類、不含稿件內容、`--check` 過期時 exit 1 且不改檔），另測 `also` 與 `paragraph` 列、標頭逐字相符、同樣輸入得到相同位元組、缺 move 的連結不寫入且印出數量、`pending` 頭與詞彙外的值 exit 2。然後把 plugins/propositions/scripts/build-paragraph-catalog.py 改寫成 plugins/propositions/scripts/build-link-catalog.py，共用定義放 plugins/propositions/scripts/_lib/link_catalog.py，並移除 tests/test_build_paragraph_catalog.py（Requirement: The link catalog is generated from annotated sidecars；設計：目錄是帶類型的連結清單，不是 DAG）
- [x] 7.2 在 tests/test_structure_links.py 先寫失敗測試：`sentence` 的兩個方向（spec 的 scenario）、`also`、跨段與跨節的 `cites`、承諾兌現、用 proposition id 指定、`--no-text`、找不到的位置 exit 2、不寫檔；`catalog` 的計數依總數排序、`--type` 與 `--label` 篩選、`--to` 反查、`--unseen` 的補集（spec 的 scenario）、`--unseen` 缺 `--kind` 與拼錯的值 exit 2、目錄標頭或次數不合法 exit 2。然後實作 plugins/propositions/scripts/structure-links.py（Requirement: Link queries report every link of a sentence and the paths of a value；設計：「所有可能」只分看過與沒看過、查詢工具）
- [x] 7.3 從兩篇稿件的附檔產生 plugins/propositions/catalog/links.csv，`--check` 通過；刪除 plugins/propositions/catalog/paragraph-catalog.yaml；用帳冊逐條比對，確認檔內沒有任何 proposition 文字片段、proposition id 或本機路徑；用 `structure-links.py sentence` 在兩篇各查 2 句，確認與 `structure-explain.py` 的輸出一致
- [x] 7.4 改文件：plugins/propositions/docs/STRUCTURE.md（目錄改成連結清單：六種 kind、方向、scope、為什麼不是 DAG、看過與沒看過）、plugins/propositions/skills/construct/SKILL.md（explain 用法加單句查詢、next 模式不讀 `links.csv`；Requirement: Next mode does not consult the link catalog）、plugins/propositions/skills/construct/references/vocabulary.md、plugins/propositions/README.md、CLAUDE.md、docs/REFERENCE-MANUSCRIPTS.md（各種連結的數量、有環的量測、看過 136／576）；確認沒有檔案再提到 `paragraph-catalog.yaml`
- [ ] 7.5 總驗證：`pytest tests/` 全過（含 tests/test_plugin_payload_tracked.py，確認 `links.csv` 進了 git、舊 YAML 已移除）、`spectra validate add-paragraph-moves` 通過、版本維持 0.8.0（尚未發布）；把結果留言到 #33

