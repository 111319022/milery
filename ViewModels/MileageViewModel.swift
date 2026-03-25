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
    
    // 使用者生日（用於計算生日當月加碼）
    var userBirthday: Date = Calendar.current.date(from: DateComponents(month: 1, day: 1)) ?? Date()
    
    // 儲存錯誤訊息，供 UI 顯示 Alert
    var saveError: String?
    var showSaveError: Bool = false
    
    // MARK: - CloudKit 遠端同步狀態
    var hasRemoteChanges: Bool = false
    private var knownDataFingerprint: String = ""
    private var isInitialLoad: Bool = true  // 只有首次載入時才建立預設資料
    private var remoteChangeWorkItem: DispatchWorkItem?  // 防抖用
    private var remoteChangeObserver: NSObjectProtocol?  // 儲存 observer 以便清理
    
    init() {}
    
    deinit {
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        remoteChangeWorkItem?.cancel()
    }
    
    /// 集中式儲存方法，取代所有 try? context.save()
    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            print("資料儲存失敗: \(error)")
            saveError = "資料儲存失敗，請稍後再試。\n(\(error.localizedDescription))"
            showSaveError = true
        }
    }
    
    func initialize(context: ModelContext) {
        self.modelContext = context
        isInitialLoad = true
        loadData()
        isInitialLoad = false
        knownDataFingerprint = fetchDataFingerprint()
        
        // 監聯 CloudKit 遠端變更通知（儲存 token 以便 deinit 清理）
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }
    
    /// 收到遠端變更通知時，防抖後檢查是否有實際資料變更再刷新
    private func handleRemoteChange() {
        // 防抖：連續收到多個通知時，只處理最後一次（1 秒內合併）
        remoteChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let context = self.modelContext else { return }
            context.rollback()
            let newFingerprint = self.fetchDataFingerprint()
            guard newFingerprint != self.knownDataFingerprint else { return }
            appLog("[Sync] 偵測到實際資料變更，刷新 UI")
            self.loadData()
            self.knownDataFingerprint = self.fetchDataFingerprint()
        }
        remoteChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// 用戶確認同步後，刷新 UI
    func acknowledgeRemoteChanges() {
        manualSyncNow()
    }

    /// 手動同步：重置快取並重新讀取本地 store（含已匯入的 CloudKit 變更）
    func manualSyncNow() {
        modelContext?.rollback()
        loadData()
        knownDataFingerprint = fetchDataFingerprint()
        hasRemoteChanges = false
    }
    
    /// App 回到前台時呼叫，重置快取後檢查是否有新資料
    func checkForRemoteChanges() {
        modelContext?.rollback()
        let latestFingerprint = fetchDataFingerprint()
        if latestFingerprint != knownDataFingerprint {
            appLog("[Sync] 偵測到資料指紋變更，自動刷新")
            loadData()
            knownDataFingerprint = fetchDataFingerprint()
        }
    }

    private func fetchDataFingerprint() -> String {
        guard let context = modelContext else { return "" }

        let accounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        let tickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        let cardPrefs = (try? context.fetch(FetchDescriptor<CardPreference>())) ?? []

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

        return [accountPart, txPart, goalPart, ticketPart, cardPrefPart].joined(separator: "||")
    }
    
    // 載入資料
    func loadData() {
        guard let context = modelContext else { return }
        
        // 載入哩程帳戶（選擇哩程最高的帳戶，避免選到 CloudKit 同步造成的空帳戶）
        let accountDescriptor = FetchDescriptor<MileageAccount>()
        if let accounts = try? context.fetch(accountDescriptor), !accounts.isEmpty,
           let account = accounts.sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            self.mileageAccount = account
            self.transactions = (account.transactions ?? []).sorted { $0.date > $1.date }
            self.flightGoals = account.flightGoals ?? []
        } else if isInitialLoad {
            // 只有首次載入且確定無帳戶時才建立新帳戶
            let newAccount = MileageAccount()
            context.insert(newAccount)
            self.mileageAccount = newAccount
            saveContext()
        }
        
        // 載入信用卡：從 store 讀取用戶偏好後，以程式碼定義重建標準卡片
        rebuildCreditCards()

        // 載入兌換成功紀錄（最新在前）
        let redeemedDescriptor = FetchDescriptor<RedeemedTicket>(
            sortBy: [SortDescriptor(\RedeemedTicket.redeemedDate, order: .reverse)]
        )
        self.redeemedTickets = (try? context.fetch(redeemedDescriptor)) ?? []
        
        let activeCards = creditCards.filter { $0.isActive }.map { $0.cardName }.joined(separator: ", ")
        appLog("[Sync] loadData 完成: 哩程=\(mileageAccount?.totalMiles ?? -1), 交易=\(transactions.count)筆, 目標=\(flightGoals.count)個, 機票=\(redeemedTickets.count)張, 已啟用卡片: [\(activeCards.isEmpty ? "無" : activeCards)]")
    }
    
    /// 信用卡規則以程式碼為準，用戶偏好（isActive / tier）透過 SwiftData CardPreference 同步。
    private func rebuildCreditCards() {
        guard let context = modelContext else { return }
        
        // 從 SwiftData 讀取 CardPreference（可透過 CloudKit 同步）
        let prefs = (try? context.fetch(FetchDescriptor<CardPreference>())) ?? []
        
        // CloudKit 不支援 unique constraints，手動清除重複記錄
        let grouped = Dictionary(grouping: prefs, by: \.cardBrandRaw)
        for (_, group) in grouped where group.count > 1 {
            for dup in group.dropFirst() { context.delete(dup) }
        }
        let dedupedPrefs = grouped.compactMapValues(\.first).values
        
        let cathayPref = dedupedPrefs.first { $0.cardBrandRaw == CardBrand.cathayUnitedBank.rawValue }
        let taishinPref = dedupedPrefs.first { $0.cardBrandRaw == CardBrand.taishinCathay.rawValue }
        
        // 決定偏好值（優先使用 SwiftData，再 fallback 舊 UserDefaults，最後用預設值）
        let cathayActive = cathayPref?.isActive
            ?? (UserDefaults.standard.object(forKey: "card_cathay_active") as? Bool)
            ?? true
        let cathayTier = cathayPref?.cathayTier
            ?? CathayCardTier(rawValue: UserDefaults.standard.string(forKey: "card_cathay_tier") ?? "")
            ?? .world
        let taishinActive = taishinPref?.isActive
            ?? (UserDefaults.standard.object(forKey: "card_taishin_active") as? Bool)
            ?? false
        
        // 從程式碼建立標準的 2 張卡，套用用戶偏好（純 in-memory，不存 SwiftData）
        let cathayCard = CreditCardRule.cathayCard(tier: cathayTier)
        cathayCard.isActive = cathayActive
        
        let taishinCard = CreditCardRule.taishinCathayCard()
        taishinCard.isActive = taishinActive
        
        self.creditCards = [cathayCard, taishinCard]
        
        // 確保 CardPreference 記錄存在（首次執行或從舊版遷移時建立）
        if cathayPref == nil {
            let newPref = CardPreference(cardBrand: .cathayUnitedBank, isActive: cathayActive, tier: cathayTier)
            context.insert(newPref)
        }
        if taishinPref == nil {
            let newPref = CardPreference(cardBrand: .taishinCathay, isActive: taishinActive)
            context.insert(newPref)
        }
        if cathayPref == nil || taishinPref == nil {
            try? context.save()
        }
        
        // 清理 store 中殘留的舊版 CreditCardRule 記錄
        let existing = (try? context.fetch(FetchDescriptor<CreditCardRule>())) ?? []
        if !existing.isEmpty {
            for card in existing {
                context.delete(card)
            }
            try? context.save()
        }
    }
    
    /// 儲存信用卡用戶偏好到 SwiftData CardPreference（透過 CloudKit 同步）
    func saveCardPreferences() {
        guard let context = modelContext else { return }
        let prefs = (try? context.fetch(FetchDescriptor<CardPreference>())) ?? []
        
        for card in creditCards {
            if let pref = prefs.first(where: { $0.cardBrandRaw == card.cardBrandRaw }) {
                pref.isActive = card.isActive
                pref.tierRaw = card.cathayTier?.rawValue ?? ""
            } else {
                // 正常不應該走到這裡，但保險起見補建
                let newPref = CardPreference(
                    cardBrand: card.cardBrand,
                    isActive: card.isActive,
                    tier: card.cathayTier
                )
                context.insert(newPref)
            }
        }
        saveContext()
    }
    
    // 新增交易
    func addTransaction(amount: Decimal,
                       earnedMiles: Int,
                       source: MileageSource,
                       acceleratorCategory: AcceleratorCategory? = nil,
                       date: Date = Date(),
                       notes: String = "",
                       flightRoute: String? = nil,
                       conversionSource: String? = nil,
                       merchantName: String? = nil,
                       promotionName: String? = nil) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        // 創建交易記錄
        let transaction = Transaction(
            date: date,
            amount: amount,
            earnedMiles: earnedMiles,
            source: source,
            acceleratorCategory: acceleratorCategory,
            notes: notes,
            flightRoute: flightRoute,
            conversionSource: conversionSource,
            merchantName: merchantName,
            promotionName: promotionName
        )
        
        context.insert(transaction)
        if account.transactions == nil { account.transactions = [] }
        account.transactions?.append(transaction)
        account.updateMiles(amount: earnedMiles, date: date)
        
        saveContext()
        loadData()
    }
    
    // 計算即時預覽哩程（使用信用卡規則）
    func previewMiles(amount: Decimal,
                     source: MileageSource,
                     acceleratorCategory: AcceleratorCategory? = nil,
                     cardRule: CreditCardRule,
                     date: Date = Date()) -> Int {
        let isBirthdayMonth = Calendar.current.isDate(date, equalTo: userBirthday, toGranularity: .month)
        return cardRule.calculateMiles(
            amount: amount,
            source: source,
            acceleratorCategory: acceleratorCategory,
            isBirthdayMonth: isBirthdayMonth
        )
    }
    
    // 取得已釘選的目標
    func pinnedGoals() -> [FlightGoal] {
        return flightGoals.filter { $0.isPriority }
    }
    
    // 新增飛行目標
    func addFlightGoal(_ goal: FlightGoal) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        // 自動設定 sortOrder 為同群組的最後一位
        let sameGroup = flightGoals.filter { $0.isPriority == goal.isPriority }
        let maxOrder = sameGroup.map { $0.sortOrder }.max() ?? -1
        goal.sortOrder = maxOrder + 1
        
        context.insert(goal)
        if account.flightGoals == nil { account.flightGoals = [] }
        account.flightGoals?.append(goal)
        
        saveContext()
        loadData()
    }
    
    // 刪除飛行目標
    func deleteFlightGoal(_ goal: FlightGoal) {
        guard let context = modelContext else { return }
        context.delete(goal)
        saveContext()
        loadData()
    }

    // 兌換目標為機票里程碑
    func redeemGoal(
        goal: FlightGoal,
        flightDate: Date,
        pnr: String,
        taxPaid: Decimal,
        airline: String = "",
        flightNumber: String = ""
    ) {
        guard let context = modelContext, let account = mileageAccount else { return }

        let redeemedDate = Date()
        let ticket = RedeemedTicket(
            originIATA: goal.origin,
            destinationIATA: goal.destination,
            originName: goal.originName,
            destinationName: goal.destinationName,
            isRoundTrip: goal.isRoundTrip,
            cabinClass: goal.cabinClass,
            spentMiles: goal.requiredMiles,
            taxPaid: taxPaid,
            flightDate: flightDate,
            pnr: pnr,
            airline: airline,
            flightNumber: flightNumber,
            redeemedDate: redeemedDate
        )
        context.insert(ticket)

        let trimmedAirline = airline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFlightNumber = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        var noteParts: [String] = []
        if !trimmedAirline.isEmpty { noteParts.append(trimmedAirline) }
        if !trimmedFlightNumber.isEmpty { noteParts.append(trimmedFlightNumber) }
        let redeemNote = noteParts.joined(separator: " ")
        let transaction = Transaction(
            date: redeemedDate,
            amount: taxPaid,
            earnedMiles: -goal.requiredMiles,
            source: .ticketRedemption,
            notes: redeemNote,
            flightRoute: "\(goal.origin)-\(goal.destination)",
            linkedTicketID: ticket.id
        )
        context.insert(transaction)
        if account.transactions == nil { account.transactions = [] }
        account.transactions?.append(transaction)
        account.updateMiles(amount: -goal.requiredMiles, date: redeemedDate)

        // 雙向連結
        ticket.linkedTransactionID = transaction.id

        deleteFlightGoal(goal)
        saveContext()
        loadData()
    }
    
    // 更新交易
    func updateTransaction(_ transaction: Transaction,
                           amount: Decimal,
                           earnedMiles: Int,
                           source: MileageSource,
                           acceleratorCategory: AcceleratorCategory? = nil,
                           date: Date,
                           notes: String = "",
                           flightRoute: String? = nil,
                           conversionSource: String? = nil,
                           merchantName: String? = nil,
                           promotionName: String? = nil) {
        guard let account = mileageAccount else { return }
        
        // 先扣掉舊的哩程，再加上新的
        let milesDiff = earnedMiles - transaction.earnedMiles
        account.updateMiles(amount: milesDiff, date: date)
        
        // 更新交易屬性
        transaction.date = date
        transaction.amount = amount
        transaction.earnedMiles = earnedMiles
        transaction.source = source
        transaction.acceleratorCategory = acceleratorCategory
        transaction.notes = notes
        transaction.flightRoute = flightRoute
        transaction.conversionSource = conversionSource
        transaction.merchantName = merchantName
        transaction.promotionName = promotionName
        
        // 重新計算每哩成本
        if earnedMiles > 0 {
            transaction.costPerMile = Double(truncating: amount as NSDecimalNumber) / Double(earnedMiles)
        } else {
            transaction.costPerMile = 0
        }
        
        saveContext()
        loadData()
    }
    
    // 刪除交易（連動刪除關聯的兌換紀錄）
    func deleteTransaction(_ transaction: Transaction) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        // 如果有連結的兌換紀錄，一併刪除
        if let ticketID = transaction.linkedTicketID,
           let ticket = redeemedTickets.first(where: { $0.id == ticketID }) {
            context.delete(ticket)
        }
        
        // 從哩程帳戶減去該交易的哩程
        account.updateMiles(amount: -transaction.earnedMiles, date: transaction.date)
        
        // 從陣列中移除
        if let index = account.transactions?.firstIndex(where: { $0.id == transaction.id }) {
            account.transactions?.remove(at: index)
        }
        
        // 從資料庫刪除
        context.delete(transaction)
        saveContext()
        loadData()
    }
    
    // 刪除兌換紀錄（連動刪除關聯的扣點交易）
    func deleteRedeemedTicket(_ ticket: RedeemedTicket) {
        guard let context = modelContext, let account = mileageAccount else { return }

        // 優先使用雙向連結刪除；若舊資料沒有連結，再嘗試依特徵比對扣點交易
        var linkedTransaction: Transaction?
        if let txID = ticket.linkedTransactionID {
            linkedTransaction = transactions.first(where: { $0.id == txID })
        }

        if linkedTransaction == nil {
            linkedTransaction = transactions.first(where: {
                ($0.source == .ticketRedemption || $0.source == .flight) &&
                $0.earnedMiles == -ticket.spentMiles &&
                $0.flightRoute == "\(ticket.originIATA)-\(ticket.destinationIATA)" &&
                $0.amount == ticket.taxPaid
            })
        }

        if let transaction = linkedTransaction {
            account.updateMiles(amount: -transaction.earnedMiles, date: transaction.date)
            if let index = account.transactions?.firstIndex(where: { $0.id == transaction.id }) {
                account.transactions?.remove(at: index)
            }
            context.delete(transaction)
        }
        
        context.delete(ticket)
        saveContext()
        loadData()
    }
    
    // 取得最接近達成的目標
    func closestGoal() -> FlightGoal? {
        guard let currentMiles = mileageAccount?.totalMiles else { return nil }
        
        let priorityGoals = flightGoals.filter { $0.isPriority }
        let goalsToCheck = priorityGoals.isEmpty ? flightGoals : priorityGoals
        
        return goalsToCheck
            .filter { $0.requiredMiles > currentMiles }
            .min { $0.milesNeeded(currentMiles: currentMiles) < $1.milesNeeded(currentMiles: currentMiles) }
    }

    // 取得目前可直接兌換的航點目標
    func redeemableGoals(limit: Int = 3) -> [FlightGoal] {
        guard let currentMiles = mileageAccount?.totalMiles else { return [] }

        let sorted = flightGoals.sorted { lhs, rhs in
            if lhs.isPriority != rhs.isPriority {
                return lhs.isPriority && !rhs.isPriority
            }
            if lhs.requiredMiles != rhs.requiredMiles {
                return lhs.requiredMiles < rhs.requiredMiles
            }
            return lhs.createdDate < rhs.createdDate
        }

        return Array(sorted.filter { $0.requiredMiles <= currentMiles }.prefix(limit))
    }
    
    // 新增信用卡
    func addCreditCard(_ card: CreditCardRule) {
        guard let context = modelContext else { return }
        context.insert(card)
        saveContext()
        loadData()
    }
    
    // 刪除信用卡
    func deleteCreditCard(_ card: CreditCardRule) {
        guard let context = modelContext else { return }
        context.delete(card)
        saveContext()
        loadData()
    }
    
    // 切換信用卡啟用狀態
    func toggleCardActive(_ card: CreditCardRule) {
        card.isActive.toggle()
        saveCardPreferences()
    }
    
    // 切換國泰卡等級
    func updateCardTier(_ card: CreditCardRule, tier: CathayCardTier) {
        card.updateTier(tier)
        saveCardPreferences()
    }
    
    
    // 取得本月交易統計
    func monthlyStats() -> (totalAmount: Decimal, totalMiles: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        
        // 兌換機票的附加稅不計入「本月消費」
        let totalAmount = monthTransactions
            .filter { $0.source != .ticketRedemption }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let totalMiles = monthTransactions.reduce(0) { $0 + $1.earnedMiles }
        
        return (totalAmount, totalMiles)
    }
}
