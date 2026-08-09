## Why

propositions plugin 的目標是讓任何 LaTeX manuscript 都能採用 Hsu case（PsychQuantHsu/psychophysical_representations）驗證過的 prop-iso 工作流，但目前「一份還沒有 ledger 的 .tex 稿如何從零開始」沒有定義：skill 只有 A（驗證）/B（修漂移）/C（抽取）三個 operation，scaffold（釘版 SCHEMA 副本、`_meta.json`、smoke tests 骨架）全靠人工抄 Hsu case 的佈局。同時，下一份要採用的稿件（article2 standard error，`main_new.tex` + `\input` 四個 parts、52 個定理環境）是 multi-file 結構，而 R1–R13 validator 與 location 定位全都假設單一 tex 檔——不補 multi-file 支援，第二個採用者就進不來。

## What Changes

- **新增 Operation D（onboard）**到 `/propositions:propositions` skill：對一個還沒有 ledger 的 manuscript repo scaffold `propositions/` 目錄（釘版 SCHEMA.md 副本、EXTRACTION-PROMPT.md 副本、`_meta.json`、README、`_smoke_tests/` 骨架），寫入前 dry-run + AskUserQuestion 確認（沿用「不動 user repo 不問」鐵律），完成後引導走 C（抽取）→ A（驗證）。
- **新增 ledger 模板**：`plugins/propositions/templates/ledger/` 收 scaffold 用的檔案骨架；模板取自 Hsu case Layer 1 佈局的裁剪版（不含 `_audit/`、`_pilot/`、`_migration/` 歷史產物）。
- **Schema 升版（multi-file location）**：`location` 欄位允許檔名前綴（如 `parts/part2-theory.tex:L123`）；無前綴時維持既有語意（`_meta.json` `source.file` 指的主檔）——無前綴的舊 ledger 完全向後相容，不需遷移。**BREAKING**（窄面）：帶「外來檔名前綴」location 的 sub-v1.6 ledger（#116 時代的 skip-count 類，如 `supplement.tex:L10`）從靜默跳過改為 R13 FAIL 提示升版——loud 優於 silent，實際語料（Hsu case）無此類條目。canonical `docs/SCHEMA.md` 先行更新，validator 隨後。
- **Validator multi-file 支援**：`validate-propositions.py` 與 `_lib/latex_env_parser.py` 從主檔解析 `\input`/`\include` 樹，R1 文字匹配、R9 環境邊界、R13 location 錨定改為 file-aware；`refresh-prop-locations.py`（Operation B）同步 file-aware。
- **`_meta.json` 契約明文化**：`source.file`（主檔路徑）為必填、新增 `source.parts`（解析出的 input 檔清單，onboard/驗證時自動更新）；路徑一律相對於 manuscript repo root。
- **新增 PLAYBOOK（完整做法文檔）**：`plugins/propositions/docs/PLAYBOOK.md` 記整條生命週期——onboard（D）→ 首次抽取與驗證（C→A）→ 日常節奏（改 tex → R13 漂移 → B 修位）→ 送審前 proofread/audit 節奏 → 新版稿 re-anchor（Hsu case #147 的 374→364 為 worked example）→ 與 co-author 的 line-anchored 對答慣例（#148 為 worked example，repo 層慣例非 skill）。Operation D scaffold 的 README 指向此文檔。
- **Pilot 驗收**：以 article2（`manuscript/parametric_bootstrapping_se/05xx-2026/main_new.tex`）跑通 D → C → A 全鏈作為 acceptance；ledger 放穩定層 `manuscript/parametric_bootstrapping_se/propositions/`，版本目錄輪替時走既有 Operation B/C re-anchor（Hsu case #147 已驗證此動作）。

## Capabilities

### New Capabilities

- `manuscript-onboarding`: Operation D — 對新 manuscript scaffold ledger 佈局並引導 C→A 完成首次抽取與驗證
- `multifile-manuscript-support`: schema 的 file-qualified location + validator/refresh 的 `\input` 樹解析與 file-aware 驗證

### Modified Capabilities

(none — 既有 spec 目錄中無 validator/skill 行為的 capability spec；本 change 為這兩個能力建立首份 spec)

## Impact

- Affected specs: `manuscript-onboarding`（新）、`multifile-manuscript-support`（新）
- Affected code:
  - New: plugins/propositions/docs/PLAYBOOK.md, plugins/propositions/templates/ledger/README.md, plugins/propositions/templates/ledger/_meta.template.json, plugins/propositions/templates/ledger/_smoke_tests/README.md
  - Modified: docs/SCHEMA.md, plugins/propositions/skills/propositions/SKILL.md, plugins/propositions/scripts/validate-propositions.py, plugins/propositions/scripts/_lib/latex_env_parser.py, plugins/propositions/scripts/refresh-prop-locations.py, plugins/propositions/README.md, CLAUDE.md, tests/
  - Removed: (none)
