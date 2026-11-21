# 實作語言是 Swift：這個 repo 的工具要完全用 Swift 寫

使用者 2026-11-04（+08:00）定調：「我的這些工具想要完全用swift做，跟akashic lib一樣， 可以家入.claude/rules」。
當時 #33 剛合併，又多了三支 Python 工具和第一個外部依賴 PyYAML。

**現況（2026-11-20 量）**：根目錄有一個 Swift package（#46）：`PropositionsKit`、`propositions`、`tschema-check`
與測試 target，共 31 個 Swift 檔。裡面有五組：引用方向（`propositions cite-order`，#46）、綱要三個檔的格式、狀態、
來源指標（`propositions outline check`、`status`、`locators`，#78），以及帳冊的行序（`propositions ledger-order`，#59，
`reorder-ledger.py` 的移植）、段落清單（`propositions paragraphs`，#77，`derive-paragraphs.py` 的移植）與兩支稽核（`propositions audit symbols`、
`citations`，#69，`audit-symbols.py`、`audit-citations.py` 的後繼）。維護者 2026-11-21 決定這幾支的 Python 版退役、
改成引導使用者改用 Swift 版；退役與 skill 的切換在帶這些子命令的 binary 發布之後一起做。發布過的 binary（`propositions-cli-v0.1.0`）只有前者；
propositions plugin 在 session 開始時用 hook 取得鎖定版本的 binary（只有 macOS；`hooks/fetch-cli.sh`，#46），
`/propositions:propositions` 的 Operation A 經由 `hooks/run-cli.sh` 呼叫 `cite-order`；綱要的三個子命令還沒有 skill 呼叫（#102）。
其餘受追蹤的可執行程式碼是 72 個 Python 檔、6 個 shell 檔，
另外有 3 段寫在 SKILL.md 裡的 Python 程式（見〈既有檔〉）。skill 用 `python3 "$VALIDATOR"` 這類寫法呼叫
plugin 內的腳本，所以使用者端要有 Python 3.10 以上；帳冊附檔用到 `move`／`type` 時還要裝 PyYAML。

**目標**：和 Akashic-Library 一樣，本體是 repo 根目錄的一個 Swift package。library `PropositionsKit`
放帳冊與附檔的型別、讀寫和各條檢查規則；executable `propositions` 是 CLI，skill 直接呼叫它的子命令；
`tschema-check` 是另一個 executable。既有的 Python 依〈移植〉換成 Swift，最後全部刪除。

## 什麼算可執行程式碼

這是封閉列舉，只有兩類。

1. **原始碼檔**：`.py`、`.sh`、`.swift`，以及任何沒有副檔名但帶 shebang 的檔。
2. **寫在 SKILL.md 或文件裡、交給直譯器執行的程式本體**：`python3 - <<'PY' … PY` 這種 heredoc、
   `python3 -c '…'`、餵給 `bash`、`sh` 的 heredoc、寫在 SKILL.md 裡交給 `jq` 的程式（`jq '…'` 引號裡
   的部分），以及〈例外〉第 4 類點名的那份 SKILL.md 的指令區塊，整個區塊都算。寫在其他文件裡的 jq 篩選式
   （例如 `docs/RELEASE-FLOW.md` 讀版本號的那兩行）是〈不適用〉第 1 類的指令列。

只呼叫一個現成工具、帶參數（可以接 pipe 或重新導向）的指令列不算，見〈不適用〉第 1 類。

## 規則

**新增的可執行程式碼一律寫成 Swift，並放進下表其中一處。** 下表是封閉列舉，只有四列。遇到表裡沒有的
情形，先在本檔加一列並寫明理由，不要從既有列推導。

