import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

final class ShieldActionExtension: ShieldActionDelegate {
    private let storeName = "FocusStore"

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handleTemporaryUnlock(for: application)
            completionHandler(.close)
        case .secondaryButtonPressed:
            endSession()
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        endSession()
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        endSession()
        completionHandler(.close)
    }

    private func handleTemporaryUnlock(for application: ApplicationToken) {
        guard let session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey),
              session.status == .running else {
            return
        }

        guard SharedDefaults.load(TemporaryUnlock.self, forKey: SharedDefaults.temporaryUnlockKey) == nil else {
            return
        }

        let temporaryUnlock = TemporaryUnlock(applicationToken: application, startedAt: Date())
        SharedDefaults.save(temporaryUnlock, forKey: SharedDefaults.temporaryUnlockKey)

        let store = ManagedSettingsStore(named: .init(storeName))
        store.shield.applicationCategories = .all(
            except: SharedDefaults.allowedApplicationTokens(for: session)
        )

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: session.startDate)
        let monitoringEnd = calendar.date(byAdding: .hour, value: 24, to: session.startDate)
            ?? session.startDate.addingTimeInterval(24 * 60 * 60)
        let endComponents = calendar.dateComponents([.hour, .minute], from: monitoringEnd)

        let activityCenter = DeviceActivityCenter()
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        let event = DeviceActivityEvent(
            applications: [application],
            threshold: DateComponents(minute: 5)
        )

        do {
            try activityCenter.startMonitoring(
                .focusSession,
                during: schedule,
                events: [.temporaryUnlock: event]
            )
        } catch {
            SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
            store.shield.applicationCategories = .all(
                except: session.whitelist.applicationTokens
            )
        }
    }

    private func endSession() {
        let store = ManagedSettingsStore(named: .init(storeName))
        store.clearAllSettings()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil

        DeviceActivityCenter().stopMonitoring([.focusSession])

        if var session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey) {
            session.status = .abandoned
            SharedDefaults.save(session, forKey: SharedDefaults.lastSessionKey)
        }

        SharedDefaults.remove(forKey: SharedDefaults.activeSessionKey)
        SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
    }
}
