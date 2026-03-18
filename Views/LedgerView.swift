//
//  LedgerView.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    @State private var showingAddTransaction = false
    @State private var selectedMonth = Date()
    
    var filteredTransactions: [Transaction] {
        viewModel.transactions.filter { transaction in
            Calendar.current.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    // 按類別統計
    var categoryStats: [(source: MileageSource, amount: Decimal, miles: Int)] {
        let grouped = Dictionary(grouping: filteredTransactions) { $0.source }
        return grouped.map { source, transactions in
            let amount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
            let miles = transactions.reduce(0) { $0 + $1.earnedMiles }
            return (source, amount, miles)
        }.sorted { $0.miles > $1.miles } // 按哩程數排序
    }
    
    var monthlyTotal: (amount: Decimal, miles: Int) {
        let amount = filteredTransactions.reduce(Decimal(0)) { $0 + $1.amount }
        let miles = filteredTransactions.reduce(0) { $0 + $1.earnedMiles }
        return (amount, miles)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 統一背景
                AviationTheme.Gradients.dashboardBackground(colorScheme)
                    .ignoresSafeArea()
                
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
                                        .foregroundColor(AviationTheme.Colors.success)
                                    Text("本月總哩程")
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                }
                                Text("\(monthlyTotal.miles.formatted())")
                                    .font(AviationTheme.Typography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AviationTheme.Colors.success)
                                + Text(" 哩")
                                    .font(AviationTheme.Typography.subheadline)
                                    .foregroundColor(AviationTheme.Colors.success)
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
                                    Text("\(monthlyTotal.miles.formatted())")
                                        .font(AviationTheme.Typography.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                                    + Text(" 哩")
                                        .font(AviationTheme.Typography.subheadline)
                                        .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                                }
                                
                                // 右側：類別統計細項
                                VStack(alignment: .leading, spacing: AviationTheme.Spacing.xs) {
                                    ForEach(categoryStats, id: \.source) { stat in
                                        CompactCategoryStatRow(
                                            source: stat.source,
                                            amount: stat.amount,
                                            miles: stat.miles,
                                            colorScheme: colorScheme
                                        )
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
                                                ? Color.white.opacity(0.05)
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
                                ForEach(Array(filteredTransactions.sorted(by: { $0.date > $1.date }).enumerated()), id: \.element.id) { index, transaction in
                                    let showDate = index == 0 || !Calendar.current.isDate(
                                        transaction.date,
                                        inSameDayAs: filteredTransactions.sorted(by: { $0.date > $1.date })[index - 1].date
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
                        }
                }
            }
            .navigationTitle("哩程記帳本")
            .navigationBarTitleDisplayMode(.large) // 使用 large 模式，滾動時會自動縮小
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
            .sheet(isPresented: $showingAddTransaction) {
                CalculatorLedgerView(viewModel: viewModel)
            }
        }
    }
    
    // 將交易按日期分組
    func groupedTransactions() -> [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // 刪除交易
    func deleteTransactions(at offsets: IndexSet, from transactions: [Transaction]) {
        for index in offsets {
            let transaction = transactions[index]
            viewModel.deleteTransaction(transaction)
        }
    }
}

// MARK: - 精簡版類別統計列（用於統計卡片右側）
struct CompactCategoryStatRow: View {
    let source: MileageSource
    let amount: Decimal
    let miles: Int
    let colorScheme: ColorScheme
    
    var hasAmount: Bool {
        amount > 0
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 圖標
            Image(systemName: source.icon)
                .font(.caption2)
                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                .frame(width: 16)
            
            // 類別名稱
            VStack(alignment: .leading, spacing: 1) {
                Text(source.rawValue)
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
            Text("\(miles.formatted())")
                .font(AviationTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            + Text(" 哩")
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
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
            
            VStack(spacing: 2) {
                Text(selectedMonth.formatted(.dateTime.year()))
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                
                Text(selectedMonth.formatted(.dateTime.month(.wide)))
                    .font(AviationTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
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
                            .fill(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.1)
                            )
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
    }
    
    var canGoNext: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? Date()
        return nextMonth <= Date()
    }
}

// MARK: - 卡片
struct DateHeaderCard: View {
    @Environment(\.colorScheme) var colorScheme
    let date: Date
    
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
    }
}

struct TransactionDetailRow: View {
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction
    var showDate: Bool = false
    
    var hasAmount: Bool {
        transaction.amount > 0
    }
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
                // 圖標
                ZStack {
                    Circle()
                        .fill(AviationTheme.Gradients.cathayJadeGradient(colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: transaction.source.icon)
                        .font(.body)
                        .foregroundColor(.white)
                }
                
                // 資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.source.rawValue)
                        .font(AviationTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                HStack(spacing: 8) {
                    // 只在有金額時顯示金額
                    if hasAmount {
                        Text("NT$ \((transaction.amount as NSDecimalNumber).intValue.formatted())")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                    
                    // 飛行累積：顯示航線
                    if let route = transaction.flightRoute, !route.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "airplane.departure")
                                .font(.caption2)
                            Text(route)
                                .font(AviationTheme.Typography.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AviationTheme.Colors.cathayJade.opacity(0.15))
                        )
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    }
                    
                    // 銀行點數兌換/他點轉入：顯示來源
                    if let source = transaction.conversionSource, !source.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: transaction.source == .pointsConversion ? "building.columns" : "arrow.down.app")
                                .font(.caption2)
                            Text(source)
                                .font(AviationTheme.Typography.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.15))
                        )
                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    }
                    
                    // 特店消費累積：顯示商家名稱
                    if let merchant = transaction.merchantName, !merchant.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "storefront")
                                .font(.caption2)
                            Text(merchant)
                                .font(AviationTheme.Typography.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    colorScheme == .dark 
                                        ? Color(red: 0.5, green: 0.6, blue: 0.7).opacity(0.2)
                                        : Color(red: 0.4, green: 0.5, blue: 0.6).opacity(0.15)
                                )
                        )
                        .foregroundColor(
                            colorScheme == .dark
                                ? Color(red: 0.6, green: 0.7, blue: 0.8)
                                : Color(red: 0.3, green: 0.4, blue: 0.5)
                        )
                    }
                    
                    // 活動贈送：顯示活動名稱
                    if let promotion = transaction.promotionName, !promotion.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "gift")
                                .font(.caption2)
                            Text(promotion)
                                .font(AviationTheme.Typography.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    colorScheme == .dark
                                        ? Color(red: 0.7, green: 0.55, blue: 0.45).opacity(0.2)
                                        : Color(red: 0.65, green: 0.5, blue: 0.4).opacity(0.15)
                                )
                        )
                        .foregroundColor(
                            colorScheme == .dark
                                ? Color(red: 0.8, green: 0.65, blue: 0.55)
                                : Color(red: 0.6, green: 0.45, blue: 0.35)
                        )
                    }
                    
                    if let accelerator = transaction.acceleratorCategory {
                        HStack(spacing: 4) {
                            Image(systemName: accelerator.icon)
                                .font(.caption2)
                            Text(accelerator.rawValue)
                                .font(AviationTheme.Typography.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AviationTheme.Colors.warning.opacity(0.15))
                        )
                        .foregroundColor(AviationTheme.Colors.warning)
                    }
                    
                    if !transaction.notes.isEmpty {
                        Text(transaction.notes)
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            .lineLimit(1)
                    }
                }
            }
            
                Spacer()
                
                // 哩程
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("+\(transaction.earnedMiles)")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.bold)
                        Text("哩")
                            .font(AviationTheme.Typography.caption)
                    }
                    .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.successColor(colorScheme).opacity(0.15))
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
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.03)
                        : Color.white
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md))
    }
}

#Preview {
    LedgerView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
