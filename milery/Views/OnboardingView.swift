import SwiftUI
import SwiftData
import UserNotifications
import UIKit

// MARK: - 浮動粒子視圖（幾何圓點，非 emoji）
struct FloatingParticlesView: View {
    let colorScheme: ColorScheme
    @State private var phase = false

    var body: some View {
        Canvas { context, size in
            let t = phase ? 1.0 : 0.0
            for i in 0..<15 {
                let seed = Double(i)
                let baseX = size.width * ((seed * 0.618).truncatingRemainder(dividingBy: 1.0))
                let baseY = size.height * ((seed * 0.381).truncatingRemainder(dividingBy: 1.0))
                let dx = sin(seed * 1.3 + t * .pi * 2) * 12
                let dy = cos(seed * 0.9 + t * .pi * 2) * 18
                let r = 2.5 + (seed.truncatingRemainder(dividingBy: 3)) * 1.5
                let alpha = 0.12 + (seed.truncatingRemainder(dividingBy: 4)) * 0.06
                let rect = CGRect(x: baseX + dx - r, y: baseY + dy - r, width: r * 2, height: r * 2)
                context.fill(Circle().path(in: rect),
                             with: .color(AviationTheme.Colors.cathayJade.opacity(alpha)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) { phase = true }
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

// MARK: - 歡迎頁英雄動畫視圖
struct WelcomeHeroAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 中心擴散的漸層光暈
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            AviationTheme.Colors.cathayJade.opacity(0.4),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .scaleEffect(isAnimating ? 1.15 : 0.85)
                .opacity(isAnimating ? 1 : 0.6)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)

            // 外圍點狀飛行軌道
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AviationTheme.Colors.cathayJade, AviationTheme.Colors.cathayJade.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 12])
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: isAnimating)