| 要寫的東西 | 放在哪裡 | 理由 |
|---|---|---|
| 帳冊與附檔的型別、讀寫、`normalize`，以及各條檢查規則（R1–R13、S1–S9、驗證紀錄） | library target `PropositionsKit` | 每條規則只有一份實作，CLI 子命令和測試都用它 |
| skill 需要的確定性計算（驗證、行號定位、抽取前後的檢查、結構查詢、目錄產生、量測、給使用者的摘要） | `propositions` CLI 的子命令，skill 用指令呼叫 | skill 裡不再寫程式；使用者端不需要 Python |
| `tschema-check` 的驗證 | 同一個 package 裡另一個 executable product `tschema-check` | 兩個 plugin 安裝後彼此隔離，各自下載各自的 binary；共用的程式碼在建置時連結，不在執行時跨 plugin 讀取 |
| 測試，含 repo 層級的守衛（marketplace 條目、plugin 內容有沒有被追蹤這一類） | Swift Testing target，放在 `tests/PropositionsKitTests/`（`Package.swift` 明寫路徑：repo 已有小寫的 `tests/`，在不分大小寫的檔案系統上另開 `Tests/` 會是同一個目錄） | 測試和被測程式用同一個 toolchain，版本不會歪斜 |

repo 根目錄的 `Package.swift` 宣告了上表的 targets（#46 建立）；不要在 plugin 目錄或其他位置另建 package。
`tschema-check` 這個 executable 目前只回報版本，驗證還在 Python 腳本裡。

## 例外：可以不是 Swift 的程式碼

這是封閉列舉，只有四類，不得依性質相似類推出第五類。

1. **Swift binary 還不存在、或使用端沒有 binary 時才需要的殼層。** 這一類只有三種：
   - plugin 取得並啟動 binary 的殼層：propositions plugin 的 `hooks/fetch-cli.sh`（SessionStart hook）與
     `hooks/run-cli.sh`（skill 經由它呼叫 binary），做法見本條末段。
     **不要照抄 Akashic-Library 把它放進 plugin 的 `bin/`**；
   - 編排 `codesign`、`notarytool` 的 release 腳本，照 Akashic-Library 的 `scripts/release-signed.sh` 寫；
   - 根目錄 `scripts/` 的轉接層，但只限於使用者依〈移植〉第 6 步決定保留它們之後，改寫成只取得並呼叫
     binary 的版本。

   **它們只做串接**：檢查 binary 在不在、下載、依序呼叫外部 CLI。裡面一旦出現領域判斷，就把它移進
   Swift。目前這一類有 3 個檔：`scripts/release-signed.sh`（簽章發布，只由維護者執行），以及
   `plugins/propositions/hooks/` 的 `fetch-cli.sh` 與 `run-cli.sh`。用 SessionStart hook 取得 binary 是維護者
   2026-11-20 定的；細節是實作時取的：`fetch-cli.sh` 在 session 開始時把 `hooks/cli.lock` 鎖定的那一版下載到
   plugin 的資料目錄（`CLAUDE_PLUGIN_DATA` 底下的 `bin/`，檔名帶鎖定的 SHA-256，每一版一個路徑；不是 plugin 目錄的 `bin/`：plugin 的目錄一旦有 `bin/`，
   claude.ai 與 Cowork 就不安裝這個 plugin，裡面的檔還會出現在 Bash 工具的 PATH 上），下載的檔要同時有鎖定的
   SHA-256 與鎖定那個 Team 的 Developer ID 簽章才安裝。`run-cli.sh` 每次執行前再比對一次 SHA-256，只執行鎖定的
   那一版；其他情形印出 `propositions: NOT RUN` 並以 3 結束，skill 把那一項回報成沒有檢查。skill 裡因此只有一行
   呼叫 `run-cli.sh` 的指令列（〈不適用〉第 1 類）。
2. **本規則成文前就已存在的程式碼（grandfathered）**，逐項列在下方〈既有檔〉。
   - 可以修 bug，也可以做不改變行為的小改，例如改訊息字句、補註解、重新命名區域變數。
   - 不得在它們旁邊新增同類檔案，也不得加入下列任何一種新功能。這是封閉列舉，只有四種：
     (a) 新的腳本、子命令或模式；(b) 新的命令列參數；(c) 新的輸出欄位或輸出格式；(d) 新的檢查規則。
     要加這四種之一時，先依〈移植〉把那個功能所在的模組移植成 Swift，再在 Swift 版上加。
   - 修 bug 時要補的回歸測試，加進已經涵蓋那支腳本的 pytest 檔。沒有任何 pytest 檔涵蓋它時（目前
     `reorder-ledger.py`、`structure-batch.py` 的案例在 `test_structure_tools.py`），加進最接近的那一個；
     不要為了它新建 `test_*.py`。
