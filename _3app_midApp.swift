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
            CreditCardRule.self,
            RedeemedTicket.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // 如果遷移失敗，先備份舊資料庫再嘗試重建
            print("無法載入資料庫: \(error)")
            
            let url = modelConfiguration.url
            let fileManager = FileManager.default
            let dbExtensions = ["", ".store-shm", ".store-wal"]
            
            // 將舊資料庫備份到 Documents/DatabaseBackup/
            let backupDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("DatabaseBackup")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let backupSubDir = backupDir.appendingPathComponent(timestamp)
            
            do {
                try fileManager.createDirectory(at: backupSubDir, withIntermediateDirectories: true)
                for ext in dbExtensions {
                    let sourceURL = ext.isEmpty ? url : url.deletingPathExtension().appendingPathExtension(String(ext.dropFirst()))
                    if fileManager.fileExists(atPath: sourceURL.path) {
                        let destURL = backupSubDir.appendingPathComponent(sourceURL.lastPathComponent)
                        try fileManager.copyItem(at: sourceURL, to: destURL)
                    }
                }
                print("資料庫已備份至: \(backupSubDir.path)")
            } catch {
                print("備份資料庫失敗: \(error)")
            }
            
            // 刪除舊資料庫
            for ext in dbExtensions {
                let fileURL = ext.isEmpty ? url : url.deletingPathExtension().appendingPathExtension(String(ext.dropFirst()))
                try? fileManager.removeItem(at: fileURL)
            }
            
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
