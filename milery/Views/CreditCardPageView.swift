import SwiftUI
import SwiftData

struct CreditCardPageView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor: return false
        }
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
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
        .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
    }
}

// MARK: - 單張信用卡卡片
struct CreditCardCell: View {
    let card: CreditCardRule
    @Bindable var viewModel: MileageViewModel
    let colorScheme: ColorScheme
    @State private var showingCategoryInfo = false
    
    /// 從 Registry 取得品牌定義
    var brandDef: CardBrandDefinition? {
        card.brandDefinition
    }
    
    /// 從 Registry 取得等級定義
    var tierDef: CardTierDefinition? {
        card.tierDefinition
    }
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: 卡片名稱
            VStack(alignment: .leading, spacing: 2) {
                Text(card.bankName)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                Text(card.cardName)
                    .font(AviationTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            .padding(.top, AviationTheme.Spacing.md)
            
            // MARK: 卡面視覺（僅有圖片時顯示）
            if let def = brandDef, def.usesCardImage, tierDef?.cardImageName != nil {
                cardVisual
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.top, AviationTheme.Spacing.sm)
            }
            
            // MARK: 等級選擇
            if let def = brandDef, def.tiers.count > 1 {
                tierPicker(definition: def)
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.top, AviationTheme.Spacing.md)
            }
            
            // MARK: 費率資訊
            if let def = brandDef {
                rateInfoSection(definition: def)
            }
            
            Divider()
                .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                .padding(.horizontal, AviationTheme.Spacing.md)
            
            // MARK: 啟用開關
            toggleSection
        }
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(card.isActive ? AviationTheme.Colors.cathayJade.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - 卡面視覺
    @ViewBuilder
    private var cardVisual: some View {
        if let imageName = tierDef?.cardImageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        }
    }
    
    // MARK: - 等級選擇器
    private func tierPicker(definition: CardBrandDefinition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡片等級")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            
            Picker("等級", selection: Binding(
                get: { card.cardTierRaw },
                set: { newTierID in
                    viewModel.updateCardTier(card, tierID: newTierID)
                }
            )) {
                ForEach(definition.tiers) { tier in
                    Text(tier.id).tag(tier.id)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - 費率資訊（通用）
    private func rateInfoSection(definition: CardBrandDefinition) -> some View {
        VStack(spacing: 12) {
            // 費率欄位
            let slots = definition.rateSlots
            let rateSlots = slots.filter { !$0.isAnnualFee }
            let feeSlots = slots.filter { $0.isAnnualFee }
            
            if !rateSlots.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(rateSlots.enumerated()), id: \.offset) { index, slot in
                        if slot.showInfoButton, let mapping = slot.infoSourceMapping {
                            // 帶 info 按鈕的費率欄位
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(slot.title)
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                    
                                    Button {
                                        showingCategoryInfo = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundColor(AviationTheme.Colors.cathayJade)
                                    }
                                    .popover(isPresented: $showingCategoryInfo) {
                                        CategoryInfoPopover(mapping: mapping, colorScheme: colorScheme)
                                            .presentationCompactAdaptation(.popover)
                                    }
                                }
                                Text("\(rateValue(for: slot).formatted()) 元/哩")
                                    .font(AviationTheme.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AviationTheme.Colors.warning)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            rateColumn(title: slot.title, value: "\(rateValue(for: slot).formatted()) 元/哩", highlight: false)
                        }
                        
                        if index < rateSlots.count - 1 {
                            Divider()
                                .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                                .frame(height: 40)
                        }
                    }
                }
            }
            
            // 年費欄位（如果有的話，跟費率放在一起）
            if !feeSlots.isEmpty {
                if !rateSlots.isEmpty {
                    // 如果費率欄位有 3 個以上，年費放下一行
                    if rateSlots.count >= 3 {
                        HStack(spacing: 0) {
                            rateColumn(title: "年費", value: "NT$ \(card.annualFee.formatted())", highlight: false)
                        }
                    } else {
                        // 否則加在費率欄位的最後面（已在上面的 HStack 裡處理）
                        // 但因為 feeSlots 是分開的，這裡加一個分隔的年費行
                    }
                }
            }
            
            // 如果費率欄位少於 3 個，年費跟費率放同一行（重新渲染整個 HStack）
            // 簡化：年費一律放在費率下方（跟台新一致）
            if !feeSlots.isEmpty && rateSlots.count < 3 {
                HStack(spacing: 0) {
                    Divider()
                        .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                        .frame(height: 40)
                        .hidden()
                    rateColumn(title: "年費", value: "NT$ \(card.annualFee.formatted())", highlight: false)
                }
            }
            
            // 年度加速上限提示
            if let tier = tierDef, tier.rates.annualCap > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    Text("年度加速上限 \(tier.rates.annualCap.formatted()) 哩")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
        .padding(.vertical, AviationTheme.Spacing.md)
    }
    
    /// 根據 slot 的 rateKeyPath 取得對應費率
    private func rateValue(for slot: CardRateSlot) -> Decimal {
        switch slot.rateKeyPath {
        case .base: return card.baseRate
        case .secondary: return card.acceleratorRate
        case .tertiary: return card.specialMerchantRate
        }
    }
    
    // MARK: - 啟用開關
    private var toggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if card.isActive {
                    HStack(spacing: 4) {
                        Text("已啟用")
                            .font(AviationTheme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        if !card.cardTierRaw.isEmpty {
                            Text("：\(card.cardTierRaw)")
                                .font(AviationTheme.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                        }
                    }
                } else {
                    Text("已停用")
                        .font(AviationTheme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
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

// MARK: - 通用子類別說明 Popover（取代 AcceleratorInfoPopover + TaishinDesignatedInfoPopover）
struct CategoryInfoPopover: View {
    let mapping: CardMileageSourceMapping
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mapping.infoPopoverTitle)
                .font(AviationTheme.Typography.headline)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            
            Text(mapping.infoPopoverSubtitle)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            
            ForEach(mapping.subcategories) { category in
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundColor(AviationTheme.Colors.warning)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.id)
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        Text(category.description)
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .frame(width: 280)
    }
}

#Preview {
    NavigationStack {
        CreditCardPageView(viewModel: MileageViewModel())
            .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
    }
}
