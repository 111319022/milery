//
//  ProgressView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct ProgressView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @State private var showingAddGoal = false
    
    var pinnedGoals: [FlightGoal] {
        viewModel.flightGoals.filter { $0.isPriority }
    }
    
    var currentMiles: Int {
        viewModel.mileageAccount?.totalMiles ?? 0
    }
    
    var nextGoal: FlightGoal? {
        pinnedGoals.sorted { $0.progress(currentMiles: currentMiles) > $1.progress(currentMiles: currentMiles) }.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 航空風格背景
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    // ✈️ 修改重點 1：將原本的 .xl spacing 增大，並明確調整頂部 padding
                    VStack(spacing: AviationTheme.Spacing.xl) {
                        // 主視覺：飛機模型與進度圓環
                        mainProgressSection
                        
                        // 所有目標列表
                        allGoalsSection
                    }
                    // 這裡修改：增加頂部 Padding，將整個內容往下推，拉開與 Navigation Title 的距離
                    .padding(.top, AviationTheme.Spacing.xl + 10)
                    .padding(.bottom, AviationTheme.Spacing.lg)
                }
            }
            .navigationTitle("進度")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                AviationTheme.Colors.background(colorScheme).opacity(0.95),
                for: .navigationBar
            )
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
            .onChange(of: showingAddGoal) { oldValue, newValue in
                if !newValue {
                    // Sheet 關閉時重新載入數據
                    viewModel.loadData()
                }
            }
        }
    }
    
    // MARK: - 主視覺區域
    private var mainProgressSection: some View {
        VStack(spacing: 0) {
            // 上半圓進度條（內含文字）
            ZStack {
                // 背景軌道（上半圓）
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(
                        AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2),
                        lineWidth: 14
                    )
                    .frame(width: 300, height: 300)
                    .rotationEffect(.degrees(180))
                
                // 進度填充（上半圓）
                if let goal = nextGoal {
                    Circle()
                        .trim(from: 0, to: min(goal.progress(currentMiles: currentMiles), 1.0) * 0.5)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AviationTheme.Colors.cathayJade,
                                    AviationTheme.Colors.cathayJadeLight
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(180))
                        .animation(.easeInOut(duration: 1.0), value: goal.progress(currentMiles: currentMiles))
                }
                
                // 文字資訊（放在半圓中間）
                if let goal = nextGoal {
                    VStack(spacing: 4) {
                        // 航線
                        HStack(spacing: 4) {
                            Text("\(goal.originName) (\(goal.origin))")
                                .font(AviationTheme.Typography.subheadline)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            
                            Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                                .font(.caption2)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            
                            Text("\(goal.destinationName) (\(goal.destination))")
                                .font(AviationTheme.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        }
                        
                        // 哩程進度
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(currentMiles)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                            Text("/")
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            Text("\(goal.requiredMiles)")
                                .font(AviationTheme.Typography.title3)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            Text("哩")
                                .font(AviationTheme.Typography.subheadline)
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        }
                        
                        // 進度百分比
                        Text("\(Int(goal.progress(currentMiles: currentMiles) * 100))%")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AviationTheme.Colors.cathayJade.opacity(0.15))
                            )
                    }
                    .offset(y: -30)
                } else {
                    VStack(spacing: 6) {
                        Text("尚未設定目標")
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        
                        Text("點擊右上角 + 新增航線目標")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .offset(y: -30)
                }
            }
            .frame(height: 150)
            .padding(.top, AviationTheme.Spacing.md)
            
            // 飛機圖片佈局
            Image("CathayPacific_plane")
                .resizable()
                .scaledToFit()
                // 將飛機寬度
                .frame(width: 350)
                // 貼和程度
                .padding(.top, -35)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    // MARK: - 所有目標列表
    private var allGoalsSection: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            Text("所有目標")
                .font(AviationTheme.Typography.headline)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                VStack(spacing: AviationTheme.Spacing.sm) {
                    ForEach(viewModel.flightGoals.sorted(by: { $0.isPriority && !$1.isPriority })) { goal in
                        GoalProgressCard(goal: goal, viewModel: viewModel, colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
            }
        }
    }
}

// MARK: - 目標進度卡片
struct GoalProgressCard: View {
    let goal: FlightGoal
    let viewModel: MileageViewModel
    let colorScheme: ColorScheme
    
    @State private var showingDeleteAlert = false
    
    var currentMiles: Int {
        viewModel.mileageAccount?.totalMiles ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 頂部：目標資訊
            HStack {
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
                
                Spacer()
                
                Menu {
                    Button {
                        goal.isPriority.toggle()
                        try? viewModel.modelContext?.save()
                        viewModel.loadData()
                    } label: {
                        Label(
                            goal.isPriority ? "取消釘選" : "釘選至進度",
                            systemImage: goal.isPriority ? "pin.slash" : "pin.fill"
                        )
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("刪除目標", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        .font(.title3)
                }
            }
            
            // 進度條
            VStack(alignment: .leading, spacing: AviationTheme.Spacing.xs) {
                HStack {
                    Text("\(currentMiles) / \(goal.requiredMiles) 哩")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Spacer()
                    
                    Text("\(Int(goal.progress(currentMiles: currentMiles) * 100))%")
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
                            .frame(width: geometry.size.width * min(goal.progress(currentMiles: currentMiles), 1.0), height: 8)
                            .animation(.easeInOut(duration: 0.5), value: goal.progress(currentMiles: currentMiles))
                    }
                }
                .frame(height: 8)
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
        .alert("確定要刪除此目標？", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                viewModel.deleteFlightGoal(goal)
            }
        } message: {
            Text("刪除後將無法復原")
        }
    }
}

#Preview {
    ProgressView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
