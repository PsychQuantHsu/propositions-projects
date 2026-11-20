## Problem

一份寫完的長稿拆成幾篇文章時，有三件事跨出了一份綱要：節或段落去了哪一篇、一篇對另一篇的依賴、節在這一篇的哪一部分（主文、附錄、補充資料）。格式沒有位置可記，使用端在 section 紀錄上自己加了一個鍵（#92）。

## Root Cause

格式的規則都以「一份綱要是一篇文章」為前提，沒有任何鍵能指到這一份綱要之外。

## Proposed Solution

維護者的決定（https://github.com/PsychQuantHsu/propositions-projects/issues/92#issuecomment-6981750690）：做法 A，每一篇文章各有自己的綱要目錄，前提留著，格式加三樣。診斷留給規格定的兩件事在這裡定：

- `moved_to`：非空字串，只在有 `dropped` 的紀錄上（section 與段落紀錄都可以）。給人讀，skill 不解析。
- `part`：section 紀錄上，封閉的三個值 `main`、`appendix`、`supplement`；沒有就是主文。它說節印在哪裡，不影響順序與前提檢查。
- 跨綱要的參照：`uses` 與 `basis` 的成員可以是 `{"outline": "<另一份綱要的目錄，從 root 寫起>", "id": "<id>"}`。兩段新指令列出並確認：目錄在 repository 內、不在 `.git` 裡、不是自己、段落檔是一般檔且是 JSON、`id` 在裡面。只確認 id 存在，不讀另一篇的內容。解析不到的算前提檢查的第六類。

locator 的三段指令略過這種參照；checker 的定義寫明不讀另一份綱要。

## Non-Goals

- 一份綱要裝幾篇文章（做法 B）。
- 兩篇對同一段原稿的說法是否一致。
- 另一個 repository 裡的綱要。

## Success Criteria

- 八種組合全過，含新的案例：合法的 `moved_to`、`part`、參照通過；`moved_to` 與 `part` 的各種錯誤寫法被報出；參照的 id 不存在、目錄在外面、在 `.git` 裡、沒有段落檔、不是 JSON、是 symbolic link、是自己、從 `/` 寫起，各自解析不到。
- `spectra validate` 與 `pytest tests/` 通過。

## Impact

- Affected specs: `article-outline`（修改 2 條 requirement，加 5 個情境）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（寫入檢查、locator 的三段指令、兩段新指令與說明）、`plugins/propositions/docs/OUTLINE.md`、`plugins/propositions/agents/outline-checker.md`、`.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
