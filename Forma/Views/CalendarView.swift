//
//  CalendarView.swift
//  Forma
//
//  Reconstructed to ensure:
//  - Jump to TODAY whenever switching in from another tab.
//  - Do NOTHING when Calendar tab is tapped again while already visible.
//  - Stable, fixed month window (−40…+40) to avoid random jumps.
//

import SwiftUI

// Notification for TabView reselection of the Calendar tab
private extension Notification.Name {
    static let calendarTabReselected = Notification.Name("CalendarTabReselected")
}

// =====================================================
// MARK: - Helpers (Dates, IDs, Weekday Symbols)
// =====================================================

private func startOfMonth(for date: Date) -> Date {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month], from: date)
    return cal.date(from: comps) ?? date
}

private func monthTitle(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = .current
    f.setLocalizedDateFormatFromTemplate("yMMMM") // e.g. “November 2025”
    return f.string(from: d)
}

private var weekdaysShort: [String] {
    let f = DateFormatter()
    f.locale = .current
    return f.shortWeekdaySymbols
}

private func calendarMonthID(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = .current
    f.dateFormat = "yyyy-MM"
    return f.string(from: date)
}

private func todayMonthID() -> String {
    calendarMonthID(startOfMonth(for: Date()))
}

// Track month positions while scrolling so we can update the header month label
private struct MonthPos: Equatable, Identifiable {
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

// =====================================================
// MARK: - CalendarView (stable + predictable)
// =====================================================

struct CalendarView: View {

    // Fixed window around today for stability
    @State private var months: [Int] = Array((-40)...40)

    // Selection + header month label
    @State private var selectedDate: Date = Date()
    @State private var currentHeaderMonth: Date = startOfMonth(for: Date())

    // Persist the last visible month id across scene recreations
    @SceneStorage("calendar.lastVisibleMonthID")
    private var persistedMonthID: String = todayMonthID()

    // Add Mode & Add Sheet state
    @State private var isAddMode: Bool = false
    @State private var showingAdd: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftWhen: Date = Calendar.current.startOfDay(for: Date())
    // Prevent the button tap from firing immediately after a long-press
    @State private var suppressNextTap: Bool = false

