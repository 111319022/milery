import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("preferredOrigin") private var preferredOrigin: String = ""
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    @State private var showingAirportPicker = false
    @State private var versionTapCount = 0
    @State private var isDeveloperModeEnabled = false
    @State private var isCheckingDeveloperAccess = false
    @State private var showingDeveloperAccessAlert = false
    @State private var developerAccessMessage = ""
    @AppStorage("lastBackupDate") private var lastBackupDateTimestamp: Double = 0
    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showingSyncRestartAlert = false
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var showingEasterEgg = false
    @State private var showBirthdayPicker = false
    
    private var lastBackupText: String {
        if lastBackupDateTimestamp > 0 {
            let date = Date(timeIntervalSince1970: lastBackupDateTimestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            return formatter.string(from: date)
        }
        return "尚未備份"
    }
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom:
            return true
        case .none, .solidColor, .gradient:
            return false
        }
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
                AppBackgroundView()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.xl) {
                        
                        // MARK: - 外觀設定
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "外觀", colorScheme: colorScheme)
                            
                            VStack(spacing: 0) {
                                SettingRow(
                                    icon: "paintbrush.fill",
                                    title: "主題",
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
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                NavigationLink {
                                    BackgroundPickerView()
                                } label: {
                                    SettingRow(
                                        icon: "photo.fill",
                                        title: "背景圖片",
                                        subtitle: nil
                                    ) {
                                        HStack(spacing: 4) {
                                            Text(BackgroundImageManager.displayName(for: backgroundSelection))
                                                .font(AviationTheme.Typography.subheadline)
                                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                CustomDivider(colorScheme: colorScheme)
                                
                                NavigationLink {
                                    AppIconPickerView()
                                } label: {
                                    SettingRow(
                                        icon: "app.badge.fill",
                                        title: "App icon更換",
                                        subtitle: nil
                                    ) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                    }
                                }
                                .buttonStyle(.plain)
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
                                Button {
                                    showBirthdayPicker = true
                                } label: {
                                    SettingRow(
                                        icon: "gift.fill",
                                        title: "生日月份",
                                        subtitle: "生日月部分卡片可享哩程雙倍加碼"
                                    ) {
                                        HStack(spacing: 4) {
                                            Text(viewModel.userBirthdayMonth >= 1 && viewModel.userBirthdayMonth <= 12 ? "\(viewModel.userBirthdayMonth) 月" : "未設定")
                                                .font(AviationTheme.Typography.subheadline)
                                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                        }
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
                                
                                NavigationLink(destination: NotificationSettingsView()) {
                                    SettingRow(
                                        icon: "bell.fill",
                                        title: "通知設定（開發中）",
                                        subtitle: enableNotifications ? "已開啟" : "已關閉"
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
                                Button(action: {
                                    guard !isCheckingDeveloperAccess else { return }
                                    handleVersionTap()
                                }) {
                                    SettingRow(
                                        icon: "info.circle.fill",
                                        title: "版本資訊",
                                        subtitle: nil
                                    ) {
                                        if isCheckingDeveloperAccess {
                                            SwiftUI.ProgressView()
                                                .scaleEffect(0.85)
                                        } else {
                                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                                            Text("\(version) (\(build))")
                                                .font(AviationTheme.Typography.subheadline)
                                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(LongPressGesture(minimumDuration: 1.0).onEnded { _ in
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    showingEasterEgg = true
                                })                            }
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

                                    CustomDivider(colorScheme: colorScheme)
                                    
                                    Button {
                                        hasCompletedOnboarding = false
                                        showDevToast("Onboarding 已重置")
                                    } label: {
                                        SettingRow(
                                            icon: "arrow.clockwise.circle.fill",
                                            title: "重新觸發 Onboarding",
                                            subtitle: "重置狀態，下次啟動時會顯示歡迎頁面"
                                        ) {
                                            Image(systemName: "")
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                }
                                .background(AviationTheme.Colors.cardBackground(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                            }
                            .padding(.horizontal, AviationTheme.Spacing.md)
                            
                            // MARK: - 開發中頁面 (隱藏)
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeaderView(title: "開發中頁面", colorScheme: colorScheme)
                                
                                VStack(spacing: 0) {
                                    NavigationLink(destination: ProgramSwitcherView(viewModel: viewModel)) {
                                        SettingRow(
                                            icon: "arrow.triangle.2.circlepath.circle.fill",
                                            title: "里程計劃切換（開發中）",
                                            subtitle: "當前：\(viewModel.activeProgram?.name ?? "Asia Miles")"
                                        ) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    CustomDivider(colorScheme: colorScheme)
                                    
                                    NavigationLink(destination: AppLockSettingsView()) {
                                        SettingRow(
                                            icon: "lock.fill",
                                            title: "App 密碼鎖（開發中）",
                                            subtitle: UserDefaults.standard.bool(forKey: "appLockEnabled") ? "已開啟" : "未開啟"
                                        ) {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    CustomDivider(colorScheme: colorScheme)
                                    
                                    NavigationLink(destination: FriendsView()) {
                                        SettingRow(
                                            icon: "person.2.fill",
                                            title: "好友（開發中）",
                                            subtitle: "透過好友代碼加入好友"
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
            .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
            .sheet(isPresented: $showingAirportPicker) {
                SettingsAirportPickerWrapper(selectedCode: $preferredOrigin)
            }
            .sheet(isPresented: $showBirthdayPicker) {
                BirthdayMonthPickerSheet(selectedMonth: Binding(
                    get: { viewModel.userBirthdayMonth },
                    set: { viewModel.userBirthdayMonth = $0 }
                ))
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .alert("開發者權限驗證", isPresented: $showingDeveloperAccessAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(developerAccessMessage)
            }
            .alert("需要重新啟動", isPresented: $showingSyncRestartAlert) {
                Button("我知道了", role: .cancel) { }
            } message: {
                Text("iCloud 同步設定變更將在下次啟動 App 後生效。")
            }
            .sheet(isPresented: $showingEasterEgg) {
                VStack(spacing: 20) {
                    Image("73")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        
                    Text("嘿嘿～你找到73了！")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                if showToast, let message = toastMessage {
                    DevToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                }
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
                showDevToast("開發者模式已關閉")
            }
        } else {
            // 未啟用開發者模式，點 10 次做 CloudKit 白名單驗證
            if versionTapCount >= 10 {
                versionTapCount = 0
                validateDeveloperAccessByCloudKit()
            }
        }
    }

    private func validateDeveloperAccessByCloudKit() {
        guard !isCheckingDeveloperAccess else { return }
        isCheckingDeveloperAccess = true

        Task {
            let result = await DeveloperAccessService.shared.verifyCurrentUserAccess()
            isCheckingDeveloperAccess = false

            switch result {
            case .allowed:
                isDeveloperModeEnabled = true
                showDevToast("開發者模式已啟用")
                appLog("[DevAccess] CloudKit 白名單驗證通過")
            case .denied(let message):
                developerAccessMessage = message
                showingDeveloperAccessAlert = true
                appLog("[DevAccess] CloudKit 白名單驗證失敗：\(message)")
            }
        }
    }
    
    private func showDevToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(duration: 0.35)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }
}

// MARK: - 輔助視圖元件

/// 區塊標題
struct SectionHeaderView: View {
    let title: String
    let colorScheme: ColorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    
    private var needsCapsuleBackground: Bool {
        switch backgroundSelection {
        case .preset, .custom:
            return true
        case .none, .solidColor, .gradient:
            return false
        }
    }
    
    var body: some View {
        Text(title)
            .font(AviationTheme.Typography.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, needsCapsuleBackground ? 4 : 0)
            .background {
                if needsCapsuleBackground {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
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
        .padding(.vertical, 10)
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

// MARK: - 開發者模式開關Toast提示
struct DevToastView: View {
    let message: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.contains("啟用") ? "hammer.fill" : "hammer")
                .font(.subheadline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.85 : 0.75))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - 生日月份滾輪彈窗
struct BirthdayMonthPickerSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMonth: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                Button("取消") {
                    dismiss()
                }
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                
                Spacer()
                
                Text("選擇生日月份")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Spacer()
                
                Button("完成") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.cathayJade)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // 滾輪
            Picker("月份", selection: $selectedMonth) {
                Text("未設定").tag(0)
                ForEach(1...12, id: \.self) { month in
                    Text("\(month) 月").tag(month)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    SettingsView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
