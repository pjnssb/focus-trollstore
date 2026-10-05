import Foundation
import FamilyControls

struct TemporaryUnlock: Codable, Equatable {
    let applicationToken: ApplicationToken
    let startedAt: Date
}
