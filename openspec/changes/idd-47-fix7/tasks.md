## 1. 義務表

- [x] 1.1 改 `plugins/propositions/catalog/obligations.yaml`，對應 Requirement「Applicability is a list of field values」：`index.data-claims-carry-data-class` 的判準限定為這篇稿件自己的資料得出的數字或結果，上方的註解寫明轉述別人研究與只做詮釋的句子不在這一列；`index.profile-valid` 的判準補上「照帳冊的 schema 版本」。驗證：守衛通過，兩條判準都在 200 字元以內，表仍是 70 列。

## 2. 文件

- [x] 2.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Applicability is a list of field values」「An article is sound only when every applicable entry passes」「The explanatory document describes the table without restating it」：資料主張那一列問的是什麼、不問什麼；帳冊的行怎麼算空的與註解；一行兩個 `id` 鍵取最後一個；default 帳冊的數字那一段；描述守衛的那一段。驗證：文件裡找不到「has no artifacts to compare with」與「still points」。

## 3. 其他 issue

- [x] 3.1 #70 的正文：Expected 第 3 條改成和新判準一樣的寫法；把兩個欄位一起寫成「還沒有規定」的兩處，改成 `SCHEMA.md` 把 `claim_type` 列為必填、`evidence_class` 選填、沒有驗證器擋。#46 留 note：守衛的拒絕只有兩組案例有掃描，其他釘選與 11 處拒絕拿掉後測試仍通過，搬到 Swift 時一起處理。驗證：兩處都找得到。

## 4. 獨立讀者盲驗

- [ ] 4.1 題目沿用修正輪 6 的 48 題，加上這一輪改到的情形（轉述別人研究的 `external` 命題、前面有空白的註解行、一行兩個 `id` 鍵、default 帳冊的數字）。答案先存檔；派新的讀者，只給表、文件與題目。紀錄貼成 #47 上一則新的留言。驗證：全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 5. 驗收

- [ ] 5.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix7` 通過；`plugins/propositions/scripts`、`plugins/tschema-check` 與 `tests/` 相對於上一個封存的 commit 沒有變動。驗證：貼出三項的輸出。
