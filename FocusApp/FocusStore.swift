import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

final class FocusStore: ObservableObject {
    private enum StorageKey {
        static let durationMinutes = "focus.durationMinutes"
        static let lastPresentedSessionID = "focus.lastPresentedSessionID"
    }

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    @Published var selection = FamilyActivitySelection() {
        didSet {
            SharedDefaults.save(selection, forKey: SharedDefaults.whitelistKey)
        }
    }

    @Published var durationMinutes: Int = 25 {
        didSet {
            UserDefaults.standard.set(durationMinutes, forKey: StorageKey.durationMinutes)
        }
    }

    @Published private(set) var activeSession: FocusSession?
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?
    @Published var completedSession: FocusSession?

    private let managedSettingsStore = ManagedSettingsStore(named: .init("FocusStore"))
    private let activityCenter = DeviceActivityCenter()
    private var timer: Timer?

    init() {
        let savedDuration = UserDefaults.standard.integer(forKey: StorageKey.durationMinutes)
        if savedDuration >= 1 {
            durationMinutes = savedDuration
        }

        if let savedSelection = SharedDefaults.load(FamilyActivitySelection.self, forKey: SharedDefaults.whitelistKey) {
            selection = savedSelection
        }

        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        restoreSession()
    }

    var canStart: Bool {
        authorizationStatus == .approved
    }

    var appGroupAvailable: Bool {
        SharedDefaults.isAvailable()
    }

    var whitelistCount: Int {
        selection.applicationTokens.count
    }

    var formattedRemaining: String {
        let totalSeconds = max(0, Int(ceil(remaining)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard let session = activeSession, session.duration > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(session.startDate)
        return min(max(elapsed / session.duration, 0), 1)
    }

    var authorizationStatusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未授权"
        case .denied:
            return "已拒绝"
        case .approved:
            return "已授权"
        @unknown default:
            return "未知"
        }
    }

    func requestAuthorizationIfNeeded() async {
        refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                self.refreshAuthorizationStatus()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Screen Time 授权失败：\(error.localizedDescription)"
                self.refreshAuthorizationStatus()
            }
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func startSession() {
        guard !isRunning else { return }

        guard canStart else {
            errorMessage = "请先授权 Screen Time 访问权限。"
            return
        }

        guard durationMinutes >= 1 else {
            errorMessage = "专注时长至少需要 1 分钟。"
            return
        }

        guard appGroupAvailable else {
            errorMessage = "App Group 不可用，无法在 App 与扩展之间共享状态。请检查 entitlements。"
            return
        }

        let duration = TimeInterval(durationMinutes * 60)
        let now = Date()
        let session = FocusSession(
            startDate: now,
            endDate: now.addingTimeInterval(duration),
            duration: duration,
            whitelist: selection,
            status: .running
        )

        SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
        SharedDefaults.save(session, forKey: SharedDefaults.activeSessionKey)

        do {
            try startMonitoring(for: session)
        } catch {
            SharedDefaults.remove(forKey: SharedDefaults.activeSessionKey)
            errorMessage = "无法启动设备活动监控：\(error.localizedDescription)"
            return
        }

        applyShield(for: session)
        activeSession = session
        remaining = duration
        isRunning = true
        completedSession = nil
        scheduleTimer()
    }

    func abandonSession() {
        guard var session = activeSession else { return }
        session.status = .abandoned
        finish(session: session)
    }

    func dismissCompletion() {
        if let id = completedSession?.id {
            UserDefaults.standard.set(id.uuidString, forKey: StorageKey.lastPresentedSessionID)
        }
        completedSession = nil
    }

    func refreshFromScene() {
        refreshAuthorizationStatus()

        if authorizationStatus != .approved && isRunning, let session = activeSession {
            var abandoned = session
            abandoned.status = .abandoned
            finish(session: abandoned)
            completedSession = nil
            errorMessage = "Screen Time 授权已失效，专注已结束。"
            return
        }

        if let sharedSession = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey) {
            activeSession = sharedSession
        } else if activeSession != nil {
            activeSession = nil
            isRunning = false
            remaining = 0
            stopTimer()
            clearShield()
        }

