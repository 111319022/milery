import Foundation
import CloudKit
import SwiftData
import UIKit

// MARK: - Codable 備份資料結構（與 SwiftData 解耦）

struct MileryBackup: Codable {
    let version: Int
    let createdAt: Date
    let deviceName: String
    let account: AccountBackup
    let transactions: [TransactionBackup]
    let flightGoals: [FlightGoalBackup]
    let creditCards: [CreditCardRuleBackup]  // 舊版備份相容用，新版不再寫入
    let redeemedTickets: [RedeemedTicketBackup]
    let cardPreferences: [CardPreferenceBackup]?  // v2: 信用卡偏好設定
}

struct CardPreferenceBackup: Codable {
    let cardBrandRaw: String
    let isActive: Bool
    let tierRaw: String
}

struct AccountBackup: Codable {
    let totalMiles: Int
    let lastActivityDate: Date
}

struct TransactionBackup: Codable {
    let id: UUID
    let date: Date
    let amount: Decimal
    let earnedMiles: Int
    let sourceRaw: String
    let acceleratorCategoryRaw: String?
    let notes: String
    let costPerMile: Double
    let flightRoute: String?
    let conversionSource: String?
    let merchantName: String?
    let promotionName: String?
    let linkedTicketID: UUID?
}

struct FlightGoalBackup: Codable {
    let id: UUID
    let origin: String
    let destination: String
    let originName: String
    let destinationName: String
    let cabinClassRaw: String
    let requiredMiles: Int
    let isOneworld: Bool
    let isPriority: Bool
    let isRoundTrip: Bool
    let createdDate: Date
    let sortOrder: Int
}

struct CreditCardRuleBackup: Codable {
    let id: UUID
    let cardName: String
    let bankName: String
    let isActive: Bool
    let cardBrandRaw: String
    let cardTierRaw: String
    let baseRate: Decimal
    let acceleratorRate: Decimal
    let specialMerchantRate: Decimal
    let birthdayMultiplier: Decimal
    let roundingModeRaw: String
    let billingDay: Int
    let annualFee: Int
}

struct RedeemedTicketBackup: Codable {
    let id: UUID
    let originIATA: String
    let destinationIATA: String
    let originName: String
    let destinationName: String
    let isRoundTrip: Bool
    let cabinClassRaw: String
    let spentMiles: Int
    let taxPaid: Decimal
    let flightDate: Date
    let pnr: String
    let airline: String
    let flightNumber: String
    let redeemedDate: Date
    let linkedTransactionID: UUID?
}

// MARK: - 錯誤定義

enum BackupError: LocalizedError {
    case noAccountData
    case missingAsset
    case iCloudUnavailable
    case decodingFailed(Error)
    case encodingFailed(Error)
    case cloudKitError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAccountData: return "找不到哩程帳戶資料"
        case .missingAsset: return "備份檔案遺失"
        case .iCloudUnavailable: return "iCloud 不可用，請確認已登入 iCloud 帳號"
        case .decodingFailed(let e): return "備份資料解碼失敗：\(e.localizedDescription)"
        case .encodingFailed(let e): return "資料編碼失敗：\(e.localizedDescription)"
        case .cloudKitError(let e): return "iCloud 同步錯誤：\(e.localizedDescription)"
        }
    }
}

// MARK: - CloudKit 備份服務

@Observable
class CloudBackupService {
    
    // MARK: - 狀態（供 View 觀察）
    var isUploading = false
    var isDownloading = false
    var isLoadingList = false
    var backupRecords: [BackupRecord] = []
    var errorMessage: String?
    var showError = false
    var uploadProgress: String = ""
    var iCloudAvailable: Bool?
    
    // MARK: - 常數
    private let recordType = "MileryBackup"
    private let container = CKContainer(identifier: "iCloud.com.73app.milery")
    private var database: CKDatabase { container.privateCloudDatabase }
    private let customZone = CKRecordZone(zoneName: "MileryBackupZone")
    
    // 備份列表用的輕量結構
    struct BackupRecord: Identifiable {
        let id: CKRecord.ID
        let backupDate: Date
        let deviceName: String
        let schemaVersion: Int
        let recordCounts: String
    }
    
    // MARK: - iCloud 狀態檢查
    
