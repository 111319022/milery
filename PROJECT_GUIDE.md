# Milery 專案指南

本文件聚焦「目前程式碼實際架構」與「後續維護方式」，適用於新進開發者與既有維護者快速理解系統。

## 目錄

- 架構總覽
- 專案目錄與責任分工
- App 啟動與資料容器
- 資料模型（SwiftData）
- 信用卡規則系統
- Database 層
- ViewModel 層（extension 分割）
- Service 層
- View 層
- 背景與主題系統
- 同步與備份流程
- 測試策略與現況
- 已知風險與技術債
- 日常維護清單

## 架構總覽

Milery 採用 SwiftUI + SwiftData + CloudKit 的 iOS 原生架構，應用層邏輯主要由 `MileageViewModel` 管理，但已透過 extension 按職責切分，降低單一檔案複雜度。

### 層級

- Presentation
  - `Views/`：所有 UI 頁面與可重用元件
- Application
  - `ViewModels/`：狀態、資料載入、業務流程
- Domain
  - `Models/`、`Models/CardDefinitions/`、`Database/`
- Infrastructure
  - `Service/`、CloudKit、SwiftData、UserDefaults

---

## 專案目錄與責任分工

```text
milery/
├── MileryApp.swift
├── AviationTheme.swift
├── Models/
│   ├── Transaction.swift
│   ├── MileageAccount.swift
│   ├── FlightGoal.swift
│   ├── RedeemedTicket.swift
│   ├── CreditCardRule.swift
│   ├── CardPreference.swift
│   ├── MileageProgram.swift
│   ├── BackgroundImageManager.swift
│   └── CardDefinitions/
│       ├── CardBrandDefinition.swift
│       ├── CardBrandRegistry.swift
│       ├── CathayUnitedBankCard.swift
│       └── TaishinCathayCard.swift
├── Database/
│   ├── CathayAwardChart.swift
│   ├── AirportDatabase.swift
│   └── airports.csv
├── ViewModels/
│   ├── MileageViewModel.swift
│   ├── MileageViewModel+Program.swift
│   ├── MileageViewModel+Transaction.swift
│   ├── MileageViewModel+Card.swift
│   └── MileageViewModel+Sync.swift
├── Service/
│   ├── CloudBackupService.swift
│   └── DeveloperAccessService.swift
└── Views/
    ├── MainTabView.swift
    ├── DashboardView.swift
    ├── ProgressView.swift
    ├── LedgerView.swift
    ├── MilestonesView.swift
    ├── SettingsView.swift
    ├── TransactionFormView.swift
    ├── CreditCardPageView.swift
    ├── CloudBackupView.swift
    ├── BackgroundPickerView.swift
    ├── AppIconPickerView.swift
    ├── NotificationSettingsView.swift
    ├── OnboardingView.swift
    └── DevViews/
```

---

## App 啟動與資料容器

### `MileryApp.swift`

主要責任：

- 建立 SwiftData Schema
- 根據 `cloudKitSyncEnabled` 決定使用 CloudKit 或 Local store
- CloudKit 失敗時 fallback 到本地
- 啟用同步診斷與 console log
- 依 `hasCompletedOnboarding` 決定進入 Onboarding 或 MainTab

Schema 目前包含：

- `MileageAccount`
- `Transaction`
- `FlightGoal`
- `CreditCardRule`
- `RedeemedTicket`
- `CardPreference`
- `MileageProgram`

---

## 資料模型（SwiftData）

### `Transaction`

- 每筆里程來源紀錄
- 關鍵欄位
  - `date`
  - `amountValue`（`Double`，舊欄位名稱 `amount`）
  - `earnedMiles`
  - `sourceRaw`
  - `cardSubcategoryID`
  - `programID`
- `amount` 以 computed property 提供 `Decimal` 存取
- 內含舊欄位遷移邏輯（accelerator / taishin 指定類別）

### `MileageAccount`

- 聚合某個計畫的里程總額與活動資訊
- 關鍵方法
  - `updateMiles(amount:date:)`
  - `expiryDate()`
  - `daysUntilExpiry()`

### `FlightGoal`

- 航線兌換目標（起訖、艙等、所需里程、排序）
- 目標進度計算與剩餘里程評估

### `RedeemedTicket`

- 已兌換機票紀錄
- 與扣點交易透過 ID 關聯

### `CreditCardRule`

- 信用卡計算模型
- 費率欄位存於 `Double`，對外以 `Decimal` 計算
- 核心方法 `calculateMiles(...)`

### `CardPreference`

- 持久化「品牌是否啟用 / 選擇等級」
- 作為跨裝置同步偏好來源

### `MileageProgram`

- 支援多里程計畫
- `ActiveProgramManager` 透過 UserDefaults 保存當前 program

---

## 信用卡規則系統

系統採用 Protocol + Registry：

- `CardBrandDefinition`：定義品牌能力（tiers、sourceMappings、rateSlots）
- `CardBrandRegistry`：集中查表與解析費率
- `CathayUnitedBankCard`、`TaishinCathayCard`：目前品牌實作

### 設計重點

- 規則定義與 UI 顯示解耦
- 新增卡片主要在 Definition 層完成
- Runtime 由 Registry 合成最終費率

---

## Database 層

### `CathayAwardChart.swift` / `FlightCalculator`

- 依距離與目的地代碼判斷區間（特別是短程 1 / 短程 2）
- 依艙等回傳所需里程
- 提供常用航點判斷與便利方法

### `AirportDatabase.swift`

- 載入機場基本資料（IATA、座標、名稱）
- 提供距離計算與查詢

