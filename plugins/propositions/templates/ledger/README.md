# Propositions ledger（本 manuscript 的 author-claim 帳本）

> 由 `/propositions:propositions` Operation D scaffold 於 `{{SCAFFOLD_DATE}}`，
> 錨定 manuscript repo commit `{{ANCHOR_COMMIT}}`。

這個目錄是**本篇稿件**的 proposition-iso 資料層（Layer 1）：`main.tex` 的每一個
declarative claim 提煉成一行 JSONL，配 R1–R13 validator 保持稿件與帳本之間的
對應永遠 falsifiable。工具（validator / skills）在 propositions plugin，資料在
這裡——spec 跟著資料走。

## 檔案角色

| 檔案 | 角色 |
|------|------|
| `SCHEMA.md` | schema 契約的**釘版副本**（scaffold 時從 plugin canonical 拷入；升版時隨 migration 更新） |
| `EXTRACTION-PROMPT.md` | 抽取紀律的釘版副本（Operation C 餵給 LLM 用） |
| `_meta.json` | `schema_version` + `source`（主檔路徑、錨定 commit、`parts` 快照）+ `coverage` |
| `main.jsonl` | 一行一個 proposition，依稿件閱讀序（Operation C 產出、A 閘門把關） |
| `_smoke_tests/` | 本稿專屬的最小 fixture（見其 README） |

## 生命週期（短版）

1. **首次抽取**：`/propositions:propositions` 選 Operation C（依 `EXTRACTION-PROMPT.md`
   對 `_meta.json` 記的主檔抽取）→ Operation A 驗證，通過才算抽完。
2. **日常**：改了 tex → Operation A 看 R13 漂移 → Operation B（dry-run 確認後）修位。
3. **送審前**：`/propositions:proofread`（語意）+ `/propositions:manuscript-audit`
   （跨檔案）+ `/propositions:clarity-audit`（可讀性）。
4. **大改版**（新 base / 章節重排）：Operation B 大範圍 re-anchor + 需要時 Operation C
   重抽該節；`retired` 欄位記錄停用的段落（見 SCHEMA.md §retired）。

完整生命週期（含 worked examples：Hsu case 的 re-anchor 與 line-anchored 通信慣例）
見 plugin 的 `docs/PLAYBOOK.md`。

## 指令備忘

```bash
# Operation A — 驗證（R1–R13）
python3 <plugin>/scripts/validate-propositions.py \
  --jsonl {{LEDGER_DIR}}/main.jsonl --meta {{LEDGER_DIR}}/_meta.json --tex {{TEX_PATH}}

# Operation B — location 漂移修復（先 dry-run）
python3 <plugin>/scripts/refresh-prop-locations.py \
  --jsonl {{LEDGER_DIR}}/main.jsonl --tex {{TEX_PATH}} --dry-run
```
