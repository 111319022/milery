//
//  CreditCardRule.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import SwiftData

@Model
final class CreditCardRule {
    var id: UUID
    var cardName: String
    var bankName: String
    var isActive: Bool
    
    // 基礎回饋率 (多少元 = 1 哩)
    var baseRate: Decimal // 例如：30 表示 30元/哩
    
    // 加速器回饋率（哩程加速器消費適用）
    var acceleratorRate: Decimal // 例如：10 表示 10元/哩
    
    // 特約商店回饋率
    var specialMerchantRate: Decimal // 例如：10 表示 10元/哩
    
    // 生日當月加碼倍數
    var birthdayMultiplier: Decimal // 例如：2.0 表示雙倍
    
    // 進位方式
    var roundingMode: RoundingMode
    
    // 每月結帳日
    var billingDay: Int
    
    // 年費
    var annualFee: Int
    
    init(cardName: String,
         bankName: String,
         baseRate: Decimal = 30,
         acceleratorRate: Decimal = 30,
         specialMerchantRate: Decimal = 30,
         birthdayMultiplier: Decimal = 1.0,
         roundingMode: RoundingMode = .down,
         billingDay: Int = 1,
         annualFee: Int = 0,
         isActive: Bool = true) {
        self.id = UUID()
        self.cardName = cardName
        self.bankName = bankName
        self.baseRate = baseRate
        self.acceleratorRate = acceleratorRate
        self.specialMerchantRate = specialMerchantRate
        self.birthdayMultiplier = birthdayMultiplier
        self.roundingMode = roundingMode
        self.billingDay = billingDay
        self.annualFee = annualFee
        self.isActive = isActive
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
        case .titanium: return 5000
        case .platinum: return 3000
        case .miles: return 2000
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
            annualFee: 2000
        )
    }
}
