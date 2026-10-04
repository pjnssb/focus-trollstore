import Foundation
import FamilyControls

enum FocusSessionStatus: String, Codable {
    case running
    case completed
    case abandoned
}

struct FocusSession: Codable, Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let whitelist: FamilyActivitySelection
    var status: FocusSessionStatus

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        whitelist: FamilyActivitySelection,
        status: FocusSessionStatus = .running
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.whitelist = whitelist
        self.status = status
    }

    var remaining: TimeInterval {
        max(0, endDate.timeIntervalSinceNow)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(startDate)
        return min(max(elapsed / duration, 0), 1)
    }
}
