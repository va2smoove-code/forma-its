import Foundation
import Combine

struct TaskItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var time: Date? = nil
    var isDone: Bool = false
}

final class TaskStore: ObservableObject {
    @Published var items: [TaskItem] = [
        TaskItem(title: "Check email", time: Date().addingTimeInterval(60*30)),
        TaskItem(title: "Draft project outline", time: Date().addingTimeInterval(60*60)),
        TaskItem(title: "Daily review")
    ]
}
