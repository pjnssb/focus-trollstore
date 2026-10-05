import Foundation
import FamilyControls
import ManagedSettings

enum ShieldTokenStore {
    static let appGroupID = "group.com.example.Focus"
    static let lastShieldedApplicationTokenKey = "focus.lastShieldedApplicationToken"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ token: ApplicationToken) {
        guard let store, let data = try? JSONEncoder().encode(token) else { return }
        store.set(data, forKey: lastShieldedApplicationTokenKey)
    }

    static func load() -> ApplicationToken? {
        guard let store, let data = store.data(forKey: lastShieldedApplicationTokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }
}
