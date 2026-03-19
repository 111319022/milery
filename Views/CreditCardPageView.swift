//
//  CreditCardPageView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/19.
//

import SwiftUI
import SwiftData

struct CreditCardPageView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.lg) {
                    
                    Text("管理您的哩程信用卡，啟用的卡片會顯示在記帳本的計算機選項中。")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, AviationTheme.Spacing.sm)
                    
                    ForEach(viewModel.creditCards) { card in
                        CreditCardCell(card: card, viewModel: viewModel, colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("我的信用卡")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
    }
}

// MARK: - 單張信用卡卡片
struct CreditCardCell: View {
    let card: CreditCardRule
    @Bindable var viewModel: MileageViewModel
    let colorScheme: ColorScheme
    
    var cardGradient: LinearGradient {
        switch card.cardBrand {
        case .cathayUnitedBank:
            if let tier = card.cathayTier {
                switch tier {
                case .world:
                    return LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.28, green: 0.28, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
                case .titanium:
                    return LinearGradient(colors: [Color(red: 0.38, green: 0.38, blue: 0.42), Color(red: 0.58, green: 0.58, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
                case .platinum:
                    return LinearGradient(colors: [Color(red: 0.0, green: 0.18, blue: 0.38), Color(red: 0.18, green: 0.45, blue: 0.68)], startPoint: .topLeading, endPoint: .bottomTrailing)
                case .miles:
                    return LinearGradient(colors: [Color(red: 0.38, green: 0.08, blue: 0.28), Color(red: 0.75, green: 0.28, blue: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            return LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.28, green: 0.28, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .taishinCathay:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.15, green: 0.5, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: 卡面視覺
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .fill(cardGradient)
                    .frame(height: 180)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title2)
                        Spacer()
                        Image(systemName: "airplane.circle.fill")
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text(card.bankName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .opacity(0.8)
                    
                    Text(card.cardName)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(AviationTheme.Spacing.lg)
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            .padding(.top, AviationTheme.Spacing.md)
            
            // MARK: 等級選擇（僅國泰卡）
            if card.cardBrand == .cathayUnitedBank {
                VStack(alignment: .leading, spacing: 8) {
                    Text("卡片等級")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                    Picker("等級", selection: Binding(
                        get: { card.cathayTier ?? .world },
                        set: { newTier in
                            viewModel.updateCardTier(card, tier: newTier)
                        }
                    )) {
                        ForEach(CathayCardTier.allCases, id: \.self) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.top, AviationTheme.Spacing.md)
            }
            
            // MARK: 費率資訊
            if card.cardBrand == .taishinCathay {
                // 台新卡佔位
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(AviationTheme.Colors.warning)
                    Text("計算規則開發中，敬請期待")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AviationTheme.Spacing.lg)
                .padding(.horizontal, AviationTheme.Spacing.md)
            } else {
                rateInfoSection
            }
            
            Divider()
                .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                .padding(.horizontal, AviationTheme.Spacing.md)
            
            // MARK: 啟用開關
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.isActive ? "已啟用" : "已停用")
                        .font(AviationTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    Text("啟用後可在計算機中選擇此卡")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { card.isActive },
                    set: { _ in viewModel.toggleCardActive(card) }
                ))
                .labelsHidden()
                .tint(AviationTheme.Colors.cathayJade)
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            .padding(.vertical, AviationTheme.Spacing.md)
        }
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(card.isActive ? AviationTheme.Colors.cathayJade.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - 費率資訊區
    private var rateInfoSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                rateColumn(title: "一般消費", value: "\(card.baseRate.formatted()) 元/哩", highlight: false)
                
                Divider()
                    .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                    .frame(height: 40)
                
                rateColumn(title: "加速消費", value: "\(card.acceleratorRate.formatted()) 元/哩", highlight: true)
                
                Divider()
                    .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                    .frame(height: 40)
                
                rateColumn(title: "年費", value: "NT$ \(card.annualFee.formatted())", highlight: false)
            }
            
            if let tier = card.cathayTier, tier.annualCap > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    Text("年度加速上限 \(tier.annualCap.formatted()) 哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
        .padding(.vertical, AviationTheme.Spacing.md)
    }
    
    private func rateColumn(title: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            Text(value)
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(highlight ? AviationTheme.Colors.warning : AviationTheme.Colors.primaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        CreditCardPageView(viewModel: MileageViewModel())
            .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
    }
}
