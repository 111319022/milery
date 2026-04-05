import Foundation
import SwiftData
import CoreData

// MARK: - CloudKit 遠端同步（初始化、變更偵測、指紋比對）

extension MileageViewModel {
    
    func initialize(context: ModelContext) {
        self.modelContext = context
        isInitialLoad = true
        loadPrograms()
        loadData()
        isInitialLoad = false
        knownDataFingerprint = fetchDataFingerprint()
        
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }
    
    func handleRemoteChange() {
        remoteChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let context = self.modelContext else { return }
            context.rollback()
            
            self.loadPrograms()
            self.migrateOrphanedDataToActiveProgram()
            
            let newFingerprint = self.fetchDataFingerprint()
            guard newFingerprint != self.knownDataFingerprint else { return }
            appLog("[Sync] 偵測到實際資料變更，刷新 UI")
            self.loadData()
            self.knownDataFingerprint = self.fetchDataFingerprint()
        }
        remoteChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    func acknowledgeRemoteChanges() {
        manualSyncNow()
    }

    func manualSyncNow() {
        modelContext?.rollback()
        loadPrograms()
        migrateOrphanedDataToActiveProgram()
        loadData()
        knownDataFingerprint = fetchDataFingerprint()
        hasRemoteChanges = false
    }
    
    func checkForRemoteChanges() {
        modelContext?.rollback()
        loadPrograms()
        migrateOrphanedDataToActiveProgram()
        let latestFingerprint = fetchDataFingerprint()
        if latestFingerprint != knownDataFingerprint {
            appLog("[Sync] 偵測到資料指紋變更，自動刷新")
            loadData()
            knownDataFingerprint = fetchDataFingerprint()
        }
    }

    func fetchDataFingerprint() -> String {
        guard let context = modelContext else { return "" }

        let accounts: [MileageAccount]
        let txs: [Transaction]
        let goals: [FlightGoal]
        let tickets: [RedeemedTicket]
        let cardPrefs: [CardPreference]
        do {
            accounts = try context.fetch(FetchDescriptor<MileageAccount>())
            txs = try context.fetch(FetchDescriptor<Transaction>())
            goals = try context.fetch(FetchDescriptor<FlightGoal>())
            tickets = try context.fetch(FetchDescriptor<RedeemedTicket>())
            cardPrefs = try context.fetch(FetchDescriptor<CardPreference>())
        } catch {
            appLog("[Sync] 資料指紋計算失敗: \(error.localizedDescription)")
            return ""
        }

        let accountPart = accounts
            .sorted { $0.lastActivityDate < $1.lastActivityDate }
            .map { "\($0.totalMiles)|\($0.lastActivityDate.timeIntervalSince1970)" }
            .joined(separator: ";")

        let txPart = txs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.date.timeIntervalSince1970)|\($0.amountValue)|\($0.earnedMiles)|\($0.sourceRaw)"
            }
            .joined(separator: ";")

        let goalPart = goals
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.origin)|\($0.destination)|\($0.cabinClassRaw)|\($0.requiredMiles)"
            }
            .joined(separator: ";")

        let ticketPart = tickets
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.spentMiles)|\($0.flightDate.timeIntervalSince1970)"
            }
            .joined(separator: ";")

        let cardPrefPart = cardPrefs
            .sorted { $0.cardBrandRaw < $1.cardBrandRaw }
            .map { "\($0.cardBrandRaw)|\($0.isActive)|\($0.tierRaw)" }
            .joined(separator: ";")

        let programPart = ActiveProgramManager.activeProgramID?.uuidString ?? "none"
        return [programPart, accountPart, txPart, goalPart, ticketPart, cardPrefPart].joined(separator: "||")
    }
}
