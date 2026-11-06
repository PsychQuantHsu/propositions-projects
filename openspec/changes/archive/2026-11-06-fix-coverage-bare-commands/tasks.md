## 1. 覆蓋工具

- [x] 1.1 在 `tests/test_check_extraction_coverage.py` 加案例釘住 Requirement「Coverage check reports uncovered text in a line range」的新 Scenario：只有排版指令的片段不回報、註腳文字已覆蓋時 `\footnote{` 不回報、註腳文字沒覆蓋時回報、`\cite{smith2020}` 回報、全由控制字組成的公式回報、沒列到的指令回報。前兩個在修之前要失敗。接著改 `plugins/propositions/scripts/check-extraction-coverage.py`：判斷片段是否含文字之前先去掉封閉列舉的排版指令，並更新 docstring，不動排除清單、參數與輸出欄位。驗證：`pytest tests/test_check_extraction_coverage.py` 通過，既有案例都沒有改。

## 2. 入口

- [x] 2.1 更新 `plugins/propositions/skills/analyze/SKILL.md`，對應 Requirement「Coverage is judged from the uncovered text」：拿掉對 #42 的引用，把不帶句子的指令的例子換成 `\vspace{1em}`，保留把這些片段交給 `construct` 的規定，並更新 `tests/test_plugin_payload_tracked.py` 裡的斷言訊息。驗證：`pytest tests/test_plugin_payload_tracked.py -k analyze` 通過，`grep -c '#42' plugins/propositions/skills/analyze/SKILL.md` 為 0。

## 3. 版本與驗收

- [x] 3.1 [P] 把 `propositions` plugin 升到 0.10.1（`plugins/propositions/.claude-plugin/plugin.json` 與 `.claude-plugin/marketplace.json`）。驗證：`pytest tests/test_marketplace_entries.py tests/test_plugin_payload_tracked.py` 通過，兩處版本相同。
- [x] 3.2 用參考帳冊跑 `check-extraction-coverage.py`：`\begin{document}` 之後的未覆蓋從 8 段變 4 段，剩下的都是文末內容，涵蓋正文的範圍 exit 0。全套 `pytest tests/` 通過、`idd-ci-gate.sh` 對 head commit 通過、`spectra validate fix-coverage-bare-commands` 通過。驗證：貼出數字，不含稿件文字。