        let presentedID = UserDefaults.standard.string(forKey: StorageKey.lastPresentedSessionID)
        if let lastSession = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.lastSessionKey),
           lastSession.status == .completed,
           completedSession == nil,
           lastSession.id.uuidString != presentedID {
            completedSession = lastSession
        }

        guard let session = activeSession else { return }

        if session.endDate <= Date() {
            var finished = session
            finished.status = .completed
            finish(session: finished)
        } else {
            remaining = session.endDate.timeIntervalSinceNow
            isRunning = true
            applyShield(for: session)
            scheduleTimer()
        }
    }

    private func restoreSession() {
        guard let session = SharedDefaults.load(FocusSession.self, forKey: SharedDefaults.activeSessionKey) else {
            return
        }

        guard authorizationStatus == .approved else {
            var abandoned = session
            abandoned.status = .abandoned
            finish(session: abandoned)
            completedSession = nil
            errorMessage = "Screen Time 授权已失效，专注已结束。"
            return
        }

        if session.status == .running && session.endDate > Date() {
            activeSession = session
            isRunning = true
            remaining = session.remaining
            applyShield(for: session)

            do {
                try startMonitoring(for: session)
            } catch {
                errorMessage = "恢复专注失败：\(error.localizedDescription)"
            }

            scheduleTimer()
        } else {
            var finished = session
            finished.status = .completed
            finish(session: finished)
        }
    }

    private func startMonitoring(for session: FocusSession) throws {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: session.startDate)
        let monitoringEnd = calendar.date(byAdding: .hour, value: 24, to: session.startDate)
            ?? session.startDate.addingTimeInterval(24 * 60 * 60)
        let endComponents = calendar.dateComponents([.hour, .minute], from: monitoringEnd)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        activityCenter.stopMonitoring([.focusSession])

        do {
            try activityCenter.startMonitoring(.focusSession, during: schedule)
        } catch {
            // 某些系统版本不接受已经开始的时间段，退回到下一分钟开始。
            let nextMinute = calendar.date(byAdding: .minute, value: 1, to: session.startDate) ?? session.startDate
            let fallbackStart = calendar.dateComponents([.hour, .minute], from: nextMinute)
            let fallbackSchedule = DeviceActivitySchedule(
                intervalStart: fallbackStart,
                intervalEnd: endComponents,
                repeats: false
            )
            try activityCenter.startMonitoring(.focusSession, during: fallbackSchedule)
        }
    }

    private func applyShield(for session: FocusSession) {
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .all(
            except: SharedDefaults.allowedApplicationTokens(for: session)
        )
        managedSettingsStore.shield.webDomains = nil
        managedSettingsStore.shield.webDomainCategories = nil
    }

    private func clearShield() {
        managedSettingsStore.clearAllSettings()
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = nil
        managedSettingsStore.shield.webDomains = nil
        managedSettingsStore.shield.webDomainCategories = nil
    }

    private func finish(session: FocusSession) {
        clearShield()
        activityCenter.stopMonitoring([.focusSession])
        stopTimer()
        isRunning = false
        activeSession = nil
        remaining = 0
        SharedDefaults.save(session, forKey: SharedDefaults.lastSessionKey)
        SharedDefaults.remove(forKey: SharedDefaults.activeSessionKey)
        SharedDefaults.remove(forKey: SharedDefaults.temporaryUnlockKey)
        completedSession = session
    }

    private func scheduleTimer() {
        stopTimer()

        let newTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let session = activeSession else { return }

        let newRemaining = session.endDate.timeIntervalSinceNow
        if newRemaining <= 0 {
            var finished = session
            finished.status = .completed
            finish(session: finished)
        } else {
            remaining = newRemaining
        }
    }
}
