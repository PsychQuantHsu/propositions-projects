## Context

`umbrella-marketplace-migration` 把 repo 改成 marketplace + `plugins/` monorepo 佈局，marketplace.json 宣告單一 entry `propositions` → `./plugins/propositions`。但該目錄下**只有 `scripts/` 進了版控**：`plugin.json`、`README.md`、四個 skill 全部被 `.gitignore` 的未錨定 `propositions/` pattern 擋下，而 `git add` 對被 ignore 的路徑是靜默跳過，因此整條遷移沒有出現任何錯誤訊息。`scripts/` 倖存純屬僥倖——它是 `git mv` 搬進來的，ignore 規則對已追蹤檔案無效。

現況因此是「本地工作目錄完整、遠端殘缺」。既有的 `tests/test_marketplace_entries.py` 檢查的是**檔案系統**是否有可安裝內容，所以它在本地一路綠燈，完全沒有攔到這個缺口。安裝端從 GitHub 解析 marketplace 時取不到 `plugin.json`，plugin 解析不出來；`umbrella-marketplace-migration` task 5.4 已因此被記為 BLOCKED。

診斷時另外查出三項同源缺陷（見 proposal）：根層三個 verb-named skill 是寫死改名前 cache 路徑的失效遺留、`proofread` 有 scaffolding 與完成版兩份分歧副本、四個 skill 共 19 處引用已不發佈的 `/math-tools:` 命名空間。這四件事同屬一個病灶——**published payload 與對外宣稱不一致，且沒有任何機械檢查在守**。

## Goals / Non-Goals

**Goals:**

- 讓 marketplace 宣告的 entry，其 payload（manifest + README + 全部 skill）完整存在於版控中，安裝端 clone 得到的東西與本地一致。
- 修掉根因（未錨定 ignore pattern），而不只是把檔案強制加入版控——後者會讓同一個坑在下次新增檔案時重開。
- 消除「同一個 skill 名稱有兩份實體」與「shipped 文件指向不存在的命令」這兩種對使用者可見的不一致。
- 補一道機械 gate，讓「payload 沒進版控」在 CI 就爆，而不是等安裝端回報。

**Non-Goals:**

- 不改任何 `plugins/propositions/scripts/` 下的 validator / audit 實作邏輯，也不動根層 `scripts/` 的 forwarding shim 路徑契約（那是 pinned CI contract，由 `tests/test_root_shims.py` 守著）。
- 不新增、不刪除任何 marketplace entry；`plugins/` 底下仍然只有 `propositions` 一個 plugin。
- 不改 skill 的執行語意（R1-R13 規則、dry-run 紀律、anchor_failed 行為一律原樣保留）。
- 不處理 `psychquant-claude-plugins` 側的 deprecation pointer 與下游 pin bump——那屬跨 repo 協調（#2），不在本 change。

## Decisions

### D1 — .gitignore 以前導斜線錨定根層 shim pattern

`.gitignore` 內 `propositions/` 與 `manuscript/` 兩條規則的意圖，都是擋 `tests/conftest.py` 在 repo 根層自動建立的 symlink shim。但 gitignore 的匹配語意是：pattern 若不含斜線、或斜線只出現在結尾，git 會拿它比對**任意深度**的路徑元件。因此 `propositions/` 同時吃掉了 `plugins/propositions/`。改寫為 `/propositions/` 與 `/manuscript/`，前導斜線把 pattern 錨定在 `.gitignore` 所在目錄（即 repo 根），意圖與效果一致。

考慮過但否決的替代方案：

- **刪掉 pattern，改靠 conftest 自行清理**——放棄防禦。conftest 舊版本留下的孤兒 symlink 正是這條規則當初存在的理由。
- **保留未錨定 pattern，另加 `!plugins/propositions/` 反向規則**——反向規則對「已被 ignore 的目錄底下的檔案」無效（git 不會遞迴進被排除的目錄），必須逐層 un-ignore，脆弱且反直覺。
- **強制加入版控（add 的 force 旗標）**——只治標。下次在 `plugins/propositions/` 新增檔案又會被靜默吞掉，且強制加入會讓「這個目錄其實被 ignore」這個事實繼續隱形。

