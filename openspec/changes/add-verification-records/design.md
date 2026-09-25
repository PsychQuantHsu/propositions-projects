## Context

propositions 帳冊（`main.jsonl`）把稿件拆成命題，每筆有 UUIDv7 `id`、逐字 `text`、`cites` DAG。帳冊本身只管「稿件說了什麼」，不管「說的對不對」。目前做雙重驗證的稿件只能在 repo 外另開對照表，欄位寫死一種方法（例如 `lean_ref`、`lean_status`），加第二種方法就得改表頭。proofread skill 已經在做逐條閱讀，但結果只留在 `.proofread/<file>.md` 的 checkbox，機器讀不到。

限制：帳冊 schema 不動（使用者裁決 1）；PR #11 正在改 proofread SKILL.md，本 change 對它只改兩行（交叉連結、checklist 模板的 id 欄改為完整 UUID），把衝突面壓到最小。

## Goals / Non-Goals

**Goals:**

- 一個與方法無關的驗證紀錄格式，同一命題可並列多種方法的判定。
- 一支 validator，能在 CI 擋住壞紀錄（懸空 id、壞列舉、沒證據的判定）。
- 能看出不同方法判定不一致的命題。
- 把 proofread 既有的 checklist 轉成紀錄，第一個方法就能真的用上。

**Non-Goals:**

- 不修改帳冊 schema、不在 `main.jsonl` 加欄位、不改 `validate-propositions.py`。
- 不實作 Lean、exact_certificate、cas、cross_model 的自動轉換；它們之後各自開 issue 接入（使用者裁決 3）。
- 不判斷哪個方法「比較可信」，也不自動合成一個總判定；不一致只報告。
- 不改 proofread 的流程或 checklist 格式。

## Decisions

### Sidecar verification.jsonl next to the ledger

紀錄放在帳冊同目錄的 `verification.jsonl`，一行一筆。選 sidecar 而非在帳冊加欄位：帳冊描述稿件，驗證描述外部證據，兩者更新頻率與作者不同；放在同一檔會讓每次重跑 Lean 都改動帳冊、污染 R13 等 location 檢查的 diff。選 JSONL 而非 CSV：`tool`、多行 `notes` 需要巢狀與跳脫，且與帳冊同格式，可重用讀取程式。替代方案「每個方法一個檔」被否決：跨方法比對要先合併，檔名也會變成隱性 schema。

### Open method vocabulary with x- prefix

`method` 是封閉列舉 `proofread / lean / exact_certificate / cas / cross_model / human`，另允許 `x-` 前綴的自訂值。封閉部分讓 validator 能擋拼錯（`leanprover`）；`x-` 讓新方法不必先改 plugin 就能記錄。替代方案「完全自由字串」被否決，因為拼錯會安靜地變成另一個方法，跨方法比對因此失真。

### Evidence required unless not attempted

`status` 為 `supported / refuted / partial / unresolved` 時必須有非空 `evidence_ref`（V5）；只有 `not_attempted` 可以沒有。判定沒有可追的證據就只是意見。`evidence_ref` 是字串（路徑加行號、Lean 常數名、commit、URL），validator 不解析它的內容，只檢查存在；解析各方法的證據屬於各方法接入時的事。

### Latest record per method decides disagreement

同一命題同一方法可以有多筆紀錄（重跑、修稿後重驗），跨方法比對時每個方法只取 `checked_at` 最新的一筆；同日多筆取檔案中較後的一行。紀錄只追加不改寫，歷史留在檔案裡。不一致定義為：某方法最新判定 `supported`，另一方法最新判定 `refuted` 或 `partial`。報告為 warning 不是 error，因為不一致本身是需要人看的訊息，不是資料壞掉。

### Proofread checklist conversion by uuid prefix

proofread checklist 每行形如 ``- [x] **P012** `019e2fbe` [claim] @L10-L12 — "…"``。原設計只用 `uuid_short` 前綴解析；**對真實帳冊實跑後推翻**：UUIDv7 的前段是時間戳，同一批抽取的命題共用前 8 碼（實測一份 364 筆的帳冊中，245 筆共用同一前綴），前綴幾乎總是不唯一。

**身分只來自 id，不來自比對。** verify 兩輪各找到一種錯接：第一輪是片段抽取失敗後退化成 ordinal；第二輪是截斷片段（約 80 字）只描述開頭，原命題改寫消失後，另一筆同前綴、開頭相同的命題就被當成它。兩者都是 exit 0、無警告。所以：

- proofread checklist 模板改為寫**完整 UUID**（SKILL.md 一行）。完整 id 直接對到該命題，且其文字仍須以片段開頭（擋改寫後的舊判定）。
- 只有短前綴的舊 checklist：片段未截斷且等於某命題全文時才接受；截斷片段一律視為無法安全識別，提示以完整 id 重產。
- view ordinal 不用來解析：帳冊增刪後它會整批位移。

