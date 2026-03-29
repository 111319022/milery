import SwiftUI
import SwiftData
import Combine

struct DashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    private let syncCheckTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    var switchToProgress: (() -> Void)? = nil
    var switchToLedger: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 航空風格漸層背景
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.lg) {
                        // 同步提示 Banner
                        if viewModel.hasRemoteChanges {
                            SyncBannerView {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.manualSyncNow()
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 英雄卡片 - 總哩程與到期資訊
                        if let account = viewModel.mileageAccount {
                            HeroMilesCard(
                                totalMiles: account.totalMiles,
                                latestActivityMonth: account.latestActivityMonthText(),
                                expiryDate: account.expiryDate(),
                                daysUntilExpiry: account.daysUntilExpiry()
                            )
                        }
                        
                        // 到期警示（< 90 天時顯示）
                        if let account = viewModel.mileageAccount,
                           account.daysUntilExpiry() < 90 {
                            ExpiryAlertCard(
                                daysUntilExpiry: account.daysUntilExpiry(),
                                expiryDate: account.expiryDate()
                            )
                        }
                        
                        // 夢想雷達：里程足夠時顯示可兌換提醒，否則顯示最接近達成目標
                        if let currentMiles = viewModel.mileageAccount?.totalMiles {
                            let redeemable = viewModel.redeemableGoals(limit: 3)
                            if !redeemable.isEmpty {
                                RedeemReadyRadarCard(
                                    goals: redeemable,
                                    currentMiles: currentMiles,
                                    onTap: switchToProgress
                                )
                            } else if let goal = viewModel.closestGoal() {
                                DreamRadarCard(
                                    goal: goal,
                                    currentMiles: currentMiles,
                                    onTap: switchToProgress
                                )
                            }
                        }
                        
                        // 本月累積
                        MonthlyCockpitCard(viewModel: viewModel)
                        
                        // 最新動態
                        RecentActivityCard(
                            transactions: viewModel.transactions,
                            onTap: switchToLedger
                        )
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.top, AviationTheme.Spacing.sm)
                    .padding(.bottom, AviationTheme.Spacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("儀表板")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            .onAppear {
                viewModel.checkForRemoteChanges()
            }
            .onReceive(syncCheckTimer) { _ in
                viewModel.checkForRemoteChanges()
            }
        }
    }
}

// MARK: - 可兌換提醒卡片
struct RedeemReadyRadarCard: View {
    @Environment(\.colorScheme) var colorScheme
    let goals: [FlightGoal]
    let currentMiles: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.successColor(colorScheme))
                Text("夢想雷達")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Text("可兌換")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.successColor(colorScheme).opacity(0.15))
                    )
                    .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
            }

            Text("你目前有 \(currentMiles.formatted()) 哩，可兌換以下航點")
                .font(AviationTheme.Typography.subheadline)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(goals) { goal in
                    HStack(spacing: 8) {
                        Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                            .font(.caption)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                            .frame(width: 12)

                        Text("\(goal.origin) → \(goal.destination)")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                        Text(goal.cabinClass.rawValue)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.12))
                            )
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))

                        Spacer()

                        Text("\(goal.requiredMiles.formatted()) 哩")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl)
                .stroke(AviationTheme.Colors.successColor(colorScheme).opacity(0.28), lineWidth: 1)
        )
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 英雄卡片
struct HeroMilesCard: View {
    @Environment(\.colorScheme) var colorScheme
    let totalMiles: Int
    let latestActivityMonth: String
    let expiryDate: Date
    let daysUntilExpiry: Int
    
    @State private var displayedMiles: Int = 0
    
    // 追蹤此次 app session 是否已播放過動畫
    private static var hasPlayedAnimation = false
    
