## Why

作者想先把整篇文章的綱要定下來、確認過，再動筆（#75）。現有的檔案放不下還沒寫的內容：帳冊只記稿件裡已有的文字，結構附檔的每一節、每一段都必須指到帳冊裡已存在的命題，也沒有欄位放「這一段要說什麼」。維護者手上有一篇寫完、要大幅重排的稿件，需要一份可以討論、可以對回原稿的重排計畫。

## What Changes

- 新增三個放在帳冊旁的檔案，合稱綱要：
  - 文章層 outline-sections.jsonl，一節一筆，每節一句話寫這一節要說什麼。
  - 段落層 outline-paragraphs.jsonl，一段一筆，每段至少一句要點；可以記這一段來自原稿的哪些地方、是不是原樣搬動、有沒有被刪除與理由。
  - 確認紀錄 outline-approvals.jsonl，一筆一次確認，存下作者通過當時那幾節與它們的段落的內容。
- 新增 skill `/propositions:outline`，六個動作：從寫完的稿反推綱要、從題目或作者的大綱起草、依作者的指示修改、交給作者之前的前提檢查、記錄作者的確認、回報狀態。它只寫上面三個檔，不寫稿件、帳冊與結構附檔。
- 新增說明文件，寫明三個檔的格式、來源怎麼指回原稿、什麼算確認、一節在什麼情況下要重新確認。
- 把新的 skill 與檔案列進 repo 與 plugin 的說明文件與 schema 文件的檔案配置；`propositions` 升到 0.12.0。
- 帳冊的 schema、結構附檔、R1–R13、S1–S9、`analyze` 的七個狀態、義務表與所有既有腳本都不變。

## Non-Goals (optional)

（design.md 會寫 Goals 與 Non-Goals。）

## Capabilities

### New Capabilities

- `article-outline`: 綱要的三個檔案的格式、來源指標、確認紀錄與「一節是否仍照通過時的內容」的判定，以及 `/propositions:outline` 六個動作的行為與它不做的事。

### Modified Capabilities

(none)

## Impact

- Affected specs: `article-outline`（新增）
- Affected code:
  - New:
    - plugins/propositions/docs/OUTLINE.md
    - plugins/propositions/skills/outline/SKILL.md
  - Modified:
    - README.md
    - CLAUDE.md
    - plugins/propositions/README.md
    - docs/SCHEMA.md
    - plugins/propositions/.claude-plugin/plugin.json
    - .claude-plugin/marketplace.json
  - Removed: (none)
- 相關 issue：#75（這個 change）、#51（照綱要擴寫與比對，不在這個 change）、#52（從題目排綱要，內容由起草這個動作涵蓋）、#46（Swift package，綱要檔的機械檢查要等它）。