3. **指名的守衛測試，在它讀的詞彙在 Swift 裡有來源之前。** 這是封閉清單，目前只有一組：
   - `tests/test_plugin_payload_tracked.py` 裡名稱以 `test_obligations_` 開頭的案例（義務表的守衛，#47）。
     它檢查的是 `plugins/propositions/catalog/obligations.yaml` 與
     `plugins/propositions/docs/OBLIGATIONS.md` 的內容，以及 `plugins/propositions/docs/VERIFICATION.md`
     的三個字句（一個指到義務表文件，兩個限縮它自己的說法），不是任何腳本的行為。

   清單裡的這一組可以修改，也可以在同一組裡加案例；不新建 `test_*.py`，不新增腳本或 `_lib` 模組。
   要把別的守衛加進這份清單，先在這裡加一列、寫明它檢查哪些檔，並由維護者決定。不得因為「它也是檢查
   資料檔的守衛」就比照辦理。

   **退場條件**：守衛讀的詞彙在 Swift 裡有了來源之後（package 已由 #46 建好，詞彙還沒有），把這一組連同
   `spec-example:` 標記搬到 `tests/PropositionsKitTests/` 的 Swift Testing target，然後刪掉這一條例外。現在不寫成 Swift 的原因
   是守衛直接從 Python 的驗證器讀詞彙（`PROFILE_VOCABULARIES`、`KINDS`、`ROLES`、`METHODS`）；驗證器移植之前，
   Swift 版只能另抄一份，抄的那一份不會跟著驗證器更新。
4. **指名的 skill 的指令區塊，在命令列工具涵蓋它們的工作之前。** 這是封閉清單，目前只有一份：
   - `plugins/propositions/skills/outline/SKILL.md` 的指令區塊（#75），整個區塊都算：交給 `jq` 執行的程式，
     以及同一個區塊裡把 `jq`、`git`、`realpath`、`find` 這些現成工具接起來的 shell 指令。它們做這些事：
     找出 repo 的根目錄並建立暫存目錄、檢查主稿件、每次呼叫開頭的守門、列出帳冊並比對帳冊指到哪一份稿件、
     確認還沒有綱要檔、三個綱要檔的寫入檢查、來源指標的列舉與計數、指向另一份綱要的參照的列舉與確認（#92）、列出可讀的 `.tex` 檔、
     決定 root 是綱要目錄所在的 repository（#91）、把暫存的綱要檔寫進綱要目錄、顯示綱要目錄、使用中的 id、狀態與差異、
     保留展示給作者的副本並記下展示了哪些節、確認紀錄的組裝與追加前的檢查。這 16 項涵蓋那份 SKILL.md 現有的
     22 段指令。

   清單裡的這一份可以修改，也可以在同一個 SKILL.md 裡加指令區塊；不得在別的 skill 或文件裡比照新增，
   也不得改寫成 Python、shell 的 heredoc、另外的腳本檔或其他直譯器的程式。要把別的 skill 加進這份清單，
   先在這裡加一列、寫明它的指令做什麼，並由維護者決定。不得因為「它也是 skill 裡的 jq」或「它也只是把
   幾個工具接起來」就比照辦理。

   **退場條件**：`propositions` CLI 的子命令涵蓋上面列的每一項工作之後，把這份 SKILL.md 的指令區塊換成
   呼叫子命令，然後刪掉這一條例外。#78 做的是寫入檢查、來源指標與狀態三項；其餘幾項還沒有子命令時，
   那幾項照這一條留著，這一條也留著。現在 skill 還不呼叫子命令的原因有兩個：plugin 鎖定的 binary（0.1.0）沒有
   綱要的子命令，而且 16 項裡只有 3 項有子命令（#102）；在那之前，skill 的確定性檢查只能交給使用者機器上已有的工具。

## 不適用

這也是封閉列舉，只有四類。

1. **SKILL.md 和文件裡的指令列**，也就是呼叫一個現成工具（`propositions`、`gh`、`latexmk` 這類）、
   帶參數、可以接 pipe 或重新導向的一行指令。〈什麼算可執行程式碼〉第 2 類的程式本體不屬於這一類。
