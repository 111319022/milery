import Foundation

// 亞洲萬里通航距級別（最新版本 2026）
enum AwardZone: String, Codable, CaseIterable {
    case ultraShortHaul = "超短途"      // 1-750 哩
    case shortHaul1 = "短途 1"          // 751-2750 哩（較便宜）
    case shortHaul2 = "短途 2"          // 751-2750 哩（較貴，特定城市）
    case mediumHaul = "中程"            // 2751-5000 哩
    case longHaul = "長程"              // 5001-7500 哩
    case ultraLongHaul = "超長程"       // 7501+ 哩
    
    var distanceRange: String {
        switch self {
        case .ultraShortHaul: return "1-750 哩"
        case .shortHaul1: return "751-2,750 哩"
        case .shortHaul2: return "751-2,750 哩"
        case .mediumHaul: return "2,751-5,000 哩"
        case .longHaul: return "5,001-7,500 哩"
        case .ultraLongHaul: return "7,501 哩以上"
        }
    }
    
    var description: String {
        switch self {
        case .ultraShortHaul: return "超短途"
        case .shortHaul1: return "短途 1（一般亞洲城市）"
        case .shortHaul2: return "短途 2（日本等）"
        case .mediumHaul: return "中程"
        case .longHaul: return "長程"
        case .ultraLongHaul: return "超長程"
        }
    }
}

// 舊的航距級別別名（保留以便向後相容）
typealias DistanceCategory = AwardZone

// 亞洲萬里通機票兌換計算引擎（最新版本 2026）
class FlightCalculator {
    
    // 短途 2 的特定城市列表（較貴的亞洲城市）
    // 包含日本、泰國、峇里島等熱門觀光目的地
    private static let shortHaul2Cities: Set<String> = [
        // 日本
        "NRT",  // 東京成田
        "HND",  // 東京羽田
        "KIX",  // 大阪關西
        "NGO",  // 名古屋
        "CTS",  // 札幌新千歲
        "FUK",  // 福岡
        "OKA",  // 沖繩
        "SDJ",  // 仙台
        "KMQ",  // 小松
        "HIJ",  // 廣島
        "KOJ",  // 鹿兒島
        "OIT",  // 大分
        "MYJ",  // 松山
        "UBJ",  // 宇部
        // 韓國
        "PUS",  // 釜山
    ]
    
    // 根據距離和目的地城市判斷航距級別
    // ⚠️ 關鍵邏輯：短途1和短途2距離重疊（都是751-2750哩），需透過城市代碼區分
    static func determineZone(distance: Int, destinationCode: String) -> AwardZone {
        switch distance {
        case 1...750:
            return .ultraShortHaul
            
        case 751...2750:
            // 關鍵判斷：檢查是否為短途2特定城市
            if shortHaul2Cities.contains(destinationCode.uppercased()) {
                return .shortHaul2  // 較貴（日本）
            } else {
                return .shortHaul1  // 較便宜（一般亞洲城市）
            }
            
        case 2751...5000:
            return .mediumHaul
            
        case 5001...7500:
            return .longHaul
            
        default:
            return .ultraLongHaul
        }
    }
    
    // 取得所需哩程數（最新兌換表）
    // 注意：此為國泰航空自家航班兌換標準
    // ⚠️ 兌換寰宇一家夥伴航空（如日航、英航等）所需哩程會較高
    static func requiredMiles(zone: AwardZone, cabinClass: CabinClass) -> Int? {
        switch (zone, cabinClass) {
        // 超短途 (1-750 哩)
        case (.ultraShortHaul, .economy):
            return 7500
        case (.ultraShortHaul, .premiumEconomy):
            return 11000
        case (.ultraShortHaul, .business):
            return 16000
        case (.ultraShortHaul, .first):
            return nil  // 超短途無頭等艙
            
        // 短途 1 (751-2750 哩) - 一般亞洲城市
        case (.shortHaul1, .economy):
            return 9000
        case (.shortHaul1, .premiumEconomy):
            return 20000
        case (.shortHaul1, .business):
            return 28000
        case (.shortHaul1, .first):
            return 43000
            
        // 短途 2 (751-2750 哩) - 日本、泰國等
        case (.shortHaul2, .economy):
            return 13000
        case (.shortHaul2, .premiumEconomy):
            return 23000
        case (.shortHaul2, .business):
            return 32000
        case (.shortHaul2, .first):
            return 50000
            
        // 中程 (2751-5000 哩)
        case (.mediumHaul, .economy):
            return 20000
        case (.mediumHaul, .premiumEconomy):
            return 38000
        case (.mediumHaul, .business):
            return 58000
        case (.mediumHaul, .first):
            return 90000
            
        // 長程 (5001-7500 哩)
        case (.longHaul, .economy):
            return 27000
        case (.longHaul, .premiumEconomy):
            return 50000
        case (.longHaul, .business):
            return 88000
        case (.longHaul, .first):
            return 125000
            
        // 超長程 (7501+ 哩)
        case (.ultraLongHaul, .economy):
            return 38000
        case (.ultraLongHaul, .premiumEconomy):
            return 75000
        case (.ultraLongHaul, .business):
            return 115000
        case (.ultraLongHaul, .first):
            return 160000
        }
    }
    
