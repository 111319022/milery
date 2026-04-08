import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("notifyMilesExpiry") private var notifyMilesExpiry: Bool = true
    @AppStorage("notifyRedemptionReady") private var notifyRedemptionReady: Bool = true
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor, .gradient: return false
        }
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    
                    // MARK: - 主開關
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "通知", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            SettingToggleRow(
                                icon: "bell.fill",
                                title: "通知提醒",
                                subtitle: "開啟後可接收各項哩程提醒通知",
                                isOn: $enableNotifications
                            )
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 通知項目
                    if enableNotifications {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "通知項目", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                SettingToggleRow(
                                    icon: "clock.badge.exclamationmark",
                                    title: "哩程到期通知",
                                    subtitle: "哩程即將到期時提醒",
                                    isOn: $notifyMilesExpiry
                                )
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                SettingToggleRow(
                                    icon: "ticket.fill",
                                    title: "哩程兌票提醒",
                                    subtitle: "可兌換目標機票時通知",
                                    isOn: $notifyRedemptionReady
                                )
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
                .animation(.easeInOut(duration: 0.25), value: enableNotifications)
            }
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
