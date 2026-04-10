import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var date: Date = Date()
    @Attribute(originalName: "amount") var amountValue: Double = 0
    var earnedMiles: Int = 0
    @Attribute(originalName: "source") var sourceRaw: String = MileageSource.cardGeneral.rawValue
    
    // 統一子類別欄位：取代舊的 acceleratorCategoryRaw 和 taishinDesignatedCategoryRaw
    var cardSubcategoryID: String?
    
    // 舊欄位保留（向後相容 CloudKit 既有資料，讀取時自動遷移到 cardSubcategoryID）
    @Attribute(originalName: "acceleratorCategory") var acceleratorCategoryRaw: String?
    var taishinDesignatedCategoryRaw: String?
    
    var notes: String = ""
    var costPerMile: Double = 0
    
    // 使用的信用卡品牌（信用卡消費時記錄）
    var cardBrandRaw: String?
    
    // 額外資訊欄位
    var flightRoute: String?
    var conversionSource: String?
    var merchantName: String?
    var promotionName: String?
    var linkedTicketID: UUID?
    
    var programID: UUID?
    var account: MileageAccount?

    var amount: Decimal {
        get { Decimal(string: String(amountValue)) ?? Decimal(amountValue) }
        set { amountValue = (newValue as NSDecimalNumber).doubleValue }
    }

    var source: MileageSource {
        get {
            if let s = MileageSource(rawValue: sourceRaw) { return s }
            // 向後相容舊版 raw value
            switch sourceRaw {
            case "聯名卡一般消費": return .cardGeneral
            case "聯名卡哩程加速器": return .cardAccelerator
            default: return .cardGeneral
            }
        }
        set { sourceRaw = newValue.rawValue }
    }
    
    /// 統一的子類別存取（自動從舊欄位遷移）
    var resolvedSubcategoryID: String? {
        get {
            // 優先使用新欄位，若為空則從舊欄位遷移
            if let id = cardSubcategoryID { return id }
            if let old = acceleratorCategoryRaw { return old }
            if let old = taishinDesignatedCategoryRaw { return old }
            return nil
        }
        set {
            cardSubcategoryID = newValue
            // 同步寫入舊欄位（向後相容）
            if source == .cardAccelerator {
                acceleratorCategoryRaw = newValue
            } else if source == .taishinDesignated {
                taishinDesignatedCategoryRaw = newValue
            }
        }
    }
    
    /// 使用的信用卡品牌（computed）
    var cardBrand: CardBrand? {
        get {
            guard let raw = cardBrandRaw else { return nil }
            return CardBrand(rawValue: raw)
        }
        set { cardBrandRaw = newValue?.rawValue }
    }
    
    /// 使用的信用卡顯示名稱
    var cardDisplayName: String? {
        guard let brand = cardBrand else { return nil }
        return brand.displayName
    }
    
    init(date: Date = Date(),
         amount: Decimal,
         earnedMiles: Int,
         source: MileageSource,
         subcategoryID: String? = nil,
         cardBrand: CardBrand? = nil,
         notes: String = "",
         flightRoute: String? = nil,
         conversionSource: String? = nil,
         merchantName: String? = nil,
         promotionName: String? = nil,
         linkedTicketID: UUID? = nil) {
        self.id = UUID()
        self.date = date
        self.amountValue = (amount as NSDecimalNumber).doubleValue
        self.earnedMiles = earnedMiles
        self.sourceRaw = source.rawValue
        self.cardSubcategoryID = subcategoryID
        self.cardBrandRaw = cardBrand?.rawValue
        // 同步舊欄位
        if source == .cardAccelerator {
            self.acceleratorCategoryRaw = subcategoryID
        } else if source == .taishinDesignated {
            self.taishinDesignatedCategoryRaw = subcategoryID
        }
        self.notes = notes
        self.flightRoute = flightRoute
        self.conversionSource = conversionSource
        self.merchantName = merchantName
        self.promotionName = promotionName
        self.linkedTicketID = linkedTicketID
        
        if earnedMiles > 0 {
            self.costPerMile = Double(truncating: amount as NSDecimalNumber) / Double(earnedMiles)
        } else {
            self.costPerMile = 0
        }
    }
}

// 里程來源
enum MileageSource: String, Codable, CaseIterable {
    case cardGeneral = "刷卡一般消費"
    case cardAccelerator = "哩程加速器"
    case taishinOverseas = "國外一般消費"
    case taishinDesignated = "越飛越有哩"
    case specialMerchant = "特店消費累積"
    case promotion = "活動贈送"
    case pointsConversion = "銀行點數兌換"
    case pointsTransfer = "他點轉入"
    case flight = "飛行累積"
    case ticketRedemption = "機票兌換"
    case initialInput = "初次輸入"
    
    var icon: String {
        switch self {
        case .cardGeneral: return "creditcard"
        case .cardAccelerator: return "bolt.fill"
        case .taishinOverseas: return "globe.asia.australia.fill"
        case .taishinDesignated: return "sparkles"
        case .specialMerchant: return "storefront"
        case .promotion: return "gift.fill"
        case .pointsConversion: return "arrow.triangle.2.circlepath"
        case .pointsTransfer: return "arrow.down.circle.fill"
        case .flight: return "airplane"
        case .ticketRedemption: return "ticket.fill"
        case .initialInput: return "tray.and.arrow.down.fill"
        }
    }

    /// 記帳細項專用自訂圖示資產名稱（Assets）
    var ledgerIconAssetName: String {
        switch self {
        case .cardGeneral: return "ledgericon_一般消費"
        case .cardAccelerator: return "ledgericon_加速器"
        case .taishinOverseas: return "ledgericon_國外"
        case .taishinDesignated: return "ledgericon_越飛越有哩"
        case .specialMerchant: return "ledgericon_特店"
        case .promotion: return "ledgericon_活動"
        case .pointsConversion: return "ledgericon_點數兌換"
        case .pointsTransfer: return "ledgericon_他點轉入"
        case .flight: return "ledgericon_飛行"
        case .ticketRedemption: return "ledgericon_機票兌換"
        case .initialInput: return "ledgericon_初次輸入"
        }
    }
    
    var color: String {
        switch self {
        case .cardGeneral: return "blue"
        case .cardAccelerator: return "orange"
        case .taishinOverseas: return "teal"
        case .taishinDesignated: return "orange"
        case .specialMerchant: return "purple"
        case .promotion: return "pink"
        case .pointsConversion: return "green"
        case .pointsTransfer: return "indigo"
        case .flight: return "cyan"
        case .ticketRedemption: return "indigo"
        case .initialInput: return "mint"
        }
    }
}
