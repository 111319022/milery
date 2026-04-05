import Foundation
import SwiftUI

/// 台新國泰航空聯名卡定義
struct TaishinCathayCard: CardBrandDefinition {
    let brandID: CardBrand = .taishinCathay
    let displayName = "國泰航空聯名卡"
    let bankName = "台新銀行"
    let defaultTierID = "世界卡"
    let defaultIsActive = false
    let defaultBillingDay = 15
    let defaultRoundingMode: RoundingMode = .down
    let birthdayMultiplier: Decimal = 1.0
    let usesCardImage = true
    
    // MARK: - 等級定義
    
    let tiers: [CardTierDefinition] = [
        CardTierDefinition(
            id: "世界卡",
            rates: ResolvedCardRates(
                baseRate: 22,
                secondaryRate: 15,
                tertiaryRate: 5,
                birthdayMultiplier: 1.0,
                annualFee: 20000,
                annualCap: 0
            ),
            gradient: [
                Color(red: 0.08, green: 0.08, blue: 0.10),
                Color(red: 0.25, green: 0.25, blue: 0.30)
            ],
            cardImageName: "Taishin_World",
            benefits: [
                "國內消費 22 元 1 哩",
                "國外消費 15 元 1 哩",
                "指定消費 5 元 1 哩",
            ]
        ),
        CardTierDefinition(
            id: "翱翔鈦金卡",
            rates: ResolvedCardRates(
                baseRate: 25,
                secondaryRate: 15,
                tertiaryRate: 5,
                birthdayMultiplier: 1.0,
                annualFee: 2400,
                annualCap: 0
            ),
            gradient: [
                Color(red: 0.05, green: 0.25, blue: 0.15),
                Color(red: 0.15, green: 0.5, blue: 0.35)
            ],
            cardImageName: "Taishin_FlyTitanium",
            benefits: [
                "國內消費 25 元 1 哩",
                "國外消費 15 元 1 哩",
                "指定消費 5 元 1 哩",
            ]
        ),
        CardTierDefinition(
            id: "鈦金卡",
            rates: ResolvedCardRates(
                baseRate: 30,
                secondaryRate: 25,
                tertiaryRate: 5,
                birthdayMultiplier: 1.0,
                annualFee: 0,
                annualCap: 0
            ),
            gradient: [
                Color(red: 0.3, green: 0.35, blue: 0.38),
                Color(red: 0.5, green: 0.55, blue: 0.58)
            ],
            cardImageName: "Taishin_Titanium",
            benefits: [
                "國內消費 30 元 1 哩",
                "國外消費 25 元 1 哩",
                "指定消費 5 元 1 哩",
            ]
        ),
    ]
    
    // MARK: - 指定消費子類別（越飛越有哩）
    
    static let designatedCategories: [CardSpendingCategory] = [
        CardSpendingCategory(id: "海外實體商店", icon: "globe.asia.australia.fill", description: "海外實體商店消費"),
        CardSpendingCategory(id: "指定訂房網站", icon: "bed.double.fill", description: "Agoda、Booking.com、Expedia、Hotels.com"),
        CardSpendingCategory(id: "旅遊體驗", icon: "figure.hiking", description: "KKday、Klook 客路"),
        CardSpendingCategory(id: "免稅商店", icon: "bag.fill", description: "昇恆昌、采盟、海外實體免稅商店"),
    ]
    
    // MARK: - MileageSource 對應
    
    var sourceMappings: [CardMileageSourceMapping] {
        [
            // 一般消費：不自動選卡
            CardMileageSourceMapping(
                source: .cardGeneral,
                autoSelectBrand: false,
                rateKeyPath: .base,
                requiresSubcategory: false,
                subcategories: [],
                subcategorySectionTitle: "",
                infoPopoverTitle: "",
                infoPopoverSubtitle: ""
            ),
            // 國外一般消費：自動選台新卡
            CardMileageSourceMapping(
                source: .taishinOverseas,
                autoSelectBrand: true,
                rateKeyPath: .secondary,
                requiresSubcategory: false,
                subcategories: [],
                subcategorySectionTitle: "",
                infoPopoverTitle: "",
                infoPopoverSubtitle: ""
            ),
            // 越飛越有哩：自動選台新卡，需子類別
            CardMileageSourceMapping(
                source: .taishinDesignated,
                autoSelectBrand: true,
                rateKeyPath: .tertiary,
                requiresSubcategory: true,
                subcategories: Self.designatedCategories,
                subcategorySectionTitle: "指定消費類別",
                infoPopoverTitle: "越飛越有哩",
                infoPopoverSubtitle: "以下指定消費類別可享 5 元 1 哩回饋"
            ),
        ]
    }
    
    // MARK: - 費率欄位佈局
    
    var rateSlots: [CardRateSlot] {
        let designatedMapping = sourceMappings.first { $0.source == .taishinDesignated }
        return [
            CardRateSlot(title: "國內消費", rateKeyPath: .base),
            CardRateSlot(title: "國外消費", rateKeyPath: .secondary),
            CardRateSlot(title: "指定消費", rateKeyPath: .tertiary, showInfoButton: true, infoSourceMapping: designatedMapping),
            CardRateSlot(title: "年費", isAnnualFee: true),
        ]
    }
    
    // MARK: - 工廠方法
    
    func makeCard(tierID: String) -> CreditCardRule {
        let tierDef = tier(for: tierID) ?? tiers[0]
        let card = CreditCardRule(
            cardName: "\(displayName) \(tierDef.id)",
            bankName: bankName,
            baseRate: tierDef.rates.baseRate,
            acceleratorRate: tierDef.rates.secondaryRate,
            specialMerchantRate: tierDef.rates.tertiaryRate,
            birthdayMultiplier: tierDef.rates.birthdayMultiplier,
            roundingMode: defaultRoundingMode,
            billingDay: defaultBillingDay,
            annualFee: tierDef.rates.annualFee,
            cardBrand: brandID
        )
        card.cardTierRaw = tierDef.id
        return card
    }
}
