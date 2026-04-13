# Milery App - 社群與好友功能開發藍圖 (Friend System Roadmap)

## 📌 核心願景 (Core Vision)
將 Milery 定位為具備「社群激勵」與「共同目標」的高質感旅遊理財助理。捨棄浮誇的遊戲化機制，專注於提供極致的 Apple 原生體驗 (WidgetKit, MapKit) 與高隱私的狀態共享 (CloudKit Public Database)。

---

## 🚀 核心功能 1：儀表板動態島 (Friend Activity Block)

### 📍 概念說明
捨棄死板的條列式清單，在首頁 `DashboardView` 中設計類似 Apple Fitness (健身圈) 的橫向滑動卡片區塊，讓使用者每次打開 App 都能無縫掌握好友的最新進度。

### 🎨 UI/UX 實作要求
* **佈局：** 位於總里程卡片下方。使用 `ScrollView(.horizontal, showsIndicators: false)` 搭配 `LazyHStack`。
* **卡片設計：** 採用 Apple 玻璃擬態質感 (Glassmorphism)，背景套用 `AviationTheme` 的卡片背景色。
* **動態文案渲染：** 根據資料庫狀態，自動組成激勵短語。
    * *情境 A (進行中)：* 「阿姿目前距離【東京機票】還差 15% ✈️」
    * *情境 B (剛達標)：* 「170 剛剛達成【首爾來回】目標 🎉」
* **互動：** 點擊單張卡片，透過 `NavigationLink` 進入該好友的「好友詳細儀表板」。

### 💾 資料庫與邏輯擴充
* `UserProfile` (CloudKit Public) 需新增欄位：
    * `currentGoalName` (String): 目前主力目標的名稱。
    * `currentGoalProgress` (Double): 0.0 到 1.0 的進度值。
    * `lastGoalCompleted` (String, Optional): 最近一次達成的目標名稱。

---

## 🎯 核心功能 2：同行集氣計畫 (Co-op Goals / 雙人賽道)

### 📍 概念說明
解決「一起出國，但哩程各自存」的痛點。在 App 內發起「共同行程」，讓雙方在同一個畫面上互相督促消費與集點進度。

### 🎨 UI/UX 實作要求
* **雙軌進度條：** 在 `ProgressView` 中設計「兩條平行的飛機跑道」或「雙人登機門」。
* **視覺設計：** 使用 `GeometryReader` 畫出跑道，兩人的頭像或專屬飛機 Icon 會根據進度百分比停在跑道上的對應位置。
* **數據對比：** 清晰標示雙方進度（如：「Ray 80% (尚缺 3,000 哩) | L 40% (尚缺 15,000 哩)」）。

### 💾 資料庫與邏輯擴充
* **新增 Record Type:** `SharedGoal` (Public DB)
    * `goalName` (String): 行程名稱 (e.g., 2026 釜山畢業旅行)。
    * `creatorRecordID` (Reference): 發起人。
    * `partnerRecordID` (Reference): 參與人。
    * `targetMiles` (Int): 該行程單人所需哩程。
* **同步機制：** 雙方 App 定期從 Public DB 拉取對方的 `totalMiles`，並計算出此 `SharedGoal` 的完成度。

---

## 🔒 核心功能 3：隱私守門員 (Privacy Dashboard)

### 📍 概念說明
哩程與消費進度屬於敏感財務資訊，必須給予使用者最高級別的隱私掌控權，以符合 Apple 對隱私權的嚴格要求。

### 🎨 UI/UX 實作要求
* **位置：** 放置於 `SettingsView` 內的「隱私與社群」區塊。
* **控制元件：** 使用原生的 `Toggle` 開關，並配上詳細的次要說明文字 (Footnote)。
    1.  **「公開總哩程數」：** 關閉時，好友只能看到目標進度(%)，無法看到實際數字。
    2.  **「公開飛行軌跡」：** 關閉時，隱藏好友詳細頁面的已兌換機票紀錄與 3D 地球儀。

### 💾 資料庫與邏輯擴充
* `UserProfile` (CloudKit Public) 需新增布林值欄位：
    * `isTotalMilesPublic` (Int/Bool): 預設為 true。
    * `isHistoryPublic` (Int/Bool): 預設為 true。
* **發布邏輯修改：** 在 `FriendService` 將資料上傳至 Public DB 前，先檢查這些布林值，若為 false 則將對應欄位寫入 `nil` 或 `0`，做到「源頭阻斷」。

---

## 🍏 核心功能 4：桌面小工具同儕連線 (Shared Boarding Pass Widget)

### 📍 概念說明
將共同目標搬上 iPhone 桌面。利用深植於 iOS 原生體驗的設計，展示強大的生態系技術整合能力，是 MAIC 評審極度看重的亮點。

