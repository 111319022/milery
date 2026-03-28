import Foundation
import CloudKit
import SwiftData
import UIKit

// MARK: - Codable 備份資料結構（與 SwiftData 解耦）

struct MileryBackup: Codable {
    let version: Int
    let createdAt: Date
    let deviceName: String
    let programName: String?  // v3: 所屬里程計劃名稱
    let account: AccountBackup
    let transactions: [TransactionBackup]
    let flightGoals: [FlightGoalBackup]
    let creditCards: [CreditCardRuleBackup]  // 舊版備份相容用，新版不再寫入
    let redeemedTickets: [RedeemedTicketBackup]
    let cardPreferences: [CardPreferenceBackup]?  // v2: 信用卡偏好設定
    let program: MilageProgramBackup?  // v3: 里程計劃資訊
}

struct MilageProgramBackup: Codable {
    let id: UUID
    let name: String
    let programTypeRaw: String
    let isDefault: Bool
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
    let acceleratorCategoryRaw: String?  // 舊版備份相容
    let cardSubcategoryID: String?       // 新版統一子類別
    let notes: String
    let costPerMile: Double
    let flightRoute: String?
    let conversionSource: String?
    let merchantName: String?
    let promotionName: String?
    let linkedTicketID: UUID?
    let cardBrandRaw: String?
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
        let programName: String
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
    
