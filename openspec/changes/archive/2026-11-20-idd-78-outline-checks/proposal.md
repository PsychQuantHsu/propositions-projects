## Problem

綱要三個檔的確定性檢查都寫成 outline SKILL.md 裡的 `jq` 與 shell 指令（Swift 規則〈例外〉第 4 類）。規格 `article-outline` 的十三條 requirement 因此都寫著沒有可執行的檢查，驗收只能在 repo 外手動執行。另外有幾條格式規則沒有任何機械檢查：必填的鍵與型別、`parent` 與 `uses` 的方向、段落的分組順序、`dropped` 的連帶規則、同一筆紀錄裡重複的鍵（#78）。

## Root Cause

這些檢查寫的時候 Swift package 還不存在（#46），之後格式又改了三次（#91、#80、#92）。

## Proposed Solution

在 `PropositionsKit` 加上：

- 嚴格的 JSON 讀取：保留同一個物件裡重複的鍵，數字以十進位的值比較（`1` 與 `1.0` 相同；兩個不同的數字不管多長都不同）。Foundation 的解析兩件事都做不到。
- `propositions outline check <目錄>`：三個檔的格式檢查，每個問題帶檔名與行號。
- `propositions outline status <目錄>`：每一節是否仍照通過時的內容、節的順序、通過之後被拿掉的節；輸出的行與 skill 現在的 status 指令相同。
- `propositions outline locators <目錄> --root <root>`：每個來源指標是否恰好指到一處。

規格的前六條 requirement 換成 Example 與帶標記的 Swift 測試，並新增一條描述這三個子命令的 requirement。其餘七條講的是 skill 在對話裡的行為與說明文件的內容，理由行改寫成實際的情形。

## Non-Goals

- skill 改成呼叫子命令：plugin 還沒有辦法取得 binary（#46 留下的決定）。
- outline SKILL.md 其餘 13 項指令的子命令（找 root、守門、列帳冊、差異、確認紀錄的組裝、跨綱要參照的確認）；Swift 規則的例外留著。
- 發布帶這三個子命令的 binary。

## Success Criteria

- `swift test` 通過，含 13 個帶 `spec-example: article-outline` 標記的測試。
- 同一個綱要目錄，新的 `outline status` 與 skill 的 status 指令輸出逐行相同（用驗收工具裡的每一次 status 比對）。
- `spectra validate`、規格連結檢查與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（新增 1 條 requirement，修改 13 條）
- Affected code:
  - New: `Sources/PropositionsKit/JSONValue.swift`、`Outline.swift`、`OutlineCheck.swift`、`OutlineStatus.swift`、`OutlineLocators.swift`、`tests/PropositionsKitTests/OutlineTests.swift`
  - Modified: `Sources/PropositionsKit/CLI.swift`、`CommandRun.swift`、`Version.swift`（0.2.0）、`CLAUDE.md`、`.claude/rules/swift-is-the-implementation-language.md`
  - Removed: (none)
