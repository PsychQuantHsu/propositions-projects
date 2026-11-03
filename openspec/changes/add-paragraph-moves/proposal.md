## Why

依存樹（#30）記下了句子怎麼接，卻沒有記這句在做什麼，所以還是看不清楚一段的走向。維護者在 #33 指定了重點：要能用這個方法看清文章句子與句子之間的關係。

量測也顯示只靠現有標籤不夠。每次留一段不進統計，用其餘段落的表預測下一句的關係，前 3 個選項的命中率：不看條件時實證稿 55%、數學稿 77%；依關係查 59%、81%；加上 `claim_type` 與章節角色反而掉到 48%、70%。跨稿件時依關係查還低於不看條件。實證稿唯一重複的關係序列出現在兩段，一段是目的總結，一段是未來方向，樹也不同。

## What Changes

- 新增一層標註：`discourse.jsonl` 的紀錄可記 `move`（這一句在做什麼），`structure.json` 的段落可記 `type`（這段是什麼類型）。兩者都是選填，`structure_version` 維持 `"2.0"`，既有附檔不改也照常通過。
- 新增封閉詞彙 `plugins/propositions/catalog/vocabulary.yaml`，手寫，定義步驟與段落類型。
- 新增 `plugins/propositions/scripts/structure-explain.py`：把一段或一節讀成「第幾句、在做什麼、掛在第幾句、什麼關係」。這是主要成果。
- 新增 `plugins/propositions/scripts/build-link-catalog.py` 與產生的 `plugins/propositions/catalog/links.csv`：步驟之間所有種類的連結，一種連結一列，記類型、段落類型、兩端、關係、範圍、標籤與次數，只含次數，不含稿件文字。（全篇標完後依維護者決定由 YAML 目錄改來，見 design。）
- 新增 `plugins/propositions/scripts/structure-links.py`：列出一句的所有連結，以及目錄裡某個步驟看過與沒看過的走法。「沒看過」由詞彙算出，不另外儲存。
- `validate-structure.py` 新增規則 S9：`move` 與 `type` 的值要在詞彙裡。目錄沒有的走法不提示。
- `structure-metrics.py` 報告步驟的覆蓋率、和 `claim_type` 與關係的關聯、下一步的命中率，以及兩份標註之間的 Cohen's κ。
- `structure-batch.py` 新增只標步驟的模式，不動既有的依存樹。
- `/propositions:construct` 的標註流程加上這一層，並新增「解釋」用法；`/propositions:construct-batch` 同步。
- 兩篇參考稿件全篇標註這一層。

## Non-Goals

- next 模式這次不引用目錄。要不要引用，之後依本次報告的命中率決定。
- 不標「不可能」的走法。兩篇稿件判斷不出來，沒看過不等於不可能；目錄只分看過與沒看過。
- 目錄沒有的走法不提示，也不觸發檢查失敗；目錄只是觀察到的走法，不是規則。
- 不修 #34（每筆都有 `note` 的問題）。

## Capabilities

### New Capabilities

- `paragraph-moves`: 步驟與段落類型的詞彙、附檔上的標註、讀法工具、目錄產生與量測

### Modified Capabilities

- `article-structure`: 結構檢查新增規則 S9
- `article-construction`: 標註流程加上步驟與段落類型，新增解釋用法

## Impact

- Affected specs: `paragraph-moves`（新）、`article-structure`、`article-construction`
- Affected code:
  - New:
    - plugins/propositions/catalog/vocabulary.yaml
    - plugins/propositions/catalog/links.csv
    - plugins/propositions/scripts/_lib/link_catalog.py
    - plugins/propositions/scripts/structure-links.py
    - plugins/propositions/scripts/_lib/move_vocabulary.py
    - plugins/propositions/scripts/structure-explain.py
    - plugins/propositions/scripts/build-link-catalog.py
    - tests/test_move_vocabulary.py
    - tests/test_structure_explain.py
    - tests/test_build_link_catalog.py
    - tests/test_structure_links.py
  - Modified:
    - plugins/propositions/scripts/validate-structure.py
    - plugins/propositions/scripts/structure-metrics.py
    - plugins/propositions/scripts/structure-batch.py
    - plugins/propositions/docs/STRUCTURE.md
    - plugins/propositions/docs/PLAYBOOK.md
    - plugins/propositions/README.md
    - plugins/propositions/skills/construct/SKILL.md
    - plugins/propositions/skills/construct/references/vocabulary.md
    - plugins/propositions/skills/construct-batch/SKILL.md
    - plugins/propositions/.claude-plugin/plugin.json
    - .claude-plugin/marketplace.json
    - docs/SCHEMA.md
    - docs/REFERENCE-MANUSCRIPTS.md
    - CLAUDE.md
    - tests/test_validate_structure.py
    - tests/test_structure_metrics.py
    - tests/test_structure_tools.py
  - Removed（本 change 內先產生、後取代）：plugins/propositions/catalog/paragraph-catalog.yaml、plugins/propositions/scripts/build-paragraph-catalog.py、tests/test_build_paragraph_catalog.py
  - 依賴：標到 `move` 或 `type` 時需要 PyYAML；沒有這兩個欄位的附檔不需要。查目錄（`structure-links.py catalog`）要用詞彙驗證輸入值，也需要 PyYAML。
