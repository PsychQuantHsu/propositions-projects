## Context

propositions plugin 有四個 skill，其中把稿件拆成帳冊的步驟（propositions skill 的 Operation C）只有一段說明，指向 `plugins/propositions/docs/EXTRACTION-PROMPT.md`。拆解完全靠 LLM 照 prompt 判斷，機械檢查只有 validator：

- R1 驗證每個 `prop.text` 正規化之後是 `.tex` 正規化之後的子字串。這只證明「沒有捏造」，不證明「沒有遺漏」；validator 自己的 docstring 也承認這不是 bijection。
- R1.5 檢查反方向，但只檢查到最上層的 `\section`，而且只發警告。一個段落漏了一個子句，現有工具都看不到。
- id 要求是 UUID v7（R7），但 plugin 沒有附產生器，這台機器的 Python 3.13 也沒有 `uuid.uuid7()`。

另一方面，#24 等待的「第一份非數學稿件」出現了：一份英文實證心理學稿件，APA 格式，沒有定理環境，有 Method／Results 與統計量。proofread Mode B 已經為實證主張定義了詞彙，但 R11／R12 是封閉 enum，用 Mode B 詞彙寫的帳冊一定 FAIL（合成探測已確認，紀錄在 #24 的留言）。

限制：

- repo 是 PUBLIC。稿件原文、作者、Overleaf 專案 ID、本機路徑都不能進入 repo，包含 artifacts、測試 fixture 與 eval 結果。
- CLAUDE.md 的 hard rule：任何寫入使用者 `main.jsonl` 的動作，必須先 dry-run 並取得確認；改 `normalize_for_match` 等共用 helper 時，必須跑完整的 R-rule 測試。
- `plugin-payload-integrity` spec 規定每個 skill 名稱只能有一個 `SKILL.md`。skill-creator 的 eval workspace 會複製 skill 快照，放在 repo 內就會違反這條。

## Goals / Non-Goals

**Goals:**

- 一個可以照著做的抽取流程（`propositions:extract`），完成的判準要能用機械方式驗證。
- 抽取出的帳冊能證明「沒有遺漏」：目標範圍內每一段文字，要嘛被某個 prop 涵蓋，要嘛明確列為被排除的結構。
- 實證稿件的帳冊能通過 validator，詞彙沿用 proofread Mode B，不另訂第二套。
- 既有帳冊（沒有宣告 profile 的）在 validator 上的輸出完全不變。

**Non-Goals:**

- 中文切句規則：沒有中文稿件可以依據，照 #24「不預先蓋」的原則，等有稿件時再以同一個 profile 機制新增。
- 重新抽取已經有 prop 的範圍：目標範圍內只要已經有 prop，skill 就停下來列出它們。取代或 `retired` 標記照 PLAYBOOK 手動處理。
- 表格與圖說的抽取：float 環境在覆蓋檢查中列為「已排除」並顯示出來，但這次不定義表格內容怎麼拆。
- profile 對其他 audit 的影響（例如實證稿要跑哪些 manuscript-audit 規則）：#24 列了這一項，但這次只處理 R11／R12 的詞彙。
- R9 的環境清單：#10 已改為從稿件的 `\newtheorem` 解析，不需要 profile 介入。

## Decisions

### 抽取做成獨立 skill，不擴寫 Operation C

抽取是 LLM 工作，另外三個 operation（validate、refresh、onboard）都是機械操作；觸發語也不同（「把這段拆成 propositions」對上「跑 validator」）。擴寫 Operation C 會讓 propositions skill 從 183 行長到約 350 行，而且只想跑 validator 時也要讀進整套抽取流程。Operation C 保留為一句話，指向新 skill，舊的叫法仍然找得到入口。使用者在 2026-11-01 選定了這個做法。

### profile 寫在帳冊的 `_meta.json`，值是封閉列舉

profile 跟著資料走，與 SCHEMA.md 由每份帳冊釘住副本是同一個原則：帳冊自己說明它用哪一套詞彙。可接受的值只有兩個：`default` 與 `empirical`。新增 profile 是 schema 變更，要更新 SCHEMA.md 與 validator，不得從字面相似的值推斷。沒宣告時當作 `default`。

