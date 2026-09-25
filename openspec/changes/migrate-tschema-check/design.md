## Context

`PsychQuant/truth-conditions`（2026-08-04 建立，5 commits，一個 262 行的 SKILL.md，無程式碼、無安裝者）定義了三層來源忠實度查核。它與本 repo 的 propositions 帳冊同構，但陳述用整數 id、自訂四級 status、全靠人工。使用者裁決：獨立 plugin、`source_support` 與 `source_locator` 另立欄位、舊 repo archive（#4 Decision comment）。

限制：plugin 安裝後彼此獨立，tschema-check 不能 import `propositions` 的 validator；repo 的 payload 測試要求 skill 內連結都在 plugin payload 內且已追蹤。

## Goals / Non-Goals

**Goals:**

- tschema-check 成為本 umbrella 的第二個 plugin，可經 marketplace 安裝。
- 檢核紀錄沿用帳冊慣例（UUID v7、逐字 `text`、`location`），外部來源資訊放新欄位。
- 把原本人工做、也最容易安靜出錯的兩件事機械化：陳述是否真在被檢文件裡（T2／T3），引用的來源原文是否真在來源檔裡（T4）。

**Non-Goals:**

- 不改 `propositions` plugin 與其帳冊 schema。
- 不自動判定 `source_support`、關係、邏輯失真；validator 只查紀錄與文件、來源是否一致。
- 不在本 change 內 archive 舊 repo（merge 後執行）。
- 不匯出到 #12 的 `verification.jsonl`（見 Open Questions）。

## Decisions

### Independent tschema-check plugin with its own validator

新 plugin 目錄 `plugins/tschema-check/`，含 `plugin.json`、skill、`scripts/validate-tschema.py`、`docs/SCHEMA.md`、README；marketplace 增一筆，版本 0.1.0。validator 自帶最小比對實作而非 import `propositions`：跨 plugin import 在使用者端不存在。所實作的機制與 R1（子字串）、R13（行號錨定）相同，文件逐條註明對應，未來若抽出共用套件再合併。

### Whitespace-free NFKC matching for CJK sources

比對前兩邊都做 NFKC 並移除所有空白。R1 的「空白收成一格」在 LaTeX 英文稿夠用，但中文逐字稿與會議記錄常在句中斷行，收成一格會在斷行處留下空白而對不上。移除全部空白對英文會把詞黏在一起，但兩邊同樣處理，只略增偽陽性機率，換到的是 CJK 斷行不再誤報。NFKC 同時統一全形／半形標點。

### SRT cue stripping for transcript evidence

來源檔副檔名為 `.srt` 時，比對前移除純數字的 cue 編號行與 `-->` 時間行，只留字幕文字，讓跨 cue 的引文能比對。原 skill 的主要來源正是 Plaud／ASR 逐字稿，不處理這點，T4 在最常見的情境幾乎全數誤報。

### Source support stays four-level beside evidence_class

`source_support` 取 `attested` / `doc` / `inferred` / `unsupported`，另有 `semantic_distance`、`drift_type`。不塞進 `evidence_class`（語意是「稿件如何主張」），也不改用 #12 的 status（那是判定，四級記的是依據類型，`attested` 與 `doc` 在 #12 都會落在 `supported`，資訊會丟）。

### Unverifiable claims are counted, not passed

`source_locator` 沒有 `path`（來源不在本機，例如只有紙本或對方系統）時 T4 無從執行。這類陳述不算通過，而是在摘要中按來源類型列為「未機械查核」。這直接落實原 skill 的反模式「把不同來源類型合併成一個數字」：不能讓「全部通過」掩蓋「其實只查了一部分」。

## Implementation Contract

**Behavior**：`python3 plugins/tschema-check/scripts/validate-tschema.py --records <tschema.jsonl> --document <被檢文件>` 逐行檢查紀錄，輸出 `[T<n>] L<line>: <message>`，接著按 `source_locator.type` 列出「T4 查核 N 筆／未機械查核 M 筆」，最後 `=== N ERROR(s) ===` 或 `✓ NO ERRORS — N of M claim(s) checked against their source`（結尾一律寫出覆蓋率，不印無條件的 PASS）。

**檢查**：T1 形狀與列舉（error）；T2 `text` 不在被檢文件（error）；T3 `text` 不在 `location` 指定行（warning）；T4 `evidence` 不在 `source_locator.path` 來源檔、或來源檔不存在（error）；T5 `attested` 缺 `evidence` 或 `source_locator`（error）；T6 關係／邏輯紀錄指不到陳述（error）；T7 被檢文件含查證失敗字句（warning）。`path` 相對於 `tschema.jsonl` 所在目錄解析。

**Exit**：0 無 error；1 有 error；2 參數或讀檔錯誤。

**Skill**：SKILL.md 從原 repo 遷入，方法論段落（上位原則、三層、失真分類、盲區、invariant、誠實邊界、反模式）保留原文；「輸出」段改為新格式並要求跑 validator；frontmatter 名稱維持 `tschema-check`。

**驗收**：`tests/test_tschema_check.py` 涵蓋 spec 每個 scenario；既有 marketplace／payload 測試對新 plugin 通過；`python3 -m pytest -q` 全綠。

**範圍外**：抽取陳述的自動化、關係層判讀、匯出到 verification.jsonl、舊 repo archive。

## Risks / Trade-offs

- [移除空白使英文詞相黏而偽陽性] → 兩邊一致處理，偽陽性需「黏起來剛好相同」才發生；中文為主要使用情境。
- [validator 與 propositions 的比對實作分岔] → 文件註明對應 R1／R13；比對規則刻意不同（CJK 空白），不追求一致。
- [使用者把 `path` 指向含第三方逐字內容的檔案並 commit] → SKILL.md 與 SCHEMA.md 註明來源檔留本機、不進 remote（raw 逐字稿規則），`path` 只是本機參照。

## Migration Plan

1. 本 PR merge 後，在 `PsychQuant/truth-conditions` 的 README 加一段指向 `PsychQuantHsu/propositions-projects` 的 `plugins/tschema-check/`，commit、push。
2. 以 `gh repo archive PsychQuant/truth-conditions` 封存（可逆：`gh repo unarchive`）。
3. 已安裝舊 plugin 的使用者：目前無（原 issue 記錄無安裝者），不需遷移指引。

## Open Questions

- #12 驗證紀錄的詞彙對應：若要把 tschema 結果匯出成 `verification.jsonl`，四級要怎麼對到 `supported / refuted / partial / unresolved`？候選：`attested`／`doc` → `supported`（`evidence_ref` 區分）、`inferred` → `partial`、`unsupported` → ？（「來源沒說」不等於 `refuted` 的「被證偽」）。待使用者確認後另開 change。
- 關係層是否需要一條對應 R3 的機械規則（例如偵測關係值從 `conditional` 變成 `none`）。
