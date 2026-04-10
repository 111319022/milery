import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("userName") private var userName: String = ""

    private let profileService = ProfileService.shared
    private let friendService = FriendService.shared

    @State private var editingName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingName = false
    @State private var showDeleteAvatarConfirm = false

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {

                    // MARK: - 頭貼區域
                    VStack(spacing: AviationTheme.Spacing.md) {
                        ProfileAvatarView(image: profileService.avatarImage, size: 100)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("更換頭貼")
                                    .font(AviationTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(AviationTheme.Colors.cathayJade))
                            }

                            if profileService.avatarImage != nil {
                                Button {
                                    showDeleteAvatarConfirm = true
                                } label: {
                                    Text("移除頭貼")
                                        .font(AviationTheme.Typography.caption)
                                        .foregroundColor(AviationTheme.Colors.danger)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .strokeBorder(AviationTheme.Colors.danger.opacity(0.3))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, AviationTheme.Spacing.xl)

                    // MARK: - 名稱
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "顯示名稱", colorScheme: colorScheme)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(AviationTheme.Colors.cathayJade)
                                    .frame(width: 24)

                                TextField("輸入你的名稱", text: $editingName)
                                    .font(AviationTheme.Typography.body)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                    .autocorrectionDisabled()
                                    .onSubmit {
                                        commitNameChange()
                                    }
                            }
                            .padding(AviationTheme.Spacing.md)
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)

                        Text("此名稱會顯示在好友列表中")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)

                    // MARK: - 好友代碼（唯讀）
                    if let profile = friendService.currentUserProfile {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "好友代碼", colorScheme: colorScheme)

                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "qrcode")
                                        .foregroundColor(AviationTheme.Colors.cathayJade)
                                        .frame(width: 24)

                                    Text(profile.friendCode)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                        .tracking(2)

                                    Spacer()

                                    Button {
                                        UIPasteboard.general.string = profile.friendCode
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.success)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.subheadline)
                                            .foregroundColor(AviationTheme.Colors.cathayJade)
                                    }
                                }
                                .padding(AviationTheme.Spacing.md)
                            }
                            .background(AviationTheme.Colors.cardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                    }
                }
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("個人資料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editingName = userName
        }
        .onDisappear {
            commitNameChange()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadAndSavePhoto(from: newValue)
                selectedPhotoItem = nil
            }
        }
        .alert("移除頭貼", isPresented: $showDeleteAvatarConfirm) {
            Button("移除", role: .destructive) {
                profileService.deleteAvatar()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("確定要移除頭貼嗎？將恢復為預設圖示。")
        }
    }

    // MARK: - Helpers

    private func commitNameChange() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != userName else { return }
        userName = trimmed
        Task {
            await profileService.updateDisplayName(trimmed)
        }
    }

    private func loadAndSavePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            appLog("[ProfileEditView] 圖片載入失敗")
            return
        }
        profileService.saveAvatar(uiImage)
    }
}
