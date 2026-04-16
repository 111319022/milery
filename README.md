# Milery — 航空哩程管理與目標追蹤

![iOS](https://img.shields.io/badge/iOS-26.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-FA7343?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Blue?style=for-the-badge&logo=swift)
![SwiftData](https://img.shields.io/badge/SwiftData-CloudKit-green?style=for-the-badge)

Milery 是一款專為哩程玩家打造的 iOS 原生應用程式。透過信用卡消費自動換算、航線兌換表即時查詢、目標進度視覺化，讓使用者輕鬆掌握哩程資產與飛行計畫。

## 下載

- **App Store 正式版:** [點此下載](https://apps.apple.com/tw/app/milery-%E5%B0%88%E7%82%BA%E5%93%A9%E7%A8%8B%E7%8E%A9%E5%AE%B6%E6%89%93%E9%80%A0/id6760928932)
- **TestFlight 公測版:** [點此加入 TestFlight 測試計畫](https://testflight.apple.com/join/gWaMP1w2)

## 核心功能

### 哩程帳戶管理
- 多來源交易記錄：信用卡消費、哩程加速器、飛行累積、銀行點數兌換、活動贈送等 11 種來源
- 哩程到期日自動計算
- 多里程計畫支援（⚠️目前以 Asia Miles 為主，結構已支援擴充，未來會支援更多里程計劃）

### 信用卡規則引擎
- 目前支援兩家銀行共 7 個卡別：
  - **國泰世華**：世界卡 / 鈦商卡 / 白金卡 / 里享卡
  - **台新銀行**：世界卡 / 翱翔鈦金卡 / 鈦金卡
- 自動計算刷卡金額 → 可獲哩程數，支援不同費率來源（一般消費、加速器、海外、指定消費）
- 三種進位模式：無條件捨去 / 無條件進位 / 四捨五入
- 生日月加碼倍數（國泰卡加速器消費雙倍）
- Protocol + Registry 架構，新增銀行僅需加一個 Definition 檔案

### 飛行目標追蹤
- 內建 亞洲萬里通 2026 年最新兌換表（6 個航距級別 x 4 種艙等）
- 內建約 40 個常用機場（含座標與距離計算）（⚠️未來會擴充）
- 目標進度百分比、剩餘哩程、可兌換通知
- 支援來回里程計算

### 兌換紀錄
- 機票兌換後自動建立扣點交易與已兌換機票紀錄
- 里程碑展示（已完成航線回顧）

### 同步與備份
- SwiftData + CloudKit 自動同步（私有資料庫 `iCloud.com.73app.milery`）
- 手動 JSON 備份/還原（CloudKit 自訂 Zone，支援版本化格式）
- 同步診斷日誌（開發者可在 App 內查看）

### 個人化
- 深色/淺色模式
- 背景自訂：預設背景 / 內建純色背景（依淺色與深色模式過濾）/ 內建漸層背景（依淺色與深色模式過濾）/ 自訂上傳圖片
- 外觀切換保護：切換淺色或深色模式時，若目前背景不適用，會自動回到預設背景
- App Icon 切換（`CFBundleAlternateIcons`）

### 安全與隱私
- App 密碼鎖（4 碼），密碼存放於 Keychain（`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）
- 支援 Face ID / Touch ID / Optic ID 解鎖
- 支援修改密碼、關閉密碼鎖（會同步刪除 Keychain 密碼）

### 用戶問題與意見回報
- 使用者可在設定頁（「關於」區段）提交問題回報
- 回報內容透過 CloudKit 公共資料庫收集，含聯絡信箱、問題描述、App 版本、設備型號、iOS 版本等
- 開發者可在設定頁開發者區段查看所有提交的回報（按提交時間排序）
- 支援查看個別回報詳情、刷新清單、空狀態提示

### 個人資料
- 頭貼管理：本地儲存 + 上傳 CloudKit CKAsset，好友可看見
- 預設頭貼為 `person.circle.fill` SF Symbol
- 顯示名稱編輯（同步至 CloudKit UserProfile）
- Onboarding 引導中可設定頭貼與名稱
- 設定頁頂部 Profile 區塊，點擊可進入編輯

### 好友（🔴🔧開發中）
- 6 碼好友代碼（排除 O/0/I/1，約 4.8 億組合）
- 好友關係三態：已加入、等待對方加入、對方已加你
- 雙向互加自動升級：利用 CloudKit Public DB 的雙階段升級機制（各自維護自己的 record）
- 好友進度同步：進入好友頁時自動將本地哩程、目標數、已兌換機票數上傳至 CloudKit
- 好友列表顯示對方的即時進度（總里程、目標數、已完成航線數）
- 支援撤銷已送出的邀請、拒絕對方邀請、刪除已有好友

### 計畫管理
- 里程計劃切換頁：可新增、切換、刪除非預設計劃
- 每個計劃資料彼此獨立（里程、交易、目標、里程碑）

## 架構

```
milery/
├── MileryApp.swift                  # App 入口、Schema、CloudKit 容器
├── AviationTheme.swift              # 主題色彩系統
├── Models/
│   ├── Transaction.swift            # 交易模型（11 種來源）
│   ├── MileageAccount.swift         # 帳戶（哩程總額、到期日）
│   ├── FlightGoal.swift             # 飛行目標（進度計算）
│   ├── CreditCardRule.swift         # 信用卡計算模型
│   ├── RedeemedTicket.swift         # 已兌換機票
│   ├── CardPreference.swift         # 卡片偏好（跨裝置同步）
│   ├── MileageProgram.swift         # 里程計畫（多計畫支援）
│   ├── BackgroundImageManager.swift # 背景選擇與自訂圖片管理
│   ├── SolidColorDefinition.swift   # 純色與漸層背景定義/Registry（含外觀可見性）
│   └── CardDefinitions/
│       ├── CardBrandDefinition.swift    # 品牌定義 Protocol
│       ├── CardBrandRegistry.swift      # 中央查表 Registry
│       ├── CathayUnitedBankCard.swift   # 國泰世華（4 卡別）
│       └── TaishinCathayCard.swift      # 台新銀行（3 卡別）
├── Database/
│   ├── CathayAwardChart.swift       # 兌換表 + FlightCalculator
│   ├── AirportDatabase.swift        # 機場查詢與距離計算
│   └── airports.csv                 # 機場原始資料
├── ViewModels/
│   ├── MileageViewModel.swift       # 主檔：狀態、init、loadData
│   ├── MileageViewModel+Program.swift     # 計畫 CRUD、去重、遷移
│   ├── MileageViewModel+Transaction.swift # 交易/目標/兌換 CRUD
│   ├── MileageViewModel+Card.swift        # 卡片重建與偏好
│   └── MileageViewModel+Sync.swift        # 遠端監聽與資料指紋比對
├── Service/
│   ├── AppLockService.swift         # App 密碼鎖與生物辨識
│   ├── CloudBackupService.swift     # CloudKit JSON 備份還原
│   ├── FriendService.swift          # 好友系統（CloudKit 公開資料庫）（🔴🔧開發中）
│   ├── ProfileService.swift         # 個人資料（頭貼本地+CloudKit、顯示名稱）
│   ├── DeveloperAccessService.swift # 開發者模式驗證
│   ├── IssueReportService.swift     # 問題回報提交（CloudKit 公開資料庫）
│   └── IssueReportAdminService.swift # 開發者查看回報清單
└── Views/
    ├── MainTabView.swift            # 5 Tab 容器
    ├── DashboardView.swift          # 總覽儀表板
    ├── ProgressView.swift           # 目標進度
    ├── LedgerView.swift             # 交易帳本
    ├── MilestonesView.swift         # 里程碑
    ├── SettingsView.swift           # 設定
    ├── TransactionFormView.swift    # 新增交易表單
    ├── EditTransactionView.swift    # 編輯交易
    ├── CreditCardPageView.swift     # 信用卡管理
    ├── AllGoalsView.swift           # 全部目標
    ├── CloudBackupView.swift        # 備份還原
    ├── OnboardingView.swift         # 首次引導
    ├── AppLockView.swift            # App 解鎖頁
    ├── AppLockSettingsView.swift    # App 密碼鎖設定頁
    ├── AppBackgroundView.swift      # 背景渲染
    ├── BackgroundPickerView.swift   # 背景選擇
    ├── ProgramSwitcherView.swift    # 里程計劃切換（🔴🔧開發中）
    ├── CalculatorComponents.swift   # 計算機元件
    ├── CalculatorLedgerView.swift   # 計算機帳本
    ├── NotificationSettingsView.swift # 通知設定
    ├── AppIconPickerView.swift        # App 圖示切換
    ├── FriendsView.swift              # 朋友頁面（🔴🔧開發中）
    ├── ProfileAvatarView.swift        # 頭貼元件（圓形 UIImage / SF Symbol）
    ├── ProfileEditView.swift          # 個人資料編輯頁
    ├── ReportIssueView.swift          # 問題回報表單
    └── DevViews/                      # 開發者工具
       ├── ConsoleLogView.swift        # 開發日誌檢視
       ├── DataManagementView.swift    # 資料管理（匯出/清除）
       ├── CloudKitAdvancedView.swift  # CloudKit 進階診斷
       ├── AirportListView.swift       # 機場資料清單檢視
       ├── TabVisibilitySettingsView.swift # Tab 顯示設定
       └── IssueReportListView.swift   # 問題回報管理
       
mileryTests/
├── FlightCalculatorTests.swift        # 航班計算測試
├── CreditCardRuleTests.swift          # 信用卡規則測試
├── FlightGoalTests.swift              # 目標模型測試
├── MileageAccountTests.swift          # 里程帳戶測試
└── AirportDatabaseTests.swift         # 機場資料庫測試
```

### 技術堆疊

| 層級 | 技術 |
|------|------|
| UI | SwiftUI（`@Observable` MVVM） |
| 資料 | SwiftData + CloudKit 私有資料庫 |
| 計算 | `Decimal` 精確運算（`Double` 儲存 + `String` ） |
| 備份 | CloudKit 自訂 Zone + JSON 序列化（版本化格式） |
| 地圖 | Mapkit + CoreLocation（Haversine 公式計算航線距離） |
| 測試 | Swift Testing 框架 |

### 設計決策

- **金額精度**：SwiftData/CloudKit 不直接支援 `Decimal`，因此底層以 `Double` 儲存，對外透過 `Decimal(string: String(doubleValue))` 轉換，避免浮點精度損失。
- **ViewModel 拆分**：`MileageViewModel` 透過 extension 按職責分為 4 個檔案（Program / Transaction / Card / Sync），主檔僅保留共享狀態與核心方法。
- **信用卡架構**：採 Protocol (`CardBrandDefinition`) + Registry (`CardBrandRegistry`) 模式，新增銀行品牌無需修改既有程式碼。
- **錯誤處理**：核心資料流程使用 `do-catch` + `appLog()` 記錄，儲存失敗透過 UI Alert 通知使用者。

## 系統需求

* **APP可運行之機型與作業系統**
    * **iPhone**: 需為 **iOS 26.0** 或以上版本 (支援 iPhone 11/SE 2 及後續機型)。
    * **多平台相容性**: 本APP採 iOS 原生架構開發，可於下列裝置以 **iPhone 相容模式**執行：
        * **iPad**: 需運行 iPadOS 26.0 或以上版本。
        * **Mac**: 僅支援搭載 **Apple Silicon** 晶片之機型，並且需運行 MacOS 26.0 或以上版本。
        * **Apple Vision Pro**: 需運行 VisionOS 26.0 或以上版本。
        
* **開發環境:** 你需要一台Mac！建議使用 Xcode 26.3 或以上版本進行編譯，並選擇或連接符合作業系統要求之裝置。

## 快速開始

```bash
git clone https://github.com/111319022/milery.git
open milery/milery.xcodeproj
```

選擇模擬器或實機，按 `Cmd+R` 編譯執行。

### 執行測試

Xcode 內：`Cmd+U` 或 Test Navigator 執行 `mileryTests`。

命令列：

```bash
xcodebuild test -project milery.xcodeproj -scheme milery \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 團隊

- **Raaay** — [github.com/111319022](https://github.com/111319022)
- **阿姿** — [github.com/mewneko-edu](https://github.com/mewneko-edu)

## 使用的AI輔助

- Gemini from Google
- Claude Code from Anthropic

---

*本專案為「2026 餘73 的 跨平台APP設計」課程之期中*

---

> 完整技術文件、檔案用途、操作流程與維護指南，請參閱 **[PROJECT_GUIDE.md](PROJECT_GUIDE.md)**。
