//
//  MileageViewModel.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class MileageViewModel {
    var modelContext: ModelContext?
    var mileageAccount: MileageAccount?
    var creditCards: [CreditCardRule] = []
    var transactions: [Transaction] = []
    var flightGoals: [FlightGoal] = []
    
    // 使用者生日（用於計算生日當月加碼）
    var userBirthday: Date = Calendar.current.date(from: DateComponents(month: 1, day: 1)) ?? Date()
    
    // 儲存錯誤訊息，供 UI 顯示 Alert
    var saveError: String?
    var showSaveError: Bool = false
    
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
    }
    
    // 載入資料
    func loadData() {
        guard let context = modelContext else { return }
        
        // 載入哩程帳戶
        let accountDescriptor = FetchDescriptor<MileageAccount>()
        if let accounts = try? context.fetch(accountDescriptor), let account = accounts.first {
            self.mileageAccount = account
            self.transactions = account.transactions.sorted { $0.date > $1.date }
            self.flightGoals = account.flightGoals
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
        
        // 如果沒有信用卡，創建預設的國泰世華四張卡
        if creditCards.isEmpty {
            let cards = [
                CreditCardRule.cathayWorldCard(),
                CreditCardRule.cathayTitaniumCard(),
                CreditCardRule.cathayPlatinumCard(),
                CreditCardRule.cathayMilesCard()
            ]
            for card in cards {
                context.insert(card)
                creditCards.append(card)
            }
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
        account.transactions.append(transaction)
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
        
        context.insert(goal)
        account.flightGoals.append(goal)
        
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
    
    // 刪除交易
    func deleteTransaction(_ transaction: Transaction) {
        guard let context = modelContext, let account = mileageAccount else { return }
        
        // 從哩程帳戶減去該交易的哩程
        account.updateMiles(amount: -transaction.earnedMiles, date: transaction.date)
        
        // 從陣列中移除
        if let index = account.transactions.firstIndex(where: { $0.id == transaction.id }) {
            account.transactions.remove(at: index)
        }
        
        // 從資料庫刪除
        context.delete(transaction)
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
    
    // 取得本月交易統計
    func monthlyStats() -> (totalAmount: Decimal, totalMiles: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        let monthTransactions = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        
        let totalAmount = monthTransactions.reduce(Decimal(0)) { $0 + $1.amount }
        let totalMiles = monthTransactions.reduce(0) { $0 + $1.earnedMiles }
        
        return (totalAmount, totalMiles)
    }
}