    var expiryColor: Color {
        if daysUntilExpiry < 30 {
            return AviationTheme.Colors.danger
        } else if daysUntilExpiry < 90 {
            return AviationTheme.Colors.warning
        } else {
            return AviationTheme.Colors.brandColor(colorScheme)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要哩程顯示區域
            VStack(spacing: AviationTheme.Spacing.md) {
                // 標題
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .font(.body)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AviationTheme.Colors.brandColor(colorScheme), AviationTheme.Colors.brandColorLight(colorScheme)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Asia Miles")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                            Text("可用哩程")
                                .font(AviationTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                    }
                    Spacer()
                }
                
                // 大數字哩程
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(displayedMiles.formatted())")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AviationTheme.Colors.brandColor(colorScheme),
                                    AviationTheme.Colors.brandColorLight(colorScheme)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("哩")
                        .font(AviationTheme.Typography.title3)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .offset(y: -8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("可用哩程 \(totalMiles) 哩")
                .onAppear {
                    if !HeroMilesCard.hasPlayedAnimation {
                        startCountAnimation(to: totalMiles)
                        HeroMilesCard.hasPlayedAnimation = true
                    } else {
                        displayedMiles = totalMiles
                    }
                }
                .onChange(of: totalMiles) {
                    startCountAnimation(to: totalMiles)
                }
            }
            .padding(AviationTheme.Spacing.lg)
            
            // 到期資訊條
            HStack(spacing: AviationTheme.Spacing.md) {
                // 最近活動月份
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundColor(expiryColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近記錄")
                            .font(.system(size: 10))
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        
                        Text(latestActivityMonth)
                            .font(AviationTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                }
                
                Spacer()
                
                // 到期日
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.body)
                        .foregroundColor(expiryColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("到期日")
                            .font(.system(size: 10))
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        Text(expiryDate.formatted(.dateTime.year().month().locale(Locale(identifier: "en"))))
                            .font(AviationTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                }
                
                Spacer()
                
                // 剩餘天數
                HStack(spacing: 4) {
                    if daysUntilExpiry < 30 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(expiryColor)
                    } else if daysUntilExpiry < 90 {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundColor(expiryColor)
                    }
                    Text("\(daysUntilExpiry)")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(expiryColor)
                    Text("天")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(expiryColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(expiryColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("距離到期還有 \(daysUntilExpiry) 天\(daysUntilExpiry < 30 ? "，即將到期" : daysUntilExpiry < 90 ? "，請留意" : "")")
            }
            .padding(AviationTheme.Spacing.md)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.02)
            )
        }
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
    }
    
    /// 數字遞增計數動畫
    private func startCountAnimation(to target: Int) {
        displayedMiles = 0
        guard target > 0 else { return }
        
        let totalDuration: Double = 0.9
        let steps = 30
        let interval = totalDuration / Double(steps)
        
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            // easeOut 曲線：先快後慢
            let eased = 1 - pow(1 - progress, 3)
            let value = Int(Double(target) * eased)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + interval * Double(step)) {
                displayedMiles = min(value, target)
            }
        }
    }
}

// MARK: - 夢想雷達卡片
struct DreamRadarCard: View {
    @Environment(\.colorScheme) var colorScheme
    let goal: FlightGoal
    let currentMiles: Int
    var onTap: (() -> Void)? = nil
    
    private var progress: Double {
        goal.progress(currentMiles: currentMiles)
    }
    
