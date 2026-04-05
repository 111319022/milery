import SwiftUI

/// App Icon 資料模型
struct AppIconOption: Identifiable {
    let id: String          // 對應 Info.plist 裡的 alternateIconName，預設 icon 用 nil
    let displayName: String // 顯示名稱
    let previewAsset: String // Assets 中預覽用的圖片名稱

    /// 是否為預設 icon
    var isDefault: Bool { id == "AppIcon" }
}

struct AppIconPickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentIconID: String = "AppIcon"
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    // 在此維護所有可切換的 icon 清單
    // previewAsset 需要在 Assets.xcassets/appicon 資料夾放入對應的圖片
    private let icons: [AppIconOption] = [
        AppIconOption(id: "AppIcon", displayName: "預設", previewAsset: "appicon_default_preview"),
        AppIconOption(id: "AppIcon-Blue-1", displayName: "藍色", previewAsset: "appicon_blue_1_preview"),
        AppIconOption(id: "AppIcon-Dark-1", displayName: "深色", previewAsset: "appicon_dark_1_preview"),
        // 之後新增的 icon 在這裡加入
        // AppIconOption(id: "AppIcon-Dark", displayName: "深色", previewAsset: "appicon/AppIcon-Dark-preview"),
        // AppIconOption(id: "AppIcon-Gold", displayName: "金色", previewAsset: "appicon/AppIcon-Gold-preview"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.xl) {
                    SectionHeaderView(title: "選擇 App 圖示", colorScheme: colorScheme)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(icons) { icon in
                            iconCard(icon)
                        }
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.vertical, AviationTheme.Spacing.md)
            }
        }
        .navigationTitle("App 圖示")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            currentIconID = UIApplication.shared.alternateIconName ?? "AppIcon"
        }
        .alert("無法更換圖示", isPresented: $showingErrorAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Icon 卡片

    private func iconCard(_ icon: AppIconOption) -> some View {
        let isSelected = currentIconID == icon.id
        return Button {
            setAppIcon(icon)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    // Icon 預覽圖
                    if let uiImage = UIImage(named: icon.previewAsset) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.4), radius: 6, x: 0, y: 3)
                    } else {
                        // 圖片尚未放置時的佔位
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AviationTheme.Colors.cardBackground(colorScheme))
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.title)
                                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            }
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 4, x: 0, y: 2)
                    }

                    // 選中勾選
                    if isSelected {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(AviationTheme.Colors.cathayJade)
                                    .background(Color.white.clipShape(Circle()))
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 2)
                            }
                        }
                        .frame(width: 72, height: 72)
                    }
                }

                Text(icon.displayName)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(
                        isSelected
                            ? AviationTheme.Colors.brandColor(colorScheme)
                            : AviationTheme.Colors.primaryText(colorScheme)
                    )
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 切換 Icon

    private func setAppIcon(_ icon: AppIconOption) {
        let iconName: String? = icon.isDefault ? nil : icon.id

        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "此裝置不支援更換 App 圖示。"
            showingErrorAlert = true
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            } else {
                currentIconID = icon.id
            }
        }
    }
}
