//
//  CardIntroView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI

struct CardIntroView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 套用航空風格背景
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.lg) {
                    // 標題區
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AviationTheme.Colors.cathayJade)
                        Text("國泰世華亞萬聯名卡")
                            .font(AviationTheme.Typography.title2)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        Text("聯名卡完整介紹")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                    .padding(.top, AviationTheme.Spacing.md)
                    
                    // 四張卡片
                    ForEach(CathayCardTier.allCases, id: \.self) { tier in
                        CathayCardDetailCard(tier: tier, colorScheme: colorScheme)
                    }
                    
                    // 台新國泰航空聯名卡
                    TaishinCardPlaceholder(colorScheme: colorScheme)
                    
                    // 加速器說明
                    AcceleratorInfoSection(colorScheme: colorScheme)
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xl)
            }
        }
        .navigationTitle("信用卡介紹")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 國泰世華卡片詳細卡
struct CathayCardDetailCard: View {
    let tier: CathayCardTier
    let colorScheme: ColorScheme
    
    var cardColor: LinearGradient {
        switch tier {
        case .world:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.3, green: 0.3, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .titanium:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.4, blue: 0.4), Color(red: 0.6, green: 0.6, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .platinum:
            return LinearGradient(colors: [Color(red: 0.0, green: 0.2, blue: 0.4), Color(red: 0.2, green: 0.5, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .miles:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.1, blue: 0.3), Color(red: 0.8, green: 0.3, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.lg) {
            // 卡片視覺化
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .fill(cardColor)
                    .frame(height: 180)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title)
                        Spacer()
                        Image(systemName: "airplane.circle.fill")
                            .font(.title)
                    }
                    
                    Spacer()
                    
                    Text("國泰世華銀行")
                        .font(.caption)
                        .fontWeight(.medium)
                        .opacity(0.8)
                    Text("亞萬聯名卡 \(tier.rawValue)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(AviationTheme.Spacing.lg)
            }
            
            // 基本資訊
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("一般消費")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        Text("\(tier.baseRate.formatted()) 元/哩")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("加速消費")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        Text("\(tier.acceleratorRate.formatted()) 元/哩")
                            .font(AviationTheme.Typography.headline)
                            .foregroundStyle(AviationTheme.Colors.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 50)
                
                Divider()
                    .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("年度上限")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        if tier.annualCap > 0 {
                            Text("\(tier.annualCap.formatted()) 哩")
                                .font(AviationTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        } else {
                            Text("無上限")
                                .font(AviationTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AviationTheme.Colors.success)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("年費")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        Text("NT$ \(tier.annualFee.formatted())")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 50)
            }
            
            Divider()
                .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
            
            // 權益列表
            VStack(alignment: .leading, spacing: 12) {
                Text("卡片權益")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                ForEach(tier.benefits, id: \.self) { benefit in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AviationTheme.Colors.success)
                            .font(.caption)
                        Text(benefit)
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.lg)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// 加速器資訊區塊
struct AcceleratorInfoSection: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            Text("四大哩程加速器")
                .font(AviationTheme.Typography.headline)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            
            Text("使用聯名卡消費以下類別，即可享有加速哩程回饋")
                .font(AviationTheme.Typography.subheadline)
                .foregroundStyle(AviationTheme.Colors.secondaryText(colorScheme))
            
            VStack(spacing: 12) {
                AcceleratorInfoRow(
                    category: .overseas,
                    description: "海外消費（含線上外幣交易）",
                    colorScheme: colorScheme
                )
                AcceleratorInfoRow(
                    category: .travel,
                    description: "國內外航空、飯店、旅行社、租車",
                    colorScheme: colorScheme
                )
                AcceleratorInfoRow(
                    category: .daily,
                    description: "超市、量販、加油、電信費",
                    colorScheme: colorScheme
                )
                AcceleratorInfoRow(
                    category: .leisure,
                    description: "電影院、KTV、健身房、遊樂園",
                    colorScheme: colorScheme
                )
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.lg)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// 加速器資訊列
struct AcceleratorInfoRow: View {
    let category: AcceleratorCategory
    let description: String
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AviationTheme.Colors.warning.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .foregroundStyle(AviationTheme.Colors.warning)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Text(description)
                    .font(AviationTheme.Typography.caption)
                    .foregroundStyle(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
        }
    }
}

// 台新國泰航空聯名卡佔位區塊
struct TaishinCardPlaceholder: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.lg) {
            // 卡片視覺化
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.15, green: 0.5, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title)
                        Spacer()
                        Image(systemName: "airplane.circle.fill")
                            .font(.title)
                    }
                    
                    Spacer()
                    
                    Text("台新銀行")
                        .font(.caption)
                        .fontWeight(.medium)
                        .opacity(0.8)
                    Text("國泰航空聯名卡")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(AviationTheme.Spacing.lg)
            }
            
            // 開發中提示
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title3)
                    .foregroundColor(AviationTheme.Colors.warning)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("計算規則開發中")
                        .font(AviationTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    Text("詳細回饋規則與權益介紹即將推出，敬請期待。")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.lg)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

#Preview {
    CardIntroView()
}