考慮過的替代方案：在 plugin 裡放 profile 設定檔，讓 validator 依檔名載入。否決的原因是這樣會把詞彙定義放到帳冊以外，帳冊就不再自我描述；兩組 enum 也小到不需要另開一個檔案。

### `empirical` 是預設詞彙的超集合

實證稿件仍然有定義、假設、評論、交叉引用，所以 `empirical` 等於預設 enum 再加上 Mode B 的值：`claim_type` 加 `result`、`interpretation`；`evidence_class` 加 `measured`、`tested`、`descriptive`、`not_computable`，以及 pilot 之後新增的 `external`。另立一套獨立詞彙的方案被否決，因為那樣會讓同一個概念（例如 `definition`）在兩個 profile 各有一份定義。

最後的詞彙在 pilot 抽取之後才凍結：先用 Mode B 詞彙手動拆兩個段落，遇到放不進去的命題才補值，補的值同時寫進 SCHEMA.md 與 proofread Mode B，兩邊保持一致。pilot 的結果見 Open Questions。

### profile 需要 schema 1.7，宣告錯誤時大聲失敗

宣告 `profile` 的帳冊必須是 `schema_version` 1.7 以上，與 file-qualified location 必須 1.6 以上的做法一致。schema 不到 1.7 卻宣告 profile、或宣告了未知的值，validator 報錯並以 exit 1 結束，不會退回預設詞彙。只有在 `_meta.json` 宣告了 profile 時，validator 才多印一行 profile 資訊；沒宣告時輸出逐字元不變。

### 暫時 id 由 script 換成 UUID v7，而不是讓 LLM 產生 UUID

LLM 抽取時用 `tmp:<label>` 當 `id`，同一批 prop 之間的 `cites` 也用 `tmp:<label>`。`assign-prop-ids.py` 再一次把所有暫時 id 換成 UUID v7，`id` 與 `cites` 同步替換。

考慮過的兩個替代方案：

- 讓 LLM 直接寫 UUID。LLM 寫的 UUID 可能格式不合、彼此重複，`cites` 也可能抄錯字元，而 R7／R8 只能抓前兩種。
- 只提供一支列印 N 個 UUID 的產生器。LLM 仍然要自己抄 UUID，`cites` 的對應照樣容易出錯。

單調性採用 RFC 9562 §6.2 的 Method 1（固定長度的專用計數器）。位元配置是：毫秒時間戳佔 48 位元，`rand_a` 的 12 位元當作計數器，其餘位元用 `secrets` 取亂數。同一次執行內，id 依照暫時 id 第一次出現的順序嚴格遞增。

### 覆蓋檢查以字元為單位，不以句子為單位

clause-level 的 prop 只涵蓋句子的一部分。如果用「每句至少有一個 prop 重疊」來判斷，一句話拆成三個子句、漏掉其中兩個，仍然會被判為已涵蓋。字元層級的作法是：把目標範圍正規化，把每個 prop 的正規化文字定位到範圍內，取所有命中區間的聯集，再列出沒有被涵蓋、而且含有至少一個字母或數字的最大連續片段。這個作法同時避開了英文斷句的難題（`e.g.`、`et al.`、`0.95`、行內數學裡的句點）。

### 正規化步驟抽成單一步驟表，R1 與覆蓋檢查共用

覆蓋檢查需要把正規化之後的位置對回原始碼的行號，所以需要一個會記錄字元來源位置的正規化函式。如果另外寫一份，就會與 `normalize_for_match` 的大約 25 道 regex 替換慢慢分岔。作法是把這些替換抽成 `plugins/propositions/scripts/_lib/` 裡的一張有序步驟表：`normalize_for_match` 對純字串套用步驟表，新的 `normalize_with_map` 對「字元加來源位置」的序列套用同一張表。兩者在構造上就是同一套規則，測試再驗證輸出逐字元相同。

考慮過的替代方案：逐行正規化。否決的原因是 LaTeX 的句子常跨行，逐行處理會讓跨行的 prop 定位不到。

### 跳脫的 `\%` 是文字，不是註解

R1 的正規化用 `%[^\n]*\n` 剝除註解，沒有排除跳脫的 `\%`（#25）。`.tex` 那一側 `\%` 之後到行尾的文字被剝掉，prop 那一側沒有換行所以保留，結果逐字正確的 prop 被判為失敗；覆蓋檢查若沿用同一套規則，也會看不到那段文字。修正規則是：`%` 前面有偶數個（含零個）反斜線才是註解開頭，奇數個時是字面上的百分號。`\\%`（強制換行之後接註解）仍然是註解，所以不能只看前一個字元是不是反斜線。

