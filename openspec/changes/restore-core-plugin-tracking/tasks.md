## 1. Payload 追蹤性測試（D5；TDD：先寫測試取得 RED）

- [x] 1.1 新增 tests/test_plugin_payload_tracked.py，payload 追蹤性測試斷言 git index 而非檔案系統：讀 .claude-plugin/marketplace.json，對每個 entry 的 source 相對路徑斷言 (a) 該目錄下的 plugin manifest 與全部 skills/*/SKILL.md 都出現在 git ls-files 輸出中、(b) 對 entry source 目錄執行 git check-ignore 回傳非零（命中時把 -v 回報的規則來源檔名/行號/pattern 帶進失敗訊息）、(c) payload universe 內每個 skill frontmatter name 只對應一份 SKILL.md（重複時訊息列出名稱與全部路徑）、(d) payload universe 內不存在落在任何 entry source 之外的孤兒 SKILL.md。payload universe 定義為各 entry source 目錄聯集 repo 根層 skills/ 目錄，並在測試內以註解說明 .agents/ 是 spectra harness skill、刻意排除。非 git work tree 時以 pytest.skip 附理由跳過，不得靜默通過。本任務為 spec requirement「Published plugin payload is version-controlled」與「A skill name has exactly one definition」的機械化守門。驗收：此時測試 RED，失敗訊息指名 plugins/propositions 底下的 plugin manifest 未被 git 追蹤

## 2. 根因修正與 payload 納入版控

- [x] 2.1 .gitignore 以前導斜線錨定根層 shim pattern：把 propositions/ 與 manuscript/ 兩條規則改為 /propositions/ 與 /manuscript/，並把註解補成說明「前導斜線是必要的——未錨定 pattern 會匹配任意深度的同名目錄，曾因此吞掉 plugins/propositions/」。其餘 ignore 規則不動。本任務落實 spec requirement「Ignore patterns for repository-root scaffolding are anchored」。驗收：對 plugins/propositions 的 plugin manifest 執行 git check-ignore 回傳非零；對 repo 根層 propositions 路徑執行 git check-ignore 仍命中 /propositions/
- [x] 2.2 把 plugins/propositions 的 plugin manifest、README.md、以及 clarity-audit / manuscript-audit / proofread / propositions 四個 skills/*/SKILL.md 納入版控（不使用 add 的 force 旗標——若仍需 force 表示 2.1 未生效，應回頭修 pattern）。本任務落實 spec requirement「Published plugin payload is version-controlled」。驗收：git ls-files plugins/propositions 的輸出同時含 plugin manifest、README.md 與四個 SKILL.md；1.1 測試的 (a)(b) 兩項轉 GREEN
- [x] 2.3 [P] 根層三個 verb-named skill 退役，能力由 plugin 內 skill 承接：刪除 skills/validate、skills/refresh-locations、skills/audit 三個目錄。三者的 CLAUDE_PLUGIN_ROOT fallback 都指向改名前的 cache 路徑、已不屬於任何 manifest，其能力分別由 plugin 內 propositions skill 的 Operation A / Operation B 與 manuscript-audit skill 承接。驗收：這三個路徑不再出現在 git ls-files '*SKILL.md' 輸出中；plugin 內 propositions skill 的 Operation B 仍逐字保有 dry-run 先行、確認後才寫、anchor 不確定回 anchor_failed 三項紀律文字
- [x] 2.4 [P] proofread 雙副本以 plugin 完成版為唯一實體：刪除根層 skills/proofread（自述僅為 v0.1.0 scaffolding、執行本體待實作），保留 plugins/propositions/skills/proofread 的完成版。根層 skills/ 目錄至此清空。本任務落實 spec requirement「A skill name has exactly one definition」。驗收：git ls-files '*SKILL.md' 輸出中 proofread 只剩 plugin 內一份；1.1 測試的 (c)(d) 兩項轉 GREEN

## 3. 文件與命名空間一致化

- [x] 3.1 [P] skill 交互引用命名空間統一為 /propositions:：把 plugins/propositions/skills/ 下四個 SKILL.md 內全部 /math-tools:<skill> 形式的交互引用改為 /propositions:<skill>，並移除 plugins/propositions/README.md 內指涉 math-tools sibling pack 的過時句。驗收：以 grep 搜尋 plugins/propositions/ 下的 math-tools 字樣，剩餘命中皆位於「本 marketplace 不發佈 math-tools plugin」這類保留說明脈絡，無任何一處仍是可呼叫命令形式
- [x] 3.2 [P] 更新 README.md 的 Quick start 與 CLAUDE.md 的 skill 對照表：改列實際 ship 的四個 skill（propositions 含 validate/refresh/extract 三個 operation、manuscript-audit、proofread、clarity-audit）及其用途，移除已退役的 /propositions:validate、/propositions:refresh-locations、/propositions:audit 三個命令；README.md 的 Layout 區塊同步反映根層 skills/ 已移除、skill 實體位於 plugins/propositions/skills/。本任務落實 spec requirement「Published plugin ships every documented skill」。驗收：README.md 與 CLAUDE.md 列出的命令集合與 plugins/propositions/skills/ 下的目錄名一一對應，無多出也無遺漏

## 4. 收尾驗證

- [x] 4.1 收尾：根層 pytest tests/ 全綠且既有測試數不回歸（含 1.1 新測試）；spectra validate restore-core-plugin-tracking 通過；git ls-files plugins/propositions 的輸出與 design「行為」段所列的 payload 清單逐項比對一致。驗收：三項逐一確認並記錄 pytest 通過數

## Traceability（spec Requirement / design decision → 任務）

Spec 依 Spectra 規範寫英文、任務依 locale 設定寫中文，兩者無字面重疊，故在此顯式對應。

| Spec Requirement（verbatim title） | 任務 |
|---|---|
| Published plugin payload is version-controlled | 1.1、2.1、2.2、4.1 |
| Ignore patterns for repository-root scaffolding are anchored | 1.1、2.1 |
| Published plugin ships every documented skill | 2.2、2.3、3.2 |
| A skill name has exactly one definition | 1.1、2.4 |

| Design decision | 任務 |
|---|---|
| D1 — .gitignore 以前導斜線錨定根層 shim pattern | 2.1 |
| D2 — 根層三個 verb-named skill 退役，能力由 plugin 內 skill 承接 | 2.3 |
| D3 — proofread 雙副本以 plugin 完成版為唯一實體 | 2.4 |
| D4 — skill 交互引用命名空間統一為 /propositions | 3.1 |
| D5 — payload 追蹤性測試斷言 git index 而非檔案系統 | 1.1、4.1 |
