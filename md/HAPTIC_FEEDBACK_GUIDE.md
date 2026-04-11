# Milery 震動回饋指南

本文件列出 App 中所有適合加入震動回饋（Haptic Feedback）的互動點，依畫面分類並標註建議的回饋類型與優先順序。

## 目錄

1. [現有震動回饋](#現有震動回饋)
2. [回饋類型說明](#回饋類型說明)
3. [建議新增位置](#建議新增位置)
4. [實作優先順序](#實作優先順序)

---

## 現有震動回饋

目前 App 已在以下 4 處使用震動回饋：

| 檔案 | 互動 | 類型 |
|------|------|------|
| `OnboardingView.swift` | 數字鍵盤按鍵 | Impact light |
| `OnboardingView.swift` | 歡迎頁長按按鈕 | Impact heavy |
| `SettingsView.swift` | 版本資訊長按（開發者彩蛋） | Notification success |
| `ProfileEditView.swift` | 複製好友碼 | Notification success |
| `FriendsView.swift` | 複製好友碼 | Notification success |

---

## 回饋類型說明

| 類型 | API | 適用情境 |
|------|-----|----------|
| **Impact light** | `UIImpactFeedbackGenerator(style: .light)` | 按鈕點擊、導航跳轉 |
| **Impact medium** | `UIImpactFeedbackGenerator(style: .medium)` | 重要操作確認（儲存、同步） |
| **Impact heavy** | `UIImpactFeedbackGenerator(style: .heavy)` | 強調動作（長按觸發） |
| **Selection** | `UISelectionFeedbackGenerator()` | 選項切換、Picker 變更、Toggle |
| **Notification success** | `UINotificationFeedbackGenerator(.success)` | 操作成功（複製、儲存完成） |
| **Notification warning** | `UINotificationFeedbackGenerator(.warning)` | 破壞性操作確認（刪除） |
| **Notification error** | `UINotificationFeedbackGenerator(.error)` | 操作失敗、錯誤提示 |

---

## 建議新增位置

### 1. MainTabView — Tab 切換

| 互動 | 類型 | 說明 |
|------|------|------|
| 切換底部 Tab | Selection | 切換主要頁面時的輕微觸感 |

### 2. DashboardView — 儀表板

| 互動 | 類型 | 說明 |
|------|------|------|
| 同步按鈕 | Impact medium | 手動觸發同步 |
| 可兌換雷達卡片點擊 | Impact light | 進入目標詳情 |
| 夢想雷達卡片點擊 | Impact light | 進入目標詳情 |
| 近期活動卡片點擊 | Impact light | 進入帳本 |

### 3. CalculatorLedgerView — 計算機帳本

| 互動 | 類型 | 說明 |
|------|------|------|
| 儲存交易 | Impact medium | 交易新增成功 |
| 切換計算機/帳本模式 | Selection | 頁面模式切換 |

### 4. TransactionFormView — 交易表單

| 互動 | 類型 | 說明 |
|------|------|------|
| 信用卡/其他來源切換 | Impact light | 表單類別切換 |
| 選擇信用卡 | Selection | 卡片選取 |
| 選擇消費來源 | Selection | 來源選取 |
| 選擇子類別 | Selection | 子類別選取 |

### 5. EditTransactionView — 編輯交易

| 互動 | 類型 | 說明 |
|------|------|------|
| 儲存修改 | Impact medium | 確認修改成功 |
| 點擊刪除按鈕 | Impact light | 發起刪除 |
| 確認刪除 | Notification warning | 破壞性操作確認 |

### 6. LedgerView — 帳本

| 互動 | 類型 | 說明 |
|------|------|------|
| 展開/收合統計區 | Selection | 區塊展開切換 |
| 新增交易按鈕 | Impact light | 開啟表單 |
| 點擊交易進入編輯 | Impact light | 導航至編輯頁 |

### 7. ProgressView — 進度

| 互動 | 類型 | 說明 |
|------|------|------|
| 新增目標按鈕 | Impact light | 開啟新增 sheet |
| 目標排序拖曳 | Selection | 排序變更 |
| 點擊目標進入編輯 | Impact light | 導航至編輯頁 |

### 8. AllGoalsView — 所有目標

| 互動 | 類型 | 說明 |
|------|------|------|
| 目標釘選/取消釘選 | Selection | 切換釘選狀態 |
| 兌換目標 | Notification success | 完成兌換 |
| 刪除目標 | Notification warning | 破壞性操作 |

### 9. MilestonesView — 里程碑

| 互動 | 類型 | 說明 |
|------|------|------|
| 開啟記錄 sheet | Impact light | 查看詳細紀錄 |
| 地圖/列表切換 | Selection | 模式切換 |

### 10. SettingsView — 設定

| 互動 | 類型 | 說明 |
|------|------|------|
| iCloud 同步開關 | Selection | 重要設定切換 |
| 主題選擇 | Selection | 外觀偏好變更 |
| 生日月份選擇 | Selection | Picker 選取 |
| 導航至子頁面 | Impact light | 各設定列點擊 |

### 11. OnboardingView — 首次引導

| 互動 | 類型 | 說明 |
|------|------|------|
| 選擇頭貼（PhotosPicker） | Selection | 照片選取 |
| 選擇里程計畫 | Impact light | 重要初始設定 |
| 選擇銀行/卡別 | Selection | 卡片設定 |
| 選擇出發機場 | Impact light | 機場 Picker |
| 選擇生日月份 | Selection | 月份格子選取 |
| 選擇主題 | Selection | 外觀選取 |
| iCloud 同步選項 | Impact light | 同步偏好 |
| 通知權限按鈕 | Impact medium | 系統權限請求 |
| 上一步/下一步按鈕 | Impact light | 頁面導航 |
| 完成 Onboarding | Notification success | 設定流程完成 |

### 12. FriendsView — 好友

| 互動 | 類型 | 說明 |
|------|------|------|
| 開啟加好友 sheet | Impact light | 開啟輸入畫面 |
| 接受好友邀請 | Notification success | 社交關係建立 |
| 拒絕好友邀請 | Notification warning | 拒絕操作 |
| 刪除好友 | Notification warning | 破壞性操作 |
| 下拉重新整理 | Impact light | 觸發更新 |

### 13. ProfileEditView — 個人資料編輯

| 互動 | 類型 | 說明 |
|------|------|------|
| 更換頭貼（PhotosPicker） | Selection | 照片選取 |
| 刪除頭貼 | Notification warning | 破壞性操作 |
| 名稱儲存完成 | Notification success | 資料更新成功 |

### 14. CreditCardPageView — 信用卡管理

| 互動 | 類型 | 說明 |
|------|------|------|
| 卡片啟用/停用 | Selection | 切換卡片狀態 |
| 等級選擇 | Selection | 卡片等級切換 |
| 資訊按鈕 | Impact light | 展示詳細說明 |

### 15. 背景與圖示

| 檔案 | 互動 | 類型 | 說明 |
|------|------|------|------|
| `BackgroundPickerView` | 選擇背景 | Selection | 背景偏好切換 |
| `AppIconPickerView` | 選擇 App 圖示 | Selection | 圖示偏好切換 |

### 16. CloudBackupView — 備份還原

| 互動 | 類型 | 說明 |
|------|------|------|
| 建立備份 | Impact medium | 發起備份 |
| 備份完成 | Notification success | 備份成功 |
| 還原確認 | Notification warning | 破壞性操作 |
| 還原完成 | Notification success | 還原成功 |
| 刪除備份 | Notification warning | 破壞性操作 |

### 17. AppLockSettingsView — 密碼鎖設定

| 互動 | 類型 | 說明 |
|------|------|------|
| 啟用/停用密碼鎖 | Selection | 安全設定切換 |
| 啟用/停用生物辨識 | Selection | 安全設定切換 |
| 修改密碼完成 | Notification success | 設定更新 |

### 18. NotificationSettingsView — 通知設定

| 互動 | 類型 | 說明 |
|------|------|------|
| 通知開關切換 | Selection | 通知偏好變更 |
| 時間選取 | Selection | 通知時間設定 |

### 19. ProgramSwitcherView — 里程計畫

| 互動 | 類型 | 說明 |
|------|------|------|
| 切換計畫 | Impact medium | 主計畫切換 |
| 新增計畫 | Impact light | 開啟新增 |
| 刪除計畫 | Notification warning | 破壞性操作 |

---

## 實作優先順序

### Tier 1 — 高優先（核心操作）

使用者最常觸發的操作，震動回饋能顯著提升操作手感。

- 交易儲存/刪除（CalculatorLedgerView、EditTransactionView）
- Tab 切換（MainTabView）
- 表單選項切換（TransactionFormView）
- 好友操作（接受/拒絕/刪除）
- 目標兌換

### Tier 2 — 中優先（設定與選擇）

設定頁面與 Onboarding 中的選取操作。

- 設定頁 Toggle（iCloud 同步、通知）
- Onboarding 各步驟選擇（計畫、卡片、生日）
- Dashboard 卡片點擊
- 背景/圖示選擇
- 備份/還原操作

### Tier 3 — 低優先（細節打磨）

完善整體操作體驗的收尾項目。

- 帳本統計展開/收合
- 導航跳轉（Settings 子頁面）
- 資訊按鈕點擊
- 頁面上下一步按鈕

---

## 統計

| 項目 | 數量 |
|------|------|
| 已有震動回饋 | 5 處 |
| 建議新增 | 65+ 處 |
| 涵蓋畫面 | 19 個 View |
