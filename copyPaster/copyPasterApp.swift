import SwiftUI
import ServiceManagement
import AppKit

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
                Picker("Delete passwords & images after", selection: $passwordLifetimeHours) {
                    Text("1 hour").tag(1)
                    Text("8 hours").tag(8)
                    Text("24 hours").tag(24)
                    Text("7 days").tag(24 * 7)
                    Text("30 days").tag(24 * 30)
                    Text("Never").tag(0)
                }
                .onChange(of: passwordLifetimeHours) { manager.removeExpiredItems() }
                Text("Items marked Secret or Likely, and images. Saved screenshot files stay in their folder. Pinned items and other text are kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ClaudeKeySettings()
                    .environment(manager)
            }
            .padding()
            .frame(width: 360)
        }
    }
}

/// Claude API key for the tile's rewrite button. Saved to the Keychain, never to project files.
private struct ClaudeKeySettings: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var keyInput = ""
    @State private var isReplacing = false
    @State private var status: String?

    var body: some View {
        Section("AI Rewrite (Claude)") {
            if manager.hasClaudeKey && !isReplacing {
                LabeledContent("API Key") {
                    HStack {
                        Label(manager.claudeKeyHint ?? "Saved", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .help("Saved in your Mac's Keychain")
                        Button("Replace") { isReplacing = true; status = nil }
                        Button("Remove", role: .destructive) {
                            manager.removeClaudeKey()
                            status = "Key removed"
                        }
                    }
                }
            } else {
                LabeledContent("API Key") {
                    HStack {
                        SecureField("API Key", text: $keyInput, prompt: Text("sk-ant-…"))
                            .labelsHidden()
                            .onSubmit(save)
                        Button("Paste") { pasteAndSave() }
                            .help("Paste the key from the clipboard and save it")
                        Button("Save", action: save)
                            .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if isReplacing {
                            Button("Cancel") { isReplacing = false; keyInput = "" }
                        }
                    }
                }
            }
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Stored only in this Mac's Keychain. Never written to the project or synced, so it can't reach GitHub. After saving, the copied key is also removed from CopyPaster's history and the clipboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func pasteAndSave() {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            status = "Clipboard is empty — copy your key first"
            return
        }
        keyInput = text
        save()
    }

    private func save() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if !key.hasPrefix("sk-ant-") {
            status = "That doesn't look like a Claude key (should start with sk-ant-)"
            return
        }
        if manager.saveClaudeKey(key) {
            status = "Key saved to Keychain"
            isReplacing = false
        } else {
            status = "Couldn't save to Keychain"
        }
        keyInput = ""
    }
}
