## 1. Plugin 骨架與遷移

- [x] 1.1 建立 Independent tschema-check plugin with its own validator 的骨架：`plugins/tschema-check/.claude-plugin/plugin.json`（0.1.0）、README、marketplace.json 新條目；驗證：`python3 -m pytest -q tests/test_marketplace_entries.py tests/test_plugin_payload_tracked.py` 通過（含 version 一致與 payload 追蹤）
- [x] 1.2 遷入 SKILL.md：方法論段落保留原文，「輸出」段改寫為 Check record format 的新格式並要求跑 validator，註明來源檔留本機不進 remote；驗證：`diff` 原檔與新檔，差異僅在輸出段、frontmatter 描述與新增的 validator 指引

## 2. validator（TDD）

- [x] 2.1 [P] 先寫失敗測試 `tests/test_tschema_check.py`，涵蓋 spec 全部 scenario（Check record format、Source support and locator vocabulary、Statement containment、Evidence containment、Attested claims carry their evidence、Relation and logic records point at claims、Verification-failure phrases、Per-source-type summary）；驗證：`python3 -m pytest -q tests/test_tschema_check.py` 為 RED
- [x] 2.2 實作 `validate-tschema.py` 的 T1／T5／T6 與 exit code（0／1／2）；驗證：對應測試 GREEN
- [x] 2.3 實作 Whitespace-free NFKC matching for CJK sources，交付 Statement containment in the checked document（T2／T3）與 Verification-failure phrases stay out of the text（T7）；驗證：跨行中文句子不誤報、缺句報 T2 的測試 GREEN
- [x] 2.4 實作 Evidence containment in the external source（T4）與 SRT cue stripping for transcript evidence，以及 Unverifiable claims are counted, not passed 的 Per-source-type summary and exit codes；驗證：跨 cue 引文、偽造引文、無 path 計入「未機械查核」三個測試 GREEN

## 3. 文件與整合

- [x] 3.1 撰寫 `plugins/tschema-check/docs/SCHEMA.md`：紀錄格式、Source support stays four-level beside evidence_class 的理由、T1–T7、與 R1／R13 的對應、Open Questions；repo 根 README 列出第二個 plugin；驗證：測試斷言 SCHEMA.md 內含每個列舉值
- [x] 3.2 全套回歸 `python3 -m pytest -q` 與 `bash tests/test_run_audit.sh` 全綠；以一份手造的中文會議記錄＋`.srt` 來源跑一次 validator，輸出貼進 PR 描述；驗證：兩個指令 exit 0
