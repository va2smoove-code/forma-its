import SwiftUI

// MARK: - Month Grid Section
struct MonthGridSection: View {
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
                    EmptyCell()
                case .day(let d):
                    DayCell(day: d, isSelected: cal.isDate(d, inSameDayAs: selected))
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

// MARK: - Grid Placeholders
private struct EmptyCell: View {
    var body: some View {
        Color.clear
            .frame(height: 72)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Cell (even, balanced card)
private struct DayCell: View {
    let day: Date
    let isSelected: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.20)
                      : Color.secondary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.5)
                                           : Color.white.opacity(0.05),
                                lineWidth: 1)
                )

            // Content (perfectly centered layout)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(dayNumber(day))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                Spacer()
            }

            // Today indicator (small dot bottom-center)
            if isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .padding(.bottom, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: 46, height: 72)  // ← consistent sizing for even grid
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dayNumber(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d")
        return f.string(from: d)
    }
}
