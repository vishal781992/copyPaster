import SwiftUI
import ServiceManagement

@main
struct copyPasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var manager = ClipboardManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(ClipboardManager.passwordLifetimeKey)
    private var passwordLifetimeHours = ClipboardManager.defaultPasswordLifetimeHours

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
        }
        .defaultSize(width: 400, height: 560)

        Settings {
            Form {
                LabeledContent("Version", value: AppVersion.full)
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                        }
                    }
                Picker("Delete passwords after", selection: $passwordLifetimeHours) {
                    Text("1 hour").tag(1)
                    Text("8 hours").tag(8)
                    Text("24 hours").tag(24)
                    Text("7 days").tag(24 * 7)
                    Text("30 days").tag(24 * 30)
                    Text("Never").tag(0)
                }
                .onChange(of: passwordLifetimeHours) { manager.removeExpiredPasswords() }
                Text("Only items marked Secret or Likely. Pinned items and other text are kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 360)
        }
    }
}
