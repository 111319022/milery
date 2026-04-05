import SwiftUI

// MARK: - 分頁顯示管理
struct TabVisibilitySettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("tabVisible_dashboard") private var dashboardVisible = true
    @AppStorage("tabVisible_progress") private var progressVisible = true
    @AppStorage("tabVisible_ledger") private var ledgerVisible = true
    @AppStorage("tabVisible_milestones") private var milestonesVisible = true
    private var visibleCount: Int {
        [dashboardVisible, progressVisible, ledgerVisible, milestonesVisible, true]
            .filter { $0 }.count
    }
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    // 說明
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "分頁開關", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            tabToggleRow(
                                icon: "gauge.with.dots.needle.bottom.50percent",
                                title: "儀表板",
                                subtitle: "總覽哩程與目標進度",
                                isOn: $dashboardVisible
                            )
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            tabToggleRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "進度",
                                subtitle: "查看累積進度與趨勢",
                                isOn: $progressVisible
                            )
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            tabToggleRow(
                                icon: "book.pages.fill",
                                title: "記帳",
                                subtitle: "哩程交易明細記錄",
                                isOn: $ledgerVisible
                            )
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            tabToggleRow(
                                icon: "ticket.fill",
                                title: "里程碑",
                                subtitle: "機票兌換與目標管理",
                                isOn: $milestonesVisible
                            )
                            
                            CustomDivider(colorScheme: colorScheme)
                            
                            SettingToggleRow(
                                icon: "gearshape.fill",
                                title: "設定",
                                subtitle: "應用程式偏好設定（無法關閉）",
                                isOn: .constant(true)
                            )
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // 目前狀態
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                        Text("目前顯示 \(visibleCount) / 5 個分頁")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        
                        Spacer()
                        
                        if visibleCount < 5 {
                            Button("全部開啟") {
                                dashboardVisible = true
                                progressVisible = true
                                ledgerVisible = true
                                milestonesVisible = true
                            }
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                        }
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md + 12)
                }
                .padding(.top, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("分頁顯示管理")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func tabToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        SettingToggleRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    // 至少要保留一個分頁開啟
                    if !newValue && visibleCount <= 1 {
                        return
                    }
                    isOn.wrappedValue = newValue
                }
            )
        )
    }
}

#Preview {
    NavigationStack {
        TabVisibilitySettingsView()
    }
}
