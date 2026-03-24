import Foundation
import SwiftData

// 信用卡品牌
enum CardBrand: String, Codable, CaseIterable {
    case cathayUnitedBank = "cathayUnitedBank"
    case taishinCathay = "taishinCathay"
    
    var displayName: String {
        switch self {
        case .cathayUnitedBank: return "國泰世華亞萬聯名卡"
        case .taishinCathay: return "台新國泰航空聯名卡"
        }
    }
    
    var bankName: String {
        switch self {
        case .cathayUnitedBank: return "國泰世華銀行"
        case .taishinCathay: return "台新銀行"
        }
    }
    
    var hasTiers: Bool {
        switch self {
        case .cathayUnitedBank: return true
        case .taishinCathay: return false
        }
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
    var baseRateValue: Double = 30 // 持久化用：CloudKit 友善型別
    
    // 加速器回饋率（哩程加速器消費適用）
    var acceleratorRateValue: Double = 30 // 持久化用：CloudKit 友善型別
    
    // 特約商店回饋率
    var specialMerchantRateValue: Double = 30 // 持久化用：CloudKit 友善型別
    
    // 生日當月加碼倍數
    var birthdayMultiplierValue: Double = 1.0 // 持久化用：CloudKit 友善型別
    
    // 進位方式
    var roundingModeRaw: String = RoundingMode.down.rawValue
    
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
    
    // Computed: 國泰卡等級（台新卡回傳 nil）
    var cathayTier: CathayCardTier? {
        get {
            guard cardBrand == .cathayUnitedBank, !cardTierRaw.isEmpty else { return nil }
            return CathayCardTier(rawValue: cardTierRaw)
        }
        set {
            cardTierRaw = newValue?.rawValue ?? ""
        }
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
         cardBrand: CardBrand = .cathayUnitedBank,
         cathayTier: CathayCardTier? = nil) {
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
        self.cardTierRaw = cathayTier?.rawValue ?? ""
    }
    
    /// 切換國泰卡等級，自動更新所有費率
    func updateTier(_ tier: CathayCardTier) {
        self.cathayTier = tier
        self.cardName = "國泰世華亞萬聯名卡 \(tier.rawValue)"
        self.baseRate = tier.baseRate
        self.acceleratorRate = tier.acceleratorRate
        self.specialMerchantRate = tier.acceleratorRate
        self.annualFee = tier.annualFee
    }
    
    // 計算哩程（新版 - 支援加速器）
    func calculateMiles(amount: Decimal, 
                       source: MileageSource,
                       acceleratorCategory: AcceleratorCategory? = nil,
                       isBirthdayMonth: Bool = false) -> Int {
        var rate: Decimal
        
        // 根據來源和加速器類別決定費率
        if source == .cardAccelerator, acceleratorCategory != nil {
            // 使用加速器費率
            rate = acceleratorRate
        } else if source == .specialMerchant {
            rate = specialMerchantRate
        } else {
            rate = baseRate
        }
        
        var miles = amount / rate
        
        // 生日當月加碼
        if isBirthdayMonth {
            miles *= birthdayMultiplier
        }
        
        // 根據進位方式處理
        let roundedMiles: Decimal
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
        roundedMiles = milesNumber.rounding(accordingToBehavior: handler) as Decimal
        
        return NSDecimalNumber(decimal: roundedMiles).intValue
    }
}

enum RoundingMode: String, Codable {
    case up = "無條件進位"
    case down = "無條件捨去"
    case nearest = "四捨五入"
}

// 國泰世華亞萬卡等級
enum CathayCardTier: String, Codable, CaseIterable {
    case world = "世界卡"
    case titanium = "鈦商卡"
    case platinum = "白金卡"
    case miles = "里享卡"
    
    var baseRate: Decimal {
        switch self {
        case .world: return 22
        case .titanium: return 25
        case .platinum: return 30
        case .miles: return 30
        }
    }
    
    var acceleratorRate: Decimal {
        switch self {
        case .world: return 10
        case .titanium: return 10
        case .platinum: return 15
        case .miles: return 30 // 無加速
        }
    }
    
    var annualCap: Int {
        switch self {
        case .world: return 150000
        case .titanium: return 100000
        case .platinum: return 50000
        case .miles: return 0 // 無上限
        }
    }
    
    var annualFee: Int {
        switch self {
        case .world: return 8000
        case .titanium: return 1800
        case .platinum: return 500
        case .miles: return 288
        }
    }
    
