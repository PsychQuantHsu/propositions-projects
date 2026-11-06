## 1. 讓新稿接得上 extract（#41）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 加測試釘住 Operation D 的 scaffold 清單列出 `main.jsonl`，並確認它在修之前失敗；在 `tests/test_validate_propositions.py` 與 `tests/test_check_extraction_coverage.py` 各加一個案例，釘住 Requirement「Operation D scaffolds a ledger for a manuscript without one」的新 Scenario：空帳冊通過驗證器，覆蓋檢查把正文列為未覆蓋。接著改 `plugins/propositions/skills/propositions/SKILL.md` 的 Operation D，連同 `plugins/propositions/templates/ledger/README.md` 與 `plugins/propositions/docs/PLAYBOOK.md`（design「Operation D 要建空的帳冊」）。驗證：`pytest tests/test_plugin_payload_tracked.py tests/test_validate_propositions.py tests/test_check_extraction_coverage.py` 通過；獨立 commit，內文帶 Refs #41。

## 2. 釘住 skill 內容的測試（先寫，要看到失敗）

- [x] 2.1 在 `tests/test_plugin_payload_tracked.py` 加測試，釘住 `plugins/propositions/skills/analyze/SKILL.md`：檔案存在；七個狀態依序出現（對應 Requirement「Analysis determines its state from the files」與 design「狀態是有順序的封閉列舉」、「進度只從檔案判斷」）；每個狀態的動作都在（Requirement「Each state has one action」）；100 筆以上走 `construct-batch`（design「長稿走 construct-batch」）。驗證：`pytest tests/test_plugin_payload_tracked.py -k analyze` 在 skill 寫好之前失敗，失敗原因是檔案不存在。
- [x] 2.2 同一個檔案加測試，釘住規定：不寫入、不代答確認（Requirement「The entry point writes nothing itself」，design「寫入都留在原本的 skill」）；覆蓋檢查不看結束碼（Requirement「Coverage is judged from the uncovered text」，design「覆蓋檢查要讀片段，不看結束碼」）；不帶 `--partial` 的結果算發現（Requirement「What the article owes is a finding」，design「附檔的形狀與文章欠的帳分開判斷」）；三個選用步驟（Requirement「Three steps run only on request」，design「三個步驟要明確要求才跑」）；報告的十項（Requirement「The analysis ends with a read-out and a report」）；停下不繞過（Requirement「Analysis stops rather than works around」）。驗證：同 2.1；換行不影響比對，用把一項改掉的方式確認測試會失敗（design「測試加在既有的 pytest 檔」）。

## 3. 入口 skill

- [x] 3.1 新增 `plugins/propositions/skills/analyze/SKILL.md`：frontmatter 的 description 照 Requirement「Whole-article requests route to the entry point」寫，明列不處理的請求；內文依序寫解析路徑、判斷狀態、依狀態行動、讀法與報告，只呼叫既有 skill，不重述它們的步驟。驗證：2.1、2.2 的測試通過；`git diff --stat -- plugins/propositions/scripts` 為空；既有七個 skill 除了 1.1 的 Operation D 之外沒有變動。

## 4. 文件與版本

- [x] 4.1 [P] 在 `plugins/propositions/README.md`、`README.md`、`CLAUDE.md` 加入 `/propositions:analyze`：是入口，不取代其他 skill，預設深度與選用步驟。驗證：三個檔案都列出它，`CLAUDE.md` 的 skill 表有一列。
- [x] 4.2 [P] 把 `propositions` plugin 升到 0.10.0（`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json`），並在 `marketplace.json` 的描述加入 analyze、把已過時的 S1-S6 改成 S1-S9。驗證：`pytest tests/test_marketplace_entries.py` 通過，兩處版本相同。

## 5. 驗收

- [ ] 5.1 實跑驗收：準備五份目錄（沒有 `_meta.json`、剛 scaffold 的空帳冊、有帳冊沒有附檔、有附檔沒有 `move`、完整），subagent 只讀 analyze 的 SKILL.md，回報狀態與下一步，不執行會寫入的步驟。檢查狀態與預先寫好的答案相同、檔案指紋不變。完整那份另外檢查報告的十項都有，讀法寫在帳冊目錄之外。驗證：把結果記到 #40，不含稿件文字；有不符就修 skill 再跑。
- [ ] 5.2 路由驗收：獨立讀者只看八個 skill 的 description，把 10 句請求（5 句分析整篇、5 句屬於其他 skill）分給 skill。驗證：10 句都分對；分錯就改 description 再跑。
- [ ] 5.3 全套 `pytest tests/` 通過、`idd-ci-gate.sh` 對 head commit 通過、`spectra validate add-analyze-entry-skill` 通過，且 `git diff --stat main -- plugins/propositions/scripts` 為空。驗證：貼出輸出。