---

## ViewModel 層（extension 分割）

`MileageViewModel` 目前採「主檔 + extension」方式切分責任，減少 God Object 的閱讀成本。

### 主檔 `MileageViewModel.swift`

- 共享狀態宣告
- `saveContext()`
- `loadData()`
- `isBirthdayMonth(for:)`

### `MileageViewModel+Program.swift`

- `loadPrograms()`
- `switchProgram(to:)`
- `addProgram(...)`
- `deleteProgram(...)`
- 預設計畫去重與孤兒資料遷移

### `MileageViewModel+Transaction.swift`

- 交易 CRUD
- 目標 CRUD
- 兌換流程（goal -> ticket + 扣點交易）
- 月統計與可兌換目標

### `MileageViewModel+Card.swift`

- 由 Registry + CardPreference 重建卡片列表
- 卡片啟用/停用
- 等級切換與偏好儲存

### `MileageViewModel+Sync.swift`

- 初始化遠端監聽
- Remote change debounce
- 資料指紋比對
- 手動同步刷新

---

## Service 層

### `CloudBackupService.swift`

- 手動備份與還原
- 備份格式為 JSON（`MileryBackup`）
- 儲存在 CloudKit 自訂 Zone
- 支援舊版欄位相容

### `DeveloperAccessService.swift`

- 開發者模式存取控制
- 透過 CloudKit 公開記錄 + 雜湊驗證

---

## View 層

### 主流程

- `MainTabView`：5 Tab 容器
- `DashboardView`：總覽、即時狀態、近期交易
- `ProgressView`：目標進度與管理
- `LedgerView`：交易列表與月份統計
- `MilestonesView`：里程碑與航線展示
- `SettingsView`：設定入口總表

### 交易與卡片相關

- `TransactionFormView`
- `EditTransactionView`
- `CreditCardPageView`

### 同步與工具

- `CloudBackupView`
- `DevViews/*`

---

## 背景與主題系統

### `AviationTheme.swift`

- 統一色彩、字級、間距、陰影
- 包含 adaptive color 與 gradient

### `BackgroundImageManager.swift`

- 自訂背景儲存/讀取/刪除
- 以檔案形式存在 App Documents

### `AppBackgroundView.swift` + `BackgroundPickerView.swift`

- 統一背景渲染（漸層 / 純色 / 圖片）
- 圖片背景時啟用可讀性加強（material + overlay）

---

## 同步與備份流程

### 自動同步（SwiftData + CloudKit）

1. App 啟動建立 CloudKit-backed ModelContainer
2. 監聽 `NSPersistentStoreRemoteChange`
3. 防抖後重新載入並比對指紋
4. 有變更才刷新 UI

### 手動備份

1. 取出當前 program 的帳戶/交易/目標/機票/偏好
2. 序列化為 `MileryBackup`
3. 上傳 CloudKit 私有資料庫

### 手動還原

1. 下載備份 JSON
2. 解碼並清除當前計畫資料
3. 重建 SwiftData 模型並存檔

---

## 測試策略與現況

### 目前現況

- 已有 `mileryTests/` 目標與測試檔
- 現有檔案多為 placeholder

### 優先補齊清單

- `CreditCardRule.calculateMiles()`
  - 不同費率來源、生日月加碼、進位模式
- `FlightCalculator.determineZone()`
  - 短程 1 / 2 關鍵分流
- `MileageAccount.expiryDate()`
  - 無交易與有交易兩種基準日期
- `CloudBackupService` 序列化往返
  - encode -> decode -> rebuild 資料一致性

### 建議執行方式

- Xcode Test Navigator 跑 `mileryTests`
- CI 或本地 CLI：

```bash
xcodebuild test -project milery.xcodeproj -scheme milery -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 已知風險與技術債

### 1. 金額精度風險

目前金額欄位為 `Double` 存儲、`Decimal` 對外運算，存在轉換誤差風險。後續可評估：

- 方案 A：改為 `Int`（分）
- 方案 B：保留 SwiftData 欄位但增加精度保護策略（輸入正規化 + 四捨五入規則）

### 2. ViewModel 規模仍偏大

雖已 extension 拆分，但仍屬單一核心物件。後續可再拆：

- `ProgramManager`
- `TransactionService`
- `GoalService`
- `CardPreferenceManager`
- `SyncCoordinator`

### 3. 錯誤處理一致性

目前已從關鍵存檔路徑回報錯誤，但仍需持續減少 `try?` 在核心流程的使用，避免靜默失敗。

---

## 日常維護清單

### 新增信用卡品牌

1. 在 `Models/CardDefinitions/` 新增 definition
2. 註冊至 `CardBrandRegistry`
3. 補齊來源映射與等級費率
4. 驗證 `TransactionFormView` 可選取

### 新增里程計畫

1. 擴充 `MilageProgramType`
2. 於設定頁面新增建立/切換流程
3. 確認 `loadData()` 的 `programID` 過濾邏輯

### 新增資料模型

1. 新增 `@Model`
2. 更新 `MileryApp.swift` Schema
3. 更新備份結構 `MileryBackup`
4. 補齊遷移與測試

### 新增主頁功能

1. 在 `Views/` 實作畫面
2. 若需全域狀態，擴充 ViewModel extension（依責任）
3. 走一輪 CloudKit + 備份還原驗證

---

如需了解上線流程、版本紀錄、或資料遷移實作細節，建議先從：

- `MileryApp.swift`
- `ViewModels/MileageViewModel+Program.swift`
- `Service/CloudBackupService.swift`

三個檔案開始閱讀。
