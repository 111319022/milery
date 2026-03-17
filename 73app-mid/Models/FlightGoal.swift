//
//  FlightGoal.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import SwiftData

@Model
final class FlightGoal {
    var id: UUID
    var origin: String // 出發地 IATA 代碼
    var destination: String // 目的地 IATA 代碼
    var originName: String // 出發地中文名稱
    var destinationName: String // 目的地中文名稱
    var cabinClass: CabinClass
    var requiredMiles: Int
    var isOneworld: Bool // 是否為寰宇一家夥伴航空
    var isPriority: Bool // 是否為優先目標
    var isRoundTrip: Bool // 是否為來回程
    var createdDate: Date
    
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
        self.cabinClass = cabinClass
        self.requiredMiles = requiredMiles
        self.isOneworld = isOneworld
        self.isPriority = isPriority
        self.isRoundTrip = isRoundTrip
        self.createdDate = Date()
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
