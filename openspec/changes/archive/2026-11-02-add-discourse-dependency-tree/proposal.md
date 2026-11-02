## Why

#26 的文章結構模型每句只記一條「跟上一句」的關係。可是在範例稿件裡，有依賴的 191 句中只有 65 句（34%）只依賴上一句；前置子句（"Because …,"）的關係在下一句，卻被迫標成向後的關係；段落也不是單位。#30 的討論定案改用三層依存樹（句、段、節），並把 #31 的承諾巢狀排序一起處理。

## What Changes

- **BREAKING** `discourse.jsonl` 的每筆記錄改成 `head`（同段內的另一句，可在前或在後；段根不寫）加 `relation`（這一句相對於頭的角色）；`refers_to` 移除；新增選填的 `also: [{to, relation}]`，記樹與 `cites` 都沒有的修辭關係。草稿的最後幾句可以寫 `"head": "pending"`，表示頭還沒寫出來（只在 `--partial` 下允許）。
- **BREAKING** 關係詞彙由 12 個改成 10 個：9 個內容關係（`continue`、`restatement`、`specification`、`instance`、`addition`、`contrast`、`reason`、`consequence`、`sequence`）加 `basis`（被指向的句子提供這一句用到的定義、結果、公理或分案）。`start`、`shift`、`return` 不再是標籤，改由樹推出。
- **BREAKING** `structure.json` 的 `structure_version` 改為 `"2.0"`；新增 `paragraphs` 清單（`id`、`first_prop`、選填 `head`、`relation`）；`sections[]` 新增 `parent`。段落是封閉子樹：一句的頭只能在同一段內，段落的頭只能在同一節內，段落不跨節。1.0 的附檔不再被接受，檢查器會指向遷移工具。
- 檢查規則：S2 改為檢查頭與關係（每段一個根、頭不出段、無環、`pending` 只在 `--partial`）；S5 加入段落計畫與章節 `parent`；新增 S7（交叉弧，只警告並計數）與 S8（標成 `basis` 的邊不在帳冊 `cites` 裡時警告）。S1、S3、S4、S6 不變。
- 狀態查詢新增：位置 t 所在的段落與段根、右邊緣（從 t 沿著頭往上到段根，再沿段頭到節根、沿 `parent` 到全文）、還在等頭的句子、每個承諾的範圍（開出它的段落與章節）。新增 `--order kind|scope`：`kind` 為 0.6.0 的排序；`scope` 為「範圍越內層越前，同範圍先開先排」，在範例稿件上命中較多（94 對 89／231），為預設。
- 新增 `derive-paragraphs.py`：由 tex 空行與帳冊 `location` 推出預設段落清單。
- 新增 `migrate-structure-v2.py`：把 1.0 附檔機械地轉成 2.0，並列出需要人工複查的記錄。
- 新增 `structure-metrics.py`：報告交叉弧比例、右邊緣長度分布、兩種承諾排序的命中數、關係與頭方向的計數。
- construct skill：annotate 模式改標頭、段落與章節樹；next 模式用右邊緣、等頭的句子與承諾提出候選，每個候選說明它掛在右邊緣的哪個節點上。
- 驗收：範例稿件（Cheng, Lay, Hsu, & Tsai, 2021）重新標註、`PsychQuantHsu/psychophysical_representations` 全篇標註，兩篇都通過檢查；以 `structure-metrics.py` 報告交叉弧比例（超過 5% 須重新檢討模型）、右邊緣中位長度與排序命中數；`scope` 排序在範例稿件 231 個位置上贏過現行的 89 個命中，才把它改成預設（量得 94，已改為預設）。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-structure`: 附檔格式改成三層依存樹；關係詞彙、S2、S5、狀態查詢改寫；新增 S7、S8、段落推導、遷移與量測工具。
- `article-construction`: annotate 模式標頭與段落；next 模式依右邊緣與等頭的句子提出候選。

## Impact

- Affected specs: `article-structure`, `article-construction`
- Affected code:
  - New:
    - plugins/propositions/scripts/derive-paragraphs.py
    - plugins/propositions/scripts/migrate-structure-v2.py
    - plugins/propositions/scripts/structure-metrics.py
    - tests/test_derive_paragraphs.py
    - tests/test_migrate_structure.py
    - tests/test_structure_metrics.py
    - tests/fixtures/structure-v1/（1.0 fixture 的原封副本，給遷移測試當輸入）
  - Modified:
    - plugins/propositions/docs/STRUCTURE.md
    - plugins/propositions/scripts/validate-structure.py
    - plugins/propositions/scripts/structure-state.py
    - plugins/propositions/skills/construct/SKILL.md
    - plugins/propositions/skills/construct/references/vocabulary.md
    - tests/test_validate_structure.py
    - tests/test_structure_state.py
    - tests/structure_case.py
    - tests/fixtures/structure/structure.json
    - tests/fixtures/structure/discourse.jsonl
    - tests/fixtures/structure/README.md
    - docs/SCHEMA.md
    - docs/REFERENCE-MANUSCRIPTS.md
    - plugins/propositions/docs/PLAYBOOK.md
    - plugins/propositions/README.md
    - plugins/propositions/.claude-plugin/plugin.json
    - .claude-plugin/marketplace.json
    - CLAUDE.md
  - Removed: (none)
- 標註附檔放在兩篇稿件各自的 repository，不進本 repo；本 repo 只記量測數字。