2. **被呼叫的外部工具本身**：它們用什麼語言寫，不歸本 repo 管。
3. **使用者稿件 repo 裡的檔案**：帳冊、附檔、稿件自己的 smoke test 與 CI 設定都留在各稿件 repo。
   本 repo 根目錄 `scripts/` 的轉接層受本 repo 追蹤，不屬於這一類，列在〈既有檔〉。
4. **不 commit 的一次性量測腳本**：放在暫存目錄，量完就丟。要留下來重跑的（像 `structure-metrics.py`
   那種量測）不算一次性，照〈規則〉的表寫成 Swift。

## 移植

把既有 Python 換成 Swift 時，照下面六步做，順序固定。

1. **決定範圍，依賴先移植。** 一次移植的單位是一個模組（一支腳本連同它用到的 `_lib` 函式），加上
   它依賴、但還沒移植的其他模組。腳本之間有用 importlib 互相載入的情形（2026-11-04 量）：
   - `validate-propositions.py` 被 `refresh-prop-locations.py`、`validate-verification.py`、
     `proofread-to-verification.py` 載入；
   - `validate-structure.py` 被 `structure-state.py` 載入；
   - `structure-state.py` 被 `structure-explain.py`、`structure-links.py`、`structure-metrics.py`、
     `build-link-catalog.py` 載入；
   - `derive-paragraphs.py` 被 `migrate-structure-v2.py` 載入；
   - `_lib/latex_env_parser.py` 被七支腳本使用，`_lib/structure_tree.py` 被六支腳本使用。

   動手前用 `grep -n importlib` 與 `_lib` 的 import 重新量一次，上面這份清單會過期。
2. **輸出一致才換。** 用同一組輸入比對兩個版本，輸入是 `tests/fixtures/` 與兩篇參考稿件的帳冊和附檔：
   - 寫出的檔案要**逐位元組相同**。帳冊和附檔都在稿件 repo 裡受 git 追蹤，換一種 JSON 跳脫或鍵的
     順序，下一次寫入就會讓整份檔案出現在 diff 裡。
   - 輸出裡含時間或亂數的欄位（`assign-prop-ids.py` 產生的 UUID v7、`proofread-to-verification.py` 的
     `--checked-at` 預設值），兩版用同一個固定值跑；Python 版無法固定的，比對時只遮蔽那些欄位，
     其餘位元組仍要相同。
   - stdout 與結束碼要相同。swift-argument-parser 的用法錯誤預設結束碼是 64，argparse 是 2，要改成
     和 Python 版相同；做不到的列為刻意差異，並在同一個變更裡改掉所有判讀那個結束碼的呼叫端。
   - 參考稿件在作者的私有 repo，位置不寫進這個公開 repo；需要時問使用者。
   - 刻意的差異逐條列在該次的 issue。
3. **先發布，再換呼叫端。** 還沒有 release 時，先依〈例外〉第 1 類建立發布腳本；plugin 怎麼取得 binary
   照〈例外〉第 1 類末段：SessionStart hook 取得 `hooks/cli.lock` 鎖定的那一版，skill 經由 `hooks/run-cli.sh` 呼叫；
   不在 plugin 的目錄放 `bin/`。發布之後要在同一個 plugin 變更裡改 `cli.lock`，plugin 才會換用新的 binary。發布簽過章的
   release 會讓檔案離開這台電腦，依全域 `CLAUDE.md`〈不可逆的事 Claude 不自己做〉，先列 operation
   格式等使用者確認。發布後用 plugin 實際取得的那份 binary 跑一次要切換的 skill。
4. **同一個變更改掉所有指向舊 `.py` 的地方**：skill（含 SKILL.md 裡的程式區塊）、`plugins/*/rules/`
   這些隨 plugin 出貨的規則、`docs/`、`openspec/specs/`、`CLAUDE.md`、README。
5. **沒有人再載入它，才刪 Python 版。** 只要還有任何剩下的 Python 程式（腳本、`_lib`、SKILL.md 裡的
   程式區塊、根目錄轉接層）載入它，Python 版就留著並且凍結：只修 bug，修 bug 時 Swift 版一起修，
   兩版靠第 2 步的比對保持一致。刪除時只刪針對它的測試案例；`test_multifile_support.py`、
   `test_structure_tools.py`、`test_root_shims.py` 這類同時涵蓋多支腳本的檔，保留其他案例。
   刪完從〈既有檔〉拿掉。