    var body: some View {
        
        ScrollViewReader { proxy in
            VStack(spacing: 0) {

                // ---------- Header (matches Today’s capsule) ----------
                HStack(alignment: .firstTextBaseline) {
                    Text("Calendar")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        jumpToToday(proxy)
                    } label: {
                        Text("Today")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minWidth: 72)
                    }
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .contentShape(Capsule())
                    .buttonStyle(.plain)

                    // Add (+) button — tap: open sheet; long-press: enter Add Mode; tap while active = Cancel
                    Button {
                        // If we just long-pressed, ignore the release-triggered tap once
                        if suppressNextTap {
                            suppressNextTap = false
                            return
                        }
                        if isAddMode {
                            // Tap while in Add Mode → Cancel
                            #if os(iOS)
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            #endif
                            withAnimation(.easeOut(duration: 0.2)) { isAddMode = false }
                        } else {
                            // Tap → open sheet, prefill with selected or today
                            draftWhen = Calendar.current.startOfDay(for: selectedDate)
                            draftTitle = ""
                            showingAdd = true
                        }
                    } label: {
                        Image(systemName: isAddMode ? "xmark" : "plus")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minWidth: 44)
                            .animation(.easeOut(duration: 0.15), value: isAddMode)
                            .accessibilityLabel(isAddMode ? "Cancel add" : "Add task")
                            .accessibilityHint(isAddMode ? "Exit add mode" : "Tap to add. Long-press to choose a date from the calendar.")
                    }
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .contentShape(Capsule())
                    .buttonStyle(.plain)
                    .tint(isAddMode ? .accentColor : .primary)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            // Long-press → enter Add Mode (stays active until canceled)
                            #if os(iOS)
                            let gen = UIImpactFeedbackGenerator(style: .soft)
                            gen.impactOccurred()
                            #endif
                            if !isAddMode {
                                withAnimation(.easeOut(duration: 0.2)) { isAddMode = true }
                            }
                            // Suppress the immediate tap that fires on touch-up after long-press
                            suppressNextTap = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider().opacity(0.08)

                // ---------- Subheader (Month + Year) ----------
                Text(monthTitle(currentHeaderMonth))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // ---------- Weekday Strip ----------
                HStack {
                    ForEach(weekdaysShort, id: \.self) { w in
                        Text(w.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // ---------- Month Grids ----------
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(months, id: \.self) { offset in
                            let monthAnchor = startOfMonth(
                                for: Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
                            )

                            CalendarMonthGridSection(
                                monthAnchor: monthAnchor,
                                selected: $selectedDate,
                                onDayTapped: { date in
                                    if isAddMode {
                                        // In Add Mode → pick date and open sheet
                                        draftWhen = Calendar.current.startOfDay(for: date)
                                        showingAdd = true
                                        isAddMode = false
                                    } else {
                                        // Normal behavior → select date
                                        selectedDate = date
                                    }
                                }
                            )
                                .id(calendarMonthID(monthAnchor))
                                .padding(.horizontal, 20)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: MonthPosKey.self,
                                            value: [MonthPos(
                                                id: calendarMonthID(monthAnchor),
                                                y: geo.frame(in: .named("calScroll")).minY,
                                                date: monthAnchor
                                            )]
                                        )
                                    }
                                )
                        }
                    }
                }
                .coordinateSpace(name: "calScroll")
                .onPreferenceChange(MonthPosKey.self) { positions in
                    guard !positions.isEmpty else { return }
                    // Use the month whose top is closest to the top of the scroll area
                    let sorted = positions.sorted { a, b in
                        if a.y >= 0, b.y >= 0 { return a.y < b.y }
                        return abs(a.y) < abs(b.y)
                    }
                    if let first = sorted.first {
                        currentHeaderMonth = first.date
                        persistedMonthID = calendarMonthID(first.date)
                    }
                }
                .onAppear {
                    // Coming back from another tab: always jump to TODAY
                    jumpToToday(proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .calendarTabReselected)) { _ in
                    // Already on Calendar and tab is tapped again → do nothing.
                    // If anything tried to move us, restore to persisted month without animation.
                    proxy.scrollTo(persistedMonthID, anchor: .top)
                }
                .overlay(alignment: .top) {
                    if isAddMode {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text("Tap a date to add")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 3)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isAddMode)
                    }
                }
                .overlay {
                    if isAddMode {
                        Color.black.opacity(0.04)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .onTapGesture {
                    // Tap outside → exit Add Mode
                    if isAddMode { isAddMode = false }
                }
                .sheet(isPresented: $showingAdd) {
                    AddQuickSheet(title: $draftTitle, when: $draftWhen) {
                        // TODO: hook into Today’s data store. For now, dismiss only.
                        showingAdd = false
                    } onCancel: {
                        showingAdd = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func jumpToToday(_ proxy: ScrollViewProxy) {
        let id = todayMonthID()
        withAnimation(.easeOut(duration: 0.35)) {
            proxy.scrollTo(id, anchor: .top)
        }
        selectedDate = Date()
        persistedMonthID = id
    }
}

// =====================================================
// MARK: - Month Grid (One Month)
// =====================================================

private struct CalendarMonthGridSection: View {
    let monthAnchor: Date
    @Binding var selected: Date
    var onDayTapped: (Date) -> Void

    private var days: [Date] {
        let cal = Calendar.current
        let dayRange = cal.range(of: .day, in: .month, for: monthAnchor) ?? (1..<32)
        return dayRange.compactMap { day in
            cal.date(byAdding: .day, value: day - 1, to: monthAnchor)
        }
    }

    private var leadingBlanks: Int {
        let cal = Calendar.current
        let firstWeekday = cal.component(.weekday, from: monthAnchor)
        return (firstWeekday - cal.firstWeekday + 7) % 7
    }

    private var totalCells: Int { leadingBlanks + days.count }
    private var rows: Int { Int(ceil(Double(totalCells) / 7.0)) }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < leadingBlanks {
                            EmptyCell()
                        } else {
                            let dayIndex = idx - leadingBlanks
                            if dayIndex < days.count {
                                DayCard(date: days[dayIndex], selected: $selected) {
                                    onDayTapped(days[dayIndex])
                                }
                            } else {
                                EmptyCell()
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func EmptyCell() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.clear)
            .frame(height: 64)
            .frame(maxWidth: .infinity)
    }
}

// =====================================================
// MARK: - Day Card
// =====================================================

private struct DayCard: View {
    let date: Date
    @Binding var selected: Date
    var onTap: () -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isSelected: Bool { Calendar.current.isDate(date, inSameDayAs: selected) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(baseBackground)

                // Border highlight
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selectionStroke, lineWidth: isSelected ? 2.5 : (isToday ? 1.5 : 0))
                    .opacity((isSelected || isToday) ? 1 : 0)

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.primary : (isToday ? Color.blue : Color.secondary))
            }
            .frame(height: 64)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private var baseBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.25) }
        if isToday { return Color.blue.opacity(0.15) }
        return Color.secondary.opacity(0.08)
    }

    private var selectionStroke: Color {
        if isSelected { return .accentColor }
        if isToday { return .blue }
        return .clear
    }
}

// =====================================================
// MARK: - AddQuickSheet (lightweight add from Calendar)
// =====================================================

private struct AddQuickSheet: View {
    @Binding var title: String
    @Binding var when: Date
    var onSave: () -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Task title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Date") {
                    DatePicker("When", selection: $when, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onSave(); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
