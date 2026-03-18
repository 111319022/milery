//
//  SettingsView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("preferredOrigin") private var preferredOrigin: String = "TPE"
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    @State private var showingAirportPicker = false
    
    var themeDisplayName: String {
        switch userColorScheme {
        case "light": return "淺色模式"
        case "dark": return "深色模式"
        default: return "跟隨系統"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 航空風格背景
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    // 加大各區塊之間的距離 (xl)
                    VStack(spacing: AviationTheme.Spacing.xl) {
                        
                        // MARK: - 外觀設定
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "外觀", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                SettingRow(
                                    icon: "paintbrush.fill",
                                    title: "主題",
                                    subtitle: themeDisplayName
                                ) {
                                    Menu {
                                        Button(action: { userColorScheme = "system" }) {
                                            Label("跟隨系統", systemImage: userColorScheme == "system" ? "checkmark" : "")
                                        }
                                        Button(action: { userColorScheme = "light" }) {
                                            Label("淺色模式", systemImage: userColorScheme == "light" ? "checkmark" : "")
                                        }
                                        Button(action: { userColorScheme = "dark" }) {
                                            Label("深色模式", systemImage: userColorScheme == "dark" ? "checkmark" : "")
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(themeDisplayName)
                                                .font(AviationTheme.Typography.subheadline)
                                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                        }
                                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                    }
                                }
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        // MARK: - 信用卡管理
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "信用卡管理", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                // 1. 啟用卡片設定
                                NavigationLink(destination: CardManagementView(viewModel: viewModel)) {
                                    SettingRow(
                                        icon: "creditcard.fill",
                                        title: "我的信用卡",
                                        subtitle: "\(viewModel.creditCards.filter { $0.isActive }.count) 張啟用中"
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                // 2. 生日月份設定
                                SettingRow(
                                    icon: "gift.fill",
                                    title: "生日月份設定",
                                    subtitle: "用於計算生日當月哩程雙倍加碼"
                                ) {
                                    DatePicker("", selection: $viewModel.userBirthday, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(AviationTheme.Colors.cathayJade)
                                }
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                // 3. 信用卡權益介紹
                                NavigationLink(destination: CardIntroView()) {
                                    SettingRow(
                                        icon: "info.square.fill",
                                        title: "聯名卡權益介紹",
                                        subtitle: "四大等級卡片回饋規則"
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        // MARK: - 一般設定
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "一般", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                Button {
                                    showingAirportPicker = true
                                } label: {
                                    SettingRow(
                                        icon: "airplane.departure",
                                        title: "常用出發地",
                                        subtitle: AirportDatabase.shared.getAirport(iataCode: preferredOrigin)?.cityName ?? "台北"
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                SettingToggleRow(
                                    icon: "bell.fill",
                                    title: "通知提醒",
                                    subtitle: "接收哩程到期與目標提醒",
                                    isOn: $enableNotifications
                                )
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        // MARK: - 關於
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "關於", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                SettingRow(
                                    icon: "info.circle.fill",
                                    title: "版本資訊",
                                    subtitle: nil
                                ) {
                                    Text("1.0.0")
                                        .font(AviationTheme.Typography.subheadline)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        .padding(.bottom, AviationTheme.Spacing.xxl)
                    }
                    .padding(.top, AviationTheme.Spacing.md)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                AviationTheme.Colors.background(colorScheme),
                for: .navigationBar
            )
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .sheet(isPresented: $showingAirportPicker) {
                SettingsAirportPickerWrapper(selectedCode: $preferredOrigin)
            }
        }
    }
}

// MARK: - 輔助視圖元件

/// 區塊標題
struct SectionHeaderView: View {
    let title: String
    let colorScheme: ColorScheme
    
    var body: some View {
        Text(title)
            .font(AviationTheme.Typography.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            .padding(.leading, 12)
    }
}

/// 對齊文字的完美分隔線
struct CustomDivider: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        Divider()
            .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
            // 60 = 16(外邊距) + 28(Icon寬度) + 16(HStack間隔)
            .padding(.leading, 60)
    }
}

// MARK: - 信用卡管理頁面 (CardManagementView)
struct CardManagementView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.md) {
                    
                    Text("請勾選您目前持有的信用卡。只有啟用的卡片會顯示在記帳本的計算機選項中。")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, AviationTheme.Spacing.sm)
                    
                    VStack(spacing: AviationTheme.Spacing.md) {
                        ForEach(viewModel.creditCards) { card in
                            HStack(spacing: AviationTheme.Spacing.md) {
                                // 卡片圖標
                                ZStack {
                                    Circle()
                                        .fill(card.isActive ? AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.3 : 0.15) : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(card.isActive ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.tertiaryText(colorScheme))
                                }
                                
                                // 卡片資訊
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.cardName)
                                        .font(AviationTheme.Typography.body)
                                        .fontWeight(card.isActive ? .bold : .regular)
                                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                    
                                    Text(card.bankName)
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                                
                                Spacer()
                                
                                // 開關
                                Toggle("", isOn: Binding(
                                    get: { card.isActive },
                                    set: { _ in viewModel.toggleCardActive(card) }
                                ))
                                .labelsHidden()
                                .tint(AviationTheme.Colors.cathayJade)
                            }
                            .padding(AviationTheme.Spacing.md)
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 5, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                                    .stroke(card.isActive ? AviationTheme.Colors.cathayJade.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("我的信用卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            AviationTheme.Colors.background(colorScheme),
            for: .navigationBar
        )
    }
}

// MARK: - 設定行元件
struct SettingRow<Accessory: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let subtitle: String?
    var titleColor: Color?
    let accessory: () -> Accessory
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        titleColor: Color? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.accessory = accessory
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 圖標
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .frame(width: 28) // 固定寬度確保文字對齊
            
            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(titleColor ?? AviationTheme.Colors.primaryText(colorScheme))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            
            Spacer()
            
            // 附件 (例如箭頭、文字、選單)
            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14) // 確保點擊範圍夠高
        .contentShape(Rectangle()) // 讓整列的空白處都能被點擊
    }
}

// MARK: - 設定開關行元件
struct SettingToggleRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 圖標
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .frame(width: 28)
            
            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            
            Spacer()
            
            // 開關
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AviationTheme.Colors.cathayJade)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10) // Toggle 本身較高，稍微減少一點 Padding
        .contentShape(Rectangle())
    }
}

// MARK: - 設定頁面專用的機場選擇器包裝
struct SettingsAirportPickerWrapper: View {
    @Binding var selectedCode: String
    @State private var selectedAirport: Airport?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        AirportPickerView(
            selectedAirport: Binding(
                get: { selectedAirport },
                set: { newValue in
                    selectedAirport = newValue
                    if let newValue = newValue {
                        selectedCode = newValue.iataCode
                        dismiss()
                    }
                }
            ),
            airports: AirportDatabase.shared.getAllAirports()
        )
        .onAppear {
            selectedAirport = AirportDatabase.shared.getAirport(iataCode: selectedCode)
        }
        .navigationTitle("選擇常用出發地")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
