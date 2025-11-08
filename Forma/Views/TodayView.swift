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

        init(id: UUID = UUID(),
             title: String,
             isDone: Bool = false,
             notes: String = "",
             when: Date? = nil,
             importance: Importance = .normal) {
            self.id = id
            self.title = title
            self.isDone = isDone
            self.notes = notes
            self.when = when
            self.importance = importance
        }
    }

    struct SelectedTask: Identifiable {
        let index: Int
        var id: Int { index }
    }

    // MARK: - State
    @State private var items: [Task] = []
    @State private var selected: SelectedTask? = nil

    // Add sheet state (a draft task edited in the + sheet)
    @State private var showingAdd = false
    @State private var draft = Task(title: "")

    // Persistence flag
    @State private var hasLoaded = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Today")) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Button {
                                    items[index].isDone.toggle()
                                } label: {
                                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                        .imageScale(.large)
                                        .foregroundColor(task.isDone ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)

                                Text(task.title)
                                    .strikethrough(task.isDone)
                                    .foregroundStyle(task.isDone ? .secondary : .primary)

                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 10) {
                                if let when = task.when {
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                        Text(when, style: .date)
                                        Text(when, style: .time)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                if task.importance != .normal {
                                    Text(task.importance.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(task.importance == .high ? Color.red.opacity(0.12) : Color.yellow.opacity(0.14))
                                        .foregroundStyle(task.importance == .high ? .red : .orange)
                                        .clipShape(Capsule())
                                }

                                if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "note.text")
                                        Text("Notes")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selected = SelectedTask(index: index) }
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // reset draft then present sheet
                        draft = Task(title: "")
                        showingAdd = true
                    } label: { Image(systemName: "plus") }
                }
            }
            // Persist on changes
            .onChange(of: items) { _, _ in save() }
            .onAppear(perform: loadIfNeeded)

            // EDIT EXISTING
            .sheet(item: $selected) { sel in
                TaskEditor(
                    task: $items[sel.index],
                    title: "Task",
                    primaryButtonTitle: "Done",
                    onPrimary: { selected = nil },
                    onCancel: { selected = nil }
                )
            }

            // ADD NEW (full settings)
            .sheet(isPresented: $showingAdd) {
                TaskEditor(
                    task: $draft,
                    title: "New Task",
                    primaryButtonTitle: "Add",
                    onPrimary: {
                        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            var toInsert = draft
                            toInsert.title = trimmed
                            items.insert(toInsert, at: 0)
                        }
                        showingAdd = false
                    },
                    onCancel: { showingAdd = false }
                )
            }
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
                    Task(title: "📝 Example Task 1"),
                    Task(title: "📅 Example Task 2", importance: .high)
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

// MARK: - Reusable Editor (used by both Add and Edit)
private struct TaskEditor: View {
    @Binding var task: TodayView.Task
    let title: String
    let primaryButtonTitle: String
    let onPrimary: () -> Void
    let onCancel: () -> Void

    @State private var hasWhen: Bool = false

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
}
