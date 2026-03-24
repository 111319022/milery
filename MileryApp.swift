import SwiftUI
import SwiftData
import CloudKit

@main
struct MileryApp: App {
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([
            MileageAccount.self,
            Transaction.self,
            FlightGoal.self,
            CreditCardRule.self,
            RedeemedTicket.self
        ])
        
        let syncEnabled = UserDefaults.standard.object(forKey: "cloudKitSyncEnabled") as? Bool ?? true
        
        if syncEnabled {
            if let container = Self.makeCloudKitContainer(schema: schema) {
                sharedModelContainer = container
                print("[Milery] CloudKit 同步已啟用 (container: iCloud.com.73app.milery)")
            } else if let container = Self.makeLocalContainer(schema: schema) {
                sharedModelContainer = container
                print("[Milery] CloudKit 建立失敗，退回本地模式")
            } else {
                fatalError("[Milery] 無法建立任何資料庫")
            }
            
            Task {
                await Self.checkiCloudAccountStatus()
            }
        } else if let container = Self.makeLocalContainer(schema: schema) {
            sharedModelContainer = container
            print("[Milery] 本地模式（CloudKit 同步已關閉）")
        } else {
            fatalError("[Milery] 無法建立任何資料庫")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - CloudKit 同步容器
    
    private static func makeCloudKitContainer(schema: Schema) -> ModelContainer? {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.73app.milery")
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("[Milery] ModelContainer 建立成功，store URL: \(config.url)")
            return container
        } catch {
            print("[Milery] CloudKit ModelContainer 建立失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - 純本地容器（fallback）
    
    private static func makeLocalContainer(schema: Schema) -> ModelContainer? {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("[Milery] Local ModelContainer 建立失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - iCloud 帳號狀態檢查
    
    private static func checkiCloudAccountStatus() async {
        do {
            let container = CKContainer(identifier: "iCloud.com.73app.milery")
            let status = try await container.accountStatus()
            switch status {
            case .available:
                print("[Milery] iCloud 帳號狀態: 可用")
            case .noAccount:
                print("[Milery] iCloud 帳號狀態: 未登入 — 同步不會運作")
            case .restricted:
                print("[Milery] iCloud 帳號狀態: 受限 — 同步不會運作")
            case .couldNotDetermine:
                print("[Milery] iCloud 帳號狀態: 無法判斷")
            case .temporarilyUnavailable:
                print("[Milery] iCloud 帳號狀態: 暫時不可用")
            @unknown default:
                print("[Milery] iCloud 帳號狀態: 未知(\(status.rawValue))")
            }
        } catch {
            print("[Milery] iCloud 帳號檢查失敗: \(error)")
        }
    }
}
