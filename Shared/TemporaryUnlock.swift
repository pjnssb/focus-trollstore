import Foundation
import FamilyControls
import ManagedSettings

struct TemporaryUnlock: Codable, Equatable {
    let applicationToken: ApplicationToken
    let startedAt: Date
}
