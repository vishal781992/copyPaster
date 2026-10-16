import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
class ClipboardManager {
    static let shared = ClipboardManager()

    var items: [ClipboardItem] = []
    var showToast = false
    var toastMessage = ""
    var isPaused = false

    private var timer: Timer?
    private var activityToken: NSObjectProtocol?
    private var lastChangeCount: Int = 0
    private let maxItems = 500
    private let storageURL: URL

    /// Where clipboard images (screenshots snapped with Cmd-Ctrl-Shift-4) get written.
    static let defaultImageDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/Screenshots", isDirectory: true).path
    private static let imageDirectoryKey = "imageSaveDirectory"

    var imageSaveDirectory: URL {
        get {
            let path = UserDefaults.standard.string(forKey: Self.imageDirectoryKey) ?? Self.defaultImageDirectory
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: Self.imageDirectoryKey)
        }
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("copyPaster", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        storageURL = appDir.appendingPathComponent("clipboard_history.json")
        loadItems()
        lastChangeCount = NSPasteboard.general.changeCount
        // Keep App Nap from throttling the poll timer while we sit in the background
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Clipboard monitoring"
        )
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
        // .common so the timer keeps firing while a menu or scroll is tracking
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func togglePause() {
        isPaused.toggle()
        // Sync lastChangeCount when resuming so we don't capture what happened while paused
        if !isPaused {
            lastChangeCount = NSPasteboard.general.changeCount
        }
    }

