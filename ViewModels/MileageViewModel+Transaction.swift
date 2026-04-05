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