    // 便利方法：直接根據距離和目的地計算所需哩程
    static func calculateRequiredMiles(
        distance: Int,
        destinationCode: String,
        cabinClass: CabinClass
    ) -> Int? {
        let zone = determineZone(distance: distance, destinationCode: destinationCode)
        return requiredMiles(zone: zone, cabinClass: cabinClass)
    }
    
    // 便利方法：根據機場代碼計算所需哩程（自動計算距離）
    static func calculateRequiredMiles(
        from originCode: String,
        to destinationCode: String,
        cabinClass: CabinClass
    ) -> Int? {
        guard let distance = AirportDatabase.shared.calculateDistance(
            from: originCode,
            to: destinationCode
        ) else {
            return nil
        }
        
        return calculateRequiredMiles(
            distance: distance,
            destinationCode: destinationCode,
            cabinClass: cabinClass
        )
    }
    
    // 檢查目的地是否為短途2城市
    static func isShortHaul2City(_ cityCode: String) -> Bool {
        return shortHaul2Cities.contains(cityCode.uppercased())
    }
    
    // 取得完整的兌換表格資料（供參考用）
    static func getCompleteAwardChart() -> [[String: Any]] {
        var chart: [[String: Any]] = []
        
        for zone in AwardZone.allCases {
            for cabinClass in CabinClass.allCases {
                if let miles = requiredMiles(zone: zone, cabinClass: cabinClass) {
                    chart.append([
                        "zone": zone.rawValue,
                        "distanceRange": zone.distanceRange,
                        "description": zone.description,
                        "cabinClass": cabinClass.rawValue,
                        "requiredMiles": miles
                    ])
                }
            }
        }
        
        return chart
    }
}

// 國泰航空台北直飛/經香港轉機可兌換航點
// 出發地為台北時，目的地在此清單中 → 使用國泰自動計算邏輯
// 目的地不在此清單中 → 需兌換寰宇一家夥伴，使用者自行輸入哩程
extension FlightCalculator {
    
    /// 國泰航空從台北出發可兌換的目的地 IATA 代碼集合
    static let cathayTPEDirectRoutes: Set<String> = [
        "HKG",  // 香港          7,000 起
        "PVG",  // 上海          9,000 起
        "ICN",  // 首爾（經香港）  9,000 起
        "SIN",  // 新加坡（經香港）9,000 起
        "SGN",  // 胡志明市（經香港）9,000 起
        "KUL",  // 吉隆坡（經香港）9,000 起
        "KIX",  // 大阪          13,000 起
        "NGO",  // 名古屋        13,000 起
        "NRT",  // 東京成田       13,000 起
        "CTS",  // 札幌（經香港）  13,000 起
        "BKK",  // 曼谷（經香港）  13,000 起
        "DPS",  // 峇里島（經香港）13,000 起
    ]
    
    /// 檢查從台北出發是否為國泰可兌換航線
    static func isCathayRouteFromTPE(destination: String) -> Bool {
        return cathayTPEDirectRoutes.contains(destination.uppercased())
    }
}

// 舊版相容性支援（保留舊的 CathayAwardChart 結構）
struct CathayAwardChart {
    
    // 舊版方法（保留以便向後相容）
    static func requiredMiles(
        distanceCategory: AwardZone,
        cabinClass: CabinClass
    ) -> Int {
        return FlightCalculator.requiredMiles(zone: distanceCategory, cabinClass: cabinClass) ?? 0
    }
    
    // 舊版方法（保留以便向後相容，但已棄用）
    static func requiredMiles(
        from originIATA: String,
        to destinationIATA: String,
        cabinClass: CabinClass
    ) -> Int? {
        return FlightCalculator.calculateRequiredMiles(
            from: originIATA,
            to: destinationIATA,
            cabinClass: cabinClass
        )
    }
}