    var cardImageName: String {
        switch self {
        case .world: return "AM_World_360x277"
        case .titanium: return "AM_TitaniumBusinessV2_360x277"
        case .platinum: return "AM_Platinum_360x277"
        case .miles: return "AM_Miles_360x277"
        }
    }
    
    var benefits: [String] {
        switch self {
        case .world:
            return [
                "一般消費 22 元 1 哩",
                "加速器消費 10 元 1 哩",
                "年度上限 15 萬哩",
                "生日月哩程雙倍",
                "機場接送服務"
            ]
        case .titanium:
            return [
                "一般消費 25 元 1 哩",
                "加速器消費 10 元 1 哩",
                "年度上限 10 萬哩",
                "生日月哩程雙倍",
                "商務優惠"
            ]
        case .platinum:
            return [
                "一般消費 30 元 1 哩",
                "加速器消費 15 元 1 哩",
                "年度上限 5 萬哩",
                "生日月哩程雙倍"
            ]
        case .miles:
            return [
                "所有消費 30 元 1 哩",
                "無加速器優惠",
                "無年度上限",
                "生日月哩程雙倍"
            ]
        }
    }
}

// 預設的信用卡規則
extension CreditCardRule {
    // 國泰世華亞萬聯名卡 - 世界卡
    static func cathayWorldCard() -> CreditCardRule {
        CreditCardRule(
            cardName: "國泰世華亞萬聯名卡 世界卡",
            bankName: "國泰世華銀行",
            baseRate: 22,
            acceleratorRate: 10,
            specialMerchantRate: 10,
            birthdayMultiplier: 2.0,
            roundingMode: .down,
            billingDay: 20,
            annualFee: 8000
        )
    }
    
    // 國泰世華亞萬聯名卡 - 鈦商卡
    static func cathayTitaniumCard() -> CreditCardRule {
        CreditCardRule(
            cardName: "國泰世華亞萬聯名卡 鈦商卡",
            bankName: "國泰世華銀行",
            baseRate: 25,
            acceleratorRate: 10,
            specialMerchantRate: 10,
            birthdayMultiplier: 2.0,
            roundingMode: .down,
            billingDay: 20,
            annualFee: 5000
        )
    }
    
    // 國泰世華亞萬聯名卡 - 白金卡
    static func cathayPlatinumCard() -> CreditCardRule {
        CreditCardRule(
            cardName: "國泰世華亞萬聯名卡 白金卡",
            bankName: "國泰世華銀行",
            baseRate: 30,
            acceleratorRate: 15,
            specialMerchantRate: 15,
            birthdayMultiplier: 2.0,
            roundingMode: .down,
            billingDay: 20,
            annualFee: 3000
        )
    }
    
    // 國泰世華亞萬聯名卡 - 里享卡
    static func cathayMilesCard() -> CreditCardRule {
        CreditCardRule(
            cardName: "國泰世華亞萬聯名卡 里享卡",
            bankName: "國泰世華銀行",
            baseRate: 30,
            acceleratorRate: 30,
            specialMerchantRate: 30,
            birthdayMultiplier: 2.0,
            roundingMode: .down,
            billingDay: 20,
            annualFee: 2000,
            cardBrand: .cathayUnitedBank,
            cathayTier: .miles
        )
    }
    
    // 整合版：國泰世華亞萬聯名卡（指定等級）
    static func cathayCard(tier: CathayCardTier = .world) -> CreditCardRule {
        CreditCardRule(
            cardName: "國泰世華亞萬聯名卡 \(tier.rawValue)",
            bankName: "國泰世華銀行",
            baseRate: tier.baseRate,
            acceleratorRate: tier.acceleratorRate,
            specialMerchantRate: tier.acceleratorRate,
            birthdayMultiplier: 2.0,
            roundingMode: .down,
            billingDay: 20,
            annualFee: tier.annualFee,
            cardBrand: .cathayUnitedBank,
            cathayTier: tier
        )
    }
    
    // 台新國泰航空聯名卡（佔位，計算規則待開發）
    static func taishinCathayCard() -> CreditCardRule {
        CreditCardRule(
            cardName: "台新國泰航空聯名卡",
            bankName: "台新銀行",
            baseRate: 30,
            acceleratorRate: 30,
            specialMerchantRate: 30,
            birthdayMultiplier: 1.0,
            roundingMode: .down,
            billingDay: 15,
            annualFee: 0,
            isActive: false,
            cardBrand: .taishinCathay,
            cathayTier: nil
        )
    }
}
