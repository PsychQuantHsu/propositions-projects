## 1. 三項擋下

- [ ] 1.1 引入規則退回清單比對，對應 Requirement「Derive and draft build an outline without inventing content」與第八輪第 1、3 列。完成時：`x` 以 `.tex` 結尾時指 `x`，否則指 `x.tex`，從主檔的目錄算起，是清單上的一行才讀，不在別處找；三份文字一致。驗證：agent 反推一份用 `\include{chapters/ch1.tex}` 的稿件，讀到 `chapters/ch1.tex`。
- [ ] 1.2 確認第 2 步不因 `EMPTY` 停下，對應第八輪第 2 列。完成時：段落檔印 `EMPTY` 時走到第 3 步。驗證：agent 確認一份只有節的綱要，走到展示並記下確認。

## 2. 驗證

- [ ] 2.1 19 段指令與 `aa8a63d` 逐段相同。
- [ ] 2.2 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤；三個目錄相對於 main 沒有變動。
