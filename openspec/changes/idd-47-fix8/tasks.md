## 1. 義務表

- [x] 1.1 改 `plugins/propositions/catalog/obligations.yaml`，對應 Requirement「Applicability is a list of field values」：資料主張那一列上方的註解寫明它不問的是沒有回報自己資料的數字或結果的句子，一句話裡兩種結果都有時照樣要問；`index.profile-valid` 的判準改成直接描述驗證器怎麼定 profile。驗證：守衛通過，判準在 200 字元以內，表仍是 70 列。

## 2. 文件

- [x] 2.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Applicability is a list of field values」：那一列不問什麼、兩種結果都有的句子怎麼算；三句說明（「回報」的意思、模型與模擬的輸出、由自己的數字算出來的數字）；舊的說法「rests on data」換掉。驗證：文件裡找不到「rests on data」。

## 3. 其他 issue

- [x] 3.1 #70 正文的 Expected 第 3 條改成和文件一樣的寫法（只不問沒有回報自己資料的句子、兩種結果都有時要問、三句說明）。驗證：#70 的正文找得到「同時」這一種情形。

## 4. 獨立讀者盲驗

- [ ] 4.1 題目沿用修正輪 7 的 52 題，加上這一輪改到的情形（兩種結果都有的句子、模擬的結果、資料算不出來的量、沒有宣告 profile 而 schema 版本較舊的帳冊）。答案先存檔；派新的讀者，只給表、文件與題目。紀錄貼成 #47 上一則新的留言。驗證：全部相同，紀錄上的 commit 是最後一個改到表或文件的 commit。

## 5. 驗收

- [ ] 5.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix8` 通過；`plugins/propositions/scripts`、`plugins/tschema-check` 與 `tests/` 相對於上一個封存的 commit 沒有變動。驗證：貼出三項的輸出。
