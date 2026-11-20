## 1. 指令

- [x] 1.1 兩處 submodule 檢查改用 `-z` 輸出、先確認 git 成功、比對綱要目錄本身；換 root 的指令確認 repository 包含綱要目錄。對應 Requirement「The outline is three files beside the ledger」。完成時：三個漏洞各有驗收案例或由寫法排除。

## 2. 文字

- [x] 2.1 SKILL.md、OUTLINE.md、規格：提示的觸發條件、被報出的情形、新 session 的條件、限制 8、保證 2，對應 Requirement「The outline skill writes only the three outline files」；「No executable check」的理由，對應 Requirement「A locator names a passage by a label or by its opening words」。

## 3. 驗證

- [x] 3.1 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。
