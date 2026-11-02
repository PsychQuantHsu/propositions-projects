## Why

帳冊目前記錄兩件事：每個 proposition 主張什麼（`claim_type`、`evidence_class`、`asserts`），以及它的成立靠哪些 proposition（`cites`）。它沒有記錄**一篇文章是怎麼蓋起來的**：文章向讀者承諾了什麼、現在寫到計畫的哪一節、這一句和上一句是什麼關係。所以本 plugin 能逐句查核，卻回答不了 #26 的問題：「已知 prop_t，prop_{t+1} 該寫什麼？」也抓不到整篇層次的失敗：引言宣告的分析後面沒做、研究問題沒有被回答、回指一個前面從沒提過的顧慮。

使用者要求從「建構一篇完整文章」的觀點處理這個問題。以範例稿件（`docs/REFERENCE-MANUSCRIPTS.md` 的期刊版）來看，下一句由三層決定：文章還欠讀者哪些承諾（研究問題、目的、宣告的章節計畫、「We now examine …」這類近距離承諾）、目前所在章節的角色、以及和上一句的局部關係（That is、Therefore、However 等連接詞標出的關係）。這三層都可以記錄，而且大部分可以機械檢查。

## What Changes

- 新增帳冊旁的兩個附檔（sidecar），不改 `main.jsonl` 的 schema，比照 `verification.jsonl` 的先例：
  - `structure.json`：文章層次，記錄章節計畫（每節的標題、角色、第一個 prop）與全文主旨所在的 prop。
  - `discourse.jsonl`：每個 prop 一筆，依帳冊閱讀順序排列，記錄它和前一個 prop 的關係、它開出的承諾、它兌現的承諾。
- 三個封閉詞彙：相鄰關係（12 個值）、承諾種類（7 個值）、章節角色（10 個值，含 worked example 標註時經使用者同意加入的 `abstract`）。
- 新增 validator `validate-structure.py`，S1–S6 規則：附檔涵蓋每個 prop 且順序一致、詞彙合法、承諾先開後兌現、每個承諾在文末前都被兌現（`future_work` 除外）、章節計畫與帳冊順序一致、近距離承諾在同一節內兌現。
- 新增狀態查詢 `structure-state.py`：給定位置 t，回報目前所在章節與角色、尚未兌現的承諾（依緊迫程度排序）、上一個關係，作為「prop_{t+1} 可以做什麼」的機械答案。
- 新增 skill `propositions:construct`，兩種模式：
  - 標註：替已有帳冊的稿件建立兩個附檔，經 validator 與使用者確認後寫入。
  - 下一步：對寫到一半的稿件，依狀態查詢說明下一句要推進哪個承諾、用什麼關係接上、會是什麼 `claim_type`，提出候選句給作者，不寫進稿件。
- 以範例稿件期刊版做 worked example：抽取完整帳冊、標註結構、跑 validator，彙總結果寫進 `docs/REFERENCE-MANUSCRIPTS.md`；帳冊與附檔留在私有稿件 repo。
- plugin 版本 0.5.0 → 0.6.0。

## Capabilities

### New Capabilities

- `article-structure`: 帳冊旁的文章結構附檔（`structure.json`、`discourse.jsonl`）、三個封閉詞彙、S1–S6 validator 與位置狀態查詢。
- `article-construction`: `propositions:construct` skill 的標註與下一步兩種模式，以及它們的確認與寫入紀律。

### Modified Capabilities

(none)

## Impact

- Affected specs: `article-structure`（新）、`article-construction`（新）
- Affected code:
  - New:
    - plugins/propositions/scripts/validate-structure.py
    - plugins/propositions/scripts/structure-state.py
    - plugins/propositions/docs/STRUCTURE.md
    - plugins/propositions/skills/construct/SKILL.md
    - plugins/propositions/skills/construct/references/vocabulary.md
    - tests/test_validate_structure.py
    - tests/test_structure_state.py
    - tests/fixtures/structure/
  - Modified:
    - docs/SCHEMA.md
    - docs/REFERENCE-MANUSCRIPTS.md
    - plugins/propositions/README.md
    - plugins/propositions/docs/PLAYBOOK.md
    - plugins/propositions/.claude-plugin/plugin.json
    - .claude-plugin/marketplace.json
    - CLAUDE.md
  - Removed: (none)
