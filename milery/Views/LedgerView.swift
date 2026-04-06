import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @State private var showingAddTransaction = false
    @State private var selectedMonth = Date()
    @State private var editingTransaction: Transaction?
    @State private var isStatsExpanded = false
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor: return false
        }
    }
    
    var filteredTransactions: [Transaction] {
        viewModel.transactions.filter { transaction in
            Calendar.current.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    /// 預先排序的交易列表（避免在 ForEach 內重複排序）
    var sortedTransactions: [Transaction] {
        filteredTransactions.sorted { $0.date > $1.date }
    }
    
    // 按類別統計（子類別再細分）
    var categoryStats: [(source: MileageSource, subcategoryID: String?, amount: Decimal, miles: Int)] {
        struct GroupKey: Hashable {
            let source: MileageSource
            let subcategoryID: String?
        }
        let grouped = Dictionary(grouping: filteredTransactions) {
            GroupKey(source: $0.source,
                     subcategoryID: $0.resolvedSubcategoryID)
        }
        return grouped.map { key, transactions in
            let amount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
            let miles = transactions.reduce(0) { $0 + $1.earnedMiles }
            return (key.source, key.subcategoryID, amount, miles)
        }.sorted {
            // 負值（如機票兌換）永遠排在前面
            if ($0.miles < 0) != ($1.miles < 0) {
                return $0.miles < 0
            }
            return abs($0.miles) > abs($1.miles)
        }
    }
    
    var monthlyTotal: (amount: Decimal, miles: Int) {
        let amount = filteredTransactions.reduce(Decimal(0)) { $0 + $1.amount }
        let miles = filteredTransactions.reduce(0) { $0 + $1.earnedMiles }
        return (amount, miles)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    // 月份選擇器與統計 - 固定在頂部，不隨內容滾動
                    VStack(spacing: 0) {
                    // 月份選擇器
                    MonthPicker(selectedMonth: $selectedMonth)
                        .padding(AviationTheme.Spacing.md)
                    
                    // 本月統計卡片 - 總哩程和類別統計
                    VStack(spacing: 0) {
                        if categoryStats.isEmpty {
                            // 沒有類別統計時,總哩程居中顯示
                            VStack(spacing: AviationTheme.Spacing.xs) {
                                HStack(spacing: 6) {
                                    Image(systemName: "airplane.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                                    Text("本月總哩程")
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("\(monthlyTotal.miles.formatted())")
                                        .font(AviationTheme.Typography.title2)
                                        .fontWeight(.bold)
                                    Text("哩")
                                        .font(AviationTheme.Typography.subheadline)
                                }
                                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(AviationTheme.Spacing.md)
                        } else {
                            // 有類別統計時,並排顯示
                            HStack(alignment: .top, spacing: AviationTheme.Spacing.lg) {
                                // 左側：總哩程顯示
                                VStack(alignment: .leading, spacing: AviationTheme.Spacing.xs) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "airplane.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                                        Text("本月總哩程")
                                            .font(AviationTheme.Typography.caption)
                                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                    }
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("\(monthlyTotal.miles.formatted())")
                                            .font(AviationTheme.Typography.title2)
                                            .fontWeight(.bold)
                                        Text("哩")
                                            .font(AviationTheme.Typography.subheadline)
                                    }
                                    .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                                }
                                
                                // 右側：類別統計細項（可折疊）
                                VStack(alignment: .leading, spacing: AviationTheme.Spacing.xs) {
                                    let maxVisible = 3
                                    let statsToShow = isStatsExpanded ? categoryStats : Array(categoryStats.prefix(maxVisible))
                                    
                                    ForEach(Array(statsToShow.enumerated()), id: \.offset) { _, stat in
                                        CompactCategoryStatRow(
                                            source: stat.source,
                                            subcategoryID: stat.subcategoryID,
                                            amount: stat.amount,
                                            miles: stat.miles,
                                            colorScheme: colorScheme
                                        )
                                    }
                                    
                                    if categoryStats.count > maxVisible {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                isStatsExpanded.toggle()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(isStatsExpanded ? "收合" : "展開全部（\(categoryStats.count)）")
                                                    .font(.system(size: 11, weight: .medium))
                                                Image(systemName: isStatsExpanded ? "chevron.up" : "chevron.down")
                                                    .font(.system(size: 9, weight: .semibold))
                                            }
                                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 8)
                                            .contentShape(Rectangle())
                                        }
                                    }
                                }
                            }
                            .padding(AviationTheme.Spacing.md)
                        }
                    }
                    .glassmorphism()
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.bottom, AviationTheme.Spacing.sm)
                    }
                    
                    // 交易列表
                    if filteredTransactions.isEmpty {
                            VStack(spacing: AviationTheme.Spacing.lg) {
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .fill(
                                            colorScheme == .dark
                                                ? Color.white.opacity(0.08)
                                                : AviationTheme.Colors.lightBeige
                                        )
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 50))
                                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                }
                                
                                VStack(spacing: AviationTheme.Spacing.sm) {
                                    Text("本月尚無交易記錄")
                                        .font(AviationTheme.Typography.headline)
                                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                    
                                    Text("點擊下方按鈕開始記帳")
                                        .font(AviationTheme.Typography.subheadline)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                                .padding(.horizontal, hasBackgroundImage ? 16 : 0)
                                .padding(.vertical, hasBackgroundImage ? 10 : 0)
                                .background {
                                    if hasBackgroundImage {
                                        RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                                
                                Button {
                                    showingAddTransaction = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.subheadline)
                                        Text("新增交易")
                                            .font(AviationTheme.Typography.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AviationTheme.Gradients.cathayJadeGradient(colorScheme))
                                    .foregroundColor(.white)
                                    .cornerRadius(AviationTheme.CornerRadius.md)
                                    .shadow(color: AviationTheme.Colors.brandColor(colorScheme).opacity(0.3), radius: 8)
                                }
                                
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(Array(sortedTransactions.enumerated()), id: \.element.id) { index, transaction in
                                    let showDate = index == 0 || !Calendar.current.isDate(
                                        transaction.date,
                                        inSameDayAs: sortedTransactions[index - 1].date
                                    )
                                    
                                    // 日期卡片（獨立顯示，不支援滑動刪除）
                                    if showDate {
                                        DateHeaderCard(date: transaction.date)
                                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                    }
                                    
                                    // 交易卡片
                                    TransactionDetailRow(transaction: transaction, showDate: false)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingTransaction = transaction
                                        }
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    viewModel.deleteTransaction(transaction)
                                                }
                                            } label: {
                                                Label("刪除", systemImage: "trash.fill")
                                            }
                                            .tint(AviationTheme.Colors.danger)
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .mask(
                                VStack(spacing: 0) {
                                    LinearGradient(
                                        colors: [.clear, .black],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 12)
                                    
                                    Color.black
                                }
                            )
                        }
                }
            }
            .navigationTitle("哩程記帳本")
            .navigationBarTitleDisplayMode(.large) // 使用 large 模式，滾動時會自動縮小
            .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    }
                }
            }
            .onChange(of: selectedMonth) {
                isStatsExpanded = false
            }
            .sheet(isPresented: $showingAddTransaction) {
                CalculatorLedgerView(viewModel: viewModel)
            }
            .sheet(item: $editingTransaction) { transaction in
                EditTransactionView(transaction: transaction, viewModel: viewModel)
            }
        }
    }
    
}

