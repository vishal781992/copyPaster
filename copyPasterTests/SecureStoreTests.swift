import Foundation
import CryptoKit
import Testing
@testable import copyPaster

/// Uses an in-memory key so nothing touches the real Keychain or history.
struct SecureStoreTests {
    private let secure = SecureStore(key: SymmetricKey(size: .bits256))

    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func item(_ text: String) -> ClipboardItem {
        ClipboardItem(id: UUID(), contentType: .text, textContent: text,
                      imageData: nil, timestamp: Date(timeIntervalSince1970: 1_800_000_000), isPinned: false)
    }

    @Test func roundTrip() throws {
        let plaintext = Data("hunter2".utf8)
        let sealed = try secure.seal(plaintext)
        #expect(SecureStore.isEncrypted(sealed))
        #expect(sealed.range(of: plaintext) == nil)
        #expect(try secure.open(sealed) == plaintext)
    }

    @Test func tamperedDataFails() throws {
        var sealed = try secure.seal(Data("hunter2".utf8))
        sealed[sealed.count - 1] ^= 0xFF
        #expect(throws: (any Error).self) { try secure.open(sealed) }
    }

    @Test func wrongKeyFails() throws {
        let sealed = try secure.seal(Data("hunter2".utf8))
        let other = SecureStore(key: SymmetricKey(size: .bits256))
        #expect(throws: (any Error).self) { try other.open(sealed) }
    }

    @Test func saveWritesNoPlaintextWithOwnerOnlyPermissions() throws {
        let store = HistoryStore(directory: try tempDirectory(), secure: secure)
        try store.save([item("my-secret-password")])

        let data = try Data(contentsOf: store.fileURL)
        #expect(data.range(of: Data("my-secret-password".utf8)) == nil)
        let perms = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)[.posixPermissions] as? Int
        #expect(perms == 0o600)
        #expect(store.load().map(\.textContent) == ["my-secret-password"])
    }

    @Test func migratesPlaintextHistory() throws {
        let store = HistoryStore(directory: try tempDirectory(), secure: secure)
        try JSONEncoder().encode([item("old-password")]).write(to: store.legacyURL)

        #expect(store.load().map(\.textContent) == ["old-password"])
        #expect(!FileManager.default.fileExists(atPath: store.legacyURL.path))
        let data = try Data(contentsOf: store.fileURL)
        #expect(SecureStore.isEncrypted(data))
        #expect(data.range(of: Data("old-password".utf8)) == nil)
    }

    @Test func unreadableHistoryIsMovedAside() throws {
        let dir = try tempDirectory()
        try HistoryStore(directory: dir, secure: secure).save([item("secret")])

        let otherKey = HistoryStore(directory: dir, secure: SecureStore(key: SymmetricKey(size: .bits256)))
        #expect(otherKey.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: otherKey.fileURL.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains { $0.hasPrefix("clipboard_history.enc.corrupt-") })
    }
}
