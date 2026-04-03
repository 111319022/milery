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
    private var knownDataFingerprint: String = ""
    private var isInitialLoad: Bool = true
    private var remoteChangeWorkItem: DispatchWorkItem?
    private var remoteChangeObserver: NSObjectProtocol?
    
    init() {}
    
    // MARK: - 里程計劃管理
    
    func loadPrograms() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MileageProgram>(
            sortBy: [SortDescriptor(\MileageProgram.createdDate)]
        )
        programs = (try? context.fetch(descriptor)) ?? []
        
        deduplicateDefaultPrograms()
        
        if programs.isEmpty {
            let defaultProgram = MileageProgram(name: "Asia Miles", programType: .asiaMiles, isDefault: true)
            context.insert(defaultProgram)
            try? context.save()
            programs = [defaultProgram]
            ActiveProgramManager.activeProgramID = defaultProgram.id
            
            migrateExistingDataToProgram(defaultProgram)
        }
        
        if let savedID = ActiveProgramManager.activeProgramID,
           let found = programs.first(where: { $0.id == savedID }) {
            activeProgram = found
        } else if let first = programs.first {
            activeProgram = first
            ActiveProgramManager.activeProgramID = first.id
        }
    }
    
    private func deduplicateDefaultPrograms() {
        guard let context = modelContext else { return }
        
        let defaultPrograms = programs.filter { $0.isDefault }
        guard defaultPrograms.count > 1 else { return }
        
        let allAccounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        
        let keepProgram = defaultPrograms.max { a, b in
            let aCount = allTransactions.filter { $0.programID == a.id }.count
                       + allAccounts.filter { $0.programID == a.id }.map { $0.totalMiles }.reduce(0, +)
            let bCount = allTransactions.filter { $0.programID == b.id }.count
                       + allAccounts.filter { $0.programID == b.id }.map { $0.totalMiles }.reduce(0, +)
            if aCount != bCount { return aCount < bCount }
            return a.createdDate > b.createdDate
        }!
        
        let duplicates = defaultPrograms.filter { $0.id != keepProgram.id }
        guard !duplicates.isEmpty else { return }
        
        let duplicateIDs = Set(duplicates.map { $0.id })
        appLog("[Program] 偵測到 \(defaultPrograms.count) 個重複的預設計劃，合併至: \(keepProgram.id.uuidString.prefix(8))")
        
        let allGoals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        let allTickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        
        for account in allAccounts where duplicateIDs.contains(account.programID ?? UUID()) {
            account.programID = keepProgram.id
        }
        for tx in allTransactions where duplicateIDs.contains(tx.programID ?? UUID()) {
            tx.programID = keepProgram.id
        }
        for goal in allGoals where duplicateIDs.contains(goal.programID ?? UUID()) {
            goal.programID = keepProgram.id
        }
        for ticket in allTickets where duplicateIDs.contains(ticket.programID ?? UUID()) {
            ticket.programID = keepProgram.id
        }
        
        let keepAccounts = allAccounts.filter { $0.programID == keepProgram.id }
        let duplicateAccounts = allAccounts.filter { duplicateIDs.contains($0.programID ?? UUID()) }
        
        if let mainAccount = keepAccounts.sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            for dupAccount in duplicateAccounts {
                for tx in dupAccount.transactions ?? [] {
                    if mainAccount.transactions == nil { mainAccount.transactions = [] }
                    mainAccount.transactions?.append(tx)
                }
                for goal in dupAccount.flightGoals ?? [] {
                    if mainAccount.flightGoals == nil { mainAccount.flightGoals = [] }
                    mainAccount.flightGoals?.append(goal)
                }
                if dupAccount.lastActivityDate > mainAccount.lastActivityDate {
                    mainAccount.lastActivityDate = dupAccount.lastActivityDate
                }
                context.delete(dupAccount)
            }
        }
        
        for dup in duplicates {
            context.delete(dup)
        }
        
        try? context.save()
        
        let descriptor = FetchDescriptor<MileageProgram>(
            sortBy: [SortDescriptor(\MileageProgram.createdDate)]
        )
        programs = (try? context.fetch(descriptor)) ?? []
        
        ActiveProgramManager.activeProgramID = keepProgram.id
        
        appLog("[Program] 重複計劃合併完成，保留計劃: \(keepProgram.name) (\(keepProgram.id.uuidString.prefix(8)))")
    }
    
    private func migrateExistingDataToProgram(_ program: MileageProgram) {
        guard let context = modelContext else { return }
        
        let accounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        for account in accounts where account.programID == nil {
            account.programID = program.id
        }
        
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in transactions where tx.programID == nil {
            tx.programID = program.id
        }
        
        let goals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        for goal in goals where goal.programID == nil {
            goal.programID = program.id
        }
        
        let tickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        for ticket in tickets where ticket.programID == nil {
            ticket.programID = program.id
        }
        
        try? context.save()
        appLog("[Program] 既有資料已遷移至計劃: \(program.name)")
    }
    
    private func migrateOrphanedDataToActiveProgram() {
        guard let context = modelContext, let activePID = activeProgram?.id else { return }
        
        let validProgramIDs = Set(programs.map { $0.id })
        var migrated = 0
        
        let accounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        for account in accounts where account.programID == nil || !validProgramIDs.contains(account.programID!) {
            account.programID = activePID
            migrated += 1
        }
        
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in transactions where tx.programID == nil || !validProgramIDs.contains(tx.programID!) {
            tx.programID = activePID
            migrated += 1
        }
        
        let goals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        for goal in goals where goal.programID == nil || !validProgramIDs.contains(goal.programID!) {
            goal.programID = activePID
            migrated += 1
        }
        
        let tickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        for ticket in tickets where ticket.programID == nil || !validProgramIDs.contains(ticket.programID!) {
            ticket.programID = activePID
            migrated += 1
        }
        
        if migrated > 0 {
            try? context.save()
            appLog("[Sync] 已將 \(migrated) 筆孤兒資料綁定至當前計劃")
        }
    }
    
    func switchProgram(to program: MileageProgram) {
        activeProgram = program
        ActiveProgramManager.activeProgramID = program.id
        isInitialLoad = true
        loadData()
        isInitialLoad = false
        knownDataFingerprint = fetchDataFingerprint()
        appLog("[Program] 已切換至計劃: \(program.name)")
    }
    
    func addProgram(name: String, type: MilageProgramType) {
        guard let context = modelContext else { return }
        let program = MileageProgram(name: name, programType: type)
        context.insert(program)
        
        let account = MileageAccount()
        account.programID = program.id
        context.insert(account)
        
        try? context.save()
        loadPrograms()
        
        switchProgram(to: program)
    }
    
    func deleteProgram(_ program: MileageProgram) {
        guard let context = modelContext, !program.isDefault else { return }
        
        let pid = program.id
        
        let accounts = (try? context.fetch(FetchDescriptor<MileageAccount>())) ?? []
        for account in accounts where account.programID == pid {
            context.delete(account)
        }
        
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for tx in transactions where tx.programID == pid {
            context.delete(tx)
        }
        
        let goals = (try? context.fetch(FetchDescriptor<FlightGoal>())) ?? []
        for goal in goals where goal.programID == pid {
            context.delete(goal)
        }
        
        let tickets = (try? context.fetch(FetchDescriptor<RedeemedTicket>())) ?? []
        for ticket in tickets where ticket.programID == pid {
            context.delete(ticket)
        }
        
        context.delete(program)
        try? context.save()
        
        loadPrograms()
        
        if let defaultProgram = programs.first(where: { $0.isDefault }) ?? programs.first {
            switchProgram(to: defaultProgram)
        }
        
        appLog("[Program] 已刪除計劃: \(program.name)")
    }
    
    deinit {
        if let observer = remoteChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        remoteChangeWorkItem?.cancel()
    }
    
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
    
    private func handleRemoteChange() {
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

        let programPart = ActiveProgramManager.activeProgramID?.uuidString ?? "none"
        return [programPart, accountPart, txPart, goalPart, ticketPart, cardPrefPart].joined(separator: "||")
    }
    
    // 載入資料（依當前啟用的里程計劃篩選）
    func loadData() {
        guard let context = modelContext else { return }
        
        let activePID = activeProgram?.id
        
        let accountDescriptor = FetchDescriptor<MileageAccount>()
        let allAccounts = (try? context.fetch(accountDescriptor)) ?? []
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
        let allTickets = (try? context.fetch(redeemedDescriptor)) ?? []
        self.redeemedTickets = allTickets.filter { $0.programID == activePID }
        
        let programName = activeProgram?.name ?? "未知"
        let activeCardNames = creditCards.filter { $0.isActive }.map { $0.cardName }.joined(separator: ", ")
        appLog("[Sync] loadData 完成 [\(programName)]: 哩程=\(mileageAccount?.totalMiles ?? -1), 交易=\(transactions.count)筆, 目標=\(flightGoals.count)個, 機票=\(redeemedTickets.count)張, 已啟用卡片: [\(activeCardNames.isEmpty ? "無" : activeCardNames)]")
    }
    
    /// 信用卡規則以程式碼為準，用戶偏好（isActive / tier）透過 SwiftData CardPreference 同步。
    /// 通用版：遍歷 CardBrandRegistry.allDefinitions 建立卡片。
    private func rebuildCreditCards() {
        guard let context = modelContext else { return }
        
        // 從 SwiftData 讀取 CardPreference
        let prefs = (try? context.fetch(FetchDescriptor<CardPreference>())) ?? []
        
        // CloudKit 不支援 unique constraints，手動清除重複記錄
        let grouped = Dictionary(grouping: prefs, by: \.cardBrandRaw)
        for (_, group) in grouped where group.count > 1 {
            for dup in group.dropFirst() { context.delete(dup) }
        }
        let dedupedPrefs = grouped.compactMapValues(\.first).values
        
        var cards: [CreditCardRule] = []
        var needsSave = false
        
        for def in CardBrandRegistry.allDefinitions {
            let pref = dedupedPrefs.first { $0.cardBrandRaw == def.brandID.rawValue }
            
            // 決定偏好值（優先使用 SwiftData，再 fallback 舊 UserDefaults，最後用預設值）
            let udActiveKey = "card_\(def.brandID.rawValue)_active"
            let udTierKey = "card_\(def.brandID.rawValue)_tier"
            
            let isActive = pref?.isActive
                ?? (UserDefaults.standard.object(forKey: udActiveKey) as? Bool)
                ?? def.defaultIsActive
            
            let tierID = {
                if let raw = pref?.tierRaw, !raw.isEmpty, def.tier(for: raw) != nil { return raw }
                if let raw = UserDefaults.standard.string(forKey: udTierKey), def.tier(for: raw) != nil { return raw }
                return def.defaultTierID
            }()
            
            let card = def.makeCard(tierID: tierID)
            card.isActive = isActive
            cards.append(card)
            
            // 確保 CardPreference 記錄存在
            if pref == nil {
                let newPref = CardPreference(cardBrand: def.brandID, isActive: isActive, tierID: tierID)
                context.insert(newPref)
                needsSave = true
            }
        }
        
        self.creditCards = cards
        
        if needsSave {
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
                pref.tierRaw = card.cardTierRaw
            } else {
                let newPref = CardPreference(
                    cardBrand: card.cardBrand,
                    isActive: card.isActive,
                    tierID: card.cardTierRaw
                )
                context.insert(newPref)
            }
        }
        saveContext()
    }
    
    // 新增交易（通用版 — 使用 subcategoryID）
    func addTransaction(amount: Decimal,
                       earnedMiles: Int,
                       source: MileageSource,
                       subcategoryID: String? = nil,
                       cardBrand: CardBrand? = nil,
                       date: Date = Date(),
                       notes: String = "",
                       flightRoute: String? = nil,
                       conversionSource: String? = nil,
                       merchantName: String? = nil,
                       promotionName: String? = nil) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        let transaction = Transaction(
            date: date,
            amount: amount,
            earnedMiles: earnedMiles,
            source: source,
            subcategoryID: subcategoryID,
            cardBrand: cardBrand,
            notes: notes,
            flightRoute: flightRoute,
            conversionSource: conversionSource,
            merchantName: merchantName,
            promotionName: promotionName
        )
        transaction.programID = activeProgram?.id
        
        context.insert(transaction)
        if account.transactions == nil { account.transactions = [] }
        account.transactions?.append(transaction)
        account.updateMiles(amount: earnedMiles, date: date)
        
        saveContext()
        loadData()
    }
    
    // 計算即時預覽哩程
    func previewMiles(amount: Decimal,
                     source: MileageSource,
                     subcategoryID: String? = nil,
                     cardRule: CreditCardRule,
                     date: Date = Date()) -> Int {
        return cardRule.calculateMiles(
            amount: amount,
            source: source,
            subcategoryID: subcategoryID,
            isBirthdayMonth: isBirthdayMonth(for: date)
        )
    }
    
    // 取得已釘選的目標
    func pinnedGoals() -> [FlightGoal] {
        return flightGoals.filter { $0.isPriority }
    }
    
    // 新增飛行目標
    func addFlightGoal(_ goal: FlightGoal) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        let sameGroup = flightGoals.filter { $0.isPriority == goal.isPriority }
        let maxOrder = sameGroup.map { $0.sortOrder }.max() ?? -1
        goal.sortOrder = maxOrder + 1
        
        goal.programID = activeProgram?.id
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
        ticket.programID = activeProgram?.id
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
        transaction.programID = activeProgram?.id
        context.insert(transaction)
        if account.transactions == nil { account.transactions = [] }
        account.transactions?.append(transaction)
        account.updateMiles(amount: -goal.requiredMiles, date: redeemedDate)

        ticket.linkedTransactionID = transaction.id

        deleteFlightGoal(goal)
        saveContext()
        loadData()
    }
    
    // 更新交易（通用版）
    func updateTransaction(_ transaction: Transaction,
                           amount: Decimal,
                           earnedMiles: Int,
                           source: MileageSource,
                           subcategoryID: String? = nil,
                           cardBrand: CardBrand? = nil,
                           date: Date,
                           notes: String = "",
                           flightRoute: String? = nil,
                           conversionSource: String? = nil,
                           merchantName: String? = nil,
                           promotionName: String? = nil) {
        guard let account = mileageAccount else { return }
        
        let milesDiff = earnedMiles - transaction.earnedMiles
        account.updateMiles(amount: milesDiff, date: date)
        
        transaction.date = date
        transaction.amount = amount
        transaction.earnedMiles = earnedMiles
        transaction.source = source
        transaction.resolvedSubcategoryID = subcategoryID
        transaction.cardBrand = cardBrand
        transaction.notes = notes
        transaction.flightRoute = flightRoute
        transaction.conversionSource = conversionSource
        transaction.merchantName = merchantName
        transaction.promotionName = promotionName
        
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
        
        if let ticketID = transaction.linkedTicketID,
           let ticket = redeemedTickets.first(where: { $0.id == ticketID }) {
            context.delete(ticket)
        }
        
        account.updateMiles(amount: -transaction.earnedMiles, date: transaction.date)
        
        if let index = account.transactions?.firstIndex(where: { $0.id == transaction.id }) {
            account.transactions?.remove(at: index)
        }
        
        context.delete(transaction)
        saveContext()
        loadData()
    }
    
    // 刪除兌換紀錄（連動刪除關聯的扣點交易）
    func deleteRedeemedTicket(_ ticket: RedeemedTicket) {
        guard let context = modelContext, let account = mileageAccount else { return }

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
    
    // 通用切換卡片等級
    func updateCardTier(_ card: CreditCardRule, tierID: String) {
        card.updateTier(tierID)
        saveCardPreferences()
    }
    
    // 取得本月交易統計
    func monthlyStats() -> (totalAmount: Decimal, totalMiles: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        
        let totalAmount = monthTransactions
            .filter { $0.source != .ticketRedemption }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let totalMiles = monthTransactions.reduce(0) { $0 + $1.earnedMiles }
        
        return (totalAmount, totalMiles)
    }
}
