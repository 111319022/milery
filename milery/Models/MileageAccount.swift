import Foundation
import SwiftData

@Model
final class MileageAccount {
    var totalMiles: Int = 0
    var lastActivityDate: Date = Date()
    var programID: UUID?
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account) var transactions: [Transaction]? = []
    @Relationship(deleteRule: .cascade, inverse: \FlightGoal.account) var flightGoals: [FlightGoal]? = []
    
    init(totalMiles: Int = 0, lastActivityDate: Date = Date()) {
        self.totalMiles = totalMiles
        self.lastActivityDate = lastActivityDate
    }
    
    // 更新哩程並更新最後活動日期
    func updateMiles(amount: Int, date: Date = Date()) {
        totalMiles += amount
        lastActivityDate = date
    }
    
    // 計算最近有記錄的月份(從交易記錄中取得)
    func latestTransactionMonth() -> Date? {
        guard let latestTransaction = (transactions ?? []).max(by: { $0.date < $1.date }) else {
            return nil
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: latestTransaction.date)
        return calendar.date(from: components)
    }
    
    // 計算哩程到期日(最近有記錄月份 + 18個月後的月底)
    func expiryDate() -> Date {
        let calendar = Calendar.current
        let baseDate: Date
        
        if let latestMonth = latestTransactionMonth() {
            baseDate = latestMonth
        } else {
            // 如果沒有交易記錄,使用最後活動日期
            baseDate = lastActivityDate
        }
        
        // 加18個月
        guard let eighteenMonthsLater = calendar.date(byAdding: .month, value: 18, to: baseDate) else {
            return Date()
        }
        
        // 取得該月的最後一天
        let components = calendar.dateComponents([.year, .month], from: eighteenMonthsLater)
        guard let firstDayOfMonth = calendar.date(from: components),
              let lastDayOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDayOfMonth) else {
            return eighteenMonthsLater
        }
        
        // 設置為當天的23:59:59
        let endOfDayComponents = DateComponents(
            year: calendar.component(.year, from: lastDayOfMonth),
            month: calendar.component(.month, from: lastDayOfMonth),
            day: calendar.component(.day, from: lastDayOfMonth),
            hour: 23,
            minute: 59,
            second: 59
        )
        
        return calendar.date(from: endOfDayComponents) ?? lastDayOfMonth
    }
    
    // 計算距離過期的天數
    func daysUntilExpiry() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate())
        return components.day ?? 0
    }
    
    // 取得最近有記錄月份的格式化文字
    func latestActivityMonthText() -> String {
        if let latestMonth = latestTransactionMonth() {
            return latestMonth.formatted(.dateTime.year().month().locale(Locale(identifier: "en")))
        } else {
            return "No Record"
        }
    }
}
