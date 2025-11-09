//
//  RootView.swift
//  Forma
//
//  Purpose:
//  - Hosts the main TabView with five sections.
//
//  Created by Forma.
//

import SwiftUI

enum Tab: Hashable {
    case today, calendar, focus, notes, review
}

struct RootView: View {
    @State private var selected: Tab = .today

    var body: some View {
        TabView(selection: $selected) {
            TodayView()
                .tag(Tab.today)
                .tabItem { Label("Today", systemImage: "sun.max") }

            CalendarView()
                .tag(Tab.calendar)
                .tabItem { Label("Calendar", systemImage: "calendar") }

            FocusView()
                .tag(Tab.focus)
                .tabItem { Label("Focus", systemImage: "timer") }

            NotesView()
                .tag(Tab.notes)
                .tabItem { Label("Notes", systemImage: "note.text") }

            ReviewView()
                .tag(Tab.review)
                .tabItem { Label("Review", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
