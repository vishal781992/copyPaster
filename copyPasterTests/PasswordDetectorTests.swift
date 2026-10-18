import Foundation
import Testing
@testable import copyPaster

struct PasswordDetectorTests {
    @Test(arguments: [
        "Password1!",
        "Tr0ub4dor&3",
        "mQ7#vL2pX9!z",
        "4$mK9!pQxZ",
        "correct-Horse-7",
        "key_live_51HxQz8KjT9vR2mWpLcN4aBd",   // API key without enough symbols
        "tok_8fK2mQ9xLp4vR7tY1nB6cW3zA5dE0sH2",
    ])
    func flagsSecrets(_ text: String) {
        #expect(PasswordDetector.isLikelySecret(text))
    }

    @Test(arguments: [
        "hello",                                   // too short
        "The weather is nice today!",              // has spaces
        "https://example.com/a?b=C1",              // URL
        "www.Example1.com",
        "John.Smith1@example.com",                 // email
        "/Users/me/Projects/App1",                 // path
        "~/Documents/Report-2024",
        "2026-10-18T12:20:00",                     // date
        "+1 (555) 123-4567",
        "v2.1.0-beta.3",                           // version
        "3F2504E0-4F89-11D3-9A0C-0305E82C3301",    // UUID
        "max_items_limit",                         // snake_case
        "MAX_ITEMS_2",
        "clipboardManager2",                       // camelCase
        "NSPasteboard.general",                    // dotted code
        "Report_2024-Final.pdf",                   // file name
        "7e42a9b1c3d4e5f60718293a4b5c6d7e8f901234", // git SHA (hex)
        "aaaaaaaaaaA1!",                           // repetitive
    ])
    func ignoresOrdinaryText(_ text: String) {
        #expect(!PasswordDetector.isLikelySecret(text))
    }

    @Test func maskHidesLength() {
        var short = ClipboardItem(id: UUID(), contentType: .text, textContent: "Ab3!efgh",
                                  imageData: nil, timestamp: .now, isPinned: false)
        var long = short
        long.textContent = "Ab3!efghijklmnopqrstuvwxyz0123"
        short.detectPassword()
        long.detectPassword()
        #expect(short.isMasked && long.isMasked)
        #expect(short.maskedPreview == "A••••••••")
        #expect(short.maskedPreview == long.maskedPreview)
    }

    @Test func userChoiceSurvivesRedetection() {
        var item = ClipboardItem(id: UUID(), contentType: .text, textContent: "Password1!",
                                 imageData: nil, timestamp: .now, isPinned: false, passwordFlag: .userCleared)
        item.detectPassword()
        #expect(!item.isMasked)

        item.textContent = "plain words"
        item.passwordFlag = .userMarked
        item.detectPassword()
        #expect(item.isMasked)
    }
}

struct PasswordExpiryTests {
    private func item(_ text: String, hoursAgo: Double, pinned: Bool = false, flag: PasswordFlag? = nil) -> ClipboardItem {
        var item = ClipboardItem(id: UUID(), contentType: .text, textContent: text, imageData: nil,
                                 timestamp: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
                                 isPinned: pinned, passwordFlag: flag)
        item.detectPassword()
        return item
    }

    @Test func onlyUnpinnedPasswordsExpire() {
        let lifetime = 24
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldPassword = item("Password1!", hoursAgo: 25)
        let freshPassword = item("Password1!", hoursAgo: 23)
        let pinnedPassword = item("Password1!", hoursAgo: 25, pinned: true)
        let oldText = item("just some old notes", hoursAgo: 500)
        let cleared = item("Password1!", hoursAgo: 25, flag: .userCleared)

        func expired(_ i: ClipboardItem) -> Bool { i.passwordExpiry(lifetimeHours: lifetime).map { $0 < now } ?? false }
        #expect(expired(oldPassword))
        #expect(!expired(freshPassword))
        #expect(!expired(pinnedPassword))
        #expect(!expired(oldText))
        #expect(!expired(cleared))
        #expect(oldPassword.passwordExpiry(lifetimeHours: 0) == nil)
    }
}
