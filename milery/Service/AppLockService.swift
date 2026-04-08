import Foundation
import Security
import LocalAuthentication

@MainActor
@Observable
final class AppLockService {
    static let shared = AppLockService()
    
    private let keychainKey = "com.73app.milery.appLockPasscode"
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockEnabled") }
    }
    
    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockBiometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockBiometricEnabled") }
    }
    
    private init() {}
    
    // MARK: - Biometric Info
    
    /// 裝置支援的生物辨識類型名稱
    var biometricTypeName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "生物辨識"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "生物辨識"
        @unknown default: return "生物辨識"
        }
    }
    
    /// 裝置是否支援生物辨識
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Passcode (Keychain)
    
    /// 儲存密碼到 Keychain
    func setPasscode(_ passcode: String) -> Bool {
        deletePasscode()
        
        guard let data = passcode.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// 驗證密碼
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let stored = getPasscode() else { return false }
        return stored == passcode
    }
    
    /// 是否已設定密碼
    var hasPasscode: Bool {
        getPasscode() != nil
    }
    
    /// 刪除密碼
    @discardableResult
    func deletePasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// 從 Keychain 讀取密碼
    private func getPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let passcode = String(data: data, encoding: .utf8) else {
            return nil
        }
        return passcode
    }
    
    // MARK: - Biometric Authentication
    
    /// 使用生物辨識驗證
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解鎖 Milery"
            )
            return success
        } catch {
            return false
        }
    }
}
