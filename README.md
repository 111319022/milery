# Milery: 航空哩程管理與目標追蹤系統

![iOS](https://img.shields.io/badge/iOS-26.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-Native-FA7343?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Blue?style=for-the-badge&logo=swift)

## 專案概述

Milery是一款專為航空常客與哩程使用者開發之 iOS 原生應用程式。系統旨在透過視覺化介面與本地資料庫技術，協助使用者系統化地管理哩程資產、設定機票兌換目標，並將抽象的點數轉換為具體的飛行進度與 3D 航線空間視覺回饋。

## 應用程式取得方式

目前提供正式上架版本與Testflight測試版本，可透過以下管道取得（Testflight測試版本更新較快）：

* **App Store 正式版:** [點此下載](https://apps.apple.com/tw/app/milery-%E5%B0%88%E7%82%BA%E5%93%A9%E7%A8%8B%E7%8E%A9%E5%AE%B6%E6%89%93%E9%80%A0/id6760928932)
* **TestFlight 公測版:** [點此加入 TestFlight 測試計畫](https://testflight.apple.com/join/gWaMP1w2)

## 核心系統模組

* **哩程資產管理模組**
  提供結構化之資料輸入介面，精確記錄哩程之獲取、轉換與消耗。支援多源點數追蹤，確保帳務邏輯之完整性與正確性。
* **信用卡規則引擎（可擴充架構）**
  採用 `CardBrandDefinition` + `CardBrandRegistry` 設計，將各銀行/卡種規則以品牌定義方式註冊，支援多品牌、多等級與來源映射，降低硬編碼與擴充成本。
* **兌換目標追蹤系統**
  依據使用者設定之起訖點 (如TPE-KIX)，系統動態計算並以量化之進度條呈現機票兌換之完成度。
* **數位登機證生成器**
  於目標達成後，系統自動擷取航班資料、艙等與 IATA 機場代碼，生成具備視覺設計感之數位登機證憑證。
* **3D 航線視覺化模組**
  介接原生 MapKit 框架，於立體地球儀模型上渲染已兌換之飛行軌跡，提供直觀的空間資訊展示。
* **個人化背景系統**
  支援預設桌布與自訂背景圖片，使用者可從相簿選擇圖片並透過全螢幕裁切設定桌布。並於自訂背景啟用時為導覽列、標籤列、區塊標題及進度文字加入毛玻璃底板與對比度增強，確保各種亮度背景下的可讀性。
* **首次啟動引導**
  首次啟動會引導使用者完成里程計劃、信用卡、常用出發地、現有里程、生日月份、外觀主題、通知權限與 iCloud 同步等設定。

## ⚠️里程計劃支援現況

目前版本以 **「亞洲萬里通（Asia Miles）」** 作為主要里程計劃設定，包含兌換規則與需求哩程計算邏輯。未來將持續擴充系統設計與資料結構，逐步支援更多航空公司與聯盟的里程計劃！

## 技術概覽

| 技術 | 用途 |
|------|------|
| **SwiftUI** | 宣告式 UI 框架 |
| **SwiftData + CloudKit** | 資料持久化與 iCloud 同步 |
| **MVVM + @Observable** | 狀態管理架構 |
| **MapKit + CoreLocation** | 3D 航線視覺化 |
| **CardBrandDefinition + Registry** | 可擴充的信用卡規則引擎 |
| **BackgroundImageManager** | 自訂背景圖片管理與持久化 |
| **AppBackgroundView + .ultraThinMaterial** | 統一背景元件與自適應可讀性機制 |

> 完整的技術文件、檔案用途說明、操作流程與新增/更新指南，請參閱 **[`PROJECT_GUIDE.md`](PROJECT_GUIDE.md)**。

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
