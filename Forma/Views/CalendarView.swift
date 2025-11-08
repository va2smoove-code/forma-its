import SwiftUI

// MARK: - Preference to track month section positions
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

private func isToday(_ d: Date) -> Bool {
    Calendar.current.isDateInToday(d)
}

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var headerMonth: Date = Date()   // <- month shown under title

    // “Infinite” window: 40 years (-20y … +20y)
    private let monthRange = (-240...240)

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {

                    // ── Header row: Title (L) + Today (R)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Calendar")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Today") {
                            let current = startOfMonth(for: Date())
                            withAnimation(.spring()) {
                                proxy.scrollTo(monthID(current), anchor: .top)
                                selectedDate = Date()
                                headerMonth = current
                            }
                        }
                        .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // ── Month + Year (auto-updates with scroll)
                    Text(monthTitle(headerMonth))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .padding(.bottom, 6)

                    // ── Static weekday strip (end-to-end)
                    WeekdayStrip()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)

                    Divider().opacity(0.08)

                    // ── Scrollable month stack (track which month is near the top)
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(monthRange, id: \.self) { offset in
                                let monthAnchor = startOfMonth(for: addMonths(to: Date(), offset))
                                MonthGridSection(
                                    monthAnchor: monthAnchor,
                                    selected: $selectedDate
                                )
                                .id(monthID(monthAnchor))
                                .padding(.horizontal, 20)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: MonthPosKey.self,
                                                value: [
                                                    MonthPos(
                                                        id: monthID(monthAnchor),
                                                        y: geo.frame(in: .named("calScroll")).minY,
                                                        date: monthAnchor
                                                    )
                                                ]
                                            )
                                    }
                                )
                            }
                            Spacer(minLength: 64)
                        }
                    }
                    .coordinateSpace(name: "calScroll")
                    .onPreferenceChange(MonthPosKey.self) { positions in
                        // Pick the month whose top is closest to the top of the scroll area
                        guard let closest = positions.min(by: { abs($0.y) < abs($1.y) }) else { return }
                        if abs(closest.y - 0) < 500 {   // simple sanity band to avoid jumps at extremes
                            headerMonth = closest.date
                        }
                    }
                    .onAppear {
                        let current = startOfMonth(for: Date())
                        proxy.scrollTo(monthID(current), anchor: .top)
                        headerMonth = current
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
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

// ── Static weekday strip
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

// ── One month block (no month header inside)
// MARK: - One month block, aligned to weekday strip
// MARK: - One month block, aligned to weekday strip
private struct MonthGridSection: View {
    let monthAnchor: Date
    @Binding var selected: Date

    private var cal: Calendar { Calendar.current }

    // 7 flexible columns
    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: 7) }

    // Build cells with leading/trailing empties so weeks align
    private var cells: [Cell] {
        // Days in month
        let range = cal.range(of: .day, in: .month, for: monthAnchor) ?? 1..<31
        let dayCount = range.count

        // Weekday of the 1st (1=Sun … 7=Sat in Gregorian), adjusted for locale firstWeekday
        var comps = cal.dateComponents([.year, .month], from: monthAnchor)
        comps.day = 1
        let firstOfMonth = cal.date(from: comps) ?? monthAnchor

        let firstWeekday = cal.firstWeekday                       // locale-dependent start
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        // number of leading blanks before day 1
        var leading = (weekdayOfFirst - firstWeekday)
        if leading < 0 { leading += 7 }

        // Real day dates
        let days: [Date] = (0..<dayCount).compactMap { i in
            cal.date(byAdding: .day, value: i, to: firstOfMonth)
        }

        // trailing blanks to complete last week
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
                    EmptyCell()
                case .day(let d):
                    DayCell(
                        day: d,
                        monthAnchor: monthAnchor,
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

    private enum Cell: Equatable {
        case empty
        case day(Date)
    }
}

// Simple blank to hold grid spacing where there’s no day
private struct EmptyCell: View {
    var body: some View {
        Color.clear
            .frame(height: 60)
            .frame(maxWidth: .infinity)
    }
}



// ── Day cell
private struct DayCell: View {
    let day: Date
    let monthAnchor: Date
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.22))
            }
            // Today ring (even when not selected)
            RoundedRectangle(cornerRadius: 14)
                .stroke(isToday(day) ? Color.accentColor.opacity(0.8) : .clear, lineWidth: 2)
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
