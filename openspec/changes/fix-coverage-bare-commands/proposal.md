## Problem

`check-extraction-coverage.py` 把只有指令的片段報成未覆蓋：`\maketitle`，以及註腳文字已有 proposition 覆蓋時剩下的 `\footnote{`。一本已抽完的參考帳冊，在 `\begin{document}` 之後的 8 段未覆蓋裡有 4 段是這種片段：`\maketitle`、兩個 `\footnote{`、一個 `{\small`。

後果是 `construct` 的 A1 會停下：它寫明任何範圍回報未覆蓋就停，而 `construct-batch` 共用 A1。有註腳的稿件，帳冊抽完了仍然到不了標註（#42）。

## Root Cause

判斷一段算不算文字時，只看有沒有字母或數字。指令的名稱也是字母，所以 `\maketitle` 算文字。

## Proposed Solution

判斷前先去掉一份封閉列舉的排版指令（`\maketitle`、`\footnote`、`\small` 這類，共 22 個）。去掉之後沒有字母或數字的片段不回報。

只能列舉，不能去掉所有控制字。第一版就是那樣寫的，全套測試都過了，但 `\alpha \le \beta` 這種全由控制字組成的公式會被靜默放過，而這個工具的目的正是不漏東西。列舉的代價是沒列到的指令仍會回報，這是現狀，方向是安全的。

帶內容的片段照舊回報：`\cite{smith2020}` 的引數算文字，`\footnote{` 後面接著沒被覆蓋的句子時，整段都會回報。

`analyze` 同步更新：拿掉對 #42 的引用，把例子換成仍會被回報的指令。把判定為不算的片段交給 `construct` 的規定留著，因為 `construct` 的 A1 看到任何未覆蓋都會停，而 `\vspace{1em}` 這類帶引數的指令仍會回報。

## Non-Goals

- 不增加第六種排除結構：排除清單不變，改的是「文字」的定義。
- 不改 `construct` 的 A1：工具不再誤報，A1 就不會因此停下。
- 不移植成 Swift：這是修 bug，依 Swift 規則可以留在既有的 Python，回歸測試加進已涵蓋它的 pytest 檔。
- 不新增參數或輸出欄位。

## Success Criteria

- 只有 `\maketitle` 或 `\footnote{` 的片段不回報。
- `\cite{smith2020}`、`\footnote{` 後面接著未覆蓋句子的片段、全由控制字組成的公式、沒列到的指令都仍回報。
- 用參考帳冊跑一次：`\begin{document}` 之後的未覆蓋從 8 段變 4 段，剩下的都是文末內容，涵蓋正文的範圍 exit 0。
- 既有的覆蓋測試全部不變地通過。

## Impact

- Affected specs: `proposition-extraction`, `article-analysis`
- Affected code:
  - Modified: `plugins/propositions/scripts/check-extraction-coverage.py`、`plugins/propositions/skills/analyze/SKILL.md`、`tests/test_check_extraction_coverage.py`、`tests/test_plugin_payload_tracked.py`、`plugins/propositions/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`
