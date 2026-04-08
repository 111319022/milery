import SwiftUI

struct AppLockSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private let lockService = AppLockService.shared
    
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("appLockBiometricEnabled") private var biometricEnabled = false
    
    @State private var showSetPasscodeSheet = false
    @State private var showChangePasscodeSheet = false
    @State private var showDisableConfirm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - 主開關
                VStack(spacing: 0) {
                    SettingToggleRow(
                        icon: "lock.fill",
                        title: "啟用 App 密碼鎖",
                        subtitle: "開啟後，每次啟動或從背景返回都需要解鎖",
                        isOn: Binding(
                            get: { appLockEnabled },
                            set: { newValue in
                                if newValue {
                                    showSetPasscodeSheet = true
                                } else {
                                    showDisableConfirm = true
                                }
                            }
                        )
                    )
                }
                .background(AviationTheme.Colors.cardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                
                // MARK: - 生物辨識 & 修改密碼（僅在開啟後顯示）
                if appLockEnabled {
                    VStack(spacing: 0) {
                        // 生物辨識
                        if lockService.isBiometricAvailable {
                            SettingToggleRow(
                                icon: biometricIconName,
                                title: "使用 \(lockService.biometricTypeName)",
                                subtitle: "驗證通過後可跳過密碼輸入",
                                isOn: $biometricEnabled
                            )
                            
                            CustomDivider(colorScheme: colorScheme)
                        }
                        
                        // 修改密碼
                        Button {
                            showChangePasscodeSheet = true
                        } label: {
                            SettingRow(
                                icon: "key.fill",
                                title: "修改密碼",
                                subtitle: nil
                            ) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .background(AviationTheme.Colors.cardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                    .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            .padding(.top, AviationTheme.Spacing.md)
        }
        .background(AviationTheme.Colors.background(colorScheme).ignoresSafeArea())
        .navigationTitle("App 密碼鎖")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSetPasscodeSheet) {
            PasscodeSetupSheet(mode: .create) { success in
                if success {
                    appLockEnabled = true
                }
                showSetPasscodeSheet = false
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showChangePasscodeSheet) {
            PasscodeSetupSheet(mode: .change) { success in
                showChangePasscodeSheet = false
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .alert("關閉密碼鎖", isPresented: $showDisableConfirm) {
            Button("取消", role: .cancel) { }
            Button("關閉", role: .destructive) {
                lockService.deletePasscode()
                biometricEnabled = false
                appLockEnabled = false
            }
        } message: {
            Text("關閉後將移除已設定的密碼")
        }
    }
    
    private var biometricIconName: String {
        switch lockService.biometricTypeName {
        case "Face ID": return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default: return "faceid"
        }
    }
}

// MARK: - 密碼設定 Sheet

struct PasscodeSetupSheet: View {
    enum Mode {
        case create
        case change
    }
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let mode: Mode
    let onComplete: (Bool) -> Void
    
    private let lockService = AppLockService.shared
    private let passcodeLength = 4
    
    enum Step {
        case verifyOld   // 修改密碼：先驗證舊密碼
        case enterNew    // 輸入新密碼
        case confirmNew  // 確認新密碼
    }
    
    @State private var currentStep: Step
    @State private var enteredPasscode = ""
    @State private var firstPasscode = ""
    @State private var isError = false
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0
    
    init(mode: Mode, onComplete: @escaping (Bool) -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        _currentStep = State(initialValue: mode == .change ? .verifyOld : .enterNew)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AviationTheme.Colors.background(colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // 標題
                    Image(systemName: stepIcon)
                        .font(.system(size: 36))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    
                    Text(stepTitle)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    // 密碼圓點
                    HStack(spacing: 20) {
                        ForEach(0..<passcodeLength, id: \.self) { index in
                            Circle()
                                .fill(index < enteredPasscode.count
                                      ? AviationTheme.Colors.cathayJade
                                      : AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                    .offset(x: shakeOffset)
                    .padding(.vertical, 8)
                    
                    if isError {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(AviationTheme.Colors.danger)
                    }
                    
                    Spacer()
                    
                    // 數字鍵盤
                    passcodeNumberPad
                    
                    Spacer()
                        .frame(height: 24)
                }
                .padding(.horizontal, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onComplete(false)
                    }
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
        }
    }
    
    // MARK: - Step Properties
    
    private var stepTitle: String {
        switch currentStep {
        case .verifyOld: return "輸入目前的密碼"
        case .enterNew: return "設定新密碼"
        case .confirmNew: return "再次輸入以確認"
        }
    }
    
    private var stepIcon: String {
        switch currentStep {
        case .verifyOld: return "lock.fill"
        case .enterNew: return "lock.badge.plus"
        case .confirmNew: return "lock.rotation"
        }
    }
    
    // MARK: - Number Pad
    
    private var numberRows: [[String]] {
        [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "delete"]
        ]
    }
    
    private var passcodeNumberPad: some View {
        VStack(spacing: 16) {
            ForEach(numberRows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        setupNumberKey(key)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func setupNumberKey(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear
                .frame(width: 72, height: 72)
        } else if key == "delete" {
            Button {
                if !enteredPasscode.isEmpty {
                    enteredPasscode.removeLast()
                    isError = false
                }
            } label: {
                Image(systemName: "delete.backward.fill")
                    .font(.title2)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    .frame(width: 72, height: 72)
            }
        } else {
            Button {
                guard enteredPasscode.count < passcodeLength else { return }
                enteredPasscode += key
                isError = false
                
                if enteredPasscode.count == passcodeLength {
                    handlePasscodeComplete()
                }
            } label: {
                Text(key)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(AviationTheme.Colors.cardBackground(colorScheme))
                            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            }
        }
    }
    
    // MARK: - Logic
    
    private func handlePasscodeComplete() {
        switch currentStep {
        case .verifyOld:
            if lockService.verifyPasscode(enteredPasscode) {
                enteredPasscode = ""
                currentStep = .enterNew
            } else {
                showError("密碼錯誤")
            }
            
        case .enterNew:
            firstPasscode = enteredPasscode
            enteredPasscode = ""
            currentStep = .confirmNew
            
        case .confirmNew:
            if enteredPasscode == firstPasscode {
                let saved = lockService.setPasscode(enteredPasscode)
                if saved {
                    onComplete(true)
                } else {
                    showError("儲存失敗，請重試")
                }
            } else {
                showError("密碼不一致，請重新設定")
                firstPasscode = ""
                enteredPasscode = ""
                currentStep = .enterNew
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        isError = true
        enteredPasscode = ""
        
        withAnimation(.default) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = -10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default) { shakeOffset = -5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}