### D2 — 根層三個 verb-named skill 退役，能力由 plugin 內 skill 承接

`skills/validate`、`skills/refresh-locations`、`skills/audit` 三者都以 `CLAUDE_PLUGIN_ROOT` 的 fallback 指向改名前的 cache 路徑 `~/.claude/plugins/cache/propositions`。marketplace 已改名 `propositions-projects`，安裝端的 cache 佈局是 `cache/<marketplace>/<plugin>/<version>/`，這條 fallback 路徑改名後不存在；同時根層 plugin manifest 已於前一 change 移除，這三個 skill 現在不屬於任何 manifest，`/propositions:validate` 這種呼叫形式根本無從解析。

移植進來的 plugin skill 已完整覆蓋：`propositions` 的 Operation A = validate、Operation B = refresh-locations（並多出 Operation C 抽取）、`manuscript-audit` = audit，且兩者都用改名後的 glob 形式解析版本目錄。因此正確動作是**退役**而非搬移——搬進 plugin 只會製造第二組同義入口。

此決定不弱化「不修 user 的 main.jsonl 不問」這條硬規則：Operation B 逐字保留 dry-run 先行、AskUserQuestion 確認後才寫、以及 anchor 不確定時回 `anchor_failed` 而非猜行號的 loud-failure 紀律。

### D3 — proofread 雙副本以 plugin 完成版為唯一實體

兩份 `proofread` 分歧：根層那份自述僅為 v0.1.0 scaffolding、執行本體標為待實作；plugin 內那份是完成版（L1-L5 六層程序、ROI 對照表、provenance 來源）。repo 追蹤的偏偏是 scaffolding 那份。合併方向取 plugin 版，刪除根層版——依專案的刪除測試，保留一份自述「執行本體未實作」的副本沒有任何東西會壞。

### D4 — skill 交互引用命名空間統一為 /propositions

四個 skill 內共 19 處以 `/math-tools:<skill>` 形式互相指路，那是移植前 `psychquant-claude-plugins` marketplace 的命名空間。前一 change 已移除 math-tools entry，README 亦明載本 marketplace 不發佈該 plugin。skill 的呼叫命名空間由所屬 plugin manifest 的 `name` 決定，本 repo 是 `propositions`，故全部改為 `/propositions:<skill>`；plugin README 內指涉 math-tools sibling pack 的過時句一併移除。

### D5 — payload 追蹤性測試斷言 git index 而非檔案系統

既有 `tests/test_marketplace_entries.py` 用檔案是否存在於磁碟來判斷 entry 有無可安裝內容，這正是它漏掉本次事故的原因——被 ignore 的檔案在磁碟上好端端存在。新測試改以 `git ls-files` 的輸出為判準，等同於「clone 下來會拿到什麼」。同時直接對每個 entry 的 source 目錄跑 `git check-ignore`，把「目錄被 ignore 但檔案被強制塞進版控」這種半殘狀態也擋掉。

考慮過但否決：**只在 CI 加一步未追蹤檔清單檢查**——雜訊太大（本地暫存檔一律誤報），且無法表達「哪些路徑*應該*被追蹤」這個意圖。

## Implementation Contract

#### 行為（ship 後可觀察到什麼）

- 從 GitHub clone 本 repo（或安裝端註冊此 marketplace）後，`plugins/propositions/` 底下取得完整 payload：plugin manifest、README、`scripts/`、以及四個 skill 目錄 `clarity-audit` / `manuscript-audit` / `proofread` / `propositions`，各自含 `SKILL.md`。
- repo 根層不再有 `skills/` 目錄；使用者從 README 與 CLAUDE.md 看到的可呼叫命令，與實際 ship 的 skill 一一對應。
- 任何 shipped skill 文字內不再出現 `/math-tools:` 形式的呼叫指示。

#### 介面 / 資料形狀

