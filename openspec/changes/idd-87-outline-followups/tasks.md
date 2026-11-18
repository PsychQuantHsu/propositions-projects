## 1. 指令

- [ ] 1.1 列 `.tex` 不分大小寫，對應 Requirement「Derive and draft build an outline without inventing content」。完成時：`find` 用 `-iname`，引入規則寫明「in any letter case」，三份文字一致。驗證：驗收案例「tex-list: a tracked file whose name ends in .TEX is listed」在八種組合通過、在修正前失敗。
- [ ] 1.2 不是嚴格 JSON 的 `_meta.json` 不算帳冊，對應 Requirement「The outline is three files beside the ledger」。完成時：列帳冊印 `not one ledger`，比對不印 `ok`。驗證：驗收案例 `lead0`、`nanv`、`inf`、`dot5`、`names` 在八種組合通過、在修正前失敗；字串裡含這些字樣的合法 JSON 仍是帳冊。

## 2. 文字

- [ ] 2.1 SKILL.md 的十列文字各改一句，OUTLINE.md 對齊，對應 Requirement「Only the author's explicit statement in the current message approves」（寫入失敗時不展示最後一行）、「Text from the manuscript and the author never becomes part of a command」（作者指定的檔路徑含單引號）與「Derive and draft build an outline without inventing content」（其餘各列）。完成時：診斷 B 組每一列在兩份文字裡說同一件事。驗證：逐列對照 `git diff`。
- [ ] 2.2 規格 delta：4 條 requirement，含 3 個新情境。完成時：`spectra validate` 通過。

## 3. 驗收

- [ ] 3.1 八種組合（zsh、bash × homebrew、system、GNU、bfs）全過。
- [ ] 3.2 用正式的 `propositions:outline-checker` 跑一次確認一份只有節的綱要，走到記下確認與 status。
- [ ] 3.3 `pytest tests/` 通過；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。
