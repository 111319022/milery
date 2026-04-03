import Foundation
import SwiftData

// 信用卡品牌
enum CardBrand: String, Codable, CaseIterable {
    case cathayUnitedBank = "cathayUnitedBank"
    case taishinCathay = "taishinCathay"
    
    var displayName: String {
        CardBrandRegistry.definition(for: self)?.displayName ?? rawValue
    }
    
    var bankName: String {
        CardBrandRegistry.definition(for: self)?.bankName ?? rawValue
    }
}

@Model
final class CreditCardRule {
    var id: UUID = UUID()
    var cardName: String = ""
    var bankName: String = ""
    var isActive: Bool = true
    
    // 卡片品牌與等級
    var cardBrandRaw: String = "cathayUnitedBank"
    var cardTierRaw: String = ""
    
    // 基礎回饋率 (多少元 = 1 哩)
    @Attribute(originalName: "baseRate") var baseRateValue: Double = 30
    
    // 第二費率（國泰: 加速器, 台新: 國外消費）
    @Attribute(originalName: "acceleratorRate") var acceleratorRateValue: Double = 30
    
    // 第三費率（國泰: 同加速器, 台新: 指定消費）
    @Attribute(originalName: "specialMerchantRate") var specialMerchantRateValue: Double = 30
    
    // 生日當月加碼倍數
    @Attribute(originalName: "birthdayMultiplier") var birthdayMultiplierValue: Double = 1.0
    
    // 進位方式
    @Attribute(originalName: "roundingMode") var roundingModeRaw: String = RoundingMode.down.rawValue
    
    // 每月結帳日
    var billingDay: Int = 1
    
    // 年費
    var annualFee: Int = 0

    var baseRate: Decimal {
        get { NSDecimalNumber(value: baseRateValue).decimalValue }
        set { baseRateValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    var acceleratorRate: Decimal {
        get { NSDecimalNumber(value: acceleratorRateValue).decimalValue }
        set { acceleratorRateValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    var specialMerchantRate: Decimal {
        get { NSDecimalNumber(value: specialMerchantRateValue).decimalValue }
        set { specialMerchantRateValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    var birthdayMultiplier: Decimal {
        get { NSDecimalNumber(value: birthdayMultiplierValue).decimalValue }
        set { birthdayMultiplierValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    var roundingMode: RoundingMode {
        get { RoundingMode(rawValue: roundingModeRaw) ?? .down }
        set { roundingModeRaw = newValue.rawValue }
    }
    
    // Computed: 卡片品牌
    var cardBrand: CardBrand {
        get { CardBrand(rawValue: cardBrandRaw) ?? .cathayUnitedBank }
        set { cardBrandRaw = newValue.rawValue }
    }
    
    init(cardName: String,
         bankName: String,
         baseRate: Decimal = 30,
         acceleratorRate: Decimal = 30,
         specialMerchantRate: Decimal = 30,
         birthdayMultiplier: Decimal = 1.0,
         roundingMode: RoundingMode = .down,
         billingDay: Int = 1,
         annualFee: Int = 0,
         isActive: Bool = true,
         cardBrand: CardBrand = .cathayUnitedBank) {
        self.id = UUID()
        self.cardName = cardName
        self.bankName = bankName
        self.baseRateValue = NSDecimalNumber(decimal: baseRate).doubleValue
        self.acceleratorRateValue = NSDecimalNumber(decimal: acceleratorRate).doubleValue
        self.specialMerchantRateValue = NSDecimalNumber(decimal: specialMerchantRate).doubleValue
        self.birthdayMultiplierValue = NSDecimalNumber(decimal: birthdayMultiplier).doubleValue
        self.roundingModeRaw = roundingMode.rawValue
        self.billingDay = billingDay
        self.annualFee = annualFee
        self.isActive = isActive
        self.cardBrandRaw = cardBrand.rawValue
    }
    
    /// 通用切換等級方法：透過 Registry 查找費率並更新
    func updateTier(_ tierID: String) {
        guard let def = CardBrandRegistry.definition(for: cardBrand),
              let tierDef = def.tier(for: tierID) else { return }
        self.cardTierRaw = tierID
        self.cardName = "\(def.displayName) \(tierID)"
        self.baseRate = tierDef.rates.baseRate
        self.acceleratorRate = tierDef.rates.secondaryRate
        self.specialMerchantRate = tierDef.rates.tertiaryRate
        self.annualFee = tierDef.rates.annualFee
    }
    
    // 計算哩程（通用版 — 透過 Registry 查找費率）
    func calculateMiles(amount: Decimal,
                       source: MileageSource,
                       subcategoryID: String? = nil,
                       isBirthdayMonth: Bool = false) -> Int {
        let rate = CardBrandRegistry.rate(for: source, card: self)
        
        var miles = amount / rate
        
        // 生日當月加碼（僅限標記 supportsBirthdayBonus 的消費類型）
        if isBirthdayMonth, birthdayMultiplier > 1 {
            let sourceSupports = CardBrandRegistry.sourceSupportsBirthdayBonus(source, brand: cardBrand)
            if sourceSupports {
                miles *= birthdayMultiplier
            }
        }
        
        // 根據進位方式處理
        let handler: NSDecimalNumberHandler
        switch roundingMode {
        case .up:
            handler = NSDecimalNumberHandler(roundingMode: .up, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        case .down:
            handler = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        case .nearest:
            handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        }
        
        let milesNumber = NSDecimalNumber(decimal: miles)
        let roundedMiles = milesNumber.rounding(accordingToBehavior: handler) as Decimal
        
        return NSDecimalNumber(decimal: roundedMiles).intValue
    }
    
    /// 取得品牌定義
    var brandDefinition: CardBrandDefinition? {
        CardBrandRegistry.definition(for: cardBrand)
    }
    
    /// 取得當前等級定義
    var tierDefinition: CardTierDefinition? {
        brandDefinition?.tier(for: cardTierRaw)
    }
}

enum RoundingMode: String, Codable {
    case up = "無條件進位"
    case down = "無條件捨去"
    case nearest = "四捨五入"
}