// MARK: - 精簡版類別統計列（用於統計卡片右側）
struct CompactCategoryStatRow: View {
    let source: MileageSource
    var subcategoryID: String? = nil
    let amount: Decimal
    let miles: Int
    let colorScheme: ColorScheme
    
    var hasAmount: Bool {
        amount > 0
    }
    
    /// 顯示名稱：帶子類別
    var displayName: String {
        if let subID = subcategoryID {
            return "\(source.rawValue)・\(subID)"
        }
        return source.rawValue
    }

    /// 圖標：有子類別時用子類別 icon
    var displayIcon: String {
        if let subID = subcategoryID,
           let cat = CardBrandRegistry.spendingCategory(for: subID) {
            return cat.icon
        }
        return source.icon
    }

    var milesColor: Color {
        source == .ticketRedemption
            ? AviationTheme.Colors.danger
            : AviationTheme.Colors.brandColor(colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 圖標
            Image(systemName: displayIcon)
                .font(.caption2)
                .foregroundColor(milesColor)
                .frame(width: 16)
            
            // 類別名稱
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    .lineLimit(1)
                
                // 只在有金額時顯示
                if hasAmount {
                    Text("NT$ \((amount as NSDecimalNumber).intValue.formatted())")
                        .font(.system(size: 10))
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
            }
            
            Spacer()
            
            // 哩程
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(miles.formatted())")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                Text("哩")
                    .font(AviationTheme.Typography.caption)
            }
            .foregroundColor(milesColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 類別統計列
struct CategoryStatRow: View {
    let source: MileageSource
    let amount: Decimal
    let miles: Int
    let colorScheme: ColorScheme
    
    var hasAmount: Bool {
        amount > 0
    }
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.sm) {
            // 圖標
            ZStack {
                Circle()
                    .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: source.icon)
                    .font(.caption)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
            
            // 類別名稱
            VStack(alignment: .leading, spacing: 2) {
                Text(source.rawValue)
                    .font(AviationTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                // 只在有金額時顯示
                if hasAmount {
                    Text("NT$ \((amount as NSDecimalNumber).intValue.formatted())")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            
            Spacer()
            
            // 哩程
            HStack(spacing: 3) {
                Text("\(miles.formatted())")
                    .font(AviationTheme.Typography.title3)
                    .fontWeight(.bold)
                Text("哩")
                    .font(AviationTheme.Typography.subheadline)
            }
            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
        }
        .padding(.vertical, AviationTheme.Spacing.sm)
    }
}

// MARK: - 月份選擇器（航空風格）
struct MonthPicker: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedMonth: Date
    @State private var showingMonthSelector = false
    
    private var formattedMonth: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedMonth)
        let month = calendar.component(.month, from: selectedMonth)
        return String(format: "%d/%02d", year, month)
    }
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                ZStack {
                    Circle()
                        .fill(AviationTheme.Gradients.cathayJadeGradient(colorScheme))
                        .frame(width: 36, height: 36)
                        .shadow(color: AviationTheme.Colors.brandColor(colorScheme).opacity(0.3), radius: 5)
                    
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            Button {
                showingMonthSelector = true
            } label: {
                HStack(spacing: 6) {
                    Text(formattedMonth)
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            
            Spacer()
            
            Button {
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                if nextMonth <= Date() {
                    selectedMonth = nextMonth
                }
            } label: {
                ZStack {
                    if canGoNext {
                        Circle()
                            .fill(AviationTheme.Gradients.cathayJadeGradient(colorScheme))
                            .frame(width: 36, height: 36)
                            .shadow(color: AviationTheme.Colors.brandColor(colorScheme).opacity(0.3), radius: 5)
                    } else {
                        Circle()
                            .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                            .frame(width: 36, height: 36)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(
                            canGoNext
                                ? .white
                                : AviationTheme.Colors.tertiaryText(colorScheme)
                        )
                }
            }
            .disabled(!canGoNext)
        }
        .sheet(isPresented: $showingMonthSelector) {
            MonthSelectorSheet(selectedMonth: $selectedMonth)
                .presentationDetents([.medium])
        }
    }
    
    var canGoNext: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? Date()
        return nextMonth <= Date()
    }
}

// MARK: - 快速月份選擇面板
struct MonthSelectorSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMonth: Date
    
    @State private var displayYear: Int
    
    private let calendar = Calendar.current
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    init(selectedMonth: Binding<Date>) {
        self._selectedMonth = selectedMonth
        self._displayYear = State(initialValue: Calendar.current.component(.year, from: selectedMonth.wrappedValue))
    }
    
    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }
    
