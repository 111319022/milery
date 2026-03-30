import SwiftUI
import SwiftData
import CloudKit
import CoreData
import UIKit

@MainActor
@Observable
final class AppConsoleStore {
    static let shared = AppConsoleStore()

    private(set) var entries: [String] = []
    private let maxEntries = 800
    private let retentionDays = 7
    private let formatter: DateFormatter
    private let fileURL: URL

    private init() {
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = appSupport.appendingPathComponent("MileryLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("app-console.log")

        if let data = try? Data(contentsOf: fileURL),
           let text = String(data: data, encoding: .utf8) {
            entries = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        }

        pruneExpiredEntries()
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persistToFile()
    }

    func log(_ message: String) {
        pruneExpiredEntries()
        let line = "[\(formatter.string(from: Date()))] \(message)"
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persistToFile()
        print(message)
    }

    func clear() {
        entries.removeAll()
        try? Data().write(to: fileURL)
    }

    private func persistToFile() {
        let content = entries.joined(separator: "\n")
        try? content.data(using: .utf8)?.write(to: fileURL)
    }

    private func pruneExpiredEntries() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        entries = entries.filter { entry in
            guard let timestamp = extractTimestamp(from: entry) else {
                return true
            }
            return timestamp >= cutoff
        }
    }

    private func extractTimestamp(from line: String) -> Date? {
        guard let start = line.firstIndex(of: "["),
              let end = line.firstIndex(of: "]"),
              start < end else {
            return nil
        }

        let value = String(line[line.index(after: start)..<end])
        return formatter.date(from: value)
    }
}

func appLog(_ message: String) {
    Task { @MainActor in
        AppConsoleStore.shared.log(message)
    }
}

@MainActor
final class SyncDiagnosticsObserver {
    static let shared = SyncDiagnosticsObserver()

    private var isStarted = false
    private var tokens: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let center = NotificationCenter.default

        tokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            appLog("[SyncDiag] App 進入背景")
        })

        tokens.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            appLog("[SyncDiag] App 即將回到前景")
        })

        tokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            appLog("[SyncDiag] App 進入 active")
        })

        tokens.append(center.addObserver(forName: NSNotification.Name.NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            appLog("[SyncDiag] 收到 NSPersistentStoreRemoteChange（本地 store 有遠端匯入/更新）")
        })

        tokens.append(center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                appLog("[SyncDiag] 收到 CloudKit 事件通知，但無法解析 event")
                return
            }

            let typeText: String
            switch event.type {
            case .setup:
                typeText = "setup"
            case .import:
                typeText = "import"
            case .export:
                typeText = "export"
            @unknown default:
                typeText = "unknown"
            }

            if let error = event.error {
                appLog("[SyncDiag] CloudKit event=\(typeText) 失敗: \(error.localizedDescription)")
                // 印出完整錯誤以供排查
                appLog("[SyncDiag] 完整錯誤: \(error)")
            } else if event.endDate != nil {
                appLog("[SyncDiag] CloudKit event=\(typeText) 完成 ✓")
            } else {
                appLog("[SyncDiag] CloudKit event=\(typeText) 開始...")
            }
        })

        tokens.append(center.addObserver(forName: Notification.Name.CKAccountChanged, object: nil, queue: .main) { _ in
            appLog("[SyncDiag] 偵測到 CKAccountChanged")
        })

        appLog("[SyncDiag] 已啟用同步診斷監聽")
    }
}

@main
struct MileryApp: App {
    let sharedModelContainer: ModelContainer
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    init() {
        SyncDiagnosticsObserver.shared.start()

        let schema = Schema([
            MileageAccount.self,
            Transaction.self,
            FlightGoal.self,
            CreditCardRule.self,
            RedeemedTicket.self,
            CardPreference.self,
            MileageProgram.self
        ])
        
        let syncEnabled = UserDefaults.standard.object(forKey: "cloudKitSyncEnabled") as? Bool ?? true
        
        if syncEnabled {
            if let container = Self.makeCloudKitContainer(schema: schema) {
                sharedModelContainer = container
                appLog("[Milery] CloudKit 同步已啟用 (container: iCloud.com.73app.milery)")
            } else if let container = Self.makeLocalContainer(schema: schema) {
                sharedModelContainer = container
                appLog("[Milery] CloudKit 建立失敗，退回本地模式")
            } else {
                fatalError("[Milery] 無法建立任何資料庫")
            }
            
            Task {
                await Self.checkiCloudAccountStatus()
            }
        } else if let container = Self.makeLocalContainer(schema: schema) {
            sharedModelContainer = container
            appLog("[Milery] 本地模式（CloudKit 同步已關閉）")
        } else {
            fatalError("[Milery] 無法建立任何資料庫")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                NavigationStack {
                    OnboardingView(viewModel: MileageViewModel())
                }
            }
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
            appLog("[Milery] ModelContainer 建立成功，store URL: \(config.url)")
            return container
        } catch {
            appLog("[Milery] CloudKit ModelContainer 建立失敗: \(error)")
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
            appLog("[Milery] Local ModelContainer 建立失敗: \(error)")
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
                appLog("[Milery] iCloud 帳號狀態: 可用")
            case .noAccount:
                appLog("[Milery] iCloud 帳號狀態: 未登入 — 同步不會運作")
            case .restricted:
                appLog("[Milery] iCloud 帳號狀態: 受限 — 同步不會運作")
            case .couldNotDetermine:
                appLog("[Milery] iCloud 帳號狀態: 無法判斷")
            case .temporarilyUnavailable:
                appLog("[Milery] iCloud 帳號狀態: 暫時不可用")
            @unknown default:
                appLog("[Milery] iCloud 帳號狀態: 未知(\(status.rawValue))")
            }
        } catch {
            appLog("[Milery] iCloud 帳號檢查失敗: \(error)")
        }
    }
}
