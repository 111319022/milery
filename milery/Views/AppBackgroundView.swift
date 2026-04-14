import SwiftUI

/// 統一背景元件：根據使用者設定顯示預設漸層或背景圖片。
/// 使用 Liquid Glass 風格的模糊漸層球體營造航空高級質感。
struct AppBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 底層：純色基底（不使用漸層）
                AviationTheme.Colors.background(colorScheme)

                // Liquid Glass 漫射光球（僅深色模式 + 無自訂背景時顯示）
                if !hasCustomBackground && colorScheme == .dark {
                    liquidGlassOrbs(in: geo.size)
                }

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

                // Ultra-thin material 霧面覆蓋：讓光球柔和滲透（僅深色模式）
                if !hasCustomBackground && colorScheme == .dark {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.55)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: backgroundSelection)
    }

    /// 是否有自訂背景（圖片/純色/漸層）
    private var hasCustomBackground: Bool {
        switch backgroundSelection {
        case .none: return false
        default: return true
        }
    }

    /// Liquid Glass 漫射光球
    @ViewBuilder
    private func liquidGlassOrbs(in size: CGSize) -> some View {
        // 翡翠綠光球 - 左上
        Circle()
            .fill(AviationTheme.Colors.cathayJade.opacity(colorScheme == .dark ? 0.35 : 0.18))
            .frame(width: size.width * 0.7, height: size.width * 0.7)
            .blur(radius: 120)
            .offset(x: -size.width * 0.25, y: -size.height * 0.1)

        // 香檳金光球 - 右下
        Circle()
            .fill(AviationTheme.Colors.gold.opacity(colorScheme == .dark ? 0.2 : 0.12))
            .frame(width: size.width * 0.6, height: size.width * 0.6)
            .blur(radius: 120)
            .offset(x: size.width * 0.3, y: size.height * 0.25)

        // 深藍光球 - 中央偏下
        Circle()
            .fill(AviationTheme.Colors.darkPrimaryMetal.opacity(colorScheme == .dark ? 0.3 : 0.08))
            .frame(width: size.width * 0.5, height: size.width * 0.5)
            .blur(radius: 100)
            .offset(x: 0, y: size.height * 0.35)
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
