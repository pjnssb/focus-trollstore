import Foundation
import ManagedSettings

enum SharedDefaults {
    static let appGroupID = "group.com.example.Focus"
    static let activeSessionKey = "focus.activeSession"
    static let lastSessionKey = "focus.lastSession"
    static let whitelistKey = "focus.whitelist"
    static let temporaryUnlockKey = "focus.temporaryUnlock"
    static let lastShieldedApplicationTokenKey = "focus.lastShieldedApplicationToken"
    static let focusBundleIdentifier = "com.example.Focus"
    static let trollStoreBundleIdentifiers = [
        "com.opa334.TrollStore",
        "com.opa334.TrollStoreLite"
    ]

    static var store: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let store, let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: key)
    }

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let store, let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func remove(forKey key: String) {
        store?.removeObject(forKey: key)
    }

    static func isAvailable() -> Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static func applicationToken(for bundleIdentifier: String) -> ApplicationToken? {
        Application(bundleIdentifier: bundleIdentifier).token
    }

    static func allowedApplicationTokens(for session: FocusSession) -> Set<ApplicationToken> {
        var tokens = session.whitelist.applicationTokens

        let alwaysAllowedBundleIdentifiers = [focusBundleIdentifier] + trollStoreBundleIdentifiers
        for bundleIdentifier in alwaysAllowedBundleIdentifiers {
            if let token = applicationToken(for: bundleIdentifier) {
                tokens.insert(token)
            }
        }

        if let temporaryUnlock = load(TemporaryUnlock.self, forKey: temporaryUnlockKey) {
            tokens.insert(temporaryUnlock.applicationToken)
        }

        return tokens
    }
}
