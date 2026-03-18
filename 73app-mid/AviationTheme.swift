//
//  AviationTheme.swift
//  73app-mid
//
//  Created by Ray Hsu on 2026/3/16.
//

import SwiftUI

// 航空風格主題系統 - 支援深色/淺色雙模式
struct AviationTheme {
    
    // MARK: - 動態顏色（根據 ColorScheme 自動切換）
    struct Colors {
        // MARK: - 星宇航空大地色系（淺色模式）
        // 深藍靛色 - 主色調
        static let starluxIndigo = Color(red: 0.20, green: 0.25, blue: 0.35)
        static let starluxIndigoLight = Color(red: 0.30, green: 0.35, blue: 0.45)
        
        // 大地棕色
        static let earthBrown = Color(red: 0.55, green: 0.45, blue: 0.35)
        static let lightBrown = Color(red: 0.75, green: 0.65, blue: 0.55)
        static let darkBrown = Color(red: 0.35, green: 0.28, blue: 0.22)
        
        // 沙漠米色
        static let desertBeige = Color(red: 0.90, green: 0.85, blue: 0.75)
        static let lightBeige = Color(red: 0.95, green: 0.92, blue: 0.85)
        static let warmBeige = Color(red: 0.85, green: 0.78, blue: 0.68)
        
        // 天空灰藍
        static let skyGray = Color(red: 0.65, green: 0.70, blue: 0.75)
        static let lightSkyGray = Color(red: 0.85, green: 0.88, blue: 0.90)
        
        // MARK: - 深色模式金屬色系
        // 深藍金屬
        static let darkPrimaryMetal = Color(red: 0.15, green: 0.25, blue: 0.35)
        static let darkSecondaryMetal = Color(red: 0.2, green: 0.3, blue: 0.4)
        
        // 金色點綴
        static let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
        static let lightGold = Color(red: 0.95, green: 0.85, blue: 0.55)
        static let darkGold = Color(red: 0.65, green: 0.50, blue: 0.10)
        
        // 銀色金屬
        static let silver = Color(red: 0.75, green: 0.75, blue: 0.75)
        static let lightSilver = Color(red: 0.90, green: 0.90, blue: 0.92)
        static let darkSilver = Color(red: 0.50, green: 0.50, blue: 0.52)
        
        // MARK: - 品牌色（統一）
        // 國泰翡翠綠
        static let cathayJade = Color(red: 0.0, green: 0.42, blue: 0.42)
        static let cathayJadeLight = Color(red: 0.1, green: 0.52, blue: 0.52)
        static let cathayJadeDark = Color(red: 0.0, green: 0.32, blue: 0.32)
        
        // 修改：深色模式專用翡翠綠（降低亮度和飽和度，改為沉穩的玉石色）
        static let cathayJadeBright = Color(red: 0.15, green: 0.65, blue: 0.65) // 原本是 0.3, 0.85, 0.85 (太刺眼)
        static let cathayJadeBrightLight = Color(red: 0.25, green: 0.75, blue: 0.75) // 原本是 0.4, 0.95, 0.95
        
        // 星宇金色
        static let starluxGold = Color(red: 0.78, green: 0.62, blue: 0.42)
        
        // MARK: - 功能色（統一）
        // 修改：微調深色模式的成功與警告色，避免過亮
        static let success = Color(red: 0.18, green: 0.65, blue: 0.35)
        static let warning = Color(red: 0.85, green: 0.60, blue: 0.15)
        static let danger = Color(red: 0.85, green: 0.25, blue: 0.25)
        
        // MARK: - 自適應顏色（根據 ColorScheme 切換）
        static func background(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(red: 0.08, green: 0.08, blue: 0.12)
                : Color(red: 0.96, green: 0.94, blue: 0.90)
        }
        
        static func cardBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(red: 0.10, green: 0.11, blue: 0.15) // 🛠️ 微調：讓卡片底色稍微暗一點點，融入背景
                : Color.white
        }
        