            // 中心實線裝飾軌道
            Circle()
                .stroke(AviationTheme.Colors.cathayJade.opacity(0.2), lineWidth: 1)
                .frame(width: 75, height: 75)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimating)

            // 轉圈圈的飛機群組
            ZStack {
                // 飛機拖尾粒子
                Circle()
                    .fill(AviationTheme.Colors.cathayJade.opacity(0.8))
                    .frame(width: 4, height: 4)
                    .offset(x: -8, y: 15)
                    .blur(radius: 2)

                Image("73") 
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70) // 放大一倍
                    .rotationEffect(.degrees(10)) 
            }
            .offset(y: -65) // 在軌道上 半徑是 65
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: isAnimating)

            // 中央主要 Icon
            Image(systemName: "globe.asia.australia.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .shadow(color: AviationTheme.Colors.cathayJade.opacity(0.5), radius: 8, x: 0, y: 4)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimating)
        }
        .frame(width: 180, height: 180)
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
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            // 歡迎頁浮動粒子（只在第 0 頁顯示）
            if currentPage == 0 {
                FloatingParticlesView(colorScheme: colorScheme)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            VStack(spacing: 0) {
                // Page indicator（動態膠囊，帶彈性動畫）
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? AviationTheme.Colors.cathayJade
                                  : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 6, height: 6)
                            .shadow(color: index == currentPage ? AviationTheme.Colors.cathayJade.opacity(0.4) : .clear, radius: 4)
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
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            WelcomeHeroAnimationView()
            
            VStack(spacing: AviationTheme.Spacing.md) {
                Text("歡迎使用 Milery")
                    .font(AviationTheme.Typography.largeTitle)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("您的里程管理助手")
                    .font(AviationTheme.Typography.title3)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            VStack(spacing: AviationTheme.Spacing.md) {
                featureRow(icon: "chart.line.uptrend.xyaxis", title: "追蹤里程累積進度")
                featureRow(icon: "creditcard.fill", title: "信用卡哩程計算")
                featureRow(icon: "ticket.fill", title: "兌換機票目標規劃")
                featureRow(icon: "icloud.fill", title: "iCloud 跨裝置同步")
            }
            .padding(.horizontal, AviationTheme.Spacing.xl)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
    
    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .frame(width: 32)
            
            Text(title)
                .font(AviationTheme.Typography.body)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            
            Spacer()
        }
    }
    
    // MARK: - Page 2: 里程計劃選擇
    private var programPage: some View {
        VStack(spacing: AviationTheme.Spacing.lg) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 48))
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                
                Text("選擇里程計劃")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("您主要累積哪個航空里程計劃？")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.secondaryText(colorScheme))
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(programType.rawValue)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(programType == .asiaMiles
                         ? "國泰航空/寰宇一家"
                         : "加入其他哩程計劃（開發中）")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Image(systemName: selectedProgramType == programType
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(selectedProgramType == programType
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(selectedProgramType == programType
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
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
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    
                    Text("選擇信用卡")
                        .font(AviationTheme.Typography.title2)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("選擇您持有的哩程信用卡，稍後也可以在設定中更改")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .multilineTextAlignment(.center)
                }
                
                // 我沒有相關信用卡 (已移除)
                
                bankSelectionSection

                if selectedCardBanks.contains(.cathay) {
                        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                            Text("國泰世華亞萬聯名卡等級")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
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
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
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
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
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
                                        ? AviationTheme.Colors.cathayJade
                                        : AviationTheme.Colors.secondaryText(colorScheme))
                        .frame(width: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bank.title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(bank == .cathay ? "國泰世華銀行" : "台新銀行")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }

                Spacer()

                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
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
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("一般 \(tier.rates.baseRate.formatted()) 元/哩 ・ 加速 \(tier.rates.secondaryRate.formatted()) 元/哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
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
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                    Text("國內 \(tier.rates.baseRate.formatted()) 元/哩 ・ 國外 \(tier.rates.secondaryRate.formatted()) 元/哩 ・ 指定 \(tier.rates.tertiaryRate.formatted()) 元/哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }

                Spacer()

                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Page 4: 常用出發地
    private var departurePage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: AviationTheme.Spacing.sm) {
                ZStack {
                    PulseRingView(color: AviationTheme.Colors.cathayJade.opacity(0.3))
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 48))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                }
                
                Text("常用出發地")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("設定您最常出發的機場，方便快速建立飛行目標")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingAirportPicker = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "airplane.departure")
                        .font(.title2)
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                        .frame(width: 36)
                    
                    if preferredOrigin.isEmpty {
                        Text("點擊選擇出發機場")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preferredOrigin)
                                .font(AviationTheme.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                            
                            if let airport = AirportDatabase.shared.getAirport(iataCode: preferredOrigin) {
                                Text(airport.cityName)
                                    .font(AviationTheme.Typography.subheadline)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .padding(AviationTheme.Spacing.md)
                .background(AviationTheme.Colors.cardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                        .stroke(!preferredOrigin.isEmpty
                                ? AviationTheme.Colors.cathayJade
                                : Color.clear,
                                lineWidth: 2)
                )
                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AviationTheme.Spacing.md)
            
            Text("此設定之後可在「設定 > 常用出發地」中更改")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            
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
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                
                Text("現有里程")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("如果您已有里程餘額，可以在這裡輸入，\n系統會自動記錄為「初次輸入」")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: AviationTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("目前里程餘額")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                    HStack(spacing: 8) {
                        Text(existingMilesText.isEmpty ? "0" : existingMilesText)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(existingMilesText.isEmpty ? AviationTheme.Colors.tertiaryText(colorScheme) : AviationTheme.Colors.primaryText(colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("哩")
                            .font(AviationTheme.Typography.title3)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            .padding(.top, 10) 
                    }
                    .padding(.vertical, AviationTheme.Spacing.md)
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3), lineWidth: 1)
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
            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 4, x: 0, y: 1)
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
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                
                Text("生日月份")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("部分信用卡在生日當月消費可享哩程加倍，\n設定後系統會自動計算加碼")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                                            ? AviationTheme.Colors.cathayJade
                                            : AviationTheme.Colors.secondaryText(colorScheme))
                            .frame(width: 36)
                        
                        Text("設定生日月份")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        
                        Spacer()
                        
                        Image(systemName: enableBirthday
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title3)
                            .foregroundColor(enableBirthday
                                            ? AviationTheme.Colors.cathayJade
                                            : AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(enableBirthday
                                    ? AviationTheme.Colors.cathayJade
                                    : Color.clear,
                                    lineWidth: 2)
                    )
                    .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
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
                                                  ? AviationTheme.Colors.cathayJade
                                                  : AviationTheme.Colors.cardBackground(colorScheme))
                                    )
                                    .foregroundColor(isSelected ? .white : AviationTheme.Colors.primaryText(colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                            .stroke(isSelected ? AviationTheme.Colors.cathayJade : Color.clear, lineWidth: 2)
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
                                            ? AviationTheme.Colors.cathayJade
                                            : AviationTheme.Colors.secondaryText(colorScheme))
                            .frame(width: 36)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("暫時不設定")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            
                            Text("不會觸發生日加倍計算")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                        
                        Spacer()
                        
                        Image(systemName: !enableBirthday
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title3)
                            .foregroundColor(!enableBirthday
                                            ? AviationTheme.Colors.cathayJade
                                            : AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(!enableBirthday
                                    ? AviationTheme.Colors.cathayJade
                                    : Color.clear,
                                    lineWidth: 2)
                    )
                    .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
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
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                
                Text("外觀主題")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("選擇您偏好的顯示模式")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            
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
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.secondaryText(colorScheme))
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
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
                    .foregroundColor(AviationTheme.Colors.cathayJade)

                Text("通知提醒")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                Text("開啟通知後，可收到哩程到期與目標進度提醒")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                notificationInfoRow(icon: "clock.badge.exclamationmark", text: "哩程即將到期提醒")
                notificationInfoRow(icon: "airplane.departure", text: "目標航線達成進度通知")
                notificationInfoRow(icon: "gift", text: "生日月加碼與活動提醒")
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(AviationTheme.Colors.cathayJade.opacity(0.2), lineWidth: 1)
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
                                            : AviationTheme.Colors.cathayJade)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(notificationPermissionStatus == .authorized ? "通知已開啟" : "開啟通知權限")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                            Text(notificationStatusSubtitle)
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }

                        Spacer()

                        Image(systemName: notificationPermissionStatus == .authorized ? "checkmark.circle.fill" : "chevron.right")
                            .font(.title3)
                            .foregroundColor(notificationPermissionStatus == .authorized
                                            ? AviationTheme.Colors.success
                                            : AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(notificationPermissionStatus == .authorized
                                    ? AviationTheme.Colors.success
                                    : AviationTheme.Colors.cathayJade.opacity(0.4),
                                    lineWidth: 1.5)
                    )
                    .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
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
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)

            Text("點選「下一步」也會直接觸發系統權限詢問，\n您可以稍後在「設定 > 通知提醒」調整。")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))

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
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .font(.subheadline)
                .frame(width: 16)

            Text(text)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

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
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                
                Text("iCloud 同步")
                    .font(AviationTheme.Typography.title2)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text("開啟後，您的資料會在所有 Apple 裝置間自動同步")
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            
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
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.secondaryText(colorScheme))
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(subtitle)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 底部按鈕們
    private var bottomButtons: some View {
        HStack(spacing: AviationTheme.Spacing.md) {

            if currentPage > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                } label: {
                    Text("上一步")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                                .stroke(AviationTheme.Colors.cathayJade.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
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
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(bottomNextButtonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(bottomNextButtonBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                            .stroke(bottomNextButtonStrokeColor, lineWidth: 1)
                    )
            }
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

    private var bottomNextButtonTextColor: Color {
        if currentPage == 2 && selectedCardBanks.isEmpty {
            return AviationTheme.Colors.cathayJade
        }
        if currentPage == 4 && (existingMilesText.isEmpty || existingMilesText == "0") {
            return AviationTheme.Colors.cathayJade
        }
        return .white
    }

    private var bottomNextButtonBackgroundColor: Color {
        if currentPage == 2 && selectedCardBanks.isEmpty {
            return AviationTheme.Colors.cardBackground(colorScheme)
        }
        if currentPage == 4 && (existingMilesText.isEmpty || existingMilesText == "0") {
            return AviationTheme.Colors.cardBackground(colorScheme)
        }
        return AviationTheme.Colors.cathayJade
    }

    private var bottomNextButtonStrokeColor: Color {
        if currentPage == 2 && selectedCardBanks.isEmpty {
            return AviationTheme.Colors.cathayJade.opacity(0.3)
        }
        if currentPage == 4 && (existingMilesText.isEmpty || existingMilesText == "0") {
            return AviationTheme.Colors.cathayJade.opacity(0.3)
        }
        return .clear
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