- `.gitignore`：兩條 pattern 由 `propositions/` / `manuscript/` 改為 `/propositions/` / `/manuscript/`，其餘規則不動。
- marketplace entry 的 payload 定義（測試據以判斷）：entry 的 `source` 相對路徑下的 plugin manifest，以及該目錄下所有 `skills/*/SKILL.md`。
- 掃描範圍（payload universe）：marketplace.json 每個 entry 的 `source` 目錄，聯集 repo 根層 `skills/` 目錄。`.agents/` 底下的 spectra harness skill **不屬於** payload universe，不參與重複名稱與孤兒檢查。
- 文件對照：README.md 的 Quick start 與 CLAUDE.md 的 skill 表格，列出的命令集合等於實際 ship 的四個 skill。

#### 失敗模式

- payload 檔案未被 git 追蹤 → 測試 FAIL，訊息指名該檔案路徑與所屬 entry 名稱。
- entry 的 source 目錄被某條 ignore 規則命中 → 測試 FAIL，訊息附上 `git check-ignore -v` 回報的規則來源（檔名、行號、pattern），讓人一眼看到是哪條規則造成。
- 同一 skill 名稱在 payload universe 內出現兩次以上 → 測試 FAIL，訊息同時列出名稱與全部定義路徑。
- payload universe 內出現不屬於任何 entry `source` 的 `SKILL.md` → 測試 FAIL，指名該孤兒路徑。
- 執行環境不是 git work tree（例如從 tarball 解壓執行）→ `git ls-files` 無法作為判準，測試以 pytest 的 skip 明示跳過並附理由，不得靜默視為通過。

#### 驗收標準

- `pytest tests/test_plugin_payload_tracked.py` 全綠；在 `.gitignore` 未修正前，同一測試必須 FAIL 且訊息指名被 ignore 的 payload 檔案（TDD 的 RED 證據）。
- `git ls-files plugins/propositions` 的輸出同時包含 plugin manifest、README，以及四個 `skills/*/SKILL.md`。
- 對 plugin manifest 路徑執行 `git check-ignore` 回傳非零（無規則命中）。
- 以 grep 搜尋 `plugins/propositions/` 下的 `/math-tools:` 字樣，零命中。
- 根層 `pytest tests/` 全綠，既有測試數不回歸。

#### 範圍邊界

**在範圍內**：`.gitignore` 兩條 pattern 的錨定；`plugins/propositions/` 下 manifest / README / 四個 skill 納入版控；根層 `skills/` 四個目錄刪除；四個 skill 與 plugin README 的命名空間文字修正；README.md 與 CLAUDE.md 的 skill 清單更新；新增 payload 追蹤性測試。

**在範圍外**：validator / audit 腳本邏輯；根層 `scripts/` forwarding shim；marketplace entry 的增減；skill 的執行語意；跨 repo 協調事項（#2）。`umbrella-marketplace-migration` task 5.4 的實測本身仍留在該 change 執行，本 change 只負責解除其結構性阻塞。

## Risks / Trade-offs

- **錨定後 conftest 產生的 shim 不再被擋** → 前導斜線只縮小匹配範圍到根層，而 conftest 建立的 shim 本來就在根層，防禦效果不變；`.gitignore` 註解同步寫明錨定的理由，避免日後有人「順手」拿掉斜線。
- **退役根層三個 skill 會讓既有使用者的肌肉記憶失效** → 這三個 skill 在 marketplace 改名後已經無法運作（cache 路徑不存在），退役只是把已經壞掉的入口移除；README 與 CLAUDE.md 同步改列實際可用的命令，使用者看到的指示第一次與現實一致。
- **測試依賴 git 可執行檔** → 非 git work tree 時明示 skip 而非靜默通過，符合專案的 loud-failure 紀律；CI 一律在 git checkout 內執行，實務上不會落入 skip 分支。
- **payload universe 的定義需要人維護（`.agents/` 例外）** → 例外清單寫在測試內並附註理由，新增 harness 目錄時必須顯式加入，這個摩擦是刻意的——預設拒絕比預設放行安全。
