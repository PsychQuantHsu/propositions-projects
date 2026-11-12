## 1. 守衛測試（先寫，要看到失敗）

- [x] 1.1 在 `tests/test_plugin_payload_tracked.py` 改守衛的常數，對應 Requirement「Entries are preconditions or obligations」「A check is named only when it is implemented」「An article is sound only when every applicable entry passes」：釘住的缺口加上 `index.profile-fits-manuscript`（前提、`owner` 70）；必要的 owner 加上 70；說明文件要寫出的 issue 加上 `#68`、`#69`、`#70`；文件要寫出的字改成 `suspicious` 與 `examined`（拿掉 `--partial` 與 `evidence_snapshot`，那兩段規則刪掉了）。不新增測試函式。驗證：改表與文件之前 `pytest tests/test_plugin_payload_tracked.py -k obligations` 有兩個失敗，訊息指名缺的列、issue 與字。

## 2. 義務表

- [x] 2.1 改 `plugins/propositions/catalog/obligations.yaml`：新增缺口 `index.profile-fits-manuscript`（前提、整篇、`owner` 70）；改寫 `completeness.thesis-stated`、`index.extraction-covers-text`、`index.cites-complete` 的判準；`unconstrained` 裡 `abstract` 的說明改成「這種發現算在指名 S5 的列」；檔頭對 `info` 的說明改成「列出、不算」。驗證：表有 67 列、15 列缺口；守衛除了文件的案例之外全部通過。

## 3. 文件

- [x] 3.1 改 `plugins/propositions/docs/OBLIGATIONS.md`，對應 Requirement「Each entry has one of four outcomes for a unit」「Applicability is a list of field values」：結果改成五條規則（適用條件讀不出來是沒檢查；機械檢查要報告列出這個單位才通過；判定過的發現；驗證紀錄要算數才決定）；寫明通過的意思；新增「報告要顯示什麼」一節並說明現在沒有檢查做到；刪掉「檢查沒跑過」的七種情況與 R9 的特例；發現算在哪一列、哪個單位改成一定算得到；適用條件讀不出來的三種情形；實證層的理由與引用技能的那一句改正。驗證：文件裡找不到 `evidence_snapshot` 與 `--partial`。
- [x] 3.2 同一個檔案，對應 Requirement「An article is sound only when every applicable entry passes」「A check is named only when it is implemented」「Entries are preconditions or obligations」：紀錄什麼時候算數改成「紀錄自己要顯示兩件事，現在的格式都顯示不出來」；過不了的原因改成四個（加上 #68），另列三個之後仍在的限制（#59、#69、#64）；檢查清單的共同性質與定理邊界稽核的排除理由改正；第二個沒有檢查的前提（profile 符合稿件，#70）。驗證：1.1 的案例通過。
- [x] 3.3 改 `plugins/propositions/docs/VERIFICATION.md` 指到 `docs/OBLIGATIONS.md` 的兩段，讓兩份文件說法一致：現在的紀錄格式看不出是哪一種閱讀、讀的是哪個版本，所以照義務表目前沒有紀錄算數；「最新一筆」只用於 disagreement 警告。驗證：`pytest tests/test_verification_records.py` 通過。

## 4. 獨立讀者盲驗

- [ ] 4.1 先把答案存檔：規格的二十個範例情況、三個判定文章是否完全合理的 Scenario、R3 拆成兩列的一題，共二十四題。再派一個只讀得到資料檔、說明文件與題目的讀者（放在 repo 以外的暫存目錄，回報它讀了哪些檔）。把題目、讀者的答案、相同的題數與對應的 commit 貼在 #47。有不同就改說明文件、派新的讀者重跑。驗證：二十四題全部相同，#47 有那則紀錄。

## 5. 其他 issue 上的紀錄

- [ ] 5.1 新開 #68（每條檢查回報它檢查過的單位，#63 併入）、#69（稽核腳本只讀主檔）、#70（帳冊的分類對不對沒有檢查），加進 #45 的子題清單。在 #57（L 層對實證命題的定義、E 層多報的發現）與 #66（主旨清單是否真的是主旨）各留一則 note。內文過隱私自審。驗證：三張 issue 存在，#45 的 Children 有它們，兩則 note 都貼出。

## 6. 驗收

- [ ] 6.1 全套 `pytest tests/` 通過，`test_obligations_` 的案例沒有被跳過；`spectra validate idd-47-fix2` 通過；`plugins/propositions/scripts` 與 `plugins/tschema-check` 相對於 main 沒有變動。驗證：貼出三項的輸出。
- [ ] 6.2 維護者回答四件事之後才做：封存這個 change、貼完成紀錄、跑第三輪驗證。四件事是審表之後動過的列、Swift 規則的例外、「外部工具」的標記、這個 change 的「通過的條件」。驗證：#47 有維護者的回覆。
