import AppKit

/// Light/dark override for the whole app. Stored under "appearance" in UserDefaults.
enum AppAppearance: String, CaseIterable {
    case auto, light, dark

    static let storageKey = "appearance"

    static var current: AppAppearance {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppAppearance.init) ?? .auto
    }

    /// Order the header button cycles through: Auto → Light → Dark → Auto.
    var next: AppAppearance {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var symbol: String {
        switch self {
        case .auto:  return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark:  return "moon.fill"
        }
    }

    var label: String {
        switch self {
        case .auto:  return "Auto"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    /// Setting it on NSApp also restyles the popover chrome, which preferredColorScheme doesn't reach.
    func apply() {
        switch self {
        case .auto:  NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:  NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
