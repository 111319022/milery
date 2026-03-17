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
    
    var activeCards: [CreditCardRule] {
        viewModel.creditCards.filter { $0.isActive }
    }
    
    // 如果只有一張卡,自動選擇
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
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("記帳")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(
                    AviationTheme.Colors.background(colorScheme).opacity(0.95),
                    for: .navigationBar
                )
                .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    // 如果只有一張卡,自動選擇
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
                VStack(spacing: AviationTheme.Spacing.lg) {
                    // 來源選擇器
                    sourceSelector
                    
                    // 主要表單內容
                    mainContentArea
                }
                .padding(.vertical, AviationTheme.Spacing.md)
            }
        }
        .onTapGesture {
            // 點擊外部關閉鍵盤
            hideKeyboard()
        }
    }
    
    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            Text("哩程來源")
                .font(AviationTheme.Typography.subheadline)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                .padding(.horizontal, AviationTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AviationTheme.Spacing.sm) {
                    ForEach(MileageSource.allCases, id: \.self) { source in
                        SourceButton(
                            source: source,
                            isSelected: selectedSource == source,
                            colorScheme: colorScheme
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSource = source
                                if !needsCardSelection {
                                    selectedCard = nil
                                }
                                if !needsAccelerator {
                                    selectedAccelerator = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
            }
        }
        .padding(.vertical, AviationTheme.Spacing.sm)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
    }
    
    private var mainContentArea: some View {
        VStack(spacing: AviationTheme.Spacing.md) {
            // 信用卡選擇（如果需要且不是自動選擇）
            if needsCardSelection && activeCards.count > 1 {
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard")
                            .font(.caption)
                            .foregroundColor(AviationTheme.Colors.cathayJade)
                        Text("選擇信用卡")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    VStack(spacing: AviationTheme.Spacing.xs) {
                        ForEach(activeCards, id: \.id) { card in
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
                        }
                    }
                    .padding(AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .cornerRadius(AviationTheme.CornerRadius.md)
                    .padding(.horizontal, AviationTheme.Spacing.md)
                }
            }
            
            // 金額或哩程輸入 + 即時顯示
            VStack(spacing: AviationTheme.Spacing.md) {
                // 一般消費 / 哩程加速器 - 輸入金額
                if needsAmountInput {
                    VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.caption)
                                .foregroundColor(AviationTheme.Colors.starluxGold)
                            Text("消費金額")
                                .font(AviationTheme.Typography.subheadline)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        VStack(spacing: 0) {
                            // 金額輸入框
                            HStack {
                                Text("NT$")
                                    .font(AviationTheme.Typography.title3)
                                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                TextField("0", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(AviationTheme.Typography.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(AviationTheme.Spacing.md)
                            
                            // 即時換算哩程顯示
                            if let info = calculatedMilesDisplay {
                                Divider()
                                    .background(
                                        colorScheme == .dark
                                            ? Color.white.opacity(0.1)
                                            : Color.black.opacity(0.1)
                                    )
                                
                                HStack {
                                    Image(systemName: "airplane.circle.fill")
                                        .foregroundColor(AviationTheme.Colors.cathayJade)
                                    Text("可獲得")
                                        .font(AviationTheme.Typography.subheadline)
                                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("\(info.miles)")
                                            .font(AviationTheme.Typography.title2)
                                            .fontWeight(.bold)
                                        Text("哩")
                                            .font(AviationTheme.Typography.subheadline)
                                    }
                                    .foregroundColor(AviationTheme.Colors.cathayJade)
                                    if info.isBirthdayMonth {
                                        Image(systemName: "gift.fill")
                                            .foregroundColor(.pink)
                                    }
                                }
                                .padding(AviationTheme.Spacing.md)
                                .background(
                                    AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.1 : 0.05)
                                )
                            }
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .cornerRadius(AviationTheme.CornerRadius.md)
                        .padding(.horizontal, AviationTheme.Spacing.md)
                    }
                    
                    // 加速器選擇（如果需要）
                    if needsAccelerator {
                        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                                    .foregroundColor(AviationTheme.Colors.warning)
                                Text("加速器類別")
                                    .font(AviationTheme.Typography.subheadline)
                                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            }
                            .padding(.horizontal, AviationTheme.Spacing.md)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AviationTheme.Spacing.sm) {
                                ForEach(AcceleratorCategory.allCases, id: \.self) { category in
                                    CompactAcceleratorButton(
                                        category: category,
                                        isSelected: selectedAccelerator == category,
                                        colorScheme: colorScheme
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedAccelerator = category
                                        }
                                    }
                                }
                            }
                            .padding(AviationTheme.Spacing.md)
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .cornerRadius(AviationTheme.CornerRadius.md)
                            .padding(.horizontal, AviationTheme.Spacing.md)
                        }
                    }
                } else {
                    // 其他來源 - 直接輸入哩程
                    VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "airplane.circle.fill")
                                .font(.caption)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                            Text("獲得哩程")
                                .font(AviationTheme.Typography.subheadline)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        
                        HStack {
                            TextField("0", text: $earnedMiles)
                                .keyboardType(.numberPad)
                                .font(AviationTheme.Typography.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                .multilineTextAlignment(.leading)
                            Text("哩")
                                .font(AviationTheme.Typography.title3)
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        }
                        .padding(AviationTheme.Spacing.md)
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .cornerRadius(AviationTheme.CornerRadius.md)
                        .padding(.horizontal, AviationTheme.Spacing.md)
                    }
                }
            }
            
            // 日期選擇
            FormRow(
                icon: "calendar.circle.fill",
                title: "日期",
                colorScheme: colorScheme
            ) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            
            // 備註輸入
            VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(AviationTheme.Colors.silver)
                    Text("備註（選填）")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                
                TextField("輸入備註", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    .padding(AviationTheme.Spacing.md)
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .cornerRadius(AviationTheme.CornerRadius.md)
                    .padding(.horizontal, AviationTheme.Spacing.md)
            }
        }
    }
    
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
            .fontWeight(.semibold)
        }
    }
    
    // 計算顯示的哩程資訊
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
        // 如果需要輸入金額
        if needsAmountInput {
            guard let amountValue = Decimal(string: amount), amountValue > 0 else {
                return false
            }
            // 需要選擇信用卡
            guard selectedCard != nil else {
                return false
            }
            // 如果是加速器,需要選擇加速器類別
            if needsAccelerator && selectedAccelerator == nil {
                return false
            }
            return true
        } else {
            // 其他來源直接輸入哩程
            guard let milesValue = Int(earnedMiles), milesValue > 0 else {
                return false
            }
            return true
        }
    }
    
    private func saveTransaction() {
        let miles: Int
        let finalAmount: Decimal
        
        if needsAmountInput {
            // 從金額計算哩程
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
            // 直接輸入哩程
            guard let milesValue = Int(earnedMiles) else { return }
            miles = milesValue
            finalAmount = 0 // 其他來源沒有金額
        }
        
        viewModel.addTransaction(
            amount: finalAmount,
            earnedMiles: miles,
            source: selectedSource,
            acceleratorCategory: selectedAccelerator,
            date: date,
            notes: notes
        )
        
        dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 表單行組件
struct FormRow<Content: View>: View {
    let icon: String
    let title: String
    let colorScheme: ColorScheme
    let content: Content
    
    init(icon: String, title: String, colorScheme: ColorScheme, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.colorScheme = colorScheme
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(AviationTheme.Colors.cathayJade)
                .font(.title3)
            
            Text(title)
                .font(AviationTheme.Typography.body)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            
            Spacer()
            
            content
        }
        .padding(AviationTheme.Spacing.md)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.md)
        .padding(.horizontal, AviationTheme.Spacing.md)
    }
}

