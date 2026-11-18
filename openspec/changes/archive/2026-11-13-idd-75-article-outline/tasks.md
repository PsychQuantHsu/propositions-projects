## 1. 說明文件

- [x] 1.1 新增說明文件 plugins/propositions/docs/OUTLINE.md 的格式部分（英文，比照同目錄的其他文件）。照 design「綱要分成三個檔，放在帳冊旁」「段落紀錄以要點為單位，至少一句」「來源用 label 或開頭文字指回原稿」「沒有列出的鍵原樣保留」寫出三個檔與每一個鍵，對應 Requirement「The outline is three files beside the ledger」「A section record says in one sentence what the section says」「A paragraph record holds at least one point」「A locator names a passage by a label or by its opening words」。完成時：只讀這份文件的人能判定一筆紀錄合不合格式。驗證：對照規格的四張表逐鍵核對，文件裡每個必填與選填的鍵都有說明，三個檔名都出現。
- [x] 1.2 同一份文件的確認部分。照 design「確認紀錄存下通過當時的內容，以節為單位」「只有作者當次明說才算確認」寫確認紀錄的鍵、三個判定與五種不算確認的情況，對應 Requirement「An approval record stores what the author approved」「A section stands as approved while it equals its latest approved copy」「Only the author's explicit statement in the current message approves」。完成時：文件寫出規格 Scenario「What one change does to the three conditions」的八種改動各自讓哪個判定不成立。驗證：對照規格那張表逐列核對。
- [x] 1.3 同一份文件的動作與界線：六個動作各讀什麼、寫什麼；前提檢查的六種結果（design「前提檢查由另一個 agent 做，結果只呈現不改綱要」）；修改時的規則（design「修改時不丟來源，刪除是標記」）；這個功能不寫稿件、照綱要寫屬於 issue 51；沒有機械檢查、要等 issue 78（design「機械檢查與測試留給 #78」）。對應 Requirement「A premise check runs before an outline is shown for approval」「Revising keeps ids stable and never loses a source」「The explanatory document describes the outline」。驗證：文件裡找得到六個動作的名稱、六種結果的名稱，以及 issue 51 與 78。

## 2. Skill

- [x] 2.1 新增 skill 檔 plugins/propositions/skills/outline/SKILL.md 的骨架：frontmatter、怎麼找到稿件與綱要檔的路徑、六個動作的入口，以及 design「skill 只寫三個綱要檔」的界線，對應 Requirement「The outline skill writes only the three outline files」。完成時：skill 明寫不寫稿件、帳冊、結構附檔與驗證紀錄，不改寫或刪除確認紀錄；每次寫入後用 jq 確認每一行是 JSON 物件、id 沒有重複，失敗時回報檔名與行、不回報成功；回報裡說明在 issue 78 之前沒有其他格式檢查。驗證：tests/test_plugin_payload_tracked.py 全部通過（skill 名稱不重複、相對連結指到已追蹤的檔）；skill 的文字裡沒有交給直譯器執行的程式本體。
- [x] 2.2 skill 的反推與起草兩個動作，對應 Requirement「Derive and draft build an outline without inventing content」。完成時：反推出來的每一筆都有來源、要點只說來源說的、定理的陳述與證明與圖表與推導各成一筆並標上 carry；起草時作者沒給的結果、數字、引用標上 pending 而不寫出內容；兩個動作都先給作者看、作者同意才寫檔，而且同意寫檔不算確認；已經有綱要檔時停下並指到修改。驗證：對照規格這條 Requirement 的三個 Scenario 逐條核對 skill 的步驟。
- [x] 2.3 skill 的修改、前提檢查、確認、狀態四個動作，對應 Requirement「Revising keeps ids stable and never loses a source」「A premise check runs before an outline is shown for approval」「Only the author's explicit statement in the current message approves」「A section stands as approved while it equals its latest approved copy」。完成時：修改之後回報哪些節不再照通過時的內容；前提檢查派出的 agent 只拿到綱要檔與來源指到的檔、看不到對話，而且派出時指定 model；確認只在作者當次明說時寫紀錄，五種不算的情況與規格一致；狀態不寫任何檔。驗證：對照規格四條 Requirement 的 Scenario 逐條核對。

## 3. 列入文件與版本

- [x] 3.1 [P] 把 skill 與三個檔列進 README.md、CLAUDE.md、plugins/propositions/README.md，並在 docs/SCHEMA.md 的檔案配置加上三個檔。完成時：讀這四份文件的人知道有 /propositions:outline 與綱要的三個檔，以及它們不改帳冊。驗證：四個檔都找得到 outline-paragraphs.jsonl 這個檔名。
- [x] 3.2 [P] 把 propositions plugin 升到 0.12.0（plugin 的 plugin.json 與 marketplace.json 兩處），marketplace 的描述提到綱要。驗證：tests/test_marketplace_entries.py 與 tests/test_plugin_payload_tracked.py 通過，兩處版本相同。

## 4. 驗收

- [x] 4.1 獨立讀者盲驗。先把題目與答案存在 repo 以外的暫存目錄；題目涵蓋格式（必填的鍵、來源指標的四種寫法、原樣搬動、刪除的標記）、三個判定（規格的八種改動）、五種不算確認的情況、修改的規則、前提檢查的六種結果。派一個只拿到說明文件與題目的 subagent（指定 model），要它回報讀了哪些檔。驗證：讀者的答案與預存的答案全部相同；有不同就改文件、換一位新的讀者重跑；題數與結果記到 #75，不含稿件文字。
- [x] 4.2 全套 pytest 通過；spectra validate 對這個 change 通過；相對於 main，plugins/propositions/scripts、plugins/tschema-check 與 tests 三個目錄沒有任何變動。驗證：貼出三項的輸出。
- [x] 4.3 交接留言：在 #51、#52、#49、#54 說明範圍的提議與格式寫在哪裡；在 #78 列出規格裡沒有可執行檢查的十二條 Requirement。驗證：五張 issue 都有那則留言。
