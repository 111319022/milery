import Foundation

/// 中央卡片註冊表：所有信用卡品牌定義的唯一入口。
/// 新增一張卡只需在 allDefinitions 中加一行。
enum CardBrandRegistry {
    
    /// 所有已註冊的信用卡品牌定義
    static let allDefinitions: [CardBrandDefinition] = [
        CathayUnitedBankCard(),
        TaishinCathayCard(),
    ]
    
    /// 根據 CardBrand 查找品牌定義
    static func definition(for brand: CardBrand) -> CardBrandDefinition? {
        allDefinitions.first { $0.brandID == brand }
    }
    
    /// 根據 MileageSource 找到擁有此來源的品牌定義（排除 .cardGeneral，因為多品牌共用）
    static func brandForSource(_ source: MileageSource) -> CardBrandDefinition? {
        guard source != .cardGeneral else { return nil }
        return allDefinitions.first { def in
            def.sourceMappings.contains { $0.source == source && $0.autoSelectBrand }
        }
    }
    
    /// 根據 MileageSource 找到對應的 sourceMapping
    static func sourceMapping(for source: MileageSource) -> CardMileageSourceMapping? {
        for def in allDefinitions {
            if let mapping = def.sourceMappings.first(where: { $0.source == source && ($0.autoSelectBrand || source == .cardGeneral) }) {
                return mapping
            }
        }
        return nil
    }
    
    /// 根據 MileageSource 找到需要子類別的 sourceMapping
    static func subcategoryMapping(for source: MileageSource) -> CardMileageSourceMapping? {
        for def in allDefinitions {
            if let mapping = def.sourceMappings.first(where: { $0.source == source && $0.requiresSubcategory }) {
                return mapping
            }
        }
        return nil
    }
    
    /// 根據 subcategoryID 在所有品牌中查找對應的 CardSpendingCategory
    static func spendingCategory(for subcategoryID: String) -> CardSpendingCategory? {
        for def in allDefinitions {
            for mapping in def.sourceMappings {
                if let cat = mapping.subcategories.first(where: { $0.id == subcategoryID }) {
                    return cat
                }
            }
        }
        return nil
    }
    
    /// 取得所有卡片品牌專屬的 MileageSource（根據已啟用的卡片過濾）
    static func cardSpecificSources(for activeCards: [CreditCardRule]) -> [MileageSource] {
        var sources: [MileageSource] = []
        let activeBrands = Set(activeCards.map { $0.cardBrand })
        
        for def in allDefinitions {
            guard activeBrands.contains(def.brandID) else { continue }
            for mapping in def.sourceMappings where mapping.source != .cardGeneral {
                if !sources.contains(mapping.source) {
                    sources.append(mapping.source)
                }
            }
        }
        return sources
    }
    
    /// 判斷某個 MileageSource 是否需要選擇信用卡
    static func sourceNeedsCard(_ source: MileageSource) -> Bool {
        // cardGeneral 和所有卡片品牌專屬來源都需要選擇信用卡
        if source == .cardGeneral { return true }
        return allDefinitions.contains { def in
            def.sourceMappings.contains { $0.source == source }
        }
    }
    
    /// 判斷某個 MileageSource 是否需要金額輸入（可自動換算哩程）
    static func sourceNeedsAmount(_ source: MileageSource) -> Bool {
        sourceNeedsCard(source)
    }
    
    /// 判斷某個 MileageSource 是否支援生日月加碼（依品牌的 sourceMapping 定義）
    static func sourceSupportsBirthdayBonus(_ source: MileageSource, brand: CardBrand) -> Bool {
        guard let def = definition(for: brand) else { return false }
        if let mapping = def.sourceMappings.first(where: { $0.source == source }) {
            return mapping.supportsBirthdayBonus
        }
        return false
    }
    
    /// 根據 MileageSource 和 CreditCardRule 取得對應的費率
    static func rate(for source: MileageSource, card: CreditCardRule) -> Decimal {
        guard let def = definition(for: card.cardBrand) else { return card.baseRate }
        if let mapping = def.sourceMappings.first(where: { $0.source == source }) {
            switch mapping.rateKeyPath {
            case .base: return card.baseRate
            case .secondary: return card.acceleratorRate
            case .tertiary: return card.specialMerchantRate
            }
        }
        return card.baseRate
    }
}
