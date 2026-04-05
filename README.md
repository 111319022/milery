# Milery: 航空哩程管理與目標追蹤

![iOS](https://img.shields.io/badge/iOS-26.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-Native-FA7343?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Blue?style=for-the-badge&logo=swift)

Milery 是一款 iOS 原生哩程管理 App，聚焦在「里程累積管理」、「航線目標追蹤」、「機票兌換紀錄」與「CloudKit 同步/備份」。

## 下載

- * **App Store 正式版:** [點此下載](https://apps.apple.com/tw/app/milery-%E5%B0%88%E7%82%BA%E5%93%A9%E7%A8%8B%E7%8E%A9%E5%AE%B6%E6%89%93%E9%80%A0/id6760928932)
- * **TestFlight 公測版:** [點此加入 TestFlight 測試計畫](https://testflight.apple.com/join/gWaMP1w2)

## 目前架構（2026）

### 技術堆疊

- SwiftUI
- SwiftData + CloudKit（私有資料庫）
- MVVM（`@Observable`）
- MapKit / CoreLocation
- CloudKit JSON 手動備份（自訂 Zone）

### 分層概念

- App Layer
  - `MileryApp.swift`：Schema、CloudKit/Local 容器建立、啟動診斷
- Domain / Model Layer
  - `Models/`：交易、帳戶、目標、兌換機票、卡片偏好、里程計畫
  - `Models/CardDefinitions/`：信用卡規則定義 + Registry
  - `Database/`：航線兌換邏輯、機場資料
- Application Layer
  - `ViewModels/MileageViewModel.swift`（核心狀態）
  - `ViewModels/MileageViewModel+Program.swift`
  - `ViewModels/MileageViewModel+Transaction.swift`
  - `ViewModels/MileageViewModel+Card.swift`
  - `ViewModels/MileageViewModel+Sync.swift`
- Service Layer
  - `Service/CloudBackupService.swift`
  - `Service/DeveloperAccessService.swift`
- Presentation Layer
  - `Views/`（Tab 主流程 + 設定 + 表單 + DevViews）

> 完整的技術文件、檔案用途說明、操作流程與新增/更新指南，請參閱 **[`PROJECT_GUIDE.md`](PROJECT_GUIDE.md)**。

## 核心功能

- 里程帳戶與交易管理
  - 支援多來源交易（刷卡、飛行、點數轉入、活動贈送、機票兌換）
- 信用卡規則引擎
  - 以 `CardBrandDefinition + CardBrandRegistry` 擴充品牌/等級/來源對應
- 飛行目標追蹤
  - 目標進度、剩餘里程、可兌換判斷
- 兌換紀錄與里程碑
  - 兌換後自動建立扣點交易與機票紀錄關聯
- 背景與主題系統
  - 預設漸層、純色、預設桌布、自訂圖片
- App Icon 切換
  - 使用 `CFBundleAlternateIcons`
- CloudKit 同步與手動備份
  - 自動同步 + JSON 備份還原

## 里程計畫支援

目前以 Asia Miles 為主，資料結構已支援多計畫（`MileageProgram`），未來會擴充其他哩程方案。

## 資料現況

- 金額欄位
  - `Transaction` 與 `CreditCardRule` 目前採 SwiftData `Double` 欄位搭配 `Decimal` 計算屬性（為了 CloudKit/SwiftData 相容與舊資料遷移）。
- ViewModel 拆分
  - 已從單一大檔案拆成 extension 分工（Program / Transaction / Card / Sync）。
- 測試現況
  - 已建立 `mileryTests/` 測試目標檔案與基礎骨架。
  - 目前測試內容仍以 placeholder 為主，下一步應補齊關鍵邏輯測試（信用卡計算、航區判定、到期日計算、備份往返）。

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


### 測試

可在 Xcode 中執行 `mileryTests`，或用 CLI：

```bash
xcodebuild test -project milery.xcodeproj -scheme milery -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 團隊

- Raaay: https://github.com/111319022
- 阿姿: https://github.com/mewneko-edu
---
*本專案為「2026 餘73 的 跨平台APP設計」課程之期中*
