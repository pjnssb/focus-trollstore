import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        if action == .primaryButtonPressed {
            handleTemporaryUnlock(for: application)
        }
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        if action == .primaryButtonPressed,
           let token = ShieldTokenStore.load() {
            handleTemporaryUnlock(for: token)
        }
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
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

        let calendar = Calendar.current
        let now = Date()
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: calendar.startOfDay(for: now)
        )
        let monitoringEnd = calendar.date(byAdding: .hour, value: 24, to: now)
            ?? now.addingTimeInterval(24 * 60 * 60)
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: monitoringEnd
        )

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
        }
    }
}
