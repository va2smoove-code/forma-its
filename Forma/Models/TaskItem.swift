import Foundation
import Combine

struct TaskItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var time: Date? = nil
    var isDone: Bool = false
    var notes: String = ""   // new field
}


final class TaskStore: ObservableObject {
    @Published var items: [TaskItem] = [] {
        didSet { save() }
    }

    private let fileName = "tasks.json"

    init() {
        load()
        // Seed initial examples only if file was empty
        if items.isEmpty {
            items = [
                TaskItem(title: "Check email", time: Date().addingTimeInterval(60*30)),
                TaskItem(title: "Draft project outline", time: Date().addingTimeInterval(60*60)),
                TaskItem(title: "Daily review")
            ]
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL(), options: .atomic)
        } catch {
            print("Save error:", error)
        }
    }

    private func load() {
        do {
            let url = fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            items = try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            print("Load error:", error)
        }
    }

    private func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }
}