這是 R1 的行為變更，所以和「步驟表只搬移」分開成獨立的 RED／GREEN 任務：先純搬移並確認基準 diff 為空，再修這道 regex。這樣基準上出現的任何差異都能歸因到 #25。

### 抽取先寫到帳冊外的暫存檔，併入時要確認

LLM 的輸出、id 替換與覆蓋檢查，全部在帳冊外的暫存目錄裡進行。validator 跑在暫存區裡的 `main.jsonl` 副本上，副本已經插入新的 prop，所以新 prop 與既有 prop 的衝突（例如 R3 循環、R8 重複 id）在寫入前就會被抓到。副本通過之後，skill 才顯示插入位置與 diff，經使用者確認才寫入。這符合 CLAUDE.md「寫 jsonl 前先 dry-run 並確認」的 hard rule，抽取失敗也不會弄髒帳冊。

### eval workspace 與實證稿件放在 repo 外

repo 是公開的，eval 結果會包含稿件原文；workspace 裡的 skill 快照也會違反「每個 skill 名稱只有一個 `SKILL.md`」。所以 eval workspace 與稿件 clone 都放在 repo 以外的位置，repo 裡只留 spec 與 skill 本身。

## Implementation Contract

#### `_meta.json` 的 `profile` 欄位與 R11／R12

- 資料形狀：`_meta.json` 可以有一個頂層字串欄位 `profile`，值只能是 `default` 或 `empirical`；欄位不存在等同 `default`。
- 行為：
  - R11 的允許集合：`default` 是 {verified, derived, hypothesized, conventional, open}；`empirical` 再加上 {measured, tested, descriptive, not_computable, external}。
  - R12 的允許集合：`default` 是現行的 12 個值；`empirical` 再加上 {result, interpretation}。
  - 錯誤訊息照現行格式，列出該 profile 的完整允許集合。
- 失敗模式：
  - `profile` 不在 {default, empirical} 內 → validator 報錯，指出這個值與允許的集合，exit 1。
  - 有 `profile` 欄位但 `schema_version` 低於 1.7 → validator 報錯，指出要先升 schema，exit 1。
  - `schema_version` 低於 1.2 時，R11／R12 照現行規則略過，profile 不改變這個行為。
- 輸出：宣告了 profile 時，validator 多印一行 `[INFO] profile: <值>`；沒宣告時輸出與變更前逐字元相同。
- 驗收：
  - 新的 pytest 涵蓋上述四種情況（default 拒收 Mode B 詞彙、empirical 接受、未知 profile、schema 不足）。
  - 既有測試全數通過。
  - 一份既有的數學帳冊在變更前後的 validator 輸出逐字元相同。

#### `assign-prop-ids.py`

- 介面：`assign-prop-ids.py <input.jsonl> [--out <path>]`。沒有 `--out` 時寫到 stdout。
- 行為：
  - `id` 符合 `tmp:[A-Za-z0-9_-]+` 的 prop，換成新的 UUID v7。`cites` 裡相同的暫時 id 同步換成同一個 UUID。
  - 已經是 UUID 的 `id` 與 `cites` 原樣保留。
  - 其他欄位與行序不變。
- 失敗模式（全部 exit 1，不寫任何輸出）：
  - `cites` 裡的暫時 id 找不到對應的 `id`。
  - 兩個 prop 用了同一個暫時 id。
  - 輸入不是合法的 JSONL。
- 失敗模式（exit 2）：`--out` 指向已存在的檔案，或與輸入是同一個檔案。
- 驗收：
  - 輸出通過 validator 的 R2、R7、R8。
  - 同一次輸出內的 UUID 依行序嚴格遞增。
  - pytest 涵蓋上述每一種失敗模式。

#### `check-extraction-coverage.py`

