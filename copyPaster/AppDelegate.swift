import AppKit
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    /// NSApp.delegate is SwiftUI's adaptor, not this class, so views reach the delegate through here.
    private(set) static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        AppAppearance.current.apply()
        setupMenuBar()
        registerGlobalHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyPaster")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = UserDefaults.standard.bool(forKey: "keepOnTop") ? .applicationDefined : .transient
        popover.contentViewController = NSHostingController(rootView: ContentView().environment(ClipboardManager.shared))
        self.popover = popover
    }

    /// Kept on top, the popover stays open when you click elsewhere and only closes from the menu bar icon or hotkey.
    func setKeepOnTop(_ on: Bool) {
        popover?.behavior = on ? .applicationDefined : .transient
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func registerGlobalHotkey() {
        // ⌘ + Shift + V
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 { // 9 = V
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }
}
