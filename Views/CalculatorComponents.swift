import SwiftUI

// 計算哩程資訊
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
            VStack(spacing: 8) {
                Image(systemName: source.icon)
                    .font(.title2)
                Text(source.rawValue)
                    .font(AviationTheme.Typography.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 85, height: 75)
            .padding(.horizontal, 4)
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
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(isSelected ? 0.4 : 0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .stroke(
                        isSelected ? Color.white.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - 精簡卡片選擇行 (iOS 原生打勾風格)
struct CompactCardRow: View {
    let card: CreditCardRule
    let isSelected: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AviationTheme.Colors.cathayJade.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "creditcard.fill")
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(card.cardName)
                    .font(AviationTheme.Typography.body)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    .lineLimit(1)
                Text(card.bankName)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
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
}

// MARK: - 通用子類別按鈕（取代 CompactAcceleratorButton + CompactTaishinDesignatedButton）
struct CompactSubcategoryButton: View {
    let category: CardSpendingCategory
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(
                        isSelected
                            ? .white
                            : AviationTheme.Colors.warning
                    )
                
                Text(category.id)
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(
                        isSelected
                            ? .white
                            : AviationTheme.Colors.primaryText(colorScheme)
                    )
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? AviationTheme.Colors.cathayJade
                    : AviationTheme.Colors.cardBackground(colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(isSelected ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}