    func createBackup(modelContext: ModelContext, programID: UUID?, programName: String, program: MileageProgram? = nil) async throws {
        isUploading = true
        uploadProgress = "正在準備資料..."
        defer { isUploading = false; uploadProgress = "" }
        
        try await ensureiCloudAvailable()
        
        // 1. Fetch 當前計劃的 SwiftData 資料
        let allAccounts = try modelContext.fetch(FetchDescriptor<MileageAccount>())
        let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let allGoals = try modelContext.fetch(FetchDescriptor<FlightGoal>())
        let allTickets = try modelContext.fetch(FetchDescriptor<RedeemedTicket>())
        let cardPrefs = (try? modelContext.fetch(FetchDescriptor<CardPreference>())) ?? []
        
        // 篩選屬於當前計劃的資料
        let accounts = allAccounts.filter { $0.programID == programID }
        let transactions = allTransactions.filter { $0.programID == programID }
        let flightGoals = allGoals.filter { $0.programID == programID }
        let redeemedTickets = allTickets.filter { $0.programID == programID }
        
        appLog("[CloudBackup] 備份資料統計: 全部帳戶=\(allAccounts.count), 符合計劃帳戶=\(accounts.count), programID=\(programID?.uuidString ?? "nil")")
        appLog("[CloudBackup] 全部帳戶 programID 列表: \(allAccounts.map { $0.programID?.uuidString ?? "nil" })")
        
        // 若找不到符合 programID 的帳戶，嘗試自動修正（將 programID 為 nil 的帳戶綁定到當前計劃）
        var account: MileageAccount
        if let matched = accounts.sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            account = matched
        } else if let programID,
                  let orphan = allAccounts.filter({ $0.programID == nil }).sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            // 自動修正：將未綁定計劃的帳戶綁定到當前計劃
            orphan.programID = programID
            try? modelContext.save()
            account = orphan
            appLog("[CloudBackup] 自動修正: 將未綁定帳戶綁定至計劃 \(programName)")
        } else {
            // 仍然找不到，建立一個新帳戶以避免備份失敗
            let newAccount = MileageAccount()
            newAccount.programID = programID
            modelContext.insert(newAccount)
            try? modelContext.save()
            account = newAccount
            appLog("[CloudBackup] 自動建立新帳戶以完成備份")
        }
        
        // 2. 轉換為 Codable 結構
        uploadProgress = "正在序列化..."
        
        let backup = MileryBackup(
            version: 1,
            createdAt: Date(),
            deviceName: UIDevice.current.name,
            programName: programName,
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
                    acceleratorCategoryRaw: t.resolvedSubcategoryID,
                    cardSubcategoryID: t.resolvedSubcategoryID,
                    notes: t.notes,
                    costPerMile: t.costPerMile,
                    flightRoute: t.flightRoute,
                    conversionSource: t.conversionSource,
                    merchantName: t.merchantName,
                    promotionName: t.promotionName,
                    linkedTicketID: t.linkedTicketID,
                    cardBrandRaw: t.cardBrandRaw
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
            },
            program: program.map { p in
                MilageProgramBackup(
                    id: p.id,
                    name: p.name,
                    programTypeRaw: p.programTypeRaw,
                    isDefault: p.isDefault
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
        record["programName"] = programName as CKRecordValue
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
                    recordCounts: record["recordCounts"] as? String ?? "",
                    programName: record["programName"] as? String ?? "Asia Miles"
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
    
    func restoreFromBackup(recordID: CKRecord.ID, modelContext: ModelContext, programID: UUID?) async throws {
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
        
        // 3. 刪除當前計劃的本地資料（保留其他計劃的資料）
        let existingAccounts = (try? modelContext.fetch(FetchDescriptor<MileageAccount>())) ?? []
        for account in existingAccounts where account.programID == programID {
            modelContext.delete(account)
        }
        let existingTransactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in existingTransactions where tx.programID == programID {
            modelContext.delete(tx)
        }
        let existingGoals = (try? modelContext.fetch(FetchDescriptor<FlightGoal>())) ?? []
        for goal in existingGoals where goal.programID == programID {
            modelContext.delete(goal)
        }
        let existingTickets = (try? modelContext.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        for ticket in existingTickets where ticket.programID == programID {
            modelContext.delete(ticket)
        }
        // CardPreference 和 CreditCardRule 是全域共用，維持原本邏輯
        try modelContext.delete(model: CreditCardRule.self)
        try modelContext.delete(model: CardPreference.self)
        
        // 3.5 還原里程計劃名稱與類型（若備份中包含計劃資訊）
        if let programBackup = backup.program, let programID {
            let allPrograms = (try? modelContext.fetch(FetchDescriptor<MileageProgram>())) ?? []
            if let existingProgram = allPrograms.first(where: { $0.id == programID }) {
                existingProgram.name = programBackup.name
                existingProgram.programTypeRaw = programBackup.programTypeRaw
            }
        }
        
        // 4. 重建 MileageAccount（綁定當前計劃）
        let newAccount = MileageAccount(
            totalMiles: backup.account.totalMiles,
            lastActivityDate: backup.account.lastActivityDate
        )
        newAccount.programID = programID
        modelContext.insert(newAccount)
        
        // 5. 重建 Transactions
        for t in backup.transactions {
            // 優先使用新版 cardSubcategoryID，fallback 到舊版 acceleratorCategoryRaw
            let subcategoryID = t.cardSubcategoryID ?? t.acceleratorCategoryRaw
            let cardBrand: CardBrand? = t.cardBrandRaw.flatMap { CardBrand(rawValue: $0) }
            let transaction = Transaction(
                date: t.date,
                amount: t.amount,
                earnedMiles: t.earnedMiles,
                source: MileageSource(rawValue: t.sourceRaw) ?? .cardGeneral,
                subcategoryID: subcategoryID,
                cardBrand: cardBrand,
                notes: t.notes,
                flightRoute: t.flightRoute,
                conversionSource: t.conversionSource,
                merchantName: t.merchantName,
                promotionName: t.promotionName,
                linkedTicketID: t.linkedTicketID
            )
            transaction.id = t.id // 保留原始 UUID
            transaction.costPerMile = t.costPerMile
            transaction.programID = programID
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
            goal.programID = programID
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
                        tierID: p.tierRaw
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
                        tierID: c.cardTierRaw
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
            ticket.programID = programID
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
