## Problem

#75 第五輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6937200906），有兩項擋下，另有 22 項範圍內的修正。兩項擋下都是修正輪 4 自己帶進來的。

- 擋下的第 1 項：修正輪 4 為了判斷「git 列不列得出這個檔」，在 repo 內容決定的目錄裡執行 `git ls-files`（主稿件的目錄、來源指標指到的檔的目錄、每一個有 `.tex` 的目錄）。目錄裡只要有 `HEAD`、`objects/`、`refs/`，git 就把它當成 bare repo 並讀它的 `config`；這些檔都可以被 commit。`config` 裡寫了 `core.fsmonitor` 時，那段指令會被執行，檔案還被判成列得出。
- 擋下的第 2 項：列 `.tex` 檔的指令改成 `find … -execdir git …`。`PATH` 有空項目或相對項目時，macOS 內建的 find 會執行 repo 裡名叫 `git` 的檔；Claude Code 的 Bash 把 `find` 包成 bfs，bfs 直接拒絕，反推停下。
- 範圍內的主要幾項：檔名最後一段的大小寫沒有正規化，GNU 的 `realpath` 下打錯大小寫的稿件被說成「git 忽略」；搬走一筆有來源的紀錄的最後一個要點、作者選不要這段時，沒有合規的結果；被引入而沒有讀的 `.tex`，綱要裡不留任何紀錄；整份確認記下刪節之後又把那一節原樣加回來，確認時看不出來；狀態與確認有三條錯誤的去路走不通；列帳冊的指令讀了它自己排除的檔；外層 repo 忽略的目錄裡若有獨立的 repo，裡面的檔仍被讀；字元檢查套在絕對路徑上，repo 放在名稱含那些字元的目錄底下就不能用；第一段指令沒有清掉環境裡同名的 `TOOLS` 與 `ROOT`；Swift 規則的工作清單漏了三段指令；封存的 fix4 tasks 4.3、4.4 打了勾而完成條件沒有達到。

## Root Cause

修正輪 2 到 4 把 repo 的內容與使用者的環境都當成不可信，防護卻是寫在 SKILL.md 裡的 shell 指令：每加一道就多一段要驗的 shell，第三、四、五輪擋下的項目裡都有上一輪修正帶進來的。修正輪 4 的驗收（324 項、三位獨立測試者）攻的是路徑的寫法與 shell 的行為，沒有人從「repo 的內容能讓 git 做什麼」下手；驗收在全新的 shell 裡跑，用的不是 Claude Code 實際用的 `find`。fix4 的 tasks 把「直到一次找不到」「讀最後的文件」寫成完成條件，實作卻在條件達到之前繼續修改。

## Proposed Solution

維護者 2026-11-17 的決定見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6938070366：24 項全部處理；skill 保留三項保證（只寫三個綱要檔、不讀 repo 以外的檔、確認紀錄只記作者親口說的），惡意的 repo 內容與異常環境的防護留給 #78 的命令列工具，寫成已知限制；第 1 項擋下仍然修掉。照 spec delta 修改 article-outline 的 10 條 requirement，skill、說明文件與 checker 的定義跟著改。

