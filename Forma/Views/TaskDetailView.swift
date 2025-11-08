import SwiftUI

struct TaskDetailView: View {
    @Binding var task: TaskItem
    let index: Int
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $task.title)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }

            Section("Schedule") {
                // Toggle controls presence of time
                Toggle("Has time", isOn: Binding(
                    get: { task.time != nil },
                    set: { hasTime in
                        task.time = hasTime ? (task.time ?? Date()) : nil
                    }
                ))

                if let _ = task.time {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { task.time ?? Date() },
                            set: { task.time = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section("Notes") {
                TextEditor(text: $task.notes)
                    .frame(minHeight: 140)
            }

            Section {
                Toggle("Completed", isOn: $task.isDone)
            }
            
            Section {
                Button {
                    withAnimation(.spring()) {
                        appState.focusTitle = task.title
                        appState.focusIndex = index 
                        appState.selectedTab = .focus
                        dismiss()
                    }
                } label: {
                    Text("Start Focus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .font(.headline)
                        .foregroundColor(.white)
                        .background(Color.formaAccent)
                        .cornerRadius(12)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Task")
    }
}
