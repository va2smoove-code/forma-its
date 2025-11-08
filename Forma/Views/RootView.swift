import SwiftUI

struct RootView: View {
    @State private var selected: Tab = .today

    enum Tab: Hashable {
        case today, calendar, focus, notes, review
    }

    var body: some View {
        TabView(selection: $selected) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            CalendarView()   // <-- swap in the real view
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
