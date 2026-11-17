## 1. 三項擋下

- [x] 1.1 引入規則退回清單比對，對應 Requirement「Derive and draft build an outline without inventing content」與第八輪第 1、3 列。完成時：`x` 以 `.tex` 結尾時指 `x`，否則指 `x.tex`，從主檔的目錄算起，是清單上的一行才讀，不在別處找；三份文字一致。驗證：agent 反推一份用 `\include{chapters/ch1.tex}` 的稿件，讀到 `chapters/ch1.tex`。
  - 一位只拿到 SKILL.md 與 OUTLINE.md 的 agent 對 `9820c56` 反推一份用 `\include{chapters/ch1.tex}` 的稿件：讀到 `manuscript/chapters/ch1.tex`（清單第 2 行），每段指令都印 `ok`，做到第 8 步。
- [x] 1.2 確認第 2 步不因 `EMPTY` 停下，對應第八輪第 2 列。完成時：段落檔印 `EMPTY` 時走到第 3 步。驗證：agent 確認一份只有節的綱要，走到展示並記下確認。
  - 同一位 agent 確認一份只有兩節、段落檔是空的綱要：段落檔的寫入檢查印 `EMPTY`，照第 2 步走到第 3 步，狀態印 `ok status`。第 3 步要啟動 `propositions:outline-checker`，這個 session 安裝的 plugin 版本沒有它，照 skill 停下、沒有記下確認；第 4 步以後這一輪沒有改，這次沒有跑到。

## 2. 驗證

- [x] 2.1 19 段指令與 `aa8a63d` 逐段相同。
  - 19 段與 `aa8a63d` 逐段相同（`9820c56`）。
- [x] 2.2 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
  - `pytest tests/`：872 passed、3 skipped；`spectra validate` 通過、`spectra analyze` 沒有 warning；三個目錄相對於 main 沒有變動。
