//
//  AirportDatabase.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import Foundation
import CoreLocation

// 機場資料結構
struct Airport: Identifiable, Codable {
    let id: String // IATA 代碼
    let iataCode: String
    let cityName: String // 城市中文名稱
    let cityNameEN: String // 城市英文名稱
    let airportName: String // 機場中文名稱
    let airportNameEN: String // 機場英文名稱
    let country: String // 國家
    let latitude: Double
    let longitude: Double
    
    init(iataCode: String, 
         cityName: String, 
         cityNameEN: String,
         airportName: String,
         airportNameEN: String,
         country: String,
         latitude: Double,
         longitude: Double) {
        self.id = iataCode
        self.iataCode = iataCode
        self.cityName = cityName
        self.cityNameEN = cityNameEN
        self.airportName = airportName
        self.airportNameEN = airportNameEN
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}

// 機場資料庫
class AirportDatabase {
    static let shared = AirportDatabase()
    
    private var airports: [String: Airport] = [:]
    
    private init() {
        loadAirportsFromCSV()
    }
    
    // 從 CSV 檔案載入機場資料
    private func loadAirportsFromCSV() {
        // 直接使用預設資料（已包含主要國際機場）
        // CSV 檔案太大（12MB），不適合打包到 App 中
        loadDefaultAirports()
        
        /* 如果需要從 CSV 載入更多機場，可取消以下註解：
        guard let csvPath = Bundle.main.path(forResource: "airports", ofType: "csv"),
              let csvContent = try? String(contentsOfFile: csvPath) else {
            loadDefaultAirports()
            return
        }
        
        let lines = csvContent.components(separatedBy: .newlines)
        
        // 跳過標題行
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            // 解析 CSV（考慮引號包裹的欄位）
            let fields = parseCSVLine(line)
            
            guard fields.count >= 14 else { continue }
            
            // 只載入有 IATA 代碼的大型/中型機場
            let type = fields[2].replacingOccurrences(of: "\"", with: "")
            let iataCode = fields[13].replacingOccurrences(of: "\"", with: "")
            
            guard !iataCode.isEmpty,
                  (type == "large_airport" || type == "medium_airport"),
                  let latitude = Double(fields[4]),
                  let longitude = Double(fields[5]) else {
                continue
            }
            
            let name = fields[3].replacingOccurrences(of: "\"", with: "")
            let municipality = fields[10].replacingOccurrences(of: "\"", with: "")
            let country = fields[8].replacingOccurrences(of: "\"", with: "")
            
            // 建立機場物件（使用英文名稱，稍後可補充中文）
            let airport = Airport(
                iataCode: iataCode,
                cityName: getChineseCityName(iataCode: iataCode, municipality: municipality),
                cityNameEN: municipality,
                airportName: getChineseAirportName(iataCode: iataCode, name: name),
                airportNameEN: name,
                country: getChineseCountry(country: country),
                latitude: latitude,
                longitude: longitude
            )
            
            airports[iataCode] = airport
        }
        
        print("成功載入 \(airports.count) 個機場")
        */
    }
    
    // 解析 CSV 行（處理引號包裹的欄位）
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                currentField.append(char)
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        if !currentField.isEmpty {
            fields.append(currentField)
        }
        
        return fields
    }
    
    // 取得中文城市名稱（常見機場）
    private func getChineseCityName(iataCode: String, municipality: String) -> String {
        let chineseNames: [String: String] = [
            "TPE": "台北(桃園)", "TSA(松山)": "台北", "KHH": "高雄", "RMQ": "台中",
            "HKG": "香港", "MFM": "澳門",
            "NRT": "東京", "HND": "東京", "KIX": "大阪", "NGO": "名古屋", 
            "FUK": "福岡", "CTS": "札幌", "OKA": "沖繩", "SDJ": "仙台",
            "ICN": "首爾", "GMP": "首爾", "PUS": "釜山",
            "PEK": "北京", "PVG": "上海", "SHA": "上海", "CAN": "廣州", 
            "SZX": "深圳", "CTU": "成都", "XIY": "西安",
            "BKK": "曼谷", "SIN": "新加坡", "KUL": "吉隆坡", "MNL": "馬尼拉",
            "SGN": "胡志明市", "HAN": "河內", "CGK": "雅加達",
            "SYD": "雪梨", "MEL": "墨爾本", "BNE": "布里斯本", "PER": "伯斯",
            "AKL": "奧克蘭",
            "LAX": "洛杉磯", "SFO": "舊金山", "JFK": "紐約", "ORD": "芝加哥",
            "SEA": "西雅圖", "YVR": "溫哥華", "YYZ": "多倫多",
            "LHR": "倫敦", "CDG": "巴黎", "FRA": "法蘭克福", "AMS": "阿姆斯特丹",
            "MAD": "馬德里", "FCO": "羅馬", "MUC": "慕尼黑", "ZRH": "蘇黎世",
            "DXB": "杜拜", "DOH": "杜哈", "DEL": "德里", "BOM": "孟買"
        ]
        
        return chineseNames[iataCode] ?? municipality
    }
    
