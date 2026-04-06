import SwiftUI
import SwiftData
import UserNotifications
import UIKit

// MARK: - Onboarding 專屬配色（淡金色 + 大地棕色）
private enum OnboardingPalette {
    // App 主色：淡金黃 #F4EFE5 + 大地棕 / 咖啡色，並支援深色模式
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static let earthBrown = dynamic(
        light: UIColor(red: 0.36, green: 0.27, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.86, green: 0.77, blue: 0.65, alpha: 1)
    )
    static let warmBrown = dynamic(
        light: UIColor(red: 0.50, green: 0.38, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.67, blue: 0.54, alpha: 1)
    )
    static let darkBrown = dynamic(
        light: UIColor(red: 0.27, green: 0.20, blue: 0.15, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.14, blue: 0.11, alpha: 1)
    )

    // 淡金強調
    static let accent = dynamic(
        light: UIColor(red: 0.79, green: 0.64, blue: 0.42, alpha: 1),
        dark: UIColor(red: 0.88, green: 0.73, blue: 0.49, alpha: 1)
    )
    static let accentBright = dynamic(
        light: UIColor(red: 0.85, green: 0.70, blue: 0.48, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.81, blue: 0.60, alpha: 1)
    )

    // 背景漸層：淺色以 #F4EFE5 為核心；深色改為暖咖啡夜景
    static let bgTop = dynamic(
        light: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
    )
    static let bgBottom = dynamic(
        light: UIColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.11, blue: 0.08, alpha: 1)
    )

    // 文字：淺色改深咖啡，提升 liquid glass 上可讀性
    static let titleText = dynamic(
        light: UIColor(red: 0.27, green: 0.20, blue: 0.15, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1)
    )
    static let bodyText = dynamic(
        light: UIColor(red: 0.36, green: 0.28, blue: 0.21, alpha: 1),
        dark: UIColor(red: 0.90, green: 0.84, blue: 0.76, alpha: 1)
    )
    static let captionText = dynamic(
        light: UIColor(red: 0.45, green: 0.36, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.76, green: 0.68, blue: 0.59, alpha: 1)
    )

    // glass 按鈕文字顏色：淺色用深棕，深色用暖白
    static let glassButtonText = dynamic(
        light: UIColor(red: 0.23, green: 0.17, blue: 0.12, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1)
    )

    static let pageIndicatorInactive = dynamic(
        light: UIColor(red: 0.50, green: 0.39, blue: 0.29, alpha: 0.35),
        dark: UIColor(red: 0.93, green: 0.86, blue: 0.74, alpha: 0.30)
    )
}

// MARK: - iOS 風格大圓漸層背景
struct OnboardingBlobBackground: View {
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 底色漸層
                LinearGradient(
                    colors: [OnboardingPalette.bgTop, OnboardingPalette.bgBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 大圓 1：左上方，較亮的暖光
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                OnboardingPalette.accent.opacity(0.38),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: w * 0.55
                        )
                    )
                    .frame(width: w * 1.2, height: w * 1.2)
                    .offset(x: -w * 0.30, y: -h * 0.18)
                    .scaleEffect(phase ? 1.03 : 0.97)

                // 大圓 2：右下方，深棕色沉穩
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                OnboardingPalette.darkBrown.opacity(0.40),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: w * 0.50
                        )
                    )
                    .frame(width: w * 1.1, height: w * 1.1)
                    .offset(x: w * 0.25, y: h * 0.25)
                    .scaleEffect(phase ? 0.97 : 1.03)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 脈衝光環
struct PulseRingView: View {
    let color: Color
    @State private var scale: CGFloat = 0.85
    @State private var ringOpacity: Double = 0.5

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: 110, height: 110)
            .scaleEffect(scale)
            .opacity(ringOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                    scale = 1.4
                    ringOpacity = 0
                }
            }
    }
}

// MARK: - 歡迎頁 Logo 視圖
struct WelcomeHeroAnimationView: View {
    @State private var isAnimating = false