    func checkiCloudStatus() async {
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)
        } catch {
            iCloudAvailable = false
        }
    }
    
    private func ensureiCloudAvailable() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw BackupError.iCloudUnavailable
        }
    }
    
    // MARK: - 確保自訂 Zone 存在
    
    private func ensureCustomZoneExists() async throws {
        do {
            _ = try await database.modifyRecordZones(saving: [customZone], deleting: [])
            appLog("[CloudBackup] 自訂 Zone '\(customZone.zoneID.zoneName)' 已建立或已存在")
        } catch let error as CKError where error.code == .serverRejectedRequest || error.code == .zoneNotFound {
            // 真正的伺服器錯誤，不應忽略
            appLog("[CloudBackup] Zone 建立失敗（伺服器拒絕）：\(error.localizedDescription)")
            throw BackupError.cloudKitError(error)
        } catch let error as CKError where error.code == .partialFailure {
            // Zone 已存在會回傳 partialFailure，屬於正常情況
            appLog("[CloudBackup] Zone 已存在，繼續操作")
        } catch {
            // 其他未預期錯誤（網路問題等），記錄但不阻斷流程
            appLog("[CloudBackup] Zone 建立遇到非預期錯誤：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 建立備份
    
    func createBackup(modelContext: ModelContext) async throws {
        isUploading = true
        uploadProgress = "正在準備資料..."
        defer { isUploading = false; uploadProgress = "" }
        
        try await ensureiCloudAvailable()
        
        // 1. Fetch 所有 SwiftData 資料
        let accounts = try modelContext.fetch(FetchDescriptor<MileageAccount>())
        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let flightGoals = try modelContext.fetch(FetchDescriptor<FlightGoal>())
        let redeemedTickets = try modelContext.fetch(FetchDescriptor<RedeemedTicket>())
        let cardPrefs = (try? modelContext.fetch(FetchDescriptor<CardPreference>())) ?? []
        
        guard let account = accounts.first else {
            throw BackupError.noAccountData
        }
        
        // 2. 轉換為 Codable 結構
        uploadProgress = "正在序列化..."
        
        let backup = MileryBackup(
            version: 1,
            createdAt: Date(),
            deviceName: UIDevice.current.name,
            account: AccountBackup(
                totalMiles: account.totalMiles,
                lastActivityDate: account.lastActivityDate
            ),
            transactions: transactions.map { t in
                TransactionBackup(
                    id: t.id,
                    date: t.date,
                    amount: t.amount,
                    earnedMiles: t.earnedMiles,
                    sourceRaw: t.source.rawValue,
                    acceleratorCategoryRaw: t.acceleratorCategory?.rawValue,
                    notes: t.notes,
                    costPerMile: t.costPerMile,
                    flightRoute: t.flightRoute,
                    conversionSource: t.conversionSource,
                    merchantName: t.merchantName,
                    promotionName: t.promotionName,
                    linkedTicketID: t.linkedTicketID
                )
            },
            flightGoals: flightGoals.map { g in
                FlightGoalBackup(
                    id: g.id,
                    origin: g.origin,
                    destination: g.destination,
                    originName: g.originName,
                    destinationName: g.destinationName,
                    cabinClassRaw: g.cabinClass.rawValue,
                    requiredMiles: g.requiredMiles,
                    isOneworld: g.isOneworld,
                    isPriority: g.isPriority,
                    isRoundTrip: g.isRoundTrip,
                    createdDate: g.createdDate,
                    sortOrder: g.sortOrder
                )
            },
            creditCards: [],  // 不再備份完整信用卡規則，改用 cardPreferences
            redeemedTickets: redeemedTickets.map { r in
                RedeemedTicketBackup(
                    id: r.id,
                    originIATA: r.originIATA,
                    destinationIATA: r.destinationIATA,
                    originName: r.originName,
                    destinationName: r.destinationName,
                    isRoundTrip: r.isRoundTrip,
                    cabinClassRaw: r.cabinClass.rawValue,
                    spentMiles: r.spentMiles,
                    taxPaid: r.taxPaid,
                    flightDate: r.flightDate,
                    pnr: r.pnr,
                    airline: r.airline,
                    flightNumber: r.flightNumber,
                    redeemedDate: r.redeemedDate,
                    linkedTransactionID: r.linkedTransactionID
                )
            },
            cardPreferences: cardPrefs.map { p in
                CardPreferenceBackup(
                    cardBrandRaw: p.cardBrandRaw,
                    isActive: p.isActive,
                    tierRaw: p.tierRaw
                )
            }
        )
        
        // 3. JSON 編碼
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData: Data
        do {
            jsonData = try encoder.encode(backup)
        } catch {
            throw BackupError.encodingFailed(error)
        }
        
        // 4. 寫入暫存檔供 CKAsset 使用
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("milery_backup_\(UUID().uuidString).json")
        try jsonData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // 5. 建立 CKRecord 並上傳（使用自訂 Zone 以支援 change token fetch）
        uploadProgress = "正在上傳至 iCloud..."
        try await ensureCustomZoneExists()
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: customZone.zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["backupDate"] = Date() as CKRecordValue
        record["deviceName"] = UIDevice.current.name as CKRecordValue
        record["schemaVersion"] = 1 as CKRecordValue
        record["recordCounts"] = "\(transactions.count) 筆交易、\(flightGoals.count) 個目標、\(redeemedTickets.count) 張機票" as CKRecordValue
        record["backupData"] = CKAsset(fileURL: tempURL)
        
        do {
            let savedRecord = try await database.save(record)
            appLog("[CloudBackup] 備份上傳成功！RecordID: \(savedRecord.recordID.recordName), Zone: \(savedRecord.recordID.zoneID.zoneName)")
        } catch {
            appLog("[CloudBackup] 備份上傳失敗：\(error.localizedDescription)")
            throw BackupError.cloudKitError(error)
        }
        
        // 6. 儲存最後備份時間
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackupDate")
    }
    
    // MARK: - 取得備份列表
    
    func fetchBackupList() async {
        isLoadingList = true
        defer { isLoadingList = false }
        
        appLog("[CloudBackup] 開始取得備份列表...")
        
        do {
            try await ensureiCloudAvailable()
        } catch {
            appLog("[CloudBackup] iCloud 不可用")
            return
        }
        
        // 使用 recordZoneChanges + 自訂 Zone 取代 CKQuery
        let zoneID = customZone.zoneID
        var allRecords: [CKRecord] = []
        var changeToken: CKServerChangeToken? = nil
        var moreComing = true
        
        appLog("[CloudBackup] 查詢 Zone: \(zoneID.zoneName)")
        
        do {
            while moreComing {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken
                )
                
                appLog("[CloudBackup] 收到 modifications: \(changes.modificationResultsByID.count), deletions: \(changes.deletions.count), moreComing: \(changes.moreComing)")
                
                for (recordID, result) in changes.modificationResultsByID {
                    switch result {
                    case .success(let modification):
                        let record = modification.record
                        appLog("[CloudBackup] Record: \(recordID.recordName), type: \(record.recordType)")
                        if record.recordType == recordType {
                            allRecords.append(record)
                        }
                    case .failure(let error):
                        appLog("[CloudBackup] Record \(recordID.recordName) error: \(error.localizedDescription)")
                    }
                }
                
                // 移除已刪除的記錄
                let deletedIDs = Set(changes.deletions.map { $0.recordID })
                if !deletedIDs.isEmpty {
                    appLog("[CloudBackup] 刪除 \(deletedIDs.count) 筆記錄")
                }
                allRecords.removeAll { deletedIDs.contains($0.recordID) }
                
                changeToken = changes.changeToken
                moreComing = changes.moreComing
            }
            
            appLog("[CloudBackup] 共找到 \(allRecords.count) 筆備份記錄")
            
            backupRecords = allRecords.compactMap { record in
                BackupRecord(
                    id: record.recordID,
                    backupDate: record["backupDate"] as? Date ?? record.creationDate ?? Date(),
                    deviceName: record["deviceName"] as? String ?? "未知裝置",
                    schemaVersion: record["schemaVersion"] as? Int ?? 1,
                    recordCounts: record["recordCounts"] as? String ?? ""
                )
            }
            .sorted { $0.backupDate > $1.backupDate }
            
            appLog("[CloudBackup] 備份列表更新完成，共 \(backupRecords.count) 筆")
        } catch {
            appLog("[CloudBackup] 取得備份列表失敗：\(error.localizedDescription)")
            backupRecords = []
        }
    }
    
    // MARK: - 還原備份
    
    func restoreFromBackup(recordID: CKRecord.ID, modelContext: ModelContext) async throws {
        isDownloading = true
        defer { isDownloading = false }
        
        try await ensureiCloudAvailable()
        
        // 1. 下載完整 CKRecord（含 CKAsset）
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            throw BackupError.cloudKitError(error)
        }
        
        guard let asset = record["backupData"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw BackupError.missingAsset
        }
        
        // 2. 讀取並解碼 JSON（在刪除本地資料之前完成，確保安全）
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup: MileryBackup
        do {
            backup = try decoder.decode(MileryBackup.self, from: jsonData)
        } catch {
            throw BackupError.decodingFailed(error)
        }
        
        // 3. 刪除所有本地資料
        try modelContext.delete(model: Transaction.self)
        try modelContext.delete(model: FlightGoal.self)
        try modelContext.delete(model: CreditCardRule.self)
        try modelContext.delete(model: CardPreference.self)
        try modelContext.delete(model: RedeemedTicket.self)
        try modelContext.delete(model: MileageAccount.self)
        
        // 4. 重建 MileageAccount
        let newAccount = MileageAccount(
            totalMiles: backup.account.totalMiles,
            lastActivityDate: backup.account.lastActivityDate
        )
        modelContext.insert(newAccount)
        
        // 5. 重建 Transactions
        for t in backup.transactions {
            let transaction = Transaction(
                date: t.date,
                amount: t.amount,
                earnedMiles: t.earnedMiles,
                source: MileageSource(rawValue: t.sourceRaw) ?? .cardGeneral,
                acceleratorCategory: t.acceleratorCategoryRaw.flatMap { AcceleratorCategory(rawValue: $0) },
                notes: t.notes,
                flightRoute: t.flightRoute,
                conversionSource: t.conversionSource,
                merchantName: t.merchantName,
                promotionName: t.promotionName,
                linkedTicketID: t.linkedTicketID
            )
            transaction.id = t.id // 保留原始 UUID
            transaction.costPerMile = t.costPerMile
            modelContext.insert(transaction)
            if newAccount.transactions == nil { newAccount.transactions = [] }
            newAccount.transactions?.append(transaction)
        }
        
        // 6. 重建 FlightGoals
        for g in backup.flightGoals {
            let goal = FlightGoal(
                origin: g.origin,
                destination: g.destination,
                originName: g.originName,
                destinationName: g.destinationName,
                cabinClass: CabinClass(rawValue: g.cabinClassRaw) ?? .economy,
                requiredMiles: g.requiredMiles,
                isOneworld: g.isOneworld,
                isPriority: g.isPriority,
                isRoundTrip: g.isRoundTrip
            )
            goal.id = g.id
            goal.createdDate = g.createdDate
            goal.sortOrder = g.sortOrder
            modelContext.insert(goal)
            if newAccount.flightGoals == nil { newAccount.flightGoals = [] }
            newAccount.flightGoals?.append(goal)
        }
        
        // 7. 重建 CardPreference（信用卡偏好）
        if let cardPrefBackups = backup.cardPreferences, !cardPrefBackups.isEmpty {
            // 新版備份：直接還原 CardPreference
            for p in cardPrefBackups {
                if let brand = CardBrand(rawValue: p.cardBrandRaw) {
                    let pref = CardPreference(
                        cardBrand: brand,
                        isActive: p.isActive,
                        tier: CathayCardTier(rawValue: p.tierRaw)
                    )
                    modelContext.insert(pref)
                }
            }
        } else if !backup.creditCards.isEmpty {
            // 舊版備份相容：從 CreditCardRuleBackup 提取偏好
            for c in backup.creditCards {
                if let brand = CardBrand(rawValue: c.cardBrandRaw) {
                    let pref = CardPreference(
                        cardBrand: brand,
                        isActive: c.isActive,
                        tier: CathayCardTier(rawValue: c.cardTierRaw)
                    )
                    modelContext.insert(pref)
                }
            }
        }
        
        // 8. 重建 RedeemedTickets
        for r in backup.redeemedTickets {
            let ticket = RedeemedTicket(
                id: r.id,
                originIATA: r.originIATA,
                destinationIATA: r.destinationIATA,
                originName: r.originName,
                destinationName: r.destinationName,
                isRoundTrip: r.isRoundTrip,
                cabinClass: CabinClass(rawValue: r.cabinClassRaw) ?? .economy,
                spentMiles: r.spentMiles,
                taxPaid: r.taxPaid,
                flightDate: r.flightDate,
                pnr: r.pnr,
                airline: r.airline,
                flightNumber: r.flightNumber,
                redeemedDate: r.redeemedDate,
                linkedTransactionID: r.linkedTransactionID
            )
            modelContext.insert(ticket)
        }
        
        // 9. 儲存
        try modelContext.save()
    }
    
    // MARK: - 刪除備份
    
    func deleteBackup(recordID: CKRecord.ID) async throws {
        try await ensureiCloudAvailable()
        
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch {
            throw BackupError.cloudKitError(error)
        }
        
        backupRecords.removeAll { $0.id == recordID }
    }
}
