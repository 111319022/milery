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
                
                VStack(spacing: AviationTheme.Spacing.lg) {
                    // 英雄卡片 - 總哩程與到期資訊
                    if let account = viewModel.mileageAccount {
                        HeroMilesCard(
                            totalMiles: account.totalMiles,
                            latestActivityMonth: account.latestActivityMonthText(),
                            expiryDate: account.expiryDate(),
                            daysUntilExpiry: account.daysUntilExpiry()
                        )
                        .padding(AviationTheme.Spacing.md)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("儀表板")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                AviationTheme.Colors.background(colorScheme).opacity(0.95),
                for: .navigationBar
            )
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }
}

// MARK: - 英雄卡片（現代化設計）
struct HeroMilesCard: View {
    @Environment(\.colorScheme) var colorScheme
    let totalMiles: Int
    let latestActivityMonth: String
    let expiryDate: Date
    let daysUntilExpiry: Int
    
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
                    Text("\(totalMiles.formatted())")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
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
            }
            .padding(AviationTheme.Spacing.md)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.03)
                    : Color.black.opacity(0.02)
            )
        }
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 12,
            x: 0,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [
                            AviationTheme.Colors.brandColor(colorScheme).opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    DashboardView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
