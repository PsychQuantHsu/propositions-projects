## Why

Marketplace 宣告要發佈的 core plugin，其**大部分內容從未進入版本控制**。`.gitignore` 內那條 `propositions/` 是未錨定 pattern（無前導斜線、無內嵌斜線），git 會用它匹配**任意深度**的同名目錄，因此整個 `plugins/propositions/` 被吞掉。`git check-ignore -v` 對三個路徑全部指向同一條規則（以下為當時的原始輸出，行號為診斷時的位置）：

```
.gitignore:24:propositions/  plugins/propositions/.claude-plugin/plugin.json
.gitignore:24:propositions/  plugins/propositions/README.md
.gitignore:24:propositions/  plugins/propositions/skills/proofread/SKILL.md
```

`plugins/propositions/scripts/` 之所以倖存，只因為它是 `git mv` 搬進來的——ignore 規則對已追蹤檔案無效。`git add` 對被 ignore 的檔案是**靜默跳過**，所以整個過程沒有任何錯誤訊息；本地工作目錄看起來一切正常，遠端卻只有 `scripts/`。

後果是可觀測的：安裝端從 GitHub 註冊此 marketplace 時，`./plugins/propositions` 目錄下取不到 plugin manifest，plugin 解析不出來。`umbrella-marketplace-migration` 的 task 5.4（安裝端切換驗證）已因此被記為 BLOCKED。

診斷過程中另外查出三項同源缺陷（同屬「published payload 與宣稱不符」）：

1. **根層三個 skill 是失效遺留，且與移植進來的 skill 功能重疊**。`skills/validate`、`skills/refresh-locations`、`skills/audit` 三者都寫死 `~/.claude/plugins/cache/propositions` —— marketplace 已於 task 4.1 改名為 `propositions-projects`，安裝端 cache 佈局是 `cache/<marketplace>/<plugin>/<version>/`，這條路徑改名後不再存在。同時，移植進來的 `propositions` skill 的 Operation A / B 已完整涵蓋 `validate` 與 `refresh-locations`（並多出 Operation C 抽取），`manuscript-audit` 已涵蓋 `audit`，且兩者都用改名後的正確路徑解析。根層 `plugin.json` 又已於 task 2.1 移除，這三個 skill 現在不屬於任何 manifest。
2. **`proofread` 有兩份分歧副本**。根層那份自述 `Status (v0.1.0) — Scaffolding only. 執行本體 TODO`；plugin 內那份是完成版（含 6 層程序、ROI 數據、provenance）。兩份無任何機制保證同步，而 repo 追蹤的偏偏是 scaffolding 那份。
3. **四個移植 skill 全部殘留舊 marketplace 命名空間**。共 19 處 `/math-tools:<skill>` 形式的交互引用（`propositions` 6 處、`proofread` 6 處、`manuscript-audit` 4 處、`clarity-audit` 2 處敘述用語、plugin README 1 處 sibling-pack 句）。task 5.2 已移除 `math-tools` entry、README 亦明載「本 marketplace 不發佈 math-tools plugin」，因此使用者照著 shipped skill 的指示打 `/math-tools:propositions` 會打到不存在的命令。

## What Changes

- `.gitignore` 的 `propositions/` 與 `manuscript/` 兩條 pattern 加前導斜線錨定為 `/propositions/` 與 `/manuscript/`，只擋 repo 根層由 conftest 產生的 shim，不再擋任意深度同名目錄。註解同步說明「錨定是必要的，不是風格偏好」。
- 把 `plugins/propositions/.claude-plugin/plugin.json`、`plugins/propositions/README.md`、以及四個既有 skill（`clarity-audit` / `manuscript-audit` / `proofread` / `propositions`）納入版本控制。這些檔案目前只存在於主 checkout 的工作目錄，從未進 git。
- 退役根層 `skills/validate`、`skills/refresh-locations`、`skills/audit` 三個失效遺留 skill；其能力由 plugin 內的 `propositions`（Operation A/B/C）與 `manuscript-audit` 承接。根層 `skills/` 目錄清空。
- 刪除根層 scaffolding 版 `skills/proofread`，以 plugin 內的完成版為唯一實體。
- 把四個 skill 內 19 處 `/math-tools:` 交互引用改為本 marketplace 實際發佈的 `/propositions:` 命名空間；plugin README 移除指涉 `math-tools` sibling pack 的過時句。
- 更新 README.md 的 Quick start 與 CLAUDE.md 的 skill 對照表，改列實際發佈的四個 skill 名稱與其用途，取代已退役的 `validate` / `refresh-locations` / `audit`。
- 新增機械測試，斷言 marketplace 每個 entry 的 plugin 目錄下，manifest 與所有 skill 檔案都是 **git-tracked**（不只是存在於磁碟）、repo 內不存在同名 skill 的重複定義、且 shipped skill 內不再出現 `/math-tools:` 命名空間。

## Capabilities

### New Capabilities

- `plugin-payload-integrity`: marketplace 發佈的 plugin 目錄，其 payload 必須完整存在於版本控制中、與文件宣稱一致、且不存在重複的 skill 定義

### Modified Capabilities

(none)

## Impact

- Affected specs: `plugin-payload-integrity`（新增）
- Affected code:
  - Modified: `.gitignore`、`plugins/propositions/README.md`、`README.md`、`CLAUDE.md`
  - New: `plugins/propositions/.claude-plugin/plugin.json`、`plugins/propositions/skills/clarity-audit/SKILL.md`、`plugins/propositions/skills/manuscript-audit/SKILL.md`、`plugins/propositions/skills/proofread/SKILL.md`、`plugins/propositions/skills/propositions/SKILL.md`、`tests/test_plugin_payload_tracked.py`
  - Removed: `skills/validate/SKILL.md`、`skills/refresh-locations/SKILL.md`、`skills/audit/SKILL.md`、`skills/proofread/SKILL.md`
- 解除 `umbrella-marketplace-migration` task 5.4 的阻塞（安裝端切換驗證）
