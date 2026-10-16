import Foundation

enum AppVersion {
    /// CFBundleShortVersionString — driven by MARKETING_VERSION in build settings.
    static let short: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    /// CFBundleVersion — driven by CURRENT_PROJECT_VERSION in build settings.
    static let build: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    /// "v1.1" for the header badge.
    static var display: String { "v\(short)" }

    /// "v1.1 (2)" for the settings pane.
    static var full: String { "v\(short) (\(build))" }
}
