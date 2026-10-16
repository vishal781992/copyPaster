import SwiftUI
import ServiceManagement

@main
struct copyPasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var manager = ClipboardManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false

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
            }
            .padding()
            .frame(width: 300)
        }
    }
}
