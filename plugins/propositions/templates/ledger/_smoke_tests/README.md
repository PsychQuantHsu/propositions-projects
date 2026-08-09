# _smoke_tests — 本稿專屬最小 fixture

放**這篇稿件自己的**最小可驗證案例（幾行 tex + 對應 jsonl + meta），用途：

1. **升級保險**：plugin / validator 升版時，先對這裡的小 fixture 跑 Operation A，
   確認行為沒變，再跑全量 ledger。
2. **回歸釘點**：踩過的坑（某個 normalize 邊界、某種環境結構）縮成 fixture 釘住，
   讓它永遠不會靜默回歸。

命名慣例：`<case>.tex` + `<case>.jsonl` + `<case>_meta.json` 三件一組
（`<stem>_meta.json` 是 validator 認得的 fixture sidecar 形式）。

Scaffold 時此目錄刻意為空——fixture 應該來自這篇稿件真實踩過的案例，
不是預先假想的。參考：Hsu case 的 `_smoke_tests/`（rollback_60 系列）。
