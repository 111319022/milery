import SwiftUI

@MainActor
struct ReportIssueView: View {
    private enum FocusField {
        case email
        case content
    }

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none

    @State private var email = ""
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @FocusState private var focusedField: FocusField?

    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom:
            return true
        case .none, .solidColor, .gradient:
            return false
        }
    }

    private var isContentEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isKeyboardActive: Bool {
        focusedField != nil
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            VStack(spacing: AviationTheme.Spacing.md) {
                if !isKeyboardActive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("回報問題")
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                        Text("請提供問題描述與聯絡方式，我們會盡快確認。")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .transition(.opacity)
                }

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("Email")
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                        }
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                        TextField(
                            "",
                            text: $email,
                            prompt: Text("請輸入聯絡信箱（選填）")
                                .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                        )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AviationTheme.Colors.surfaceBackground(colorScheme))
                            )
                    }
                    .padding(AviationTheme.Spacing.md)

                    CustomDivider(colorScheme: colorScheme)

                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("問題描述")
                        } icon: {
                            Image(systemName: "text.bubble.fill")
                                .foregroundStyle(AviationTheme.Colors.brandColorLight(colorScheme))
                        }
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AviationTheme.Colors.surfaceBackground(colorScheme))

                            TextEditor(text: $content)
                                .frame(minHeight: 150)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                .focused($focusedField, equals: .content)

                            if isContentEmpty {
                                Text("請描述你遇到的狀況與重現步驟")
                                    .font(.body)
                                    .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 22)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(AviationTheme.Spacing.md)
                }
                .background(AviationTheme.Colors.cardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                .padding(.horizontal, AviationTheme.Spacing.md)

                Button {
                    submitReport()
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            SwiftUI.ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }

                        Text(isSubmitting ? "送出中..." : "送出回報")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [AviationTheme.Colors.brandColor(colorScheme), AviationTheme.Colors.brandColorLight(colorScheme)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg, style: .continuous))
                }
                .disabled(isSubmitting || isContentEmpty)
                .opacity(isSubmitting || isContentEmpty ? 0.65 : 1)
                .padding(.horizontal, AviationTheme.Spacing.md)

                Spacer(minLength: 0)
            }
            .padding(.top, AviationTheme.Spacing.md)
            .padding(.bottom, AviationTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.2), value: isKeyboardActive)
        }
        .navigationTitle("問題回報")
        .navigationBarTitleDisplayMode(isKeyboardActive ? .inline : .large)
        .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func submitReport() {
        guard !isSubmitting else { return }
        isSubmitting = true

        Task {
            do {
                try await IssueReportService.shared.submitReport(content: content, email: email)
                await MainActor.run {
                    isSubmitting = false
                    content = ""
                    alertTitle = "送出成功"
                    alertMessage = "已收到你的問題回報，謝謝你協助改善 Milery。"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertTitle = "送出失敗"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    NavigationStack {
        ReportIssueView()
    }
}
