import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MileageViewModel
    
    @State private var currentPage = 0
    
    // Page 2: 里程計劃選擇
    @State private var selectedProgramType: MilageProgramType = .asiaMiles
    
    // Page 3: 信用卡選擇
    @State private var selectedCathayTierID: String? = nil
    @State private var enableTaishinCard = false
    
    private let cathayDefinition = CathayUnitedBankCard()
    private let taishinDefinition = TaishinCathayCard()
    
    // Page 4: Cloudkit同步設定
    @AppStorage("cloudKitSyncEnabled") private var cloudKitSyncEnabled: Bool = true
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? AviationTheme.Colors.cathayJade
                                  : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    programPage.tag(1)
                    creditCardPage.tag(2)
                    iCloudPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, AviationTheme.Spacing.lg)
                    .padding(.bottom, AviationTheme.Spacing.xl)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("關閉") {
                    dismiss()
                }
                .foregroundColor(AviationTheme.Colors.cathayJade)
            }
        }
    }
    
    // MARK: - Page 1: WELCOME
    private var welcomePage: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            Spacer()
            
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    AviationTheme.Gradients.cathayJadeGradient(colorScheme)
                )
            
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
                ForEach(MilageProgramType.allCases, id: \.self) { programType in
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
                         ? "國泰航空亞洲萬里通"
                         : "其他里程計劃")
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
                
                // Cathay United Bank card
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                    Text("國泰世華亞萬聯名卡")
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
                
                // Taishin card
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                    Text("台新國泰航空聯名卡")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        .padding(.leading, 4)
                    
                    taishinCard
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                
                Spacer().frame(height: AviationTheme.Spacing.xxl)
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    private func cathayTierCard(_ tier: CardTierDefinition) -> some View {
        let isSelected = selectedCathayTierID == tier.id
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if selectedCathayTierID == tier.id {
                    selectedCathayTierID = nil
                } else {
                    selectedCathayTierID = tier.id
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
    
    private var taishinCard: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                enableTaishinCard.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.05, green: 0.25, blue: 0.15),
                                     Color(red: 0.15, green: 0.5, blue: 0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 38)
                    
                    Image(systemName: "creditcard.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("台新國泰航空聯名卡")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("計算規則開發中")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.warning)
                }
                
                Spacer()
                
                Image(systemName: enableTaishinCard
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.title3)
                    .foregroundColor(enableTaishinCard
                                    ? AviationTheme.Colors.cathayJade
                                    : AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(enableTaishinCard
                            ? AviationTheme.Colors.cathayJade
                            : Color.clear,
                            lineWidth: 2)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Page 4: CloudKit同步設定
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
                    title: "僅儲存在本機",
                    subtitle: "資料只存在此裝置，不會上傳至 iCloud",
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
                if currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                Text(currentPage < totalPages - 1 ? "下一步" : "開始使用")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AviationTheme.Colors.cathayJade)
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
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
