import Foundation
import Security

/// Small Keychain wrapper for local-only secrets.
///
/// Drift has no account system. This store is used only for the optional
/// focus-session lock and for deleting credentials left by older cloud builds.
enum LocalCredentialStore {
    private static let service = "com.drift.app.local"
    private static let retiredCloudService = "net.drift.app"

    static let focusPasswordHashKey = "focus_password_hash"

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        delete(service: service, account: key)
    }

    /// Removes tokens created by the retired account/sync client.
    static func purgeRetiredCloudCredentials() {
        delete(service: retiredCloudService, account: "drift_access_token")
        delete(service: retiredCloudService, account: "drift_refresh_token")
    }

    private static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
