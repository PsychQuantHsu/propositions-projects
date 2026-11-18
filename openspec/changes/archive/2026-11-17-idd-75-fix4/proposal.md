## Problem

#75 第四輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6922928621），有四項擋下，另有 19 項範圍內的修正。

- 擋下的第 1 項：主稿件本身沒有任何檢查。它是指到 repo 外的 symbolic link 時，反推照樣把外部內容當來源讀進來，之後每一個來源指標都解析不了，反推永遠做不完。
- 擋下的第 2 項：帳冊的 `source.file` 從兩個根目錄各讀一次、任一個對到就算，於是 submodule 或內層 repo 裡另一篇稿件的帳冊也會「指到」外層的稿件，skill 不問就把別篇的帳冊目錄當成綱要目錄。
- 擋下的第 3 項：交給 checker 的檔名是根目錄加上來源指標的 `file` 原字串。計數先跟 symbolic link、再處理 `..`，Read 工具先以字面消去 `..`，兩者會指到不同的檔；來源指標的檔名也原樣進了 checker 的任務訊息。
- 擋下的第 4 項：整份確認之前，節的順序變了、或有節被刪掉，都不會展示給作者。
- 範圍內的主要幾項：沒有稿件的起草在 repo 裡有任何帳冊時就停下；兩段完全相同的段落定位不了，反推卻被要求修到通過；jq 1.6 把兩個不同的長整數讀成同一個；Swift 規則〈不適用〉第 1 類被放寬到整個 repo；稿件不在 git repo 時第一段指令不印 `STOP`；確認紀錄檔的兩種錯誤 jq 不指名檔案；一份 `_meta.json` 算不算一份帳冊，列出與比對兩處判斷不一致；暫存目錄的守門只看它在 repo 外。

## Root Cause

修正輪 1 起，被引入的檔與來源指標的檔逐輪加上邊界檢查，主稿件與交給 checker 的路徑一直不在檢查之內。修正輪 3 把 `source.file` 改成兩個根目錄都試時，驗收只列了應該認得出來的三個例子，沒有不該認的例子，修正輪 1 擋掉的情形因此回來。狀態從第一版就算出節的順序，確認時要展示什麼，規格卻只寫了每一節的三種情況。Swift 規則的放寬是為了讓守門行有類別可歸，寫成了整個 repo 的接法清單，超出 2026-11-15 的決定。

## Proposed Solution

照 spec delta 修改 article-outline 的 10 條 requirement，skill、說明文件與 checker 的定義跟著改；維護者 2026-11-17 的決定見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6923670862。

