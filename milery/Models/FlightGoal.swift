import Foundation
import SwiftData

@Model
final class FlightGoal {
    var id: UUID = UUID()
    var origin: String = "" // 出發地 IATA 代碼
    var destination: String = "" // 目的地 IATA 代碼
    var originName: String = "" // 出發地中文名稱
    var destinationName: String = "" // 目的地中文名稱
    @Attribute(originalName: "cabinClass") var cabinClassRaw: String = CabinClass.economy.rawValue
    var requiredMiles: Int = 0
    var isOneworld: Bool = false // 是否為寰宇一家夥伴航空
    var isPriority: Bool = false // 是否為優先目標
    var isRoundTrip: Bool = false // 是否為來回程
    var createdDate: Date = Date()
    var sortOrder: Int = 0 // 排序順序（越小越前面，釘選與非釘選分開排序）
    
    var programID: UUID?
    var account: MileageAccount? // CloudKit 要求 relationship 必須為 optional

    var cabinClass: CabinClass {
        get { CabinClass(rawValue: cabinClassRaw) ?? .economy }
        set { cabinClassRaw = newValue.rawValue }
    }
    
    init(origin: String,
         destination: String,
         originName: String,
         destinationName: String,
         cabinClass: CabinClass,
         requiredMiles: Int,
         isOneworld: Bool = false,
         isPriority: Bool = false,
         isRoundTrip: Bool = false) {
        self.id = UUID()
        self.origin = origin
        self.destination = destination
        self.originName = originName
        self.destinationName = destinationName
        self.cabinClassRaw = cabinClass.rawValue
        self.requiredMiles = requiredMiles
        self.isOneworld = isOneworld
        self.isPriority = isPriority
        self.isRoundTrip = isRoundTrip
        self.createdDate = Date()
        self.sortOrder = 0
    }
    
    // 計算進度百分比
    func progress(currentMiles: Int) -> Double {
        guard requiredMiles > 0 else { return 0 }
        return min(Double(currentMiles) / Double(requiredMiles), 1.0)
    }
    
    // 還需要多少哩程
    func milesNeeded(currentMiles: Int) -> Int {
        return max(requiredMiles - currentMiles, 0)
    }
}

enum CabinClass: String, Codable, CaseIterable {
    case economy = "經濟艙"
    case premiumEconomy = "豪華經濟艙"
    case business = "商務艙"
    case first = "頭等艙"
    
    var icon: String {
        switch self {
        case .economy: return "airplane.circle"
        case .premiumEconomy: return "airplane.circle.fill"
        case .business: return "sparkles"
        case .first: return "crown.fill"
        }
    }
    
    var color: String {
        switch self {
        case .economy: return "blue"
        case .premiumEconomy: return "purple"
        case .business: return "orange"
        case .first: return "yellow"
        }
    }
}

// 常見航線的哩程需求（使用資料庫自動計算）
extension FlightGoal {
    static func popularRoutes() -> [FlightGoal] {
        // 使用新的資料庫方法
        return FlightGoal.popularRoutesFromDatabase()
    }
}
