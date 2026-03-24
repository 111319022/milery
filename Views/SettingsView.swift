import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("preferredOrigin") private var preferredOrigin: String = ""
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    @State private var showingAirportPicker = false
    @State private var versionTapCount = 0
    @State private var isDeveloperModeEnabled = false
    @State private var showingDevPasswordAlert = false
    @State private var devPasswordInput = ""
    @AppStorage("developerPassword") private var developerPassword: String = "7373"
    @AppStorage("lastBackupDate") private var lastBackupDateTimestamp: Double = 0
    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true
    @State private var showingSyncRestartAlert = false
    
    private var lastBackupText: String {
        if lastBackupDateTimestamp > 0 {
            let date = Date(timeIntervalSince1970: lastBackupDateTimestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            return formatter.string(from: date)
        }
        return "尚未備份"
    }
    
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
                                // 1. 我的信用卡
                                NavigationLink(destination: CreditCardPageView(viewModel: viewModel)) {
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
                                        subtitle: preferredOrigin.isEmpty ? "未設定" : (AirportDatabase.shared.getAirport(iataCode: preferredOrigin)?.cityName ?? preferredOrigin)
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
                        
                        // MARK: - 備份與同步
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "備份與同步", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                SettingToggleRow(
                                    icon: "arrow.triangle.2.circlepath",
                                    title: "iCloud 同步",
                                    subtitle: "在相同 Apple ID 的裝置間自動同步資料",
                                    isOn: $cloudKitSyncEnabled
                                )
                                .onChange(of: cloudKitSyncEnabled) {
                                    showingSyncRestartAlert = true
                                }
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                NavigationLink(destination: CloudBackupView(viewModel: viewModel)) {
                                    SettingRow(
                                        icon: "icloud.and.arrow.up.fill",
                                        title: "iCloud 備份",
                                        subtitle: lastBackupText
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
                        
                        // MARK: - 關於
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "關於", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                Button(action: handleVersionTap) {
                                    SettingRow(
                                        icon: "info.circle.fill",
                                        title: "版本資訊",
                                        subtitle: nil
                                    ) {
                                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                                        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                                        Text("\(version) (\(build))")
                                            .font(AviationTheme.Typography.subheadline)
                                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        // MARK: - 開發者 (隱藏)
                        if isDeveloperModeEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeaderView(title: "開發者", colorScheme: colorScheme)
                                
                                VStack(spacing: 0) {
                                    NavigationLink(destination: AirportListView()) {
                                        SettingRow(
                                            icon: "airplane",
                                            title: "機場資料列表",
                                            subtitle: "搜尋機場完善AirportDatabase用"
                                        ) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    CustomDivider(colorScheme: colorScheme)
                                    
                                    NavigationLink(destination: TabVisibilitySettingsView()) {
                                        SettingRow(
                                            icon: "square.grid.2x2",
                                            title: "分頁顯示管理",
                                            subtitle: "設定 TabView 要顯示哪些分頁"
                                        ) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    CustomDivider(colorScheme: colorScheme)

                                    NavigationLink(destination: DataManagementView()) {
                                        SettingRow(
                                            icon: "externaldrive.fill.badge.icloud",
                                            title: "資料管理",
                                            subtitle: "檢視 SwiftData 全量資料與清理舊版異常"
                                        ) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    CustomDivider(colorScheme: colorScheme)

                                    NavigationLink(destination: ConsoleLogView()) {
                                        SettingRow(
                                            icon: "terminal.fill",
                                            title: "Console 日誌",
                                            subtitle: "檢視 App 內部同步與備份紀錄"
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
                        }
                    }
                    .padding(.top, AviationTheme.Spacing.md)
                    .padding(.bottom, AviationTheme.Spacing.xxl)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            .sheet(isPresented: $showingAirportPicker) {
                SettingsAirportPickerWrapper(selectedCode: $preferredOrigin)
            }
            .alert("開發者模式", isPresented: $showingDevPasswordAlert) {
                SecureField("請輸入四位數密碼", text: $devPasswordInput)
                    .keyboardType(.numberPad)
                Button("確認") {
                    if devPasswordInput == developerPassword {
                        isDeveloperModeEnabled = true
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("請輸入密碼以啟用開發者模式")
            }
            .alert("需要重新啟動", isPresented: $showingSyncRestartAlert) {
                Button("我知道了", role: .cancel) { }
            } message: {
                Text("iCloud 同步設定變更將在下次啟動 App 後生效。")
            }
        }
    }
    
    // MARK: - 版本資訊點擊處理
    private func handleVersionTap() {
        versionTapCount += 1
        
        if isDeveloperModeEnabled {
            // 已啟用開發者模式，再點 10 次會隱藏
            if versionTapCount >= 10 {
                isDeveloperModeEnabled = false
                versionTapCount = 0
            }
        } else {
            // 未啟用開發者模式，點 10 次彈出密碼輸入
            if versionTapCount >= 10 {
                devPasswordInput = ""
                showingDevPasswordAlert = true
                versionTapCount = 0
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
