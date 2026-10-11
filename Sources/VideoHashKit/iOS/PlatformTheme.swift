import SwiftUI

#if canImport(UIKit)
import UIKit

public extension Color {
    static let dedupeCardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let dedupeSubBackground = Color(uiColor: .systemGray6)
    static let dedupeChipBackground = Color(uiColor: .systemGray5)
    static let dedupeMainBackground = Color(uiColor: .systemGroupedBackground)
}
#elseif canImport(AppKit)
import AppKit

public extension Color {
    static let dedupeCardBackground = Color(nsColor: .controlBackgroundColor)
    static let dedupeSubBackground = Color(nsColor: .windowBackgroundColor)
    static let dedupeChipBackground = Color(nsColor: .underPageBackgroundColor)
    static let dedupeMainBackground = Color(nsColor: .windowBackgroundColor)
}
#endif
