import Foundation
import SwiftData
import SwiftUI
import CoreData

@Observable
class MileageViewModel {
    var modelContext: ModelContext?
    var mileageAccount: MileageAccount?
    var creditCards: [CreditCardRule] = []
    var transactions: [Transaction] = []
    var flightGoals: [FlightGoal] = []
    var redeemedTickets: [RedeemedTicket] = []
    
    // MARK: - 里程計劃
    var programs: [MileageProgram] = []
    var activeProgram: MileageProgram?
    
    /// 當前計劃是否支援國泰兌換表自動計算
    var supportsCathayAwardChart: Bool {
        activeProgram?.programType.supportsCathayAwardChart ?? true
    }
    
    // 使用者生日月份（1~12，0 表示未設定；透過 UserDefaults 持久化）
    var userBirthdayMonth: Int = UserDefaults.standard.integer(forKey: "userBirthdayMonth") {
        didSet { UserDefaults.standard.set(userBirthdayMonth, forKey: "userBirthdayMonth") }
    }
    
    /// 判斷指定日期是否為用戶生日當月
    func isBirthdayMonth(for date: Date) -> Bool {
        let month = userBirthdayMonth
        guard month >= 1, month <= 12 else { return false }
        return Calendar.current.component(.month, from: date) == month
    }
    
    // 儲存錯誤訊息，供 UI 顯示 Alert
    var saveError: String?
    var showSaveError: Bool = false
    
    // MARK: - CloudKit 遠端同步狀態
    var hasRemoteChanges: Bool = false
    var knownDataFingerprint: String = ""
    var isInitialLoad: Bool = true
    var remoteChangeWorkItem: DispatchWorkItem?
    var remoteChangeObserver: NSObjectProtocol?
    
    init() {}
    
    deinit {
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        remoteChangeWorkItem?.cancel()
    }
    
    // MARK: - 核心方法
    
    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            appLog("[Data] 資料儲存失敗: \(error.localizedDescription)")
            saveError = "資料儲存失敗，請稍後再試。\n(\(error.localizedDescription))"
            showSaveError = true
        }
    }
    
    // 載入資料（依當前啟用的里程計劃篩選）
    func loadData() {
        guard let context = modelContext else { return }
        
        let activePID = activeProgram?.id
        
        let accountDescriptor = FetchDescriptor<MileageAccount>()
        let allAccounts: [MileageAccount]
        do {
            allAccounts = try context.fetch(accountDescriptor)
        } catch {
            appLog("[Sync] 載入帳戶資料失敗: \(error.localizedDescription)")
            return
        }
        let programAccounts = allAccounts.filter { $0.programID == activePID }
        
        if !programAccounts.isEmpty,
           let account = programAccounts.sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            self.mileageAccount = account
            self.transactions = (account.transactions ?? []).sorted { $0.date > $1.date }
            self.flightGoals = account.flightGoals ?? []
        } else if isInitialLoad {
            let newAccount = MileageAccount()
            newAccount.programID = activePID
            context.insert(newAccount)
            self.mileageAccount = newAccount
            saveContext()
        }
        
        // 載入信用卡：從 store 讀取用戶偏好後，以程式碼定義重建標準卡片
        rebuildCreditCards()

        let redeemedDescriptor = FetchDescriptor<RedeemedTicket>(
            sortBy: [SortDescriptor(\RedeemedTicket.redeemedDate, order: .reverse)]
        )
        do {
            let allTickets = try context.fetch(redeemedDescriptor)
            self.redeemedTickets = allTickets.filter { $0.programID == activePID }
        } catch {
            appLog("[Sync] 載入兌換紀錄失敗: \(error.localizedDescription)")
            self.redeemedTickets = []
        }
        
        let programName = activeProgram?.name ?? "未知"
        let activeCardNames = creditCards.filter { $0.isActive }.map { $0.cardName }.joined(separator: ", ")
        appLog("[Sync] loadData 完成 [\(programName)]: 哩程=\(mileageAccount?.totalMiles ?? -1), 交易=\(transactions.count)筆, 目標=\(flightGoals.count)個, 機票=\(redeemedTickets.count)張, 已啟用卡片: [\(activeCardNames.isEmpty ? "無" : activeCardNames)]")
    }
}
