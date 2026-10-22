import Foundation
import SwiftData

// MARK: - 交易、飛行目標、兌換紀錄 CRUD 與統計

extension MileageViewModel {
    
    // MARK: - 交易 CRUD
    
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
        
        let previousStatementBrand = transaction.source == .cardStatement ? transaction.cardBrand : nil
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
        
        if let brand = previousStatementBrand {
            clearStatementFields(transaction)
            recalculateStatementTransfers(for: brand)
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
        
        let statementBrand = transaction.source == .cardStatement ? transaction.cardBrand : nil
        context.delete(transaction)
        if let brand = statementBrand {
            recalculateStatementTransfers(for: brand)
        }
        saveContext()
        loadData()
    }
    
    // MARK: - 帳單哩程（每期帳單轉點）
    
    /// 新增一期帳單哩程：points 先進銀行端點數池，實際轉入里數由 recalculateStatementTransfers 決定
    func addStatement(cardBrand: CardBrand,
                      date: Date,
                      baseMiles: Int,
                      bonusMiles: Int,
                      birthdayMiles: Int,
                      notes: String = "") {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        let transaction = Transaction(
            date: date,
            amount: 0,
            earnedMiles: 0,
            source: .cardStatement,
            cardBrand: cardBrand,
            notes: notes
        )
        transaction.programID = activeProgram?.id
        applyStatementFields(transaction, baseMiles: baseMiles, bonusMiles: bonusMiles, birthdayMiles: birthdayMiles)
        
        context.insert(transaction)
        if account.transactions == nil { account.transactions = [] }
        account.transactions?.append(transaction)
        account.updateMiles(amount: 0, date: date)
        recalculateStatementTransfers(for: cardBrand)
        
        saveContext()
        loadData()
    }
    
    /// 更新帳單哩程（也可把其他類型交易改成帳單哩程）
    func updateStatement(_ transaction: Transaction,
                         cardBrand: CardBrand,
                         date: Date,
                         baseMiles: Int,
                         bonusMiles: Int,
                         birthdayMiles: Int,
                         notes: String = "") {
        guard let account = mileageAccount else { return }
        
        let previousStatementBrand = transaction.source == .cardStatement ? transaction.cardBrand : nil
        // 先扣回原本計入的里數，轉入量交給重算決定
        account.updateMiles(amount: -transaction.earnedMiles, date: date)
        transaction.earnedMiles = 0
        
        transaction.date = date
        transaction.amount = 0
        transaction.costPerMile = 0
        transaction.source = .cardStatement
        transaction.resolvedSubcategoryID = nil
        transaction.cardBrand = cardBrand
        transaction.notes = notes
        transaction.flightRoute = nil
        transaction.conversionSource = nil
        transaction.merchantName = nil
        transaction.promotionName = nil
        applyStatementFields(transaction, baseMiles: baseMiles, bonusMiles: bonusMiles, birthdayMiles: birthdayMiles)
        
        recalculateStatementTransfers(for: cardBrand)
        if let previousStatementBrand, previousStatementBrand != cardBrand {
            recalculateStatementTransfers(for: previousStatementBrand)
        }
        
        saveContext()
        loadData()
    }
    
    /// 依時間順序重跑銀行端點數池，更新每期轉入里數與帳戶總里程
    func recalculateStatementTransfers(for brand: CardBrand) {
        guard let account = mileageAccount,
              let rule = CardBrandRegistry.statementPosting(for: brand) else { return }
        
        var balance = bankPointsOpeningBalance(for: brand)
        for transaction in statementTransactions(for: brand, in: account.transactions ?? []) {
            let result = StatementPostingCalculator.post(
                points: transaction.statementPoints,
                carryOver: balance,
                transferUnit: rule.transferUnit
            )
            if transaction.earnedMiles != result.transferred {
                account.totalMiles += result.transferred - transaction.earnedMiles
                transaction.earnedMiles = result.transferred
            }
            transaction.statementBankBalance = result.balanceAfter
            balance = result.balanceAfter
        }
    }
    
    /// 預覽一期帳單轉點結果（不寫入資料）
    func previewStatement(cardBrand: CardBrand,
                          date: Date,
                          points: Int,
                          excluding transactionID: UUID? = nil) -> (carryOver: Int, result: StatementPostingCalculator.Result)? {
        guard let rule = CardBrandRegistry.statementPosting(for: cardBrand) else { return nil }
        
        var balance = bankPointsOpeningBalance(for: cardBrand)
        let earlier = statementTransactions(for: cardBrand, in: transactions)
            .filter { $0.id != transactionID && $0.date <= date }
        for transaction in earlier {
            balance = StatementPostingCalculator.post(
                points: transaction.statementPoints,
                carryOver: balance,
                transferUnit: rule.transferUnit
            ).balanceAfter
        }
        let result = StatementPostingCalculator.post(points: points, carryOver: balance, transferUnit: rule.transferUnit)
        return (balance, result)
    }
    
    /// 目前留在銀行端、尚未轉入的哩程點數
    func bankPointsBalance(for brand: CardBrand) -> Int {
        statementTransactions(for: brand, in: transactions).last?.statementBankBalance
            ?? bankPointsOpeningBalance(for: brand)
    }
    
    func bankPointsOpeningBalance(for brand: CardBrand) -> Int {
        cardPreference(for: brand)?.bankPointsOpeningBalance ?? 0
    }
    
    /// 設定銀行端起始點數（開始用帳單記錄前已累積的零頭），並重算所有帳單
    func setBankPointsOpeningBalance(_ balance: Int, for brand: CardBrand) {
        guard let context = modelContext else { return }
        if let pref = cardPreference(for: brand) {
            pref.bankPointsOpeningBalance = max(0, balance)
        } else {
            let pref = CardPreference(cardBrand: brand, isActive: creditCards.first { $0.cardBrand == brand }?.isActive ?? false)
            pref.bankPointsOpeningBalance = max(0, balance)
            context.insert(pref)
        }
        recalculateStatementTransfers(for: brand)
        saveContext()
        loadData()
    }
    
    private func cardPreference(for brand: CardBrand) -> CardPreference? {
        guard let context = modelContext else { return nil }
        let prefs = (try? context.fetch(FetchDescriptor<CardPreference>())) ?? []
        return prefs.first { $0.cardBrandRaw == brand.rawValue }
    }
    
    /// 某品牌的帳單哩程，依帳單日期排序（同日以 id 決定順序，確保各裝置重算一致）
    private func statementTransactions(for brand: CardBrand, in list: [Transaction]) -> [Transaction] {
        list.filter { $0.source == .cardStatement && $0.cardBrand == brand }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
    }
    
    private func applyStatementFields(_ transaction: Transaction, baseMiles: Int, bonusMiles: Int, birthdayMiles: Int) {
        transaction.statementBaseMiles = baseMiles
        transaction.statementBonusMiles = bonusMiles
        transaction.statementBirthdayMiles = birthdayMiles > 0 ? birthdayMiles : nil
    }
    
    private func clearStatementFields(_ transaction: Transaction) {
        transaction.statementBaseMiles = nil
        transaction.statementBonusMiles = nil
        transaction.statementBirthdayMiles = nil
        transaction.statementBankBalance = nil
    }
    
    // MARK: - 飛行目標
    
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
    
    // MARK: - 兌換紀錄
    
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
    
    // MARK: - 查詢與統計
    
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
