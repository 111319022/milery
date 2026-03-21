import SwiftUI

// MARK: - CSV 機場資料模型（獨立於 AirportDatabase）
struct CSVAirport: Identifiable {
    let id: String          // IATA 代碼
    let iataCode: String
    let icaoCode: String
    let name: String        // 機場英文名稱
    let municipality: String // 城市名稱
    let isoCountry: String  // ISO 國家代碼 (e.g. "TW", "JP")
    let continent: String   // 大洲代碼 (AS, EU, NA, SA, AF, OC, AN)
    let type: String        // large_airport / medium_airport
    let latitude: Double
    let longitude: Double
    
    // 顯示用的國家中文名稱
    var countryDisplayName: String {
        CSVAirport.countryNames[isoCountry] ?? isoCountry
    }
    
    // 顯示用的大洲中文名稱
    var continentDisplayName: String {
        CSVAirport.continentNames[continent] ?? continent
    }
    
    // 顯示用的機場類型
    var typeDisplayName: String {
        type == "large_airport" ? "大型" : "中型"
    }
    
    // ISO 國家代碼 → 中文名稱
    static let countryNames: [String: String] = [
        "TW": "台灣", "HK": "香港", "MO": "澳門",
        "JP": "日本", "KR": "韓國", "CN": "中國",
        "TH": "泰國", "SG": "新加坡", "MY": "馬來西亞",
        "PH": "菲律賓", "VN": "越南", "ID": "印尼",
        "IN": "印度", "KH": "柬埔寨", "MM": "緬甸",
        "LA": "寮國", "BD": "孟加拉", "LK": "斯里蘭卡",
        "NP": "尼泊爾", "PK": "巴基斯坦", "MN": "蒙古",
        "AU": "澳洲", "NZ": "紐西蘭", "FJ": "斐濟",
        "PG": "巴布亞紐幾內亞", "NC": "新喀里多尼亞",
        "US": "美國", "CA": "加拿大", "MX": "墨西哥",
        "GB": "英國", "FR": "法國", "DE": "德國",
        "IT": "義大利", "ES": "西班牙", "NL": "荷蘭",
        "CH": "瑞士", "PT": "葡萄牙", "SE": "瑞典",
        "NO": "挪威", "DK": "丹麥", "FI": "芬蘭",
        "IE": "愛爾蘭", "AT": "奧地利", "BE": "比利時",
        "PL": "波蘭", "CZ": "捷克", "GR": "希臘",
        "TR": "土耳其", "RU": "俄羅斯", "UA": "烏克蘭",
        "RO": "羅馬尼亞", "HU": "匈牙利", "HR": "克羅埃西亞",
        "IS": "冰島", "RS": "塞爾維亞", "BG": "保加利亞",
        "AE": "阿聯酋", "QA": "卡達", "SA": "沙烏地阿拉伯",
        "IL": "以色列", "JO": "約旦", "OM": "阿曼",
        "BH": "巴林", "KW": "科威特", "LB": "黎巴嫩",
        "IR": "伊朗", "IQ": "伊拉克",
        "BR": "巴西", "AR": "阿根廷", "CL": "智利",
        "CO": "哥倫比亞", "PE": "秘魯", "EC": "厄瓜多",
        "VE": "委內瑞拉", "UY": "烏拉圭", "PY": "巴拉圭",
        "BO": "玻利維亞",
        "ZA": "南非", "EG": "埃及", "MA": "摩洛哥",
        "KE": "肯亞", "ET": "衣索比亞", "NG": "奈及利亞",
        "TZ": "坦尚尼亞", "GH": "迦納",
        "CU": "古巴", "PA": "巴拿馬", "CR": "哥斯大黎加",
        "PR": "波多黎各", "DO": "多明尼加", "JM": "牙買加",
    ]
    
    // 大洲代碼 → 中文名稱
    static let continentNames: [String: String] = [
        "AS": "亞洲",
        "EU": "歐洲",
        "NA": "北美洲",
        "SA": "南美洲",
        "AF": "非洲",
        "OC": "大洋洲",
        "AN": "南極洲",
    ]
}

// MARK: - CSV 解析器
private enum CSVAirportLoader {
    
    static func loadFromBundle() -> [CSVAirport] {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "csv"),
              let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        var results: [CSVAirport] = []
        let lines = content.components(separatedBy: "\n")
        
        // 跳過標題行
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let fields = parseCSVLine(line)
            guard fields.count >= 14 else { continue }
            
            let type = fields[2].trimmingQuotes()
            let iataCode = fields[13].trimmingQuotes()
            
            // 只載入有 IATA 代碼的大型/中型機場
            guard !iataCode.isEmpty,
                  iataCode != "0",
                  iataCode.count >= 2 && iataCode.count <= 4,
                  type == "large_airport" || type == "medium_airport",
                  let lat = Double(fields[4].trimmingQuotes()),
                  let lon = Double(fields[5].trimmingQuotes()) else {
                continue
            }
            
            let airport = CSVAirport(
                id: iataCode,
                iataCode: iataCode,
                icaoCode: fields.count > 12 ? fields[12].trimmingQuotes() : "",
                name: fields[3].trimmingQuotes(),
                municipality: fields[10].trimmingQuotes(),
                isoCountry: fields[8].trimmingQuotes(),
                continent: fields[7].trimmingQuotes(),
                type: type,
                latitude: lat,
                longitude: lon
            )
            
