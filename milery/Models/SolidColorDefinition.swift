import SwiftUI

// MARK: - 基礎枚舉與定義

/// 外觀模式篩選
enum ColorSchemeVisibility: String {
    case light   // 僅淺色模式顯示
    case dark    // 僅深色模式顯示
    case both    // 都顯示
}

/// 內建純色背景定義
struct SolidColorDefinition: Identifiable {
    var id: String { hex }
    let hex: String       // 色碼（不含 #）
    let name: String      // 顯示名稱
    let titleHex: String  // 標題文字色碼（不含 #）
    let visibility: ColorSchemeVisibility

    /// 標題文字顏色
    var titleColor: Color { Color(hex: titleHex) }

    func isVisible(in colorScheme: ColorScheme) -> Bool {
        switch visibility {
        case .both: return true
        case .light: return colorScheme == .light
        case .dark: return colorScheme == .dark
        }
    }
}

// MARK: - 純色管理

enum SolidColorRegistry {
    static let all: [SolidColorDefinition] = [
        SolidColorDefinition(hex: "F2F2F7", name: "淺灰色", titleHex: "8E8E93", visibility: .light),
        // 往下新增更多純色背景
    ]

    static func visible(for colorScheme: ColorScheme) -> [SolidColorDefinition] {
        all.filter { $0.isVisible(in: colorScheme) }
    }
}

// MARK: - 漸層定義

struct GradientStop {
    let hex: String
    let location: CGFloat // 0.0 ~ 1.0
}

struct GradientDefinition: Identifiable {
    let id: String
    let name: String
    let titleHex: String  // 標題文字色碼（不含 #）
    let stops: [GradientStop]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    let visibility: ColorSchemeVisibility

    /// 標題文字顏色
    var titleColor: Color { Color(hex: titleHex) }

    func isVisible(in colorScheme: ColorScheme) -> Bool {
        switch visibility {
        case .both: return true
        case .light: return colorScheme == .light
        case .dark: return colorScheme == .dark
        }
    }

    var linearGradient: LinearGradient {
        LinearGradient(
            stops: stops.map { Gradient.Stop(color: Color(hex: $0.hex), location: $0.location) },
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// MARK: - 漸層管理

enum GradientRegistry {
    static let all: [GradientDefinition] = [
        // MARK: - 琥珀夜色 (in深色模式)
        GradientDefinition(
            id: "amber_night",
            name: "琥珀夜色",
            titleHex: "FFD9A0",
            stops: [
                GradientStop(hex: "FFB347", location: 0.0),
                GradientStop(hex: "8B4513", location: 0.15),
                GradientStop(hex: "321400", location: 0.4),
                GradientStop(hex: "0D0800", location: 0.7),
                GradientStop(hex: "000000", location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
            visibility: .dark
        ),
        
        // MARK: - 琥珀晨光 (in淺色模式)
        GradientDefinition(
            id: "amber_morning",
            name: "琥珀晨光",
            titleHex: "C49A40",
            stops: [
                GradientStop(hex: "FFF9E0", location: 0.0),
                
                GradientStop(hex: "FFFCED", location: 0.4),
                
                GradientStop(hex: "FFFAF0", location: 0.8),
                
                GradientStop(hex: "FFFFFF", location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
            visibility: .light
        )
    ]

    /// 根據 ID 查找漸層定義 (現在已正確包含在 enum 內)
    static func definition(for id: String) -> GradientDefinition? {
        all.first { $0.id == id }
    }

    /// 根據目前外觀模式篩選可見的漸層背景
    static func visible(for colorScheme: ColorScheme) -> [GradientDefinition] {
        all.filter { $0.isVisible(in: colorScheme) }
    }
}