    // 取得中文機場名稱
    private func getChineseAirportName(iataCode: String, name: String) -> String {
        let chineseNames: [String: String] = [
            "TPE": "桃園國際機場", "TSA": "松山機場",
            "HKG": "香港國際機場",
            "NRT": "成田國際機場", "HND": "羽田機場", "KIX": "關西國際機場",
            "ICN": "仁川國際機場", "GMP": "金浦機場",
            "BKK": "素萬那普機場", "SIN": "樟宜機場"
        ]
        
        return chineseNames[iataCode] ?? name
    }
    
    // 取得中文國家名稱
    private func getChineseCountry(country: String) -> String {
        let countryNames: [String: String] = [
            "TW": "台灣", "HK": "香港", "MO": "澳門",
            "JP": "日本", "KR": "韓國", "CN": "中國",
            "TH": "泰國", "SG": "新加坡", "MY": "馬來西亞", 
            "PH": "菲律賓", "VN": "越南", "ID": "印尼",
            "AU": "澳洲", "NZ": "紐西蘭",
            "US": "美國", "CA": "加拿大",
            "GB": "英國", "FR": "法國", "DE": "德國", "IT": "義大利",
            "ES": "西班牙", "NL": "荷蘭", "CH": "瑞士",
            "AE": "阿聯酋", "QA": "卡達", "IN": "印度"
        ]
        
        return countryNames[country] ?? country
    }
    
