## Why

propositions 帳冊只負責把稿件拆成命題索引，本身不驗證任何命題是否為真；真正的驗證來自 Lean 形式化、精確數值憑證、電腦代數重算、跨模型獨立重推、人工審閱、以及 proofread 的逐條閱讀，但這些判定目前沒有標準位置。做雙重驗證的稿件只能在 repo 外另開對照表、欄位寫死單一方法，加第二種方法就得改表頭（#12）。

## What Changes

- 新增**驗證紀錄 sidecar** 格式：帳冊旁的 `verification.jsonl`，每行一筆紀錄，描述「某方法對某命題的判定」。同一命題可有多筆不同方法的紀錄並列。
- 新增 `validate-verification.py`：檢查紀錄的形狀、命題 id 能在帳冊找到、列舉值、日期、證據指向、重複紀錄，並列出同一命題被不同方法判得不一致的清單。
- 新增 `proofread-to-verification.py`：把 proofread 的 `.proofread/<file>.md` checklist 轉成 `method=proofread` 的紀錄。
- 新增 `docs/VERIFICATION.md`：格式、method 與 status 詞彙、各方法如何接入。
- proofread SKILL 加一行交叉連結指向轉換腳本，並把 checklist 模板的 id 欄改為完整 UUID（短前綴不足以識別命題）。
- 帳冊 schema（`docs/SCHEMA.md`、`main.jsonl`）**不變**。

## Non-Goals

（見 design.md 的 Goals / Non-Goals）

## Capabilities

### New Capabilities

- `verification-records`: 帳冊旁的驗證紀錄 sidecar 格式、其 validator，以及 proofread checklist 的轉換

### Modified Capabilities

(none)

## Impact

- Affected specs: verification-records（新）
- Affected code:
  - New: plugins/propositions/scripts/validate-verification.py, plugins/propositions/scripts/proofread-to-verification.py, plugins/propositions/docs/VERIFICATION.md, tests/test_verification_records.py
  - Modified: plugins/propositions/skills/proofread/SKILL.md, plugins/propositions/README.md
  - Removed: (none)

## 使用者裁決（2026-09-25，#12 Clarity Surface）

1. 紀錄放帳冊旁的 sidecar；plugin 定格式與 validator，帳冊 schema 不動。
2. proofread 算一種驗證方法，寫成 `method=proofread`。
3. 第一版＝格式＋validator＋接 proofread；其他方法之後各自接。