實測一份 364 筆帳冊：以完整 id 重產的 40 行 checklist 全數解析（32 筆紀錄），舊的短前綴 checklist 則被拒並附原因。

兩種失敗分開處理：縮小後仍多於一筆 → 一律整批失敗（錯接到別的命題比少一筆紀錄危險）；一筆都沒有（文字在 checklist 產生後改寫、或命題重抽換了 id）→ 預設整批失敗，`--allow-unmatched` 時略過並列在 stderr，因為它不可能錯接。實測一份 2026-08 的舊 checklist：46 行中 45 行因帳冊重抽而無對應，其中 11 行的文字仍在、但已換成新 id——依文字轉移判定到新 id 並不安全（新命題的 asserts／cites 可能不同），所以不做。

對應：`[x]`／`[X]`→`supported`、`[~]`→`partial`、`[-]`→`not_attempted`、`[ ]` 略過。`evidence_ref` 為 `<checklist 路徑>:L<行號>`。`[~]` 對應 `partial` 而非 `refuted`：proofread 的 finding 多半是帳冊拆解或引用的瑕疵，不等於命題為假。

proofread 的 `supported` 語意要在文件寫清楚：它代表六項閱讀檢查（拆解忠實、claim_type、引用完整、引用推得出、evidence_class、location）都通過，是對帳冊條目與論證鏈的檢查，不是形式證明。

## Implementation Contract

**validate-verification.py**

- 呼叫：`validate-verification.py --records <verification.jsonl> --ledger <main.jsonl>`。
- 輸出：每個 finding 一行 `[V<n>] L<line>: <message>`；最後一段 `=== N ERROR(s) ===` 或 `✓ ALL VERIFICATION CHECKS PASSED`，以及 `[WARN] disagreement` 區段，每個不一致命題一行，列出 `method=status` 對。
- 檢查：V1 JSON 壞或缺必填鍵（`prop_id`、`method`、`status`、`checked_at`）；V2 `prop_id` 不在帳冊；V3 `method`／`status` 不在列舉；V4 `checked_at` 不是合法 `YYYY-MM-DD`；V5 非 `not_attempted` 卻無非空 `evidence_ref`；V6（warning）同 `prop_id`＋`method`＋`evidence_ref` 重複。
- Exit：0 無 error；1 至少一個 error；2 參數錯誤或讀檔失敗。帳冊以 `validate-propositions.py` 的 `load_props_jsonl` 讀取（importlib 載入該模組，與既有 tests 的載入方式相同），不另寫解析。
- 空的 `verification.jsonl` 合法（0 筆紀錄，exit 0）。

**proofread-to-verification.py**

- 呼叫：`proofread-to-verification.py --checklist <.proofread/x.md> --ledger <main.jsonl> [--checked-at YYYY-MM-DD] [--checker NAME] [--allow-unmatched]`，JSONL 寫到 stdout。`--checked-at` 預設為今天（臺北時間），且與 validator 的 V4 用同一條規則（恰為 `YYYY-MM-DD`），不合即 exit 2。
- 任一行縮小後仍不唯一：exit 1，stderr 列出行號，stdout 不寫任何東西。任一行無對應：預設同上；`--allow-unmatched` 時略過並在 stderr 列出。
- 不符合 checklist 行格式的行（標題、Findings 表格）一律忽略。

**文件**：`plugins/propositions/docs/VERIFICATION.md` 寫格式、兩張詞彙表、V1–V6、不一致定義、proofread 的 `supported` 語意、其他方法如何接入（寫一筆紀錄、跑 validator）。proofread SKILL.md 只加一行指向轉換腳本；plugin README 加一行指向 VERIFICATION.md。

**驗收**：`tests/test_verification_records.py` 涵蓋 spec 的每個 scenario；`python3 -m pytest -q` 全綠；對一份真實帳冊跑轉換再跑 validator 可通過。

**範圍外**：Lean／CAS 等轉換器、帳冊 schema、CI workflow 的接線（由下游 repo 自行加一步）。

## Risks / Trade-offs

- [uuid_short 前綴在 UUIDv7 帳冊上幾乎必撞、截斷片段不構成身分] → checklist 改寫完整 id；短前綴只在片段等於全文時接受，否則拒絕，永不猜。
- [舊 checklist 大量無對應] → 預設失敗提醒重做 proofread；`--allow-unmatched` 只轉仍對得上的行。
- [proofread 的 `supported` 被誤讀為形式證明] → VERIFICATION.md 明寫其語意；不一致報告列出方法名，讀者看得到是哪種證據。
- [`evidence_ref` 只檢查存在，指向的檔案可能已不存在] → 第一版接受此限制；各方法接入時可加自己的證據檢查（例如 Lean 常數是否存在）。
- [PR #11 同時修改 proofread SKILL.md] → 本 change 只改兩行，衝突時手動合併成本低。
