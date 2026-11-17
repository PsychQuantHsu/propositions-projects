## Problem

#75 第六輪驗證判定 FAIL（https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6956657369），擋下 1 項，另有範圍內 20 項。

- 擋下的那一項：修正輪 5 讓沒讀、又不在圖表裡的被引入檔自成一筆 `carry` 紀錄，以引入指令當開頭文字。同一個檔被引入兩次（knitr／R 稿件常在兩處插入同一個生成的數字），那個指令出現兩次，反推整份停下；`997d3d0` 做得完，這是退步。
- 範圍內的主要幾項：狀態沒有先跑寫入檢查；確認紀錄可能只追加了一半；第二項保證沒有涵蓋 checker 被稿件裡的文字誘導去讀別的檔，也沒有涵蓋起草時讀作者指定的檔；根目錄是 `/` 時的暫存目錄；最近的上層目錄可能落在更大的 repo；幾處文字比指令寬。

## Root Cause

修正輪 5 處理第五輪第 9 列（沒讀的被引入檔在綱要裡不留紀錄）時，自行設計了一種新紀錄，並沿用「來源指標的開頭文字要出現一次」的規則，於是引入指令重複時沒有合規的寫法。這個行為寫在由模型執行的反推步驟裡，三輪獨立實跑只跑指令區塊，沒有執行到它。

## Proposed Solution

維護者 2026-11-18 的指示見 https://github.com/PsychQuantHsu/propositions-projects/issues/75#issuecomment-6956741179：照 `/idd-all` 繼續做，修正輪 6 只開這一輪，第七輪仍有擋下就停下。照 spec delta 修改 article-outline 的 9 條 requirement，skill 與說明文件跟著改。**19 段指令不改**，封存前逐段與 `aa8a63d` 比對。

- 沒讀的被引入檔：不新增紀錄、不新增來源指標。反推把一句話寫進既有紀錄的 `note`（引入指令所在的段落或區塊；否則同一節裡在它之前的那一筆；否則它之後的第一筆），寫明是哪個檔、沒讀、為什麼。同一個檔被引入兩次就是兩筆紀錄各有一句，反推不停。整份稿件沒有任何紀錄可掛時，只告訴作者。確認時展示 `note`；修改時 `note` 跟著紀錄走，合併時合起來，拆分時各留一份。
- 引入指令怎麼對到 `.tex` 清單裡的檔：`x` 沒有副檔名時加 `.tex`，從主檔的目錄算起，不分大小寫的檔案系統上同一個檔算同一個。
- 狀態：先跑寫入檢查，沒過就不報狀態；檔案打不開時說「不見或不是可讀的一般檔」，引用 jq 的原因。
- 確認紀錄的追加失敗時，先檢查確認紀錄檔；檢查沒過就停下，不重試。
- 第二項保證列的「git 自己讀的檔」改成包括 repo 的 git 目錄（不論在哪裡）；加第 9 項已知限制：稿件或來源指標指到的檔裡的文字要讀者去讀別的檔（checker 與 skill 的 Read 只靠規則守）。
- 起草與修改時作者指定的檔：先用主稿件那一段檢查，印 `ok` 才讀，否則請作者貼上。
- 根目錄是 `/`：不支援，寫明第一段指令在那時已在 repo 裡建了暫存目錄。最近的上層目錄：找到 repo 之後先問作者稿件會不會放在那裡。
- 最外層 repo 的 `check-ignore` 任何錯誤都算「沒有回答」，寫明；之前寫的來源指標可能因此解析不了，寫明。
- 沒有稿件時帳冊比對不跑 git，「所以會問」那句加上條件。
- submodule 不設層數上限標成維護者尚未決定。

## Non-Goals

- 任何指令區塊的改動；第六輪第 22 列（列 `.tex` 較慢）與第 23 列（`tojson` 不跳脫雙向字元）是 Follow-up。
- 第五輪起的信任邊界不變。

## Success Criteria

- 19 段指令與 `aa8a63d` 逐段相同，所以三輪獨立實跑與 389 項驗收仍然涵蓋現在的指令；八種組合重跑一次確認。
- 一位只拿到 SKILL.md 的 agent，對「同一個被忽略的檔在兩段裡各被引入一次、註解裡另有一份」的稿件照反推做到第 8 步，只寫暫存檔，做得完，寫入檢查與來源指標都印 `ok`。
- 文字凍結之後，獨立 agent 對照規格、OUTLINE.md 與 SKILL.md；最後一次改 OUTLINE.md 之後才盲讀，讀者標出的句子若再改就再讀。
- 全套 pytest 通過；spectra validate 與 analyze 沒有錯誤。

## Impact

- Affected specs: `article-outline`（修改 9 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`（散文，指令區塊不動）
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - New: (none)
  - Removed: (none)
