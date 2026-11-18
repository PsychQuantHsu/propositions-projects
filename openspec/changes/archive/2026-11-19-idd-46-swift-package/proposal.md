## Why

repo 沒有 Swift package，而 Swift 規則不准既有的 Python 加新的檢查，所以每一條新的機械檢查都卡住（#46）。#45 的決定（2026-11-11）定了第一步：建 package，並把第一條新檢查「引用只能指向前面出現過的命題」直接寫成 Swift；既有的 R1–R13、S1–S9 留在 Python。

## What Changes

- 根目錄新增 `Package.swift`：library `PropositionsKit`、executable `propositions`、executable `tschema-check`、測試 target `PropositionsKitTests`（Swift Testing）。
- `PropositionsKit` 讀帳冊（`id`、`location`、`cites`、`retired`）、解析 `location`、依 `\input` 樹算閱讀順序，並做引用方向檢查。
- `propositions cite-order`：每一個指到後面命題的引用報一行警告；第一版只警告、不擋。
- `tschema-check` 第一版只回報版本並說明驗證仍在 Python 腳本。
- plugin 下載 binary 的 wrapper 與簽章發布的腳本（Swift 規則〈例外〉第 1 類）。發布本身不在這次做，等維護者確認。
- 本機 CI 加上 `swift test`；`CLAUDE.md` 與 Swift 規則檔更新現況。

## Non-Goals

- 移植既有的 Python 驗證器、`tschema-check` 的驗證、義務表的守衛。
- 自動放行路線圖與預告這兩種向後的引用：第一版一律警告，由作者判斷。
- 發布簽過章的 binary，以及讓 skill 呼叫新的子命令：兩者都等發布。義務表的 `dependence.cites-backward` 在發布之前維持缺口。

## Capabilities

### New Capabilities

- `citation-order`: 引用方向檢查，以及它所在的 Swift package 與命令列工具。

### Modified Capabilities

(none)

## Impact

- Affected specs: `citation-order`（新）
- Affected code:
  - New: `Package.swift`、`Package.resolved`、`Sources/PropositionsKit/`、`Sources/propositions/`、`Sources/tschema-check/`、`tests/PropositionsKitTests/`、`plugins/propositions/bin/propositions-wrapper.sh`、`scripts/release-signed.sh`
  - Modified: `.gitignore`、`CLAUDE.md`、`.claude/rules/swift-is-the-implementation-language.md`、`pytest.ini`
  - Removed: (none)
