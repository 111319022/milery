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
        case .none:
            return nil
        case .preset(let name):
            return UIImage(named: name)
        case .custom(let filename):
            return BackgroundImageManager.shared.loadCustomImage(filename: filename)
        }
    }
}
