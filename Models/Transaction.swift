import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var date: Date = Date()
    var amountValue: Double = 0 // 持久化用：CloudKit 友善型別
    var earnedMiles: Int = 0
    var sourceRaw: String = MileageSource.cardGeneral.rawValue
    var acceleratorCategoryRaw: String? // 加速器類別（如果適用）
    var notes: String = ""
    var costPerMile: Double = 0 // 每哩成本（自動計算）
    
    // 額外資訊欄位
    var flightRoute: String? // 飛行累積：航線（例如：TPE-NRT）
    var conversionSource: String? // 銀行點數兌換/他點轉入：來源（例如：國泰世華銀行、Marriott Bonvoy）
    var merchantName: String? // 特店消費累積：商家名稱（例如：星巴克、誠品書店）
    var promotionName: String? // 活動贈送：活動名稱（例如：開卡禮、生日禮）
    var linkedTicketID: UUID? // 兌換機票時連結的 RedeemedTicket ID
    
    var account: MileageAccount? // CloudKit 要求 relationship 必須為 optional

    var amount: Decimal {
        get { NSDecimalNumber(value: amountValue).decimalValue }
        set { amountValue = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    var source: MileageSource {
        get { MileageSource(rawValue: sourceRaw) ?? .cardGeneral }
        set { sourceRaw = newValue.rawValue }
    }

    var acceleratorCategory: AcceleratorCategory? {
        get { acceleratorCategoryRaw.flatMap { AcceleratorCategory(rawValue: $0) } }
        set { acceleratorCategoryRaw = newValue?.rawValue }
    }
    
    init(date: Date = Date(), 
         amount: Decimal, 
         earnedMiles: Int, 
         source: MileageSource,
         acceleratorCategory: AcceleratorCategory? = nil,
         notes: String = "",
         flightRoute: String? = nil,
         conversionSource: String? = nil,
         merchantName: String? = nil,
         promotionName: String? = nil,
         linkedTicketID: UUID? = nil) {
        self.id = UUID()
        self.date = date
        self.amountValue = NSDecimalNumber(decimal: amount).doubleValue
        self.earnedMiles = earnedMiles
        self.sourceRaw = source.rawValue
        self.acceleratorCategoryRaw = acceleratorCategory?.rawValue
        self.notes = notes
        self.flightRoute = flightRoute
        self.conversionSource = conversionSource
        self.merchantName = merchantName
        self.promotionName = promotionName
        self.linkedTicketID = linkedTicketID
        
        // 計算每哩成本
        if earnedMiles > 0 {
            self.costPerMile = Double(truncating: amount as NSDecimalNumber) / Double(earnedMiles)
        } else {
            self.costPerMile = 0
        }
    }
}

// 里程來源
enum MileageSource: String, Codable, CaseIterable {
    case cardGeneral = "聯名卡一般消費"
    case cardAccelerator = "聯名卡哩程加速器"
    case specialMerchant = "特店消費累積"
    case promotion = "活動贈送"
    case pointsConversion = "銀行點數兌換"
    case pointsTransfer = "他點轉入"
    case flight = "飛行累積"
    case ticketRedemption = "機票兌換"
    
    var icon: String {
        switch self {
        case .cardGeneral: return "creditcard"
        case .cardAccelerator: return "bolt.fill"
        case .specialMerchant: return "storefront"
        case .promotion: return "gift.fill"
        case .pointsConversion: return "arrow.triangle.2.circlepath"
        case .pointsTransfer: return "arrow.down.circle.fill"
        case .flight: return "airplane"
        case .ticketRedemption: return "ticket.fill"
        }
    }
    
    var color: String {
        switch self {
        case .cardGeneral: return "blue"
        case .cardAccelerator: return "orange"
        case .specialMerchant: return "purple"
        case .promotion: return "pink"
        case .pointsConversion: return "green"
        case .pointsTransfer: return "indigo"
        case .flight: return "cyan"
        case .ticketRedemption: return "indigo"
        }
    }
}

// 加速器類別（國泰世華亞萬卡的四大加速器）
enum AcceleratorCategory: String, Codable, CaseIterable {
    case overseas = "海外"
    case travel = "旅遊交通"
    case daily = "日常消費"
    case leisure = "休閒娛樂"
    
    var icon: String {
        switch self {
        case .overseas: return "globe.asia.australia.fill"
        case .travel: return "airplane.departure"
        case .daily: return "cart.fill"
        case .leisure: return "theatermasks.fill"
        }
    }
    
    var acceleratorDescription: String {
        switch self {
        case .overseas: return "海外消費（含線上外幣交易）"
        case .travel: return "國內外航空、飯店、旅行社、租車"
        case .daily: return "超市、量販、加油、電信費"
        case .leisure: return "電影院、KTV、健身房、遊樂園"
        }
    }
}
