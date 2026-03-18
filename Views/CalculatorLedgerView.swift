//
//  CalculatorLedgerView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct CalculatorLedgerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MileageViewModel
    
    @State private var selectedSource: MileageSource = .cardGeneral
    @State private var selectedCard: CreditCardRule?
    @State private var selectedAccelerator: AcceleratorCategory?
    @State private var amount: String = ""
    @State private var earnedMiles: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var flightRoute: String = "" // 飛行累積：航線
    @State private var conversionSource: String = "" // 銀行點數兌換/他點轉入：來源
    @State private var merchantName: String = "" // 特店消費累積：商家名稱
    @State private var promotionName: String = "" // 活動贈送：活動名稱
    @FocusState private var isAnyFieldFocused: Bool
    
    var activeCards: [CreditCardRule] {
        viewModel.creditCards.filter { $0.isActive }
    }
    
    // 如果只有一張卡，自動選擇
    var defaultCard: CreditCardRule? {
        activeCards.count == 1 ? activeCards.first : nil
    }
    
    var needsCardSelection: Bool {
        selectedSource == .cardGeneral || selectedSource == .cardAccelerator
    }
    
    var needsAccelerator: Bool {
        selectedSource == .cardAccelerator
    }
    
    // 是否需要輸入金額(可自動換算哩程)
    var needsAmountInput: Bool {
        selectedSource == .cardGeneral || selectedSource == .cardAccelerator
    }
    
    // 是否可以自動計算哩程
    var canCalculateMiles: Bool {
        needsCardSelection && selectedCard != nil && !amount.isEmpty
    }
    
    // 自訂的來源顯示順序（將飛行累積移到活動贈送前面）
    var displaySources: [MileageSource] {
        [
            .cardGeneral,
            .cardAccelerator,
            .specialMerchant,
            .flight,
            .promotion,
            .pointsConversion,
            .pointsTransfer
        ]
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("新增記帳")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(
                    AviationTheme.Colors.background(colorScheme),
                    for: .navigationBar
                )
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    // 如果只有一張卡，自動選擇
                    if let defaultCard = defaultCard, selectedCard == nil {
                        selectedCard = defaultCard
                    }
                }
        }
    }
    
    private var contentView: some View {
        ZStack {
            // 航空風格背景
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    
                    // 1. 來源選擇器
                    sourceSelector
                    
                    // 2. 信用卡與加速器選擇（動態顯示）
                    if needsCardSelection && !activeCards.isEmpty {
                        cardSelectionSection
                    }
                    if needsAccelerator {
                        acceleratorSection
                    }
                    
                    // 3. 交易資訊（金額 / 哩程）
                    transactionInputSection
                    
                    // 4. 額外資訊（航線 / 來源 / 商家 / 活動）
                    if selectedSource == .flight || selectedSource == .pointsConversion || selectedSource == .pointsTransfer || selectedSource == .specialMerchant || selectedSource == .promotion {
                        extraInfoSection
                    }
                    
                    // 5. 其他資訊（日期 / 備註）
                    additionalInfoSection
                }
                .padding(.vertical, AviationTheme.Spacing.lg)
            }
        }
        .onTapGesture {
            isAnyFieldFocused = false
        }
    }
    
    // MARK: - 區塊 1: 來源選擇器
    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("哩程來源")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AviationTheme.Spacing.sm) {
                    Spacer().frame(width: 12) // 左側安全距離
                    
                    ForEach(displaySources, id: \.self) { source in
                        SourceButton(
                            source: source,
                            isSelected: selectedSource == source,
                            colorScheme: colorScheme
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSource = source
                                if !needsCardSelection {
                                    selectedCard = nil
                                } else if let defaultCard = defaultCard, selectedCard == nil {
                                    selectedCard = defaultCard // 切換回來時自動補上單張卡
                                }
                                if !needsAccelerator {
                                    selectedAccelerator = nil
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(width: 12) // 右側安全距離
                }
            }
        }
    }
    
    // MARK: - 區塊 2: 信用卡選擇
    private var cardSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選擇信用卡")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            VStack(spacing: 0) {
                ForEach(Array(activeCards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCard = card
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
    
    // MARK: - 區塊 3: 加速器選擇
    private var acceleratorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("加速器類別")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AcceleratorCategory.allCases, id: \.self) { category in
                    CompactAcceleratorButton(
                        category: category,
                        isSelected: selectedAccelerator == category,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedAccelerator = category
                        }
                    }
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 區塊 4: 交易金額與哩程輸入
    private var transactionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交易明細")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            VStack(spacing: 0) {
                if needsAmountInput {
                    // 輸入金額
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
                            .focused($isAnyFieldFocused)
                            .onChange(of: amount) { _, newValue in
                                amount = sanitizeDecimalInput(newValue)
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    
                    // 自動計算的哩程結果
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
                    // 其他來源直接輸入哩程
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
                            .focused($isAnyFieldFocused)
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
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 8, x: 0, y: 2)
            .padding(.horizontal, AviationTheme.Spacing.md)
        }
    }
    
    // MARK: - 區塊 4: 額外資訊（航線 / 來源）
    private var extraInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                selectedSource == .flight ? "航線資訊" :
                selectedSource == .specialMerchant ? "商家資訊" :
                selectedSource == .promotion ? "活動資訊" :
                "來源資訊"
            )
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            VStack(spacing: 0) {
                // 飛行累積：航線輸入
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
                
                // 銀行點數兌換/他點轉入：來源輸入
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
                
                // 特店消費累積：商家名稱輸入
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
                
                // 活動贈送：活動名稱輸入
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
    
    // MARK: - 區塊 5: 日期與備註
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("其他資訊")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            VStack(spacing: 0) {
                // 日期選擇
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
                
                // 備註
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
    
    // MARK: - 工具列與邏輯
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("取消") {
                dismiss()
            }
            .foregroundColor(AviationTheme.Colors.silver)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("儲存") {
                saveTransaction()
            }
            .disabled(!canSave)
            .foregroundColor(canSave ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.silver.opacity(0.3))
            .fontWeight(.bold)
        }
    }
    
    private var calculatedMilesDisplay: CalculatedMilesInfo? {
        guard canCalculateMiles, let card = selectedCard else { return nil }
        
        let isBirthdayMonth = Calendar.current.isDate(date, equalTo: viewModel.userBirthday, toGranularity: .month)
        let miles = card.calculateMiles(
            amount: Decimal(string: amount) ?? 0,
            source: selectedSource,
            acceleratorCategory: selectedAccelerator,
            isBirthdayMonth: isBirthdayMonth
        )
        
        return CalculatedMilesInfo(miles: miles, isBirthdayMonth: isBirthdayMonth)
    }
    
    private var canSave: Bool {
        if needsAmountInput {
            guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
            guard selectedCard != nil else { return false }
            if needsAccelerator && selectedAccelerator == nil { return false }
            return true
        } else {
            guard let milesValue = Int(earnedMiles), milesValue > 0 else { return false }
            return true
        }
    }
    
    private func saveTransaction() {
        let miles: Int
        let finalAmount: Decimal
        
        if needsAmountInput {
            guard let amountValue = Decimal(string: amount), let card = selectedCard else { return }
            finalAmount = amountValue
            
            let isBirthdayMonth = Calendar.current.isDate(date, equalTo: viewModel.userBirthday, toGranularity: .month)
            miles = card.calculateMiles(
                amount: amountValue,
                source: selectedSource,
                acceleratorCategory: selectedAccelerator,
                isBirthdayMonth: isBirthdayMonth
            )
        } else {
            guard let milesValue = Int(earnedMiles) else { return }
            miles = milesValue
            finalAmount = 0
        }
        
        viewModel.addTransaction(
            amount: finalAmount,
            earnedMiles: miles,
            source: selectedSource,
            acceleratorCategory: selectedAccelerator,
            date: date,
            notes: notes,
            flightRoute: selectedSource == .flight && !flightRoute.isEmpty ? flightRoute : nil,
            conversionSource: (selectedSource == .pointsConversion || selectedSource == .pointsTransfer) && !conversionSource.isEmpty ? conversionSource : nil,
            merchantName: selectedSource == .specialMerchant && !merchantName.isEmpty ? merchantName : nil,
            promotionName: selectedSource == .promotion && !promotionName.isEmpty ? promotionName : nil
        )
        
        dismiss()
    }
    
    /// 過濾金額輸入，只允許數字和一個小數點
    private func sanitizeDecimalInput(_ value: String) -> String {
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

#Preview {
    CalculatorLedgerView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
