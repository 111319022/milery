import Testing
import Foundation
@testable import milery

@Suite("MileageAccount Tests")
struct MileageAccountTests {
    
    private let calendar = Calendar.current
    
    // MARK: - expiryDate
    
    @Test("Expiry date is 18 months after last activity when no transactions")
    func expiryDateNoTransactions() {
        let account = MileageAccount(totalMiles: 1000, lastActivityDate: makeDate(2025, 1, 15))
        let expiry = account.expiryDate()
        
        // 18 months from Jan 2025 = July 2026, last day = July 31
        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 31)
    }
    
    @Test("Expiry date uses end of day (23:59:59)")
    func expiryDateEndOfDay() {
        let account = MileageAccount(totalMiles: 500, lastActivityDate: makeDate(2025, 6, 1))
        let expiry = account.expiryDate()
        
        let hour = calendar.component(.hour, from: expiry)
        let minute = calendar.component(.minute, from: expiry)
        let second = calendar.component(.second, from: expiry)
        #expect(hour == 23)
        #expect(minute == 59)
        #expect(second == 59)
    }
    
    @Test("Expiry from December goes to June next year + 1")
    func expiryDateDecemberCrossYear() {
        let account = MileageAccount(totalMiles: 100, lastActivityDate: makeDate(2025, 12, 25))
        let expiry = account.expiryDate()
        
        // 18 months from Dec 2025 = June 2027, last day = June 30
        let components = calendar.dateComponents([.year, .month, .day], from: expiry)
        #expect(components.year == 2027)
        #expect(components.month == 6)
        #expect(components.day == 30)
    }
    
    // MARK: - updateMiles
    
    @Test("updateMiles adds to totalMiles")
    func updateMilesAdds() {
        let account = MileageAccount(totalMiles: 1000)
        account.updateMiles(amount: 500)
        #expect(account.totalMiles == 1500)
    }
    
    @Test("updateMiles with negative amount decreases totalMiles")
    func updateMilesSubtracts() {
        let account = MileageAccount(totalMiles: 1000)
        account.updateMiles(amount: -300)
        #expect(account.totalMiles == 700)
    }
    
    @Test("updateMiles updates lastActivityDate")
    func updateMilesUpdatesDate() {
        let oldDate = makeDate(2024, 1, 1)
        let newDate = makeDate(2025, 6, 15)
        let account = MileageAccount(totalMiles: 0, lastActivityDate: oldDate)
        account.updateMiles(amount: 100, date: newDate)
        #expect(account.lastActivityDate == newDate)
    }
    
    // MARK: - latestActivityMonthText
    
    @Test("No transactions returns 'No Record'")
    func noTransactionsText() {
        let account = MileageAccount()
        // transactions is empty by default
        #expect(account.latestActivityMonthText() == "No Record")
    }
    
    // MARK: - Helper
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
