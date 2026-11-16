## Problem

#75 第二輪驗證（6 個獨立 AI）判定 FAIL，有三項擋下，另有 28 項屬於這張 issue 的範圍。

擋下的三項：

- 寫入檢查把只屬於段落檔的兩項（points 要是清單、每個要點要有 id）也套在節的檔上；規格沒有寫這兩項。節的紀錄可以帶規格沒定義的鍵，名為 points 的鍵卻會讓檢查失敗。
- 一筆段落紀錄的 section 指不到任何一節時，它不在任何一節的確認範圍裡，也不會被拿給作者看；狀態仍然回報每一節照通過時的內容、整份也通過。
- 稿件所在的 repo 是另一個 repo 的 submodule、帳冊放在外層 repo 時，skill 只認得稿件所在的那一層，外層的帳冊目錄被判定在 repo 以外，綱要寫不進去。

範圍內的 28 項之中，需要改指令的有：狀態與差異讀確認紀錄檔時，讀不到也照樣回報成功；使用中的 id 漏了只剩 section、parent、uses 還指著的 id；from 或 basis 不是清單時沒有回報；反推與起草在只剩確認紀錄檔的目錄也照樣開始；來源指標可以指到 .git 底下的檔；檔名含換行時，列出的清單會斷成兩行；暫存目錄沒有在每次呼叫重新確認在 repo 以外；綱要目錄是一般檔案時沒有擋下；第一個指令沒有確認 git 在不在；空的 _meta.json 看不出來。其餘是句子比實際做的事寬：label 是照文字計數（註解裡的也算），文件卻說「定義一次」；前提檢查的 agent 被告知只讀，工具卻沒有限制；原樣搬動區塊的要點範例「States Theorem 1.」不是完整的句子；說「每一段原文的去向都答得出來」，但反推沒有記 commit；拆開一筆紀錄時只要求每個來源至少在一筆裡；「可能屬於另一份稿件」那一句沒有限定在沒有帳冊指到這份稿件的時候；範例的路徑不是從 repo 根目錄寫起；其他幾處摘要與規則的字句對不上（skill 的描述說前提檢查整個由另一個 agent 做；確認的第 1 步說之後都從副本顯示；id 清單用空白分隔）。

## Root Cause

第一輪的驗收照 skill 的寫法逐段實跑了指令，但用的 repo 佈局、紀錄的形狀都是我自己想到的那幾種：沒有 submodule、每一筆段落紀錄都指得到一節、確認紀錄檔永遠讀得到。規格裡的檢查是照「回報什麼」寫的，沒有寫「對哪一個檔」，於是段落檔的兩項被套到所有檔上。整份通過的條件只看每一節與順序，沒有看到不屬於任何一節的紀錄。repo 用的是稿件所在那一層的 git 根目錄。

## Proposed Solution

照 spec delta 修改 article-outline 的 11 條 requirement（「節的紀錄」與「確認紀錄的鍵」兩條不動），skill 與說明文件跟著改，同一個 commit。原則是收窄句子，不另外加檢查；擋下的三項與使用者已決定的兩項才改行為。

- 寫入檢查依檔名分辨段落檔：points 要是清單、每個要點要有 id 只查段落檔；節的紀錄裡規格沒定義的鍵不看，名為 points 的也一樣。規格與文件寫明這一點。
- section 指不到任何一節的段落紀錄：狀態列出它們；只要有一筆，整份就不算照通過時的內容；確認時給作者看的那一份有這種紀錄，就不追加確認紀錄，先給作者看並經由修改改正。
- repo 的定義：稿件所在的 repo，或它被 checkout 成 submodule 時最外層的 repo，最多兩層；更多層就問作者。沒有登記成 submodule、只是放在別的 repo 目錄裡的 repo，算它自己。第一個指令用 git 往上找。帳冊的 source.file 照 SCHEMA 是從放帳冊的那個 repo 的根目錄寫起，所以「帳冊指到這份稿件」改成逐份帳冊從它自己的 repo 根目錄解析、比實際路徑，submodule 裡的帳冊照樣不必問。綱要放在 submodule 裡時，來源路徑相對於最外層，單獨 checkout 那個 submodule 時解析不到，文件寫明。（使用者 2026-11-15 選「最上層的 repo」。）
- 前提檢查的另外五種，改由 plugin 自己定義、只有 Read 工具的 agent `propositions:outline-checker` 判斷；啟動不了就停下，不改用別的 agent 或自己判斷。規格的「SHALL be told」改成工具限制，並寫明 Read 本身打得開任何檔、只讀給它的那幾個檔是定義裡的指示。（使用者選「改成只有 Read」。）
- repo 的 Swift 規則：〈什麼算可執行程式碼〉第 2 類列出 jq 程式（目前只有這份 SKILL.md 用到 jq），加〈例外〉第 4 類指名這份 SKILL.md 的 jq 程式，退場條件是 #78 的命令列子命令。（使用者選「記一條指名的例外」；規則的字句由使用者在 PR 審。）
- 指令：狀態、差異、使用中的 id 讀確認紀錄檔改用 slurpfile，讀不到或不是 JSON 就失敗；使用中的 id 一行一個，含 section、parent、uses 指著的；from、basis 不是一個以上來源指標的清單時回報（空清單也算）；反推與起草在確認紀錄檔存在時也停下；來源指標不讀 .git 底下的檔與 submodule 的 .git 檔；列檔時排除路徑含換行的；每次呼叫的開頭也確認暫存目錄存在且在 repo 以外、綱要目錄不在 .git 底下、不是一般檔案；第一個指令也確認 git；列帳冊時每個 _meta.json 先印一行，讀不成一份帳冊的看得出來。
- 句子：目錄的比對寫成「實際路徑不同」；label 照文字計數、註解裡的也算；原樣搬動區塊的要點是完整的句子，範例換掉；「去向」那一句加上反推沒有記 commit 的限制；拆開時每一筆新紀錄都至少帶一個原來的來源；「另一份稿件」那一句只在沒有帳冊指到這份稿件時；範例路徑從 repo 根目錄寫起；symbolic link 的解析包含最後一層；skill 讀到的都是資料；空的段落檔只在作者給的綱要還沒有段落時才可以；沒有工具檢查缺少的必填鍵，只有作者的閱讀。CLAUDE.md 的硬規則與 manuscript-jsonl-sync 的規則寫明說的是帳冊，不含綱要檔。