    // 預設機場資料（當 CSV 載入失敗時使用）
    private func loadDefaultAirports() {
        let airportList: [Airport] = [
            // 台灣
            Airport(iataCode: "TPE", cityName: "台北", cityNameEN: "Taipei",
                   airportName: "桃園國際機場", airportNameEN: "Taoyuan International Airport",
                   country: "台灣", latitude: 25.0777, longitude: 121.2328),
            Airport(iataCode: "TSA", cityName: "台北", cityNameEN: "Taipei",
                   airportName: "松山機場", airportNameEN: "Songshan Airport",
                   country: "台灣", latitude: 25.0694, longitude: 121.5519),
            
            // 香港
            Airport(iataCode: "HKG", cityName: "香港", cityNameEN: "Hong Kong",
                   airportName: "香港國際機場", airportNameEN: "Hong Kong International Airport",
                   country: "香港", latitude: 22.3080, longitude: 113.9185),
            
            // 日本
            Airport(iataCode: "NRT", cityName: "東京", cityNameEN: "Tokyo",
                   airportName: "成田國際機場", airportNameEN: "Narita International Airport",
                   country: "日本", latitude: 35.7647, longitude: 140.3864),
            Airport(iataCode: "HND", cityName: "東京", cityNameEN: "Tokyo",
                   airportName: "羽田機場", airportNameEN: "Haneda Airport",
                   country: "日本", latitude: 35.5494, longitude: 139.7798),
            Airport(iataCode: "KIX", cityName: "大阪", cityNameEN: "Osaka",
                   airportName: "關西國際機場", airportNameEN: "Kansai International Airport",
                   country: "日本", latitude: 34.4347, longitude: 135.2440),
            Airport(iataCode: "NGO", cityName: "名古屋", cityNameEN: "Nagoya",
                   airportName: "中部國際機場", airportNameEN: "Chubu Centrair International Airport",
                   country: "日本", latitude: 34.8584, longitude: 136.8054),
            Airport(iataCode: "FUK", cityName: "福岡", cityNameEN: "Fukuoka",
                   airportName: "福岡機場", airportNameEN: "Fukuoka Airport",
                   country: "日本", latitude: 33.5859, longitude: 130.4510),
            Airport(iataCode: "CTS", cityName: "札幌", cityNameEN: "Sapporo",
                   airportName: "新千歲機場", airportNameEN: "New Chitose Airport",
                   country: "日本", latitude: 42.7752, longitude: 141.6920),
            Airport(iataCode: "OKA", cityName: "沖繩", cityNameEN: "Okinawa",
                   airportName: "那霸機場", airportNameEN: "Naha Airport",
                   country: "日本", latitude: 26.1958, longitude: 127.6458),
            
            // 韓國
            Airport(iataCode: "ICN", cityName: "首爾", cityNameEN: "Seoul",
                   airportName: "仁川國際機場", airportNameEN: "Incheon International Airport",
                   country: "韓國", latitude: 37.4602, longitude: 126.4407),
            Airport(iataCode: "GMP", cityName: "首爾", cityNameEN: "Seoul",
                   airportName: "金浦機場", airportNameEN: "Gimpo International Airport",
                   country: "韓國", latitude: 37.5583, longitude: 126.7906),
            Airport(iataCode: "PUS", cityName: "釜山", cityNameEN: "Busan",
                   airportName: "金海國際機場", airportNameEN: "Gimhae International Airport",
                   country: "韓國", latitude: 35.1795, longitude: 128.9385),
            
            // 東南亞
            Airport(iataCode: "BKK", cityName: "曼谷", cityNameEN: "Bangkok",
                   airportName: "素萬那普機場", airportNameEN: "Suvarnabhumi Airport",
                   country: "泰國", latitude: 13.6900, longitude: 100.7501),
            Airport(iataCode: "SIN", cityName: "新加坡", cityNameEN: "Singapore",
                   airportName: "樟宜機場", airportNameEN: "Changi Airport",
                   country: "新加坡", latitude: 1.3644, longitude: 103.9915),
            Airport(iataCode: "KUL", cityName: "吉隆坡", cityNameEN: "Kuala Lumpur",
                   airportName: "吉隆坡國際機場", airportNameEN: "Kuala Lumpur International Airport",
                   country: "馬來西亞", latitude: 2.7456, longitude: 101.7099),
            Airport(iataCode: "MNL", cityName: "馬尼拉", cityNameEN: "Manila",
                   airportName: "尼諾伊·艾奎諾國際機場", airportNameEN: "Ninoy Aquino International Airport",
                   country: "菲律賓", latitude: 14.5086, longitude: 121.0194),
            Airport(iataCode: "SGN", cityName: "胡志明市", cityNameEN: "Ho Chi Minh City",
                   airportName: "新山一國際機場", airportNameEN: "Tan Son Nhat International Airport",
                   country: "越南", latitude: 10.8188, longitude: 106.6519),
            Airport(iataCode: "HAN", cityName: "河內", cityNameEN: "Hanoi",
                   airportName: "內排國際機場", airportNameEN: "Noi Bai International Airport",
                   country: "越南", latitude: 21.2212, longitude: 105.8072),
            
            // 中國大陸
            Airport(iataCode: "PEK", cityName: "北京", cityNameEN: "Beijing",
                   airportName: "首都國際機場", airportNameEN: "Capital International Airport",
                   country: "中國", latitude: 40.0773, longitude: 116.5967),
            Airport(iataCode: "PVG", cityName: "上海", cityNameEN: "Shanghai",
                   airportName: "浦東國際機場", airportNameEN: "Pudong International Airport",
                   country: "中國", latitude: 31.1434, longitude: 121.8050),
            Airport(iataCode: "CAN", cityName: "廣州", cityNameEN: "Guangzhou",
                   airportName: "白雲國際機場", airportNameEN: "Baiyun International Airport",
                   country: "中國", latitude: 23.3924, longitude: 113.2990),
            Airport(iataCode: "SZX", cityName: "深圳", cityNameEN: "Shenzhen",
                   airportName: "寶安國際機場", airportNameEN: "Bao'an International Airport",
                   country: "中國", latitude: 22.6395, longitude: 113.8103),
            
            // 印度與中東
            Airport(iataCode: "DEL", cityName: "德里", cityNameEN: "New Delhi",
                   airportName: "英迪拉甘地國際機場", airportNameEN: "Indira Gandhi International Airport",
                   country: "印度", latitude: 28.5556, longitude: 77.0952),
            Airport(iataCode: "BOM", cityName: "孟買", cityNameEN: "Mumbai",
                   airportName: "賈特拉帕蒂希瓦吉機場", airportNameEN: "Chhatrapati Shivaji Maharaj International Airport",
                   country: "印度", latitude: 19.0887, longitude: 72.8679),
            Airport(iataCode: "DXB", cityName: "杜拜", cityNameEN: "Dubai",
                   airportName: "杜拜國際機場", airportNameEN: "Dubai International Airport",
                   country: "阿聯酋", latitude: 25.2498, longitude: 55.3710),
            Airport(iataCode: "DOH", cityName: "杜哈", cityNameEN: "Doha",
                   airportName: "哈馬德國際機場", airportNameEN: "Hamad International Airport",
                   country: "卡達", latitude: 25.2731, longitude: 51.6081),
            
            // 澳洲與紐西蘭
            Airport(iataCode: "SYD", cityName: "雪梨", cityNameEN: "Sydney",
                   airportName: "雪梨機場", airportNameEN: "Sydney Airport",
                   country: "澳洲", latitude: -33.9399, longitude: 151.1753),
            Airport(iataCode: "MEL", cityName: "墨爾本", cityNameEN: "Melbourne",
                   airportName: "墨爾本機場", airportNameEN: "Melbourne Airport",
                   country: "澳洲", latitude: -37.6733, longitude: 144.8433),
            Airport(iataCode: "BNE", cityName: "布里斯本", cityNameEN: "Brisbane",
                   airportName: "布里斯本機場", airportNameEN: "Brisbane International Airport",
                   country: "澳洲", latitude: -27.3842, longitude: 153.1170),
            Airport(iataCode: "PER", cityName: "伯斯", cityNameEN: "Perth",
                   airportName: "伯斯機場", airportNameEN: "Perth International Airport",
                   country: "澳洲", latitude: -31.9403, longitude: 115.9670),
            Airport(iataCode: "AKL", cityName: "奧克蘭", cityNameEN: "Auckland",
                   airportName: "奧克蘭機場", airportNameEN: "Auckland International Airport",
                   country: "紐西蘭", latitude: -37.0120, longitude: 174.7863),
            
            // 美洲
            Airport(iataCode: "LAX", cityName: "洛杉磯", cityNameEN: "Los Angeles",
                   airportName: "洛杉磯國際機場", airportNameEN: "Los Angeles International Airport",
                   country: "美國", latitude: 33.9416, longitude: -118.4085),
            Airport(iataCode: "SFO", cityName: "舊金山", cityNameEN: "San Francisco",
                   airportName: "舊金山國際機場", airportNameEN: "San Francisco International Airport",
                   country: "美國", latitude: 37.6213, longitude: -122.3790),
            Airport(iataCode: "JFK", cityName: "紐約", cityNameEN: "New York",
                   airportName: "約翰甘迺迪國際機場", airportNameEN: "John F. Kennedy International Airport",
                   country: "美國", latitude: 40.6413, longitude: -73.7781),
            Airport(iataCode: "ORD", cityName: "芝加哥", cityNameEN: "Chicago",
                   airportName: "歐海爾國際機場", airportNameEN: "O'Hare International Airport",
                   country: "美國", latitude: 41.9786, longitude: -87.9048),
            Airport(iataCode: "SEA", cityName: "西雅圖", cityNameEN: "Seattle",
                   airportName: "西雅圖塔科馬國際機場", airportNameEN: "Seattle-Tacoma International Airport",
                   country: "美國", latitude: 47.4479, longitude: -122.3103),
            Airport(iataCode: "YVR", cityName: "溫哥華", cityNameEN: "Vancouver",
                   airportName: "溫哥華國際機場", airportNameEN: "Vancouver International Airport",
                   country: "加拿大", latitude: 49.1939, longitude: -123.1844),
            Airport(iataCode: "YYZ", cityName: "多倫多", cityNameEN: "Toronto",
                   airportName: "多倫多皮爾遜國際機場", airportNameEN: "Toronto Pearson International Airport",
                   country: "加拿大", latitude: 43.6759, longitude: -79.6294),
            
            // 歐洲
            Airport(iataCode: "LHR", cityName: "倫敦", cityNameEN: "London",
                   airportName: "希斯洛機場", airportNameEN: "Heathrow Airport",
                   country: "英國", latitude: 51.4700, longitude: -0.4543),
            Airport(iataCode: "CDG", cityName: "巴黎", cityNameEN: "Paris",
                   airportName: "戴高樂機場", airportNameEN: "Charles de Gaulle Airport",
                   country: "法國", latitude: 49.0097, longitude: 2.5479),
            Airport(iataCode: "FRA", cityName: "法蘭克福", cityNameEN: "Frankfurt",
                   airportName: "法蘭克福機場", airportNameEN: "Frankfurt Airport",
                   country: "德國", latitude: 50.0379, longitude: 8.5622),
            Airport(iataCode: "AMS", cityName: "阿姆斯特丹", cityNameEN: "Amsterdam",
                   airportName: "史基浦機場", airportNameEN: "Amsterdam Airport Schiphol",
                   country: "荷蘭", latitude: 52.3086, longitude: 4.7639),
            Airport(iataCode: "MAD", cityName: "馬德里", cityNameEN: "Madrid",
                   airportName: "馬德里巴拉哈斯機場", airportNameEN: "Adolfo Suárez Madrid-Barajas Airport",
                   country: "西班牙", latitude: 40.4934, longitude: -3.5722),
            Airport(iataCode: "FCO", cityName: "羅馬", cityNameEN: "Rome",
                   airportName: "李奧納多達文西機場", airportNameEN: "Leonardo da Vinci-Fiumicino Airport",
                   country: "義大利", latitude: 41.8045, longitude: 12.2520),
            Airport(iataCode: "MUC", cityName: "慕尼黑", cityNameEN: "Munich",
                   airportName: "慕尼黑機場", airportNameEN: "Munich Airport",
                   country: "德國", latitude: 48.3538, longitude: 11.7861),
            Airport(iataCode: "ZRH", cityName: "蘇黎世", cityNameEN: "Zurich",
                   airportName: "蘇黎世機場", airportNameEN: "Zurich Airport",
                   country: "瑞士", latitude: 47.4581, longitude: 8.5481),
        ]
        
        for airport in airportList {
            airports[airport.iataCode] = airport
        }
    }
    
