import Testing
import Foundation
@testable import milery

@Suite("CreditCardRule.calculateMiles Tests")
struct CreditCardRuleTests {
    
    // MARK: - Helper
    
    /// Create a Cathay United Bank 世界卡 for testing
    private func makeCathayWorldCard() -> CreditCardRule {
        CathayUnitedBankCard().makeCard(tierID: "世界卡")
    }
    
    /// Create a Taishin 鈦金卡 for testing
    private func makeTaishinTitaniumCard() -> CreditCardRule {
        TaishinCathayCard().makeCard(tierID: "鈦金卡")
    }
    
    // MARK: - Basic calculation (Cathay United Bank)
    
    @Test("世界卡 general: 22000 / 22 = 1000 miles (round down)")
    func cathayWorldGeneralBasic() {
        let card = makeCathayWorldCard()
        let miles = card.calculateMiles(amount: 22000, source: .cardGeneral)
        #expect(miles == 1000)
    }
    
    @Test("世界卡 general: 100 / 22 = 4 miles (round down)")
    func cathayWorldGeneralSmall() {
        let card = makeCathayWorldCard()
        let miles = card.calculateMiles(amount: 100, source: .cardGeneral)
        // 100 / 22 = 4.545... → floor = 4
        #expect(miles == 4)
    }
    
    @Test("世界卡 accelerator: 10000 / 10 = 1000 miles")
    func cathayWorldAccelerator() {
        let card = makeCathayWorldCard()
        let miles = card.calculateMiles(amount: 10000, source: .cardAccelerator)
        #expect(miles == 1000)
    }
    
    @Test("世界卡 accelerator: 155 / 10 = 15 miles (round down)")
    func cathayWorldAcceleratorRoundDown() {
        let card = makeCathayWorldCard()
        let miles = card.calculateMiles(amount: 155, source: .cardAccelerator)
        // 155 / 10 = 15.5 → floor = 15
        #expect(miles == 15)
    }
    
    @Test("Zero amount yields zero miles")
    func zeroAmount() {
        let card = makeCathayWorldCard()
        let miles = card.calculateMiles(amount: 0, source: .cardGeneral)
        #expect(miles == 0)
    }
    
    // MARK: - Rounding modes
    
    @Test("Round up: 100 / 22 = 5 (ceiling)")
    func roundUp() {
        let card = makeCathayWorldCard()
        card.roundingMode = .up
        let miles = card.calculateMiles(amount: 100, source: .cardGeneral)
        // 100 / 22 = 4.545... → ceil = 5
        #expect(miles == 5)
    }
    
    @Test("Round nearest: 100 / 22 = 5 (rounds to nearest)")
    func roundNearest() {
        let card = makeCathayWorldCard()
        card.roundingMode = .nearest
        let miles = card.calculateMiles(amount: 100, source: .cardGeneral)
        // 100 / 22 = 4.545... → round = 5
        #expect(miles == 5)
    }
    
    @Test("Round nearest: 110 / 22 = 5 (exact, no rounding needed)")
    func roundNearestExact() {
        let card = makeCathayWorldCard()
        card.roundingMode = .nearest
        let miles = card.calculateMiles(amount: 110, source: .cardGeneral)
        // 110 / 22 = 5.0 → exactly 5
        #expect(miles == 5)
    }
    
    @Test("Round down is the default")
    func roundDownDefault() {
        let card = makeCathayWorldCard()
        #expect(card.roundingMode == .down)
    }
    
    // MARK: - Birthday multiplier (Cathay accelerator supports it)
    
    @Test("Birthday month doubles accelerator miles for Cathay card")
    func birthdayMonthAccelerator() {
        let card = makeCathayWorldCard()
        // birthdayMultiplier = 2.0 for Cathay
        let normalMiles = card.calculateMiles(amount: 10000, source: .cardAccelerator, isBirthdayMonth: false)
        let birthdayMiles = card.calculateMiles(amount: 10000, source: .cardAccelerator, isBirthdayMonth: true)
        // 10000 / 10 = 1000, birthday = 1000 * 2 = 2000
        #expect(normalMiles == 1000)
        #expect(birthdayMiles == 2000)
    }
    
    @Test("Birthday month does NOT double general miles for Cathay card")
    func birthdayMonthGeneral() {
        let card = makeCathayWorldCard()
        let normalMiles = card.calculateMiles(amount: 22000, source: .cardGeneral, isBirthdayMonth: false)
        let birthdayMiles = card.calculateMiles(amount: 22000, source: .cardGeneral, isBirthdayMonth: true)
        // cardGeneral does not support birthday bonus for Cathay
        #expect(normalMiles == birthdayMiles)
    }
    
    @Test("Taishin card has no birthday bonus (multiplier = 1.0)")
    func taishinNoBirthdayBonus() {
        let card = makeTaishinTitaniumCard()
        let normalMiles = card.calculateMiles(amount: 3000, source: .cardGeneral, isBirthdayMonth: false)
        let birthdayMiles = card.calculateMiles(amount: 3000, source: .cardGeneral, isBirthdayMonth: true)
        #expect(normalMiles == birthdayMiles)
    }
    
    // MARK: - Taishin card rates
    
    @Test("Taishin 鈦金卡 general: 3000 / 30 = 100 miles")
    func taishinTitaniumGeneral() {
        let card = makeTaishinTitaniumCard()
        let miles = card.calculateMiles(amount: 3000, source: .cardGeneral)
        #expect(miles == 100)
    }
    
    @Test("Taishin 鈦金卡 overseas: 2500 / 25 = 100 miles")
    func taishinTitaniumOverseas() {
        let card = makeTaishinTitaniumCard()
        let miles = card.calculateMiles(amount: 2500, source: .taishinOverseas)
        #expect(miles == 100)
    }
    
    @Test("Taishin 鈦金卡 designated: 500 / 5 = 100 miles")
    func taishinTitaniumDesignated() {
        let card = makeTaishinTitaniumCard()
        let miles = card.calculateMiles(amount: 500, source: .taishinDesignated)
        #expect(miles == 100)
    }
    
    // MARK: - Decimal precision
    
    @Test("Decimal precision: large amount does not lose precision")
    func decimalPrecisionLargeAmount() {
        let card = makeCathayWorldCard()
        // 999999 / 22 = 45454.5 → floor = 45454
        let miles = card.calculateMiles(amount: 999999, source: .cardGeneral)
        #expect(miles == 45454)
    }
    
    @Test("Decimal rate stored and read back correctly")
    func decimalRateRoundTrip() {
        let card = makeCathayWorldCard()
        card.baseRate = Decimal(string: "22")!
        #expect(card.baseRate == 22)
        
        card.baseRate = Decimal(string: "10.5")!
        #expect(card.baseRate == Decimal(string: "10.5"))
    }
    
    // MARK: - Tier updates
    
    @Test("updateTier changes rates to match tier definition")
    func updateTierChangesRates() {
        let card = makeCathayWorldCard()
        #expect(card.baseRate == 22)
        
        card.updateTier("白金卡")
        #expect(card.baseRate == 30)
        #expect(card.acceleratorRate == 15)
        #expect(card.annualFee == 500)
    }
    
    @Test("updateTier to 里享卡: all rates = 30")
    func updateTierMilesCard() {
        let card = makeCathayWorldCard()
        card.updateTier("里享卡")
        #expect(card.baseRate == 30)
        #expect(card.acceleratorRate == 30)
        #expect(card.specialMerchantRate == 30)
        #expect(card.annualFee == 288)
    }
}
