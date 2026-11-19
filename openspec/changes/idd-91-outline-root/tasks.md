## 1. 指令

- [x] 1.1 新增「The root is the repository of the outline directory」一段指令，對應 Requirement「The outline is three files beside the ledger」。完成時：文章 repo 當 root、只 clone 文章 repo 時同樣的 locator 解析得到、綱要在不含稿件的 repo 時停下、綱要目錄在 repo 外或父目錄不存在時停下、沒有稿件時照常、經 symbolic link 的目錄照實際位置算，各有驗收案例。

## 2. 文字

- [x] 2.1 SKILL.md 的 `ROOT` 定義、忽略規則的兩段；OUTLINE.md 的 repository 定義與 locator 段落；規格兩條 requirement，對應 Requirement「A locator names a passage by a label or by its opening words」。
- [x] 2.2 Swift 規則檔〈例外〉第 4 類的清單加一項、段數改成 20。

## 3. 驗證

- [x] 3.1 八種組合（zsh、bash × homebrew、system、GNU、bfs）全過；既有 19 段指令與 main 逐段相同。
- [x] 3.2 `spectra validate` 通過；`pytest tests/` 通過。
