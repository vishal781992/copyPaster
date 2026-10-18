import Foundation
import AppKit

enum ClipboardContentType: String, Codable {
    case text
    case image
    case filePath
}

/// Why a text item is treated as a password. Stored, so the user's own choice survives restarts.
enum PasswordFlag: String, Codable {
    /// A password manager tagged the copy with org.nspasteboard.ConcealedType.
    case concealed
    /// PasswordDetector guessed it. Re-evaluated on load, so it isn't persisted as a decision.
    case detected
    /// User chose "Mark as Password".
    case userMarked
    /// User chose "Not a Password" — never masked again.
    case userCleared
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var contentType: ClipboardContentType
    var textContent: String?
    var imageData: Data?
    /// On-disk location of an image item. Screenshots copied to the clipboard are written to
    /// ClipboardManager.imageSaveDirectory; images copied from Finder keep their original path.
    var imagePath: String? = nil
    var timestamp: Date
    var isPinned: Bool
    var passwordFlag: PasswordFlag? = nil

    /// Masked in the list and left out of search.
    var isMasked: Bool {
        switch passwordFlag {
        case .concealed, .detected, .userMarked: return true
        case .userCleared, nil:                  return false
        }
    }

    /// First character and a fixed run of dots, so the length isn't given away.
    var maskedPreview: String {
        "\(textContent?.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "")••••••••"
    }

    var passwordLabel: String {
        passwordFlag == .detected ? "Might be password" : "Password"
    }

    /// Runs the guess for text items the user hasn't decided on. Called on capture and on load.
    mutating func detectPassword() {
        guard contentType == .text, passwordFlag == nil || passwordFlag == .detected else { return }
        passwordFlag = PasswordDetector.isLikelySecret(textContent ?? "") ? .detected : nil
    }

    var characterCount: Int {
        textContent?.count ?? 0
    }

    var imageSizeDescription: String? {
        guard let data = imageData else { return nil }
        let kb = Double(data.count) / 1024.0
        return kb > 1024 ? String(format: "%.1f MB", kb / 1024.0) : String(format: "%.0f KB", kb)
    }

    var imageFileName: String? {
        guard let path = imagePath else { return nil }
        return (path as NSString).lastPathComponent
    }

    var imageFileExists: Bool {
        guard let path = imagePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var fileCount: Int? {
        guard contentType == .filePath, let text = textContent else { return nil }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    /// Folders a Terminal can be opened in: each copied file's folder (or the folder itself),
    /// or a text item that is just an existing path such as `pwd` output. No duplicates, missing paths skipped.
    var terminalDirectories: [URL] {
        let paths: [String]
        switch contentType {
        case .filePath:
            paths = (textContent ?? "").components(separatedBy: "\n")
        case .text:
            let trimmed = (textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("/") || trimmed.hasPrefix("~"), !trimmed.contains("\n") else { return [] }
            paths = [trimmed]
        case .image:
            return []
        }
        var seen = Set<String>()
        var dirs: [URL] = []
        for raw in paths where !raw.isEmpty {
            let path = (raw as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            let dir = isDir.boolValue ? URL(fileURLWithPath: path) : URL(fileURLWithPath: path).deletingLastPathComponent()
            if seen.insert(dir.path).inserted {
                dirs.append(dir)
            }
        }
        return dirs
    }

    /// http(s) links found in a text item, in order of appearance, without duplicates.
    var webURLs: [URL] {
        guard contentType == .text, let text = textContent else { return [] }
        return Self.extractWebURLs(from: text)
    }

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Only matches that are spelled out as http://, https:// or www. count — NSDataDetector would
    /// otherwise turn things like "config.app" in code snippets into links.
    static func extractWebURLs(from text: String) -> [URL] {
        guard let detector = linkDetector else { return [] }
        let ns = text as NSString
        var seen = Set<String>()
        var urls: [URL] = []
        for match in detector.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            let raw = ns.substring(with: match.range).lowercased()
            guard raw.hasPrefix("http://") || raw.hasPrefix("https://") || raw.hasPrefix("www.") else { continue }
            if seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }
        return urls
    }

    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isPinned == rhs.isPinned &&
        lhs.timestamp == rhs.timestamp &&
        lhs.imagePath == rhs.imagePath &&
        lhs.passwordFlag == rhs.passwordFlag
    }
}
