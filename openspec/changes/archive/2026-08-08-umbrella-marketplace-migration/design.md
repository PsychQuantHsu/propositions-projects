## Context

本 repo（`PsychQuantHsu/propositions`）現為 single-plugin marketplace：根層 `.claude-plugin/plugin.json` + `marketplace.json`（name `propositions`、單一 `source: "./"` entry）。同一套 validator/audit scripts 在 psychquant-claude-plugins 的 `plugins/math-tools/` 有人工鏡像（HEAD byte-identical、發佈版 skew：CI pin v0.1.1 vs 安裝端 0.5.0）。math-tools 的四個 skills（clarity-audit / proofread / manuscript-audit / propositions）皆為通用 manuscript-QA、無一 math-specific。scaffold（`a24c54b`、`637b9f1`）已放好 `plugins/` 佈局的 placeholder 與 `docs/MIGRATION-propositions-projects.md`。

利害關係方：安裝端使用者（marketplace 註冊 + plugin 安裝）、下游 manuscript repo 的 CI（以 tag pin checkout 本 repo 根層 scripts）、psychquant-claude-plugins maintainer（同一人）。

時序前置：#1（retired-field 支援 → tag v0.1.2 → 下游 pin bump）先於「舊 pin 退場」；但本 change 的佈局工作不受 pin 凍結影響（pin 是 tag snapshot，HEAD 變動不影響已 pin 的 CI）。

## Goals / Non-Goals

**Goals**

- 工具鏈單一源頭：scripts/skills 唯一實體住 `plugins/propositions/`，根層以 shim 維持 CI 入口契約
- marketplace 升級為 umbrella 結構（`propositions-projects`、`plugins/<name>` entries），目前收斂為單一 core entry `propositions`（見 D6）
- repo 改名 `propositions-projects`，與 marketplace / 本地目錄名對齊
- 給跨 repo 協調動作（deprecation、pin bump）產出明確清單與時序

**Non-Goals**

- 不在本 change 內執行 psychquant-claude-plugins 或下游 repo 的改動（該兩 repo 的 edits 由 #2 task list 協調、各自 repo 執行）
- 不實作任何新領域 profile（psych / prose）——本 change 只建結構位置（見 #2 Residue）
- 不動 validator 行為（retired-field 支援屬 #1 / #118 / #119，另行實作）
- 不遷移 SCHEMA.md 進 repo（spec 跟 ledger 資料走；本 repo 只宣告支援區間）

## Decisions

### D1 — 根層 CI 入口用「轉呼叫 shim」而非 symlink 或雙實體

`run-audit.sh` / `validate-propositions.py` 等唯一實體移入 `plugins/propositions/scripts/`；根層同名檔改為 2-3 行轉呼叫 shim（`exec "$(dirname "$0")/../plugins/propositions/scripts/<name>" "$@"` 形式；Python 檔用 runpy 轉呼叫）。理由：(a) 消滅雙實體（本 change 的存在理由）；(b) symlink 在 GitHub tarball / actions checkout 情境跨平台行為不一；(c) shim 讓既有 pin 路徑契約（`propositions-plugin/scripts/run-audit.sh`）在未來每個 tag 都成立。`tests/`（實作時定案）：測試套件**留在根層 tests/ 作為唯一實體**，不複製進 plugin——安裝端 plugin 不需要帶 tests，而根層套件以 subprocess 呼叫根層 scripts/ 時自然行經 shim 層，等於每次全套測試都端到端驗證 pinned contract；source-inspection / import 類測試另設 IMPL 常數直指 core 實作。否決 forwarding conftest / 星號 re-export：pytest 的 conftest 發現是目錄制，跨目錄轉發會失去 fixture 可見性、机制脆弱。驗收標準：根層 `pytest tests/` 全綠（143+ passed，含 shim 煙霧測試）。

### D2 — marketplace rename 的既註冊使用者語意：實測後定 README 遷移文案

風險（#2 Risk 1）：已用舊 URL / 舊 name 註冊 marketplace 的使用者，改名後 `claude plugin marketplace update` 是否跟隨。GitHub repo redirect 會讓 git fetch 繼續動，但 marketplace 的顯示名與 install 座標（`plugin@marketplace-name`）改變。處置：實作階段以本機第二註冊做 probe（tasks 內列驗證步驟），兩種結果各有預案——(a) update 可跟隨：README 只記名稱變更；(b) 不可跟隨：README 記 `claude plugin marketplace remove propositions` + `add PsychQuantHsu/propositions-projects` 一次性遷移指令。文案落在 README「Migration notes」段。

### D3 — 撞名時序：先 parity、後 deprecation、most-late GA

風險（#2 Risk 2）：過渡期使用者同時裝著舊 math-tools（含 propositions skills 鏡像）與新 propositions plugin → 同名 skills 並存。時序防護：(1) 本 change 完成 = 新 plugin 達 parity（skills + scripts 齊）但**不**主動宣告 GA；(2) psychquant-claude-plugins 端換 deprecation pointer（跨 repo 動作，#2 協調）；(3) README 遷移文案明示「install propositions 前先 uninstall math-tools 或於 install 後移除舊 plugin」。本 repo 可做的部分 = README 文案 + coordinated-change 清單；時序執行本身在 #2。