6. **根目錄 `scripts/` 轉接層的去留由使用者決定。** 那是稿件 repo 的 CI 釘住的入口，稿件 repo 的 CI
   環境裡沒有 binary，改動會影響別的 repo。移植對應的腳本時，列出兩個選項（改寫成只取得並呼叫
   binary 的轉接層，或公告退場與期限）給使用者選；不能留下一個指向已刪除檔案的轉接層。

## 寫 Swift 之前

- 依全域 `CLAUDE.md`〈Swift / Apple App 開發〉，寫或改 `.swift`、`Package.swift` 之前，先載入
  apple-xcode-skills 裡對應的 skill。測試用 Swift Testing，從 XCTest 的寫法轉換時看
  `apple-xcode-skills:test-modernizer`。
- 外部套件比照 AkashicKit：YAML 用 Yams，命令列用 swift-argument-parser。
- binary 隨 GitHub release 發布，簽章並 notarize（`scripts/release-signed.sh`，流程見 `docs/RELEASE-FLOW.md`）。
  plugin 用 SessionStart hook 取得鎖定的版本，不照 Akashic-Library 放 `bin/`（〈例外〉第 1 類末段）；發布新的
  binary 之後要改 `hooks/cli.lock` 的版本與 SHA-256，plugin 才會換用它。
  `plugin.json` 的版本和 binary 的 release tag 分開記，原因見 Akashic-Library #275：只改 plugin 外殼時
  也會升版本，但那個版本並沒有對應的 release。

## 既有檔（grandfathered，2026-11-04 用 `git ls-files` 量，只計受追蹤的檔）

**propositions plugin 的腳本（23 個）**，都在 `plugins/propositions/scripts/`：
`assign-prop-ids.py`、`audit-{citations,code-manuscript,symbols,theorem-boundaries}.py`、
`build-link-catalog.py`、`check-extraction-coverage.py`、`derive-paragraphs.py`、
`migrate-{json-to-jsonl,prop-id-to-uuid,structure-v2}.py`、`proofread-to-verification.py`、
`refresh-prop-locations.py`、`reorder-ledger.py`、`run-audit.sh`、
`structure-{batch,explain,links,metrics,state}.py`、
`validate-{propositions,structure,verification}.py`

**propositions plugin 的共用函式（7 個）**，都在 `plugins/propositions/scripts/_lib/`：
`latex_env_parser.py`、`link_catalog.py`、`move_metrics.py`、`move_vocabulary.py`、`normalize.py`、
`structure_io.py`、`structure_tree.py`

**SKILL.md 裡的 Python 程式區塊（3 段）**，以所在步驟指名，不用行號：
- `plugins/propositions/skills/extract/SKILL.md` 的 Step 2「Stop if the range is already extracted」
- `plugins/propositions/skills/extract/SKILL.md` 的 Step 9「Validate a merged copy」
- `plugins/propositions/skills/construct/SKILL.md` 的 A5「Summary for the user」

**tschema-check plugin（1 個）**：`plugins/tschema-check/scripts/validate-tschema.py`

**根目錄轉接層（9 個）**，都在 `scripts/`：
`audit-{citations,code-manuscript,symbols,theorem-boundaries}.py`、`migrate-{json-to-jsonl,prop-id-to-uuid}.py`、
`refresh-prop-locations.py`、`run-audit.sh`、`validate-propositions.py`

**測試（35 個）**，都在 `tests/`：
`conftest.py`、`link_case.py`、`structure_case.py`、`test_run_audit.sh`，以及下列 31 個 `test_*.py`：
`assign_prop_ids`、`audit_citations`、`audit_code_manuscript`、`audit_symbols`、`audit_theorem_boundaries`、
`build_link_catalog`、`check_extraction_coverage`、`derive_paragraphs`、`ledger_profiles`、
`lib_latex_env_parser`、`lib_normalize`、`marketplace_entries`、`migrate_json_to_jsonl`、
`migrate_prop_id_to_uuid`、`migrate_structure`、`move_vocabulary`、`multifile_support`、
`plugin_payload_tracked`、`r15_multifile_coverage`、`refresh_prop_locations`、`retired_field`、`root_shims`、
`structure_explain`、`structure_links`、`structure_metrics`、`structure_state`、`structure_tools`、
`tschema_check`、`validate_propositions`、`validate_structure`、`verification_records`