    private var milesNeeded: Int {
        goal.milesNeeded(currentMiles: currentMiles)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題列
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("夢想雷達")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            // 航線資訊
            HStack(spacing: 6) {
                Text(goal.originName)
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                    .font(.caption2)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                Text(goal.destinationName)
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text(goal.cabinClass.rawValue)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.12))
                    )
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 6)
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
                        .frame(width: geometry.size.width * min(progress, 1.0))
                    
                    // 飛機 icon 在進度前端
                    if progress > 0.05 {
                        Image(systemName: "airplane")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(x: max(8, geometry.size.width * min(progress, 1.0) - 20))
                    }
                }
            }
            .frame(height: 12)
            
            // 鼓勵文字
            HStack {
                if milesNeeded > 0 {
                    HStack(spacing: 0) {
                        Text("還差 ")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        Text("\(milesNeeded.formatted())")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                        Text(" 哩就能免費飛！加油！")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                        Text("已達成！可以準備出發了")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                    }
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .glassEffect(in: .rect(cornerRadius: AviationTheme.CornerRadius.xl))
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 本月累積卡片
struct MonthlyCockpitCard: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: MileageViewModel
    
    var body: some View {
        let stats = viewModel.monthlyStats()
        
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題
            HStack {
                Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("本月駕駛艙")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Text(Date().formatted(.dateTime.month(.wide).locale(Locale(identifier: "zh_TW"))))
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            // 兩欄統計
            HStack(spacing: AviationTheme.Spacing.md) {
                // 本月消費
                VStack(spacing: 6) {
                    Image(systemName: "wallet.bifold")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.warning)
                    
                    Text("NT$\(NSDecimalNumber(decimal: stats.totalAmount).intValue.formatted())")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text("本月消費")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                        .fill(AviationTheme.Colors.warning.opacity(colorScheme == .dark ? 0.08 : 0.06))
                )
                
                // 本月哩程
                VStack(spacing: 6) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    
                    Text("\(stats.totalMiles.formatted())")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("累積哩程")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                        .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.06))
                )
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

// MARK: - 最新動態卡片
struct RecentActivityCard: View {
    @Environment(\.colorScheme) var colorScheme
    let transactions: [Transaction]
    var onTap: (() -> Void)? = nil
    
    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(3))
    }

    private func activityIcon(for transaction: Transaction) -> String {
        transaction.source.icon
    }

    private func activityTitle(for transaction: Transaction) -> String {
        transaction.source.rawValue
    }

    private func activityIconColor(for transaction: Transaction) -> Color {
        transaction.source == .ticketRedemption ? AviationTheme.Colors.starluxIndigo : AviationTheme.Colors.brandColor(colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("最新動態")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                if !transactions.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
            }
            
            if recentTransactions.isEmpty {
                // 空狀態
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    Text("尚無交易紀錄")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    Text("前往記帳開始累積哩程")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                        HStack(spacing: 12) {
                            // 來源 icon
                            Image(systemName: activityIcon(for: transaction))
                                .font(.body)
                                .foregroundColor(activityIconColor(for: transaction))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(activityIconColor(for: transaction).opacity(colorScheme == .dark ? 0.2 : 0.12))
                                )
                            
                            // 來源名稱 + 時間
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activityTitle(for: transaction))
                                    .font(AviationTheme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                
                                Text(transaction.date, format: .dateTime.year().month(.abbreviated).day())
                                    .font(AviationTheme.Typography.caption)
                                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            }
                            
                            Spacer()
                            
                            // 哩程數
                            Text("\(transaction.earnedMiles > 0 ? "+" : "")\(transaction.earnedMiles.formatted())")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(transaction.source == .ticketRedemption ? AviationTheme.Colors.danger : AviationTheme.Colors.brandColor(colorScheme))
                        }
                        .padding(.vertical, 10)
                        
                        if index < recentTransactions.count - 1 {
                            Divider()
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                        }
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 到期警示卡片
struct ExpiryAlertCard: View {
    @Environment(\.colorScheme) var colorScheme
    let daysUntilExpiry: Int
    let expiryDate: Date
    
    private var alertColor: Color {
        daysUntilExpiry < 30 ? AviationTheme.Colors.danger : AviationTheme.Colors.warning
    }
    
    private var alertIcon: String {
        daysUntilExpiry < 30 ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alertIcon)
                .font(.title3)
                .foregroundColor(alertColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(daysUntilExpiry < 30 ? "哩程即將到期！" : "哩程到期提醒")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(alertColor)
                
                Text("剩餘 \(daysUntilExpiry) 天，請盡快使用或累積新哩程以延長效期")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
        }
        .padding(AviationTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .fill(alertColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .stroke(alertColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 同步提示 Banner
struct SyncBannerView: View {
    @Environment(\.colorScheme) var colorScheme
    var onSync: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("收到來自其他裝置的更新")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Text("點選同步以更新儀表板資料")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
            
            Button(action: onSync) {
                Text("同步")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.cathayJade)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .fill(AviationTheme.Colors.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(AviationTheme.Colors.cathayJade.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView(viewModel: MileageViewModel())
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}
