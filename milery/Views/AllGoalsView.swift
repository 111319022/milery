import SwiftUI
import SwiftData

struct AllGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @State private var showingAddGoal = false
    @State private var showingPopularRoutes = false
    @State private var editingGoal: FlightGoal?
    
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
                            
                            if viewModel.supportsCathayAwardChart {
                                Button {
                                    showingPopularRoutes = true
                                } label: {
                                    Label("瀏覽熱門航線", systemImage: "star.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
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
                                },
                                onEdit: {
                                    editingGoal = goal
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
                        if viewModel.supportsCathayAwardChart {
                            Button {
                                showingPopularRoutes = true
                            } label: {
                                Label("熱門航線", systemImage: "star")
                            }
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
            .sheet(item: $editingGoal) { goal in
                EditFlightGoalView(goal: goal, viewModel: viewModel)
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
    var onEdit: (() -> Void)? = nil
    
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
                        onEdit?()
                    } label: {
                        Label("編輯目標", systemImage: "pencil")
                    }
                    Button {
                        onTogglePriority()
                    } label: {
                        Label(
                            goal.isPriority ? "取消釘選" : "釘選至儀表板",
                            systemImage: goal.isPriority ? "pin.slash" : "pin.fill"
                        )
                    }
                    Divider()
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
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
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
    @AppStorage("preferredOrigin") private var preferredOrigin: String = ""
    
    @State private var selectedOrigin: Airport?
    @State private var selectedDestination: Airport?
    @State private var cabinClass: CabinClass = .economy
    @State private var isPriority = false
    @State private var isRoundTrip = false
    @State private var showingOriginPicker = false
    @State private var showingDestinationPicker = false
    @State private var manualMilesInput: String = ""
    @FocusState private var isManualMilesFocused: Bool
    
    private var airports = AirportDatabase.shared.getAllAirports()
    
    init(viewModel: MileageViewModel) {
        self.viewModel = viewModel
    }
    
    /// 判斷是否為國泰可自動計算的航線（起點台北 + 目的地在國泰航點表內 + 當前計劃支援）
    private var isCathayAutoRoute: Bool {
        guard viewModel.supportsCathayAwardChart,
              let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode else { return false }
        return origin.uppercased() == "TPE" && FlightCalculator.isCathayRouteFromTPE(destination: destination)
    }
    
    /// 起點為台北但目的地不在國泰航點表 → 需兌換寰宇一家夥伴
    private var isOneworldRequired: Bool {
        guard viewModel.supportsCathayAwardChart,
              let origin = selectedOrigin?.iataCode,
              selectedDestination != nil else { return false }
        return origin.uppercased() == "TPE" && !isCathayAutoRoute
    }
    
    /// 起點非台北或非國泰計劃 → 一律手動輸入
    private var isNonTPEOrigin: Bool {
        guard let origin = selectedOrigin?.iataCode else { return false }
        return origin.uppercased() != "TPE" || !viewModel.supportsCathayAwardChart
    }
    
    /// 是否需要使用者手動輸入哩程
    private var needsManualMiles: Bool {
        return isOneworldRequired || isNonTPEOrigin
    }
    
    /// 自動計算的哩程（僅國泰台北航線且當前計劃支援）
    private var autoCathayMiles: Int? {
        guard isCathayAutoRoute,
              let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode,
              let miles = CathayAwardChart.requiredMiles(from: origin, to: destination, cabinClass: cabinClass) else {
            return nil
        }
        return isRoundTrip ? miles * 2 : miles
    }
    
    /// 手動輸入的哩程
    private var manualMiles: Int? {
        guard let value = Int(manualMilesInput), value > 0 else { return nil }
        return isRoundTrip ? value * 2 : value
    }
    
    /// 最終使用的哩程（自動或手動）
    private var finalMiles: Int? {
        if isCathayAutoRoute { return autoCathayMiles }
        return manualMiles
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
                // 航線選擇
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
                
                // 艙等設定
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
                
                // 寰宇一家夥伴提醒（台北出發但不在國泰航點表）
                if selectedOrigin != nil && selectedDestination != nil && isOneworldRequired {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "globe.asia.australia.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("需兌換寰宇一家夥伴航空")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                Text("此航線非國泰航空直飛，需透過日航、英航等夥伴航空兌換，所需哩程較高")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("所需哩程（單程）")
                            Spacer()
                            TextField("輸入哩程", text: $manualMilesInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .focused($isManualMilesFocused)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isManualMilesFocused = true }
                    } header: {
                        Text("哩程設定")
                    } footer: {
                        if isRoundTrip, let miles = manualMiles {
                            Text("來回程合計：\(miles.formatted()) 哩")
                                .font(.caption)
                        }
                    }
                }
                
                // 非台北出發 → 一律手動輸入
                if selectedOrigin != nil && selectedDestination != nil && isNonTPEOrigin {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自訂哩程")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("出發地非台北，請自行查詢並輸入所需哩程")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("所需哩程（單程）")
                            Spacer()
                            TextField("輸入哩程", text: $manualMilesInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .focused($isManualMilesFocused)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isManualMilesFocused = true }
                    } header: {
                        Text("哩程設定")
                    } footer: {
                        if isRoundTrip, let miles = manualMiles {
                            Text("來回程合計：\(miles.formatted()) 哩")
                                .font(.caption)
                        }
                    }
                }
                
                // 國泰自動計算的航線資訊
                if isCathayAutoRoute, let distance = flightDistance, let miles = autoCathayMiles {
                    Section {
                        HStack {
                            Text("飛行距離")
                            Spacer()
                            Text("\(distance.formatted()) 哩")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let destination = selectedDestination?.iataCode {
                            let zone = FlightCalculator.determineZone(distance: distance, destinationCode: destination)
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
                        Text("此為國泰航空自家航班兌換標準")
                            .font(.caption)
                    }
                }
                
                // 其他設定
                Section {
                    Toggle("釘選至儀表板", isOn: $isPriority)
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
                if selectedOrigin == nil && !preferredOrigin.isEmpty {
                    selectedOrigin = AirportDatabase.shared.getAirport(iataCode: preferredOrigin)
                }
            }
        }
    }
    
    private var canSave: Bool {
        guard selectedOrigin != nil, selectedDestination != nil else { return false }
        return finalMiles != nil && (finalMiles ?? 0) > 0
    }
    
    private func saveGoal() {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode,
              let miles = finalMiles else { return }
        
        let originAirport = AirportDatabase.shared.getAirport(iataCode: origin)
        let destinationAirport = AirportDatabase.shared.getAirport(iataCode: destination)
        
        let goal = FlightGoal(
            origin: origin.uppercased(),
            destination: destination.uppercased(),
            originName: originAirport?.cityName ?? origin,
            destinationName: destinationAirport?.cityName ?? destination,
            cabinClass: cabinClass,
            requiredMiles: miles,
            isOneworld: isOneworldRequired,
            isPriority: isPriority,
            isRoundTrip: isRoundTrip
        )
        
        viewModel.addFlightGoal(goal)
        dismiss()
    }
}

// 編輯航線目標視圖
struct EditFlightGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let goal: FlightGoal
    @Bindable var viewModel: MileageViewModel
    
    @State private var selectedOrigin: Airport?
    @State private var selectedDestination: Airport?
    @State private var cabinClass: CabinClass
    @State private var isPriority: Bool
    @State private var isRoundTrip: Bool
    @State private var manualMilesInput: String
    @State private var showingOriginPicker = false
    @State private var showingDestinationPicker = false
    @State private var showingDeleteAlert = false
    @FocusState private var isManualMilesFocused: Bool
    
    private var airports = AirportDatabase.shared.getAllAirports()
    
    /// 判斷是否為國泰可自動計算的航線（起點台北 + 目的地在國泰航點表內 + 當前計劃支援）
    private var isCathayAutoRoute: Bool {
        guard viewModel.supportsCathayAwardChart,
              let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode else { return false }
        return origin.uppercased() == "TPE" && FlightCalculator.isCathayRouteFromTPE(destination: destination)
    }
    
    /// 起點為台北但目的地不在國泰航點表 → 需兌換寰宇一家夥伴
    private var isOneworldRequired: Bool {
        guard viewModel.supportsCathayAwardChart,
              let origin = selectedOrigin?.iataCode,
              selectedDestination != nil else { return false }
        return origin.uppercased() == "TPE" && !isCathayAutoRoute
    }
    
    /// 起點非台北或非國泰計劃 → 一律手動輸入
    private var isNonTPEOrigin: Bool {
        guard let origin = selectedOrigin?.iataCode else { return false }
        return origin.uppercased() != "TPE" || !viewModel.supportsCathayAwardChart
    }
    
    /// 是否需要使用者手動輸入哩程
    private var needsManualMiles: Bool {
        return isOneworldRequired || isNonTPEOrigin
    }
    
    /// 自動計算的哩程（僅國泰台北航線且當前計劃支援）
    private var autoCathayMiles: Int? {
        guard isCathayAutoRoute,
              let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode,
              let miles = CathayAwardChart.requiredMiles(from: origin, to: destination, cabinClass: cabinClass) else {
            return nil
        }
        return isRoundTrip ? miles * 2 : miles
    }
    
    /// 手動輸入的哩程
    private var manualMiles: Int? {
        guard let value = Int(manualMilesInput), value > 0 else { return nil }
        return isRoundTrip ? value * 2 : value
    }
    
    /// 最終使用的哩程
    private var finalMiles: Int? {
        if isCathayAutoRoute { return autoCathayMiles }
        return manualMiles
    }
    
    private var flightDistance: Int? {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode else {
            return nil
        }
        return AirportDatabase.shared.calculateDistance(from: origin, to: destination)
    }
    
    init(goal: FlightGoal, viewModel: MileageViewModel) {
        self.goal = goal
        self.viewModel = viewModel
        
        // 初始化編輯狀態
        _selectedOrigin = State(initialValue: AirportDatabase.shared.getAirport(iataCode: goal.origin))
        _selectedDestination = State(initialValue: AirportDatabase.shared.getAirport(iataCode: goal.destination))
        _cabinClass = State(initialValue: goal.cabinClass)
        _isPriority = State(initialValue: goal.isPriority)
        _isRoundTrip = State(initialValue: goal.isRoundTrip)
        
        // 如果不是國泰自動航線（或非國泰計劃），需要反推單程哩程作為手動輸入初始值
        let isAuto = viewModel.supportsCathayAwardChart && goal.origin.uppercased() == "TPE" && FlightCalculator.isCathayRouteFromTPE(destination: goal.destination)
        if !isAuto {
            let singleMiles = goal.isRoundTrip ? goal.requiredMiles / 2 : goal.requiredMiles
            _manualMilesInput = State(initialValue: "\(singleMiles)")
        } else {
            _manualMilesInput = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 航線選擇
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
                
                // 艙等設定
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
                
                // 寰宇一家夥伴提醒（台北出發但不在國泰航點表）
                if selectedOrigin != nil && selectedDestination != nil && isOneworldRequired {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "globe.asia.australia.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("需兌換寰宇一家夥伴航空")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                Text("此航線非國泰航空直飛，需透過日航、英航等夥伴航空兌換，所需哩程較高")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("所需哩程（單程）")
                            Spacer()
                            TextField("輸入哩程", text: $manualMilesInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .focused($isManualMilesFocused)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isManualMilesFocused = true }
                    } header: {
                        Text("哩程設定")
                    } footer: {
                        if isRoundTrip, let miles = manualMiles {
                            Text("來回程合計：\(miles.formatted()) 哩")
                                .font(.caption)
                        }
                    }
                }
                
                // 非台北出發 → 一律手動輸入
                if selectedOrigin != nil && selectedDestination != nil && isNonTPEOrigin {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自訂哩程")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("出發地非台北，請自行查詢並輸入所需哩程")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("所需哩程（單程）")
                            Spacer()
                            TextField("輸入哩程", text: $manualMilesInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .focused($isManualMilesFocused)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { isManualMilesFocused = true }
                    } header: {
                        Text("哩程設定")
                    } footer: {
                        if isRoundTrip, let miles = manualMiles {
                            Text("來回程合計：\(miles.formatted()) 哩")
                                .font(.caption)
                        }
                    }
                }
                
                // 國泰自動計算的航線資訊
                if isCathayAutoRoute, let distance = flightDistance, let miles = autoCathayMiles {
                    Section {
                        HStack {
                            Text("飛行距離")
                            Spacer()
                            Text("\(distance.formatted()) 哩")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let destination = selectedDestination?.iataCode {
                            let zone = FlightCalculator.determineZone(distance: distance, destinationCode: destination)
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
                        Text("此為國泰航空自家航班兌換標準")
                            .font(.caption)
                    }
                }
                
                // 其他設定
                Section {
                    Toggle("釘選至儀表板", isOn: $isPriority)
                }
                
                // 刪除按鈕
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("刪除此目標", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("編輯目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveChanges()
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
            .alert("確定要刪除此目標？", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    viewModel.deleteFlightGoal(goal)
                    dismiss()
                }
            } message: {
                Text("刪除後將無法復原")
            }
        }
    }
    
    private var canSave: Bool {
        guard selectedOrigin != nil, selectedDestination != nil else { return false }
        return finalMiles != nil && (finalMiles ?? 0) > 0
    }
    
    private func saveChanges() {
        guard let origin = selectedOrigin?.iataCode,
              let destination = selectedDestination?.iataCode,
              let miles = finalMiles else { return }
        
        let originAirport = AirportDatabase.shared.getAirport(iataCode: origin)
        let destinationAirport = AirportDatabase.shared.getAirport(iataCode: destination)
        
        goal.origin = origin.uppercased()
        goal.destination = destination.uppercased()
        goal.originName = originAirport?.cityName ?? origin
        goal.destinationName = destinationAirport?.cityName ?? destination
        goal.cabinClass = cabinClass
        goal.isPriority = isPriority
        goal.isRoundTrip = isRoundTrip
        goal.requiredMiles = miles
        goal.isOneworld = isOneworldRequired
        
        viewModel.saveContext()
        viewModel.loadData()
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
    
    var popularAirports: [Airport] {
        AirportDatabase.shared.getPopularAirports()
    }
    
    var searchResults: [Airport] {
        guard !searchText.isEmpty else { return [] }
        
        let exactMatch = airports.filter {
            $0.iataCode.uppercased() == searchText.uppercased()
        }
        if !exactMatch.isEmpty {
            return exactMatch
        }
        return AirportDatabase.shared.searchAirports(query: searchText).prefix(50).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        ForEach(popularAirports) { airport in
                            Button {
                                selectedAirport = airport
                                dismiss()
                            } label: {
                                AirportRowView(airport: airport, isSelected: selectedAirport?.id == airport.id)
                            }
                        }
                    } header: {
                        Text("熱門機場")
                    }
                    
                    Section {
                        ForEach(airports.filter { airport in
                            !AirportDatabase.popularIATACodes.contains(airport.iataCode)
                        }) { airport in
                            Button {
                                selectedAirport = airport
                                dismiss()
                            } label: {
                                AirportRowView(airport: airport, isSelected: selectedAirport?.id == airport.id)
                            }
                        }
                    } header: {
                        Text("所有機場")
                    }
                } else {
                    Section {
                        ForEach(searchResults) { airport in
                            Button {
                                selectedAirport = airport
                                dismiss()
                            } label: {
                                AirportRowView(airport: airport, isSelected: selectedAirport?.id == airport.id)
                            }
                        }
                    } header: {
                        Text("搜尋結果")
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
