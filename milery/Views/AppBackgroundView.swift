import SwiftUI

/// 統一背景元件：根據使用者設定顯示預設漸層或背景圖片。
/// 用於取代各頁面中的 `AviationTheme.Gradients.dashboardBackground(colorScheme)`。
struct AppBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 底層：始終渲染漸層（作為 fallback 與載入時的底色）
                AviationTheme.Gradients.dashboardBackground(colorScheme)

                // 純色背景
                if case .solidColor(let hex) = backgroundSelection {
                    Color(hex: hex)
                }

                // 漸層背景
                if case .gradient(let id) = backgroundSelection,
                   let def = GradientRegistry.definition(for: id) {
                    def.linearGradient
                }

                // 若有選擇背景圖片
                if let image = resolvedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // 可讀性遮罩：確保文字在圖片上仍可閱讀
                    Rectangle()
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.45)
                                : Color.white.opacity(0.35)
                        )
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: backgroundSelection)
    }

    private var resolvedImage: UIImage? {
        switch backgroundSelection {
        case .none, .solidColor, .gradient:
            return nil
        case .preset(let name):
            return BackgroundImageManager.shared.loadPresetImage(name: name)
        case .custom(let filename):
            return BackgroundImageManager.shared.loadCustomImage(filename: filename)
        }
    }
}

// MARK: - Color Hex 初始化

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
