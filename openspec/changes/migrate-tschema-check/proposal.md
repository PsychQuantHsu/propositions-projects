## Summary

把 `PsychQuant/truth-conditions` 的 `tschema-check` skill 遷入本 umbrella，成為獨立 plugin，並把它句級檢核中可機械化的部分做成 validator：它是 R1 的推廣——R1 查「命題文字是被檢文件的子字串」，這裡查「引用的來源原文是外部來源的子字串」（#4）。

## Motivation

`tschema-check` 查核一份從來源素材整理出來的文件（會議記錄、訪談整理、初稿）是否忠於來源。它與 `propositions` 同構，但全靠人工：陳述用整數 id、四級 `status` 自訂、沒有任何機械檢查。原 repo 的實跑出過兩次人工錯誤（工具靜默漏匹配、未標記的推論被當前提）。本 repo 已有 UUID v7、逐字 `text`、`location`、R1 子字串比對、R13 行號錨定，可以直接承接。

## Proposed Solution

- 新增 plugin `plugins/tschema-check/`（`plugin.json`、`skills/tschema-check/SKILL.md`、`scripts/validate-tschema.py`、`docs/SCHEMA.md`），marketplace 增一筆。
- **檢核紀錄格式**（`tschema.jsonl`，一行一筆）：
  - 陳述紀錄沿用帳冊慣例：UUID v7 `id`、逐字 `text`、`location`（指向**被檢文件**，R13 語意不變）。
  - 四級來源支持放新欄位 `source_support`（`attested` / `doc` / `inferred` / `unsupported`），不進 `evidence_class`。
  - 外部來源位置放新欄位 `source_locator`（`type`：transcript／email／statute／document／dataset／other，`ref`：時間碼、檔名、條號等，選填 `path` 指向本機來源檔）。
  - 保留 `semantic_distance`、`drift_type`、`evidence`（來源逐字引文）。
  - 關係層紀錄（`pair`、`source_relation`、`rendered_relation`）與邏輯層紀錄照原 skill 的語意。
- **validator**：T1 形狀與列舉；T2 陳述 `text` 為被檢文件的子字串（R1 機制）；T3 `location` 行號錨定（R13 機制）；**T4 `evidence` 為 `source_locator.path` 指向之來源檔的子字串**（R1 推廣到外部來源，本 issue 的核心）；T5 `attested` 必須有 `evidence` 與 `source_locator`；T6 關係紀錄的 `pair` 指得到陳述、關係值在列舉內；T7 正文出現「查證失敗狀態」字句時 warn（原 skill 已寫明可機械化）。
- SKILL.md 從原 repo 遷入，輸出段改寫為新格式並指向 validator；其餘方法論（三層、上位原則、失真分類、檢核者 invariant）逐字保留。

## Non-Goals

- 不修改 `propositions` 帳冊 schema、不改 `validate-propositions.py`。
- 不自動抽取陳述或判定 `source_support`；判定仍是人（或 agent）依 SKILL.md 做，validator 只檢查紀錄與來源是否一致。
- 不做關係層與邏輯層的自動判讀；只檢查紀錄的形狀與指涉。
- 不在本 change 內 archive 舊 repo：那是對外動作，待本 PR merge 後執行（見 design 的 Migration Plan）。
- v1 不把 tschema 結果自動匯出為 #12 的 `verification.jsonl`（詞彙對應是有損的，列入 Open Questions）。

## Alternatives Considered

- **併入 `propositions` plugin**：該 plugin 的 `scripts/` 以 LaTeX 為中心，tschema-check 是通用文件（md／txt／逐字稿）導向；使用者已裁決獨立 plugin。
- **import `propositions` 的 validator 程式碼**：plugin 安裝後各自獨立，跨 plugin import 在使用者端不存在（repo 的 payload 測試也禁止 skill 連結指出 payload）。改為在 tschema-check 內實作同一機制的最小版本（空白正規化子字串、行號錨定），並在文件註明與 R1／R13 的對應。
- **把四級塞進 `evidence_class`**：語意不同（稿件如何主張 vs 外部來源支不支持），使用者已裁決另立欄位。

## Impact

- Affected specs: tschema-check（新）
- Affected code:
  - New: plugins/tschema-check/.claude-plugin/plugin.json, plugins/tschema-check/skills/tschema-check/SKILL.md, plugins/tschema-check/scripts/validate-tschema.py, plugins/tschema-check/docs/SCHEMA.md, plugins/tschema-check/README.md, tests/test_tschema_check.py
  - Modified: .claude-plugin/marketplace.json, README.md
  - Removed: (none)

## 使用者裁決（2026-09-25，#4 Decision comment）與本 change 的假設

1. 獨立 plugin `plugins/tschema-check/`。
2. 四級另立 `source_support` 欄位，不塞進 `evidence_class`。裁決選項附註「與 #12 驗證紀錄共用狀態詞彙」：**本 change 的解讀**是 `source_support` 保留四級（它記的是「依據是哪一種」，#12 的 status 記的是判定，兩者無法無損互轉），與 #12 的對應表列入 Open Questions，待使用者確認後另開 change 實作匯出。
3. 外部來源位置另立 `source_locator`（含 `type`），`location` 維持指向被檢文件，R13 語意不變。
4. 舊 repo archive、README 指向新位置——merge 後執行。