- 驗收時找到的（規格對指令的對照表 16 處、31 列逐列核對 3 處、盲讀者 1 處歧義）：
  - 改指令的四處，都是現有的檢查沒做到它宣稱的事：寫入檢查回報 JSON 沒有的數字（jq 會把 `nan` 讀進來，存進確認紀錄後變成 null，該節剛確認就顯示不同）；label 的值也把連續空白算成一個空格，與已經壓平的檔案文字一致；第一個指令印出缺少的是哪一個工具；列帳冊時每個 _meta.json 各跑一次 jq，壞掉的那一個只少掉自己那一行。
  - 其餘收窄句子：submodule 以 git 回報的為準；根目錄底下另一個獨立 repo 的檔算在裡面，反過來外層的帳冊不算；經 `..` 繞回 repo 裡的路徑以它實際指到的位置判定；label 與 starts 都有時兩個都要只出現一次；lines 與 commit 的值不檢查；尚未存在的綱要目錄，它的上一層要存在；三個路徑要從 `/` 寫起；確認時比對的是節檔與段落檔；守門停下時輸入檔還在，第 1 步會清掉；git 忽略的檔會被讀取並交給 checker；空的確認紀錄檔算沒有紀錄；`points` 是空清單或缺少時沒有工具檢查。

## Non-Goals

- 綱要檔的驗證器與各條 requirement 的可執行測試：仍延後到 #78（排在 Swift package #46 之後）。
- 照綱要把文字寫進稿件：#51。
- 第二輪報告裡列為後續的 6 項（#82、#67，以及要記進 #78、#51 的說明、#77 的更正）不在這個 change 處理。
- 報告裡提出的四項更正（決定留言、#78 與 #77 的正文、一則舊留言）由使用者決定，這個 change 不動。
- 第 34 列的三件事：封存的 proposal 與 design 不改（封存目錄受保護）；範圍已在 2026-11-15 的決定定案，移到 #51，寫在這份 proposal 的 Non-Goals。決定留言裡的項數屬於上一項的更正。#52 列進這一輪的 Implementation Complete 的「還沒有定案的事」。

## Success Criteria

- SKILL.md 的 18 段指令照寫法逐段實跑，zsh 與 bash、Homebrew 的 jq 與系統內建的 jq 四種組合，各 168 項全部符合預期。新增的情境含：兩層 submodule、不是 submodule 的內層 repo、三層 submodule；帳冊在 submodule 裡、在外層、指到別的檔、指到不存在的檔、沒有 source.file；綱要目錄在 .git 底下；nan 與 NaN；label 裡的連續空白；缺 jq 或 git 時印出缺哪一個；壞掉的 _meta.json 不讓其他帳冊消失；沒有 git；暫存目錄在 repo 裡或不見了；綱要目錄是一般檔案；只有確認紀錄檔；節的紀錄帶 points；from 與 basis 不是清單（含空清單、null、數字）；註解裡的 label；路徑含換行；空的、兩個值的、壞掉的 _meta.json；指不到節的段落紀錄（狀態與確認）；只剩 uses 指著的 id；讀不到的確認紀錄檔。
- `propositions:outline-checker` 在只載入這個 plugin 的 Claude Code 裡實際啟動一次：清單上它的工具只有 Read，對一份測試綱要回報了預期的三項。
- 一位獨立 agent 對照第二輪報告這一輪要處理的 31 列（第 1 到 12、14 到 21、23 到 30、32、34、36 列），逐列回報已處理與在哪一句；沒有未處理的。另外 6 列（第 13、22、31、33、35、37 列）是後續，已有去處。
- 一位獨立 agent 做規格對指令的對照表：規格說會檢查或會擋下的每一件事，都找得到做這件事的指令；指令做的每一項檢查，規格與文件都寫了。
- 只拿到 OUTLINE.md 的讀者，對這一輪改過的規則答得與預存的答案相同。
- 全套 pytest 通過；spectra validate 與 spectra analyze 對這個 change 沒有錯誤。

## Impact

- Affected specs: `article-outline`（修改 11 條 requirement）
- Affected code:
  - Modified: `plugins/propositions/skills/outline/SKILL.md`
  - Modified: `plugins/propositions/docs/OUTLINE.md`
  - Modified: `plugins/propositions/README.md`
  - Modified: `plugins/propositions/rules/manuscript-jsonl-sync.md`
  - Modified: `README.md`
  - Modified: `CLAUDE.md`
  - Modified: `.claude/rules/swift-is-the-implementation-language.md`
  - New: `plugins/propositions/agents/outline-checker.md`
  - Removed: (none)
