import SwiftUI
import SwiftData

struct ProgressView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @State private var showingAddGoal = false
    @State private var selectedGoalIndex = 0
    @State private var isEditingOrder = false
    @State private var editingGoal: FlightGoal? = nil
    @State private var editingPinnedGoals: [FlightGoal] = []
    @State private var editingUnpinnedGoals: [FlightGoal] = []
    
    private var hasBackgroundImage: Bool {
        backgroundSelection != .none
    }
    
    var currentMiles: Int {
        viewModel.mileageAccount?.totalMiles ?? 0
    }
    
    /// 半圓進度條顯示的目標列表
    /// 有釘選 → 所有釘選目標（依 sortOrder）；無釘選 → 第一個目標
    var heroGoals: [FlightGoal] {
        let pinned = viewModel.flightGoals.filter { $0.isPriority }
        if !pinned.isEmpty {
            return pinned.sorted { $0.sortOrder < $1.sortOrder }
        }
        // 無釘選時，顯示第一個目標
        if let first = viewModel.flightGoals.sorted(by: { $0.createdDate < $1.createdDate }).first {
            return [first]
        }
        return []
    }
    
    /// 所有目標列表（釘選永遠在最上面，各自依 sortOrder 排序）
    var orderedGoals: [FlightGoal] {
        let pinned = viewModel.flightGoals.filter { $0.isPriority }
            .sorted { $0.sortOrder < $1.sortOrder }
        let unpinned = viewModel.flightGoals.filter { !$0.isPriority }
            .sorted { $0.sortOrder < $1.sortOrder }
        return pinned + unpinned
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.md) {
                        // 主視覺：飛機模型與進度圓環
                        mainProgressSection
                        
                        // 所有目標列表
                        allGoalsSection
                    }
                    .padding(.bottom, AviationTheme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("進度")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddFlightGoalView(viewModel: viewModel)
            }
            .sheet(isPresented: $isEditingOrder) {
                GoalReorderSheet(
                    pinnedGoals: $editingPinnedGoals,
                    unpinnedGoals: $editingUnpinnedGoals,
                    colorScheme: colorScheme,
                    onDone: {
                        for (i, g) in editingPinnedGoals.enumerated() { g.sortOrder = i }
                        for (i, g) in editingUnpinnedGoals.enumerated() { g.sortOrder = i }
                        viewModel.saveContext()
                        viewModel.loadData()
                        isEditingOrder = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingGoal) { goal in
                EditFlightGoalView(goal: goal, viewModel: viewModel)
            }
            .onChange(of: showingAddGoal) { oldValue, newValue in
                if !newValue {
                    // Sheet 關閉時重新載入數據
                    viewModel.loadData()
                }
            }
            .onChange(of: editingGoal) { oldValue, newValue in
                if newValue == nil {
                    viewModel.loadData()
                }
            }
        }
    }
    
    // MARK: - 主視覺區域
    private var mainProgressSection: some View {
        VStack(spacing: 0) {
            if heroGoals.isEmpty {
                emptyProgressView
                    .frame(height: 250)
            } else if heroGoals.count == 1 {
                HalfCircleProgressView(
                    goal: heroGoals[0],
                    currentMiles: currentMiles,
                    colorScheme: colorScheme
                )
                .frame(height: 250)
            } else {
                TabView(selection: $selectedGoalIndex) {
                    ForEach(Array(heroGoals.enumerated()), id: \.element.id) { index, goal in
                        HalfCircleProgressView(
                            goal: goal,
                            currentMiles: currentMiles,
                            colorScheme: colorScheme
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 250)
            }
            
            // 飛機圖片佈局（固定不動）
            Image("CathayPacific_plane")
                .resizable()
                .scaledToFit()
                .frame(width: 350)
                .padding(.top, -25)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
        .background {
            if hasBackgroundImage {
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl)
                    .fill(.ultraThinMaterial)
                    .padding(.horizontal, AviationTheme.Spacing.sm)
            }
        }
    }
    
    private var emptyProgressView: some View {
        // 使用底層對齊的 ZStack 取代 offset
        ZStack(alignment: .bottom) {
            HalfCirclePath()
                .stroke(
                    AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 320, height: 160)
                .padding(.horizontal, 7)
                .padding(.top, 7)
            
            VStack(spacing: 6) {
                Text("尚未設定目標")
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                
                Text("點擊右上角 + 新增航線目標")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(.bottom, 30) // 讓文字貼齊圓心底部上方
        }
        .padding(.bottom, 35)
    }
    
    // MARK: - 所有目標列表
    private var allGoalsSection: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題列 + 編輯順序按鈕
            HStack {
                Text("所有目標")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    .padding(.horizontal, hasBackgroundImage ? 12 : 0)
                    .padding(.vertical, hasBackgroundImage ? 4 : 0)
                    .background {
                        if hasBackgroundImage {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                    }
                
                Spacer()
                
                if !viewModel.flightGoals.isEmpty {
                    Button {
                        editingPinnedGoals = viewModel.flightGoals
                            .filter { $0.isPriority }
                            .sorted { $0.sortOrder < $1.sortOrder }
                        editingUnpinnedGoals = viewModel.flightGoals
                            .filter { !$0.isPriority }
                            .sorted { $0.sortOrder < $1.sortOrder }
                        isEditingOrder = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.caption)
                            Text("編輯順序")
                                .font(AviationTheme.Typography.caption)
                        }
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(AviationTheme.Colors.cathayJade.opacity(0.12))
                        )
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            if viewModel.flightGoals.isEmpty {
                VStack(spacing: AviationTheme.Spacing.md) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 48))
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    
                    Text("還沒有任何目標")
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                    Text("開始規劃您的夢想旅程")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.xxl)
                .background(AviationTheme.Colors.cardBackground(colorScheme))
                .cornerRadius(AviationTheme.CornerRadius.md)
                .padding(.horizontal, AviationTheme.Spacing.md)
            } else {
                // 正常模式：顯示完整卡片
                VStack(spacing: AviationTheme.Spacing.sm) {
                    ForEach(orderedGoals) { goal in
                        GoalProgressCard(
                            goal: goal,
                            viewModel: viewModel,
                            colorScheme: colorScheme,
                            onEdit: { editingGoal = goal }
                        )
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
            }
        }
    }
}

