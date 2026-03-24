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
    
    init() {}
    
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
        loadData()
        knownDataFingerprint = fetchDataFingerprint()
        
        // 監聽 CloudKit 遠端變更通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }
    
    /// 收到遠端變更通知時，檢查是否有新資料
    private func handleRemoteChange() {
        let latestFingerprint = fetchDataFingerprint()
        if latestFingerprint != knownDataFingerprint {
            hasRemoteChanges = true
        }
    }
    
    /// 用戶確認同步後，刷新 UI
    func acknowledgeRemoteChanges() {
        manualSyncNow()
    }

    /// 手動同步：重新讀取本地 store（含已匯入的 CloudKit 變更）
    func manualSyncNow() {
        loadData()
        knownDataFingerprint = fetchDataFingerprint()
        hasRemoteChanges = false
    }
    
    /// App 回到前台時呼叫，檢查是否有待同步的遠端資料
    func checkForRemoteChanges() {
        let latestFingerprint = fetchDataFingerprint()
        if latestFingerprint != knownDataFingerprint {
            hasRemoteChanges = true
        }
    }

    private func fetchDataFingerprint() -> String {
        guard let context = modelContext else { return "" }

        let accounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        let cards = (try? context.fetch(FetchDescriptor<CreditCardRule>())) ?? []
        let tickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []

        let accountPart = accounts
            .sorted { $0.lastActivityDate < $1.lastActivityDate }
            .map { "\($0.totalMiles)|\($0.lastActivityDate.timeIntervalSince1970)" }
            .joined(separator: ";")

        let txPart = txs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.date.timeIntervalSince1970)|\($0.amountValue)|\($0.earnedMiles)|\($0.sourceRaw)|\($0.acceleratorCategoryRaw ?? "")|\($0.notes)|\($0.costPerMile)|\($0.flightRoute ?? "")|\($0.conversionSource ?? "")|\($0.merchantName ?? "")|\($0.promotionName ?? "")|\($0.linkedTicketID?.uuidString ?? "")"
            }
            .joined(separator: ";")

        let goalPart = goals
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.origin)|\($0.destination)|\($0.originName)|\($0.destinationName)|\($0.cabinClassRaw)|\($0.requiredMiles)|\($0.isOneworld)|\($0.isPriority)|\($0.isRoundTrip)|\($0.createdDate.timeIntervalSince1970)|\($0.sortOrder)"
            }
            .joined(separator: ";")

        let cardPart = cards
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.cardName)|\($0.bankName)|\($0.isActive)|\($0.cardBrandRaw)|\($0.cardTierRaw)|\($0.baseRateValue)|\($0.acceleratorRateValue)|\($0.specialMerchantRateValue)|\($0.birthdayMultiplierValue)|\($0.roundingModeRaw)|\($0.billingDay)|\($0.annualFee)"
            }
            .joined(separator: ";")

        let ticketPart = tickets
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.originIATA)|\($0.destinationIATA)|\($0.originName)|\($0.destinationName)|\($0.isRoundTrip)|\($0.cabinClassRaw)|\($0.spentMiles)|\($0.taxPaidValue)|\($0.flightDate.timeIntervalSince1970)|\($0.pnr)|\($0.airline)|\($0.flightNumber)|\($0.redeemedDate.timeIntervalSince1970)|\($0.linkedTransactionID?.uuidString ?? "")"
            }
            .joined(separator: ";")

        return [accountPart, txPart, goalPart, cardPart, ticketPart].joined(separator: "||")
    }
    
    // 載入資料
    func loadData() {
        guard let context = modelContext else { return }
        
        // 載入哩程帳戶
        let accountDescriptor = FetchDescriptor<MileageAccount>()
        if let accounts = try? context.fetch(accountDescriptor), let account = accounts.first {
            self.mileageAccount = account
            self.transactions = (account.transactions ?? []).sorted { $0.date > $1.date }
            self.flightGoals = account.flightGoals ?? []
        } else {
            // 創建新帳戶
            let newAccount = MileageAccount()
            context.insert(newAccount)
            self.mileageAccount = newAccount
            saveContext()
        }
        
        // 載入信用卡規則
        let cardDescriptor = FetchDescriptor<CreditCardRule>()
        self.creditCards = (try? context.fetch(cardDescriptor)) ?? []

        // 載入兌換成功紀錄（最新在前）
        let redeemedDescriptor = FetchDescriptor<RedeemedTicket>(
            sortBy: [SortDescriptor(\RedeemedTicket.redeemedDate, order: .reverse)]
        )
        self.redeemedTickets = (try? context.fetch(redeemedDescriptor)) ?? []
        
        // 舊資料遷移：多張國泰卡 → 1 張 + 等級選擇
        migrateCardDataIfNeeded()
        
        // 如果沒有信用卡，創建預設卡片
        if creditCards.isEmpty {
            let cathayCard = CreditCardRule.cathayCard(tier: .world)
            let taishinCard = CreditCardRule.taishinCathayCard()
            context.insert(cathayCard)
            context.insert(taishinCard)
            creditCards = [cathayCard, taishinCard]
            saveContext()
        }
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
        saveContext()
        loadData()
    }
    
    // 切換國泰卡等級
    func updateCardTier(_ card: CreditCardRule, tier: CathayCardTier) {
        card.updateTier(tier)
        saveContext()
    }
    
    // 舊資料遷移：多張國泰世華卡 → 1 張 + 等級
    private func migrateCardDataIfNeeded() {
        guard let context = modelContext else { return }
        
        let cathayCards = creditCards.filter { $0.bankName == "國泰世華銀行" }
        
        // 只有多張國泰卡時才需要遷移
        guard cathayCards.count > 1 else {
            // 確保既有的單張國泰卡也有 brand/tier 標記
            if let single = cathayCards.first, single.cardBrandRaw == "cathayUnitedBank", single.cardTierRaw.isEmpty {
                // 從 cardName 推斷等級
                let tier = inferTier(from: single.cardName)
                single.cardBrandRaw = CardBrand.cathayUnitedBank.rawValue
                single.cardTierRaw = tier.rawValue
            }
            // 確保有台新卡與國泰卡
            ensureCathayCardExists()
            ensureTaishinCardExists()
            return
        }
        
        // 找出要保留的那張（優先保留 active 的，再取第一張）
        let keepCard = cathayCards.first(where: { $0.isActive }) ?? cathayCards.first!
        let tier = inferTier(from: keepCard.cardName)
        keepCard.cardBrandRaw = CardBrand.cathayUnitedBank.rawValue
        keepCard.cardTierRaw = tier.rawValue
        keepCard.cardName = "國泰世華亞萬聯名卡 \(tier.rawValue)"
        
        // 刪除多餘的國泰卡
        for card in cathayCards where card.id != keepCard.id {
            context.delete(card)
        }
        
        // 確保有台新卡
        ensureTaishinCardExists()
        
        saveContext()
        
        // 重新載入
        let cardDescriptor = FetchDescriptor<CreditCardRule>()
        self.creditCards = (try? context.fetch(cardDescriptor)) ?? []
    }
    
    // 從 cardName 推斷國泰卡等級
    private func inferTier(from cardName: String) -> CathayCardTier {
        if cardName.contains("世界") { return .world }
        if cardName.contains("鈦") { return .titanium }
        if cardName.contains("白金") { return .platinum }
        if cardName.contains("里享") { return .miles }
        return .world // 預設
    }
    
    // 確保台新卡存在
    private func ensureTaishinCardExists() {
        guard let context = modelContext else { return }
        let hasTaishin = creditCards.contains { $0.bankName == "台新銀行" }
        if !hasTaishin {
            let taishinCard = CreditCardRule.taishinCathayCard()
            context.insert(taishinCard)
            creditCards.append(taishinCard)
            saveContext()
        }
    }
    
    // 確保國泰卡存在
    private func ensureCathayCardExists() {
        guard let context = modelContext else { return }
        let hasCathay = creditCards.contains { $0.cardBrandRaw == CardBrand.cathayUnitedBank.rawValue }
        if !hasCathay {
            let cathayCard = CreditCardRule.cathayCard(tier: .world)
            context.insert(cathayCard)
            creditCards.append(cathayCard)
            saveContext()
        }
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