### 🎨 UI/UX 實作要求
* **框架：** 導入 `WidgetKit` 與 `AppIntents`。
* **視覺設計：** 設計成一張精緻的「虛擬登機證」。
    * 背景採用 `AviationTheme` 色系。
    * 佈局分左右兩半（左：我方進度與頭像，右：好友進度與頭像）。
    * 加上登機證常見的條碼、虛線等裝飾元素。
* **尺寸支援：** 支援 `systemMedium` (2x4) 與 `systemLarge` (4x4)。

### 💾 資料庫與邏輯擴充
* **資料獲取：** 在 `TimelineProvider` 中實作輕量級的 CloudKit 查詢，定時去 Public DB 拉取最新的 `SharedGoal` 與 `UserProfile` 進度。
* **App Group：** 需設定 App Groups，讓主 App 與 Widget extension 能共享暫存資料。

---

## 🌍 核心功能 5：3D 航線地球儀共享 (Shared 3D Footprint)

### 📍 概念說明
榨乾 MapKit 效能，視覺化呈現好友「已兌換並完成」的實體航線，滿足航空迷展示戰績的成就感。

### 🎨 UI/UX 實作要求
* **位置：** `FriendDetailDashboard` 頁面上方的主要視覺區塊。
* **框架：** 使用 iOS 17+ `MapKit` 的 `Map` 視圖。
* **視覺設計：**
    * 設定 `.mapStyle(.imagery(elevation: .realistic))` 呈現真實 3D 地球質感。
    * 使用 `MapPolyline` 畫出弧線連接兩地機場座標。
    * 套用發光或漸層特效的線條，展現科技質感。
* **互動：** 允許使用者自由旋轉、縮放地球儀查看航線。

### 💾 資料庫與邏輯擴充
* **資料流：** 需在 CloudKit Public DB 中建立 `PublicFlightRoute` 表單（或將輕量化的座標陣列存入 `UserProfile` 的 `completedRoutes` 欄位）。
* **轉換：** 讀取好友的 IATA 機場代碼 (如 TPE -> NRT)，透過本地的 `AirportDatabase` 轉換為經緯度座標交由 MapKit 渲染。

---
---

# 實作計畫 (Implementation Plan)

> 以下為根據上方 5 項核心功能，結合現有 codebase 架構 (`@Observable` MVVM、CloudKit Public/Private 雙資料庫、SwiftData、AviationTheme 設計系統) 所撰寫的具體實作步驟。

---

## Phase 0：前置準備 (Prerequisites)

### 0-1. CloudKit Schema 擴充

**目標：** 在 CloudKit Dashboard (Development) 新增/修改 Record Type 欄位。

| Record Type | 新增欄位 | 類型 | 說明 |
|---|---|---|---|
| `UserProfile` | `currentGoalName` | String | 主力目標名稱 |
| `UserProfile` | `currentGoalProgress` | Double | 0.0~1.0 進度 |
| `UserProfile` | `lastGoalCompleted` | String | 最近達成的目標 (Optional) |
| `UserProfile` | `isTotalMilesPublic` | Int64 | 1=公開, 0=隱藏 (預設 1) |
| `UserProfile` | `isHistoryPublic` | Int64 | 1=公開, 0=隱藏 (預設 1) |
| `SharedGoal` *(新建)* | `goalName` | String | 行程名稱 |
| `SharedGoal` | `creatorRecordID` | Reference (→Users) | 發起人 |
| `SharedGoal` | `partnerRecordID` | Reference (→Users) | 參與人 |
| `SharedGoal` | `targetMiles` | Int64 | 單人所需哩程 |
| `SharedGoal` | `creatorProgress` | Double | 發起人當前進度 |
| `SharedGoal` | `partnerProgress` | Double | 參與人當前進度 |
| `SharedGoal` | `status` | String | `active` / `completed` / `cancelled` |
| `SharedGoal` | `createdAt` | Date/Time | 建立時間 |
| `PublicFlightRoute` *(新建)* | `ownerRecordID` | Reference (→Users) | 擁有者 |
| `PublicFlightRoute` | `originIATA` | String | 出發機場 IATA |
| `PublicFlightRoute` | `destinationIATA` | String | 目的機場 IATA |
| `PublicFlightRoute` | `flightDate` | Date/Time | 飛行日期 |