    private func checkClipboard() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // File URLs first — Finder copies include a preview image so this must run before the image check
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL], !urls.isEmpty {
            captureFilePaths(urls)
            return
        }

        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            // Check if there's also text — if so, prefer text (avoids capturing styled text as image)
            if pasteboard.string(forType: .string) != nil {
                captureText(from: pasteboard)
            } else {
                let bitmap = NSBitmapImageRep(data: tiff)
                if let png = bitmap?.representation(using: .png, properties: [:]) {
                    let path = writeImageToDisk(png)
                    addItem(ClipboardItem(
                        id: UUID(), contentType: .image, textContent: nil,
                        imageData: png, imagePath: path, timestamp: Date(), isPinned: false
                    ))
                }
            }
        } else {
            captureText(from: pasteboard)
        }
    }

    private func captureFilePaths(_ urls: [URL]) {
        // Single file that macOS identifies as an image → load and store as image tile
        if urls.count == 1, let url = urls.first {
            let ext = url.pathExtension.lowercased()
            if let utType = UTType(filenameExtension: ext), utType.conforms(to: .image),
               let image = NSImage(contentsOf: url),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                addItem(ClipboardItem(id: UUID(), contentType: .image, textContent: nil,
                                      imageData: png, imagePath: url.path,
                                      timestamp: Date(), isPinned: false))
                return
            }
        }

        // Everything else (non-image files, or multiple files) → store full path(s)
        let paths = urls.map { $0.path }.joined(separator: "\n")
        if let idx = items.firstIndex(where: { !$0.isPinned && $0.contentType == .filePath && $0.textContent == paths }) {
            items[idx].timestamp = Date()
            sortItems()
            saveItems()
            return
        }
        addItem(ClipboardItem(id: UUID(), contentType: .filePath, textContent: paths,
                              imageData: nil, timestamp: Date(), isPinned: false))
    }

    private func captureText(from pasteboard: NSPasteboard) {
        // Grab any text type and strip to plain text
        guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        recordWeblinks(in: text)

        // Duplicate detection: if last non-pinned item has same text, just update timestamp
        if let idx = items.firstIndex(where: { !$0.isPinned && $0.contentType == .text && $0.textContent == text }) {
            items[idx].timestamp = Date()
            sortItems()
            saveItems()
            return
        }

        addItem(ClipboardItem(
            id: UUID(), contentType: .text, textContent: text,
            imageData: nil, timestamp: Date(), isPinned: false
        ))
    }

    private func addItem(_ item: ClipboardItem) {
        items.append(item)
        enforceLimit()
        saveItems()
        switch item.contentType {
        case .text:     triggerToast("Text captured")
        case .image:    triggerToast(item.imagePath != nil ? "Image saved" : "Image captured")
        case .filePath: triggerToast("Path captured")
        }
    }

    private func enforceLimit() {
        // Sort before trimming — prefix() keeps the newest only if the array is already
        // newest-first, and addItem() appends to the end.
        let pinned = items.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        var unpinned = items.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        if unpinned.count > maxItems {
            unpinned = Array(unpinned.prefix(maxItems))
        }
        items = pinned + unpinned
    }

    private func sortItems() {
        let pinned = items.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        items = pinned + unpinned
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.contentType {
        case .text, .filePath:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }
        lastChangeCount = pasteboard.changeCount // prevent re-capture
    }

    /// Puts the image's on-disk path on the pasteboard as plain text. Writes the file first if it
    /// isn't on disk yet (old history items, or a file the user moved/deleted).
    func copyImagePath(_ item: ClipboardItem) {
        guard item.contentType == .image else { return }
        var path = item.imagePath
        if path == nil || !FileManager.default.fileExists(atPath: path!) {
            guard let data = item.imageData, let written = writeImageToDisk(data, date: item.timestamp) else {
                triggerToast("Couldn't save image file")
                return
            }
            path = written
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].imagePath = written
                saveItems()
            }
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path!, forType: .string)
        lastChangeCount = pasteboard.changeCount // prevent re-capture
        triggerToast("Path copied")
    }

    func revealImageInFinder(_ item: ClipboardItem) {
        guard let path = item.imagePath, FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func openTerminal(at directory: URL) {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            triggerToast("Folder no longer exists")
            return
        }
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            triggerToast("Terminal not found")
            return
        }
        // Opening a folder with Terminal starts a new window with that folder as the working directory.
        NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            print("Failed to open Terminal at \(directory.path): \(error)")
            Task { @MainActor in ClipboardManager.shared.triggerToast("Couldn't open Terminal") }
        }
    }

    /// Writes PNG data into imageSaveDirectory, returning the absolute path (nil on failure).
    @discardableResult
    private func writeImageToDisk(_ png: Data, date: Date = Date()) -> String? {
        let dir = imageSaveDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create image directory \(dir.path): \(error)")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "Screenshot \(formatter.string(from: date))"

        // Same-second captures would collide — suffix until we find a free name
        var url = dir.appendingPathComponent("\(base).png")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base) (\(counter)).png")
            counter += 1
        }

        do {
            try png.write(to: url, options: .atomic)
            return url.path
        } catch {
            print("Failed to write image to \(url.path): \(error)")
            return nil
        }
    }

    // MARK: - Weblinks

    /// Every http(s) link copied gets recorded here, so it survives clearing or trimming the history.
    /// HTML so the links are clickable — it opens in the browser.
    static let weblinksFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("Weblinks.html")

    /// Earlier versions wrote a Markdown file; its entries are imported once when the HTML file doesn't exist yet.
    private static let legacyWeblinksFileURL = weblinksFileURL
        .deletingPathExtension().appendingPathExtension("md")

    private struct WeblinkEntry {
        let stamp: String
        let url: String
    }

    /// Records links from copied text in the Weblinks file, newest first, skipping ones already in it.
    private func recordWeblinks(in text: String) {
        let urls = ClipboardItem.extractWebURLs(from: text)
        guard !urls.isEmpty else { return }

        let fileURL = Self.weblinksFileURL
        let entries = loadWeblinkEntries()
        let known = Set(entries.map(\.url))
        let newURLs = urls.filter { !known.contains($0.absoluteString) }
        guard !newURLs.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = formatter.string(from: Date())
        // Within one copy, keep the links in the order they appeared in the text.
        let added = newURLs.map { WeblinkEntry(stamp: stamp, url: $0.absoluteString) }

        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try renderWeblinks(added + entries).write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write weblinks to \(fileURL.path): \(error)")
        }
    }

    /// Entries in file order (newest first). Reads the legacy Markdown file (oldest first) if there's no HTML file yet.
    private func loadWeblinkEntries() -> [WeblinkEntry] {
        if let html = try? String(contentsOf: Self.weblinksFileURL, encoding: .utf8) {
            // Entry lines look like: <li><span class="t">2026-10-09 14:32</span> <a href="…" …>…</a></li>
            let regex = /<li><span class="t">([^<]*)<\/span> <a href="([^"]*)"/
            return html.split(separator: "\n").compactMap { line in
                guard let m = line.firstMatch(of: regex) else { return nil }
                return WeblinkEntry(stamp: String(m.1), url: Self.unescapeHTML(String(m.2)))
            }
        }
        guard let md = try? String(contentsOf: Self.legacyWeblinksFileURL, encoding: .utf8) else { return [] }
        // Entries look like "- 2026-10-09 14:32 — <url>"
        let entries: [WeblinkEntry] = md.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("- ") else { return nil }
            let parts = line.dropFirst(2).components(separatedBy: " — ")
            guard parts.count == 2 else { return nil }
            return WeblinkEntry(stamp: parts[0].trimmingCharacters(in: .whitespaces),
                                url: parts[1].trimmingCharacters(in: .whitespaces))
        }
        return entries.reversed()
    }

    private func renderWeblinks(_ entries: [WeblinkEntry]) -> String {
        var html = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>Weblinks</title>
        <style>
        :root { color-scheme: light dark; }
        body { font: 14px -apple-system, system-ui, sans-serif; max-width: 860px; margin: 32px auto; padding: 0 16px; }
        p { color: GrayText; }
        ul { list-style: none; padding: 0; }
        li { padding: 6px 0; border-bottom: 1px solid color-mix(in srgb, CanvasText 10%, transparent); overflow-wrap: anywhere; }
        .t { color: GrayText; font-variant-numeric: tabular-nums; margin-right: 8px; }
        </style></head><body>
        <h1>Weblinks</h1>
        <p>Links copied with CopyPaster, newest first.</p>
        <ul>

        """
        for entry in entries {
            let url = Self.escapeHTML(entry.url)
            html += "<li><span class=\"t\">\(Self.escapeHTML(entry.stamp))</span> <a href=\"\(url)\" target=\"_blank\">\(url)</a></li>\n"
        }
        html += "</ul>\n</body></html>\n"
        return html
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func unescapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func openWeblinksFile() {
        let fileURL = Self.weblinksFileURL
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let legacy = loadWeblinkEntries()
            if !legacy.isEmpty {
                try? renderWeblinks(legacy).write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            triggerToast("No links saved yet")
            return
        }
        NSWorkspace.shared.open(fileURL)
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func togglePin(_ item: ClipboardItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isPinned.toggle()
            sortItems()
            saveItems()
        }
    }

    func clearAll() {
        items.removeAll()
        saveItems()
    }

    func addManualText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = items.firstIndex(where: { !$0.isPinned && $0.contentType == .text && $0.textContent == trimmed }) {
            items[idx].timestamp = Date()
            sortItems()
            saveItems()
            triggerToast("Already in history")
            return
        }
        let item = ClipboardItem(id: UUID(), contentType: .text, textContent: trimmed,
                                 imageData: nil, timestamp: Date(), isPinned: false)
        items.append(item)
        enforceLimit()
        saveItems()
        triggerToast("Snippet added")
    }

    private func triggerToast(_ message: String) {
        toastMessage = message
        showToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            self.showToast = false
        }
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    private func loadItems() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
}
