//
//  CalendarView.swift
//  Forma
//
//  Purpose:
//  - Infinite month scroller with weekday strip.
//  - Large title matches Today view.
//
//  Created by Forma.
//

import SwiftUI

// MARK: - Month position tracking (for header month if needed later)

private struct MonthPos: Equatable {
    let id: String
    let y: CGFloat
    let date: Date
}

private struct MonthPosKey: PreferenceKey {
    static var defaultValue: [MonthPos] = []
    static func reduce(value: inout [MonthPos], nextValue: () -> [MonthPos]) {
        value.append(contentsOf: nextValue())
    }
}

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var headerMonth: Date = Date()

    private let monthRange = (-240...240) // ~20y before/after

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month+Year label (optional—kept to match prior layout)
                Text(monthTitle(headerMonth))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .padding(.bottom, 6)

                WeekdayStrip()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                Divider().opacity(0.08)

                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(monthRange, id: \.self) { offset in
                            let monthAnchor = startOfMonth(for: addMonths(to: Date(), offset))
                            MonthGridSection(monthAnchor: monthAnchor, selected: $selectedDate)
                                .id(monthID(monthAnchor))
                                .padding(.horizontal, 20)
                        }
                        Spacer(minLength: 64)
                    }
                }
            }
            .navigationTitle("Calendar")  // Large title like Today
        }
    }

    // MARK: - Helpers
    private func addMonths(to base: Date, _ offset: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: base) ?? base
    }
    private func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
    private func monthID(_ d: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: d)
        return "m-\(comps.year ?? 0)-\(comps.month ?? 0)"
    }
    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f.string(from: d)
    }
}

// MARK: - Weekday strip

private struct WeekdayStrip: View {
    private var cal: Calendar { Calendar.current }
    private var symbols: [String] {
        var s = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        if first > 0 { s = Array(s[first...] + s[..<first]) }
        return s
    }

    var body: some View {
        HStack {
            ForEach(symbols, id: \.self) { sym in
                Text(sym.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Month grid

private struct MonthGridSection: View {
    let monthAnchor: Date
    @Binding var selected: Date

    private var cal: Calendar { Calendar.current }
    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: 7) }

    private enum Cell: Equatable { case empty, day(Date) }

    private var cells: [Cell] {
        let range = cal.range(of: .day, in: .month, for: monthAnchor) ?? 1..<31
        let dayCount = range.count

        var comps = cal.dateComponents([.year, .month], from: monthAnchor)
        comps.day = 1
        let firstOfMonth = cal.date(from: comps) ?? monthAnchor

        let firstWeekday = cal.firstWeekday
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        var leading = (weekdayOfFirst - firstWeekday)
        if leading < 0 { leading += 7 }

        let days: [Date] = (0..<dayCount).compactMap { i in
            cal.date(byAdding: .day, value: i, to: firstOfMonth)
        }

        let filled = leading + dayCount
        let trailing = (7 - (filled % 7)) % 7

        return Array(repeating: .empty, count: leading)
            + days.map { .day($0) }
            + Array(repeating: .empty, count: trailing)
    }

    var body: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                switch cell {
                case .empty:
                    Color.clear
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                case .day(let d):
                    DayCell(
                        day: d,
                        isSelected: cal.isDate(d, inSameDayAs: selected)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selected = d
                        }
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Date
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.22)
                                 : Color.secondary.opacity(0.08))
                .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: 3, y: 2)

            Text(dayNumber(day))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }

    private func dayNumber(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d")
        return f.string(from: d)
    }
}