- git：每一個讀 repo 的 git 指令都帶 `-c safe.bareRepository=explicit -c core.fsmonitor=false`。前者讓 git 只認有 `.git` 的目錄，偽裝成 repo 的目錄不被當成 repo、它的 `config` 不被讀；後者讓 git 不啟動設定檔指名的監看程式。第一段指令要求 git 2.38 以上（`safe.bareRepository` 從這一版開始有）。linked worktree 與 `.git` 是檔案的 repo 照常找得到。
- 列 `.tex` 檔：不用 `-execdir`。先列出檔案，再逐一問 git。
- 信任邊界：三份文字（skill、說明文件、規格）都寫明三項保證，以及八項已知限制的封閉清單，每一項寫明可能破壞哪一項保證：路徑含單引號、`PATH` 有空或相對項目、zsh 的 `chpwd` 函式、repo 裡別人做的獨立 git repo 的設定、`noclobber` 與 `cp -i`、暫存目錄的 ACL、檔案身分不穩定的檔案系統、環境裡指揮 git 的變數（`GIT_DIR` 這一類；這一項是這一輪驗收時才量到的，`997d3d0` 也是這樣）。`pwd` 只在 `/usr/bin` 與 `/bin` 找的代價（兩處都沒有的系統上停下）也寫明。
- submodule：不設層數上限，一路往上找到最外層的 repo。這是實作提出的第三種做法（維護者沒有追認「超過兩層時停下」，原本的做法是請作者指定根目錄，已被先前的決定排除）；途中 git 失敗時印 `STOP`。
- 忽略的檔：除了在檔案所在的目錄問 git，也在根目錄問最外層的 repo 是否忽略它；外層忽略就不讀。外層答不出來時（submodule 裡的檔），以內層的回答為準。
- 檔名最後一段：主稿件與來源指標的檔，最後一段取目錄裡實際的名稱（`find -samefile`），所以打錯大小寫的檔名在兩種 `realpath` 下行為相同；同一個目錄有兩個名稱指到同一個檔時維持原樣。
- 列帳冊：只讀清單裡的檔；字元檢查只看根目錄以下的那一段。`_meta.json` 與綱要目錄不問 git 是否忽略，文字照實寫明（只有來源才問）。
- 第一段指令：開頭清掉 `TOOLS` 與 `ROOT`。稿件將放的目錄還不存在時，改用存在的最近上層目錄（只改文字，由 skill 給目錄）。
- 反推：被引入而沒有讀、又不在圖表裡的檔，留一筆 `carry` 的紀錄，`from` 指到引入它的那個指令，要點帶 `pending`，寫明作者要補的是那個檔的內容以及沒有讀的原因。
- 修改：搬走最後一個要點時，問作者補新的要點還是不要這筆。不要而且沒有來源：搬完後刪掉。不要而且有來源：要點帶著 id 搬走，原紀錄留一個新 id 的要點（同樣的文字）並標 `dropped`。
- 確認：展示全部的節時多展示第三樣，最後一次整份確認沒有的節（`added`），即使它與自己最近一次通過的內容相同也完整展示。
- 錯誤的去路：狀態失敗而 jq 沒有指名檔案時，對節檔與段落檔跑寫入檢查；檔案不見時照實說，狀態不建檔也不改檔；追加確認紀錄時找不到「展示了哪些節」的紀錄，回到第 1 步，不重寫輸入檔。
- checker 的定義：`label` 與 `starts` 並存、指到不同段落時由 `label` 決定。
- Swift 規則：〈例外〉第 4 類的工作清單補成 14 項，對 19 段指令逐段對過。README：「不讀 git 忽略的檔」改成只指來源。
- fix4 封存的 tasks 4.3、4.4：取消勾選，註明當時實際做到哪裡，指到這個 change 的對應 task。

## Non-Goals

- 對惡意的 repo 內容與異常環境的防護：照維護者的決定留給 #78 的命令列工具。第 3 列（單引號）、第 16 列（`chpwd`）、第 2 列的 `PATH` 部分、第 24 列（`pwd`）不加新的 shell，寫成已知限制。
- 綱要檔的驗證器與各條 requirement 的可執行測試：仍延後到 #78（排在 #46 之後）。
- 格式要不要能分辨兩段相同的段落（#84）、plugin 層級的 `allowed-tools`（#85）、其他 skill 既有的 shell 寫法（#86）。
- 列檔的 find 改成在目錄層剪掉 `.git`（第五輪報告第 26 列，Follow-up）。

## Success Criteria

- SKILL.md 的 19 段指令照寫法逐段實跑，八種組合全部符合預期：zsh 與 bash，各配 Homebrew 的 jq、系統內建的 jq、GNU coreutils 在 `PATH` 最前面，以及把 `find` 換成 Claude Code 的 Bash 實際用的 bfs。新加的檢查在修正前的檔案（`cb5efd2`）上會失敗。
- 第五輪報告第 1 列的重現例子（提交偽裝成 repo 的目錄、`config` 指名一段指令）：第一段指令、主稿件檢查、帳冊比對、列 `.tex` 檔、逐檔計數都不執行那段指令，那些目錄裡的檔不被讀。
- linked worktree、bare repo 的 worktree 兩種放法，加了選項之後照常運作。
- 指令凍結之後由獨立測試者實跑；重複到一輪裡沒有「破壞三項保證」或「相對 `997d3d0` 的功能退步」的重現為止，任何指令修正之後重來一輪。落在八項已知限制裡的不算重現，記進清單。
- 文字與規格凍結之後，獨立 agent 逐句對照規格與指令，只拿到最後的 OUTLINE.md 的讀者作答；之後文件再改時，重做改到的部分。tasks 記下各自對的 commit。
- 全套 pytest 通過；spectra validate 與 spectra analyze 對這個 change 沒有錯誤；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。

## Impact

- Affected specs: `article-outline`（修改 10 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - Modified: `plugins/propositions/agents/outline-checker.md`
  - Modified: `plugins/propositions/README.md`
  - Modified: `README.md`
  - Modified: `CLAUDE.md`
  - Modified: `.claude/rules/swift-is-the-implementation-language.md`
  - Modified: `openspec/changes/archive/2026-11-17-idd-75-fix4/tasks.md`
  - New: (none)
  - Removed: (none)
