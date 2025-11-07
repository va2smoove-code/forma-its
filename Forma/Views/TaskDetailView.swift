import SwiftUI

struct TaskDetailView: View {
    @Binding var task: TaskItem

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $task.title)
            }
            
            Section("Notes") {
                TextEditor(text: $task.notes)
                    .frame(minHeight: 120)
            }

            Section("Schedule") {
                Toggle("Has time", isOn: Binding(
                    get: { task.time != nil },
                    set: { hasTime in
                        task.time = hasTime ? (task.time ?? Date()) : nil
                    }
                ))

                if let _ = task.time {
                    DatePicker("Time", selection: Binding(
                        get: { task.time ?? Date() },
                        set: { task.time = $0 }
                    ), displayedComponents: [.hourAndMinute, .date])
                }
            }

            Section {
                Toggle("Completed", isOn: $task.isDone)
            }
        }
        .navigationTitle("Task")
    }
}
