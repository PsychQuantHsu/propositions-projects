## Why

#47 的第五輪驗證不通過：7 項要修、13 項範圍內的小修。這是把結果規則拆到 #71 之後的第一輪，原本每輪約 7 項的「發現算在哪一列、哪個單位」沒有再出現。剩下的 7 項裡，3 項是留在這個 capability 的一小段結果語意彼此對不上，2 項是適用條件，1 項是測試缺陷，1 項是一句文字。

維護者 2026-11-13 回覆 Codex 的額度恢復了，沒有對貼出的修法提出不同意見（#47 的決定紀錄）。這個 change 照那份修法做，之後跑完整的第六輪。

## What Changes

- **四種結果的定義**不再寫「檢查回報了什麼」。`passed` 是這一列對這個單位判定為過，`failed` 是判定為不過，兩者成立的條件由 #71 的規則定；`unverified` 仍是其他三種都沒有成立。
- 這個 capability 只留下那些規則要守住的七點：`unverified` 是剩下的那一種；`passed` 要檢查確實檢查過這個單位，而且不代表判準成立；`failed` 要有對這個單位不利的發現或紀錄；`info` 的那種警告既不擋通過也不算沒通過；`judge` 的警告沒有人判定之前擋通過；一筆 `supported` 只對那次閱讀做過的檢查算數；今天沒有任何一列是通過。
- 可以是 `info` 的四列，判準寫的就是那條警告回報的情況。規格與文件寫明：單位可以在判準不成立時通過這四列，這是維護者審表時的決定。
- 適用條件的值讀不出來時是 `unverified`，檢查對這個單位印了什麼都一樣。文件寫明這是定義的結果：值讀不出來，這一列適不適用就沒有成立。
- 拿掉「錯誤是說判準被違反」這一句。
- **新的一列缺口** `truth.cited-work-agrees`（負責人 #50）：命題的文字引用的每一份外部文獻，說的是命題取用的內容。沒有 `applies`，所以 default 帳冊也適用。帶 `external_source: true` 的列從三列變成四列；表從 67 列變成 68 列。文件與規格原本把這件事寫成限制，那一段拿掉。
- **讀不出來的條件改成封閉列舉**，一個鍵一條：
  - `profile`：加上 `_meta.json` 解析不了或不是物件。
  - `claim_type`、`evidence_class`：加上值不在帳冊 profile 的詞彙裡。
  - `opens`：加上命題沒有 id，或和另一筆未退役的命題共用 id。
  - `section_role`：章節清單不可用的十一種情形才算；主旨、`parent`、摘要裡的承諾、段落計畫的錯誤不算。「未退役」照結構驗證器的算法。
- 報告指名單位時，沒有 id 或共用 id 的命題用帳冊的行。
- 守衛：型別不對的案例只對格式檢查的結果下斷言，並加「沒改動的小表不命中」的基準；文件的檢查改成整個詞比對，並改用帶著那句話的字句；釘住新的一列。
- `docs/VERIFICATION.md` 那一段改成「今天沒有紀錄能讓一列通過」，拿掉規格沒有要求的一句。
- 文字修正：兩段 SHALL 移到第一個 Scenario 之前；一個 Scenario 的標題；行號更新試跑的排除理由；`relation`、`profile` 鍵、L5 三處寫錯的理由；文件裡一段像是對照規則的話。
- Swift 規則檔的例外補上守衛讀的第四組詞彙 `METHODS`。

## Non-Goals

- 不改任何腳本，不改驗證紀錄的格式，不實作任何缺口的檢查。
- 不定義怎麼從檢查的輸出算出結果，也不定義通過的條件。那是 #71 的工作。
- 不改維護者看過的列的欄位。新的一列是另外加的；外部依據的兩列維持原樣，它們和新列在 empirical 帳冊裡重疊的部分留給 #50 決定。
- 不升版：這些內容還沒發布過，版本維持 0.11.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-obligations`: 八條 requirement 修改：類別、適用條件、已實作的檢查、驗證方式、四種結果、完全合理、說明文件、守衛。

## Impact

- Affected specs: `article-obligations`（修改）
- Affected code:
  - Modified: `plugins/propositions/catalog/obligations.yaml`、`plugins/propositions/docs/OBLIGATIONS.md`、`plugins/propositions/docs/VERIFICATION.md`、`tests/test_plugin_payload_tracked.py`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
- GitHub：#71 的正文補上這一輪交給它的規則；#50 留 note 說明新的一列；#47 記錄維護者的回覆、計畫與盲驗的題目、答案。