// 擴展 FlightGoal 以使用新的計算引擎
extension FlightGoal {
    
    // 使用新的計算引擎自動建立航線目標
    convenience init(
        fromIATA origin: String,
        toIATA destination: String,
        cabinClass: CabinClass,
        isOneworld: Bool = false,
        isPriority: Bool = false,
        isRoundTrip: Bool = false
    ) {
        // 從資料庫取得機場資訊
        let originAirport = AirportDatabase.shared.getAirport(iataCode: origin)
        let destinationAirport = AirportDatabase.shared.getAirport(iataCode: destination)
        
        let originName = originAirport?.cityName ?? origin
        let destinationName = destinationAirport?.cityName ?? destination
        
        // 使用新的計算引擎自動計算所需哩程
        var requiredMiles = FlightCalculator.calculateRequiredMiles(
            from: origin,
            to: destination,
            cabinClass: cabinClass
        ) ?? 0
        
        // 如果是來回程，哩程加倍
        if isRoundTrip {
            requiredMiles *= 2
        }
        
        self.init(
            origin: origin.uppercased(),
            destination: destination.uppercased(),
            originName: originName,
            destinationName: destinationName,
            cabinClass: cabinClass,
            requiredMiles: requiredMiles,
            isOneworld: isOneworld,
            isPriority: isPriority,
            isRoundTrip: isRoundTrip
        )
    }
    
    // 取得航線的實際飛行距離
    var flightDistance: Int? {
        return AirportDatabase.shared.calculateDistance(from: origin, to: destination)
    }
    
    // 取得航距級別（使用新的計算引擎）
    var distanceCategory: AwardZone? {
        guard let distance = flightDistance else { return nil }
        return FlightCalculator.determineZone(distance: distance, destinationCode: destination)
    }
    
    // 檢查目的地是否為短途2城市
    var isShortHaul2Destination: Bool {
        return FlightCalculator.isShortHaul2City(destination)
    }
}

// 熱門航線預設資料
extension FlightGoal {
    
    // 使用資料庫自動建立熱門航線（含正確的短途1/短途2判斷）
    static func popularRoutesFromDatabase() -> [FlightGoal] {
        return [
            // 台北 → 香港（超短途）
            FlightGoal(fromIATA: "TPE", toIATA: "HKG", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "HKG", cabinClass: .business),
            
            // 台北 → 日本（短途2 - 較貴）
            FlightGoal(fromIATA: "TPE", toIATA: "NRT", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "NRT", cabinClass: .business),
            FlightGoal(fromIATA: "TPE", toIATA: "KIX", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "KIX", cabinClass: .business),
            FlightGoal(fromIATA: "TPE", toIATA: "FUK", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "CTS", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "OKA", cabinClass: .economy),
            
            // 台北 → 泰國（短途1 - 較便宜）
            FlightGoal(fromIATA: "TPE", toIATA: "BKK", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "BKK", cabinClass: .business),
            
            // 台北 → 韓國（短途1 - 較便宜）
            FlightGoal(fromIATA: "TPE", toIATA: "ICN", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "ICN", cabinClass: .business),
            
            // 台北 → 東南亞（短途1 - 較便宜）
            FlightGoal(fromIATA: "TPE", toIATA: "SIN", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "SIN", cabinClass: .business),
            FlightGoal(fromIATA: "TPE", toIATA: "MNL", cabinClass: .economy),
            
            // 台北 → 中國（短途1 - 較便宜）
            FlightGoal(fromIATA: "TPE", toIATA: "PEK", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "PVG", cabinClass: .economy),
            
            // 台北 → 澳洲（中程）
            FlightGoal(fromIATA: "TPE", toIATA: "SYD", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "SYD", cabinClass: .business),
            
            // 台北 → 北美（長程/超長程）
            FlightGoal(fromIATA: "TPE", toIATA: "LAX", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "LAX", cabinClass: .business),
            FlightGoal(fromIATA: "TPE", toIATA: "SFO", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "YVR", cabinClass: .economy),
            
            // 台北 → 歐洲（長程）
            FlightGoal(fromIATA: "TPE", toIATA: "LHR", cabinClass: .economy),
            FlightGoal(fromIATA: "TPE", toIATA: "LHR", cabinClass: .business),
            FlightGoal(fromIATA: "TPE", toIATA: "FRA", cabinClass: .economy),
        ]
    }
}

