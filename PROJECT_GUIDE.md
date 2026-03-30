# Milery 專案指南

---

## 目錄

- [專案架構總覽](#專案架構總覽)
- [核心入口](#核心入口)
- [設計系統](#設計系統)
- [資料模型 (Models)](#資料模型-models)
- [信用卡系統 (CardDefinitions)](#信用卡系統-carddefinitions)
- [資料庫 (Database)](#資料庫-database)
- [ViewModel](#viewmodel)
- [服務層 (Service)](#服務層-service)
- [畫面 (Views)](#畫面-views)
- [開發者工具 (DevViews)](#開發者工具-devviews)
- [資料儲存與同步](#資料儲存與同步)
- [常見操作流程](#常見操作流程)
- [新增 / 更新指南](#新增--更新指南)

---

## 專案架構總覽

```
milery/
├── MileryApp.swift                     # App 入口、日誌系統、CloudKit 同步設定
├── AviationTheme.swift                 # 設計系統（顏色、字型、間距、陰影）
├── Models/
│   ├── Transaction.swift               # 交易模型 + MileageSource 列舉
│   ├── MileageAccount.swift            # 里程帳戶模型（含過期計算）
│   ├── FlightGoal.swift                # 飛行目標模型 + CabinClass 列舉
│   ├── RedeemedTicket.swift            # 已兌換機票模型
│   ├── CreditCardRule.swift            # 信用卡規則（記憶體中的計算模型）
│   ├── CardPreference.swift            # 信用卡偏好設定（SwiftData 持久化）
│   ├── MileageProgram.swift            # 里程計劃模型 + ActiveProgramManager
│   └── CardDefinitions/
│       ├── CardBrandDefinition.swift   # 信用卡品牌 Protocol + 支援類型
│       ├── CardBrandRegistry.swift     # 信用卡中央註冊表
│       ├── CathayUnitedBankCard.swift  # 國泰世華聯名卡定義
│       └── TaishinCathayCard.swift     # 台新國泰聯名卡定義
├── Database/
│   ├── CathayAwardChart.swift          # 國泰獎勵機票兌換計算
│   ├── AirportDatabase.swift           # 機場資料庫
│   └── airports.csv                    # 機場原始資料
├── ViewModels/
│   └── MileageViewModel.swift          # 主要狀態管理器
├── Service/
│   ├── CloudBackupService.swift        # 手動雲端備份/還原
│   └── DeveloperAccessService.swift    # 開發者存取控制
└── Views/
    ├── MainTabView.swift               # 根層 Tab 導覽
    ├── OnboardingView.swift            # 首次啟動引導（正式上線，9 頁）
    ├── DashboardView.swift             # 儀表板
    ├── ProgressView.swift              # 進度/目標
    ├── LedgerView.swift                # 帳本/交易紀錄
    ├── MilestonesView.swift            # 里程碑（地圖）
    ├── SettingsView.swift              # 設定頁面
    ├── TransactionFormView.swift       # 通用記帳表單
    ├── CreditCardPageView.swift        # 信用卡管理頁面
    ├── EditTransactionView.swift       # 編輯交易
    ├── CloudBackupView.swift           # 雲端備份 UI
    ├── AllGoalsView.swift              # 完整目標清單
    ├── CalculatorComponents.swift      # 可重用 UI 元件
    ├── CalculatorLedgerView.swift      # 計算器帳本
    └── DevViews/
        ├── DataManagementView.swift    # 資料檢視/清理
        ├── CloudKitAdvancedView.swift  # CloudKit 除錯
        ├── ConsoleLogView.swift        # 日誌檢視器
        ├── AirportListView.swift       # 機場瀏覽
        ├── ProgramSwitcherView.swift   # [⚠️開發中]里程計劃切換
        └── TabVisibilitySettingsView.swift # Tab 可見性設定
```

---

## 核心入口

### `MileryApp.swift`

App 的啟動入口，負責：

| 功能 | 說明 |
|------|------|
| **SwiftData 容器初始化** | 設定 `ModelContainer`，包含所有 Model Schema |
| **CloudKit 同步** | 若 `cloudKitSyncEnabled` 開啟，則使用 `iCloud.com.73app.milery` 容器 |
| **降級處理** | CloudKit 不可用時自動退回本地儲存 |
| **日誌系統** | `AppConsoleStore` 單例，最多 800 筆、保留 7 天 |
| **同步診斷** | `SyncDiagnosticsObserver` 監控 CloudKit import/export 事件 |

**全域函式：**
- `appLog(_ message: String)` — 記錄帶時間戳的日誌

**Schema 包含的模型：**
`MileageAccount`, `Transaction`, `FlightGoal`, `CreditCardRule`, `RedeemedTicket`, `CardPreference`, `MileageProgram`

---

## 設計系統

### `AviationTheme.swift`

集中管理整個 App 的視覺設計語彙，支援 Light/Dark 模式。

**顏色系統：**
- 品牌色：Cathay Jade、Starlux Gold、大地色系
- 自適應色：背景色、文字色根據外觀模式自動切換

**漸層：**
- Dark 金屬藍、Light 大地色、金屬金/銀、Cathay Jade 漸層

**排版：**
- 10 種文字樣式（`largeTitle` ~ `caption`）
- 專用等寬里程數字顯示

**間距 & 圓角 & 陰影：**
- 6 級間距（xs: 4pt ~ xxl: 48pt）
- 4 級圓角（sm: 8pt ~ xl: 20pt）
- 卡片陰影、深層陰影、金色光暈

**ViewModifier：**
- `MetalCardStyle` — 3D 金屬質感卡片
- `GlassmorphismStyle` — 毛玻璃效果
- `MetalButtonStyle` — 漸層按鈕（含按壓回饋）
- 快捷方法：`.metalCard()`、`.glassmorphism()`

---

## 資料模型 (Models)

### `Transaction.swift` — 交易記錄

每筆里程累積的交易紀錄。

**主要欄位：**
- `id`, `date`, `amount` (Decimal), `earnedMiles` (Int)
- `source` — `MileageSource` 列舉（10 種來源）
- `cardSubcategoryID` — 統一子類別 ID（取代舊版欄位）
- `cardBrand` — 使用的信用卡品牌
- `costPerMile` — 每哩成本（效率指標）
- `programID` — 所屬里程計劃
- `account` — 關聯到 `MileageAccount`

**MileageSource 列舉：**

| 值 | 說明 |
|----|------|
| `cardGeneral` | 一般刷卡 |
| `cardAccelerator` | 加速類別 |
| `taishinOverseas` | 台新海外 |
| `taishinDesignated` | 台新指定 |
| `flight` | 飛行累積 |
| `promotion` | 促銷活動 |
| `pointsConversion` | 點數轉換 |
| `pointsTransfer` | 點數移轉 |
| `specialMerchant` | 特約商店 |
| `ticketRedemption` | 機票兌換（負值） |

---

### `MileageAccount.swift` — 里程帳戶

代表一個里程帳戶，追蹤目前里程數與活動狀態。

**關鍵方法：**
- `updateMiles(amount:date:)` — 增減里程並更新活動日期
- `expiryDate()` — 計算過期日（最後交易後 18 個月）
- `daysUntilExpiry()` — 距離過期剩餘天數
- `latestActivityMonthText()` — 最後交易月份文字

**關聯：** 包含 `transactions` 與 `flightGoals`

---

### `FlightGoal.swift` — 飛行目標

使用者期望兌換的航線/艙等。

**主要欄位：** 出發/目的地 IATA 碼、艙等、所需里程、優先標記、排序順序

**關鍵方法：**
- `progress(currentMiles:)` — 回傳 0~1 進度比例
- `milesNeeded(currentMiles:)` — 還差多少里程

**CabinClass 列舉：** Economy / PremiumEconomy / Business / First

---

### `RedeemedTicket.swift` — 已兌換機票

記錄已成功兌換的飛行紀錄。

**主要欄位：** 花費里程、稅金、航線資訊、PNR 編號、兌換日期、關聯交易 ID

---

### `CreditCardRule.swift` — 信用卡規則（記憶體模型）

**用途：** 在記憶體中表示信用卡的累哩規則，用於即時計算。

**關鍵方法：**
- `calculateMiles()` — 根據金額/來源/等級計算里程
- `updateTier()` — 切換卡片等級並透過 Registry 更新費率

**費率欄位：** `baseRate`、`acceleratorRate`、`specialMerchantRate`（元/哩）

---

### `CardPreference.swift` — 信用卡偏好（持久化）

輕量級 SwiftData 模型，用於 CloudKit 同步。

**儲存內容：** 卡片啟用狀態、選擇的等級 ID

> 注意：不儲存費率，費率由 `CardBrandRegistry` 的程式碼定義。

---

### `MileageProgram.swift` — 里程計劃

**用途：** 代表不同的里程計劃（Asia Miles、自訂）

**MilageProgramType 列舉：** 包含圖示與是否支援國泰獎勵表

**ActiveProgramManager：** 透過 UserDefaults 追蹤當前選擇的計劃

---

## 信用卡系統

### 架構說明

信用卡系統採用 **Protocol + Registry** 模式，方便擴充新卡片品牌。

```
CardBrandDefinition (Protocol)
    ├── CathayUnitedBankCard (實作)
    └── TaishinCathayCard (實作)

CardBrandRegistry (中央註冊表，靜態查詢)
```

### `CardBrandDefinition.swift` — Protocol

定義信用卡品牌必須提供的介面：

- `brandID`, `displayName`, `bankName`, `defaultTierID`
- `tiers` — 各等級定義（費率、漸層、卡片圖片、福利）
- `sourceMappings` — MileageSource 到卡片福利的對應
- `rateSlots` — UI 顯示的費率欄位配置

**支援類型：**
- `CardTierDefinition` — 等級費率與視覺設定
- `ResolvedCardRates` — 解析後的完整費率
- `CardSpendingCategory` — 消費子類別
- `CardMileageSourceMapping` — 來源對應規則
- `CardRateSlot` — 費率顯示設定

### `CathayUnitedBankCard.swift` — 國泰世華亞洲萬里通聯名卡

| 等級 | 一般消費 | 加速類別 |
|------|---------|---------|
| 世界卡 | 22 元/哩 | 10 元/哩 |
| 鈦商卡 | 25 元/哩 | 10 元/哩 |
| 白金卡 | 30 元/哩 | 15 元/哩 |
| 里享卡 | 30 元/哩 | 30 元/哩 |

- 加速類別：海外、旅遊交通、日常消費、休閒娛樂
- 生日月加倍：2.0x [⚠️尚未實作完成]

### `TaishinCathayCard.swift` — 台新國泰航空聯名卡

| 等級 | 一般消費 | 海外消費 | 指定消費 |
|------|---------|---------|---------|
| 世界卡 | 22 元/哩 | 15 元/哩 | 5 元/哩 |
| 翱翔鈦金卡 | 25 元/哩 | 20 元/哩 | 5 元/哩 |
| 鈦金卡 | 30 元/哩 | 25 元/哩 | 5 元/哩 |

- 指定類別：4 種消費子分類

### `CardBrandRegistry.swift` — 註冊表

**關鍵靜態方法：**

| 方法 | 用途 |
|------|------|
| `definition(for:)` | 查詢品牌定義 |
| `brandForSource()` | 依來源自動選取品牌 |
| `sourceMapping()` | 取得來源的費率對應 |
| `spendingCategory()` | 查詢消費子類別 |
| `rate()` | 計算實際費率（來源 + 卡片 + 等級） |

### 如何新增一張信用卡

1. 在 `Models/CardDefinitions/` 新增檔案（如 `NewBankCard.swift`）
2. 建立 struct 實作 `CardBrandDefinition` protocol
3. 定義 `brandID`、`tiers`、`sourceMappings`、`rateSlots`
4. 在 `CardBrandRegistry.swift` 的 `allDefinitions` 陣列中加入新實例
5. 若有新的 `MileageSource`，需在 `Transaction.swift` 的列舉中新增
6. 在 `TransactionFormView.swift` 中確認新來源能被正確選取

---

## 資料庫 (Database)

### `CathayAwardChart.swift` — 國泰獎勵表計算

**FlightCalculator：**

| 方法 | 用途 |
|------|------|
| `determineZone(distance:destinationCode:)` | 判斷航線區域（6 種距離） |
| `requiredMiles(zone:cabinClass:)` | 查詢所需里程 |
| `isOneworld(route:)` | 判斷是否為寰宇一家夥伴航線 |
| `popularRoutes()` | 取得常見航線目標 |

**AwardZone：** ultraShortHaul / shortHaul1 / shortHaul2 / mediumHaul / longHaul / ultraLongHaul

> 短程航線依目的地城市（日本/泰國等）分為兩個層級，寰宇一家夥伴航線多 20-30% 里程。

### `AirportDatabase.swift` — 機場資料庫

- `Airport` 結構：IATA 代碼、城市（中英文）、機場名稱、座標
- `AirportDatabase.shared` 單例，預載約 100 個主要機場
- 40+ 個熱門機場碼（TPE、HND、LAX、LHR 等）

---

## ViewModel

### `MileageViewModel.swift` — 主要狀態管理器

使用 `@Observable` 宏，是整個 App 的核心狀態管理器。

**主要狀態：**
- `mileageAccount` — 目前帳戶
- `programs` — 所有里程計劃
- `activeProgram` — 當前選擇的計劃
- `creditCards` — 記憶體中的信用卡定義（由 Registry + 偏好重建）
- `transactions`, `flightGoals`, `redeemedTickets` — 當前計劃的資料
- `hasRemoteChanges` — CloudKit 同步通知旗標

**關鍵方法：**

| 方法 | 用途 |
|------|------|
| `initialize(context:)` | 載入計劃、設定同步觀察者 |
| `loadPrograms()` | 讀取計劃、處理重複、遷移未綁定資料 |
| `switchProgram(to:)` | 切換計劃並重新載入資料 |
| `addProgram(name:type:)` | 建立新里程計劃 |
| `deleteProgram()` | 刪除計劃及所有關聯資料 |
| `loadData()` | 依 programID 讀取帳戶/交易/目標 |
| `rebuildCreditCards()` | 從 Registry + SwiftData 偏好重建信用卡列表 |
| `addTransaction()` | 建立交易並更新帳戶里程 |
| `addFlightGoal()` | 新增飛行目標（自動排序） |
| `redeemGoal()` | 將目標轉為已兌換機票 |
| `previewMiles()` | 預覽里程（不儲存，供 UI 即時顯示） |

**CloudKit 同步邏輯：**
- 監聽 `NSPersistentStoreRemoteChange` 通知
- 1 秒防抖延遲避免頻繁重載
- 資料指紋比對以偵測實際變更

---

## 服務層 (Service)

### `CloudBackupService.swift` — 雲端備份服務

使用 `@Observable` 宏，提供手動備份/還原功能。

**備份結構：** `MileryBackup`（Codable），包含帳戶、交易、目標、機票、信用卡偏好、計劃資訊。

**關鍵方法：**

| 方法 | 用途 |
|------|------|
| `checkiCloudStatus()` | 檢查 iCloud 帳號可用性 |
| `createBackup()` | 序列化當前計劃為 JSON → 上傳 CloudKit |
| `fetchBackupList()` | 使用 recordZoneChanges API 列出所有備份 |
| `restoreFromBackup()` | 下載解碼 → 清空本地 → 重建資料 |

**技術細節：**
- 使用自訂 CloudKit Zone `MileryBackupZone`
- JSON 格式：ISO8601 日期、Pretty Printed
- 自動去重 `CardPreference` 記錄
- 向後相容舊版 `CreditCardRule` 備份

### `DeveloperAccessService.swift` — 開發者存取控制

- 以 iCloud record name 的 SHA256 雜湊做身分驗證
- 白名單存在 CloudKit 公開記錄：`DevAccessPolicy/main-dev-access-policy`
- `verifyCurrentUserAccess()` 回傳 `.allowed` 或 `.denied`

---

## 畫面 (Views)

### `MainTabView.swift` — 根導覽

5 個 Tab 頁籤（儀表板、進度、帳本、里程碑、設定），每個 Tab 的可見性由 `@AppStorage` 控制。支援外觀模式切換（系統/亮色/暗色）。

### `DashboardView.swift` — 儀表板（Tab 1）

- **英雄區塊：** 總里程顯示、到期日警告
- **可兌換雷達：** 顯示哪些目標已有足夠里程
- **夢想雷達：** 最接近目標的進度
- **每月駕駛艙：** 本月累積里程
- **近期動態：** 最新 3~5 筆交易
- 20 秒自動檢查遠端變更

### `ProgressView.swift` — 進度（Tab 2）

- 半圓形進度指示器（釘選目標）
- 所有目標列表（釘選優先）
- 拖拉排序、新增/編輯目標

### `LedgerView.swift` — 帳本（Tab 3）

- 月份選擇器與導覽
- 統計：月度總計、分類統計
- 交易列表（含排序）
- 新增/編輯交易

### `MilestonesView.swift` — 里程碑（Tab 4）

- 地圖顯示：已兌換（藍色）、可兌換（橘色）、未完成（橘色虛線）航線
- 航線統計
- 記錄機票互動

### `SettingsView.swift` — 設定（Tab 5）

- 外觀設定、信用卡管理、使用者偏好
- 雲端備份、同步開關
- 開發者存取、App 資訊與版本歷史

### `TransactionFormView.swift` — 記帳表單

共用的交易輸入表單，流程如下：

1. 選擇交易類型（信用卡 vs 非信用卡）
2. 選擇信用卡（若為信用卡模式）
3. 選擇來源（依品牌顯示可用選項）
4. 選擇子類別（若該來源需要）
5. 輸入金額或里程
6. 即時預覽計算結果（透過 `previewMiles()`）

### `CreditCardPageView.swift` — 信用卡管理

列出所有已註冊的信用卡品牌，可切換等級、啟用/停用、查看費率。儲存偏好至 `CardPreference`。

### 其他畫面

| 檔案 | 用途 |
|------|------|
| `EditTransactionView.swift` | 編輯/刪除交易 |
| `CloudBackupView.swift` | 備份狀態、備份/還原操作 |
| `OnboardingView.swift` | 首次啟動 9 頁引導（含卡片、主題、通知與同步設定） |
| `AllGoalsView.swift` | 完整目標清單 Modal |
| `CalculatorComponents.swift` | 可重用元件（`SourceButton`、`CompactCardRow`） |
| `CalculatorLedgerView.swift` | 計算器帳本 |

---

## 開發者工具 (DevViews)

需通過 `DeveloperAccessService` 驗證才能存取。

| 檔案 | 用途 |
|------|------|
| `DataManagementView.swift` | 各模型數量統計、CloudKit 狀態、安全清理（重複帳戶、孤立資料、舊版 CreditCardRule） |
| `CloudKitAdvancedView.swift` | CloudKit 記錄檢視 |
| `ConsoleLogView.swift` | 查看 App 日誌（來自 `AppConsoleStore`） |
| `AirportListView.swift` | 瀏覽/搜尋機場資料庫 |
| `ProgramSwitcherView.swift` | 管理多個里程計劃 |
| `TabVisibilitySettingsView.swift` | 切換 MainTab 的可見性 |

### Onboarding 測試重置按鈕

為了方便測試首次引導流程，開發者模式提供「重置已讀 Onboarding」入口：

1. 進入 `SettingsView`。
2. 在「開發中頁面」點選「重新觸發 Onboarding」。
3. 系統會將 `hasCompletedOnboarding` 設為 `false`。
4. 並馬上顯示頁面，若未完成所有流程下次重啟後一樣進入Onboarding。
---

## 資料儲存與同步

### SwiftData + CloudKit

- 本地 SQLite 資料庫（App Documents 資料夾）
- CloudKit 私人資料庫（`iCloud.com.73app.milery`）
- 自動同步由 `NSPersistentCloudKitContainer` 處理

### UserDefaults 儲存項目

| Key | 類型 | 說明 |
|-----|------|------|
| `cloudKitSyncEnabled` | Bool | 同步主開關 |
| `userColorScheme` | String | 外觀偏好 |
| `userName` | String | 使用者名稱 |
| `preferredOrigin` | String | 偏好出發機場 |
| `hasCompletedOnboarding` | Bool | 首次引導是否完成 |
| `tabVisible_*` | Bool | 各 Tab 可見性 |
| `lastBackupDate` | Date | 最後備份時間 |
| `activeMileageProgramID` | UUID | 當前計劃 ID |

### 手動備份

- CloudKit 自訂 Zone：`MileryBackupZone`
- 備份格式：JSON（CKAsset 附件）
- 每個備份以 programID 過濾，僅包含該計劃的資料

---

## 常見操作流程

### 新增一筆信用卡交易

```
使用者 → Ledger → 新增按鈕
    → TransactionFormView
    → 選擇「信用卡消費」
    → 選擇信用卡
    → TransactionFormView 查詢 CardBrandRegistry 取得可用 sourceMappings
    → 選擇來源（如 cardAccelerator）
    → 選擇子類別（如「海外」）
    → 輸入金額
    → previewMiles() 即時計算：金額 / 費率 = 里程
    → 確認 → viewModel.addTransaction()
    → 建立 Transaction + 更新 MileageAccount
    → CloudKit 自動同步
```

### 切換里程計劃

```
Settings → 里程計劃 → 選擇計劃
    → viewModel.switchProgram(to:)
    → 更新 ActiveProgramManager（UserDefaults）
    → loadData() 依 programID 過濾
    → 重設資料指紋
    → 所有畫面重新渲染
```

### 重新測試 Onboarding

```
Settings（開發者模式） → 重新觸發 Onboarding
    → hasCompletedOnboarding = false
    → 重新啟動 App
    → 顯示 OnboardingView（完整首次引導流程）
```

### 雲端備份與還原

```
備份：
    Settings → 雲端備份 → 備份到 iCloud
    → CloudBackupService.createBackup()
    → 依 activeProgram.id 過濾資料
    → 序列化為 JSON → CKRecord + CKAsset
    → 上傳至 MileryBackupZone

還原：
    選擇備份 → 確認還原
    → 下載 CKAsset → 解碼 JSON
    → 清空當前計劃所有資料
    → 從備份重建所有模型
    → CloudKit 傳播至其他裝置
```

---

## 新增 / 更新指南

### 新增信用卡品牌

1. 建立新檔案 `Models/CardDefinitions/XXXCard.swift`
2. 實作 `CardBrandDefinition` protocol
3. 在 `CardBrandRegistry.allDefinitions` 加入新實例
4. 若需新的 `MileageSource`，更新 `Transaction.swift` 列舉
5. 更新 `TransactionFormView` 確保新來源可被選取
6. 若需卡片圖片，加入 `Assets.xcassets`

### 新增資料模型

1. 在 `Models/` 建立新 SwiftData `@Model` class
2. 在 `MileryApp.swift` 的 Schema 陣列加入新類型
3. 在 `MileageViewModel` 加入對應的 CRUD 方法
4. 在 `CloudBackupService.MileryBackup` 加入新欄位以支援備份
5. 更新備份版本號（如有破壞性變更）

### 新增畫面 (View)

1. 在 `Views/` 建立新的 SwiftUI View
2. 遵循 `AviationTheme` 設計系統
3. 透過 `@Environment(MileageViewModel.self)` 取得 ViewModel
4. 若為主頁面，在 `MainTabView` 加入新 Tab 並設定 `@AppStorage` 控制
5. 若為子頁面，在對應的父 View 加入導覽

### 更新獎勵表

1. 修改 `Database/CathayAwardChart.swift` 中的 `requiredMiles()` 查表
2. 必要時更新 `AwardZone` 列舉
3. 更新 `popularRoutes()` 熱門航線

### 更新機場資料

1. 修改 `Database/airports.csv` 或直接編輯 `AirportDatabase.swift`
2. 更新 `popularAirportCodes` 陣列

---

## 使用的框架與依賴

| 框架 | 用途 |
|------|------|
| **SwiftUI** | UI 框架 |
| **SwiftData** | 資料持久化 + CloudKit 同步 |
| **CloudKit** | iCloud 同步與備份儲存 |
| **MapKit** | 里程碑地圖顯示 |
| **CoreLocation** | 機場座標資料 |
| **CryptoKit** | SHA256 雜湊（開發者驗證） |

---

## 設計模式

| 模式 | 應用 |
|------|------|
| **MVVM** | `MileageViewModel` (@Observable) + Views |
| **Singleton** | `AppConsoleStore`, `AirportDatabase`, `DeveloperAccessService`, `ActiveProgramManager` |
| **Registry** | `CardBrandRegistry` 動態信用卡配置 |
| **Protocol** | `CardBrandDefinition` 可擴充的信用卡支援 |
| **Computed Properties** | `Transaction.amount`、`MileageAccount.expiryDate()` |
| **Relationship** | SwiftData `@Relationship` 帳戶 ↔ 交易關聯 |
