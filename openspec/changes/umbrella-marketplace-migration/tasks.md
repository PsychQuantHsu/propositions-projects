## 1. 佈局搬移（單一實體 + 根層 shim；TDD：先寫煙霧測試）

- [x] 1.1 新增 shim 煙霧測試 tests/test_root_shims.py：對 fixture manuscript 分別以根層 scripts/run-audit.sh 與 plugins/propositions/scripts/run-audit.sh 執行，斷言 exit code 相同、audit report 內容等價；validate-propositions.py 同式斷言。此時測試 RED（core 路徑尚不存在）
- [x] 1.2 以 git mv 把 scripts/ 全部實作（run-audit.sh、validate-propositions.py、audit-citations.py、audit-symbols.py、audit-code-manuscript.py、audit-theorem-boundaries.py、refresh-prop-locations.py、migrate 系列、scripts/_lib/）移入 plugins/propositions/scripts/；根層 scripts/ 重建為轉呼叫 shim（bash 用 exec 轉呼叫、Python 用 runpy），argv/stdout/exit code 逐位元轉遞。驗收：1.1 測試轉 GREEN
- [x] 1.3 [P] 從 psychquant-claude-plugins 工作 clone 移植四個通用 skills（clarity-audit、proofread、manuscript-audit、propositions）到 plugins/propositions/skills/，skill 內部引用的 script 路徑改指 core plugin 內實體。驗收：四個 skill 的 SKILL.md 存在且引用路徑經 grep 確認無舊 marketplace 路徑
- [x] 1.4 建 plugins/propositions/.claude-plugin/plugin.json（承接根層 plugin.json 內容、名稱 propositions、version 0.2.0）與 plugins/math-tools/.claude-plugin/plugin.json（薄 pack placeholder manifest、明示「math-only 內容於後續 change 進駐」）。驗收：兩 manifest 通過 JSON parse 且欄位齊（name/version/description/author/license）
- [x] 1.5 tests/ 歸位（依 design D1 實作定案）：測試唯一實體**留在根層 tests/**、不複製進 plugin；subprocess 類測試行經根層 shims（端到端驗 pinned contract）、source-inspection/import 類測試以 IMPL 常數直指 core 實作；修正 SMOKE_TESTS_DIR 指向 tests/fixtures/_smoke_tests（port 遺留的 manuscript-repo 路徑 bug，含 2 個先天 FAIL 復活）。驗收：根層執行 pytest tests/ 全綠（143 passed + 3 skipped），含 1.1 煙霧測試

## 2. Marketplace manifest 升級與 schema 宣告

- [x] 2.1 原地升級 .claude-plugin/marketplace.json：name 改 propositions-projects、移除單一 "./" entry、加入 ./plugins/propositions 與 ./plugins/math-tools 兩個 entries（各帶 description 與 version）；根層 .claude-plugin/plugin.json 移除（單 plugin 佈局終結）。驗收：jq 檢查 name 與兩個 entries 的 source 值
- [x] 2.2 [P] schema-range 宣告：core plugin manifest description 載明 supported ledger schema ≤ 1.5；plugins/propositions/README.md 增「Schema compatibility」表（schema 版本 × validator 條件規則 v1.2+ / v1.4+）。驗收：兩處文字存在且版本區間一致

## 3. Rename 語意 probe 與遷移文件

- [x] 3.1 D2 probe：以本機對 marketplace 的既有註冊模擬「rename 後 claude plugin marketplace update 是否跟隨」（repo rename 前先以測試性 rename 或文件調研確認；不可行則於 4.1 rename 後立即實測並回填）。產出：probe 結果記入 docs/MIGRATION-propositions-projects.md 附註（跟隨 / 需 remove+re-add 二擇一）
- [x] 3.2 README.md 增「Migration notes」段：依 3.1 結果寫既註冊使用者的遷移指令；含 D3 撞名防護（安裝 core plugin 前先移除舊 math-tools plugin）與 coordinated-change 清單（psychquant-claude-plugins deprecation pointer、下游 pin bump 於 vNext tag 後執行——執行本身屬 #2 協調、不在本 change）。驗收：README 段落存在且與 design D2/D3 一致
- [x] 3.3 [P] 建 docs/RELEASE-FLOW.md：version bump → marketplace.json 同步 → tag → push → marketplace update 驗證的有序 checklist；含「pinned entry-point contract 變更聲明」欄位（每次 release notes 必填）。驗收：文件涵蓋 plugin-release-flow spec 三條 Requirement

## 4. Repo rename 收尾與驗證

- [x] 4.1 以 gh 執行 repo rename（propositions → propositions-projects）；更新本地 remote URL、README 與 docs/MIGRATION-propositions-projects.md 內的 repo URL；3.1 若延至此步，於 rename 後立即完成 probe 並回填 3.1/3.2 的文案。驗收：git remote 指新 URL、grep 無殘留舊 URL（redirect 過渡的外部引用除外，列於 MIGRATION doc）
- [x] 4.2 收尾驗證：全套 pytest 綠（根層 + core 兩跑法）、spectra validate 通過、MIGRATION doc 標記步驟 2-4 完成、release notes 草稿載明「pinned entry-point contract unchanged（root shims 維持路徑契約）」。驗收：上述四項逐一確認