        static func surfaceBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color(red: 0.13, green: 0.14, blue: 0.18)
                : Color(red: 0.98, green: 0.96, blue: 0.93)
        }
        
        static func primaryText(_ colorScheme: ColorScheme) -> Color {
            // 修改：深色模式下純白太刺眼，改用帶有一點點灰藍的「珍珠白」
            colorScheme == .dark ? Color(red: 0.92, green: 0.92, blue: 0.95) : starluxIndigo
        }
        
        static func secondaryText(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? silver : earthBrown
        }
        
        static func tertiaryText(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? darkSilver : skyGray
        }
        
        // 自適應品牌色（國泰翡翠綠）
        static func brandColor(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? cathayJadeBright : cathayJade
        }
        
        static func brandColorLight(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? cathayJadeBrightLight : cathayJadeLight
        }
        
        // 自適應成功色（綠色）
        static func successColor(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(red: 0.4, green: 0.9, blue: 0.6) : Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }
    
    // MARK: - Gradients (自適應漸層)
    struct Gradients {
        // 🛠️ 修改：深色模式漸層 - 降低藍色飽和度與亮度，讓它更接近深邃的夜空消光感
        static let darkMetalBlue = LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.15, blue: 0.22), // 原本是 0.15, 0.25, 0.40
                Color(red: 0.07, green: 0.09, blue: 0.13)  // 原本是 0.10, 0.18, 0.30
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 淺色模式漸層 - 星宇大地色
        static let lightEarthTone = LinearGradient(
            colors: [
                Color(red: 0.92, green: 0.88, blue: 0.80),
                Color(red: 0.85, green: 0.78, blue: 0.68)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let lightIndigo = LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.30, blue: 0.42),
                Color(red: 0.20, green: 0.25, blue: 0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 金色漸層（通用）
        static let metalGold = LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.75, blue: 0.25),
                Color(red: 0.75, green: 0.55, blue: 0.15),
                Color(red: 0.65, green: 0.45, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 星宇金色漸層
        static let starluxGold = LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.70, blue: 0.50),
                Color(red: 0.75, green: 0.60, blue: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 銀色金屬漸層
        static let metalSilver = LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.85, blue: 0.88),
                Color(red: 0.65, green: 0.65, blue: 0.68),
                Color(red: 0.55, green: 0.55, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 國泰翡翠綠漸層（淺色模式）
        static let cathayJade = LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.50, blue: 0.50),
                Color(red: 0.00, green: 0.38, blue: 0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 修改：國泰翡翠綠漸層（深色模式 - 沉穩玉石色）
        static let cathayJadeBright = LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.75, blue: 0.75), // 原本 0.4, 0.95, 0.95
                Color(red: 0.15, green: 0.65, blue: 0.65)  // 原本 0.3, 0.85, 0.85
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 自適應國泰翡翠綠漸層
        static func cathayJadeGradient(_ colorScheme: ColorScheme) -> LinearGradient {
            colorScheme == .dark ? cathayJadeBright : cathayJade
        }
        
        // 自適應背景漸層
        static func dashboardBackground(_ colorScheme: ColorScheme) -> LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 0.92),
                        Color(red: 0.94, green: 0.90, blue: 0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        
        // 自適應卡片漸層
        static func cardGradient(_ colorScheme: ColorScheme) -> LinearGradient {
            if colorScheme == .dark {
                return darkMetalBlue
            } else {
                return lightIndigo
            }
        }
    }
    
    // MARK: - Shadows (自適應陰影)
    struct Shadows {
        static func cardShadow(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.black.opacity(0.08)
        }
        
        static func deepShadow(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.black.opacity(0.5)
                : Color.black.opacity(0.12)
        }
        
        static let lightShadow = Color.black.opacity(0.05)
        static let goldGlow = Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.3)
    }
    
    // MARK: - Typography (航空字型)
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .medium, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
        
        // 數字專用字型
        static let mileageDisplay = Font.system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
    }
    
    // MARK: - Spacing (間距)
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius (圓角)
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
}

// MARK: - 金屬卡片樣式（自適應）
struct MetalCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var gradient: LinearGradient?
    var cornerRadius: CGFloat = AviationTheme.CornerRadius.lg
    var useAdaptiveGradient: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 背景漸層
                    if let gradient = gradient {
                        gradient
                    } else if useAdaptiveGradient {
                        AviationTheme.Gradients.cardGradient(colorScheme)
                    }
                    
                    // 修改：減弱深色模式下的金屬邊緣反光
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35),
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(cornerRadius)
            .shadow(
                color: AviationTheme.Shadows.cardShadow(colorScheme),
                radius: colorScheme == .dark ? 10 : 8,
                x: 0,
                y: colorScheme == .dark ? 5 : 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5), // 🛠️ 邊框反光減弱
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - 玻璃擬態效果（自適應）
struct GlassmorphismStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if colorScheme == .dark {
                        Color.white.opacity(0.05)
                        BlurView(style: .systemUltraThinMaterialDark)
                    } else {
                        Color.white.opacity(0.7)
                        BlurView(style: .systemUltraThinMaterialLight)
                    }
                }
            )
            .cornerRadius(AviationTheme.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: AviationTheme.Shadows.cardShadow(colorScheme),
                radius: 6,
                x: 0,
                y: 2
            )
    }
}

// MARK: - 模糊視圖（iOS 兼容）
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - 金屬按鈕樣式
struct MetalButtonStyle: ButtonStyle {
    var color: LinearGradient = AviationTheme.Gradients.metalGold
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    color
                    
                    if configuration.isPressed {
                        Color.black.opacity(0.2)
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(AviationTheme.CornerRadius.md)
            .shadow(color: AviationTheme.Shadows.goldGlow, radius: configuration.isPressed ? 5 : 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func metalCard(
        gradient: LinearGradient? = nil,
        cornerRadius: CGFloat = AviationTheme.CornerRadius.lg,
        useAdaptiveGradient: Bool = true
    ) -> some View {
        modifier(MetalCardStyle(
            gradient: gradient,
            cornerRadius: cornerRadius,
            useAdaptiveGradient: useAdaptiveGradient
        ))
    }
    
    func glassmorphism() -> some View {
        modifier(GlassmorphismStyle())
    }
}
