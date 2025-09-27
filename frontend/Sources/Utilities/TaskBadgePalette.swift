import SwiftUI
import AppKit

extension TaskBadgeColor {
    var color: Color {
        switch self {
        case .neutral: return Color.gray.opacity(0.6)
        case .active: return Color.blue
        case .attention: return Color.orange
        case .success: return Color.green
        case .danger: return Color.red
        }
    }

    var nsColor: NSColor {
        switch self {
        case .neutral: return NSColor.systemGray
        case .active: return NSColor.systemBlue
        case .attention: return NSColor.systemOrange
        case .success: return NSColor.systemGreen
        case .danger: return NSColor.systemRed
        }
    }
}
