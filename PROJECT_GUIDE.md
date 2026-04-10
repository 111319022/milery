# Milery 專案指南

本文件為 Milery 的完整技術文件，涵蓋架構設計、模組職責、資料流程、測試與日常維護指南。適用於新進開發者快速上手與既有維護者查閱參考。

## 目錄

1. [架構總覽](#架構總覽)
2. [App 啟動流程](#app-啟動流程)
3. [資料模型 (SwiftData)](#資料模型-swiftdata)
4. [信用卡規則系統](#信用卡規則系統)
5. [航線計算引擎](#航線計算引擎)
6. [ViewModel 層](#viewmodel-層)
7. [Service 層](#service-層)
8. [View 層](#view-層)
9. [主題與背景系統](#主題與背景系統)
10. [同步與備份流程](#同步與備份流程)
11. [測試](#測試)
12. [已知限制與後續方向](#已知限制與後續方向)
13. [日常維護](#日常維護)

---

## 架構總覽

Milery 採 SwiftUI + SwiftData + CloudKit 的 iOS 原生 MVVM 架構，使用 `@Observable` 巨集驅動 UI 更新。

```
┌─────────────────────────────────────────────────┐
│  Presentation                                   │
│  Views/ (SwiftUI)                               │
├─────────────────────────────────────────────────┤
│  Application                                    │
│  MileageViewModel (主檔 + 4 Extension)           │
├─────────────────────────────────────────────────┤
│  Domain                                         │
│  Models/  ·  CardDefinitions/  ·  Database/     │
├─────────────────────────────────────────────────┤
│  Infrastructure                                 │
│  SwiftData  ·  CloudKit  ·  Service/            │
└─────────────────────────────────────────────────┘
```

### 技術選型

| 項目 | 選擇 | 理由 |
|------|------|------|
| UI | SwiftUI | 宣告式 UI、原生支援 |
| 狀態管理 | `@Observable` | 取代 ObservableObject，更簡潔 |
| 持久層 | SwiftData | 原生 Swift ORM，自動 CloudKit 同步 |
| 雲端 | CloudKit 私有資料庫 | 免後端、Apple 生態原生整合 |
| 精度 | `Double` 儲存 + `Decimal` 運算 | 兼顧 CloudKit 相容與計算精度 |

---

## App 啟動流程

**檔案**：`MileryApp.swift`

啟動順序：

1. 啟用 `SyncDiagnosticsObserver`（監聽 CloudKit 事件、前後景切換）
2. 定義 SwiftData Schema（7 個 `@Model`）
3. 讀取 `cloudKitSyncEnabled` (UserDefaults)：
   - `true` → 嘗試建立 CloudKit-backed `ModelContainer`
   - 失敗 → fallback 到本地 `ModelContainer`
   - `false` → 直接建立本地容器
4. 檢查 iCloud 帳號狀態（`CKContainer.accountStatus()`）
5. 依 `hasCompletedOnboarding` 決定顯示 `OnboardingView` 或 `MainTabView`

**Schema 包含**：

| Model | 說明 |
|-------|------|
| `MileageAccount` | 哩程帳戶（與 Transaction、FlightGoal 有 cascade 關聯） |
| `Transaction` | 交易紀錄（11 種來源） |
| `FlightGoal` | 飛行兌換目標 |
| `CreditCardRule` | 信用卡規則與費率 |
| `RedeemedTicket` | 已兌換機票 |
| `CardPreference` | 卡片品牌啟用/等級偏好 |
| `MileageProgram` | 里程計畫（多計畫支援） |

**日誌系統**：`AppConsoleStore` 是 App 內日誌引擎，透過全域函式 `appLog()` 寫入，保留最近 800 筆、7 天內記錄，儲存於 App Support 目錄。

---

## 資料模型 (SwiftData)

### Transaction

每筆哩程來源紀錄。

| 欄位 | 型別 | 說明 |
|------|------|------|
| `amountValue` | `Double` | 底層儲存（`@Attribute(originalName: "amount")`） |
| `amount` | `Decimal` (computed) | 對外介面，透過 `Decimal(string:)` 轉換避免精度損失 |
| `earnedMiles` | `Int` | 獲得哩程數 |
| `sourceRaw` | `String` | 來源（對應 `MileageSource` enum，11 種） |
| `cardSubcategoryID` | `String?` | 統一子類別欄位 |
| `cardBrandRaw` | `String?` | 使用的信用卡品牌 |
| `programID` | `UUID?` | 所屬里程計畫 |

**向後相容**：保留 `acceleratorCategoryRaw` 和 `taishinDesignatedCategoryRaw` 舊欄位供 CloudKit 既有資料遷移。`resolvedSubcategoryID` computed property 自動從舊欄位 fallback。

**MileageSource 列舉** (11 種)：`cardGeneral` / `cardAccelerator` / `taishinOverseas` / `taishinDesignated` / `specialMerchant` / `promotion` / `pointsConversion` / `pointsTransfer` / `flight` / `ticketRedemption` / `initialInput`

### MileageAccount

哩程帳戶，聚合某個計畫的總額與活動資訊。

- `@Relationship(deleteRule: .cascade)` 連接 `Transaction` 和 `FlightGoal`
- `expiryDate()`：取最近交易月份（或 `lastActivityDate`）+ 18 個月，計算到該月月底 23:59:59
- `daysUntilExpiry()`：距離到期的天數

### FlightGoal

航線兌換目標。

- `progress(currentMiles:)` → `Double`（0.0 ~ 1.0，超過 cap 在 1.0）
- `milesNeeded(currentMiles:)` → `Int`（不足的哩程數，最低 0）
- Convenience init：傳入 IATA 代碼自動查詢機場名稱與計算所需哩程
- `isRoundTrip` 為 `true` 時，`requiredMiles` 自動加倍

### CreditCardRule

信用卡計算核心。

| 費率欄位 | 底層 | 對外 | 用途 |
|----------|------|------|------|
| `baseRateValue` | `Double` | `baseRate: Decimal` | 一般消費費率（N 元 = 1 哩） |
| `acceleratorRateValue` | `Double` | `acceleratorRate: Decimal` | 第二費率（國泰:加速器 / 台新:國外） |
| `specialMerchantRateValue` | `Double` | `specialMerchantRate: Decimal` | 第三費率（國泰:同加速器 / 台新:指定消費） |
| `birthdayMultiplierValue` | `Double` | `birthdayMultiplier: Decimal` | 生日月加碼倍數 |

**`calculateMiles(amount:source:subcategoryID:isBirthdayMonth:)`**：

1. 透過 `CardBrandRegistry.rate(for:card:)` 取得對應費率
2. `miles = amount / rate`
3. 若 `isBirthdayMonth` 且來源支援生日加碼 → `miles *= birthdayMultiplier`
4. 依 `roundingMode`（down / up / nearest）進位
5. 回傳 `Int`

**`updateTier(_:)`**：透過 Registry 查找新等級費率並更新所有欄位。

### RedeemedTicket

已兌換機票紀錄，透過 `linkedTransactionID` 關聯扣點交易。

### CardPreference

持久化品牌啟用狀態與選擇等級，用於跨裝置同步卡片偏好。

### MileageProgram

支援多里程計畫。`MilageProgramType` enum 定義計畫類型（目前：`asiaMiles` / `custom`）。`ActiveProgramManager` 透過 UserDefaults 保存當前計畫 ID。

---

## 信用卡規則系統

採用 **Protocol + Registry** 架構，實現品牌定義與業務邏輯的解耦。

### 三層結構

```
CardBrandDefinition (Protocol)
    ├── CathayUnitedBankCard (國泰世華，4 卡別)
    └── TaishinCathayCard    (台新銀行，3 卡別)

CardBrandRegistry (Enum，中央查表)
    ├── definition(for:)     → 查品牌定義
    ├── rate(for:card:)      → 查來源對應費率
    ├── brandForSource(_:)   → 查來源歸屬品牌
    └── sourceSupportsBirthdayBonus(_:brand:) → 查生日加碼支援
```

### CardBrandDefinition Protocol

每個品牌需實作：

| 屬性/方法 | 說明 |
|-----------|------|
| `brandID` | `CardBrand` enum case |
| `tiers` | `[CardTierDefinition]`：各等級費率、漸層色、卡圖、權益 |
| `sourceMappings` | `[CardMileageSourceMapping]`：來源 ↔ 費率 keyPath 對應 |
| `rateSlots` | `[CardRateSlot]`：UI 費率欄位配置 |
| `makeCard(tierID:)` | 工廠方法，建立 `CreditCardRule` 實體 |

### 目前支援的卡別

**國泰世華** (`CathayUnitedBankCard`)：

| 卡別 | 一般 | 加速器 | 年費 | 年度上限 | 加速器生日加碼 |
|------|------|--------|------|----------|----------|
| 世界卡 | 22 元/哩 | 10 元/哩 | 8,000 | 15 萬哩 | 2x |
| 鈦商卡 | 25 元/哩 | 10 元/哩 | 1,800 | 10 萬哩 | 2x |
| 白金卡 | 30 元/哩 | 15 元/哩 | 500 | 5 萬哩 | 2x |
| 里享卡 | 30 元/哩 | 30 元/哩 | 288 | 無上限 | 2x |

**台新銀行** (`TaishinCathayCard`)：

| 卡別 | 國內 | 國外 | 指定消費 | 年費 | 生日加碼 |
|------|------|------|----------|------|----------|
| 世界卡 | 22 元/哩 | 15 元/哩 | 5 元/哩 | 20,000 | 無 |
| 翱翔鈦金卡 | 25 元/哩 | 15 元/哩 | 5 元/哩 | 2,400 | 無 |
| 鈦金卡 | 30 元/哩 | 25 元/哩 | 5 元/哩 | 0 | 無 |

### 新增銀行品牌步驟

1. 在 `CardBrand` enum 新增 case
2. 在 `Models/CardDefinitions/` 新增 `XXXCard.swift`，實作 `CardBrandDefinition`
3. 在 `CardBrandRegistry.allDefinitions` 加入實體
4. 若有新的 `MileageSource`，在 `MileageSource` enum 新增 case

---

## 航線計算引擎

### FlightCalculator (`CathayAwardChart.swift`)

Asia Miles 2026 年兌換表計算引擎。

**航距級別判定** (`determineZone`)：

| 級別 | 距離範圍 | 備註 |
|------|----------|------|
| 超短途 | 1–750 哩 |香港 |
| 短途 1 | 751–2,750 哩 | 東南亞國家/大陸 |
| 短途 2 | 751–2,750 哩 | 日本 |
| 中程 | 2,751–5,000 哩 | |
| 長程 | 5,001–7,500 哩 | |
| 超長程 | 7,501 哩以上 | |

短途 1 vs 短途 2 的關鍵判定：同一距離範圍內，依目的地 IATA 代碼區分。（`shortHaul2Cities` ）

**兌換表** (單程，國泰自家航班)：

| 級別 | 經濟 | 豪經 | 商務 | 頭等 |
|------|------|------|------|------|
| 超短途 | 7,500 | 11,000 | 16,000 | — |
| 短途 1 | 9,000 | 20,000 | 28,000 | 43,000 |
| 短途 2 | 13,000 | 23,000 | 32,000 | 50,000 |
| 中程 | 20,000 | 38,000 | 58,000 | 90,000 |
| 長程 | 27,000 | 50,000 | 88,000 | 125,000 |
| 超長程 | 38,000 | 75,000 | 115,000 | 160,000 |

### AirportDatabase (`AirportDatabase.swift`)

內建約 40 個亞太常用機場資料，支援：

- IATA 代碼查詢（不分大小寫）
- Haversine 公式計算兩點距離（公里→哩）
- 中/英文城市名稱搜尋
- 熱門機場排序清單

---

## ViewModel 層

`MileageViewModel` 使用 `@Observable` 巨集，透過 extension 按職責分為 5 個檔案。

### 主檔 `MileageViewModel.swift` (~117 行)

- 所有共享狀態宣告（`mileageAccount`, `creditCards`, `transactions`, `flightGoals` 等）
- `userBirthdayMonth`（UserDefaults 持久化）
- `isBirthdayMonth(for:)` 判定
- `saveContext()` — 統一儲存，失敗時設定 `saveError` / `showSaveError` 供 UI Alert
- `loadData()` — 依 `activeProgram` 載入帳戶、交易、目標、卡片、兌換紀錄
- CloudKit 遠端同步狀態（`hasRemoteChanges`, `knownDataFingerprint` 等）

### `MileageViewModel+Program.swift`

| 方法 | 說明 |
|------|------|
| `loadPrograms()` | 載入所有計畫，無預設則建立 Asia Miles |
| `switchProgram(to:)` | 切換啟用計畫並重新 loadData |
| `addProgram(...)` | 新增自訂計畫 |
| `deleteProgram(...)` | 刪除計畫（保護最後一個） |
| `deduplicateDefaultPrograms()` | CloudKit 同步可能產生重複，僅保留最新 |
| `migrateExistingDataToProgram()` | 首次加入計畫系統時遷移既有資料 |
| `migrateOrphanedDataToActiveProgram()` | 遷移無主資料到當前計畫 |

### `MileageViewModel+Transaction.swift`

| 方法 | 說明 |
|------|------|
| `addTransaction(...)` | 新增交易並更新帳戶哩程 |
| `updateTransaction(...)` | 修改既有交易 |
| `deleteTransaction(...)` | 刪除交易並扣回哩程 |
| `addFlightGoal(...)` | 新增飛行目標 |
| `deleteFlightGoal(...)` | 刪除目標 |
| `redeemGoal(...)` | 兌換目標 → 建立扣點交易 + RedeemedTicket |
| `deleteRedeemedTicket(...)` | 刪除兌換紀錄並退回哩程 |
| `pinnedGoals()` | 回傳已釘選目標 |
| `closestGoal()` | 回傳最接近可兌換的目標 |
| `redeemableGoals()` | 回傳所有可兌換目標 |
| `previewMiles(...)` | 預覽刷卡可獲哩程 |
| `monthlyStats(...)` | 月份統計（交易數、哩程數、消費金額） |

### `MileageViewModel+Card.swift`

| 方法 | 說明 |
|------|------|
| `rebuildCreditCards()` | 從 CardPreference + Registry 重建卡片列表 |
| `saveCardPreferences()` | 將當前卡片狀態寫入 CardPreference |
| `addCreditCard(...)` | 新增卡片 |
| `deleteCreditCard(...)` | 刪除卡片 |
| `toggleCardActive(...)` | 切換啟用/停用 |
| `updateCardTier(...)` | 更新卡片等級 |

### `MileageViewModel+Sync.swift`

| 方法 | 說明 |
|------|------|
| `initialize(context:)` | 設定 ModelContext、載入程式/資料、啟動遠端監聽 |
| `handleRemoteChange()` | 1 秒 debounce 後比對指紋決定是否重新載入 |
| `acknowledgeRemoteChanges()` | 使用者確認遠端變更後重新載入 |
| `manualSyncNow()` | 手動觸發同步檢查 |
| `fetchDataFingerprint()` | 計算資料雜湊指紋 |

---

## Service 層

### CloudBackupService

手動備份與還原服務，使用 CloudKit 自訂 Zone。

- 備份格式：`MileryBackup`（JSON），包含帳戶、交易、目標、機票、卡片偏好
- 版本化格式（支援 v1 / v2 / v3 舊版解碼）
- 備份時序列化當前計畫所有資料
- 還原時清除當前計畫資料後重建

### DeveloperAccessService

開發者模式存取控制。透過 CloudKit 公開記錄查詢 + 雜湊白名單比對，確認目前登入的 iCloud 使用者是否具備開發者權限。

#### 驗證目標

這個服務驗證的不是裝置、不是 App 版本，也不是 Apple ID 電子郵件，而是「目前登入這台裝置的 CloudKit 使用者身分」是否落在遠端白名單內。

#### 驗證流程

1. 先確認 iCloud 帳號可用，若 `accountStatus()` 不是 `.available` 就直接拒絕。
2. 取得目前使用者的 `userRecordID`。
3. 將 `userRecordID.recordName` 做 SHA-256，轉成 16 進位字串。
4. 再把結果做一次正規化，只保留 0-9 與 a-f，避免貼上雜訊或大小寫差異。
5. 到 CloudKit 公開資料庫讀取固定記錄 `DevAccessPolicy/main-dev-access-policy`。
6. 檢查該記錄的 `recordType` 必須是 `DevAccessPolicy`。
7. 讀取 `enabled`，若為 `false` 則代表遠端關閉開發者功能。
8. 讀取 `allowedUserHashes`，將內容正規化後組成白名單集合。
9. 比對目前使用者 hash 是否存在於白名單，存在則允許，不存在則拒絕。

#### CloudKit 設計

| Record Type | Record ID | 欄位 | 型別 | 用途 |
|-------------|-----------|------|------|------|
| `DevAccessPolicy` | `main-dev-access-policy` | `enabled` | Bool / NSNumber | 遠端總開關 |
| `DevAccessPolicy` | `main-dev-access-policy` | `allowedUserHashes` | [String] | 允許使用開發者模式的使用者 hash 清單 |

#### Hash 的來源

目前採用的是 `SHA-256(userRecordID.recordName)`。實際流程是先拿 CloudKit 提供的使用者 record name，再用 SHA-256 轉成固定長度的十六進位字串，最後拿這個值去跟白名單比對。

#### 管理者操作方式

`currentUserHashForAdmin()` 會回傳目前登入者的原始 SHA-256 值，方便管理者把它貼進 CloudKit 的 `allowedUserHashes`。為了容錯，這個欄位支援多行或逗號分隔輸入，系統會自動清理格式並去重。

#### 失敗情境

- iCloud 不可用：回傳「無法驗證開發者權限」
- `DevAccessPolicy/main-dev-access-policy` 不存在：回傳白名單設定尚未建立
- `recordType` 不正確：回傳設定格式錯誤
- `enabled = false`：回傳遠端已關閉開發者功能
- 白名單為空：回傳需要先填入 `allowedUserHashes`
- 使用者不在白名單：回傳目前使用者的 hash，讓管理者加入白名單

### AppLockService

App 密碼鎖與生物辨識解鎖服務。

- `@Observable + @MainActor` 單例服務（`AppLockService.shared`）
- `isEnabled`、`isBiometricEnabled` 透過 UserDefaults 持久化
- 4 碼密碼存放於 Keychain（`kSecClassGenericPassword`）
- Keychain 權限使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- 支援 Face ID / Touch ID / Optic ID，使用 `LAContext.evaluatePolicy` 驗證

### ProfileService

個人資料管理服務，處理頭貼儲存/上傳與顯示名稱同步。

- **架構**：`@Observable + @MainActor` 單例（`ProfileService.shared`）
- **本地儲存路徑**：`Documents/ProfileImages/avatar.jpg`
- **圖片處理**：UIGraphicsImageRenderer 縮圖至 512px max，JPEG 品質 0.7
- **CloudKit**：頭貼以 CKAsset 儲存於 UserProfile record 的 `avatarAsset` 欄位

#### 主要方法

| 方法 | 說明 |
|------|------|
| `loadLocalAvatar()` | 從本地 Documents 目錄載入頭貼 |
| `saveAvatar(_ image:)` | 縮圖 → 存本地 → 上傳 CloudKit CKAsset |
| `deleteAvatar()` | 刪除本地檔案 + 清除 CloudKit avatarAsset |
| `uploadAvatarToCloudKit()` | 讀本地 avatar.jpg → CKAsset → 更新 UserProfile record |
| `loadFriendAvatar(for recordName:)` | 從 CloudKit UserProfile 讀取 CKAsset → UIImage（帶 NSCache 快取） |
| `updateDisplayName(_ name:)` | 更新 `@AppStorage("userName")` + CloudKit UserProfile.displayName |

#### 快取策略

好友頭貼使用 `NSCache<NSString, UIImage>` 快取，避免重複下載。key 為好友的 `userRecordName`。

### FriendService（🔴🔧開發中）

好友系統服務，使用 CloudKit **公開資料庫**（`publicCloudDatabase`）。

- **容器**：`iCloud.com.73app.milery`
- **架構**：`@Observable + @MainActor` 單例（`FriendService.shared`）

#### CloudKit Schema（Public Database）

| Record Type | 欄位 | 型別 | 說明 |
|-------------|------|------|------|
| `UserProfile` | `userRecordID` | Reference | 指向 Users record |
| | `friendCode` | String | 6 碼好友代碼 |
| | `displayName` | String | 顯示名稱 |
| | `avatarAsset` | Asset (CKAsset) | 使用者頭貼圖片 |
| | `totalMiles` | Int64 | 總哩程（從本地同步） |
| | `goalCount` | Int64 | 飛行目標數 |
| | `completedRoutesCount` | Int64 | 已兌換機票數 |
| | `lastUpdated` | Date/Time | 最後同步時間 |
| | `sharingEnabled` | Int64 | 分享開關 |
| `FriendRelation` | `fromUserRecordID` | Reference | 發起方 |
| | `toUserRecordID` | Reference | 接收方 |
| | `status` | String | `pending` / `accepted` |
| | `createdAt` | Date/Time | 建立時間 |

> **注意**：CloudKit Development 環境在首次 `save()` 時自動建立 Record Type。部署到 Production 需在 CloudKit Console 手動「Deploy to Production」。

#### 好友代碼

- 6 碼，字元集 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`（排除 O/0/I/1）
- 組合空間：28^6 ≈ 4.8 億
- 碰撞檢查：最多重試 10 次

#### 加好友流程 (`addFriend`)

```
A 輸入 B 的好友碼
  ↓
查詢 B 的 UserProfile → 取得 B 的 userRecordID
  ↓
檢查：不是自己、沒有已存在的 A→B 關係
  ↓
查詢反向：B→A 是否存在？
  ├── 存在 → 建立 A→B (status=accepted)
  └── 不存在 → 建立 A→B (status=pending)
```

**CloudKit Public DB 權限限制**：使用者只能修改自己建立的 record，無法直接修改對方的 `FriendRelation`。因此互加升級分兩階段完成：
1. B 加 A 時，B 偵測到 A→B 存在，建立 B→A 為 `accepted`
2. A 下次 `fetchFriends` 時，偵測到雙向關係都存在，自動將自己的 A→B 從 `pending` 升級為 `accepted`

#### 好友列表查詢 (`fetchFriends`)

```
查詢 fromUserRecordID == me（我加的）
查詢 toUserRecordID == me（別人加的）
  ↓
建立反向 lookup（對方 userID → record）
  ↓
遍歷「我加的」：
  ├── 雙向都存在 → accepted（自動升級自己的 pending）
  ├── 只有我→對方 且 accepted → accepted
  └── 只有我→對方 且 pending → outgoing
  ↓
遍歷「別人加的」：
  └── 對方→我 存在但我沒有反向 → incoming
```

#### 本地數據同步 (`syncLocalStatsToProfile`)

進入好友頁面時自動觸發，讀取 SwiftData 中當前計畫的：
- `MileageAccount.totalMiles`
- `FlightGoal` 數量
- `RedeemedTicket` 數量

更新到 CloudKit UserProfile record，讓好友能看到最新進度。

#### 刪除好友 (`removeFriend`)

刪除雙向的 `FriendRelation` 記錄（我→對方 + 對方→我）。由於 Public DB 權限限制，只有自己建立的 record 能成功刪除，對方建立的會靜默失敗。

---

## View 層

### Tab 結構 (`MainTabView`)

| Tab | View | 功能 |
|-----|------|------|
| 總覽 | `DashboardView` | 哩程概覽、到期倒數、近期交易、最近目標 |
| 進度 | `ProgressView` | 目標進度條、可兌換判定 |
| 記帳 | `CalculatorLedgerView` | 計算機 + 帳本整合 |
| 里程碑 | `MilestonesView` | 已兌換機票展示 |
| 設定 | `SettingsView` | 信用卡管理、備份、主題、開發者工具 |

### 交易相關

- `TransactionFormView`：新增交易表單（來源選擇、金額輸入、卡片選擇、子類別）
- `EditTransactionView`：編輯既有交易
- `CreditCardPageView`：信用卡管理頁面（等級切換、費率預覽）

### 其他頁面

- `AllGoalsView`：所有目標列表
- `OnboardingView`：首次使用引導（10 頁，含個人資料設定頁）
- `CloudBackupView`：備份/還原 UI
- `AppLockView`：App 鎖定時解鎖介面（數字鍵盤 + 生物辨識）
- `AppLockSettingsView`：密碼鎖開關、生物辨識開關、修改密碼
- `BackgroundPickerView`：背景選擇
- `AppIconPickerView`：App 圖示切換
- `NotificationSettingsView`：通知設定
- `ProgramSwitcherView`：里程計畫切換/新增/刪除（非預設）
- `FriendsView`：好友代碼展示、加好友、好友狀態列表、顯示好友頭貼（🔴🔧開發中）
- `ProfileAvatarView`：可重用頭貼元件（有圖 → 圓形 UIImage；無圖 → `person.circle.fill` SF Symbol，cathayJade 色）
- `ProfileEditView`：個人資料編輯頁（PhotosPicker 選擇頭貼、名稱 TextField、好友碼顯示、刪除頭貼）

### DevViews（開發者工具）

| View | 用途 |
|------|------|
| `ConsoleLogView` | App 日誌檢視 |
| `DataManagementView` | 資料管理（匯出、清除） |
| `CloudKitAdvancedView` | CloudKit 進階診斷 |
| `AirportListView` | 機場資料庫瀏覽 |
| `TabVisibilitySettingsView` | Tab 顯示控制 |

---

## 主題與背景系統

### AviationTheme

統一的航空風格設計語言，定義：

- 色彩系統（大地色系淺色 / 金屬色系深色，自動適應 ColorScheme）
- 字級、間距、圓角、陰影
- Gradient 預設組合
- Adaptive color helpers

### 背景系統

| 元件 | 職責 |
|------|------|
| `BackgroundImageManager` | 背景選擇型別與序列化（none/preset/custom/solidColor/gradient）、自訂背景圖片儲存/讀取/刪除（App Documents） |
| `SolidColorDefinition` / `SolidColorRegistry` | 內建純色背景定義，支援依 ColorScheme（light/dark/both）過濾顯示 |
| `GradientDefinition` / `GradientRegistry` | 內建漸層背景定義（含色票 stop、方向、標題色），支援依 ColorScheme 過濾顯示 |
| `BackgroundPickerView` | 背景選擇 UI，顯示「預設」「內建純色背景」「內建漸層背景」「自訂圖片」 |
| `AppBackgroundView` | 統一背景渲染（預設 / 純色 / 漸層 / 預設圖片 / 自訂圖片） |
| `MainTabView` | 監聽系統外觀變更，若目前純色或漸層背景不適用新模式，會自動回退為預設背景 |

背景選擇持久化格式（AppStorage）：

- `none`
- `preset:名稱`
- `custom:檔名`
- `solidColor:HEX`
- `gradient:ID`

可見性策略：

- 純色與漸層皆可標記為 `light`、`dark`、`both`
- `BackgroundPickerView` 僅顯示當前模式可用選項
- 使用者切換模式後，若當前背景不可見，`MainTabView` 會觸發自動回退，避免顯示不一致

圖片背景啟用時會疊加 material + overlay 確保文字可讀性。

---

## 同步與備份流程

### 自動同步（SwiftData + CloudKit）

```
App 啟動
  ↓
建立 CloudKit-backed ModelContainer
  ↓
監聽 NSPersistentStoreRemoteChange
  ↓
收到通知 → 1 秒 debounce（DispatchWorkItem）
  ↓
fetchDataFingerprint() → 與 knownDataFingerprint 比對
  ↓
有變更 → hasRemoteChanges = true → 使用者確認 → loadData()
```

### 手動備份

```
取出當前 program 的帳戶/交易/目標/機票/偏好
  ↓
序列化為 MileryBackup JSON
  ↓
上傳 CloudKit 私有資料庫（自訂 Zone: MileryBackupZone）
```

### 手動還原

```
列出 CloudKit 上的備份清單
  ↓
選擇一份 → 下載 JSON
  ↓
解碼 MileryBackup（支援 v1/v2/v3 格式）
  ↓
清除當前計畫所有資料
  ↓
重建 SwiftData 模型 → saveContext()
```

---

## 測試

### 測試目標

`mileryTests` target，使用 Swift Testing 框架（`import Testing`）。

### 測試檔案

| 檔案 | 測試範圍 |
|------|----------|
| `FlightCalculatorTests.swift` | 航距級別判定、哩程需求查表、shortHaul2 城市判定 |
| `CreditCardRuleTests.swift` | 哩程計算、進位模式、生日加碼、等級切換 |
| `FlightGoalTests.swift` | 進度百分比、剩餘哩程、來回程加倍 |
| `MileageAccountTests.swift` | 到期日計算、哩程更新 |
| `AirportDatabaseTests.swift` | IATA 查詢、距離計算、搜尋功能 |

### 執行方式

- Xcode：`Cmd+U` 或 Test Navigator
- 命令列：

```bash
xcodebuild test -project milery.xcodeproj -scheme milery \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 待補齊

- `CloudBackupService` encode → decode 往返一致性
- 更多邊界條件與異常路徑

---

## 已知限制與後續方向

### 1. 金額精度策略

底層以 `Double` 儲存，對外透過 `Decimal(string: String(doubleValue))` 轉換。此方案在現有消費金額範圍內精度足夠，但極端數值仍可能有微小誤差。長期可評估改為 `Int`（分）儲存，但需處理 CloudKit schema 遷移。

### 2. ViewModel 進一步解耦

目前 ViewModel 已透過 extension 拆分為 5 個檔案（主檔 ~117 行），但所有業務邏輯仍共享同一個 `@Observable` 物件。後續可進一步拆為獨立 Manager（`ProgramManager` / `TransactionService` / `SyncCoordinator` 等）。

### 3. RedeemedTicket 精度

`RedeemedTicket.taxPaid` 仍使用 `NSDecimalNumber(value:)` 轉換，未套用 `String` 中介方案。影響較低（稅金精度需求不如哩程計算嚴格），但應統一。

### 4. Accessibility

目前 UI 尚未加入 `accessibilityLabel` / `accessibilityHint`，VoiceOver 支援有限。

---

## 日常維護

### 新增信用卡品牌

1. 在 `CardBrand` enum 新增 case
2. 在 `Models/CardDefinitions/` 新增 `XXXCard.swift`，實作 `CardBrandDefinition`
3. 在 `CardBrandRegistry.allDefinitions` 加入實體
4. 若有新的消費來源，在 `MileageSource` enum 新增 case
5. 驗證 `TransactionFormView` 可正確選取新來源
6. 補齊測試

### 新增里程計畫

1. 在 `MilageProgramType` enum 新增 case
2. 若有專屬兌換表，新增對應的 Calculator
3. 確認 `loadData()` 的 `programID` 過濾邏輯
4. 更新 `CloudBackupService` 的序列化/反序列化

### 維護個人資料（ProfileService）

1. 頭貼儲存路徑為 `Documents/ProfileImages/avatar.jpg`，變更路徑時需同步更新 `localAvatarURL`
2. CloudKit `avatarAsset` 欄位須在 CloudKit Dashboard 確認已部署到 Production
3. 圖片壓縮參數（512px、JPEG 0.7）可調整，但需考慮 CloudKit 上傳大小限制
4. 好友頭貼快取使用 NSCache，App 重啟後會重新下載
5. 顯示名稱同步：`ProfileService.updateDisplayName` 與 `FriendService.ensureUserProfile` 都會更新 CloudKit，確保邏輯一致

### 維護好友系統（CloudKit 公開資料庫）

1. 確認 CloudKit Dashboard 已建立 `UserProfile` 與 `FriendRelation` record type
2. 若新增欄位，先做相容讀取（提供預設值）避免舊資料解碼失敗
3. 保持互加邏輯一致：反向 pending 需雙方升級為 accepted
4. 測試 iCloud 未登入情境，確認錯誤訊息與 UI 提示可用

### 維護 App 密碼鎖

1. 調整密碼策略時，確認 Keychain 查詢 key 不變（避免舊密碼遺失）
2. 若變更生物辨識流程，需同時測試 Face ID / Touch ID 不可用 fallback 行為
3. 關閉密碼鎖時必須同步清除 Keychain 密碼與生物辨識開關狀態

### 新增資料模型

1. 建立 `@Model` class
2. 在 `MileryApp.swift` 的 Schema 加入新 Model
3. 更新 `MileryBackup` 結構（新增欄位 + 版本號）
4. 補齊遷移邏輯與測試

### 新增 View

1. 在 `Views/` 建立新頁面
2. 若需全域狀態，在對應的 ViewModel extension 新增方法
3. 驗證 CloudKit 同步 + 備份還原不受影響

---
