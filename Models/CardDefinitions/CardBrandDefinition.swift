import Foundation
import SwiftUI

// MARK: - 信用卡品牌定義 Protocol

/// 每家銀行的信用卡定義實作此 Protocol，包含所有等級、費率、來源對應、UI 資訊。
/// 新增一張信用卡只需 conform 此 Protocol，並在 CardBrandRegistry 註冊。
protocol CardBrandDefinition {
    /// 品牌識別 ID（對應 CardBrand enum）
    var brandID: CardBrand { get }
    /// 品牌顯示名稱（例如：「國泰世華亞萬聯名卡」）
    var displayName: String { get }
    /// 銀行名稱（例如：「國泰世華銀行」）
    var bankName: String { get }
    /// 預設等級 ID（首次啟用時使用）
    var defaultTierID: String { get }
    /// 預設是否啟用
    var defaultIsActive: Bool { get }
    /// 預設結帳日
    var defaultBillingDay: Int { get }
    /// 進位方式
    var defaultRoundingMode: RoundingMode { get }
    /// 生日月倍數
    var birthdayMultiplier: Decimal { get }
    
    /// 所有卡片等級定義
    var tiers: [CardTierDefinition] { get }
    /// 此品牌的 MileageSource 對應
    var sourceMappings: [CardMileageSourceMapping] { get }
    /// 費率顯示欄位佈局（用於 CreditCardPageView）
    var rateSlots: [CardRateSlot] { get }
    
    /// 使用卡面圖片（true = 用 Image 顯示卡面圖，false = 用漸層色卡面）
    var usesCardImage: Bool { get }
    
    /// 工廠方法：建立 CreditCardRule（in-memory，不存 SwiftData）
    func makeCard(tierID: String) -> CreditCardRule
}

extension CardBrandDefinition {
    /// 根據 tierID 找到對應的等級定義
    func tier(for tierID: String) -> CardTierDefinition? {
        tiers.first { $0.id == tierID }
    }
}

// MARK: - 卡片等級定義

/// 單一等級的完整定義（費率、漸層色、卡面圖、benefits）
struct CardTierDefinition: Identifiable {
    let id: String                    // 等級原始值（例如 "世界卡"）
    let rates: ResolvedCardRates      // 該等級的所有費率
    let gradient: [Color]             // 卡面漸層色（2 色）
    let cardImageName: String?        // 卡面圖片名稱（若有）
    let benefits: [String]            // 卡片權益列表
}

// MARK: - 費率結構

/// 解析後的完整費率（從等級定義取得）
struct ResolvedCardRates {
    let baseRate: Decimal             // 基礎消費費率（元/哩）
    let secondaryRate: Decimal        // 第二費率（國泰: 加速器, 台新: 國外消費）
    let tertiaryRate: Decimal         // 第三費率（國泰: 同加速器, 台新: 指定消費）
    let birthdayMultiplier: Decimal   // 生日月倍數
    let annualFee: Int                // 年費
    let annualCap: Int                // 年度加速上限（0 = 無上限）
}

// MARK: - 消費子類別

/// 統一的消費子類別定義（取代 AcceleratorCategory + TaishinDesignatedCategory）
struct CardSpendingCategory: Identifiable, Hashable {
    let id: String          // 原始值（例如 "海外", "海外實體商店"）
    let icon: String        // SF Symbol 名稱
    let description: String // 說明文字
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CardSpendingCategory, rhs: CardSpendingCategory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MileageSource 對應

/// 定義一個 MileageSource 如何對應到卡片品牌
struct CardMileageSourceMapping {
    let source: MileageSource          // 哩程來源
    let autoSelectBrand: Bool          // 選擇此來源時是否自動選擇該品牌的卡
    let rateKeyPath: RateKeyPath       // 使用哪個費率
    let requiresSubcategory: Bool      // 是否需要選擇子類別
    let subcategories: [CardSpendingCategory]  // 子類別清單（空 = 不需要）
    let subcategorySectionTitle: String // 子類別區塊標題（例如「加速器類別」）
    let infoPopoverTitle: String       // Info Popover 標題
    let infoPopoverSubtitle: String    // Info Popover 副標題
    let supportsBirthdayBonus: Bool    // 生日月是否適用加碼
    
    enum RateKeyPath {
        case base
        case secondary
        case tertiary
    }
    
    init(source: MileageSource,
         autoSelectBrand: Bool,
         rateKeyPath: RateKeyPath,
         requiresSubcategory: Bool,
         subcategories: [CardSpendingCategory],
         subcategorySectionTitle: String,
         infoPopoverTitle: String,
         infoPopoverSubtitle: String,
         supportsBirthdayBonus: Bool = false) {
        self.source = source
        self.autoSelectBrand = autoSelectBrand
        self.rateKeyPath = rateKeyPath
        self.requiresSubcategory = requiresSubcategory
        self.subcategories = subcategories
        self.subcategorySectionTitle = subcategorySectionTitle
        self.infoPopoverTitle = infoPopoverTitle
        self.infoPopoverSubtitle = infoPopoverSubtitle
        self.supportsBirthdayBonus = supportsBirthdayBonus
    }
}

// MARK: - 費率顯示欄位

/// CreditCardPageView 中費率區的欄位定義
struct CardRateSlot {
    let title: String                      // 欄位標題（例如「一般消費」）
    let rateKeyPath: CardMileageSourceMapping.RateKeyPath  // 對應哪個費率
    let showInfoButton: Bool               // 是否顯示 info 按鈕
    let isAnnualFee: Bool                  // 是否為年費欄位
    let infoSourceMapping: CardMileageSourceMapping?  // info 按鈕對應的 sourceMapping（用於 popover）
    
    init(title: String,
         rateKeyPath: CardMileageSourceMapping.RateKeyPath = .base,
         showInfoButton: Bool = false,
         isAnnualFee: Bool = false,
         infoSourceMapping: CardMileageSourceMapping? = nil) {
        self.title = title
        self.rateKeyPath = rateKeyPath
        self.showInfoButton = showInfoButton
        self.isAnnualFee = isAnnualFee
        self.infoSourceMapping = infoSourceMapping
    }
}
