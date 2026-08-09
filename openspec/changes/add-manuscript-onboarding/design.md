## Context

propositions plugin（本 repo）是 Hsu case 的抽象化產物：Layer 1 資料（ledger）在使用者的 manuscript repo，Layer 2 validator 與 Layer 3 discipline 在 plugin。Hsu case 現況：364 條 ledger、`_meta.json` `schema_version: 1.5`、單一 `main.tex`。第二個採用者 article2（PsychQuant/IRT_variacne_bootstrapping_estimtor）的現行工作稿是 multi-file：`manuscript/parametric_bootstrapping_se/05xx-2026/main_new.tex` 以 `\input` 引入 `parts/part1-intro` 至 `parts/part4-discussion` 四檔，且採「日期版目錄」輪替慣例（`05xx-2026/`、`archive/04xx-2025.tex` 等）。

現有工具鏈的單檔假設分佈在：`validate-propositions.py`（R1 對單一 tex 做 normalize-aware 子字串比對；R9/R13 用 `latex_env_parser` 的單檔行號範圍）、`refresh-prop-locations.py`（windowed locator 對單檔行號）、skill 的自動偵測（`manuscript/propositions/main.jsonl` + `manuscript/main.tex` 慣例）。

2026-08-08 spectra-discuss 結論（使用者確認）：範圍限 ledger 基礎設施（不含 IDD/通信層）；交付為既有 skill 的 Operation D；Hsu 佈局裁剪為模板；路徑參數化進 `_meta.json`；multi-file 走 file-qualified location（方案 b），以 article2 為 pilot。

## Goals / Non-Goals

**Goals:**

- 一條可重複的 onboarding 路徑：新 manuscript 從零到「首次抽取通過 R1–R13」不需要人工抄 Hsu case 佈局
- Multi-file manuscript 一等公民：`\input`/`\include` 樹內的任何檔案都可被 location 定位與驗證
- 完全向後相容：Hsu case 既有 ledger（單檔、無檔名前綴 location）不需任何遷移即通過新 validator

**Non-Goals:**

- 不自動化 IDD/通信層（#148 式 line-anchored 問答、GitHub↔Overleaf 同步）——那是 repo 層慣例，記入 case-study 文檔即可
- 不做 flatten 快照方案（錨定到作者不編輯的產物違反 loud-failure 哲學）、不強制作者併回單檔
- 不處理 `\subimport`/`\subfile` 等非標準引入巨集（pilot 與 Hsu case 都用不到；遇到時 loud fail 提示不支援）
- 不自動遷移 article2 的版本目錄慣例——ledger 放穩定層，版本輪替沿用既有 Operation B/C re-anchor
- 不動 R2–R8、R10–R12（與檔案結構無關的規則）

## Decisions

