import SwiftUI

@main
struct FormaApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var taskStore = TaskStore()   // <-- shared store

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(taskStore)          // <-- inject globally
        }
    }
}