    private var currentMonth: Int {
        calendar.component(.month, from: Date())
    }
    
    private var selectedYear: Int {
        calendar.component(.year, from: selectedMonth)
    }
    
    private var selectedMonthValue: Int {
        calendar.component(.month, from: selectedMonth)
    }
    
    private func isFutureMonth(_ month: Int) -> Bool {
        if displayYear > currentYear { return true }
        if displayYear == currentYear && month > currentMonth { return true }
        return false
    }
    
    private func isSelected(_ month: Int) -> Bool {
        displayYear == selectedYear && month == selectedMonthValue
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AviationTheme.Spacing.lg) {
                // 年份選擇
                HStack {
                    Button {
                        displayYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    }
                    
                    Spacer()
                    
                    Text(String(displayYear))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Spacer()
                    
                    Button {
                        if displayYear < currentYear {
                            displayYear += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(displayYear < currentYear ? AviationTheme.Colors.brandColor(colorScheme) : AviationTheme.Colors.tertiaryText(colorScheme))
                    }
                    .disabled(displayYear >= currentYear)
                }
                .padding(.horizontal, AviationTheme.Spacing.lg)
                
                // 月份 Grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...12, id: \.self) { month in
                        let future = isFutureMonth(month)
                        let selected = isSelected(month)
                        
                        Button {
                            if let date = calendar.date(from: DateComponents(year: displayYear, month: month, day: 1)) {
                                selectedMonth = date
                                dismiss()
                            }
                        } label: {
                            Text(String(format: "%02d", month))
                                .font(.system(size: 18, weight: selected ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                        .fill(
                                            selected
                                            ? AviationTheme.Colors.brandColor(colorScheme)
                                                : AviationTheme.Colors.cardBackground(colorScheme)
                                        )
                                )
                                .foregroundColor(
                                    selected
                                        ? .white
                                        : future
                                            ? AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.4)
                                            : AviationTheme.Colors.primaryText(colorScheme)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                        .stroke(
                                            selected ? AviationTheme.Colors.brandColor(colorScheme) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: selected ? AviationTheme.Colors.brandColor(colorScheme).opacity(0.28) : .clear, radius: 4, x: 0, y: 2)
                        }
                        .disabled(future)
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                
                Spacer()
            }
            .padding(.top, AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.background(colorScheme))
            .navigationTitle("選擇月份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                }
            }
        }
    }
}

