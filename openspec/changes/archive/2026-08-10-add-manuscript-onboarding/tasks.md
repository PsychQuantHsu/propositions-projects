## 1. Schema 升版（v1.6：file-qualified location）

- [x] 1.1 更新 docs/SCHEMA.md：location 文法擴為 `[<relpath>.tex:]L<a>[-L<b>]`（relpath 相對主檔目錄）、`_meta.json` 新增選填 `source.parts`（非權威快照）、明訂「schema_version < 1.6 帶檔名前綴 → R13 fail 提示升版」與兩座標系（location 相對主檔目錄、meta 路徑相對 repo root）；版本節記 v1.6 變更史（spec: File-qualified location syntax）
- [x] [P] 1.2 修正 plugins/propositions/README.md 與 CLAUDE.md 的 schema 版本敘述（現寫 v1.0–v1.3，與 Hsu ledger 實際 1.5 脫節）為 v1.0–v1.6 一覽

## 2. Validator multi-file 支援（TDD：先寫 fixtures 再改實作）

- [x] 2.1 新增 tests/ 的 multi-file fixtures：主檔＋`\input` parts 的最小稿（含 verbatim 環境內偽 `\input`）、前綴命中案例、前綴檔不存在、循環引入、v1.5 ledger 帶前綴應 fail、location 前綴指向樹外檔案應 fail——每案一個獨立 pytest，先 RED
- [x] 2.2 在 plugins/propositions/scripts/_lib/latex_env_parser.py 增加 input-tree resolver：從主檔遞迴解析 `\input{}`/`\include{}`（自動補 .tex、跳過註解行、深度上限 3、循環偵測 abort、缺檔 abort 並列引用檔與行號），回傳 file→content 映射（spec: Input-tree resolution from the main file）
- [x] 2.3 改 plugins/propositions/scripts/validate-propositions.py：R1 對檔案聯集比對（無前綴 prop 只對主檔）、R9/R13 依 prop 的 location 前綴選檔跑環境邊界與錨定、schema_version 檢查（<1.6 帶前綴 → R13 fail）、跑完回寫 `_meta.json` `source.parts` 快照（spec: File-qualified location syntax；Meta records the resolved parts as a non-authoritative snapshot；Location prefix outside the input tree fails）
- [x] 2.4 改 plugins/propositions/scripts/refresh-prop-locations.py（Operation B）為 file-aware：dry-run 輸出含檔名（`parts/part2-theory.tex:L120 → L134`），錨定範圍限 prop 自己的檔案
- [x] 2.5 回歸驗證：對 Hsu case ledger 快照（psychophysical_representations_manuscript @ 當日 HEAD 抓下的 main.tex + main.jsonl 複本，放 tests/fixtures/ 不進 git——.gitignore 擋）跑 Operation A，比對升版前後 R1–R13 結果一致；結果記入 tasks 完成註記

## 3. Operation D（onboard）與模板

- [x] [P] 3.1 建 plugins/propositions/templates/ledger/：README.md（三檔角色與 A/B/C/D 指令一覽）、_meta.template.json（source.file/commit_sha/extracted_at/coverage 佔位欄）、_smoke_tests/README.md（骨架說明）；模板不含 SCHEMA/EXTRACTION-PROMPT 複本
- [x] 3.2 在 plugins/propositions/skills/propositions/SKILL.md 增寫 Operation D 段：偵測無 ledger → 問主檔路徑與放置層（預設主檔上一層穩定目錄）→ dry-run 列將建檔案 → AskUserQuestion 確認 → scaffold（模板＋從 docs/SCHEMA.md 與 plugins/propositions/docs/EXTRACTION-PROMPT.md 現拷釘版＋`git rev-parse HEAD` 錨定）→ 報告下一步 C/A 與已解析路徑；既有 ledger 偵測到即 abort 不覆寫（spec: Operation D scaffolds a ledger for a manuscript without one；Scaffold writes are dry-run gated；Onboarding hands off to extraction and validation）
- [x] 3.3 更新 plugins/propositions/README.md 的 skill 一覽表（A/B/C → A/B/C/D）與 Quick start 加 onboarding 起手式
- [x] 3.4 撰寫 plugins/propositions/docs/PLAYBOOK.md：整條生命週期（D → C→A → 日常 B 修漂移 → 送審前 proofread/manuscript-audit/clarity-audit 節奏 → 新版稿 re-anchor 以 Hsu #147 為 worked example → co-author line-anchored 對答慣例以 #148 為 worked example）；templates/ledger/README.md 加生命週期短版摘要＋指回 PLAYBOOK（spec: Onboarding surfaces the lifecycle playbook）

## 4. Pilot 驗收（article2）與收尾

- [x] 4.1 對 /Users/che/Academic/projects/active/IRT_theories/article2_standard_error 跑 Operation D：scaffold 至 manuscript/parametric_bootstrapping_se/propositions/、_meta.json `source.file` 指 manuscript/parametric_bootstrapping_se/05xx-2026/main_new.tex（使用者確認後寫入；pilot 產物 commit 到該 repo 由使用者決定）
- [x] 4.2 Operation C 抽取 part2-theory 的一節（與使用者共選）→ Operation A 通過 R1–R13；過程中發現的 spec 缺口記回本 change 的 design Risks 節
- [x] 4.3 pytest tests/ 全綠（既有 142+ 案不退化）；spectra validate 通過；plugin 版號 bump（0.2.1 → 0.3.0，schema 升版屬 minor feature）並依 common-release-flow 判斷是否觸發 marketplace sync