            results.append(airport)
        }
        
        return results.sorted { $0.iataCode < $1.iataCode }
    }
    
    // 解析 CSV 行（處理引號包裹的欄位）
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char)
            } else if char == "," && !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}

private extension String {
    func trimmingQuotes() -> String {
        var s = self
        if s.hasPrefix("\"") { s.removeFirst() }
        if s.hasSuffix("\"") { s.removeLast() }
        return s
    }
}

// MARK: - AirportListView
struct AirportListView: View {
    @State private var searchText = ""
    @State private var selectedGrouping: GroupingOption = .continent
    @State private var selectedType: TypeFilter = .all
    @State private var allAirports: [CSVAirport] = []
    @State private var isLoading = true
    
    enum GroupingOption: String, CaseIterable {
        case continent = "大洲"
        case country = "國家"
        
        var id: Self { self }
    }
    
    enum TypeFilter: String, CaseIterable {
        case all = "全部"
        case large = "大型"
        case medium = "中型"
        
        var id: Self { self }
    }
    
    var filteredAirports: [CSVAirport] {
        var result = allAirports
        
        // 類型篩選
        switch selectedType {
        case .large:
            result = result.filter { $0.type == "large_airport" }
        case .medium:
            result = result.filter { $0.type == "medium_airport" }
        case .all:
            break
        }
        
        // 搜尋篩選
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { airport in
                airport.iataCode.lowercased().contains(query) ||
                airport.icaoCode.lowercased().contains(query) ||
                airport.name.lowercased().contains(query) ||
                airport.municipality.lowercased().contains(query) ||
                airport.countryDisplayName.contains(query) ||
                airport.isoCountry.lowercased().contains(query)
            }
        }
        
        return result
    }
    
    var groupedAirports: [String: [CSVAirport]] {
        Dictionary(grouping: filteredAirports) { airport in
            switch selectedGrouping {
            case .continent:
                return airport.continentDisplayName
            case .country:
                return airport.countryDisplayName
            }
        }.mapValues { $0.sorted { $0.iataCode < $1.iataCode } }
    }
    
    var sortedGroupKeys: [String] {
        groupedAirports.keys.sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜尋和篩選區
            VStack(spacing: 10) {
                // 搜尋框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜尋 IATA / ICAO / 城市 / 機場名稱", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // 分類選項
                HStack(spacing: 12) {
                    Picker("分類", selection: $selectedGrouping) {
                        ForEach(GroupingOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("類型", selection: $selectedType) {
                        ForEach(TypeFilter.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                
                // 統計
                Text("共 \(filteredAirports.count) 座機場")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            // 機場列表
            if isLoading {
                VStack {
                    Spacer()
                    SwiftUI.ProgressView()
                        .scaleEffect(1.2)
                    Text("正在載入全球機場資料...")
                        .foregroundColor(.gray)
                        .padding(.top, 12)
                    Spacer()
                }
            } else if filteredAirports.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("找不到機場")
                        .font(.headline)
                        .padding(.top, 12)
                    Text("請嘗試不同的搜尋條件")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Spacer()
                }
            } else {
                List {
                    ForEach(sortedGroupKeys, id: \.self) { section in
                        Section(header: sectionHeader(section)) {
                            ForEach(groupedAirports[section] ?? []) { airport in
                                CSVAirportRowView(airport: airport)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("機場資料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if allAirports.isEmpty {
                loadAirports()
            }
        }
    }
    
    private func loadAirports() {
        DispatchQueue.global(qos: .userInitiated).async {
            let airports = CSVAirportLoader.loadFromBundle()
            DispatchQueue.main.async {
                self.allAirports = airports
                self.isLoading = false
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.cathayJade)
            
            Spacer()
            
            let count = groupedAirports[title]?.count ?? 0
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray4))
                .cornerRadius(4)
        }
    }
}

// MARK: - CSV 機場列表行
struct CSVAirportRowView: View {
    let airport: CSVAirport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主要資訊
            HStack(spacing: 12) {
                // IATA 代碼徽章
                Text(airport.iataCode)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(airport.type == "large_airport"
                                ? AviationTheme.Colors.cathayJade
                                : AviationTheme.Colors.cathayJadeLight)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(airport.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        if !airport.municipality.isEmpty {
                            Text(airport.municipality)
                        }
                        Text("·")
                        Text(airport.countryDisplayName)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 機場類型標籤
                Text(airport.typeDisplayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(airport.type == "large_airport"
                                ? Color.blue.opacity(0.15)
                                : Color.orange.opacity(0.15))
                    .foregroundColor(airport.type == "large_airport"
                                    ? .blue : .orange)
                    .cornerRadius(4)
            }
            
            // 詳細資訊
            HStack(spacing: 16) {
                if !airport.icaoCode.isEmpty {
                    Label(airport.icaoCode, systemImage: "building.2")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Label(
                    String(format: "%.4f, %.4f", airport.latitude, airport.longitude),
                    systemImage: "location"
                )
                .font(.caption2)
                .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 預覽
#Preview {
    NavigationStack {
        AirportListView()
    }
}