// MARK: - 卡片
struct DateHeaderCard: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    let date: Date
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor: return false
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(AviationTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
        }
        .padding(.horizontal, hasBackgroundImage ? 10 : 0)
        .padding(.vertical, hasBackgroundImage ? 4 : 0)
        .background {
            if hasBackgroundImage {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

struct TransactionDetailRow: View {
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    var showDate: Bool = false
    
    var hasAmount: Bool {
        transaction.amount > 0
    }

    var isRedeemTransaction: Bool {
        transaction.source == .ticketRedemption
    }

    var isCardSource: Bool {
        CardBrandRegistry.sourceNeedsCard(transaction.source)
    }

    var displayTitle: String {
        transaction.source.rawValue
    }

    var milesTintColor: Color {
        isRedeemTransaction ? AviationTheme.Colors.danger : AviationTheme.Colors.brandColor(colorScheme)
    }

    var redeemAccentColor: Color {
        colorScheme == .dark ? AviationTheme.Colors.starluxIndigoLight : AviationTheme.Colors.starluxIndigo
    }

    /// 根據來源類型回傳對應的明細文字
    var sourceDetail: String? {
        switch transaction.source {
        case .cardAccelerator, .taishinDesignated:
            return transaction.resolvedSubcategoryID
        case .specialMerchant:
            return transaction.merchantName
        case .pointsConversion, .pointsTransfer:
            return transaction.conversionSource
        case .promotion:
            return transaction.promotionName
        default:
            return nil
        }
    }

    var cleanedNoteText: String {
        let note = transaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRedeemTransaction && note.hasPrefix("兌換機票：") {
            return ""
        }
        return note
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: AviationTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(isRedeemTransaction ? redeemAccentColor : AviationTheme.Colors.brandColor(colorScheme))
                    .frame(width: 44, height: 44)

                Image(systemName: isRedeemTransaction ? "ticket.fill" : transaction.source.icon)
                    .font(.body)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(AviationTheme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                // 信用卡名稱（信用卡消費來源時顯示）
                if let cardName = transaction.cardDisplayName, isCardSource {
                    Text(cardName)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                        .lineLimit(1)
                }

                // 來源明細：加速器類別 / 商家名稱 / 轉點來源 / 活動名稱
                if let detail = sourceDetail, !detail.isEmpty {
                    Text(detail)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if hasAmount {
                    Text("NT$ \((transaction.amount as NSDecimalNumber).intValue.formatted())")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }

                if let route = transaction.flightRoute, !route.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isRedeemTransaction ? "airplane.arrival" : "airplane.departure")
                            .font(.caption2)
                        Text(route)
                            .font(AviationTheme.Typography.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundColor(isRedeemTransaction ? redeemAccentColor : AviationTheme.Colors.brandColor(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((isRedeemTransaction ? redeemAccentColor : AviationTheme.Colors.brandColor(colorScheme)).opacity(0.15))
                    )
                }

                if !cleanedNoteText.isEmpty {
                    Text(cleanedNoteText)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(transaction.earnedMiles > 0 ? "+" : "")\(transaction.earnedMiles)")
                        .font(AviationTheme.Typography.subheadline)
                        .fontWeight(.bold)
                    Text("哩")
                        .font(AviationTheme.Typography.caption)
                }
                .foregroundColor(milesTintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(milesTintColor.opacity(0.15))
                )

                if hasAmount && transaction.costPerMile > 0 {
                    Text("@\(String(format: "%.2f", transaction.costPerMile))")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
            }
        }
        .padding(AviationTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .fill(AviationTheme.Colors.cardBackground(colorScheme))
        )
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .stroke(
                    isRedeemTransaction
                        ? redeemAccentColor.opacity(colorScheme == .dark ? 0.35 : 0.22)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    LedgerView(viewModel: MileageViewModel())
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}
