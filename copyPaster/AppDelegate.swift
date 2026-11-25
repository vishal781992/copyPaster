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

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardManager.shared.flushPendingSave()
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

    /// Hides the popover instantly, then snaps the full screen to the clipboard so it lands in history.
    func takeScreenshot() {
        guard let popover = popover else { return }
        // Skip the fade-out so the popover is gone before the capture fires.
        popover.animates = false
        popover.contentViewController?.view.window?.orderOut(nil)
        popover.performClose(nil)
        popover.animates = true
        // Hand focus back to the app underneath so the shot shows it as it was.
        NSApp.hide(nil)

        // One short beat for the window server to redraw without the popover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-c"]
            try? task.run()
        }
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