- 主稿件：新增一段檢查。它必須是 repo 裡的一般檔，本身不是 symbolic link，不在 `.git` 裡，而且 git 列得出它（已追蹤，或未追蹤且未忽略）；不符就停下。通過後 skill 以印出的實際路徑讀稿件，反推讀稿之前再檢查一次。
- 帳冊：一份帳冊最多指到一個檔。`source.file` 先從帳冊自己的 git repo 根目錄讀，再從最外層的根目錄讀；第一個指到「帳冊自己的 repo 裡的一般檔」的讀法決定它指到哪個檔。
- checker：逐檔計數的指令把來源指標的檔名與實際路徑寫進暫存目錄的清單，一行一個 JSON 物件。任務訊息只給四個 skill 自己產生的路徑（節檔、段落檔、清單、要看的節的 id 檔），不含綱要、稿件或檔名的文字。check 開頭先對兩個檔跑寫入檢查。
- 節的順序：狀態多回報「通過之後被拿掉的節」（不在檔裡，而且最近一次通過的內容在最後一次整份確認、或之後的確認紀錄裡）；差異指令在節的順序沒有照通過時的內容時印出兩種順序，並為每一個這樣的節印出它通過時的內容。展示的節是全部的節時，skill 先展示這兩樣；整份確認記下之後，已經確認過的刪除不再列出。
- git 忽略的檔：來源指標指到的檔要 git 列得出，否則不讀。同一條也套在主稿件與被引入的 `.tex` 上（Decision 寫明這是照決定延伸的）。詢問 git 時在檔案所在的目錄執行，所以 submodule 與內層 repo 的檔照它們自己的規則判斷。
- 第一段指令：先測 jq 能不能分辨 9007199254740993 與 9007199254740992，不能就停下；git 找不到 repo 時印 `STOP`；先確認機器的暫存目錄在 repo 外才建暫存目錄；暫存目錄記下它屬於哪個根目錄，之後每一段指令都確認暫存目錄是這個使用者的、別人不能讀寫、而且是為這個根目錄建的。
- 列帳冊：`_meta.json` 恰好是一個 JSON 物件才算一份帳冊，其餘印 `not one ledger`；路徑以 JSON 字串印出。沒有稿件時比對指令印一行 `ok` 說明，不印 `STOP`。有 `_meta.json` 讀不了、或請求裡的目錄與帳冊的目錄不同時，問作者。
- 確認紀錄檔：每一行的解析錯誤與紀錄形狀不對，都報成指名確認紀錄檔的錯誤；狀態失敗時依 jq 的訊息分三種處理，不猜是哪個檔。
- 相同的段落：兩段沒有 label、內容到結尾都相同的段落，反推認出後停下並說明，不拿後一段的文字湊數；格式要不要能分辨它們另開 issue。
- 沒有標題的引言：第一個標題之前、不是摘要的文字自成一節，`heading` 用文章的標題。
- 修改：搬走一筆紀錄的最後一個要點時，問作者這筆要不要、還是補新的要點。
- 來源指標的檔名含 U+007F 到 U+009F、或換行與改變文字方向的字元時不是來源指標；label 以 JSON 字串印出。
- Swift 規則：〈不適用〉第 1 類退回修正輪 3 之前的字句；〈例外〉第 4 類改成點名同一份 SKILL.md 的指令區塊；標題與 skill 的句子改成和退場條件一致。同步規則與 `CLAUDE.md` 的硬規則退回原本的字句，只加一句綱要檔不在內。
- 驗收時三位獨立 agent 找到的（逐列核對、只看這一輪的 diff 找會出錯的輸入、規格對指令逐句對照），都在這一輪處理：
  - 目錄的比較改用系統回報的名稱。`realpath` 不還原 macOS 上同一個磁碟的另一個名稱（`/System/Volumes/Data/…`），GNU 版也不還原大小寫，repo 裡的目錄因此會被判成在 repo 外。做法是用 shell 內建的 `cd -P` 進入目錄、取 `pwd -P`，再確認得到的名稱與原本的路徑是同一個目錄；檔案則取實際路徑、把所在目錄換成這樣的名稱，再確認是同一個檔。第一版用一般的 `cd` 與 `dirname`／`basename`，第二位獨立測試者實跑出五項：目錄名結尾是換行時會指到另一個檔、`..` 照字面處理、使用者 profile 裡會印東西的 `cd` 讓第一段指令失敗、NFD 存檔的檔名以 NFC 輸入被擋、檔名的檢查依賴 `ls` 的輸出格式。現在的寫法不經過這些。第三位測試者對這個寫法跑了一萬多次，沒有一項讓檢查印出錯的 `ok`，另外找到兩項小的：綱要目錄的字元檢查比來源指標的定義窄，改用同一個定義；`PATH` 開頭是空項目時，進入 repo 的目錄後會找到 repo 裡名叫 `pwd` 的程式，改成只在 `/usr/bin` 與 `/bin` 找。
  - 寫入檢查原本靠檔名結尾判斷是不是段落檔，認不出 approve 保留的副本；check 開頭的寫入檢查因此略過段落檔的幾項。
  - 比對帳冊的指令沒有跑完時，那份帳冊算讀不了，改問作者；原本被當成沒有指到稿件。
  - approve 之外對部分節做 check 時，節的 id 另寫一個檔，不動「展示過哪些節」的紀錄。
  - 追加確認紀錄之前，也檢查既有紀錄的形狀；形狀的檢查補上段落清單裡必須是物件。
  - 主稿件與被引入的 `.tex`，路徑含來源指標不能帶的字元時不讀、不列；綱要目錄的路徑含控制字元時停下。
  - 通過之後被拿掉的節，只在節的順序沒有照通過時的內容時回報：順序照通過時的內容，表示節的檔正好是最後一次整份確認的那些節。
  - 帳冊自己放在獨立的 repo（只放帳冊的 submodule）時不指到任何檔，skill 改問作者。這是「只接受帳冊自己的 repo 裡的檔」的後果，規格寫明。
- `allowed-tools`：官方文件只記載 `Agent(名稱)` 用在 deny 規則，沒有記載它能用在 skill 的 `allowed-tools`，而且 `allowed-tools` 只是省去權限詢問、不限制工具。這一輪不改成沒有記載的寫法：skill 與說明文件照實寫它做什麼，plugin 層級的權限另開 issue。

## Non-Goals

- 綱要檔的驗證器與各條 requirement 的可執行測試：仍延後到 #78（排在 #46 之後）。同一筆紀錄裡重複的鍵（第四輪報告第 24 列）也歸到 #78。
- 格式要不要能分辨兩段相同的段落：另開 issue，由維護者決定。
- 限縮 skill 預先核准的工具：另開 plugin 層級的 issue。
- 封存的 proposal 與 tasks 不改。

## Success Criteria

- SKILL.md 的 19 段指令照寫法逐段實跑，zsh 與 bash、Homebrew 的 jq 與系統內建的 jq 四種組合，各 324 項全部符合預期；另把 GNU coreutils 放在最前面，兩種 shell 各跑一次。第四輪報告的重現例子寫成 17 項檢查，在修正前的檔案上全部失敗，在修正後的檔案上全部通過。
- 每一項改動的行為都有不該通過的例子：別篇稿件的帳冊（submodule、內層 repo、用 `..` 爬出去、主檔不見）不指到外層的稿件；指到 symbolic link、repo 外、`.git`、git 忽略的主稿件停下；git 忽略的檔（外層、submodule、內層 repo）不讀也不進 checker 的清單；上一層目錄、`/tmp`、別的 repo 的暫存目錄、別人讀得到的目錄都不被當成暫存目錄；形狀不對的確認紀錄讓狀態失敗並指名確認紀錄檔。
- 一位獨立 agent 對照第四輪報告要處理的列，逐列回報已處理與在哪一句；另一位只看這一輪的 diff，為每一項改動的行為找會出錯的輸入。
- 只拿到 OUTLINE.md 的讀者，對這一輪改過的規則答得與預存的答案相同。
- 全套 pytest 通過；spectra validate 與 spectra analyze 對這個 change 沒有錯誤；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。

## Impact

- Affected specs: `article-outline`（修改 10 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - Modified: `plugins/propositions/agents/outline-checker.md`
  - Modified: `plugins/propositions/rules/manuscript-jsonl-sync.md`
  - Modified: `plugins/propositions/README.md`
  - Modified: `CLAUDE.md`
  - Modified: `.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