// MARK: - 半圓進度條元件
struct HalfCircleProgressView: View {
    let goal: FlightGoal
    let currentMiles: Int
    let colorScheme: ColorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    
    private let arcDiameter: CGFloat = 320
    private let strokeWidth: CGFloat = 14
    private var radius: CGFloat { arcDiameter / 2 }
    
    @State private var animatedProgress: Double = 0
    @State private var hasAppeared = false
    
    private var hasBackgroundImage: Bool {
        backgroundSelection != .none
    }
    
    private var targetProgress: Double {
        min(goal.progress(currentMiles: currentMiles), 1.0)
    }
    
    /// 有背景圖片時使用更深的顏色以確保在毛玻璃上可讀
    private var subtitleColor: Color {
        hasBackgroundImage ? AviationTheme.Colors.primaryText(colorScheme) : AviationTheme.Colors.secondaryText(colorScheme)
    }
    
    private var captionColor: Color {
        hasBackgroundImage ? AviationTheme.Colors.secondaryText(colorScheme) : AviationTheme.Colors.tertiaryText(colorScheme)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 背景軌道與進度條
            ZStack {
                HalfCirclePath()
                    .stroke(
                        AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                
                HalfCirclePath()
                    .trim(from: 0, to: max(animatedProgress, 0.001))
                    .stroke(
                        LinearGradient(
                            colors: [
                                AviationTheme.Colors.cathayJade,
                                AviationTheme.Colors.cathayJadeLight
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .animation(.easeOut(duration: 1.0), value: animatedProgress)
            }
            .frame(width: arcDiameter, height: radius)
            .padding(.horizontal, strokeWidth / 2)
            .padding(.top, strokeWidth / 2)
            
            // 2. 文字資訊
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("\(goal.originName) (\(goal.origin))")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(subtitleColor)
                    
                    Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                        .font(.caption2)
                        .foregroundColor(subtitleColor)
                    
                    Text("\(goal.destinationName) (\(goal.destination))")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(currentMiles)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    Text("/")
                        .font(AviationTheme.Typography.title3)
                        .foregroundColor(subtitleColor)
                    Text("\(goal.requiredMiles)")
                        .font(AviationTheme.Typography.title2)
                        .foregroundColor(subtitleColor)
                    Text("哩")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(captionColor)
                }
                
                Text("\(Int(targetProgress * 100))%")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.cathayJade.opacity(0.15))
                    )
            }
            .offset(y: 12)
        }
        .padding(.bottom, 35)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: targetProgress) {
            animatedProgress = targetProgress
        }
    }
}

