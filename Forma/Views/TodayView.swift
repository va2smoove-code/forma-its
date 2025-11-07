import SwiftUI
import Combine

struct TodayView: View {
    @StateObject private var store = TaskStore()
    @State private var showingAdd = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, task in
                    NavigationLink {
                        TaskDetailView(task: $store.items[index])
                    } label: {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    store.items[index].isDone.toggle()
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .imageScale(.large)
                                    .foregroundColor(task.isDone ? .formaAccent : .formaSubtext)
                            }
                            .buttonStyle(.plain)

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
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.items.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { /* snooze later */ } label: {
                            Label("Snooze", systemImage: "clock.arrow.circlepath")
                        }
                        .tint(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.formaBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTitle = ""
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.formaAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    Form {
                        Section(header: Text("Task")) {
                            TextField("Title", text: $newTitle)
                        }
                    }
                    .navigationTitle("New Task")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !title.isEmpty {
                                    store.items.insert(TaskItem(title: title), at: 0)
                                }
                                showingAdd = false
                            }
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }
}
