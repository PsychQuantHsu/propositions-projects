## 1. 紀錄格式與 validator（TDD）

- [x] 1.1 在 `tests/test_verification_records.py` 先寫失敗測試，涵蓋 Verification record format 與 Method and status vocabulary 的全部 scenario（兩方法並列有效、帳冊不受影響、`x-monte-carlo` 接受、`leanprover` 拒絕並列出允許值）；驗證：`python3 -m pytest -q tests/test_verification_records.py` 在實作前為 RED
- [x] 1.2 實作 `plugins/propositions/scripts/validate-verification.py` 的 Validator checks V1–V6：以 `load_props_jsonl` 讀帳冊，逐行回報 `[V<n>] L<line>: <message>`，exit 0／1／2 依 design 的 Implementation Contract；空 sidecar 為 exit 0。驗證：1.1 的測試與新增的 V1–V6 各一個 scenario 測試（含 Dangling proposition id、Evidence required unless not attempted 的兩個 scenario）轉 GREEN
- [x] 1.3 實作 Cross-method disagreement report，依 Latest record per method decides disagreement 規則（每方法取 `checked_at` 最新、同日取較後一行），不一致列為 `[WARN] disagreement` 且不影響 exit code。驗證：Lean supports / proofread finds a problem 與 Latest record wins within a method 兩個 scenario 測試 GREEN

## 2. proofread 轉換

- [x] 2.1 先寫 Proofread checklist conversion by uuid prefix 的失敗測試：`[x]`/`[~]`/`[-]` 對應 supported/partial/not_attempted、`[ ]` 略過、標題與 Findings 表格行忽略、`evidence_ref` 為 `<checklist>:L<n>`、前綴不唯一或查無時 exit 1 且 stdout 為空；驗證：`python3 -m pytest -q tests/test_verification_records.py -k proofread` 為 RED
- [x] 2.2 實作 `plugins/propositions/scripts/proofread-to-verification.py`（Proofread checklist conversion，依前綴→文字片段→ordinal 縮小、多於一筆一律整批失敗、無對應預設失敗而 `--allow-unmatched` 時略過，`--checked-at` 預設臺北時間今天、`--checker` 選填），並確認其輸出能通過 `validate-verification.py`。驗證：2.1 測試 GREEN，另有一個 round-trip 測試（轉換輸出餵給 validator 得 exit 0）

## 3. 文件與交叉連結

- [x] 3.1 撰寫 `plugins/propositions/docs/VERIFICATION.md`：說明 Sidecar verification.jsonl next to the ledger 的格式、Open method vocabulary with x- prefix 的兩張詞彙表、V1–V6、不一致定義、proofread 的 `supported` 只代表六項閱讀檢查通過（非形式證明）、其他方法如何接入。驗證：人工核對文件中每個列舉值與 validator 常數一致（測試斷言 VERIFICATION.md 內含每個 method／status 字面值）
- [x] 3.2 proofread SKILL.md 只加一行指向 `proofread-to-verification.py` 與 VERIFICATION.md，plugin README 加一行指向 VERIFICATION.md；驗證：`git diff --stat` 顯示 SKILL.md 僅 +1 行，README 僅新增指向行

## 4. 整合驗證

- [x] 4.1 全套回歸：`python3 -m pytest -q` 與 `bash tests/test_run_audit.sh` 全綠，且 `validate-propositions.py` 對 smoke fixtures 的輸出不變（Ledger untouched scenario）；驗證：兩個指令 exit 0
- [x] 4.2 對一份真實帳冊與其 proofread checklist（或以帳冊前 5 筆 id 手造的 checklist）跑轉換再跑 validator，結果 exit 0；驗證：指令輸出貼進 PR 描述
