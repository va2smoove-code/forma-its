import SwiftUI
import Combine

enum Tab: Hashable {
    case today, calendar, focus, notes, review
}

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .today
    @Published var focusIndex: Int? = nil
    @Published var focusTitle: String? = nil
}