    var body: some View {
        Image("milery_logo_no_bg")
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            .scaleEffect(isAnimating ? 1.03 : 0.97)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MileageViewModel
    
    @State private var currentPage = 0
    
    // Page 2: 里程計劃選擇
    @State private var selectedProgramType: MilageProgramType = .asiaMiles
    
    // Page 3: 信用卡選擇
    @State private var selectedCathayTierID: String? = nil
    @State private var selectedTaishinTierID: String? = nil
    @State private var selectedCardBanks: Set<CardBankOption> = []
    
    private let cathayDefinition = CathayUnitedBankCard()
    private let taishinDefinition = TaishinCathayCard()
    
    // Page 4: 常用出發地
    @AppStorage("preferredOrigin") private var preferredOrigin: String = ""
    @State private var showingAirportPicker = false
    @State private var selectedAirport: Airport? = nil
    
    // Page 5: 現有里程輸入
    @State private var existingMilesText: String = ""
    
    // Page 6: 生日選擇
    @State private var enableBirthday = true
    @State private var selectedBirthdayMonth: Int = Calendar.current.component(.month, from: Date())
    
    // Page 7: 主題選擇
    @AppStorage("userColorScheme") private var userColorScheme: String = "system"
    @AppStorage("enableNotifications") private var enableNotifications: Bool = false
    
    // Page 9: CloudKit同步設定
    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true
    
    // Onboarding 完成狀態
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var notificationPermissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var themeOverlayOpacity: Double = 0
    @State private var themeOverlayColor: Color = .white
    @State private var appliedOnboardingColorSchemeSetting: String = "system"
    
    // 開發者跳過 Onboarding
    @State private var showDevSkipAlert = false
    @State private var devVerificationMessage: String = ""
    
    // 分段入場動畫狀態
    
    private let totalPages = 9
    private let themePageIndex = 6

    private enum CardBankOption: String, CaseIterable, Hashable {
        case cathay
        case taishin

        var title: String {
            switch self {
            case .cathay: return CathayUnitedBankCard().displayName
            case .taishin: return TaishinCathayCard().displayName
            }
        }

        var icon: String {
            switch self {
            case .cathay: return "building.columns.fill"
            case .taishin: return "building.2.fill"
            }
        }
    }

    private enum NotificationPermissionStatus {
        case notDetermined
        case denied
        case authorized
    }

    private var preferredOnboardingColorScheme: ColorScheme? {
        if currentPage < themePageIndex {
            return .light
        }

        switch appliedOnboardingColorSchemeSetting {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func animateThemeTransition(to newScheme: String) {
        // 根據目標主題決定遮罩顏色，使過渡更自然
        themeOverlayColor = (newScheme == "dark") ? .black : .white

        // 階段一：遮罩淡入至完全不透明，遮蓋住畫面
        withAnimation(.easeIn(duration: 0.32)) {
            themeOverlayOpacity = 1.0
        }
        // 階段二：遮罩到達高點後，切換實際色彩主題，再把遮罩淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            appliedOnboardingColorSchemeSetting = newScheme
            withAnimation(.easeOut(duration: 0.45)) {
                themeOverlayOpacity = 0
            }
        }
    }

    private func moveToNextPage() {
        guard currentPage < totalPages - 1 else {
            completeOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage += 1
        }
    }
    
    var body: some View {
        ZStack {
            // 所有 Onboarding 頁面統一使用大地色圓形漸層背景
            OnboardingBlobBackground()
            
            VStack(spacing: 0) {
                // Page indicator（動態膠囊，帶彈性動畫）
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? OnboardingPalette.accentBright
                                  : OnboardingPalette.pageIndicatorInactive)
                            .frame(width: index == currentPage ? 24 : 6, height: 6)
                            .shadow(color: index == currentPage ? OnboardingPalette.accent.opacity(0.5) : .clear, radius: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    programPage.tag(1)
                    creditCardPage.tag(2)
                    departurePage.tag(3)
                    existingMilesPage.tag(4)
                    birthdayPage.tag(5)
                    themePage.tag(6)
                    notificationPage.tag(7)
                    iCloudPage.tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)
                
                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, AviationTheme.Spacing.lg)
                    .padding(.bottom, AviationTheme.Spacing.xl)
            }
        }
        .overlay {
            if themeOverlayOpacity > 0 {
                themeOverlayColor
                    .opacity(themeOverlayOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(preferredOnboardingColorScheme)
        .animation(nil, value: preferredOnboardingColorScheme)
        .navigationBarBackButtonHidden(true)
        .alert("開發者模式", isPresented: $showDevSkipAlert) {
            Button("跳過 Onboarding", role: .destructive) {
                skipOnboarding()
            }
            Button("繼續設定", role: .cancel) { }
        } message: {
            Text(devVerificationMessage)
        }
        .sheet(isPresented: $showingAirportPicker) {
            AirportPickerView(
                selectedAirport: Binding(
                    get: { selectedAirport },
                    set: { newValue in
                        selectedAirport = newValue
                        if let airport = newValue {
                            preferredOrigin = airport.iataCode
                        }
                    }
                ),
                airports: AirportDatabase.shared.getAllAirports()
            )
        }
        .onChange(of: currentPage) { oldValue, newValue in
            if newValue >= themePageIndex {
                if oldValue < themePageIndex {
                    // 從前面頁面（強制淺色）首次跨入主題頁時，
                    // 如果使用者的主題不是淺色，用遮罩過渡動畫切換。
                    if userColorScheme != "light" {
                        animateThemeTransition(to: userColorScheme)
                    } else {
                        appliedOnboardingColorSchemeSetting = userColorScheme
                    }
                }
            }
        }
        .onChange(of: userColorScheme) { _, _ in
            if currentPage >= themePageIndex {
                animateThemeTransition(to: userColorScheme)
            } else {
                appliedOnboardingColorSchemeSetting = userColorScheme
            }
        }
        .onAppear {
            // 初始化 viewModel 的 modelContext
            if viewModel.modelContext == nil {
                viewModel.initialize(context: modelContext)
            }

            appliedOnboardingColorSchemeSetting = userColorScheme

            Task {
                await refreshNotificationPermissionStatus()
            }
        }
    }
    
    // MARK: - Page 1: WELCOME
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            WelcomeHeroAnimationView()

            Spacer()
                .frame(height: AviationTheme.Spacing.lg)

            // 標題區域
            VStack(spacing: AviationTheme.Spacing.sm) {
                Text("歡迎使用 Milery")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(OnboardingPalette.titleText)

                Text("您的里程管理助手")
                    .font(AviationTheme.Typography.title3)
                    .foregroundColor(OnboardingPalette.bodyText)

                Text("簡單 · 直覺 · 掌握每一哩")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText.opacity(0.8))
                    .padding(.top, 2)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    // MARK: - Page 2: 里程計劃選擇
    private var programPage: some View {
        VStack(spacing: AviationTheme.Spacing.lg) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)
                
                Text("選擇里程計劃")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("您主要累積哪個航空里程計劃？")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
            }
            
            VStack(spacing: AviationTheme.Spacing.md) {
                ForEach(Array(MilageProgramType.allCases.enumerated()), id: \.element) { index, programType in
                    programSelectionCard(programType)
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    private func programSelectionCard(_ programType: MilageProgramType) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedProgramType = programType
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: programType.icon)
                    .font(.title2)
                    .foregroundColor(selectedProgramType == programType
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(programType.rawValue)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text(programType == .asiaMiles
                         ? "國泰航空/寰宇一家"
                         : "加入其他哩程計劃（開發中）")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }
                
                Spacer()
                
                Image(systemName: selectedProgramType == programType
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(selectedProgramType == programType
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(selectedProgramType == programType
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Page 3: 信用卡選擇
    private var creditCardPage: some View {
        ScrollView {
            VStack(spacing: AviationTheme.Spacing.lg) {
                Spacer().frame(height: AviationTheme.Spacing.md)
                
                VStack(spacing: AviationTheme.Spacing.sm) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 48))
                        .foregroundColor(OnboardingPalette.accent)
                    
                    Text("選擇信用卡")
                        .font(AviationTheme.Typography.title2)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text("選擇您持有的哩程信用卡，稍後也可以在設定中更改")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(OnboardingPalette.bodyText)
                        .multilineTextAlignment(.center)
                }
                
                // 我沒有相關信用卡 (已移除)
                
                bankSelectionSection

                if selectedCardBanks.contains(.cathay) {
                        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                            Text("國泰世華亞萬聯名卡等級")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(OnboardingPalette.titleText)
                                .padding(.leading, 4)

                            VStack(spacing: AviationTheme.Spacing.sm) {
                                ForEach(cathayDefinition.tiers) { tier in
                                    cathayTierCard(tier)
                                }
                            }
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                    }

                    if selectedCardBanks.contains(.taishin) {
                        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                            Text("台新國泰航空聯名卡等級")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(OnboardingPalette.titleText)
                                .padding(.leading, 4)

                            VStack(spacing: AviationTheme.Spacing.sm) {
                                ForEach(taishinDefinition.tiers) { tier in
                                    taishinTierCard(tier)
                                }
                            }
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                    }

                    if selectedCardBanks.isEmpty {
                        Text("先選擇您持有的銀行卡別，再選擇卡片等級")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(OnboardingPalette.bodyText)
                            .padding(.top, AviationTheme.Spacing.xs)
                    }
                
                Spacer().frame(height: AviationTheme.Spacing.xxl)
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    private var bankSelectionSection: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            Text("先選擇銀行卡別（可複選）")
                .font(AviationTheme.Typography.headline)
                .foregroundColor(OnboardingPalette.titleText)
                .padding(.leading, 4)

            VStack(spacing: AviationTheme.Spacing.sm) {
                ForEach(CardBankOption.allCases, id: \.self) { bank in
                    bankSelectionCard(bank)
                }
            }
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }

    private func bankSelectionCard(_ bank: CardBankOption) -> some View {
        let isSelected = selectedCardBanks.contains(bank)
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if isSelected {
                    selectedCardBanks.remove(bank)
                    if bank == .cathay {
                        selectedCathayTierID = nil
                    } else {
                        selectedTaishinTierID = nil
                    }
                } else {
                    selectedCardBanks.insert(bank)
                }
            }
        } label: {
            HStack(spacing: 16) {
                if let logoImageName = bankLogoImageName(for: bank) {
                    Image(logoImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: bank.icon)
                        .font(.title2)
                        .foregroundColor(isSelected
                                        ? OnboardingPalette.accent
                                        : OnboardingPalette.bodyText)
                        .frame(width: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bank.title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text(bank == .cathay ? "國泰世華銀行" : "台新銀行")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }

                Spacer()

                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func bankLogoImageName(for bank: CardBankOption) -> String? {
        let tiers: [CardTierDefinition]
        switch bank {
        case .cathay:
            tiers = cathayDefinition.tiers
        case .taishin:
            tiers = taishinDefinition.tiers
        }

        if let worldTierImage = tiers.first(where: {
            $0.id.localizedCaseInsensitiveContains("世界") ||
            $0.id.localizedCaseInsensitiveContains("world")
        })?.cardImageName {
            return worldTierImage
        }

        return tiers.first(where: { $0.cardImageName != nil })?.cardImageName
    }
    
    private func cathayTierCard(_ tier: CardTierDefinition) -> some View {
        let isSelected = selectedCathayTierID == tier.id
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if selectedCathayTierID == tier.id {
                    selectedCathayTierID = nil
                } else {
                    selectedCathayTierID = tier.id
                    selectedCardBanks.insert(.cathay)
                }
            }
        } label: {
            HStack(spacing: 14) {
                if let imageName = tier.cardImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.id)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text("一般 \(tier.rates.baseRate.formatted()) 元/哩 ・ 加速 \(tier.rates.secondaryRate.formatted()) 元/哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func taishinTierCard(_ tier: CardTierDefinition) -> some View {
        let isSelected = selectedTaishinTierID == tier.id
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if selectedTaishinTierID == tier.id {
                    selectedTaishinTierID = nil
                } else {
                    selectedTaishinTierID = tier.id
                    selectedCardBanks.insert(.taishin)
                }
            }
        } label: {
            HStack(spacing: 14) {
                if let imageName = tier.cardImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: tier.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 38)

                        Image(systemName: "creditcard.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.id)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)

                    Text("國內 \(tier.rates.baseRate.formatted()) 元/哩 ・ 國外 \(tier.rates.secondaryRate.formatted()) 元/哩 ・ 指定 \(tier.rates.tertiaryRate.formatted()) 元/哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }

                Spacer()

                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Page 4: 常用出發地
    private var departurePage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                ZStack {
                    PulseRingView(color: OnboardingPalette.accent.opacity(0.3))
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 48))
                        .foregroundColor(OnboardingPalette.accent)
                }
                
                Text("常用出發地")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("設定您最常出發的機場，方便快速建立飛行目標")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingAirportPicker = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "airplane.departure")
                        .font(.title2)
                        .foregroundColor(OnboardingPalette.accent)
                        .frame(width: 36)
                    
                    if preferredOrigin.isEmpty {
                        Text("點擊選擇出發機場")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(OnboardingPalette.bodyText)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preferredOrigin)
                                .font(AviationTheme.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(OnboardingPalette.accent)
                            
                            if let airport = AirportDatabase.shared.getAirport(iataCode: preferredOrigin) {
                                Text(airport.cityName)
                                    .font(AviationTheme.Typography.subheadline)
                                    .foregroundColor(OnboardingPalette.bodyText)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(OnboardingPalette.bodyText.opacity(0.7))
                }
                .padding(AviationTheme.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                        .stroke(!preferredOrigin.isEmpty
                                ? OnboardingPalette.accent
                                : Color.clear,
                                lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Text("此設定之後可在「設定 > 常用出發地」中更改")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(OnboardingPalette.bodyText.opacity(0.7))
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    // MARK: - Page 5: 現有里程輸入
    private var existingMilesPage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)
                
                Text("現有里程")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("如果您已有里程餘額，可以在這裡輸入，\n系統會自動記錄為「初次輸入」")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: AviationTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("目前里程餘額")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                    
                    HStack(spacing: 8) {
                        Text(existingMilesText.isEmpty ? "0" : existingMilesText)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(existingMilesText.isEmpty ? OnboardingPalette.bodyText.opacity(0.7) : OnboardingPalette.titleText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("哩")
                            .font(AviationTheme.Typography.title3)
                            .foregroundColor(OnboardingPalette.bodyText)
                            .padding(.top, 10) 
                    }
                    .padding(.vertical, AviationTheme.Spacing.md)
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                }
                .padding(.horizontal, AviationTheme.Spacing.md)

                customNumberPad
            }
            
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }

    private var customNumberPad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(1..<4, id: \.self) { col in
                        let number = row * 3 + col
                        numberPadButton(text: "\(number)") {
                            appendDigit("\(number)")
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Spacer()
                    .frame(maxWidth: .infinity)
                numberPadButton(text: "0") {
                    appendDigit("0")
                }
                numberPadButton(icon: "delete.left.fill") {
                    deleteDigit()
                }
            }
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
        .padding(.bottom, 8)
    }

    private func numberPadButton(text: String? = nil, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                }
            }
            .foregroundColor(OnboardingPalette.titleText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        let currentString = existingMilesText.replacingOccurrences(of: ",", with: "")
        guard currentString.count < 8 else { return } // 最多 8 位數 (99,999,999)
        let newString = currentString + digit
        if let value = Int(newString) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            existingMilesText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }

    private func deleteDigit() {
        var currentString = existingMilesText.replacingOccurrences(of: ",", with: "")
        guard !currentString.isEmpty else { return }
        currentString.removeLast()
        if let value = Int(currentString) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            existingMilesText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        } else {
            existingMilesText = ""
        }
    }
    
    // MARK: - Page 6: 生日選擇
    private var birthdayPage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)
                
                Text("生日月份")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("部分信用卡在生日當月消費可享哩程加倍，\n設定後系統會自動計算加碼")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: AviationTheme.Spacing.md) {
                // 啟用/跳過
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        enableBirthday = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundColor(enableBirthday
                                            ? OnboardingPalette.accent
                                            : OnboardingPalette.bodyText)
                            .frame(width: 36)
                        
                        Text("設定生日月份")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(OnboardingPalette.titleText)
                        
                        Spacer()
                        
                        Image(systemName: enableBirthday
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title3)
                            .foregroundColor(enableBirthday
                                            ? OnboardingPalette.accent
                                            : OnboardingPalette.bodyText.opacity(0.7))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(enableBirthday
                                    ? OnboardingPalette.accent
                                    : Color.clear,
                                    lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // 月份選擇器
                if enableBirthday {
                    let columns = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(1...12, id: \.self) { month in
                            let isSelected = selectedBirthdayMonth == month
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedBirthdayMonth = month
                                }
                            } label: {
                                Text("\(month) 月")
                                    .font(AviationTheme.Typography.subheadline)
                                    .fontWeight(isSelected ? .bold : .medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                            .fill(isSelected
                                                  ? OnboardingPalette.accent
                                                  : Color.white.opacity(0.25))
                                    )
                                    .foregroundColor(isSelected ? .white : OnboardingPalette.titleText)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                            .stroke(isSelected ? OnboardingPalette.accent : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // 不設定
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        enableBirthday = false
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(!enableBirthday
                                            ? OnboardingPalette.accent
                                            : OnboardingPalette.bodyText)
                            .frame(width: 36)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("暫時不設定")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(OnboardingPalette.titleText)
                            
                            Text("不會觸發生日加倍計算")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(OnboardingPalette.bodyText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: !enableBirthday
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title3)
                            .foregroundColor(!enableBirthday
                                            ? OnboardingPalette.accent
                                            : OnboardingPalette.bodyText.opacity(0.7))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(!enableBirthday
                                    ? OnboardingPalette.accent
                                    : Color.clear,
                                    lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    // MARK: - Page 7: 主題選擇
    private var themePage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)
                
                Text("外觀主題")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("選擇您偏好的顯示模式")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
            }
            
            VStack(spacing: AviationTheme.Spacing.md) {
                themeOptionCard(
                    icon: "circle.lefthalf.filled",
                    title: "跟隨系統",
                    subtitle: "隨裝置設定自動切換淺色 / 深色",
                    value: "system"
                )
                
                themeOptionCard(
                    icon: "sun.max.fill",
                    title: "淺色模式",
                    subtitle: "始終使用明亮的淺色背景",
                    value: "light"
                )
                
                themeOptionCard(
                    icon: "moon.fill",
                    title: "深色模式",
                    subtitle: "始終使用暗色背景，減少眩光",
                    value: "dark"
                )
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Text("此設定之後可在「設定 > 外觀」中更改")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(OnboardingPalette.bodyText.opacity(0.7))
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    private func themeOptionCard(icon: String, title: String, subtitle: String, value: String) -> some View {
        let isSelected = userColorScheme == value
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                userColorScheme = value
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 8: 通知權限
    private var notificationPage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()

            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)

                Text("通知提醒")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)

                Text("開啟通知後，可收到哩程到期與目標進度提醒")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                notificationInfoRow(icon: "clock.badge.exclamationmark", text: "哩程即將到期提醒")
                notificationInfoRow(icon: "airplane.departure", text: "目標航線達成進度通知")
                notificationInfoRow(icon: "gift", text: "生日月加碼與活動提醒")
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(OnboardingPalette.accent.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, AviationTheme.Spacing.md)

            VStack(spacing: AviationTheme.Spacing.md) {
                Button {
                    requestNotificationPermission()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: notificationPermissionStatus == .authorized ? "checkmark.bell.fill" : "bell.fill")
                            .font(.title2)
                            .foregroundColor(notificationPermissionStatus == .authorized
                                            ? AviationTheme.Colors.success
                                            : OnboardingPalette.accent)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(notificationPermissionStatus == .authorized ? "通知已開啟" : "開啟通知權限")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(OnboardingPalette.titleText)

                            Text(notificationStatusSubtitle)
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(OnboardingPalette.bodyText)
                        }

                        Spacer()

                        Image(systemName: notificationPermissionStatus == .authorized ? "checkmark.circle.fill" : "chevron.right")
                            .font(.title3)
                            .foregroundColor(notificationPermissionStatus == .authorized
                                            ? AviationTheme.Colors.success
                                            : OnboardingPalette.bodyText.opacity(0.7))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(notificationPermissionStatus == .authorized
                                    ? AviationTheme.Colors.success
                                    : OnboardingPalette.accent.opacity(0.4),
                                    lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                if notificationPermissionStatus == .denied {
                    Button {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                              UIApplication.shared.canOpenURL(settingsURL) else {
                            return
                        }
                        UIApplication.shared.open(settingsURL)
                    } label: {
                        Text("前往系統設定開啟通知")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(OnboardingPalette.accent)
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)

            Text("點選「下一步」也會直接觸發系統權限詢問，\n您可以稍後在「設定 > 通知提醒」調整。")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(OnboardingPalette.bodyText.opacity(0.7))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }

    private var notificationStatusSubtitle: String {
        switch notificationPermissionStatus {
        case .authorized:
            return "將接收哩程到期與目標提醒"
        case .denied:
            return "目前已拒絕，需至系統設定手動開啟"
        case .notDetermined:
            return "點擊後會跳出系統權限詢問"
        }
    }

    private func notificationInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(OnboardingPalette.accent)
                .font(.subheadline)
                .frame(width: 16)

            Text(text)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(OnboardingPalette.titleText)

            Spacer()
        }
    }
    
    // MARK: - Page 9: CloudKit同步設定
    private var iCloudPage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OnboardingPalette.accent)
                
                Text("iCloud 同步")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(OnboardingPalette.titleText)
                
                Text("開啟後，您的資料會在所有 Apple 裝置間自動同步")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(OnboardingPalette.bodyText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: AviationTheme.Spacing.md) {
                iCloudOptionCard(
                    icon: "icloud.and.arrow.up.fill",
                    title: "開啟 iCloud 同步",
                    subtitle: "資料自動備份至 iCloud，在多裝置間同步",
                    isSelected: cloudKitSyncEnabled
                ) {
                    withAnimation(.spring(duration: 0.25)) {
                        cloudKitSyncEnabled = true
                    }
                }
                
                iCloudOptionCard(
                    icon: "internaldrive.fill",
                    title: "僅存在本機，手動備份",
                    subtitle: "資料不會自動同步，但您可以隨時手動上傳 iCloud 備份",
                    isSelected: !cloudKitSyncEnabled
                ) {
                    withAnimation(.spring(duration: 0.25)) {
                        cloudKitSyncEnabled = false
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Text("此設定之後可在「設定 > 備份與同步」中更改")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(OnboardingPalette.bodyText.opacity(0.7))
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    private func iCloudOptionCard(icon: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(OnboardingPalette.titleText)
                    
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(OnboardingPalette.bodyText)
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? OnboardingPalette.accent
                                    : OnboardingPalette.bodyText.opacity(0.7))
            }
            .padding(AviationTheme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? OnboardingPalette.accent
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 底部按鈕們
    private var bottomButtons: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // 返回按鈕：小型「<」
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.glassButtonText)
                            .frame(width: 52, height: 52)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                }

                // 下一步 / 跳過 / 開始使用
                Button {
                    if currentPage == 7 {
                        if notificationPermissionStatus == .notDetermined {
                            requestNotificationPermission(advanceAfterRequest: true)
                        } else {
                            moveToNextPage()
                        }
                        return
                    }
                    moveToNextPage()
                } label: {
                    Text(bottomNextButtonText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(OnboardingPalette.glassButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1)
                        .onEnded { _ in
                            guard currentPage == 0 else { return }
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            verifyDevAndPromptSkip()
                        }
                )
            }
        }
    }

    private var bottomNextButtonText: String {
        if currentPage == totalPages - 1 {
            return "開始使用"
        }
        if currentPage == 2 && selectedCardBanks.isEmpty {
            return "跳過"
        }
        if currentPage == 4 && (existingMilesText.isEmpty || existingMilesText == "0") {
            return "跳過"
        }
        return "下一步"
    }


    
    // MARK: - 完成 Onboarding
    private func completeOnboarding() {
        // 寫入現有里程（如果有輸入）
        if let miles = Int(existingMilesText.replacingOccurrences(of: ",", with: "")),
           miles > 0 {
            viewModel.addTransaction(
                amount: 0,
                earnedMiles: miles,
                source: .initialInput,
                notes: "初次設定時輸入的現有里程"
            )
        }
        
        // 寫入生日月份（持久化到 UserDefaults）
        if enableBirthday {
            viewModel.userBirthdayMonth = selectedBirthdayMonth
        } else {
            viewModel.userBirthdayMonth = 0
        }

        if selectedCardBanks.isEmpty {
            if let cathayCard = viewModel.creditCards.first(where: { $0.cardBrand == .cathayUnitedBank }) {
                cathayCard.isActive = false
            }
            if let taishinCard = viewModel.creditCards.first(where: { $0.cardBrand == .taishinCathay }) {
                taishinCard.isActive = false
            }
        } else {
            if let cathayCard = viewModel.creditCards.first(where: { $0.cardBrand == .cathayUnitedBank }) {
                if selectedCardBanks.contains(.cathay), let selectedCathayTierID {
                    cathayCard.updateTier(selectedCathayTierID)
                    cathayCard.isActive = true
                } else {
                    cathayCard.isActive = false
                }
            }

            if let taishinCard = viewModel.creditCards.first(where: { $0.cardBrand == .taishinCathay }) {
                if selectedCardBanks.contains(.taishin), let selectedTaishinTierID {
                    taishinCard.updateTier(selectedTaishinTierID)
                    taishinCard.isActive = true
                } else {
                    taishinCard.isActive = false
                }
            }
        }

        viewModel.saveCardPreferences()
        
        // 標記 Onboarding 已完成
        hasCompletedOnboarding = true
        
        dismiss()
    }

    private func skipOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }

    private func verifyDevAndPromptSkip() {
        Task {
            let result = await DeveloperAccessService.shared.verifyCurrentUserAccess()
            await MainActor.run {
                switch result {
                case .allowed:
                    devVerificationMessage = "已驗證白名單身分，是否要跳過 Onboarding 直接進入主畫面？"
                    showDevSkipAlert = true
                case .denied:
                    // 非開發者，靜默忽略，不顯示任何提示
                    break
                }
            }
        }
    }

    private func requestNotificationPermission(advanceAfterRequest: Bool = false) {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                await MainActor.run {
                    enableNotifications = granted
                    notificationPermissionStatus = granted ? .authorized : .denied
                    if advanceAfterRequest {
                        moveToNextPage()
                    }
                }
                await refreshNotificationPermissionStatus()
            } catch {
                await MainActor.run {
                    enableNotifications = false
                    notificationPermissionStatus = .denied
                    if advanceAfterRequest {
                        moveToNextPage()
                    }
                }
            }
        }
    }

    private func refreshNotificationPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notificationPermissionStatus = .authorized
                enableNotifications = true
            case .denied:
                notificationPermissionStatus = .denied
                enableNotifications = false
            case .notDetermined:
                notificationPermissionStatus = .notDetermined
                enableNotifications = false
            @unknown default:
                notificationPermissionStatus = .notDetermined
                enableNotifications = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView(viewModel: MileageViewModel())
            .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, MileageProgram.self])
    }
}
