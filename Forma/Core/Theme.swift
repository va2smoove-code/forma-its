import SwiftUI

// Colors (auto-adapt with light/dark using system bases)
extension Color {
    static let formaBackground = Color(UIColor.systemGroupedBackground)   // soft gray
    static let formaCard       = Color(UIColor.systemBackground)          // true surface (white in light)
    static let formaAccent     = Color(red: 0.20, green: 0.44, blue: 0.90)
    static let formaText       = Color.primary
    static let formaSubtext    = Color.secondary
}

// Typography
extension Font {
    static let formaTitleXL = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let formaTitleL  = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let formaBody    = Font.system(size: 17, weight: .regular, design: .default)
    static let formaCaption = Font.system(size: 13, weight: .regular, design: .default)
}
