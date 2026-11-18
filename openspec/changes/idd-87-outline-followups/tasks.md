## 1. 指令

- [x] 1.1 列 `.tex` 不分大小寫，對應 Requirement「Derive and draft build an outline without inventing content」。完成時：`find` 用 `-iname`，引入規則寫明「in any letter case」，三份文字一致。驗證：驗收案例「tex-list: a tracked file whose name ends in .TEX is listed」在八種組合通過、在修正前失敗。
  - `510e38b`：`find … -iname '*.tex'`；驗收案例在八種組合通過，在 main 的 SKILL.md 上失敗。
- [x] 1.2 不是嚴格 JSON 的 `_meta.json` 不算帳冊，對應 Requirement「The outline is three files beside the ledger」。完成時：列帳冊印 `not one ledger`，比對不印 `ok`。驗證：驗收案例 `lead0`、`nanv`、`inf`、`dot5`、`names` 在八種組合通過、在修正前失敗；字串裡含這些字樣的合法 JSON 仍是帳冊。
  - `510e38b`：列帳冊與比對帳冊都先跑寫入檢查那一段原始文字的判斷。`01`、`nan`、`Infinity`、`.5` 四種各印 `not one ledger`，比對不印 `ok`；字串裡含這些字樣的 JSON 仍印 `ledger`。新加 7 項，在 main 的 SKILL.md 上 6 項失敗。寫壞的 JSON（例如 `{not json`）以前沒有任何一行、只有 jq 的錯誤，現在也印 `not one ledger`；兩項舊驗收的期望跟著改。

## 2. 文字

- [x] 2.1 SKILL.md 的十列文字各改一句，OUTLINE.md 對齊，對應 Requirement「Only the author's explicit statement in the current message approves」（寫入失敗時不展示最後一行）、「Text from the manuscript and the author never becomes part of a command」（作者指定的檔路徑含單引號）與「Derive and draft build an outline without inventing content」（其餘各列）。完成時：診斷 B 組每一列在兩份文字裡說同一件事。驗證：逐列對照 `git diff`。
  - `510e38b`：SKILL.md 十處、OUTLINE.md 七處。
- [x] 2.2 規格 delta：4 條 requirement，含 3 個新情境。完成時：`spectra validate` 通過。
  - 4 條 requirement、3 個新情境；`spectra validate` 通過，`spectra analyze` 沒有 warning。

## 3. 驗收

- [x] 3.1 八種組合（zsh、bash × homebrew、system、GNU、bfs）全過。
  - 八種組合各 394 項全過（bfs 的兩種 393 項），0 項失敗。
- [x] 3.2 用正式的 `propositions:outline-checker` 跑一次確認一份只有節的綱要，走到記下確認與 status。
  - 一份兩節、段落檔是空的綱要：寫入檢查印 `ok write check: 2 records` 與 `EMPTY`，來源指標清單是空的；以 skill 規定的訊息啟動 `propositions:outline-checker`（安裝的 plugin 是 0.12.0），它只用 Read 讀了三個檔，對兩節各回報一項第 5 類，其餘四類沒有發現。展示、記下確認與 status 三步這次沒有接著手動跑，由驗收的 `shown`、`append`、`status` 各項涵蓋。
- [x] 3.3 `pytest tests/` 通過；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。
  - `pytest tests/`：872 passed、3 skipped；三個目錄相對於 main 沒有變動；指令區塊仍是 19 段。