**操作步驟：**
1. 打開 [CloudKit Dashboard](https://icloud.developer.apple.com) → 選擇 `iCloud.com.73app.milery` Container
2. 進入 Schema → Record Types → 點選 `UserProfile` → Add Field 新增上述 5 個欄位
3. 新建 `SharedGoal` Record Type，加入上述欄位並設定 Index（`creatorRecordID` QUERYABLE、`partnerRecordID` QUERYABLE、`status` QUERYABLE）
4. 新建 `PublicFlightRoute` Record Type，加入上述欄位並設定 `ownerRecordID` QUERYABLE
5. **注意：** Development 環境也可透過首次 `CKRecord.save()` 自動建立 schema（現有 `FriendService` 已採用此策略），但建議先手動建立以確保 Index 正確

### 0-2. App Group 設定 (for Widget)

**目標：** 讓主 App 與 `MileryWidgetExtension` 共享資料。

**操作步驟：**
1. Xcode → milery Target → Signing & Capabilities → + Capability → App Groups
2. 新增 Group ID：`group.com.73app.milery`
3. 對 `MileryWidgetExtension` Target 重複相同步驟
4. 在 `milery.entitlements` 與 `MileryWidgetExtension.entitlements` 中確認已包含此 Group
5. 建立共享資料存取工具：

```swift
// 新建檔案：milery/Service/SharedDataService.swift
import Foundation

enum SharedDataService {
    static let suiteName = "group.com.73app.milery"
    static let defaults = UserDefaults(suiteName: suiteName)!

    // Keys
    static let totalMilesKey = "widget_totalMiles"
    static let currentGoalNameKey = "widget_currentGoalName"
    static let currentGoalProgressKey = "widget_currentGoalProgress"
    static let partnerNameKey = "widget_partnerName"
    static let partnerProgressKey = "widget_partnerProgress"
    static let sharedGoalNameKey = "widget_sharedGoalName"

    static func writeMilesData(totalMiles: Int, goalName: String?, goalProgress: Double?) {
        defaults.set(totalMiles, forKey: totalMilesKey)
        defaults.set(goalName, forKey: currentGoalNameKey)
        defaults.set(goalProgress ?? 0, forKey: currentGoalProgressKey)
    }

    static func writeSharedGoalData(partnerName: String, partnerProgress: Double, goalName: String) {
        defaults.set(partnerName, forKey: partnerNameKey)
        defaults.set(partnerProgress, forKey: partnerProgressKey)
        defaults.set(goalName, forKey: sharedGoalNameKey)
    }
}
```

### 0-3. FriendData 模型擴充

**檔案：** `milery/Service/FriendService.swift`

在 `FriendData` struct 中新增欄位：

```swift
struct FriendData: Identifiable {
    let id: String
    let displayName: String
    let friendCode: String
    let status: String
    let isIncoming: Bool
    let userRecordName: String
    // 已有欄位
    let totalMiles: Int
    let goalCount: Int
    let completedRoutesCount: Int
    // ✅ 新增欄位
    let currentGoalName: String?        // 功能 1
    let currentGoalProgress: Double?    // 功能 1
    let lastGoalCompleted: String?      // 功能 1
    let isTotalMilesPublic: Bool        // 功能 3
    let isHistoryPublic: Bool           // 功能 3
}
```

同時修改 `fetchFriends()` 與 `resolveProfile()` 中建構 `FriendData` 的地方，讀取新欄位。

---

## Phase 1：核心功能 3 — 隱私守門員 (Privacy Dashboard)

> **優先實作理由：** 隱私機制是其他功能的前提。上傳資料前必須先有開關控制，否則後續功能會洩漏使用者不願公開的資訊。

### 步驟 1-1. 新增隱私設定 UI

**檔案：** `milery/Views/SettingsView.swift`

在 `SettingsView` 的 `body` 中，找到合適的 Section 位置（建議在「好友」相關 Section 附近），新增：

```swift
// MARK: - 隱私與社群
Section {
    Toggle(isOn: $isTotalMilesPublic) {
        VStack(alignment: .leading, spacing: 4) {
            Text("公開總哩程數")
                .font(AviationTheme.Typography.body)
            Text("關閉時，好友只能看到目標進度百分比")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
        }
    }
    .tint(AviationTheme.Colors.brandColor(colorScheme))

    Toggle(isOn: $isHistoryPublic) {
        VStack(alignment: .leading, spacing: 4) {
            Text("公開飛行軌跡")
                .font(AviationTheme.Typography.body)
            Text("關閉時，好友無法查看兌換紀錄與航線地圖")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
        }
    }
    .tint(AviationTheme.Colors.brandColor(colorScheme))
} header: {
    Text("隱私與社群")
}
```

**State 綁定：** 使用 `@AppStorage` 並在切換時同步到 CloudKit：

```swift
@AppStorage("isTotalMilesPublic") private var isTotalMilesPublic: Bool = true
@AppStorage("isHistoryPublic") private var isHistoryPublic: Bool = true
```

搭配 `.onChange(of: isTotalMilesPublic)` 與 `.onChange(of: isHistoryPublic)` 呼叫 `FriendService.shared.updatePrivacySettings(...)`。

### 步驟 1-2. FriendService 隱私同步方法

**檔案：** `milery/Service/FriendService.swift`

新增方法：

```swift
// MARK: - Privacy Settings Sync

func updatePrivacySettings(isTotalMilesPublic: Bool, isHistoryPublic: Bool) async {
    guard let profile = currentUserProfile else { return }
    do {
        let record = try await database.record(for: profile.recordID)
        record["isTotalMilesPublic"] = (isTotalMilesPublic ? 1 : 0) as CKRecordValue
        record["isHistoryPublic"] = (isHistoryPublic ? 1 : 0) as CKRecordValue
        _ = try await database.save(record)
        appLog("[FriendService] 隱私設定已更新")
    } catch {
        appLog("[FriendService] 隱私設定更新失敗: \(error.localizedDescription)")
    }
}
```

### 步驟 1-3. 修改 syncLocalStatsToProfile — 源頭阻斷

**檔案：** `milery/Service/FriendService.swift`

在 `syncLocalStatsToProfile(context:)` 中，上傳前檢查隱私開關：

```swift
let isMilesPublic = UserDefaults.standard.bool(forKey: "isTotalMilesPublic")
// ...
record["totalMiles"] = (isMilesPublic ? totalMiles : 0) as CKRecordValue
```

如果 `isHistoryPublic == false`，則不上傳 `completedRoutesCount`（設為 0）且不寫入 `PublicFlightRoute` records。

---

## Phase 2：核心功能 1 — 儀表板動態島 (Friend Activity Block)

### 步驟 2-1. syncLocalStatsToProfile 擴充 — 上傳目標進度

**檔案：** `milery/Service/FriendService.swift` → `syncLocalStatsToProfile(context:)`

在現有同步邏輯後，新增目標進度計算：

```swift
// 計算主力目標進度
let allGoals = try context.fetch(FetchDescriptor<FlightGoal>())
let programGoals = allGoals.filter { $0.programID == activePID }
let priorityGoal = programGoals.first(where: { $0.isPriority }) ?? programGoals.first

if let goal = priorityGoal {
    let progress = goal.progress(currentMiles: totalMiles)
    record["currentGoalName"] = "\(goal.originName)→\(goal.destinationName)" as CKRecordValue
    record["currentGoalProgress"] = progress as CKRecordValue

    if progress >= 1.0 {
        record["lastGoalCompleted"] = "\(goal.originName)→\(goal.destinationName)" as CKRecordValue
    }
}
```

### 步驟 2-2. 建立 FriendActivityCard 元件

**新建檔案：** `milery/Views/FriendActivityCard.swift`

```swift
import SwiftUI

struct FriendActivityCard: View {
    @Environment(\.colorScheme) var colorScheme
    let friend: FriendService.FriendData

    private var statusText: String {
        if let completed = friend.lastGoalCompleted, !completed.isEmpty {
            return "\(friend.displayName) 剛達成【\(completed)】"
        }
        if let goalName = friend.currentGoalName,
           let progress = friend.currentGoalProgress, progress > 0 {
            let remaining = Int((1.0 - progress) * 100)
            return "\(friend.displayName) 距離【\(goalName)】還差 \(remaining)%"
        }
        return "\(friend.displayName) 正在累積哩程中"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            // 頭像 + 名稱
            HStack(spacing: AviationTheme.Spacing.sm) {
                ProfileAvatarView(userRecordName: friend.userRecordName, size: 36)
                Text(friend.displayName)
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }

            // 進度條
            if let progress = friend.currentGoalProgress, progress > 0 {
                ProgressView(value: progress)
                    .tint(AviationTheme.Colors.brandColor(colorScheme))
            }

            // 動態文案
            Text(statusText)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))

            // 哩程數（尊重隱私設定）
            if friend.isTotalMilesPublic {
                Text("\(friend.totalMiles.formatted()) 哩")
                    .font(AviationTheme.Typography.monoDigits(size: 14))
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
        }
        .padding(AviationTheme.Spacing.md)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AviationTheme.Colors.cardBorder(colorScheme), lineWidth: 0.5)
                )
        )
    }
}
```

### 步驟 2-3. 在 DashboardView 中嵌入好友動態區塊

**檔案：** `milery/Views/DashboardView.swift`

在 `RecentActivityCard` 之前插入：

```swift
// 好友動態（僅有已接受好友時顯示）
if !FriendService.shared.friends.isEmpty {
    FriendActivitySection(friends: FriendService.shared.friends)
}
```

**新建或嵌入 FriendActivitySection：**

```swift
struct FriendActivitySection: View {
    @Environment(\.colorScheme) var colorScheme
    let friends: [FriendService.FriendData]

    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                Text("好友動態")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AviationTheme.Spacing.md) {
                    ForEach(friends) { friend in
                        NavigationLink(destination: FriendDetailDashboard(friend: friend)) {
                            FriendActivityCard(friend: friend)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
```

### 步驟 2-4. 建立 FriendDetailDashboard 頁面

**新建檔案：** `milery/Views/FriendDetailDashboard.swift`

此頁面包含：
- 好友頭像與暱稱 (大尺寸)
- 總哩程 (若 `isTotalMilesPublic`)
- 目標進度列表 (含百分比)
- 3D 航線地球儀 (若 `isHistoryPublic`，Phase 5 實作)
- 已兌換機票紀錄 (若 `isHistoryPublic`)

```swift
import SwiftUI

struct FriendDetailDashboard: View {
    @Environment(\.colorScheme) var colorScheme
    let friend: FriendService.FriendData

    var body: some View {
        ScrollView {
            VStack(spacing: AviationTheme.Spacing.lg) {
                // 頭像 + 暱稱
                ProfileAvatarView(userRecordName: friend.userRecordName, size: 80)
                Text(friend.displayName)
                    .font(AviationTheme.Typography.title2)

                // 統計卡片
                HStack(spacing: AviationTheme.Spacing.md) {
                    StatCard(title: "總哩程",
                             value: friend.isTotalMilesPublic ? "\(friend.totalMiles.formatted())" : "隱藏",
                             icon: "airplane")
                    StatCard(title: "目標數", value: "\(friend.goalCount)", icon: "target")
                    StatCard(title: "飛行紀錄",
                             value: friend.isHistoryPublic ? "\(friend.completedRoutesCount)" : "隱藏",
                             icon: "globe.americas")
                }

                // 目標進度
                if let goalName = friend.currentGoalName,
                   let progress = friend.currentGoalProgress {
                    GoalProgressCard(goalName: goalName, progress: progress)
                }

                // 3D 地球儀預留位置 (Phase 5)
                if friend.isHistoryPublic {
                    // SharedFlightGlobeView(userRecordName: friend.userRecordName)
                    Text("航線地圖 (開發中)")
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            .padding(AviationTheme.Spacing.md)
        }
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

---

## Phase 3：核心功能 2 — 同行集氣計畫 (Co-op Goals)

### 步驟 3-1. SharedGoalService 服務

**新建檔案：** `milery/Service/SharedGoalService.swift`

```swift
import Foundation
import CloudKit

@MainActor
@Observable
final class SharedGoalService {
    static let shared = SharedGoalService()

    private let container = CKContainer(identifier: "iCloud.com.73app.milery")
    private var database: CKDatabase { container.publicCloudDatabase }

    var activeGoals: [SharedGoalData] = []
    var isLoading = false

    struct SharedGoalData: Identifiable {
        let id: String          // CKRecord.ID.recordName
        let goalName: String
        let targetMiles: Int
        let creatorName: String
        let partnerName: String
        let creatorProgress: Double
        let partnerProgress: Double
        let isCreator: Bool     // 當前使用者是否為發起人
        let status: String
    }

    // 建立共同目標
    func createSharedGoal(goalName: String, targetMiles: Int, partnerFriendCode: String) async throws { ... }

    // 拉取所有與我相關的 SharedGoal
    func fetchMySharedGoals() async { ... }

    // 更新自己的進度（由 syncLocalStatsToProfile 觸發）
    func syncMyProgress(currentMiles: Int) async { ... }
}
```

**核心邏輯：**
- `createSharedGoal`：查詢 partner 的 `userRecordID` → 建立 `SharedGoal` CKRecord → 設定 `creatorRecordID` = 自己、`partnerRecordID` = 對方
- `fetchMySharedGoals`：組合查詢 `creatorRecordID == me OR partnerRecordID == me` → 再 resolve 雙方 displayName
- `syncMyProgress`：找到 active 的 SharedGoal → 計算 `min(currentMiles / targetMiles, 1.0)` → 更新對應的 `creatorProgress` 或 `partnerProgress`

### 步驟 3-2. 建立共同目標 UI — CreateSharedGoalView

**新建檔案：** `milery/Views/CreateSharedGoalView.swift`

- 表單包含：行程名稱 (TextField)、所需哩程 (NumberField)、好友選擇 (Picker，從 `FriendService.shared.friends` 中選)
- 確認後呼叫 `SharedGoalService.shared.createSharedGoal(...)`
- 入口放在 `FriendsView` 中的 Section header 或 toolbar

### 步驟 3-3. 雙軌跑道進度 UI — SharedGoalRunwayView

**新建檔案：** `milery/Views/SharedGoalRunwayView.swift`

使用 `GeometryReader` 實作雙跑道視覺效果：

```swift
import SwiftUI

struct SharedGoalRunwayView: View {
    @Environment(\.colorScheme) var colorScheme
    let goal: SharedGoalService.SharedGoalData

    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            Text(goal.goalName)
                .font(AviationTheme.Typography.headline)

            Text("目標：\(goal.targetMiles.formatted()) 哩/人")
                .font(AviationTheme.Typography.caption)

            // 雙軌跑道
            VStack(spacing: AviationTheme.Spacing.sm) {
                RunwayTrack(
                    name: goal.creatorName,
                    progress: goal.creatorProgress,
                    targetMiles: goal.targetMiles,
                    isMe: goal.isCreator
                )
                RunwayTrack(
                    name: goal.partnerName,
                    progress: goal.partnerProgress,
                    targetMiles: goal.targetMiles,
                    isMe: !goal.isCreator
                )
            }
        }
        .padding(AviationTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

struct RunwayTrack: View {
    @Environment(\.colorScheme) var colorScheme
    let name: String
    let progress: Double
    let targetMiles: Int
    let isMe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(isMe ? .bold : .regular)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(AviationTheme.Typography.monoDigits(size: 14))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 跑道背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AviationTheme.Colors.cardBackground(colorScheme).opacity(0.3))
                        .frame(height: 24)

                    // 進度填充
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AviationTheme.Colors.brandColor(colorScheme))
                        .frame(width: geo.size.width * CGFloat(progress), height: 24)

                    // 飛機 Icon
                    Image(systemName: "airplane")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .offset(x: max(0, geo.size.width * CGFloat(progress) - 20))
                }
            }
            .frame(height: 24)

            // 尚缺哩程
            let remaining = max(targetMiles - Int(Double(targetMiles) * progress), 0)
            Text("尚缺 \(remaining.formatted()) 哩")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
        }
    }
}
```

### 步驟 3-4. 整合入口

- **ProgressView (進度頁)：** 在現有目標列表上方，加入 SharedGoal 區塊。若有 active 的 SharedGoal，顯示 `SharedGoalRunwayView`
- **FriendsView：** 在好友列表下方加入「共同目標」Section，列出所有 SharedGoal，點擊可查看詳情
- **DashboardView：** 在好友動態 Section 中，若有 active SharedGoal，優先顯示一張 SharedGoal 摘要卡片

---

## Phase 4：核心功能 4 — 桌面小工具同儕連線 (Shared Boarding Pass Widget)

### 步驟 4-1. 重構 Widget TimelineProvider

**檔案：** `MileryWidget/MileryWidget.swift`

將 `Provider` 改為讀取 App Group 共享資料：

```swift
struct Provider: AppIntentTimelineProvider {
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let defaults = UserDefaults(suiteName: "group.com.73app.milery")

