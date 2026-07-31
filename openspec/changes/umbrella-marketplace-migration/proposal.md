## Why

本 repo 的 propositions toolchain 已是領域通用的 manuscript-claim 基礎設施，但仍以單 plugin 佈局發佈，且同一套 validator scripts 在 psychquant-claude-plugins 的 math-tools plugin 內以人工鏡像並存——發佈版本 skew（CI pin v0.1.1 vs 安裝端 math-tools 0.5.0）已實際藏住過 retired-field 缺口（#1、PsychQuant/psychquant-claude-plugins#118/#119）。需要把本 repo 升級為 umbrella marketplace（`propositions-projects`），成為工具鏈唯一源頭。

## What Changes

- 本 repo 改為 `plugins/` monorepo 佈局：`plugins/propositions/`（core：validator + audit chain 入口 + 通用 manuscript-QA skills）與 `plugins/math-tools/`（薄 math-only pack）
- 從 psychquant-claude-plugins 的 math-tools 移植四個通用 skills（clarity-audit / proofread / manuscript-audit / propositions）到 core plugin
- 根層 `scripts/` 與 `tests/` 保留為 CI pin 的 audit-chain 入口（單一實體在 `plugins/propositions/` 內，根層以轉呼叫 shim 維持既有路徑契約）
- **BREAKING** `.claude-plugin/marketplace.json` 原地升級：marketplace name `propositions` → `propositions-projects`；單一 `"./"` entry → 兩個 `./plugins/*` entries
- **BREAKING** repo 改名 `propositions` → `propositions-projects`（GitHub redirect 過渡；下游 workflow `repository:` ref 需顯式更新）
- core plugin 宣告支援的 ledger schema 區間（≤ 1.5），不 vendoring SCHEMA.md
- 建立 release-flow 紀律文件（version bump + marketplace.json 同步 + `claude plugin marketplace update`）
- 產出給 psychquant-claude-plugins 與下游 repo 的 coordinated-change 清單（deprecation pointer、pin bump 指引），供跨 repo 執行

## Capabilities

### New Capabilities

- `umbrella-marketplace-layout`: `plugins/` monorepo 佈局 + marketplace manifest 的結構契約（entries、命名、CI 入口 shim、schema-range 宣告）
- `plugin-release-flow`: 本 marketplace 的發佈紀律（tag、version bump、manifest 同步、下游 pin bump 時序）

### Modified Capabilities

(none)

## Impact

- Affected specs: `umbrella-marketplace-layout`（new）、`plugin-release-flow`（new）
- Affected code:
  - New: plugins/propositions/.claude-plugin/plugin.json, plugins/propositions/scripts/, plugins/propositions/skills/, plugins/propositions/tests/, plugins/math-tools/.claude-plugin/plugin.json, docs/RELEASE-FLOW.md
  - Modified: .claude-plugin/marketplace.json, .claude-plugin/plugin.json, scripts/, tests/, README.md, plugins/propositions/README.md, plugins/math-tools/README.md, docs/MIGRATION-propositions-projects.md
  - Removed: .claude-plugin/plugin.json（單 plugin 佈局終結；根層 scripts 不刪、改為 shim）
