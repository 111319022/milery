import SwiftUI
import SwiftData

struct CalculatorLedgerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MileageViewModel
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor: return false
        }
    }
    
    @State private var selectedSource: MileageSource = .cardGeneral
    @State private var selectedCard: CreditCardRule?
    @State private var selectedSubcategoryID: String?
    @State private var amount: String = ""
    @State private var earnedMiles: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var flightRoute: String = ""
    @State private var conversionSource: String = ""
    @State private var merchantName: String = ""
    @State private var promotionName: String = ""
    @FocusState private var focusedField: TransactionFormView.TransactionField?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView {
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
                    .padding(.vertical, AviationTheme.Spacing.lg)
                }
            }
            .onTapGesture { focusedField = nil }
            .navigationTitle("新增記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AviationTheme.Colors.silver)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { saveNewTransaction() }
                        .disabled(!formCanSave)
                        .foregroundColor(formCanSave ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.silver.opacity(0.3))
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                let activeCards = viewModel.creditCards.filter { $0.isActive }
                if activeCards.count == 1 {
                    selectedCard = activeCards.first
                }
            }
        }
    }
    
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
    
    private func saveNewTransaction() {
        let miles: Int
        let finalAmount: Decimal
        let needsAmount = CardBrandRegistry.sourceNeedsAmount(selectedSource)
        
        if needsAmount {
            guard let amountValue = Decimal(string: amount), let card = selectedCard else { return }
            finalAmount = amountValue
            
            miles = card.calculateMiles(
                amount: amountValue,
                source: selectedSource,
                subcategoryID: selectedSubcategoryID,
                isBirthdayMonth: viewModel.isBirthdayMonth(for: date)
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
            subcategoryID: selectedSubcategoryID,
            cardBrand: selectedCard?.cardBrand,
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

#Preview {
    CalculatorLedgerView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
