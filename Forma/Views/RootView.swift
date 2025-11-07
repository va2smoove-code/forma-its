import SwiftUI

enum Tab: Hashable { case today, calendar, focus, notes, review }

struct RootView: View {
    @State private var selected: Tab = .today

    var body: some View {
        TabView(selection: $selected) {
            Text("Today")
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            Text("Calendar")
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(Tab.calendar)

            Text("Focus")
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
