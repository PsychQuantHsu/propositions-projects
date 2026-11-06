## Why

`propositions:construct` 的 next 模式目前會說下一句掛在哪裡、用什麼關係相接、推進哪個承諾、預期的 `claim_type`，但不說這一句要做什麼。#33 建了連結清單 `plugins/propositions/catalog/links.csv`，當時的 spec 規定 next 模式這一版不讀它，要不要讀之後依命中率決定。

#36 的量測給出了依據：用目前這一句的 `move` 查表，預測下一句的 `move`（前 3 個命中），同一篇內留一段是 61%／27%（實證稿）、82%／78%（數學稿），用另一篇的表是 43%／28% 與 67%／40%（依 `move`／不看條件）。預測下一句的關係則沒有提升（51%／55%、77%／77%）。維護者 2026-11-06 決定採用，並縮小範圍。

## What Changes

- next 模式的每個候選多一項：這一句預期的 `move`（標籤「Does」）。
- next 模式在提候選之前，用現成的工具查目前這一句的 `move`，再查連結清單裡這個 `move` 之後出現過的走法，依下一步的 `move` 加總次數，取最多的三個當提示。
- 提示只影響候選寫出來的 `move`，不改候選的先後順序：有等頭的子句、有未兌現的 announcement 時，第一個候選仍照原規則決定。
- 候選的 `move` 可以不在提示裡，不產生任何警告；連結清單仍然是觀察到的走法，不是規則。
- 關係不參考連結清單：候選的關係照原本的方式決定，因為量測顯示連結清單對關係沒有提升。
- 目前這一句沒有 `move`、連結清單裡沒有這個 `move` 的走法、或查詢失敗時，略過提示並說明原因，next 模式照常完成。
- `propositions` plugin 版本升到 0.9.0。

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `article-construction`: 修改 Requirement「Next mode proposes at most three candidates without writing」，候選新增 `move`；以新的 Requirement 取代「Next mode does not consult the link catalog」，規定提示的取得、用途與略過條件。

## Impact

- Affected specs: `article-construction`
- Affected code:
  - Modified: `plugins/propositions/skills/construct/SKILL.md`、`plugins/propositions/docs/STRUCTURE.md`、`plugins/propositions/README.md`、`docs/REFERENCE-MANUSCRIPTS.md`、`CLAUDE.md`、`plugins/propositions/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`tests/test_structure_links.py`
  - New: (none)
  - Removed: (none)
- Python 腳本的行為不變：查詢用現成的工具，符合 `.claude/rules/swift-is-the-implementation-language.md`。