這張清單只減不增：移植成 Swift 或刪除時，從這裡拿掉；新的程式碼不得加進來。

## 為什麼

1. **和 Akashic-Library 用同一套做法。** Akashic 的本體（AkashicKit、`akashic` CLI、`akashic-mcp`、
   守衛）都是 Swift。兩個 repo 用同一套 toolchain、同一條簽章與發布流程，在一邊學到的做法可以直接
   用到另一邊。
2. **使用者端不必準備 Python 環境。** 現在每次呼叫 skill，都是在使用者的機器上跑 `python3`：
   `CLAUDE.md` 標的相容版本是 3.10 以上；從 #33 起，用到 `move`、`type` 還要另外裝 PyYAML。本 repo 沒有
   CI，沒有任何機制確認這些腳本在別的 Python 版本上跑得動。簽過章的 binary 不需要這些前提。

## 觸發過的實例

| 日期 | 實例 | 處置 |
|---|---|---|
| 2026-11-04 | #33 新增三支 Python 工具（`structure-explain.py`、`structure-links.py`、`build-link-catalog.py`），並新增 PyYAML 依賴；合併後使用者說要和 Akashic 一樣完全用 Swift | 寫下本規則；#33 的檔案列入〈既有檔〉 |
| 2026-11-04 | 本規則第一版交給獨立讀者盲審，找到三個會讓照著做的人出錯的缺口：(1) SKILL.md 裡用 heredoc 寫的 Python 被當成「指令列」，可以照樣新增；(2) 移植步驟沒有考慮腳本之間互相載入，刪掉一支就弄壞三支；(3) 換呼叫端之前沒有發布 binary 這一步 | 加了〈什麼算可執行程式碼〉，〈移植〉改成依賴先移、先發布再換、沒人載入才刪；「新功能」改成封閉列舉。**不要把〈什麼算可執行程式碼〉簡化回「新增的檔案」**：缺口 (1) 就是那樣出現的 |
| 2026-11-12 | #47 的義務表守衛是加在既有 pytest 檔裡的 18 個 `test_obligations_` 函式。兩輪驗證都指出本檔沒有記這個例外，規格卻明文要求這樣做 | 維護者同意改規則（「如果需要swift的話也可以swift，幫我改規則」）：加〈例外〉第 3 類，退場條件是 #46。**不要把第 3 類改寫成用性質定義的一類**：#47 第三輪驗證指出第一版寫成「檢查資料檔與文件內容的守衛」，任何這種守衛都符合；現在是指名的清單，只有義務表這一組 |
| 2026-11-15 | #75 的 outline skill 把確定性檢查寫成 SKILL.md 裡的 `jq` 程式。第二輪驗證指出本檔沒有記這個例外，〈什麼算可執行程式碼〉也沒有列出 jq 程式 | 維護者選「記一條指名的例外」：〈什麼算可執行程式碼〉第 2 類加上 jq 程式，加〈例外〉第 4 類，退場條件是 #78。**不要把第 4 類改寫成「skill 裡的 jq 程式」這種性質**：理由同第 3 類那一列，是指名的清單 |
| 2026-11-16 | #75 第三輪驗證指出：第 2 類把文件裡的 jq 也算進來，`docs/RELEASE-FLOW.md` 既有的兩行因此不屬於任何類別；第 4 類的退場條件只涵蓋六段 jq 裡的三段；守門這類用 `&&` 串起幾個工具的檢查列不屬於任何一類 | 第 2 類的 jq 只算 SKILL.md 裡的；退場條件改成子命令涵蓋每一段之後；〈不適用〉第 1 類當時加了一份指令列可以用的接法清單，2026-11-17 退回（見下一列） |
| 2026-11-17 | #75 第四輪驗證指出：2026-11-16 加在〈不適用〉第 1 類的接法清單對整個 repo 都適用，超出 2026-11-15「記一條指名的例外」的決定，也沒有另外的決定；清單用寫法劃界（`[ x ] && a \|\| b` 就是 `if`／`else`），照它自己的標準也沒有涵蓋 outline 用到的參數展開；第 4 類的標題仍說到 #78 為止 | 維護者選「退回，併入例外第 4 類」：〈不適用〉第 1 類退回原本的字句；第 4 類改成點名那份 SKILL.md 的指令區塊（jq 程式與同一區塊的 shell 指令），標題改成與退場條件一致。**不要用接法或寫法的清單去界定什麼是指令列**：2026-11-16 那一次就是這樣超出範圍的。其他 skill 裡既有的 `for`、`if` 與子 shell 不屬於任何一類，另記在 #86 |
| 2026-11-17 | #75 第五輪驗證指出：第 4 類說整個指令區塊都算，接著列的 12 項工作卻漏了三段（確認還沒有綱要檔、顯示綱要目錄、記下展示了哪些節），退場條件依這份清單，於是那三段沒有退場條件 | 清單補成 14 項，對那份 SKILL.md 的 19 段指令逐段對過。**清單要跟著指令區塊走**：在那份 SKILL.md 加一段指令時，同一個變更裡把它做的事加進清單 |
| 2026-11-19 | 本檔原本要 plugin 的 wrapper 照 Akashic-Library 的 `plugin/bin/akashic-mcp-wrapper.sh` 寫。#46 照做之後，驗證查到 Claude Code 的 plugin 文件：plugin 目錄有 `bin/` 時 claude.ai 與 Cowork 不安裝這個 plugin，裡面的檔還會出現在 Bash 工具的 PATH 上 | 〈例外〉第 1 類、〈移植〉第 3 步、〈寫 Swift 之前〉三處改成「還沒有定、不放進 `bin/`」。這是實作時取的做法，維護者尚未確認，第一次發布時決定。Akashic-Library 的 wrapper 由 `.mcp.json` 呼叫、後面有已發布的 binary，情形不同 |
| 2026-11-19 | #46 建立 Swift package 與第一條 Swift 檢查（引用方向）。有三件事因此在 Python 與 Swift 各寫了一份：判斷 `retired` 區塊是否格式正確、讀 `location`、數稿件檔的行。#46 的驗證指出 Python 那邊讀稿件的函式彼此不一致（數行有 `splitlines` 與照換行切兩種，`main.tex:` 的意思 `parse_location_v16` 與 R15 相反），Swift 版第一次修正時照錯了對象 | **三件事各有一個對齊的對象**：`retired` 照驗證器的 `retired_problem`，`location` 照 `parse_location_v16`，數行照寫 `location` 的工具 `refresh-prop-locations.py` 的 `read_tex_lines`（行在 LF、CR、CRLF 結束）。`tests/PropositionsKitTests/ParityTests.swift` 直接載入這三個 Python 函式、拿同一組輸入餵兩邊比對，改其中一邊而另一邊沒跟上時會失敗；改這三個 Python 函式時同一個變更要改 `Sources/PropositionsKit/`。`\input` 樹 Swift 版用自己的規則讀（寫在規格 `citation-order`），不是 `resolve_input_tree` 的副本（#94） |
| 2026-11-20 | #46 的 binary 發布之後，維護者決定 plugin 用 SessionStart hook 取得它（「照你的建議，先做第 1 題」）。實作時的試跑把 binary 寫進了另一個 plugin 的資料目錄：shell 環境裡留著那個 plugin 的 `CLAUDE_PLUGIN_DATA` | 〈例外〉第 1 類改成現在的寫法。hook 只寫進名稱是 `propositions` 或以 `propositions-` 開頭的資料目錄，有測試。**skill 裡不要直接信任 shell 環境的 `CLAUDE_PLUGIN_DATA`**：Bash 工具的環境沒有這個 plugin 的值，有的話是別的 plugin 的；路徑要寫在 SKILL.md 的內文裡，由 Claude Code 載入時代換 |

## 語言組成（2026-11-20 量，只計受追蹤的檔）

Swift 31、Python 72、shell 6（其中 3 個是〈例外〉第 1 類的殼層），另有 SKILL.md 裡的 Python 程式區塊 3 段。量法是用 `git ls-files` 依副檔名
計數，再加上 `grep -n "<<'PY'"` 找到的程式區塊。這些數字會隨移植下降，引用時重新量，不要照抄這一行。
