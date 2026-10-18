import Foundation
import CryptoKit
import Security

/// AES-GCM encryption for data at rest. The 256-bit key lives in the login Keychain, never on disk.
struct SecureStore {
    let key: SymmetricKey

    /// Leading bytes of every encrypted file, so plaintext history from older versions can be told apart.
    static let magic = Data("CPENC1".utf8)

    enum Failure: Error {
        case notEncrypted
        case keychain(OSStatus)
    }

    func seal(_ plaintext: Data) throws -> Data {
        // combined is nonce + ciphertext + tag; only nil for non-standard nonce sizes
        Self.magic + (try AES.GCM.seal(plaintext, using: key).combined!)
    }

    /// Throws if the data isn't ours, was encrypted with another key, or was tampered with.
    func open(_ data: Data) throws -> Data {
        guard Self.isEncrypted(data) else { throw Failure.notEncrypted }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(Self.magic.count))
        return try AES.GCM.open(box, using: key)
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: magic)
    }

    // MARK: - Keychain

    private static let account = "history-key"

    /// Loads the history key from the login Keychain, creating one on first run.
    /// Throws if the Keychain refuses access (e.g. the user clicked Deny), so callers never replace a key they couldn't read.
    static func keychainKey(service: String = Bundle.main.bundleIdentifier ?? "vish.copyPaster") throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw Failure.keychain(status) }

        let key = SymmetricKey(size: .bits256)
        var add = query
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        add[kSecAttrLabel as String] = "CopyPaster history key"
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw Failure.keychain(addStatus) }
        return key
    }
}

/// Clipboard history on disk, encrypted with a SecureStore.
struct HistoryStore {
    let fileURL: URL
    /// Plaintext file written by versions before encryption; migrated on first load, then deleted.
    let legacyURL: URL
    let secure: SecureStore

    init(directory: URL, secure: SecureStore) {
        fileURL = directory.appendingPathComponent("clipboard_history.enc")
        legacyURL = directory.appendingPathComponent("clipboard_history.json")
        self.secure = secure
    }

    func load() -> [ClipboardItem] {
        let fm = FileManager.default
        if let data = try? Data(contentsOf: fileURL) {
            do {
                let items = try JSONDecoder().decode([ClipboardItem].self, from: secure.open(data))
                // A migration that saved but couldn't delete the plaintext copy leaves it behind
                try? fm.removeItem(at: legacyURL)
                return items
            } catch {
                // Wrong or missing key, or a damaged file. Keep it rather than overwrite it on the next save.
                quarantine(fileURL, error)
                return []
            }
        }

        guard let legacy = try? Data(contentsOf: legacyURL) else { return [] }
        do {
            let items = try JSONDecoder().decode([ClipboardItem].self, from: legacy)
            try save(items)
            try fm.removeItem(at: legacyURL)
            return items
        } catch {
            print("Failed to migrate plaintext clipboard history: \(error)")
            return []
        }
    }

    func save(_ items: [ClipboardItem]) throws {
        let sealed = try secure.seal(JSONEncoder().encode(items))
        try sealed.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// Renames an unreadable file to `<name>.corrupt-<timestamp>` so a fresh history can start beside it.
    private func quarantine(_ url: URL, _ error: Error) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let aside = url.appendingPathExtension("corrupt-\(formatter.string(from: Date()))")
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            print("Couldn't decrypt clipboard history (\(error)); moved it to \(aside.path)")
        } catch {
            print("Couldn't decrypt clipboard history or move it aside: \(error)")
        }
    }
}