        let totalMiles = defaults?.integer(forKey: "widget_totalMiles") ?? 0
        let goalName = defaults?.string(forKey: "widget_currentGoalName")
        let goalProgress = defaults?.double(forKey: "widget_currentGoalProgress") ?? 0
        let partnerName = defaults?.string(forKey: "widget_partnerName")
        let partnerProgress = defaults?.double(forKey: "widget_partnerProgress") ?? 0
        let sharedGoalName = defaults?.string(forKey: "widget_sharedGoalName")

        let entry = SimpleEntry(
            date: Date(),
            totalMiles: totalMiles,
            goalName: goalName,
            goalProgress: goalProgress,
            partnerName: partnerName,
            partnerProgress: partnerProgress,
            sharedGoalName: sharedGoalName
        )

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
```

### 步驟 4-2. 更新 SimpleEntry

```swift
struct SimpleEntry: TimelineEntry {
    let date: Date
    let totalMiles: Int
    let goalName: String?
    let goalProgress: Double
    let partnerName: String?
    let partnerProgress: Double
    let sharedGoalName: String?
}
```

### 步驟 4-3. 登機證 Widget UI — BoardingPassWidgetView

**新建檔案：** `MileryWidget/BoardingPassWidgetView.swift`

```swift
import SwiftUI
import WidgetKit

struct BoardingPassWidgetView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumBoardingPass(entry: entry)
        case .systemLarge:
            LargeBoardingPass(entry: entry)
        default:
            SmallMilesWidget(entry: entry)
        }
    }
}

