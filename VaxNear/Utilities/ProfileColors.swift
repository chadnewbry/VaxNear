import SwiftUI

enum ProfileColors {
    static let presets: [String] = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5AC8FA", // Light Blue
        "#FFCC00", // Yellow
        "#8E8E93", // Gray
        "#00C7BE", // Teal
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
