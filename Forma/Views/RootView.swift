import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            Text("Calendar")
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(Tab.calendar)

            FocusView()
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(Tab.focus)

            Text("Notes")
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(Tab.notes)

            Text("Review")
                .tabItem { Label("Review", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.review)
        }
    }
}
