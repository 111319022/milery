import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MileageViewModel
    let transaction: Transaction
    
    @State private var selectedSource: MileageSource
    @State private var selectedCard: CreditCardRule?
    @State private var selectedSubcategoryID: String?
    @State private var amount: String
    @State private var earnedMiles: String
    @State private var date: Date
    @State private var notes: String
    @State private var flightRoute: String
    @State private var conversionSource: String
    @State private var merchantName: String
    @State private var promotionName: String
    @State private var showDeleteAlert = false
    @FocusState private var focusedField: TransactionFormView.TransactionField?
    
    init(transaction: Transaction, viewModel: MileageViewModel) {
        self.transaction = transaction
        self.viewModel = viewModel
        _selectedSource = State(initialValue: transaction.source)
        _selectedSubcategoryID = State(initialValue: transaction.resolvedSubcategoryID)
        _amount = State(initialValue: transaction.amount > 0 ? "\((transaction.amount as NSDecimalNumber).stringValue)" : "")
        _earnedMiles = State(initialValue: transaction.earnedMiles > 0 ? "\(transaction.earnedMiles)" : "")
        _date = State(initialValue: transaction.date)
        _notes = State(initialValue: transaction.notes)
        _flightRoute = State(initialValue: transaction.flightRoute ?? "")
        _conversionSource = State(initialValue: transaction.conversionSource ?? "")
        _merchantName = State(initialValue: transaction.merchantName ?? "")
        _promotionName = State(initialValue: transaction.promotionName ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.xl) {
                        TransactionFormView(
                            viewModel: viewModel,
                            selectedSource: $selectedSource,
                            selectedCard: $selectedCard,
                            selectedSubcategoryID: $selectedSubcategoryID,
                            amount: $amount,
                            earnedMiles: $earnedMiles,
                            date: $date,
                            notes: $notes,
                            flightRoute: $flightRoute,
                            conversionSource: $conversionSource,
                            merchantName: $merchantName,
                            promotionName: $promotionName,
                            focusedField: $focusedField
                        )
                        
                        // 刪除按鈕
                        deleteSection
                    }
                    .padding(.vertical, AviationTheme.Spacing.lg)
                }
            }
            .onTapGesture { focusedField = nil }
            .navigationTitle("編輯記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AviationTheme.Colors.silver)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { saveTransaction() }
                        .disabled(!formCanSave)
                        .foregroundColor(formCanSave ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.silver.opacity(0.3))
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                // 嘗試匹配已選擇的信用卡
                let activeCards = viewModel.creditCards.filter { $0.isActive }
                if CardBrandRegistry.sourceNeedsCard(selectedSource) && selectedCard == nil {
                    // 先依據來源對應品牌選卡
                    if let brandDef = CardBrandRegistry.brandForSource(selectedSource) {
                        selectedCard = activeCards.first { $0.cardBrand == brandDef.brandID }
                    }
                    // fallback: 若只有一張卡直接選
                    if selectedCard == nil && activeCards.count == 1 {
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
    
    // MARK: - 邏輯
    
    private var formCanSave: Bool {
        let needsAmount = CardBrandRegistry.sourceNeedsAmount(selectedSource)
        if needsAmount {
            guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
            guard selectedCard != nil else { return false }
            if let mapping = CardBrandRegistry.subcategoryMapping(for: selectedSource),
               mapping.requiresSubcategory && selectedSubcategoryID == nil { return false }
            return true
        } else {
            guard let milesValue = Int(earnedMiles), milesValue > 0 else { return false }
            return true
        }
    }
    
    private func saveTransaction() {
        let miles: Int
        let finalAmount: Decimal
        let needsAmount = CardBrandRegistry.sourceNeedsAmount(selectedSource)
        
        if needsAmount {
            guard let amountValue = Decimal(string: amount), let card = selectedCard else { return }
            finalAmount = amountValue
            
            let isBirthdayMonth = Calendar.current.isDate(date, equalTo: viewModel.userBirthday, toGranularity: .month)
            miles = card.calculateMiles(
                amount: amountValue,
                source: selectedSource,
                subcategoryID: selectedSubcategoryID,
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
            subcategoryID: selectedSubcategoryID,
            date: date,
            notes: notes,
            flightRoute: selectedSource == .flight && !flightRoute.isEmpty ? flightRoute : nil,
            conversionSource: (selectedSource == .pointsConversion || selectedSource == .pointsTransfer) && !conversionSource.isEmpty ? conversionSource : nil,
            merchantName: selectedSource == .specialMerchant && !merchantName.isEmpty ? merchantName : nil,
            promotionName: selectedSource == .promotion && !promotionName.isEmpty ? promotionName : nil
        )
        
        dismiss()
    }
}
