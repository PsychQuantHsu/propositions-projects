## 1. 指令

- [x] 1.1 守門改成向 git 比對綱要目錄的 repository 與 root，並擋沒 checkout 的 submodule；拿掉記號。換 root 的指令拿掉 `NOTE`、擋沒 checkout 的 submodule、分開 `M` 的兩個訊息。對應 Requirement「The outline is three files beside the ledger」。完成時：每一種停下都有驗收案例。

## 2. 文字

- [x] 2.1 SKILL.md、OUTLINE.md、README：舊綱要的說明、暫存目錄與守門的段落、保證 2、限制 8、殘留的 "the repository"。對應 Requirement「The outline skill writes only the three outline files」。
- [x] 2.2 規格：排成 repository 樣子的目錄、四個情境、「No executable check」的理由。對應 Requirement「Text from the manuscript and the author never becomes part of a command」。

## 3. 驗證

- [x] 3.1 八種組合全過；`spectra validate` 與 `pytest tests/` 通過。
