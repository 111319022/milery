import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Environment(\.colorScheme) var colorScheme
    let onUnlock: () -> Void
    
    @State private var enteredPasscode = ""
    @State private var isError = false
    @State private var shakeOffset: CGFloat = 0
    @State private var attempts = 0
    
    private let lockService = AppLockService.shared
    private let passcodeLength = 4
    
    var body: some View {
        ZStack {
            // 背景
            AviationTheme.Colors.background(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 鎖頭圖示
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .padding(.bottom, 8)
                
                Text("輸入密碼以解鎖")
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
                    Text("密碼錯誤，請重試")
                        .font(.subheadline)
                        .foregroundColor(AviationTheme.Colors.danger)
                }
                
                Spacer()
                
                // 數字鍵盤
                numberPad
                
                // Face ID / Touch ID 按鈕
                if lockService.isBiometricEnabled && lockService.isBiometricAvailable {
                    Button {
                        triggerBiometric()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: biometricIconName)
                                .font(.title3)
                            Text("使用 \(lockService.biometricTypeName)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                    .frame(height: 24)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            if lockService.isBiometricEnabled && lockService.isBiometricAvailable {
                triggerBiometric()
            }
        }
    }
    
    // MARK: - Biometric Icon
    
    private var biometricIconName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "faceid"
        }
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "faceid"
        @unknown default: return "faceid"
        }
    }
    
    // MARK: - Number Pad
    
    private var numberPad: some View {
        VStack(spacing: 16) {
            ForEach(numberRows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        numberKey(key)
                    }
                }
            }
        }
    }
    
    private var numberRows: [[String]] {
        [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "delete"]
        ]
    }
    
    @ViewBuilder
    private func numberKey(_ key: String) -> some View {
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
                    validatePasscode()
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
    
    // MARK: - Validation
    
    private func validatePasscode() {
        if lockService.verifyPasscode(enteredPasscode) {
            onUnlock()
        } else {
            attempts += 1
            isError = true
            enteredPasscode = ""
            
            // 搖晃動畫
            withAnimation(.default) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) {
                    shakeOffset = -10
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.default) {
                    shakeOffset = 8
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.default) {
                    shakeOffset = -5
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.default) {
                    shakeOffset = 0
                }
            }
        }
    }
    
    // MARK: - Biometric
    
    private func triggerBiometric() {
        Task {
            let success = await lockService.authenticateWithBiometrics()
            if success {
                onUnlock()
            }
        }
    }
}
