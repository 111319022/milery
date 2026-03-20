//
//  EditTransactionView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/20.
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MileageViewModel
    let transaction: Transaction
    
    @State private var selectedSource: MileageSource
    @State private var selectedCard: CreditCardRule?
    @State private var selectedAccelerator: AcceleratorCategory?
    @State private var amount: String
    @State private var earnedMiles: String
    @State private var date: Date
    @State private var notes: String
    @State private var flightRoute: String
    @State private var conversionSource: String
    @State private var merchantName: String
    @State private var promotionName: String
    @State private var showDeleteAlert = false
    @FocusState private var focusedField: TransactionField?
    
    enum TransactionField {
        case amount, miles
    }
    
    init(transaction: Transaction, viewModel: MileageViewModel) {
        self.transaction = transaction
        self.viewModel = viewModel
        _selectedSource = State(initialValue: transaction.source)
        _selectedAccelerator = State(initialValue: transaction.acceleratorCategory)
        _amount = State(initialValue: transaction.amount > 0 ? "\((transaction.amount as NSDecimalNumber).stringValue)" : "")
        _earnedMiles = State(initialValue: transaction.earnedMiles > 0 ? "\(transaction.earnedMiles)" : "")
        _date = State(initialValue: transaction.date)
        _notes = State(initialValue: transaction.notes)
        _flightRoute = State(initialValue: transaction.flightRoute ?? "")
        _conversionSource = State(initialValue: transaction.conversionSource ?? "")
        _merchantName = State(initialValue: transaction.merchantName ?? "")
        _promotionName = State(initialValue: transaction.promotionName ?? "")
    }
    
    var activeCards: [CreditCardRule] {
        viewModel.creditCards.filter { $0.isActive }
    }
    
    var needsCardSelection: Bool {
        selectedSource == .cardGeneral || selectedSource == .cardAccelerator
    }
    
    var needsAccelerator: Bool {
        selectedSource == .cardAccelerator
    }
    
    var needsAmountInput: Bool {
        selectedSource == .cardGeneral || selectedSource == .cardAccelerator
    }
    
    var canCalculateMiles: Bool {
        needsCardSelection && selectedCard != nil && !amount.isEmpty
    }
    
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
                .navigationTitle("編輯記帳")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    // 嘗試匹配已選擇的信用卡（根據交易的來源和金額推斷）
                    if needsCardSelection && selectedCard == nil {
                        if activeCards.count == 1 {
                            selectedCard = activeCards.first
                        }
                    }
                }
                .alert("確定要刪除這筆交易？", isPresented: $showDeleteAlert) {
                    Button("取消", role: .cancel) { }
                    Button("刪除", role: .destructive) {
                        viewModel.deleteTransaction(transaction)
                        dismiss()
                    }
                } message: {
                    Text("刪除後將無法復原，該筆哩程也會從帳戶中扣除。")
                }
        }
    }
    
    private var contentView: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    
                    // 1. 來源選擇器
                    sourceSelector
                    
                    // 2. 信用卡與加速器選擇
                    if needsCardSelection && !activeCards.isEmpty {
                        cardSelectionSection
                    }
                    if needsAccelerator {
                        acceleratorSection
                    }
                    
                    // 3. 交易資訊
                    transactionInputSection
                    
                    // 4. 額外資訊
                    if selectedSource == .flight || selectedSource == .pointsConversion || selectedSource == .pointsTransfer || selectedSource == .specialMerchant || selectedSource == .promotion {
                        extraInfoSection
                    }
                    
                    // 5. 其他資訊
                    additionalInfoSection
                    
                    // 6. 刪除按鈕
                    deleteSection
                }
                .padding(.vertical, AviationTheme.Spacing.lg)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - 來源選擇器
    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("哩程來源")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AviationTheme.Spacing.sm) {
                    Spacer().frame(width: 12)
                    
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
                                } else if let defaultCard = activeCards.count == 1 ? activeCards.first : nil, selectedCard == nil {
                                    selectedCard = defaultCard
                                }
                                if !needsAccelerator {
                                    selectedAccelerator = nil
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(width: 12)
                }
            }
        }
    }
    
    // MARK: - 信用卡選擇
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
    
    // MARK: - 加速器選擇
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
    
    // MARK: - 交易金額與哩程
    private var transactionInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交易明細")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
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
            Text("其他資訊")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, 28)
            
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
    
    // MARK: - 刪除按鈕
    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("刪除這筆交易")
            }
            .font(AviationTheme.Typography.body)
            .fontWeight(.semibold)
            .foregroundColor(AviationTheme.Colors.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AviationTheme.Colors.danger.opacity(colorScheme == .dark ? 0.15 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        }
        .padding(.horizontal, AviationTheme.Spacing.md)
        .padding(.bottom, AviationTheme.Spacing.lg)
    }
    
    // MARK: - 工具列
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
    
    // MARK: - 計算邏輯
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
        
        viewModel.updateTransaction(
            transaction,
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
