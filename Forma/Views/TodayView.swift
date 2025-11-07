import SwiftUI
import Combine

private enum ActiveSheet: Identifiable {
    case add
    case edit(Int)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let i): return "edit-\(i)"
        }
    }
}

struct TodayView: View {
    @StateObject private var store = TaskStore()
    @State private var activeSheet: ActiveSheet? = nil
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, task in
                        // Card
                        HStack(spacing: 12) {
                            // CHECKBOX BUTTON (only this toggles)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    store.items[index].isDone.toggle()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                                    .foregroundColor(task.isDone ? .formaAccent : .formaSubtext)
                            }
                            .buttonStyle(.plain)

                            // CONTENT AREA (tap opens sheet)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.formaBody)
                                    .foregroundStyle(Color.formaText)
                                    .strikethrough(task.isDone)

                                if let t = task.time {
                                    Text(t, style: .time)
                                        .font(.formaCaption)
                                        .foregroundStyle(Color.formaSubtext)
                                }
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.formaSubtext)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.formaCard)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        )
                        .contentShape(Rectangle())                 // make whole card tappable
                        .onTapGesture { activeSheet = .edit(index) } // tap anywhere (except checkbox) opens sheet
                        .contextMenu {
                            Button("Open") { activeSheet = .edit(index) }
                            Button("Delete", role: .destructive) { store.items.remove(at: index) }
                        }
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 12)
                }
            }
            .background(Color.formaBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTitle = ""
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.formaAccent)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    NavigationStack {
                        Form {
                            Section(header: Text("Task")) {
                                TextField("Title", text: $newTitle)
                            }
                        }
                        .navigationTitle("New Task")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { activeSheet = nil }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !title.isEmpty {
                                        store.items.insert(TaskItem(title: title), at: 0)
                                    }
                                    activeSheet = nil
                                }
                                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }

                case .edit(let i):
                    NavigationStack {
                        TaskDetailView(task: $store.items[i])
                            .navigationTitle("Task")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { activeSheet = nil }
                                }
                            }
                    }
                }
            }
        }
    }
}
