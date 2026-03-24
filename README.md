# Milery: 航空哩程管理與目標追蹤系統

![iOS](https://img.shields.io/badge/iOS-26.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-Native-FA7343?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Blue?style=for-the-badge&logo=swift)

## 專案概述

Milery是一款專為航空常客與哩程使用者開發之 iOS 原生應用程式。系統旨在透過視覺化介面與本地資料庫技術，協助使用者系統化地管理哩程資產、設定機票兌換目標，並將抽象的點數轉換為具體的飛行進度與 3D 航線空間視覺回饋。

## 應用程式取得方式

目前提供正式上架版本與Testflight測試版本，可透過以下管道取得：

* **App Store 正式版:** Apple審核中
* **TestFlight 公測版:** [點此加入 TestFlight 測試計畫](https://testflight.apple.com/join/gWaMP1w2)

## 核心系統模組

* **哩程資產管理模組**
  提供結構化之資料輸入介面，精確記錄哩程之獲取、轉換與消耗。支援多源點數追蹤，確保帳務邏輯之完整性與正確性。
* **兌換目標追蹤系統**
  依據使用者設定之起訖點 (如TPE-KIX)，系統動態計算並以量化之進度條呈現機票兌換之完成度。
* **數位登機證生成器**
  於目標達成後，系統自動擷取航班資料、艙等與 IATA 機場代碼，生成具備視覺設計感之數位登機證憑證。
* **3D 航線視覺化模組**
  介接原生 MapKit 框架，於立體地球儀模型上渲染已兌換之飛行軌跡，提供直觀的空間資訊展示。

## ⚠️里程計劃支援現況

目前版本以 **「亞洲萬里通（Asia Miles）」** 作為主要里程計劃設定，包含兌換規則與需求哩程計算邏輯。未來將持續擴充系統設計與資料結構，逐步支援更多航空公司與聯盟的里程計劃！

## App 技術說明

本專案基於 iOS 原生開發規範建置，核心技術如下：

* **UI 與互動層:** `SwiftUI`
  以宣告式 UI 建立儀表板、目標追蹤、明細編輯與設定頁面，並透過自訂主題集中管理色彩與視覺風格。
* **資料模型與狀態管理:** `MVVM` + `Observable` ViewModel
  將哩程帳務、目標進度與票券邏輯集中在 ViewModel，維持畫面與資料同步，降低畫面耦合。
* **本地資料持久化:** `SwiftData`
  儲存哩程帳戶、交易紀錄、目標與兌換票券等資料，提供離線可用且高效率的資料讀寫體驗。
* **雲端備份:** `CloudKit`
  透過 iCloud 私有資料庫進行資料備份與還原，將所有 SwiftData 資料序列化為 JSON 並以 CKAsset 上傳，支援多版本備份管理。
* **地理空間資訊與航線呈現:** `MapKit` + `CoreLocation`
  用於機場座標查詢、航線路徑計算與 3D 空間視覺化，將兌換成果轉化為可視化飛行軌跡。
* **資料來源與規則基礎:** `CSV` + 本地規則檔
  透過 `airports.csv` 與 `CathayAwardChart` 等資料來源，支撐航點資訊與兌換需求哩程計算。
* **圖示與介面一致性:** `SF Symbols`
  建立跨頁面一致的圖示語言，提升資訊辨識效率與整體可讀性。

## 專案資料夾結構與檔案用途

```text
.
├── MileryApp.swift
├── AviationTheme.swift
├── Assets.xcassets/
├── Database/
├── Models/
├── ViewModels/
├── Views/
│   └── DevViews/
├── Service/
├── milery.xcodeproj/
└── README.md
```

* **`MileryApp.swift`**
  App 進入點，負責啟動應用程式與注入主要環境設定。
* **`AviationTheme.swift`**
  全域視覺主題設定，管理色彩、字體與元件風格。
* **`Assets.xcassets/`**
  影像與色票資產庫，包含 App Icon、圖片與自訂色彩。
* **`Database/`**
  靜態資料與規則來源，例如機場資料表、航點資料與兌換規則。
* **`Models/`**
  資料模型定義，如交易、目標、帳戶與兌換票券等核心結構。
* **`ViewModels/`**
  商業邏輯與狀態管理層，處理資料計算與畫面同步。
* **`Views/`**
  UI 畫面與元件，涵蓋儀表板、計算器、里程本與設定頁。
  * **`DevViews/`** 開發者模式專用頁面（詳細請見下方「開發者模式專區」）。
* **`Service/`**
  服務層，包含 CloudKit 備份與還原、開發者白名單驗證等邏輯。
* **`milery.xcodeproj/`**
  Xcode 專案設定與建置檔案。

## 開發者模式專區（Developer Tools）

> 本區塊僅供內部開發與維運人員使用與參考，目的是加速除錯、資料檢查與同步診斷流程。
> 開發者權限採 CloudKit 白名單管理，需由內部管理者加入使用者識別碼（hash）。需要者請洽開發人員。

### 開發者功能樹狀圖

```text
設定
└── 開發者（隱藏，需 CloudKit 白名單驗證）
    ├── 機場資料列表（AirportListView.swift）
    │   └── 搜尋 CSV 機場資料、協助完善 AirportDatabase
    ├── 分頁顯示管理（TabVisibilitySettingsView.swift）
    │   └── 控制 TabView 顯示哪些分頁
    ├── 資料管理（DataManagementView.swift）
    │   ├── SwiftData 全量資料檢視（Account / Transaction / Goal / Ticket / Legacy Card）
    │   ├── 每筆資料可右滑刪除（清理異常資料）
    │   ├── 安全清理（重複帳戶、孤兒資料、舊版殘留）
    │   ├── CloudKit 狀態摘要（同步開關 / iCloud 帳號 / 備份筆數）
    │   └── CloudKit record 詳細檢視（進階，CloudKitAdvancedView.swift）
    └── Console 日誌（ConsoleLogView.swift）
        ├── 全量日誌檢視
        ├── 只看同步相關（Sync / iCloud / CloudKit）
        ├── 複製目前清單
        └── 自動清理 7 天前日誌
```

### 開發者模式啟用方式

1. 進入「設定」。
2. 連續點擊「版本資訊」10 次。
3. App 會自動進行 CloudKit 白名單驗證。
4. 驗證通過後，顯示「開發者」區塊。

### TestFlight / 正式版部署重點

* **TestFlight 與 App Store 版本會使用 CloudKit Production 環境。**
* 請確認 Production 也建立以下資料（不是只有 Development）：
  * Record Type：`DevAccessPolicy`
  * Record Name：`main-dev-access-policy`（相容舊版：`default`）
  * `enabled = 1`
  * `allowedUserHashes` 已加入目標使用者 hash
* 若只在 Development 設定白名單，TestFlight / 正式版會驗證失敗。

### 各工具頁用途說明

* **機場資料列表** (`Views/DevViews/AirportListView.swift`)
  用於查閱與匯入機場基礎資料，協助維護 `AirportDatabase`。
* **分頁顯示管理** (`Views/DevViews/TabVisibilitySettingsView.swift`)
  用於快速開關 Tab 頁籤，便於測試不同資訊架構與導覽流程。
* **資料管理** (`Views/DevViews/DataManagementView.swift`)
  用於資料庫層級除錯：查看所有 SwiftData 記錄、逐筆刪除異常、執行安全清理、檢查 CloudKit 概況。
* **CloudKit record 詳細檢視（進階）** (`Views/DevViews/CloudKitAdvancedView.swift`)
  用於查看雲端備份 Record 細節（recordName / zone / schema / device / 日期）。
* **Console 日誌** (`Views/DevViews/ConsoleLogView.swift`)
  用於檢查同步與備份事件；支援同步關鍵字過濾，並採 7 天保留策略避免日誌無限成長。

### 資料異常時建議除錯流程

1. 先到「Console 日誌」開啟「只看同步相關」，確認近期同步事件與錯誤訊息。
2. 到「資料管理」查看是否有孤兒資料或重複帳戶。
3. 針對異常記錄進行逐筆刪除；若資料污染範圍大，再使用「安全清理」。
4. 如需比對雲端狀態，進入「CloudKit record 詳細檢視（進階）」確認 Record 是否更新。

## 系統需求與安裝執行

### 系統需求

* **機型與作業系統**
    * **iPhone**: 需為 **iOS 26.0** 或以上版本 (支援 iPhone 11/SE 2 及後續機型)。
    * **多平台相容性**: 本APP採 iOS 原生架構開發，可於下列裝置以 **iPhone 相容模式**執行：
        * **iPad**: 需運行 iPadOS 26.0 或以上版本。
        * **Mac**: 僅支援搭載 **Apple Silicon** 晶片之機型，並且需運行 MacOS 26.0 或以上版本。
        * **Apple Vision Pro**: 需運行 VisionOS 26.0 或以上版本。
        
* **開發環境:** 建議使用 Xcode 26.3 或以上版本進行編譯，並選擇或連接符合作業系統要求之裝置。

### 安裝與執行指引

1. 複製本專案原始碼：`git clone https://github.com/111319022/milery.git`
2. 於 Xcode 中開啟 `milery.xcodeproj`。
3. 選擇適當模擬器或實機，完成編譯並執行。

## 開發團隊

* **Raaay**: [https://github.com/111319022](https://github.com/111319022)
* **阿姿**: [https://github.com/mewneko-edu](https://github.com/mewneko-edu)

---
*本專案為「2026 餘73 的 跨平台APP設計」課程之期中*