// 自訂繪製的半圓形 Path
struct HalfCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = rect.width / 2
        
        // 畫一個從左（180度）到右（0度）的上半圓
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        return path
    }
}

// MARK: - 目標排序 Sheet
struct GoalReorderSheet: View {
    @Binding var pinnedGoals: [FlightGoal]
    @Binding var unpinnedGoals: [FlightGoal]
    let colorScheme: ColorScheme
    let onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if !pinnedGoals.isEmpty {
                    Section {
                        ForEach(pinnedGoals) { goal in
                            GoalReorderRow(goal: goal, isPinned: true)
                        }
                        .onMove { source, destination in
                            pinnedGoals.move(fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Label("釘選目標", systemImage: "pin.fill")
                            .font(.caption)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                    }
                }
                
                if !unpinnedGoals.isEmpty {
                    Section {
                        ForEach(unpinnedGoals) { goal in
                            GoalReorderRow(goal: goal, isPinned: false)
                        }
                        .onMove { source, destination in
                            unpinnedGoals.move(fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Label("其他目標", systemImage: "location.fill")
                            .font(.caption)
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(6)
            .contentMargins(.horizontal, 16)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("排列順序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 排序用的目標行
struct GoalReorderRow: View {
    @Environment(\.colorScheme) var colorScheme
    let goal: FlightGoal
    let isPinned: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(goal.originName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(goal.destinationName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text("\(goal.cabinClass.rawValue) · \(goal.requiredMiles) 哩")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(AviationTheme.Colors.cardBackground(colorScheme))
                .padding(.vertical, 2)
        )
    }
}

// MARK: - 目標進度卡片
struct GoalProgressCard: View {
    let goal: FlightGoal
    let viewModel: MileageViewModel
    let colorScheme: ColorScheme
    var onEdit: (() -> Void)? = nil
    
    @State private var showingDeleteAlert = false
    @State private var showingRedeemSheet = false
    @State private var showingActions = false
    @State private var actionPopoverEdge: Edge = .top
    @State private var actionButtonFrame: CGRect = .zero
    @State private var animatedProgress: Double = 0
    @State private var hasAppeared = false
    
    var currentMiles: Int {
        viewModel.mileageAccount?.totalMiles ?? 0
    }

    var isRedeemable: Bool {
        goal.progress(currentMiles: currentMiles) >= 1.0
    }
    
    private var targetProgress: Double {
        min(goal.progress(currentMiles: currentMiles), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 頂部：目標資訊
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: goal.isPriority ? "pin.fill" : "location.fill")
                                .foregroundColor(goal.isPriority ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.secondaryText(colorScheme))
                                .font(.caption)

                            Text("\(goal.originName) (\(goal.origin))")
                                .font(AviationTheme.Typography.subheadline)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))

                            Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                                .font(.caption2)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))

                            Text("\(goal.destinationName) (\(goal.destination))")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        }

                        Text("\(goal.cabinClass.rawValue)")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.trailing, 36)

                Button {
                    let screenHeight = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.screen.bounds.height ?? 800
                    let estimatedMenuHeight: CGFloat = 190
                    let availableBelow = screenHeight - actionButtonFrame.maxY
                    actionPopoverEdge = availableBelow < estimatedMenuHeight ? .bottom : .top
                    showingActions = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        .font(.title3)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                actionButtonFrame = proxy.frame(in: .global)
                            }
                            .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                                actionButtonFrame = newFrame
                            }
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .popover(isPresented: $showingActions, attachmentAnchor: .rect(.bounds), arrowEdge: actionPopoverEdge) {
                    VStack(spacing: 0) {
                        Button {
                            showingActions = false
                            onEdit?()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 18)
                                Text("編輯目標")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)

                        Button {
                            showingActions = false
                            let targetGroup = viewModel.flightGoals.filter { $0.isPriority == !goal.isPriority }
                            let maxOrder = targetGroup.map { $0.sortOrder }.max() ?? -1
                            goal.sortOrder = maxOrder + 1
                            goal.isPriority.toggle()
                            viewModel.saveContext()
                            viewModel.loadData()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: goal.isPriority ? "pin.slash" : "pin.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 18)
                                Text(goal.isPriority ? "取消釘選" : "釘選至進度")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)

                        Divider()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)

                        Button(role: .destructive) {
                            showingActions = false
                            showingDeleteAlert = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 18)
                                Text("刪除目標")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }
                    .frame(width: 210)
                    .presentationCompactAdaptation(.popover)
                }
            }
            
            // 進度條
            VStack(alignment: .leading, spacing: AviationTheme.Spacing.xs) {
                HStack {
                    Text("\(currentMiles) / \(goal.requiredMiles) 哩")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Spacer()
                    
                    Text("\(Int(targetProgress * 100))%")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AviationTheme.Colors.cathayJade,
                                        AviationTheme.Colors.cathayJadeLight
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedProgress, height: 8)
                            .animation(.easeOut(duration: 0.7), value: animatedProgress)
                    }
                }
                .frame(height: 8)
            }

            if isRedeemable {
                Button {
                    showingRedeemSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                        Text("立即兌換機票")
                            .fontWeight(.bold)
                    }
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                            .fill(AviationTheme.Gradients.cathayJadeGradient(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: AviationTheme.Colors.cathayJade.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AviationTheme.Spacing.md)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .stroke(
                    goal.isPriority ? AviationTheme.Colors.cathayJade.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.originName)到\(goal.destinationName)，\(goal.cabinClass.rawValue)，進度 \(Int(goal.progress(currentMiles: currentMiles) * 100))%，\(currentMiles) / \(goal.requiredMiles) 哩")
        .onTapGesture {
            onEdit?()
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: targetProgress) {
            animatedProgress = targetProgress
        }
        .alert("確定要刪除此目標？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                viewModel.deleteFlightGoal(goal)
            }
        } message: {
            Text("刪除後將無法復原")
        }
        .sheet(isPresented: $showingRedeemSheet) {
            RedeemTicketSheet(
                goal: goal,
                viewModel: viewModel,
                isPresented: $showingRedeemSheet
            )
        }
    }
}

