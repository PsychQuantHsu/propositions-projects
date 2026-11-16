## Problem

#75 第三輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6909737914），有兩項擋下，另有 19 項範圍內的修正。

- 擋下的第 1 項：稿件不在任何 git repo 時，skill 請作者指定最上層的目錄並把它當成 repo；規格與說明文件都沒有寫這條路，而由作者指定邊界正是 11-15 決定排除的做法。超過兩層 submodule 時也一樣。
- 擋下的第 2 項：寫入檢查只擋 `nan`，`Infinity`、`-Infinity` 照樣通過；確認之後狀態立刻回報該節不同。`01`、`.5`、`+1` 這類不是 JSON 的寫法也通過。
- 範圍內的主要幾項：帳冊 `source.file` 的座標在 plugin 自己的參考佈局下認不出來；狀態把確認紀錄檔當成 JSON 串流讀，多行的紀錄、同一行兩筆都照樣通過，追加之後才被擋下，而 skill 又不准改那個檔；把要點搬到別的段落紀錄時來源會丟；`_meta.json` 的路徑由模型抄進指令；Swift 規則的例外有三個缺口；`CLAUDE.md` 的硬規則收窄過頭；`.git` 的排除只認小寫。

## Root Cause

修正輪 2 的驗收逐段實跑了指令，但「稿件不在 git repo」這條路是 skill 的說明文字、不是指令，對照表把它列在「skill 說了、規格沒寫」的清單裡，沒有被處理。寫入檢查的 `nan` 修正看的是 jq 讀進來的值；jq 讀 `Infinity` 與合法的大數 `1e400` 都得到無限大，只看值分不開兩者，所以當時拿掉了無限大的檢查。確認紀錄檔用 `--slurpfile` 讀，那是 JSON 串流的讀法，不是逐行的讀法。帳冊的座標改成「從帳冊所在 repo 的根目錄」時，沒有試 plugin 自己的範例。

## Proposed Solution

照 spec delta 修改 article-outline 的 9 條 requirement，skill 與說明文件跟著改；維護者 2026-11-16 的決定見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6910045662。

- 稿件不在 git repo、或超過兩層 submodule 時，skill 停下並說明，不請作者指定邊界（第二項照第一項的理由延伸，Decision 已寫明）。`DIR` 與 `MAIN` 也要從 `/` 寫起。
- 寫入檢查看原始文字：一行裡字串以外的每一個值，都要是 JSON 的寫法；jq 讀成無限大的合法數字另外報成「jq 無法保存的數字」。確認紀錄檔的檢查用同一條。
- 帳冊的 `source.file` 從兩個根目錄各解析一次（帳冊所在的 git repo、最外層的 repo），任一個對到稿件就算；文件不再說這出自 SCHEMA。
- 狀態、差異、使用中的 id 與追加之前，都逐行讀確認紀錄檔；有一行不是照 JSON 寫的物件就失敗，追加什麼都不做，並說明檔案被手動改過，skill 不改它。
- 列帳冊時把 `_meta.json` 的路徑寫進暫存目錄的清單，比對的指令從清單讀出。
- `.git` 的排除不分大小寫；列檔時跟著改用 `-ipath`。
- 修改時把要點搬到別的段落紀錄，原紀錄的來源放進這個要點的 `basis`。
- 一節只和自己的紀錄比，`uses` 依賴的別節改了不影響它，文件寫明。
- 經由 symbolic link 的目錄引入的 `.tex` 列進「不讀的檔」；修改時拿掉全部沒有 `from` 的段落、段落檔變空，是可以接受的第二種空檔；checker 的定義補上 `note`；規格的 Scenario 補上條件。
- Swift 規則：第 2 類的 jq 只算 SKILL.md 裡的；〈不適用〉第 1 類寫明指令列可以用哪些接法；第 4 類的退場條件改成子命令涵蓋每一段 jq 之後。
- `CLAUDE.md` 的硬規則與 `manuscript-jsonl-sync.md` 回到原本涵蓋的 jsonl，只把綱要檔排除；需要 git 的不只綱要 skill。

- 驗收時找到的：第三輪報告逐列核對只剩第 9 列部分處理（Swift 規則的指令列接法沒有 `{ …; }` 分組與 `exit`），已補上；規格對指令的對照表實跑 265 項，找到 11 處對不上：兩處改指令（綱要目錄的上一層要是目錄；列帳冊與比對帳冊的路徑要從 `/` 寫起），其餘收窄句子（路徑含換行或在 `.git` 底下的 `_meta.json` 與 `.tex` 不讀；不是 UTF-8 的位元組不報；狀態失敗時告訴作者；`ROOT` 與 `STAGE` 不從回答取得；使用中的 id 可以列得比較多；`id` 是非空字串；形狀不對的確認紀錄可能讓狀態做到一半失敗；確認紀錄只有四個鍵沒有工具檢查；暫存目錄不見時重跑第一段指令）。第十六位盲讀者標出「repo 根目錄是一切讀寫的邊界」與暫存目錄在 repo 外互相矛盾，句子收窄成綱要檔與來源檔的邊界。

## Non-Goals

- 綱要檔的驗證器與各條 requirement 的可執行測試：仍延後到 #78（排在 #46 之後）。`agents/` 有沒有被追蹤的測試也一樣，記到 #78。
- 第三輪報告第 19 列（沒有帳冊時建議的目錄與 Operation D 的預設不同）另開一張。
- 封存的 proposal 與 tasks 不改。修正輪 2 的 proposal 說「收窄句子、不另加檢查」，實際加了第二輪報告要求的幾項行為；task 2.1 說 pytest 涵蓋新的 agent 檔，實際沒有。兩處在這一輪的 Implementation Complete 照實寫。

## Success Criteria

- SKILL.md 的 18 段指令照寫法逐段實跑，zsh 與 bash、Homebrew 的 jq 與系統內建的 jq 四種組合，各 194 項全部符合預期。新增的情境含：目錄不是從 `/` 寫起、三層 submodule 都停下並說明；照 SCHEMA 範例寫的子模組帳冊認得出來；`Infinity`、`01`、`.5`、`1e400` 與字串裡的同樣文字；確認紀錄檔的多行紀錄、同一行兩筆、只有空白的行、`nan`，四種情況下狀態、差異、使用中的 id 都失敗，追加什麼都不做；`.GIT/HEAD`；列帳冊與比對帳冊時路徑不是從 `/` 寫起；綱要目錄的上一層是一般檔案。
- 一位獨立 agent 對照第三輪報告要處理的列，逐列回報已處理與在哪一句。
- 只拿到 OUTLINE.md 的讀者，對這一輪改過的規則答得與預存的答案相同。
- 全套 pytest 通過；spectra validate 與 spectra analyze 對這個 change 沒有錯誤；`plugins/propositions/scripts`、`plugins/tschema-check`、`tests` 相對於 main 沒有變動。

## Impact

- Affected specs: `article-outline`（修改 9 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - Modified: `plugins/propositions/agents/outline-checker.md`
  - Modified: `plugins/propositions/rules/manuscript-jsonl-sync.md`
  - Modified: `README.md`
  - Modified: `CLAUDE.md`
  - Modified: `.claude/rules/swift-is-the-implementation-language.md`
  - New: (none)
  - Removed: (none)
