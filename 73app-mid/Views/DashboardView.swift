//
//  DashboardView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 航空風格漸層背景
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.lg) {
                        // 總哩程卡片 - 金色金屬質感
                        TotalMilesCard(
                            totalMiles: viewModel.mileageAccount?.totalMiles ?? 0,
                            expiryDate: viewModel.mileageAccount?.expiryDate ?? Date()
                        )
                        
                        // 本月統計 - 雙卡片設計
                        MonthlyStatsCard(
                            amount: viewModel.monthlyStats().totalAmount,
                            miles: viewModel.monthlyStats().totalMiles
                        )
                        
                        // 過期提醒
                        if let account = viewModel.mileageAccount {
                            ExpiryReminderCard(daysUntilExpiry: account.daysUntilExpiry())
                        }
                        
                        // 最近交易 - 玻璃擬態效果
                        RecentTransactionsSection(transactions: Array(viewModel.transactions.prefix(5)))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .padding(.bottom, AviationTheme.Spacing.xxl)
                }
            }
            .navigationTitle("Asia Miles")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                AviationTheme.Colors.background(colorScheme).opacity(0.95),
                for: .navigationBar
            )
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}

// MARK: - 總哩程卡片（金色金屬質感）
struct TotalMilesCard: View {
    @Environment(\.colorScheme) var colorScheme
    let totalMiles: Int
    let expiryDate: Date
    
    var body: some View {
        VStack(spacing: AviationTheme.Spacing.lg) {
            // 頂部標題
            HStack {
                ZStack {
                    Circle()
                        .fill(AviationTheme.Gradients.metalGold)
                        .frame(width: 44, height: 44)
                        .shadow(color: AviationTheme.Shadows.goldGlow, radius: 10)
                    
                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Asia Miles")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.lightGold)
                    Text("可用哩程總計")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                }
                
                Spacer()
            }
            
            // 巨大數字顯示
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(totalMiles.formatted())")
                    .font(AviationTheme.Typography.mileageDisplay)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AviationTheme.Colors.lightGold, AviationTheme.Colors.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AviationTheme.Shadows.goldGlow, radius: 5)
                
                Text("哩")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 底部裝飾線
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AviationTheme.Colors.gold.opacity(0.5),
                            AviationTheme.Colors.gold.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(AviationTheme.Spacing.lg)
        .metalCard(useAdaptiveGradient: true)
    }
}

// MARK: - 本月統計卡片（雙欄式金屬卡片）
struct MonthlyStatsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let amount: Decimal
    let miles: Int
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            // 左側：本月消費
            VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                        .font(.title3)
                    Text("本月消費")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Text("NT$ \((amount as NSDecimalNumber).intValue.formatted())")
                    .font(AviationTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 分隔線
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 8)
            
            // 右側：累積哩程
            VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .foregroundColor(AviationTheme.Colors.success)
                        .font(.title3)
                    Text("累積哩程")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Text("\(miles.formatted()) 哩")
                    .font(AviationTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AviationTheme.Colors.success)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AviationTheme.Spacing.lg)
        .glassmorphism()
    }
}

// MARK: - 過期提醒卡片（警告金屬質感）
struct ExpiryReminderCard: View {
    @Environment(\.colorScheme) var colorScheme
    let daysUntilExpiry: Int
    
    var reminderColor: Color {
        if daysUntilExpiry < 30 {
            return AviationTheme.Colors.danger
        } else if daysUntilExpiry < 90 {
            return AviationTheme.Colors.warning
        } else {
            return AviationTheme.Colors.success
        }
    }
    
    var reminderGradient: LinearGradient {
        if daysUntilExpiry < 30 {
            return LinearGradient(
                colors: [Color(red: 0.85, green: 0.25, blue: 0.25), Color(red: 0.65, green: 0.15, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if daysUntilExpiry < 90 {
            return AviationTheme.Gradients.metalGold
        } else {
            return LinearGradient(
                colors: [AviationTheme.Colors.success, Color(red: 0.1, green: 0.5, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(reminderGradient)
                    .frame(width: 50, height: 50)
                
                Image(systemName: daysUntilExpiry < 30 ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("哩程效期提醒")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.silver)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(daysUntilExpiry)")
                        .font(AviationTheme.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    Text("天後到期")
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            
            Spacer()
        }
        .padding(AviationTheme.Spacing.lg)
        .metalCard(gradient: reminderGradient, cornerRadius: AviationTheme.CornerRadius.md)
    }
}

// MARK: - 最近交易區塊（玻璃擬態）
struct RecentTransactionsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題列
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    Text("最近交易")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                }
                
                Spacer()
                
                NavigationLink {
                    // 連結到完整記帳本
                } label: {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(AviationTheme.Typography.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                }
            }
            
            // 交易列表
            if transactions.isEmpty {
                VStack(spacing: AviationTheme.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(AviationTheme.Colors.silver.opacity(0.5))
                    Text("尚無交易記錄")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AviationTheme.Spacing.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                        TransactionRow(transaction: transaction)
                        
                        if index < transactions.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, AviationTheme.Spacing.sm)
                        }
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .glassmorphism()
    }
}





// MARK: - 交易列（金屬風格）
struct TransactionRow: View {
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            // 圖標
            ZStack {
                Circle()
                    .fill(AviationTheme.Gradients.cathayJade)
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.source.icon)
                    .font(.body)
                    .foregroundColor(.white)
            }
            
            // 交易資訊
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.source.rawValue)
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
            
            // 金額與哩程
            VStack(alignment: .trailing, spacing: 3) {
                Text("NT$ \((transaction.amount as NSDecimalNumber).intValue.formatted())")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                
                HStack(spacing: 3) {
                    Text("+\(transaction.earnedMiles)")
                        .font(AviationTheme.Typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.success)
                    Text("哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.success)
                }
            }
        }
        .padding(.vertical, AviationTheme.Spacing.sm)
    }
}

#Preview {
    DashboardView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
