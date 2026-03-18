//
//  _3app_midApp.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

@main
struct _3app_midApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MileageAccount.self,
            Transaction.self,
            FlightGoal.self,
            CreditCardRule.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // 如果遷移失敗,嘗試刪除舊資料庫並重新建立
            print("無法載入資料庫: \(error)")
            
            // 取得資料庫 URL
            let url = modelConfiguration.url
            print("嘗試刪除資料庫: \(url)")
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            
            // 重新建立容器
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("無法建立資料庫: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