- 介面：`check-extraction-coverage.py --tex <file> --lines <start>-<end> --jsonl <path> [--main <main.tex>] [--format text|json]`。`--main` 是稿件的主檔，預設等於 `--tex`；多檔稿件檢查子檔時才需要指定，因為 `parts/x.tex:L5` 這類前綴是相對於主檔所在目錄解析的（v1.6 規則，沿用 `_lib/latex_env_parser.py` 的 `parse_location_v16`：沒有前綴或前綴是 `main.tex` 都指主檔）。原本寫的 `--meta` 被否決：`_meta.json` 的 `source.file` 是相對於稿件 repo 根目錄的路徑，script 無從得知那個根目錄。
- 行號範圍超出檔案行數、起點小於 1、終點小於起點，都視為不合法的範圍（exit 2）。只有一部分落在範圍內的 prop，它的文字在範圍內定位不到，照「定位不到」處理（警告）。
- `--format json` 的形狀：`{"tex": <路徑>, "lines": [<起>, <訖>], "candidates": <整數>, "uncovered": [{"start_line", "end_line", "excerpt"}], "excluded": [{"kind", "start_line", "end_line"}], "warnings": [{"id", "message"}]}`。`excerpt` 是未涵蓋片段正規化後的文字；`excluded` 只列 float（其他四類排除結構數量太多，列出來只是雜訊）。
- 行為：
  - 候選 prop：`location` 所在檔案與 `--tex` 相同（照 v1.6 的 file-qualified 規則判斷），而且行號範圍與目標範圍有交集的 prop。
  - 對每個候選 prop，在正規化後的目標範圍裡定位它的正規化文字。出現多次時，取最接近它 `location` 起始行的一處。
  - 輸出每一段未涵蓋片段的起訖行號與文字摘錄，最後是摘要（候選 prop 數、未涵蓋片段數、被排除區塊清單）。
- 排除的結構（封閉列舉，只有這五類，不得依性質相似類推第六類）：
  1. 未跳脫的 `%` 之後到行尾的註解。
  2. `\label{...}`。
  3. 章節命令（`\section`、`\subsection`、`\subsubsection`、`\paragraph`，含星號版本）與它的大括號標題；標題之後同一行的文字照常檢查。
  4. `\begin{...}`、`\end{...}` 標記本身，含緊接的方括號選填參數。
  5. float 環境（`table`、`table*`、`figure`、`figure*`）的整個內容。
- 被排除的 float 會逐一列在輸出中（環境名稱與行號範圍），不會悄悄略過。
- 失敗模式：
  - 有未涵蓋片段 → exit 1。
  - 檔案不存在、行號範圍不合法、JSONL 無法解析 → exit 2。
  - 某個候選 prop 在範圍內定位不到 → 列為警告，不計入涵蓋；這屬於 R1 的職責。
- 驗收：
  - pytest 涵蓋：全部涵蓋（exit 0）、漏掉一個子句（exit 1，並回報正確的行號）、跨行的 prop、被排除的 float 有列出、`--format json` 的形狀、多檔稿件以 `--main` 解析子檔前綴。
  - 等價測試：對所有 fixture 的 `.tex`，`normalize_with_map` 的字串部分與 `normalize_for_match` 的輸出逐字元相同。

#### `propositions:extract` skill

- 位置：`plugins/propositions/skills/extract/`，frontmatter 的 `name` 是 `extract`。
- 流程：
  1. 讀帳冊 `_meta.json` 的 profile，載入對應的 reference（`references/math.md` 或 `references/empirical.md`）。
  2. 確認目標範圍內沒有既有 prop；有的話停下來列出。
  3. 選切法：沿用帳冊已有的切法；新帳冊則問使用者。
  4. 目標落在定理類環境內時，用 grep 取得環境起訖行，寫進 per-call prompt 的 TARGET ENV。
  5. LLM 以暫時 id 輸出到暫存檔。
  6. 執行 `assign-prop-ids.py`。
  7. 執行 `check-extraction-coverage.py`。
  8. 人工 curation。
  9. 在暫存區把新 prop 插進 `main.jsonl` 的副本，對副本跑 validator；沒通過就停下來列出失敗的規則，不提供併入。
  10. 副本通過後，顯示插入位置與 diff，取得確認後才寫入 `main.jsonl`。
  11. 寫入後對 `main.jsonl` 再跑一次 validator，確認結果與副本相同。
- 完成判準：
  - 併入後 validator exit 0。
  - 覆蓋檢查 exit 0；或者每個未涵蓋片段都在 curation 時由使用者明確接受，並記錄在完成報告中。