struct MediumBoardingPass: View {
    let entry: SimpleEntry

    var body: some View {
        HStack(spacing: 0) {
            // 左半：我方
            VStack(alignment: .leading, spacing: 4) {
                Text("ME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("\(entry.totalMiles.formatted())")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("MILES")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                if entry.goalProgress > 0 {
                    ProgressView(value: entry.goalProgress)
                        .tint(.green)
                    Text("\(Int(entry.goalProgress * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity)

            // 虛線分隔
            DashedDivider()

            // 右半：好友
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.partnerName?.uppercased() ?? "FRIEND")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let _ = entry.partnerName {
                    Text("\(Int(entry.partnerProgress * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    ProgressView(value: entry.partnerProgress)
                        .tint(.blue)
                } else {
                    Text("--")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
```

### 步驟 4-4. Widget 尺寸與登記

**檔案：** `MileryWidget/MileryWidget.swift`

```swift
struct MileryWidget: Widget {
    let kind: String = "MileryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BoardingPassWidgetView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        colors: [Color(red: 0.004, green: 0.337, blue: 0.302), Color(red: 0.004, green: 0.2, blue: 0.18)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName("Milery 登機證")
        .description("追蹤你與好友的哩程進度")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### 步驟 4-5. 主 App 寫入共享資料

在 `MileageViewModel+Sync.swift` 或 `FriendService.syncLocalStatsToProfile()` 結尾加入：

```swift
// 同步寫入 App Group，供 Widget 讀取
SharedDataService.writeMilesData(
    totalMiles: totalMiles,
    goalName: priorityGoal?.destinationName,
    goalProgress: priorityGoal?.progress(currentMiles: totalMiles)
)
// 同步 SharedGoal 資料
if let activeSharedGoal = SharedGoalService.shared.activeGoals.first(where: { $0.status == "active" }) {
    SharedDataService.writeSharedGoalData(
        partnerName: activeSharedGoal.isCreator ? activeSharedGoal.partnerName : activeSharedGoal.creatorName,
        partnerProgress: activeSharedGoal.isCreator ? activeSharedGoal.partnerProgress : activeSharedGoal.creatorProgress,
        goalName: activeSharedGoal.goalName
    )
}
// 通知 WidgetKit 更新
WidgetCenter.shared.reloadAllTimelines()
```

---

## Phase 5：核心功能 5 — 3D 航線地球儀共享 (Shared 3D Footprint)

### 步驟 5-1. PublicFlightRoute 上傳

**檔案：** `milery/Service/FriendService.swift`

新增方法，在使用者兌換機票後，將航線上傳至 Public DB（需檢查 `isHistoryPublic`）：

```swift
// MARK: - Public Flight Route Sync

func uploadFlightRoute(origin: String, destination: String, flightDate: Date) async {
    guard let profile = currentUserProfile else { return }
    guard UserDefaults.standard.bool(forKey: "isHistoryPublic") else {
        appLog("[FriendService] 飛行軌跡已設為隱藏，跳過上傳")
        return
    }

    let userRef = profile.userRecordID
    let record = CKRecord(recordType: "PublicFlightRoute")
    record["ownerRecordID"] = userRef
    record["originIATA"] = origin as CKRecordValue
    record["destinationIATA"] = destination as CKRecordValue
    record["flightDate"] = flightDate as CKRecordValue

    do {
        _ = try await database.save(record)
        appLog("[FriendService] 上傳航線成功: \(origin)→\(destination)")
    } catch {
        appLog("[FriendService] 上傳航線失敗: \(error.localizedDescription)")
    }
}

func fetchFlightRoutes(for userRecordName: String) async -> [(origin: String, destination: String, date: Date)] {
    // 查詢該使用者的所有 PublicFlightRoute
    // 返回 [(originIATA, destinationIATA, flightDate)]
}
```

### 步驟 5-2. 3D 地球儀 View

**新建檔案：** `milery/Views/SharedFlightGlobeView.swift`

```swift
import SwiftUI
import MapKit

struct SharedFlightGlobeView: View {
    let routes: [(origin: Airport, destination: Airport)]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                // 大圓弧線
                MapPolyline(coordinates: greatCirclePoints(
                    from: route.origin.coordinate,
                    to: route.destination.coordinate
                ))
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )

                // 起點標記
                Annotation(route.origin.iataCode, coordinate: route.origin.coordinate) {
                    Circle()
                        .fill(.cyan)
                        .frame(width: 6, height: 6)
                }

                // 終點標記
                Annotation(route.destination.iataCode, coordinate: route.destination.coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // 大圓弧線採樣點
    private func greatCirclePoints(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, segments: Int = 50) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        let lat1 = from.latitude.radians, lon1 = from.longitude.radians
        let lat2 = to.latitude.radians, lon2 = to.longitude.radians
        let d = acos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(lon2-lon1))

        for i in 0...segments {
            let f = Double(i) / Double(segments)
            let A = sin((1-f)*d) / sin(d)
            let B = sin(f*d) / sin(d)
            let x = A*cos(lat1)*cos(lon1) + B*cos(lat2)*cos(lon2)
            let y = A*cos(lat1)*sin(lon1) + B*cos(lat2)*sin(lon2)
            let z = A*sin(lat1) + B*sin(lat2)
            let lat = atan2(z, sqrt(x*x + y*y))
            let lon = atan2(y, x)
            points.append(CLLocationCoordinate2D(latitude: lat.degrees, longitude: lon.degrees))
        }
        return points
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
```

### 步驟 5-3. 整合到 FriendDetailDashboard

在 `FriendDetailDashboard` 中，若 `friend.isHistoryPublic == true`：

1. 在 `.task {}` 中呼叫 `FriendService.shared.fetchFlightRoutes(for: friend.userRecordName)`
2. 將回傳的 IATA codes 透過 `AirportDatabase` 轉換為座標
3. 傳入 `SharedFlightGlobeView(routes: convertedRoutes)`

---

## Phase 6：整合測試與收尾

### 6-1. 單元測試

**新建檔案：** `mileryTests/SharedGoalTests.swift`

- 測試 `SharedGoalData` 進度計算
- 測試 `SharedGoalService` 資料轉換邏輯

**新建檔案：** `mileryTests/PrivacyFilterTests.swift`

- 測試隱私開關為 false 時，`syncLocalStatsToProfile` 上傳的值為 0
- 測試 `FriendData` 的 `isTotalMilesPublic` 正確影響 UI 顯示

### 6-2. Widget Preview 測試

在 `MileryWidget.swift` 中更新 `#Preview`：

```swift
#Preview(as: .systemMedium) {
    MileryWidget()
} timeline: {
    SimpleEntry(date: .now, totalMiles: 28500, goalName: "東京", goalProgress: 0.72,
                partnerName: "阿姿", partnerProgress: 0.45, sharedGoalName: "2026 東京之旅")
}
```

### 6-3. CloudKit Production Deploy

完成所有開發測試後：
1. CloudKit Dashboard → Deploy Schema to Production
2. 確認所有新 Record Types（`SharedGoal`、`PublicFlightRoute`）與 UserProfile 新欄位都已部署

---

## 檔案總覽 (File Inventory)

| 操作 | 檔案路徑 | 說明 |
|---|---|---|
| **新建** | `milery/Service/SharedDataService.swift` | App Group 共享資料工具 |
| **新建** | `milery/Service/SharedGoalService.swift` | 共同目標服務 |
| **新建** | `milery/Views/FriendActivityCard.swift` | 好友動態卡片元件 |
| **新建** | `milery/Views/FriendDetailDashboard.swift` | 好友詳細儀表板 |
| **新建** | `milery/Views/CreateSharedGoalView.swift` | 建立共同目標表單 |
| **新建** | `milery/Views/SharedGoalRunwayView.swift` | 雙軌跑道進度 UI |
| **新建** | `milery/Views/SharedFlightGlobeView.swift` | 3D 航線地球儀 |
| **新建** | `MileryWidget/BoardingPassWidgetView.swift` | 登機證 Widget UI |
| **新建** | `mileryTests/SharedGoalTests.swift` | 共同目標測試 |
| **新建** | `mileryTests/PrivacyFilterTests.swift` | 隱私過濾測試 |
| **修改** | `milery/Service/FriendService.swift` | 擴充 FriendData + 隱私方法 + 航線上傳 |
| **修改** | `milery/Views/SettingsView.swift` | 新增隱私 Toggle Section |
| **修改** | `milery/Views/DashboardView.swift` | 嵌入好友動態區塊 |
| **修改** | `milery/Views/FriendsView.swift` | 加入共同目標入口 |
| **修改** | `milery/Views/ProgressView.swift` | 加入 SharedGoal 跑道區塊 |
| **修改** | `milery/ViewModels/MileageViewModel+Sync.swift` | Widget 資料寫入 + 目標進度同步 |
| **修改** | `MileryWidget/MileryWidget.swift` | 重構 Provider + Entry + 登記尺寸 |
| **修改** | `milery.entitlements` | 新增 App Group |
| **修改** | `MileryWidgetExtension.entitlements` | 新增 App Group |

---

## 建議開發順序

```
Phase 0 (前置) → Phase 1 (隱私) → Phase 2 (儀表板動態) → Phase 3 (共同目標) → Phase 4 (Widget) → Phase 5 (地球儀) → Phase 6 (測試)
```

每個 Phase 完成後都應該能獨立 build & run，不依賴後續 Phase 的程式碼。