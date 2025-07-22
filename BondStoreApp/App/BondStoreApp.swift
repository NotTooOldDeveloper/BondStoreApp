import SwiftUI
import SwiftData

@main
struct BondStoreApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dataCoordinator = DataCoordinator()

    var body: some Scene {
        WindowGroup {
            MonthSelectorView()
                .environmentObject(appState)
                .environmentObject(dataCoordinator)
                // This .id() modifier is CRITICAL. It forces the entire UI
                // to be destroyed and recreated when the container changes,
                // ensuring all views get the new, restored data.
                .id(ObjectIdentifier(dataCoordinator.modelContainer))
        }
        .modelContainer(dataCoordinator.modelContainer)
    }
}