// MARK: - 計算哩程資訊
struct CalculatedMilesInfo {
    let miles: Int
    let isBirthdayMonth: Bool
}

// MARK: - 來源按鈕
struct SourceButton: View {
    let source: MileageSource
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: source.icon)
                    .font(.title3)
                Text(source.rawValue)
                    .font(AviationTheme.Typography.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 80, minHeight: 65)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                isSelected 
                    ? AviationTheme.Colors.cathayJade
                    : AviationTheme.Colors.surfaceBackground(colorScheme)
            )
            .foregroundColor(
                isSelected 
                    ? .white 
                    : AviationTheme.Colors.primaryText(colorScheme)
            )
            .cornerRadius(AviationTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .stroke(
                        isSelected ? AviationTheme.Colors.cathayJadeLight : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - 精簡卡片選擇行
struct CompactCardRow: View {
    let card: CreditCardRule
    let isSelected: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            // 選擇指示器
            ZStack {
                Circle()
                    .stroke(
                        isSelected ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.tertiaryText(colorScheme),
                        lineWidth: 2
                    )
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(AviationTheme.Colors.cathayJade)
                        .frame(width: 10, height: 10)
                }
            }
            
            // 卡片資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(card.cardName)
                    .font(AviationTheme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, AviationTheme.Spacing.sm)
        .padding(.horizontal, AviationTheme.Spacing.md)
        .background(
            isSelected
                ? AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.15 : 0.08)
                : Color.clear
        )
        .cornerRadius(AviationTheme.CornerRadius.sm)
    }
}

