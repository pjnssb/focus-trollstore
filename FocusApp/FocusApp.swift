import SwiftUI

@main
struct FocusApp: App {
    @StateObject private var store = FocusStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