struct RedeemTicketSheet: View {
    let goal: FlightGoal
    let viewModel: MileageViewModel
    @Binding var isPresented: Bool

    @State private var flightDate: Date = Date()
    @State private var pnr: String = ""
    @State private var taxPaidText: String = ""
    @State private var airline: String = ""
    @State private var flightNumber: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("航班資訊") {
                    DatePicker("搭乘日期", selection: $flightDate, displayedComponents: [.date])

                    TextField("訂位代號 (PNR)", text: $pnr)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("航空公司（選填）", text: $airline)
                        .autocorrectionDisabled()

                    TextField("航班編號（選填）", text: $flightNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("稅金與附加費", text: $taxPaidText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    HStack {
                        Text("航線")
                        Spacer()
                        Text("\(goal.origin) → \(goal.destination)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("艙等")
                        Spacer()
                        Text(goal.cabinClass.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("扣除哩程")
                        Spacer()
                        Text("\(goal.requiredMiles) 哩")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("兌換機票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("確認兌換") {
                        let taxPaid = Decimal(string: taxPaidText.replacingOccurrences(of: ",", with: "")) ?? 0
                        viewModel.redeemGoal(
                            goal: goal,
                            flightDate: flightDate,
                            pnr: pnr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            taxPaid: taxPaid,
                            airline: airline.trimmingCharacters(in: .whitespacesAndNewlines),
                            flightNumber: flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        )
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProgressView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}
