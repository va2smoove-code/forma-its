import SwiftUI

struct TodayView: View {
    // MARK: - Model
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

        init(id: UUID = UUID(),
             title: String,
             isDone: Bool = false,
             notes: String = "",
             when: Date? = nil,
             importance: Importance = .normal,
             tags: [String] = []) {
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

    enum SortMode: String, CaseIterable {
        case manual = "Manual"
        case date = "Date"
        case importance = "Importance"
    }

    // MARK: - State
    @State private var items: [Task] = []
    @State private var selected: SelectedTask? = nil
    @State private var showingAdd = false
    @State private var draft = Task(title: "")
    @State private var hasLoaded = false
    @State private var sortMode: SortMode = .manual

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(items.indices, id: \.self) { i in
                        let t = items[i]
                        TaskRowSimple(
                            title: t.title,
                            isDone: t.isDone,
                            when: t.when,
                            importance: t.importance,
                            hasNotes: !t.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            tags: t.tags,
                            onToggle: {
                                items[i].isDone.toggle()
                                resort()
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selected = SelectedTask(index: i) }
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortMode) {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draft = Task(title: "")
                        showingAdd = true
                    } label: { Image(systemName: "plus") }
                }
            }
            // Persist + load + react to sort changes
            .onChange(of: items) { _, _ in
                save()
            }
            .onChange(of: sortMode) { _, _ in
                resort()
            }
            .onAppear {
                loadIfNeeded()
                resort()
            }

            // Edit sheet
            .sheet(item: $selected) { sel in
                TaskEditor(
                    task: Binding(
                        get: { items[sel.index] },
                        set: { items[sel.index] = $0; resort() }
                    ),
                    title: "Task",
                    primaryButtonTitle: "Done",
                    onPrimary: { selected = nil },
                    onCancel: { selected = nil }
                )
            }

            // Add (+)
            .sheet(isPresented: $showingAdd) {
                TaskEditor(
                    task: $draft,
                    title: "New Task",
                    primaryButtonTitle: "Add",
                    onPrimary: {
                        let parsed = Parser.parse(draft.title)
                        var toInsert = draft
                        toInsert.title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        toInsert.importance = parsed.importance
                        toInsert.when = parsed.when

                        if !toInsert.title.isEmpty {
                            items.insert(toInsert, at: 0)
                            resort()
                        }
                        showingAdd = false
                    },
                    onCancel: { showingAdd = false }
                )
            }
        }
    }

    // MARK: - Sorting
    private func resort() {
        guard sortMode != .manual else {
            // Manual: keep items as-is, but still push completed to bottom within “manual” intent
            items = stableGroupDone(items)
            return
        }
        switch sortMode {
        case .manual:
            items = stableGroupDone(items)
        case .date:
            items = stableGroupDone(items).sorted(by: { a, b in
                // earlier date first; nil last
                switch (a.when, b.when) {
                case let (lhs?, rhs?): return lhs < rhs
                case (nil, _?): return false
                case (_?, nil): return true
                default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
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
        switch imp {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }

    // MARK: - Persistence
    private let fileName = "today_tasks.json"

    private func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL(), options: .atomic)
        } catch {
            print("Save error:", error)
        }
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
        } catch {
            print("Load error:", error)
        }
    }

    // MARK: - Actions
    private func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

// MARK: - Compact Row with tags
private struct TaskRowSimple: View {
    let title: String
    let isDone: Bool
    let when: Date?
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

            // Metadata row
            HStack(spacing: 10) {
                if let when {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(when, style: .date)
                        Text(when, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if importance != .normal {
                    Text(importance.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(importance == .high ? Color.red.opacity(0.12) : Color.yellow.opacity(0.14))
                        .foregroundStyle(importance == .high ? .red : .orange)
                        .clipShape(Capsule())
                }

                if hasNotes {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                        Text("Notes")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Tags row (chips)
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
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

// MARK: - Reusable Editor (with tags)
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

                Section("Notes") {
                    TextEditor(text: $task.notes)
                        .frame(minHeight: 120)
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
                    }
                    .pickerStyle(.segmented)
                }

                // Tags editor
                Section("Tags") {
                    HStack(spacing: 8) {
                        TextField("Add tag", text: $tagInput)
                            .onSubmit(addTagFromInput)
                        Button("Add") { addTagFromInput() }
                            .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !task.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(task.tags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag)
                                            .font(.caption2)
                                        Button {
                                            remove(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill").imageScale(.small)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Section {
                    Toggle("Completed", isOn: $task.isDone)
                }
            }
            .onAppear { hasWhen = (task.when != nil) }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryButtonTitle) { onPrimary() }
                        .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Tag helpers
    private func addTagFromInput() {
        let tokens = tagInput
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return }
        var set = Set(task.tags.map { $0.lowercased() })
        for t in tokens {
            let key = t.lowercased()
            if !set.contains(key) {
                task.tags.append(t)
                set.insert(key)
            }
        }
        tagInput = ""
    }

    private func remove(_ tag: String) {
        task.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
}
