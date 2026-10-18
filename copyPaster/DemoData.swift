import AppKit

/// Sample history shown in demo mode (see ClipboardManager.isDemo).
enum DemoData {
    static var items: [ClipboardItem] {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            ClipboardItem(id: UUID(), contentType: .text,
                          textContent: "git commit -m \"Add Liquid Glass UI\" && git push",
                          timestamp: ago(1), isPinned: true),
            ClipboardItem(id: UUID(), contentType: .text,
                          textContent: "Release notes are up: https://developer.apple.com/documentation/swiftui",
                          timestamp: ago(4), isPinned: false),
            ClipboardItem(id: UUID(), contentType: .text, textContent: "Tr0ub4dor&3xK!",
                          timestamp: ago(6), isPinned: false, passwordFlag: .concealed),
            ClipboardItem(id: UUID(), contentType: .text, textContent: "mQ7#vL2pX9!z",
                          timestamp: ago(7), isPinned: false),
            ClipboardItem(id: UUID(), contentType: .image, imageData: sampleImagePNG(),
                          timestamp: ago(9), isPinned: false),
            ClipboardItem(id: UUID(), contentType: .filePath,
                          textContent: "/Applications/Xcode.app\n/usr/local/bin",
                          timestamp: ago(15), isPinned: false),
            ClipboardItem(id: UUID(), contentType: .text,
                          textContent: "let greeting = \"Hello, CopyPaster!\"\nprint(greeting)",
                          timestamp: ago(32), isPinned: false),
            ClipboardItem(id: UUID(), contentType: .filePath,
                          textContent: "/Library/Desktop Pictures",
                          timestamp: ago(60), isPinned: false),
        ]
    }

    /// A gradient card with a symbol, so the demo needs no image from disk.
    private static func sampleImagePNG() -> Data? {
        let size = NSSize(width: 480, height: 240)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [.systemGray, .darkGray])?.draw(in: rect, angle: 20)
            let config = NSImage.SymbolConfiguration(pointSize: 96, weight: .semibold)
                .applying(.init(paletteColors: [.white]))
            if let symbol = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let s = symbol.size
                symbol.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2,
                                       width: s.width, height: s.height))
            }
            return true
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