// MARK: - 精簡加速器按鈕
struct CompactAcceleratorButton: View {
    let category: AcceleratorCategory
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(
                        isSelected
                            ? .white
                            : AviationTheme.Colors.secondaryText(colorScheme)
                    )
                    .frame(height: 30)
                
                Text(category.rawValue)
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(
                        isSelected
                            ? .white
                            : AviationTheme.Colors.primaryText(colorScheme)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AviationTheme.Spacing.md)
            .background(
                Group {
                    if isSelected {
                        AviationTheme.Gradients.cathayJade
                    } else {
                        AviationTheme.Colors.surfaceBackground(colorScheme)
                    }
                }
            )
            .cornerRadius(AviationTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .stroke(
                        isSelected ? Color.clear : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 信用卡選擇行
struct CardSelectionRow: View {
    let card: CreditCardRule
    let isSelected: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            // 選擇指示器
            ZStack {
                Circle()
                    .stroke(
                        isSelected ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.tertiaryText(colorScheme),
                        lineWidth: 2
                    )
                    .frame(width: 22, height: 22)
                
                if isSelected {
                    Circle()
                        .fill(AviationTheme.Colors.cathayJade)
                        .frame(width: 12, height: 12)
                }
            }
            
            // 卡片資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardName)
                    .font(AviationTheme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text(card.bankName)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
            
            // 卡片圖標
            Image(systemName: "creditcard.fill")
                .foregroundColor(
                    isSelected 
                        ? AviationTheme.Colors.cathayJade 
                        : AviationTheme.Colors.tertiaryText(colorScheme)
                )
        }
        .padding(AviationTheme.Spacing.md)
        .background(
            isSelected 
                ? AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.1 : 0.05)
                : Color.clear
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.sm)
                .stroke(
                    isSelected ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2),
                    lineWidth: 1
                )
        )
        .cornerRadius(AviationTheme.CornerRadius.sm)
    }
}

// MARK: - 加速器按鈕
struct AcceleratorButton: View {
    let category: AcceleratorCategory
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AviationTheme.Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(
                        isSelected 
                            ? AviationTheme.Colors.cathayJade 
                            : AviationTheme.Colors.secondaryText(colorScheme)
                    )
                    .frame(height: 40)
                
                Text(category.rawValue)
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(
                        isSelected 
                            ? AviationTheme.Colors.primaryText(colorScheme) 
                            : AviationTheme.Colors.secondaryText(colorScheme)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(AviationTheme.Spacing.md)
            .background(
                isSelected 
                    ? AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.1 : 0.05)
                    : AviationTheme.Colors.surfaceBackground(colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .stroke(
                        isSelected ? AviationTheme.Colors.cathayJade : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(AviationTheme.CornerRadius.md)
        }
    }
}

#Preview {
    CalculatorLedgerView(viewModel: MileageViewModel())
        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self])
}
