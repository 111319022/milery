import SwiftUI
import SwiftData

/// 共用交易表單 — 由 CalculatorLedgerView 和 EditTransactionView 共用
struct TransactionFormView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @Bindable var viewModel: MileageViewModel
    
    private var hasBackgroundImage: Bool {
        backgroundSelection != .none
    }
    
    @Binding var selectedSource: MileageSource
    @Binding var selectedCard: CreditCardRule?
    @Binding var selectedSubcategoryID: String?
    @Binding var amount: String
    @Binding var earnedMiles: String
    @Binding var date: Date
    @Binding var notes: String
    @Binding var flightRoute: String
    @Binding var conversionSource: String
    @Binding var merchantName: String
    @Binding var promotionName: String
    @FocusState.Binding var focusedField: TransactionField?
    
    enum TransactionField {
        case amount, miles
    }
    
    // MARK: - 頂層類別
    
    /// 是否為信用卡消費模式
    var isCardMode: Bool {
        CardBrandRegistry.sourceNeedsCard(selectedSource)
    }
    
    var activeCards: [CreditCardRule] {
        viewModel.creditCards.filter { $0.isActive }
    }
    
    /// 非信用卡的哩程來源
    private let nonCardSources: [MileageSource] = [
        .specialMerchant,
        .flight,
        .promotion,
        .pointsConversion,
        .pointsTransfer
    ]
    
    /// 選定的卡片所屬品牌的 sourceMappings
    var cardSourceMappings: [CardMileageSourceMapping] {
        guard let card = selectedCard,
              let def = CardBrandRegistry.definition(for: card.cardBrand) else { return [] }
        return def.sourceMappings
    }
    
    /// 當前來源是否需要子類別選擇
    var subcategoryMapping: CardMileageSourceMapping? {
        CardBrandRegistry.subcategoryMapping(for: selectedSource)
    }
    
    var needsAmountInput: Bool {
        CardBrandRegistry.sourceNeedsAmount(selectedSource)
    }
    
    var canCalculateMiles: Bool {
        isCardMode && selectedCard != nil && !amount.isEmpty
    }
    
    var body: some View {
        VStack(spacing: AviationTheme.Spacing.xl) {
            // 1. 頂層選擇：信用卡消費 / 其他來源
            topCategorySelector
            
            if isCardMode {
                // 2a. 信用卡模式：選卡 → 來源（帶費率） → 子類別 → 金額
                if !activeCards.isEmpty {
                    cardSelectionSection
                }
                
                if selectedCard != nil {
                    cardSourceSelector
                }
                
                if let mapping = subcategoryMapping {
                    subcategorySection(mapping: mapping)
                }
            } else {
                // 2b. 非信用卡：直接顯示非卡來源
                nonCardSourceSelector
            }
            
            // 3. 交易資訊（金額 / 哩程）
            transactionInputSection
            
            // 4. 額外資訊
            if !isCardMode && (selectedSource == .flight || selectedSource == .pointsConversion || selectedSource == .pointsTransfer || selectedSource == .specialMerchant || selectedSource == .promotion) {
                extraInfoSection
            }
            
            // 5. 其他資訊（日期 / 備註）
            additionalInfoSection
        }
    }
    
    // MARK: - Section 標題（自動加模糊底板）
    private func formSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AviationTheme.Typography.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            .padding(.horizontal, hasBackgroundImage ? 12 : 28)
            .padding(.vertical, hasBackgroundImage ? 4 : 0)
            .background {
                if hasBackgroundImage {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
            .padding(.horizontal, hasBackgroundImage ? 16 : 0)
    }
    
    // MARK: - 頂層類別選擇器（信用卡消費 vs 其他）
    private var topCategorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("記帳類型")
            
            HStack(spacing: 12) {
                topCategoryButton(
                    icon: "creditcard.fill",
                    title: "信用卡消費",
                    isSelected: isCardMode
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSource = .cardGeneral
                        // 自動選卡（若只有一張）
                        if activeCards.count == 1, selectedCard == nil {
                            selectedCard = activeCards.first
                        }
                        selectedSubcategoryID = nil
                    }
                }
                
                topCategoryButton(
                    icon: "ellipsis.circle.fill",
                    title: "其他來源",
                    isSelected: !isCardMode
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSource = .flight
                        selectedCard = nil
                        selectedSubcategoryID = nil
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    private func topCategoryButton(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(AviationTheme.Typography.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? AviationTheme.Colors.cathayJade
                    : AviationTheme.Colors.cardBackground(colorScheme)
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : AviationTheme.Colors.primaryText(colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(isSelected ? 0.4 : 0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - 信用卡選擇
    private var cardSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("選擇信用卡")
            
            VStack(spacing: 0) {
                ForEach(Array(activeCards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let previousBrand = selectedCard?.cardBrand
                            selectedCard = card
                            // 切卡時：若品牌改變，重設來源為 .cardGeneral
                            if card.cardBrand != previousBrand {
                                selectedSource = .cardGeneral
                                selectedSubcategoryID = nil
                            }
                        }
                    } label: {
                        CompactCardRow(
                            card: card,
                            isSelected: selectedCard?.id == card.id,
                            colorScheme: colorScheme
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if index < activeCards.count - 1 {
                        Divider()
                            .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                            .padding(.leading, 60)
                    }
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 信用卡消費來源選擇（帶費率顯示）
    private var cardSourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("消費類型")
            
            VStack(spacing: 0) {
                ForEach(Array(cardSourceMappings.enumerated()), id: \.element.source) { index, mapping in
                    let isSelected = selectedSource == mapping.source
                    let rate = rateForMapping(mapping)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSource = mapping.source
                            selectedSubcategoryID = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mapping.source.icon)
                                .font(.title3)
                                .foregroundColor(
                                    isSelected
                                        ? AviationTheme.Colors.cathayJade
                                        : AviationTheme.Colors.secondaryText(colorScheme)
                                )
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mapping.source.rawValue)
                                    .font(AviationTheme.Typography.body)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                
                                if let rate {
                                    Text("\(rate.formatted()) 元 / 哩")
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.cathayJade)
                                }
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(AviationTheme.Colors.cathayJade)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .background(
                            isSelected
                                ? AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.1 : 0.03)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if index < cardSourceMappings.count - 1 {
                        Divider()
                            .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    /// 取得指定 mapping 的費率
    private func rateForMapping(_ mapping: CardMileageSourceMapping) -> Decimal? {
        guard let card = selectedCard else { return nil }
        switch mapping.rateKeyPath {
        case .base: return card.baseRate
        case .secondary: return card.acceleratorRate
        case .tertiary: return card.specialMerchantRate
        }
    }
    
    // MARK: - 非信用卡來源選擇
    private var nonCardSourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("哩程來源")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AviationTheme.Spacing.sm) {
                    Spacer().frame(width: 12)
                    
                    ForEach(nonCardSources, id: \.self) { source in
                        SourceButton(
                            source: source,
                            isSelected: selectedSource == source,
                            colorScheme: colorScheme
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSource = source
                            }
                        }
                    }
                    
                    Spacer().frame(width: 12)
                }
            }
        }
    }
    
    // MARK: - 通用子類別選擇
    private func subcategorySection(mapping: CardMileageSourceMapping) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader(mapping.subcategorySectionTitle)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(mapping.subcategories) { category in
                    CompactSubcategoryButton(
                        category: category,
                        isSelected: selectedSubcategoryID == category.id,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSubcategoryID = category.id
                        }
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 交易金額與哩程輸入
    private var transactionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("交易明細")
            
            VStack(spacing: 0) {
                if needsAmountInput {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.starluxGold)
                            .frame(width: 28)
                        Text("消費金額")
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        
                        Spacer()
                        
                        Text("NT$")
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(AviationTheme.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amount) { _, newValue in
                                amount = sanitizeDecimalInput(newValue)
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .amount }
                    
                    if let info = calculatedMilesDisplay {
                        Divider().padding(.leading, 60)
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                                .frame(width: 28)
                            Text("可獲得哩程")
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            
                            Spacer()
                            
                            if info.isBirthdayMonth {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.pink)
                                    .font(.caption)
                            }
                            Text("\(info.miles)")
                                .font(AviationTheme.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                            Text("哩")
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.15 : 0.05))
                    }
                } else {
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .frame(width: 28)
                        Text("獲得哩程")
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        
                        Spacer()
                        
                        TextField("0", text: $earnedMiles)
                            .keyboardType(.numberPad)
                            .font(AviationTheme.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .focused($focusedField, equals: .miles)
                            .onChange(of: earnedMiles) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue { earnedMiles = filtered }
                            }
                        Text("哩")
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .miles }
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 額外資訊
    private var extraInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader(
                selectedSource == .flight ? "航線資訊" :
                selectedSource == .specialMerchant ? "商家資訊" :
                selectedSource == .promotion ? "活動資訊" :
                "來源資訊"
            )
            
            VStack(spacing: 0) {
                if selectedSource == .flight {
                    HStack {
                        Image(systemName: "airplane.departure")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .frame(width: 28)
                        
                        TextField("航線（例如：TPE-NRT）", text: $flightRoute)
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .autocapitalization(.allCharacters)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                }
                
                if selectedSource == .pointsConversion || selectedSource == .pointsTransfer {
                    HStack {
                        Image(systemName: selectedSource == .pointsConversion ? "building.columns.fill" : "arrow.down.app.fill")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .frame(width: 28)
                        
                        TextField(
                            selectedSource == .pointsConversion ? "點數來源（例如：國泰世華銀行）" : "轉入來源（例如：Happy Go）",
                            text: $conversionSource
                        )
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                }
                
                if selectedSource == .specialMerchant {
                    HStack {
                        Image(systemName: "storefront.fill")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .frame(width: 28)
                        
                        TextField("商家名稱（例如：Lalaport）", text: $merchantName)
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                }
                
                if selectedSource == .promotion {
                    HStack {
                        Image(systemName: "gift.fill")
                            .font(.title3)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                            .frame(width: 28)
                        
                        TextField("活動名稱（例如：里賞季）", text: $promotionName)
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 日期與備註
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formSectionHeader("其他資訊")
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.silver)
                        .frame(width: 28)
                    Text("日期")
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AviationTheme.Colors.cathayJade)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                    .background(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                    .padding(.leading, 60)
                
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.silver)
                        .frame(width: 28)
                        .padding(.top, 8)
                    
                    TextField("加入備註（選填）", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 計算邏輯
    
    var calculatedMilesDisplay: CalculatedMilesInfo? {
        guard canCalculateMiles, let card = selectedCard else { return nil }
        
        let isBirthdayMonth = Calendar.current.isDate(date, equalTo: viewModel.userBirthday, toGranularity: .month)
        let miles = card.calculateMiles(
            amount: Decimal(string: amount) ?? 0,
            source: selectedSource,
            subcategoryID: selectedSubcategoryID,
            isBirthdayMonth: isBirthdayMonth
        )
        
        return CalculatedMilesInfo(miles: miles, isBirthdayMonth: isBirthdayMonth)
    }
    
    var canSave: Bool {
        if needsAmountInput {
            guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
            guard selectedCard != nil else { return false }
            if let mapping = subcategoryMapping, mapping.requiresSubcategory && selectedSubcategoryID == nil { return false }
            return true
        } else {
            guard let milesValue = Int(earnedMiles), milesValue > 0 else { return false }
            return true
        }
    }
    
    func sanitizeDecimalInput(_ value: String) -> String {
        var result = ""
        var hasDecimal = false
        for char in value {
            if char.isNumber {
                result.append(char)
            } else if char == "." && !hasDecimal {
                hasDecimal = true
                result.append(char)
            }
        }
        return result
    }
}
