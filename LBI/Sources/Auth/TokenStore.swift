import Foundation
import Security

/// Stores the session token issued by the backend after Sign in with Apple.
protocol TokenStore: Sendable {
    func currentToken() -> String?
    func save(token: String)
    func clear()
}

/// Keychain-backed implementation. The JWT returned by the backend is stored
/// securely and read by the auth interceptor on every authenticated request.
final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service: String
    private let account: String
    private let lock = NSLock()

    init(service: String = "dev.tuist.LBI.auth", account: String = "session-token") {
        self.service = service
        self.account = account
    }

    func currentToken() -> String? {
        lock.lock(); defer { lock.unlock() }
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(token: String) {
        lock.lock(); defer { lock.unlock() }
        let data = Data(token.utf8)
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        // Token must never leave this device (no iCloud/backup migration).
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// In-memory token store for previews and tests.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) { self.token = token }

    func currentToken() -> String? {
        lock.lock(); defer { lock.unlock() }
        return token
    }

    func save(token: String) {
        lock.lock(); defer { lock.unlock() }
        self.token = token
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        token = nil
    }
}