- 驗收：
  - skill-creator eval 至少兩題（一題取自實證稿件的段落，一題取自既有數學帳冊所對應的 `.tex` 段落），分別在有 skill 與沒有 skill 的情況下執行。
  - assertions 至少包含：暫存帳冊通過 validator、覆蓋檢查 exit 0、每個 `text` 逐字取自原文、id 由 `assign-prop-ids.py` 產生。
  - 結果用 skill-creator 的 viewer 交給使用者審閱。

#### 範圍

- **In scope**：上面四項；SCHEMA.md 的 v1.7 一節；Operation C 改為指向新 skill；proofread Mode B 改為說明需要宣告 profile；Operation D 的 `_meta.json` 範本與交棒說明；PLAYBOOK、plugin README、CLAUDE.md 的 skill 表；plugin 版本升到 0.5.0。
- **Out of scope**：Goals / Non-Goals 中列出的五項。

## Risks / Trade-offs

- [抽出步驟表會改到 `normalize_for_match`，R1 的行為可能悄悄改變] → 改動前後各跑一次完整測試，並比對一份既有數學帳冊在變更前後的 validator 輸出必須逐字元相同；步驟表先只搬移、不修改任何一道 regex。
- [#25 的修正會改變原文含 `\%` 的帳冊的 R1 結果] → 修正放在純搬移之後的獨立任務；基準比對時，原文不含 `\%` 的帳冊必須逐字元相同，含 `\%` 的帳冊逐項列出差異，而且只允許 R1／R13 從誤判失敗變成通過。
- [Mode B 的詞彙可能不夠描述實證稿件，例如引述前人文獻的主張] → 實作 validator 之前先 pilot 手動拆兩個段落，詞彙在 pilot 之後才凍結；新增的值同步寫入 proofread Mode B。
- [覆蓋檢查的排除清單太寬，會把真正的命題排除掉] → 排除結構是封閉列舉；float 以外的排除不會吞掉任何句子文字，float 則逐一列在輸出中。
- [稿件原文經由 eval 結果或測試 fixture 進入公開 repo] → eval workspace 放在 repo 外；測試 fixture 只用合成文字；commit 前檢查 diff 中沒有稿件內容。
- [prop 文字在範圍內出現多次，定位到錯的那一處] → 取最接近 `location` 起始行的一處；兩處距離相同時列為警告，不猜。

## Migration Plan

- 既有帳冊不需要遷移：沒有 `profile` 欄位就等同 `default`，`schema_version` 維持原值也照常通過。
- 要使用 `empirical` profile 的帳冊，把 `schema_version` 改成 1.7 並加上 `profile`，SCHEMA.md 的 Versioning 一節會寫明這一步。
- Operation D 之後產生的新帳冊直接是 1.7，並在 scaffold 時詢問 profile。
- 回退：還原 plugin 版本即可。宣告了 1.7 的帳冊在舊版 validator 上，R11／R12 會拒收 Mode B 詞彙，這就是目前的行為，不會損壞資料。

## Open Questions

- ~~實證稿件中引述前人文獻的主張要用哪個 `evidence_class`？~~ **已決定（2026-11-01，pilot 之後）**：`empirical` profile 新增 `external`，意思是「支持在論文以外：句中引用的文獻，或在沒有引用時，指這個領域的共同知識」。
  - pilot：一份實證稿件的引言一段、Results 一段，共 13 個句子層級的 prop。Results 的 9 句全部放得進 Mode B 詞彙；放不進去的 3 句都在引言，都是「支持在論文以外」的主張，其中一句有 `\citep`、兩句沒有引用。
  - 不拆成 `cited`／`background` 兩個值：有沒有引用由原文的 `\cite` 指令判斷就知道，enum 再記一次就會有兩個可能互相矛盾的來源。
  - 不用 `cites` 指向 bib key：`cites` 只能放 prop 的 UUID，R2 會擋下。
  - 不加進 `default` profile：`default` 的輸出必須逐字元不變；數學稿件若需要，之後以 schema 變更另行加入。
  - pilot 也顯示 #25 的影響比原先估計的大：13 句中 6 句 R1 FAIL，其中一句本身不含 `\%`，只是在同一行的 `\%` 之後。
