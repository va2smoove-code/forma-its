//
//  TodayView.swift
//  Forma
//
//  Purpose:
//  - Daily task list with sorting, filters, add/edit sheets, search,
//    swipe actions, undo toast, recently-deleted, and manual reordering.
//  - Self-contained file: model + editor + row + filters + helpers.
//
//  Created by Forma.
//

import SwiftUI

// ┌────────────────────────────────────────────────────────────────────────────┐
// │ TODAY VIEW                                                                 │
 // └────────────────────────────────────────────────────────────────────────────┘
struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    // ──────────────────────────  MODEL (Local to Today)  ──────────────────────
    struct Task: Identifiable, Hashable, Codable {
        enum Importance: String, CaseIterable, Identifiable, Codable {
            case low = "Low", normal = "Normal", high = "High"
            var id: String { rawValue }
        }
        let id: UUID
        var title: String
        var isDone: Bool
        var notes: String
        var when: Date?
        var importance: Importance
        var tags: [String]

        init(
            id: UUID = UUID(),
            title: String,
            isDone: Bool = false,
            notes: String = "",
            when: Date? = nil,
            importance: Importance = .normal,
            tags: [String] = []
        ) {
            self.id = id
            self.title = title
            self.isDone = isDone
            self.notes = notes
            self.when = when
            self.importance = importance
            self.tags = tags
        }
    }

    struct SelectedTask: Identifiable { let index: Int; var id: Int { index } }

    // Recently Deleted entry (kept up to 7 days)
    struct DeletedEntry: Identifiable, Codable, Hashable {
        let id: UUID
        var task: Task
        var deletedAt: Date
        var originalIndex: Int
        init(id: UUID = UUID(), task: Task, deletedAt: Date = Date(), originalIndex: Int) {
            self.id = id
            self.task = task
            self.deletedAt = deletedAt
            self.originalIndex = originalIndex
        }
    }

    enum SortMode: String, CaseIterable { case manual = "Manual", date = "Date", importance = "Importance" }

    // ───────────────────────────────  STATE  ──────────────────────────────────
    @State private var items: [Task] = []
    @State private var selected: SelectedTask? = nil

    // Add sheet
    @State private var showingAdd = false
    @State private var draft = Task(title: "")

    // Sorting
    @State private var sortMode: SortMode = .manual
    @State private var isReordering: Bool = false

    // Filters
    @State private var filterImportance: Task.Importance? = nil
    @State private var filterTags = Set<String>()
    @State private var filterOverdue: Bool = false
    @State private var showingFilterSheet = false

    // Search
    @State private var searchText: String = ""

    // Delete flow
    @State private var pendingDeleteIndex: Int? = nil
    @State private var showDeleteDialog: Bool = false

    // Recently Deleted (Trash)
    @State private var recentlyDeleted: [DeletedEntry] = []
    @State private var showingTrash: Bool = false

    // Undo
    @State private var lastDeleted: (task: Task, index: Int)? = nil
    @State private var showUndoToast: Bool = false
    @State private var undoWorkItem: DispatchWorkItem? = nil

    // Misc
    @State private var hasLoaded = false
    @State private var expandedCompletedSections: Set<String> = []
    
    // SEARCH — inline expanding bar
    @State private var isSearchExpanded: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    // ───────────────────────────  DERIVED / HELPERS  ─────────────────────────
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var allTags: [String] {
        Array(
            Set(
                items.flatMap { $0.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                    .filter { !$0.isEmpty }
                    .map { $0.lowercased() }
            )
        ).sorted()
    }

    private func isOverdue(_ t: Task) -> Bool {
        guard !t.isDone, let when = t.when else { return false }
        return when < Date()
    }

    private func matchesSearch(_ t: Task) -> Bool {
        guard isSearching else { return true }
        let q = searchText.lowercased()
        if t.title.lowercased().contains(q) { return true }
        if t.notes.lowercased().contains(q) { return true }
        if t.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
        return false
    }

    private var displayedIndices: [Int] {
        items.indices.filter { i in
            let t = items[i]
            if let f = filterImportance, t.importance != f { return false }
            if !filterTags.isEmpty {
                let set = Set(t.tags.map { $0.lowercased() })
                if set.isDisjoint(with: filterTags) { return false }
            }
            if filterOverdue, !isOverdue(t) { return false }
            if !matchesSearch(t) { return false }
            return true
        }
    }

    private var filteredItems: [Task] { items }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private var sortLabel: String {
        switch sortMode {
        case .manual:     return "Manual"
        case .date:       return "Date"
        case .importance: return "Importance"
        }
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f
    }

    private func sectionTitle(for date: Date?) -> String {
        guard let d = date else { return "No date" }
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "Today" }
        if cal.isDateInTomorrow(d)  { return "Tomorrow" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return dayFormatter.string(from: d)
    }

    private var groupedByDay: [(title: String, indices: [Int])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: displayedIndices) { idx -> String in
            if let dd = items[idx].when { return sectionTitle(for: cal.startOfDay(for: dd)) }
            return sectionTitle(for: nil)
        }
        let sorter: (String, String) -> Bool = { a, b in
            let rank: (String) -> Int = {
                switch $0 {
                case "Today": return 0
                case "Tomorrow": return 1
                case "Yesterday": return 2
                case "No date": return 9999
                default: return 10
                }
            }
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a.localizedCompare(b) == .orderedAscending
        }
        return groups.map { ($0.key, $0.value) }.sorted { sorter($0.0, $1.0) }
    }

    private var groupedByImportance: [(title: String, indices: [Int])] {
        let order: [Task.Importance] = [.high, .normal, .low]
        let groups = Dictionary(grouping: displayedIndices) { idx in items[idx].importance }
        return order.compactMap { imp in
            if let arr = groups[imp], !arr.isEmpty { return (imp.rawValue, arr) }
            return nil
        }
    }

    private func expandedBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { expandedCompletedSections.contains(key) },
            set: { isOn in
                if isOn { expandedCompletedSections.insert(key) }
                else { expandedCompletedSections.remove(key) }
            }
        )
    }

    private var hasUndo: Bool { lastDeleted != nil }

    // ────────────────────────────────  BODY  ──────────────────────────────────
    var body: some View {
        NavigationStack {
            // HEADER (Title left + capsule right)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Text("Today")
                        .font(.largeTitle.bold())
                        .padding(.leading, 20)
                        .padding(.top, 10)
                        .baselineOffset(2)

                    Spacer(minLength: 0)

                    ToolbarGroupCapsule {
                        if sortMode == .manual {
                            Button {
                                isReordering.toggle()
                                haptic(isReordering ? .soft : .light)
                            } label: {
                                Image(systemName: isReordering ? "checkmark.circle" : "arrow.up.and.down.and.arrow.left.and.right")
                            }
                            .accessibilityLabel(isReordering ? "Done Reordering" : "Reorder")
                            .buttonStyle(.plain)
                        }

                        // Trash (recently deleted)
                        Button { showingTrash = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: recentlyDeleted.isEmpty ? "trash" : "trash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(
                                        recentlyDeleted.isEmpty
                                        ? AnyShapeStyle(.primary)
                                        : AnyShapeStyle(Color.red)
                                    )
                                    .contentTransition(.symbolEffect(.replace))
                                if !recentlyDeleted.isEmpty {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .accessibilityLabel("Recently Deleted")
                        .buttonStyle(.plain)

                        // Sort menu
                        Menu {
                            Picker("Sort", selection: $sortMode) {
                                ForEach(SortMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        } label: { Image(systemName: "arrow.up.arrow.down") }
                        .buttonStyle(.plain)

                        // Filter button (dot indicator when active)
                        Button { showingFilterSheet = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(
                                    (filterImportance != nil || !filterTags.isEmpty || filterOverdue)
                                    ? .accentColor : .primary
                                )
                                .overlay(alignment: .topTrailing) {
                                    if filterImportance != nil || !filterTags.isEmpty || filterOverdue {
                                        Circle().fill(Color.accentColor)
                                            .frame(width: 6, height: 6)
                                            .offset(x: 10, y: -10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)

                        // Add
                        Button {
                            draft = Task(title: "")
                            showingAdd = true
                        } label: { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 44)
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                .padding(.bottom, 6)

                Divider().opacity(0.08)
            }

            // ACTIVE FILTER/SORT/SEARCH CHIPS (pinned under header)
            if sortMode != .manual || filterImportance != nil || !filterTags.isEmpty || filterOverdue || isSearching {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {

                        // Search chip
                        if isSearching {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass").font(.caption2.weight(.semibold))
                                Text("“\(searchText)”").font(.caption.weight(.semibold)).lineLimit(1)
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                        }

                        // Sort chip (not for manual)
                        if sortMode != .manual {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down").font(.caption2.weight(.semibold))
                                Text("Sort: \(sortLabel)").font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                        }

                        // Importance chip
                        if let imp = filterImportance {
                            HStack(spacing: 6) {
                                Text(imp.rawValue).font(.caption.weight(.semibold))
                                Button {
                                    filterImportance = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15)).clipShape(Capsule())
                        }

                        // Overdue chip
                        if filterOverdue {
                            HStack(spacing: 6) {
                                Text("Overdue").font(.caption.weight(.semibold)).foregroundStyle(.red)
                                Button { filterOverdue = false } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red.opacity(0.14)).clipShape(Capsule())
                        }

                        // Tag chips
                        ForEach(Array(filterTags).sorted(), id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag).font(.caption.weight(.medium))
                                Button { filterTags.remove(tag) } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                        }

                        // Clear all
                        Button("Clear All") { clearAllFilters() }
                            .font(.caption).foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6).padding(.bottom, 4)
                }
            }

            // EMPTY STATE
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Text("You're all clear for today!")
                        .font(.title3.weight(.semibold))

                    Button {
                        draft = Task(title: ""); showingAdd = true
                    } label: {
                        Label("Add a task", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.1)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }

            // LIST
            List {
                // Completed section at very top
                let completedTop = displayedIndices.filter { items[$0].isDone }
                if !completedTop.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: expandedBinding(for: "COMPLETED-TOP")) {
                            ForEach(completedTop, id: \.self) { idx in
                                taskRow(for: idx)
                            }
                        } label: {
                            Text("Completed (\(completedTop.count))")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Open tasks by mode
                if sortMode == .manual {
                    let open = displayedIndices.filter { !items[$0].isDone }
                    Section {
                        ForEach(open, id: \.self) { idx in
                            taskRow(for: idx)
                        }
                        .onMove { indices, newOffset in
                            moveOpenTasks(openOrder: open, from: indices, to: newOffset)
                        }
                    }
                } else if sortMode == .date {
                    ForEach(groupedByDay, id: \.title) { group in
                        let open = group.indices.filter { !items[$0].isDone }
                        if !open.isEmpty {
                            Section {
                                ForEach(open, id: \.self) { idx in
                                    taskRow(for: idx)
                                }
                            } header: {
                                Text(group.title.uppercased())
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    ForEach(groupedByImportance, id: \.title) { group in
                        let open = group.indices.filter { !items[$0].isDone }
                        if !open.isEmpty {
                            Section {
                                ForEach(open, id: \.self) { idx in
                                    taskRow(for: idx)
                                }
                            } header: {
                                Text(group.title.uppercased())
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onTapGesture {
                if isSearchExpanded {
                    isSearchFieldFocused = false
                }
            }

            // NO RESULTS for search
            .overlay {
                if isSearching && displayedIndices.isEmpty && !items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No results").font(.subheadline.weight(.semibold))
                        Button("Clear search") { searchText = "" }.font(.caption)
                    }
                    .padding(.top, 48)
                }
            }

            // Bottom-right search: icon → expands into search bar (above the tab bar)
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                HStack {
                    Spacer()
                    Group {
                        if isSearchExpanded {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)

                                TextField("Search tasks", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .focused($isSearchFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        // keep it open; dismiss keyboard
                                        isSearchFieldFocused = false
                                    }

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        // collapse if you want to auto-close on clear:
                                        // withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { isSearchExpanded = false }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button("Cancel") {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                        isSearchExpanded = false
                                    }
                                    isSearchFieldFocused = false
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                            .padding(.trailing, 20)
                            .padding(.bottom, 10)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .task { isSearchFieldFocused = true }
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                    isSearchExpanded = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .imageScale(.large)
                                    .padding(12)
                                    .background(.regularMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                            .padding(.bottom, 10)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }

            // Use edit mode when reordering
            .environment(\.editMode, .constant(isReordering ? EditMode.active : EditMode.inactive))

            // Centered delete confirmation
            .overlay {
                if showDeleteDialog {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { showDeleteDialog = false }

                        VStack(spacing: 16) {
                            HStack(spacing: 10) {
                                Image(systemName: "trash.fill").foregroundColor(.red)
                                Text("Delete task?").font(.headline)
                            }
                            Text("You can Undo for 5 seconds after deletion.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Button(role: .destructive) {
                                    haptic(.rigid)
                                    if let idx = pendingDeleteIndex { performDelete(at: idx) }
                                    showDeleteDialog = false
                                    pendingDeleteIndex = nil
                                } label: { Text("Delete").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent).tint(.red)

                                Button {
                                    showDeleteDialog = false
                                    pendingDeleteIndex = nil
                                } label: { Text("Cancel").frame(maxWidth: .infinity) }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(20).frame(maxWidth: 360)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
                        .padding(.horizontal, 24)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: showDeleteDialog)
                }
            }

            // Undo toast
            .overlay(alignment: .bottom) {
                if showUndoToast, hasUndo {
                    HStack(spacing: 12) {
                        Image(systemName: "trash").imageScale(.large)
                        Text("Task deleted").font(.subheadline)
                        Spacer(minLength: 8)
                        Button(action: { undoDelete() }) { Text("Undo").font(.headline) }
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .padding(.bottom, 120).padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showUndoToast)
                }
            }

            // Changes & lifecycle
            .onChange(of: items) { _, _ in save() }
            .onChange(of: sortMode) { _, _ in resort() }
            .onChange(of: sortMode) { _, newMode in if newMode != .manual { isReordering = false } }
            .onAppear { loadIfNeeded(); resort() }

            // MARK: - Sheets: Edit
            .sheet(item: $selected) { sel in
                EditTaskSheet(
                    task: Binding(
                        get: { items[sel.index] },
                        set: { items[sel.index] = $0; resort() }
                    ),
                    onDone: {
                        haptic(.light)
                        selected = nil
                    },
                    onCancel: {
                        selected = nil
                    },
                    onToggleComplete: {
                        items[sel.index].isDone.toggle()
                        resort()
                        haptic(.soft)
                    },
                    onRequestDelete: {
                        // Close the sheet first (user gets immediate feedback)
                        haptic(.soft)
                        selected = nil

                        // After the sheet animation, present the centered popup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            pendingDeleteIndex = sel.index
                            haptic(.rigid) // tactile snap as the popup appears
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showDeleteDialog = true
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAdd) {
                NewTaskSheet(
                    task: $draft,
                    onAdd: { newTask in
                        // Reuse your existing lightweight parsing
                        let parsed = RuleParser.parse(newTask.title)
                        var toInsert = newTask
                        toInsert.title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        toInsert.when  = toInsert.when ?? parsed.when
                        switch parsed.importance {
                        case .low:    toInsert.importance = .low
                        case .normal: toInsert.importance = .normal
                        case .high:   toInsert.importance = .high
                        }

                        guard !toInsert.title.isEmpty else { return }
                        items.insert(toInsert, at: 0)
                        resort()
                        haptic(.light)
                    },
                    onCancel: {
                        // Reset draft if you want a clean slate next time
                        draft = Task(title: "")
                    }
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    allTags: allTags,
                    filterImportance: $filterImportance,
                    filterTags: $filterTags,
                    filterOverdue: $filterOverdue,
                    onClearAll: clearAllFilters
                )
            }
            .sheet(isPresented: $showingTrash) {
                RecentlyDeletedSheet(
                    entries: $recentlyDeleted,
                    onRestore: { entry in
                        let insertAt = max(0, min(entry.originalIndex, items.count))
                        items.insert(entry.task, at: insertAt)
                        recentlyDeleted.removeAll { $0.id == entry.id }
                        saveRecentlyDeleted()
                        resort()
                    },
                    onDeleteNow: { indexSet in
                        recentlyDeleted.remove(atOffsets: indexSet)
                        saveRecentlyDeleted()
                    },
                    onEmpty: {
                        recentlyDeleted.removeAll()
                        saveRecentlyDeleted()
                    }
                )
            }
        }
    }

    // ─────────────────────────────  ROW FACTORY  ──────────────────────────────
    @ViewBuilder
    private func taskRow(for idx: Int) -> some View {
        let t = items[idx]
        TaskRowSimple(
            title: t.title,
            isDone: t.isDone,
            when: t.when,
            notes: t.notes,
            importance: t.importance,
            hasNotes: !t.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            tags: t.tags,
            onToggle: {
                items[idx].isDone.toggle()
                resort()
                haptic(.light)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { selected = SelectedTask(index: idx) }

        // Leading: mark done/undone
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                items[idx].isDone.toggle()
                resort()
                haptic(.light)
            } label: {
                Label(items[idx].isDone ? "Mark Undone" : "Mark Done",
                      systemImage: items[idx].isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)
        }

        // Trailing: delete / edit
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                haptic(.medium)
                pendingDeleteIndex = idx
                showDeleteDialog = true
            } label: { Label("Delete", systemImage: "trash") }

            Button { selected = SelectedTask(index: idx) } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        // Long-press
        .contextMenu {
            Button {
                items[idx].isDone.toggle(); resort()
            } label: {
                Label(items[idx].isDone ? "Mark Undone" : "Mark Done",
                      systemImage: items[idx].isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            Button { selected = SelectedTask(index: idx) } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) {
                haptic(.medium)
                pendingDeleteIndex = idx
                showDeleteDialog = true
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // ─────────────────────────────  SORTING  ──────────────────────────────────
    private func resort() {
        switch sortMode {
        case .manual:
            items = stableGroupDone(items)
        case .date:
            items = stableGroupDone(items).sorted(by: { a, b in
                switch (a.when, b.when) {
                case let (lhs?, rhs?): return lhs < rhs
                case (nil, _?):        return false
                case (_?, nil):        return true
                default:
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            })
        case .importance:
            items = stableGroupDone(items).sorted(by: { a, b in
                weight(a.importance) < weight(b.importance)
                || (weight(a.importance) == weight(b.importance)
                    && a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending)
            })
        }
    }

    private func stableGroupDone(_ arr: [Task]) -> [Task] {
        let open = arr.filter { !$0.isDone }
        let done = arr.filter { $0.isDone }
        return open + done
    }

    private func weight(_ imp: Task.Importance) -> Int {
        switch imp { case .high: return 0; case .normal: return 1; case .low: return 2 }
    }

    // ─────────────────────────────  REORDERING  ───────────────────────────────
    /// Reorders only the OPEN tasks using the current `openOrder` mapping from the section.
    private func moveOpenTasks(openOrder: [Int], from source: IndexSet, to destination: Int) {
        var openItems: [Task] = openOrder.map { items[$0] }
        openItems.move(fromOffsets: source, toOffset: destination)
        for (pos, globalIndex) in openOrder.enumerated() {
            items[globalIndex] = openItems[pos]
        }
        items = stableGroupDone(items)
    }

    // ─────────────────────────────  DELETE & UNDO  ────────────────────────────
    private func performDelete(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        let removed = items.remove(at: index)

        // Add to Recently Deleted (with original index)
        let entry = DeletedEntry(task: removed, originalIndex: index)
        recentlyDeleted.insert(entry, at: 0)
        saveRecentlyDeleted()

        lastDeleted = (removed, index)

        // Show toast and auto-hide
        showUndoToast = true
        undoWorkItem?.cancel()
        let work = DispatchWorkItem {
            showUndoToast = false
            lastDeleted = nil
        }
        if showUndoToast {
            haptic(.soft)
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func undoDelete() {
        haptic(.soft)
        guard let last = lastDeleted else { return }
        let insertIndex = min(last.index, items.count)
        items.insert(last.task, at: insertIndex)

        if let idx = recentlyDeleted.firstIndex(where: { $0.task.id == last.task.id }) {
            recentlyDeleted.remove(at: idx)
            saveRecentlyDeleted()
        }

        showUndoToast = false
        lastDeleted = nil
        undoWorkItem?.cancel()
        undoWorkItem = nil
    }

    // ─────────────────────────────  PERSISTENCE  ──────────────────────────────
    private let fileName = "today_tasks.json"
    private func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL(), options: .atomic)
        } catch { print("Save error:", error) }
    }

    private let trashFileName = "recently_deleted.json"
    private func trashURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(trashFileName)
    }

    private func saveRecentlyDeleted() {
        do {
            let data = try JSONEncoder().encode(recentlyDeleted)
            try data.write(to: trashURL(), options: .atomic)
        } catch { print("Trash save error:", error) }
    }

    private func loadRecentlyDeleted() {
        do {
            let url = trashURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                recentlyDeleted = try JSONDecoder().decode([DeletedEntry].self, from: data)
            } else {
                recentlyDeleted = []
            }
        } catch { print("Trash load error:", error); recentlyDeleted = [] }
    }

    private func purgeExpiredTrash(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let before = recentlyDeleted.count
        recentlyDeleted.removeAll { $0.deletedAt < cutoff }
        if recentlyDeleted.count != before { saveRecentlyDeleted() }
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        do {
            let url = fileURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                items = try JSONDecoder().decode([Task].self, from: data)
            } else {
                items = [
                    Task(title: "📝 Example Task 1", tags: ["personal"]),
                    Task(title: "📅 Example Task 2", importance: .high, tags: ["work", "meeting"])
                ]
                save()
            }
        } catch { print("Load error:", error) }

        loadRecentlyDeleted()
        purgeExpiredTrash()
    }

    // ─────────────────────────────  ACTIONS  ──────────────────────────────────
    private func clearAllFilters() {
        filterImportance = nil
        filterTags.removeAll()
        filterOverdue = false
        sortMode = .manual
        searchText = ""
    }
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ FILTER SHEET                                                              │
 // └────────────────────────────────────────────────────────────────────────────┘
private struct FilterSheet: View {
    let allTags: [String]
    @Binding var filterImportance: TodayView.Task.Importance?
    @Binding var filterTags: Set<String>
    @Binding var filterOverdue: Bool
    var onClearAll: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Importance") {
                    Picker("Show", selection: Binding(
                        get: { filterImportance?.rawValue ?? "All" },
                        set: { raw in filterImportance = TodayView.Task.Importance(rawValue: raw) }
                    )) {
                        Text("All").tag("All")
                        ForEach(TodayView.Task.Importance.allCases) { imp in
                            Text(imp.rawValue).tag(imp.rawValue)
                        }
                    }
                }
                Section("Overdue") {
                    Toggle("Overdue only", isOn: $filterOverdue)
                }
                Section("Tags") {
                    if allTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(allTags, id: \.self) { tag in
                            Toggle(isOn: Binding(
                                get: { filterTags.contains(tag) },
                                set: { on in if on { filterTags.insert(tag) } else { filterTags.remove(tag) } }
                            )) { Text(tag) }
                        }
                    }
                }
                if filterImportance != nil || !filterTags.isEmpty || filterOverdue {
                    Section { Button("Clear filters", role: .destructive) { onClearAll() } }
                }
            }
            .navigationTitle("Filters")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ ROW (TaskRowSimple)                                                        │
 // └────────────────────────────────────────────────────────────────────────────┘
private struct TaskRowSimple: View {
    let title: String
    let isDone: Bool
    let when: Date?
    let notes: String?
    let importance: TodayView.Task.Importance
    let hasNotes: Bool
    let tags: [String]
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(isDone ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                Text(title)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)

                Spacer(minLength: 0)
            }

            // Metadata line
            HStack(spacing: 10) {
                let overdue: Bool = {
                    guard !isDone, let when else { return false }
                    return when < Date()
                }()

                if let when {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(when, style: .date)
                        Text(when, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(overdue ? .red : .secondary)
                }

                if overdue {
                    Text("Overdue")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.14))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }

                if importance != .normal {
                    Text(importance.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(importance == .high ? Color.red.opacity(0.12) : Color.yellow.opacity(0.14))
                        .foregroundStyle(importance == .high ? .red : .orange)
                        .clipShape(Capsule())
                }
            }

            // Notes preview with soft fade
            if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            colors: [Color.clear, Color(uiColor: .systemBackground)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 28)
                        .allowsHitTesting(false)
                    }
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ EDITOR                                                                    │
 // └────────────────────────────────────────────────────────────────────────────┘
private struct TaskEditor: View {
    @Binding var task: TodayView.Task
    let title: String
    let primaryButtonTitle: String
    let onPrimary: () -> Void
    let onCancel: () -> Void

    @State private var hasWhen: Bool = false
    @State private var tagInput: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $task.title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Details") {
                    TextEditor(text: $task.notes)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.15))
                        )
                }

                Section("Schedule") {
                    Toggle("Has date & time", isOn: $hasWhen)
                        .onChange(of: hasWhen) { _, on in
                            task.when = on ? (task.when ?? Date()) : nil
                        }
                    if hasWhen {
                        DatePicker(
                            "When",
                            selection: Binding(
                                get: { task.when ?? Date() },
                                set: { task.when = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Importance") {
                    Picker("Level", selection: $task.importance) {
                        ForEach(TodayView.Task.Importance.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }.pickerStyle(.segmented)
                }

                Section("Tags") {
                    HStack(spacing: 8) {
                        TextField("Add tag", text: $tagInput).onSubmit(addTagFromInput)
                        Button("Add") { addTagFromInput() }
                            .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !task.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(task.tags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag).font(.caption2)
                                        Button {
                                            remove(tag)
                                        } label: { Image(systemName: "xmark.circle.fill").imageScale(.small) }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12)).clipShape(Capsule())
                                }
                            }
                        }.padding(.top, 2)
                    }
                }

                Section { Toggle("Completed", isOn: $task.isDone) }
            }
            .onAppear { hasWhen = (task.when != nil) }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryButtonTitle) { onPrimary() }
                        .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addTagFromInput() {
        let tokens = tagInput
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return }
        var set = Set(task.tags.map { $0.lowercased() })
        for t in tokens {
            let k = t.lowercased()
            if !set.contains(k) { task.tags.append(t); set.insert(k) }
        }
        tagInput = ""
    }

    private func remove(_ tag: String) {
        task.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
}


//       NEW TASK SHEET
// MARK: - New Task Sheet (polished add flow)
private struct NewTaskSheet: View {
    @Binding var task: TodayView.Task
    var onAdd: (TodayView.Task) -> Void
    var onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var hasWhen: Bool = false
    @State private var tagInput: String = ""
    @FocusState private var titleFocused: Bool

    // Quick date helpers
    private var cal: Calendar { .current }
    private var today: Date { Date() }
    private var tomorrow: Date { cal.date(byAdding: .day, value: 1, to: today) ?? today }
    private var eveningToday: Date {
        let comps = cal.dateComponents([.year, .month, .day], from: today)
        let evening = cal.date(from: comps).flatMap { cal.date(byAdding: .hour, value: 19, to: $0) } // ~7 PM
        return evening ?? today
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // TITLE CARD
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("What’s the task?", text: $task.title)
                                .textInputAutocapitalization(.sentences)
                                .focused($titleFocused)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // QUICK SCHEDULE CHIPS
                    Group {
                        HStack {
                            Text("Quick schedule")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Chip("Today") {
                                    hasWhen = true
                                    task.when = cal.startOfDay(for: today)
                                }
                                Chip("Tomorrow") {
                                    hasWhen = true
                                    task.when = cal.startOfDay(for: tomorrow)
                                }
                                Chip("This evening") {
                                    hasWhen = true
                                    task.when = eveningToday
                                }
                                Chip("Clear date", style: .plain) {
                                    hasWhen = false
                                    task.when = nil
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // SCHEDULE CARD
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Has date & time", isOn: $hasWhen)
                                .onChange(of: hasWhen) { _, on in
                                    task.when = on ? (task.when ?? Date()) : nil
                                }

                            if hasWhen {
                                DatePicker(
                                    "When",
                                    selection: Binding(
                                        get: { task.when ?? Date() },
                                        set: { task.when = $0 }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // IMPORTANCE CARD
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Importance")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $task.importance) {
                                ForEach(TodayView.Task.Importance.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // TAGS CARD
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                TextField("Add tag", text: $tagInput)
                                    .onSubmit(addTagFromInput)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)

                                Button("Add") { addTagFromInput() }
                                    .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if !task.tags.isEmpty {
                                Wrap(tags: task.tags) { tag in
                                    CapsuleTag(tag: tag) {
                                        remove(tag)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // NOTES CARD
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $task.notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(task)
                        dismiss()
                    }
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                hasWhen = (task.when != nil)
                // Focus title on open for faster entry
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { titleFocused = true }
            }
        }
    }

    // Helpers
    private func addTagFromInput() {
        let tokens = tagInput
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return }
        var set = Set(task.tags.map { $0.lowercased() })
        for t in tokens {
            let k = t.lowercased()
            if !set.contains(k) {
                task.tags.append(t)
                set.insert(k)
            }
        }
        tagInput = ""
    }

    private func remove(_ tag: String) {
        task.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    // Small subviews
    private struct Chip: View {
        enum Style { case filled, plain }
        var title: String
        var style: Style = .filled
        var action: () -> Void
        init(_ title: String, style: Style = .filled, action: @escaping () -> Void) {
            self.title = title; self.style = style; self.action = action
        }
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(style == .filled ? Color.secondary.opacity(0.15) : Color.clear)
                    .overlay(
                        Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: style == .filled ? 0 : 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private struct CapsuleTag: View {
        var tag: String
        var onRemove: () -> Void
        var body: some View {
            HStack(spacing: 6) {
                Text(tag).font(.caption2)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").imageScale(.small)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    // Simple flow layout for tags
    private struct Wrap<Content: View>: View {
        let items: [String]
        let content: (String) -> Content
        init(tags items: [String], @ViewBuilder content: @escaping (String) -> Content) {
            self.items = items; self.content = content
        }
        @State private var totalHeight: CGFloat = .zero
        var body: some View {
            GeometryReader { geo in
                self.generate(in: geo)
            }
            .frame(minHeight: totalHeight)
        }
        private func generate(in g: GeometryProxy) -> some View {
            var width = CGFloat.zero
            var height = CGFloat.zero
            return ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding(.trailing, 8)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > g.size.width) {
                                width = 0
                                height -= d.height + 8
                            }
                            let result = width
                            if item == items.last {
                                width = 0
                            } else {
                                width -= d.width + 8
                            }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { _ in
                            let result = height
                            if item == items.last {
                                height = 0
                            }
                            return result
                        })
                }
            }
            .background(viewHeightReader($totalHeight))
        }
        private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
            GeometryReader { geo -> Color in
                DispatchQueue.main.async { binding.wrappedValue = geo.size.height }
                return Color.clear
            }
        }
    }
}


//      EDIT TASK SHEET
// MARK: - Edit Task Sheet (polished)
private struct EditTaskSheet: View {
    @Binding var task: TodayView.Task
    var onDone: () -> Void
    var onCancel: () -> Void
    var onToggleComplete: () -> Void
    var onRequestDelete: () -> Void    // ← NEW

    @Environment(\.dismiss) private var dismiss

    @State private var hasWhen: Bool = false
    @State private var tagInput: String = ""
    @State private var isDeleting: Bool = false

    private var cal: Calendar { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // TITLE
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("What’s the task?", text: $task.title)
                                .textInputAutocapitalization(.sentences)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // SCHEDULE
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Has date & time", isOn: $hasWhen)
                                .onChange(of: hasWhen) { _, on in
                                    task.when = on ? (task.when ?? Date()) : nil
                                }
                            if hasWhen {
                                DatePicker(
                                    "When",
                                    selection: Binding(
                                        get: { task.when ?? Date() },
                                        set: { task.when = $0 }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // IMPORTANCE
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Importance")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $task.importance) {
                                ForEach(TodayView.Task.Importance.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // TAGS
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                TextField("Add tag", text: $tagInput)
                                    .onSubmit(addTagFromInput)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                Button("Add") { addTagFromInput() }
                                    .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if !task.tags.isEmpty {
                                Wrap(tags: task.tags) { tag in
                                    CapsuleTag(tag: tag) {
                                        remove(tag)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }

                    // DETAILS
                    Group {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Details")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $task.notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    
                    // DELETE BUTTON (uses TodayView's centered confirmation popup)
                    Group {
                        Button(role: .destructive) {
                            // quick press animation then hand off to TodayView
                            withAnimation(.easeInOut(duration: 0.12)) { isDeleting = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onRequestDelete()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete Task")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .scaleEffect(isDeleting ? 0.98 : 1.0)
                        .opacity(isDeleting ? 0.85 : 1.0)
                        .disabled(isDeleting)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                // Mark Complete toggle
                ToolbarItem(placement: .principal) {
                    Button {
                        onToggleComplete()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            Text(task.isDone ? "Completed" : "Mark Complete")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                // Done
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { hasWhen = (task.when != nil) }
        }
    }

    // Helpers
    private func addTagFromInput() {
        let tokens = tagInput
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return }
        var set = Set(task.tags.map { $0.lowercased() })
        for t in tokens {
            let k = t.lowercased()
            if !set.contains(k) {
                task.tags.append(t)
                set.insert(k)
            }
        }
        tagInput = ""
    }

    private func remove(_ tag: String) {
        task.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    // Small subviews (same as in NewTaskSheet)
    private struct CapsuleTag: View {
        var tag: String
        var onRemove: () -> Void
        var body: some View {
            HStack(spacing: 6) {
                Text(tag).font(.caption2)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").imageScale(.small)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private struct Wrap<Content: View>: View {
        let items: [String]
        let content: (String) -> Content
        init(tags items: [String], @ViewBuilder content: @escaping (String) -> Content) {
            self.items = items; self.content = content
        }
        @State private var totalHeight: CGFloat = .zero
        var body: some View {
            GeometryReader { geo in
                self.generate(in: geo)
            }
            .frame(minHeight: totalHeight)
        }
        private func generate(in g: GeometryProxy) -> some View {
            var width = CGFloat.zero
            var height = CGFloat.zero
            return ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding(.trailing, 8)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > g.size.width) {
                                width = 0; height -= d.height + 8
                            }
                            let result = width
                            if item == items.last { width = 0 } else { width -= d.width + 8 }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { _ in
                            let result = height
                            if item == items.last { height = 0 }
                            return result
                        })
                }
            }
            .background(viewHeightReader($totalHeight))
        }
        private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
            GeometryReader { geo -> Color in
                DispatchQueue.main.async { binding.wrappedValue = geo.size.height }
                return Color.clear
            }
        }
    }
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ TOOLBAR CAPSULE (Shared look with Calendar)                               │
 // └────────────────────────────────────────────────────────────────────────────┘
private struct ToolbarGroupCapsule<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 22) {
            content
                .labelStyle(.iconOnly)
                .imageScale(.large)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .contentShape(Capsule())
        .allowsHitTesting(true)
    }
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ EXTENSIONS & SUBVIEWS                                                     │
 // └────────────────────────────────────────────────────────────────────────────┘
extension TodayView {
    // Reorder helper is above (moveOpenTasks)
}

// ┌────────────────────────────────────────────────────────────────────────────┐
 // │ RECENTLY DELETED SHEET                                                    │
 // └────────────────────────────────────────────────────────────────────────────┘
private struct RecentlyDeletedSheet: View {
    @Binding var entries: [TodayView.DeletedEntry]
    var onRestore: (TodayView.DeletedEntry) -> Void
    var onDeleteNow: (IndexSet) -> Void
    var onEmpty: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trash").imageScale(.large).foregroundStyle(.secondary)
                        Text("No recently deleted items.").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries.sorted(by: { $0.deletedAt > $1.deletedAt })) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "trash").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.task.title).lineLimit(2)
                                Text("Deleted " + RelativeDateTimeFormatter().localizedString(for: entry.deletedAt, relativeTo: Date()))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") { onRestore(entry) }.buttonStyle(.bordered)
                        }
                    }
                    .onDelete(perform: onDeleteNow)
                }
            }
            .navigationTitle("Recently Deleted")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    if !entries.isEmpty { Button("Empty") { onEmpty() }.foregroundColor(.red) }
                }
            }
        }
    }
}

