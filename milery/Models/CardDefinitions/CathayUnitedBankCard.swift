import Foundation
import SwiftUI

/// 國泰世華亞萬聯名卡定義
struct CathayUnitedBankCard: CardBrandDefinition {
    let brandID: CardBrand = .cathayUnitedBank
    let displayName = "亞洲萬里通聯名卡"
    let bankName = "國泰世華銀行"
    let defaultTierID = "世界卡"
    let defaultIsActive = true
    let defaultBillingDay = 20
    let defaultRoundingMode: RoundingMode = .down
    let birthdayMultiplier: Decimal = 2.0
    let usesCardImage = true
    
    // MARK: - 等級定義
    
    let tiers: [CardTierDefinition] = [
        CardTierDefinition(
            id: "世界卡",
            rates: ResolvedCardRates(
                baseRate: 22,
                secondaryRate: 10,
                tertiaryRate: 10,
                birthdayMultiplier: 2.0,
                annualFee: 8000,
                annualCap: 150000
            ),
            gradient: [
                Color(red: 0.12, green: 0.12, blue: 0.14),
                Color(red: 0.28, green: 0.28, blue: 0.32)
            ],
            cardImageName: "AM_World_360x277",
            benefits: [
                "一般消費 22 元 1 哩",
                "加速器消費 10 元 1 哩",
                "年度上限 15 萬哩",
                "生日月哩程雙倍",
                "機場接送服務"
            ]
        ),
        CardTierDefinition(
            id: "鈦商卡",
            rates: ResolvedCardRates(
                baseRate: 25,
                secondaryRate: 10,
                tertiaryRate: 10,
                birthdayMultiplier: 2.0,
                annualFee: 1800,
                annualCap: 100000
            ),
            gradient: [
                Color(red: 0.38, green: 0.38, blue: 0.42),
                Color(red: 0.58, green: 0.58, blue: 0.62)
            ],
            cardImageName: "AM_TitaniumBusinessV2_360x277",
            benefits: [
                "一般消費 25 元 1 哩",
                "加速器消費 10 元 1 哩",
                "年度上限 10 萬哩",
                "生日月哩程雙倍",
                "商務優惠"
            ]
        ),
        CardTierDefinition(
            id: "白金卡",
            rates: ResolvedCardRates(
                baseRate: 30,
                secondaryRate: 15,
                tertiaryRate: 15,
                birthdayMultiplier: 2.0,
                annualFee: 500,
                annualCap: 50000
            ),
            gradient: [
                Color(red: 0.0, green: 0.18, blue: 0.38),
                Color(red: 0.18, green: 0.45, blue: 0.68)
            ],
            cardImageName: "AM_Platinum_360x277",
            benefits: [
                "一般消費 30 元 1 哩",
                "加速器消費 15 元 1 哩",
                "年度上限 5 萬哩",
                "生日月哩程雙倍"
            ]
        ),
        CardTierDefinition(
            id: "里享卡",
            rates: ResolvedCardRates(
                baseRate: 30,
                secondaryRate: 30,
                tertiaryRate: 30,
                birthdayMultiplier: 2.0,
                annualFee: 288,
                annualCap: 0
            ),
            gradient: [
                Color(red: 0.38, green: 0.08, blue: 0.28),
                Color(red: 0.75, green: 0.28, blue: 0.48)
            ],
            cardImageName: "AM_Miles_360x277",
            benefits: [
                "所有消費 30 元 1 哩",
                "無加速器優惠",
                "無年度上限",
                "生日月哩程雙倍"
            ]
        ),
    ]
    
    // MARK: - 加速器子類別
    
    static let acceleratorCategories: [CardSpendingCategory] = [
        CardSpendingCategory(id: "海外", icon: "globe.asia.australia.fill", description: "海外消費（含線上外幣交易）"),
        CardSpendingCategory(id: "旅遊交通", icon: "airplane.departure", description: "國內外航空、飯店、旅行社、租車"),
        CardSpendingCategory(id: "日常消費", icon: "cart.fill", description: "超市、量販、加油、電信費"),
        CardSpendingCategory(id: "休閒娛樂", icon: "theatermasks.fill", description: "電影院、KTV、健身房、遊樂園"),
    ]
    
    // MARK: - MileageSource 對應
    
    var sourceMappings: [CardMileageSourceMapping] {
        [
            // 一般消費：不自動選卡（多張卡共用此來源）
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
            // 哩程加速器：自動選國泰卡，需要選擇子類別，支援生日月雙倍
            CardMileageSourceMapping(
                source: .cardAccelerator,
                autoSelectBrand: true,
                rateKeyPath: .secondary,
                requiresSubcategory: true,
                subcategories: Self.acceleratorCategories,
                subcategorySectionTitle: "加速器類別",
                infoPopoverTitle: "四大哩程加速器",
                infoPopoverSubtitle: "以下類別消費可享加速哩程回饋",
                supportsBirthdayBonus: true
            ),
        ]
    }
    
    // MARK: - 費率欄位佈局
    
    var rateSlots: [CardRateSlot] {
        let accelMapping = sourceMappings.first { $0.source == .cardAccelerator }
        return [
            CardRateSlot(title: "一般消費", rateKeyPath: .base),
            CardRateSlot(title: "加速消費", rateKeyPath: .secondary, showInfoButton: true, infoSourceMapping: accelMapping),
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