1. **Location 語法（schema 升版）**：`location` 值允許 `relpath.tex:L<n>`／`relpath.tex:L<a>-L<b>` 形式；`relpath` 相對於主檔所在目錄。無檔名前綴時語意不變（指 `_meta.json` `source.file` 的主檔）。理由：加法式擴充，舊資料零遷移；相對於主檔目錄（而非 repo root）讓 location 與 `\input{parts/part2-theory}` 的寫法直接對得上。
2. **`\input` 樹解析**：從主檔遞迴解析 `\input{...}`/`\include{...}`（補 `.tex` 副檔名、忽略註解行內的引用），深度上限 3 層、循環偵測直接 abort。解析結果快取為 file→lines 映射供各規則使用。理由：pilot 只有 1 層，但遞迴 + 上限的成本低；循環是作者錯誤，loud fail。
3. **R1/R9/R13 的 file-aware 化**：R1 對「主檔＋全部 parts」的聯集做既有 normalize-aware 比對（無前綴 prop 照舊只對主檔；有前綴 prop 對指定檔）；R9/R13 的環境範圍與錨定改為對 prop location 所指的那個檔案跑 `latex_env_parser`。理由：規則語意不變，只是把「哪個檔」從常數變成參數。
4. **`_meta.json` 契約**：`source.file` 必填（主檔，相對 repo root）；新增選填 `source.parts`（字串陣列，validator/Operation D 每次跑時重新解析並更新——是快照非權威，權威永遠是 `\input` 樹的即時解析）。理由：讓人不開 tex 也能看到稿件結構，但不讓快照變成第二真相來源。
5. **Operation D 流程**：偵測目標 repo 無 ledger → 詢問主檔路徑與 ledger 放置層（預設主檔上一層的穩定目錄）→ dry-run 列出將建立的檔案 → AskUserQuestion 確認 → scaffold（模板 + `_meta.json` 填實際路徑與 `git rev-parse HEAD` 錨定 commit）→ 提示下一步跑 C 抽取、A 驗證。理由：沿用 Operation B 的 dry-run-gated 寫入紀律；scaffold 與抽取分兩步，抽取（LLM 工時大）失敗不汙染 scaffold。
6. **模板內容**：`templates/ledger/` 收 `README.md`（說明三檔角色與指令）、`_meta.template.json`（佔位欄位）、`_smoke_tests/README.md`（骨架說明）。SCHEMA.md 與 EXTRACTION-PROMPT.md **不**放模板複本——Operation D 從 `docs/SCHEMA.md` 與 `plugins/propositions/docs/EXTRACTION-PROMPT.md` 現拷（釘住當下版本），避免模板層再養一份會漂移的複本。
7. **版本號**：canonical `docs/SCHEMA.md` 的 multi-file 擴充升為 v1.6（Hsu ledger 已自標 1.5；plugin CLAUDE.md 的「v1.0–v1.3」敘述同步修正）。validator 對 `schema_version < 1.6` 的 ledger 若遇到帶檔名前綴的 location → R13 loud fail 提示先升版。
8. **PLAYBOOK 收錄層級**：完整生命週期文檔放 plugin（`plugins/propositions/docs/PLAYBOOK.md`，跟著 plugin 版本走），scaffold 進使用者 repo 的只有 README 短版摘要＋指回 PLAYBOOK 的連結。理由：生命週期知識會隨 plugin 演進，複本進每個 manuscript repo 會漂移（同 Decision 6 不養複本的邏輯）；#148 通信慣例以 worked example 形式收錄於 PLAYBOOK（維持 Non-Goals：不 skill 化）。

## Implementation Contract

- **Behavior**：(1) 在無 ledger 的 manuscript repo 執行 `/propositions:propositions` 選 Operation D，確認後得到 `propositions/{README.md, SCHEMA.md, EXTRACTION-PROMPT.md, _meta.json, _smoke_tests/README.md}`，且 `_meta.json` 的 `source.file` 指向使用者確認的主檔。(2) 對 multi-file 稿跑 Operation A，帶 `parts/part2-theory.tex:L123` 前綴的 prop 在該檔第 123 行做 R1/R13 驗證；無前綴 prop 行為與現行完全一致。(3) Hsu case ledger 以新 validator 重跑，結果與升版前 byte-identical。
- **Interface / data shape**：`location` 值文法 `[<relpath>.tex:]L<a>[-L<b>]`；`_meta.json` 新增 `source.parts: string[]`（選填）；`validate-propositions.py` 與 `refresh-prop-locations.py` 的 `--tex` 參數語意改為「主檔」（引入樹自動解析），CLI flag 不新增。
- **Failure modes**：`\input` 目標檔不存在 → 該檔引用處 loud fail（列檔名與引用行）；循環引入 → abort；非標準引入巨集 → warning 列出並跳過該巨集（不 silent）；location 檔名前綴指向不在引入樹內的檔 → R13 fail；schema_version < 1.6 帶前綴 → R13 fail 提示升版。
- **Acceptance criteria**：(1) `pytest tests/` 全綠且新增 multi-file fixtures（含前綴命中、前綴檔不存在、循環引入、v1.5 帶前綴 fail）各有獨立測試；(2) Hsu ledger 回歸：對 psychophysical_representations_manuscript 快照跑 Operation A，R1–R13 結果與升版前一致；(3) article2 pilot：Operation D scaffold 成功 + Operation C 抽取 part2-theory 至少一節 + Operation A 通過，全程無人工手抄佈局。

## Risks / Trade-offs

- **`\input` 解析的假陽性**：verbatim/comment 環境內的 `\input` 字樣被誤解析 → 解析器只認行首非註解位置的巨集，fixtures 覆蓋 verbatim 案例；殘餘誤判會以「檔案不存在」loud fail 浮出，不會 silent。
- **相對路徑歧義**（主檔目錄 vs repo root）：統一「location 相對主檔目錄、`_meta.json` 路徑相對 repo root」並寫進 SCHEMA.md——兩個座標系並存是刻意的（各自貼近其讀者），文件不寫清楚就是坑。
- **article2 pilot 的抽取量**：52 個定理環境全抽工時大；pilot 驗收刻意只要求 part2-theory 的一節走通全鏈，全量抽取留給後續正常使用。