    // 根據 IATA 代碼查詢機場
    func getAirport(iataCode: String) -> Airport? {
        return airports[iataCode.uppercased()]
    }
    
    // 取得所有機場列表
    func getAllAirports() -> [Airport] {
        return Array(airports.values).sorted { $0.cityNameEN < $1.cityNameEN }
    }
    
    // 計算兩個機場之間的距離（使用 CoreLocation，單位：英哩）
    func calculateDistance(from: String, to: String) -> Int? {
        guard let fromAirport = getAirport(iataCode: from),
              let toAirport = getAirport(iataCode: to) else {
            return nil
        }
        
        // 使用 CoreLocation 計算距離
        let fromLocation = CLLocation(
            latitude: fromAirport.latitude,
            longitude: fromAirport.longitude
        )
        let toLocation = CLLocation(
            latitude: toAirport.latitude,
            longitude: toAirport.longitude
        )
        
        // distance(from:) 回傳單位為「公尺」
        let distanceInMeters = fromLocation.distance(from: toLocation)
        
        // 轉換為英哩 (Statute Miles)
        // 1 英哩 = 1609.34 公尺
        let distanceInMiles = distanceInMeters / 1609.34
        
        return Int(distanceInMiles)
    }
    
    // 搜尋機場（支援 IATA 代碼、城市名稱、機場名稱）
    func searchAirports(query: String) -> [Airport] {
        guard !query.isEmpty else {
            return getAllAirports()
        }
        
        let lowercaseQuery = query.lowercased()
        
        return getAllAirports().filter { airport in
            airport.iataCode.lowercased().contains(lowercaseQuery) ||
            airport.cityName.lowercased().contains(lowercaseQuery) ||
            airport.cityNameEN.lowercased().contains(lowercaseQuery) ||
            airport.airportName.lowercased().contains(lowercaseQuery) ||
            airport.airportNameEN.lowercased().contains(lowercaseQuery)
        }
    }
}
