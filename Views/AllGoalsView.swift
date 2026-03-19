//
//  AllGoalsView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct AllGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @State private var showingAddGoal = false
    @State private var showingPopularRoutes = false
    
    var sortedGoals: [FlightGoal] {
        viewModel.flightGoals.sorted { goal1, goal2 in
            if goal1.isPriority != goal2.isPriority {
                return goal1.isPriority
            }
            let miles = viewModel.mileageAccount?.totalMiles ?? 0
            return goal1.milesNeeded(currentMiles: miles) < goal2.milesNeeded(currentMiles: miles)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sortedGoals.isEmpty {
                        // 空狀態
                        VStack(spacing: 20) {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("尚未設定航線目標")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("設定你的夢想航線，追蹤哩程進度")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                showingPopularRoutes = true
                            } label: {
                                Label("瀏覽熱門航線", systemImage: "star.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 60)
                    } else {
                        ForEach(sortedGoals, id: \.id) { goal in
                            DetailedFlightGoalCard(
                                goal: goal,
                                currentMiles: viewModel.mileageAccount?.totalMiles ?? 0,
                                onTogglePriority: {
                                    goal.isPriority.toggle()
                                    viewModel.saveContext()
                                    viewModel.loadData()
                                },
                                onDelete: {
                                    viewModel.deleteFlightGoal(goal)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("航線目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddGoal = true
                        } label: {
                            Label("自訂航線", systemImage: "plus.circle")
                        }
                        Button {
                            showingPopularRoutes = true
                        } label: {
                            Label("熱門航線", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddFlightGoalView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingPopularRoutes) {
                PopularRoutesView(viewModel: viewModel)
            }
        }
    }
}

// 詳細航線目標卡片
struct DetailedFlightGoalCard: View {
    @Environment(\.colorScheme) var colorScheme
    let goal: FlightGoal
    let currentMiles: Int
    let onTogglePriority: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var progress: Double {
        goal.progress(currentMiles: currentMiles)
    }
    
    var milesNeeded: Int {
        goal.milesNeeded(currentMiles: currentMiles)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題列
            HStack {
                if goal.isPriority {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(goal.originName)
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(goal.destinationName)
                            .font(.headline)
                    }
                    Text("\(goal.origin) → \(goal.destination)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button {
                        onTogglePriority()
                    } label: {
                        Label(
                            goal.isPriority ? "取消釘選" : "釘選至儀表板",
                            systemImage: goal.isPriority ? "pin.slash" : "pin.fill"
                        )
                    }
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // 艙等與哩程需求
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Label(goal.cabinClass.rawValue, systemImage: goal.cabinClass.icon)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(8)
                    
                    if goal.isRoundTrip {
                        Label("來回", systemImage: "arrow.left.arrow.right")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .cornerRadius(8)
                    }
                    
                    if let distance = goal.flightDistance {
                        Label("\(distance.formatted()) 哩", systemImage: "ruler")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AviationTheme.Colors.successColor(colorScheme).opacity(0.15))
                            .foregroundStyle(AviationTheme.Colors.successColor(colorScheme))
                            .cornerRadius(8)
                    }
                    
                    if let category = goal.distanceCategory {
                        Text(category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    if goal.isOneworld {
                        Label("寰宇一家", systemImage: "globe")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .cornerRadius(8)
                        Text("⚠️ 所需哩程較高")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("所需哩程")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(goal.requiredMiles.formatted())")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
            }
            
            // 進度條
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                        
                        // 進度
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                        
                        // 飛機圖示
                        if progress > 0.05 {
                            Image(systemName: "airplane")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .offset(x: max(20, geometry.size.width * progress - 30))
                        }
                    }
                }
                .frame(height: 32)
                
                HStack {
                    Text("\(currentMiles.formatted()) / \(goal.requiredMiles.formatted()) 哩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if milesNeeded > 0 {
                        Text("還需 \(milesNeeded.formatted()) 哩")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已達成")
                        }
                        .font(.caption)
                        .foregroundStyle(AviationTheme.Colors.successColor(colorScheme))
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .alert("確定要刪除此目標？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                onDelete()
            }
        }
    }
}

// 新增航線目標視圖
struct AddFlightGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("preferredOrigin") private var preferredOrigin: String = "TPE"
    
    @State private var selectedOrigin: Airport?
    @State private var selectedDestination: Airport?
    @State private var cabinClass: CabinClass = .economy
    @State private var isOneworld = false
    @State private var isPriority = false
    @State private var isRoundTrip = false
    @State private var showingOriginPicker = false
    @State private var showingDestinationPicker = false
    
    private var airports = AirportDatabase.shared.getAllAirports()
    
    init(viewModel: MileageViewModel) {
        self.viewModel = viewModel
    }
    
    private var calculatedMiles: Int? {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode,
              let miles = CathayAwardChart.requiredMiles(from: origin, to: destination, cabinClass: cabinClass) else {
            return nil
        }
        return isRoundTrip ? miles * 2 : miles
    }
    
    private var flightDistance: Int? {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode else {
            return nil
        }
        return AirportDatabase.shared.calculateDistance(from: origin, to: destination)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingOriginPicker = true
                    } label: {
                        HStack {
                            Text("出發地")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let airport = selectedOrigin {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(airport.iataCode)
                                        .fontWeight(.semibold)
                                    Text(airport.cityName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("請選擇")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        showingDestinationPicker = true
                    } label: {
                        HStack {
                            Text("目的地")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let airport = selectedDestination {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(airport.iataCode)
                                        .fontWeight(.semibold)
                                    Text(airport.cityName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("請選擇")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("航線")
                }
                
                Section {
                    Picker("艙等", selection: $cabinClass) {
                        ForEach(CabinClass.allCases, id: \.self) { cabin in
                            Label(cabin.rawValue, systemImage: cabin.icon)
                                .tag(cabin)
                        }
                    }
                    
                    Toggle(isOn: $isRoundTrip) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.blue)
                            Text("來回程")
                        }
                    }
                } header: {
                    Text("艙等")
                } footer: {
                    if isRoundTrip {
                        Text("來回程所需哩程為單程的兩倍")
                            .font(.caption)
                    }
                }
                
                if let distance = flightDistance, let miles = calculatedMiles {
                    Section {
                        HStack {
                            Text("飛行距離")
                            Spacer()
                            Text("\(distance.formatted()) 哩")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let origin = selectedOrigin?.iataCode,
                           let destination = selectedDestination?.iataCode,
                           let dist = AirportDatabase.shared.calculateDistance(from: origin, to: destination) {
                            let zone = FlightCalculator.determineZone(distance: dist, destinationCode: destination)
                            HStack {
                                Text("航距級別")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(zone.rawValue)
                                        .foregroundStyle(.orange)
                                    Text(zone.distanceRange)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        HStack {
                            Text("所需哩程")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(miles.formatted())")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(AviationTheme.Colors.successColor(colorScheme))
                        }
                    } header: {
                        Text("航線資訊")
                    } footer: {
                        if isOneworld {
                            Text("⚠️ 注意：兌換寰宇一家夥伴航空所需哩程會比此數值更高")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("此為國泰航空自家航班兌換標準")
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    Toggle("寰宇一家夥伴航空", isOn: $isOneworld)
                    Toggle("釘選至儀表板", isOn: $isPriority)
                } footer: {
                    Text("寰宇一家包含日本航空、英國航空、美國航空等夥伴")
                        .font(.caption)
                }
            }
            .navigationTitle("新增航線目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveGoal()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingOriginPicker) {
                AirportPickerView(selectedAirport: $selectedOrigin, airports: airports)
            }
            .sheet(isPresented: $showingDestinationPicker) {
                AirportPickerView(selectedAirport: $selectedDestination, airports: airports)
            }
            .onAppear {
                // 如果尚未選擇出發地，且有設定常用出發地，則自動填入
                if selectedOrigin == nil {
                    selectedOrigin = AirportDatabase.shared.getAirport(iataCode: preferredOrigin)
                }
            }
        }
    }
    
    private var canSave: Bool {
        selectedOrigin != nil && selectedDestination != nil && calculatedMiles != nil
    }
    
    private func saveGoal() {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode else {
            return
        }
        
        let goal = FlightGoal(
            fromIATA: origin,
            toIATA: destination,
            cabinClass: cabinClass,
            isOneworld: isOneworld,
            isPriority: isPriority,
            isRoundTrip: isRoundTrip
        )
        
        viewModel.addFlightGoal(goal)
        dismiss()
    }
}

// 機場選擇器（支援直接輸入 IATA 代碼）
struct AirportPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAirport: Airport?
    let airports: [Airport]
    
    @State private var searchText = ""
    
    var filteredAirports: [Airport] {
        if searchText.isEmpty {
            return airports.prefix(50).map { $0 } // 只顯示前 50 個，避免列表太長
        } else {
            // 優先顯示 IATA 代碼完全匹配的結果
            let exactMatch = airports.filter { 
                $0.iataCode.uppercased() == searchText.uppercased()
            }
            
            if !exactMatch.isEmpty {
                return exactMatch
            }
            
            // 然後顯示部分匹配的結果
            return AirportDatabase.shared.searchAirports(query: searchText).prefix(50).map { $0 }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredAirports) { airport in
                        Button {
                            selectedAirport = airport
                            dismiss()
                        } label: {
                            AirportRowView(airport: airport, isSelected: selectedAirport?.id == airport.id)
                        }
                    }
                } header: {
                    if !searchText.isEmpty {
                        Text("搜尋結果")
                    } else {
                        Text("熱門機場")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("選擇機場")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .automatic, prompt: "搜尋機場名稱或代碼")
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
    }
}

// 機場列視圖
struct AirportRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let airport: Airport
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(airport.iataCode)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(colorScheme == .dark ? Color.blue.opacity(0.9) : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.1))
                        )
                    Text(airport.cityName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Text(airport.airportName)
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                HStack(spacing: 4) {
                    Text(airport.cityNameEN)
                        .font(.caption2)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    Text(airport.country)
                        .font(.caption2)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(colorScheme == .dark ? Color.blue.opacity(0.9) : .blue)
            }
        }
    }
}

// 熱門航線視圖
struct PopularRoutesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    
    let popularRoutes = FlightGoal.popularRoutes()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(popularRoutes, id: \.id) { route in
                    Button {
                        addRoute(route)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(route.originName) → \(route.destinationName)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Label(route.cabinClass.rawValue, systemImage: route.cabinClass.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(route.requiredMiles.formatted()) 哩")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("熱門航線")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addRoute(_ route: FlightGoal) {
        let newGoal = FlightGoal(
            fromIATA: route.origin,
            toIATA: route.destination,
            cabinClass: route.cabinClass,
            isOneworld: route.isOneworld,
            isPriority: false
        )
        viewModel.addFlightGoal(newGoal)
    }
}

#Preview {
    AllGoalsView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
