import DeviceActivity
import ManagedSettings
import FamilyControls

final class FocusDeviceActivityMonitor: DeviceActivityMonitor {
    private let storeName = "FocusStore"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == .focusSession else { return }
        guard let session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey),
              session.status == .running else {
            return
        }

        applyShield(for: session)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity == .focusSession else { return }

        clearShield()

        guard var session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey) else {
            return
        }

        session.status = .completed
        SharedDefaults.save(session, forKey: SharedDefaults.lastSessionKey)
        SharedDefaults.remove(forKey: SharedDefaults.activeSessionKey)
        SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == .focusSession, event == .temporaryUnlock else { return }

        guard let session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey),
              session.status == .running else {
            return
        }

        SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
        applyShield(for: session)
    }

    private func applyShield(for session: FocusSession) {
        let store = ManagedSettingsStore(named: .init(storeName))
        store.shield.applications = nil
        store.shield.applicationCategories = .all(
            except: SharedDefaults.allowedApplicationTokens(for: session)
        )
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    private func clearShield() {
        let store = ManagedSettingsStore(named: .init(storeName))
        store.clearAllSettings()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