### D4 — 改名時點：本 change 末端、單一 commit 窗口

`gh repo rename` 放在佈局 + manifest 都落地並驗證後的最後一步，同一時窗內完成：rename → 本地 remote URL 更新 → README/MIGRATION doc 內 URL 更新 → push。理由：改名先行會讓 change 進行中所有文件 URL 兩頭跳；改名收尾則 redirect 只需掩護「舊 URL 的外部引用」單一方向。

### D5 — schema-range 宣告位置

`plugins/propositions/.claude-plugin/plugin.json` 的 description 內載明 supported ledger schema（≤ 1.5），並於 core plugin README 設「Schema compatibility」小節（表格：schema 版本 × validator 行為，含 v1.2+ / v1.4+ 條件規則）。不建 machine-readable 欄位（Claude plugin manifest 無此 schema 擴充點；README 表格是人讀的正確層）。

### D6 — 核心 plugin 定名 `propositions`，marketplace 收斂為單一 entry

scaffold 階段建了 `plugins/math-tools/`（v0.0.1、僅 manifest + README、零 skill 零 script），意圖是「日後放 math-only 內容」。實作完成後回頭檢驗：**它通過刪除測試**——刪掉不會有任何功能消失，而留著會讓遷移過來的使用者裝到一個空 plugin 並合理地判定「這東西壞了」。決定移除該目錄，marketplace 只保留 `propositions` 一個 entry。

連帶確認核心 plugin 定名 `propositions`（而非沿用來源端的 `math-tools`），理由由強到弱：

1. **名實相符**：移植的四個 skills（clarity-audit / proofread / manuscript-audit / propositions）皆為 domain-general manuscript-QA、無一 math-specific（本文件 Context 段已載明）。核心資產是 proposition ledger 與 `main.tex` 之間的 falsifiable 雙向對應，與數學無關。
2. **命名即收錄邊界**：`propositions` 提供可判定的準則——不涉及 proposition ledger 的內容不進 core；`math-tools` 對任何沾邊的東西都說得通，會讓 core 逐步稀釋成雜物袋。這是本決策的主要理由，不是美學偏好。
3. **三層座標對齊**：repo `propositions-projects` / marketplace `propositions-projects` / core plugin `propositions`。若 core 命名 `math-tools`，會產生 `propositions-projects/math-tools` 的內部矛盾。
4. **保留名稱給真正需要的內容**：未來 sympy substitution 驗證、Lean bridging 落地時再建 `plugins/math-tools/`，屆時名稱名實相符。

**接受的代價**：`propositions:proofread` 的讀感略遜於 `math-tools:proofread`（前者是資料名 + 動作名的組合）。判定為可接受——plugin 名不必與每個 skill 的動詞搭配。

**否決的替代**：(a) 留空殼但標記 experimental——空 plugin 對安裝端沒有「實驗」可言，只有壞掉；(b) 把 math-tools 當 core 命名——違反上述 1、2；(c) 現在就把 sympy/Lean 內容補進去湊實——超出本 change 範圍，且該內容尚未設計。

## Risks / Trade-offs

- **R1 marketplace rename 語意未實測**（D2 處置：probe 先行、雙預案文案）
- **R2 shim 的 argv/exit-code 透明性**：shim 必須逐位元轉遞 stdout/exit code（CI gate 解析 report 依賴）；tasks 內以既有 pytest suite + 一個 shim 煙霧測試把關
- **R3 pin 凍結窗口**：v0.1.1（舊佈局）與未來 vNext（新佈局）之間不得插入「根層 scripts 缺席」的 tag——D1 的 shim 讓根層路徑永久有效，結構上消除此風險
- **R4 redirect 依賴**：改名後外部 pin `repository: PsychQuantHsu/propositions` 靠 redirect 存活；#2 task list 已含顯式更新，redirect 僅為過渡保險
- **R5 安裝端 skew（實測已發生）**：maintainer 本機 `~/.claude/plugins/cache/` 內存有 psychquant-claude-plugins 的 math-tools 0.2.0–0.5.0，`propositions-projects` marketplace 未註冊，且已安裝的 `rules/manuscript-consistency-audit.md` 缺 #103 framework-aware boundary detection 段——亦即 repo 端佈局已完成，安裝端仍在跑落後版 rules。這與 proposal `Why` 所述的 CI pin skew 是同一失敗模式的另一面（CI 端 vs 安裝端）。處置：本 change 收尾加入安裝端切換驗證（tasks 5.4），把「repo 完成」與「實際可用」分開驗收



## Migration Plan

1. 佈局搬移（D1）＋ pytest 全綠（根層與 core 兩跑法）
2. manifest 升級（marketplace name + 單一 core entry `./plugins/propositions`；空殼 pack 依 D6 移除）＋ D5 schema-range 宣告
3. D2 probe ＋ README Migration notes / coordinated-change 清單（含 D3 時序）
4. D4 repo rename ＋ URL 收尾 ＋ release-flow 文件
5. 跨 repo 執行（psychquant-claude-plugins deprecation、下游 pin bump）＝ #2 協調、不在本 change

## Open Questions

- (none 阻斷性；D2 的 probe 結果決定文案分支，已含雙預案)
