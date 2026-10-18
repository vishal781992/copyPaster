import Foundation

/// Guesses whether copied text is a password or secret token, so the tile can be masked.
/// It errs toward hiding: a wrongly masked item costs a click, a missed password is shown on screen.
enum PasswordDetector {
    static let lengthRange = 8...100

    static func isLikelySecret(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard lengthRange.contains(text.count),
              !text.contains(where: { $0.isWhitespace }),
              !looksLikeNonSecret(text) else { return false }

        let classes = characterClasses(in: text)
        let entropy = shannonEntropy(text)

        // Typical password: mixes at least three of upper, lower, digit, symbol and isn't repetitive
        if classes >= 3 && entropy >= log2(Double(text.count)) * 0.75 {
            return true
        }
        // Long random tokens (API keys) often skip symbols. Above 4 bits/char rules out hex hashes.
        let hasLetter = text.contains(where: \.isLetter)
        let hasDigit = text.contains(where: \.isNumber)
        return text.count >= 20 && hasLetter && hasDigit && entropy > 4.2
    }

    /// Shapes that mix character classes but aren't secrets: links, emails, paths, versions, code, file names.
    private static let nonSecretPatterns: [NSRegularExpression] = [
        #"^[a-z][a-z0-9+.-]*://"#,                                       // any URL scheme
        #"^www\."#,
        #"^[^@]+@[^@]+\.[A-Za-z]{2,}$"#,                                 // email
        #"^(/|~/|\./|\.\./)"#,                                           // file path
        #"^[0-9.,:/+\-]+$"#,                                             // numbers, dates, times, phone numbers
        #"^v?\d+(\.\d+)+([-+][0-9A-Za-z.\-]+)?$"#,                       // version like v2.1.0-beta
        #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, // UUID
        #"^[a-z0-9]+(_[a-z0-9]+)+$"#,                                    // snake_case
        #"^[A-Z0-9]+(_[A-Z0-9]+)+$"#,                                    // SCREAMING_SNAKE
        #"^[a-z]+([A-Z][a-z0-9]+)+$"#,                                   // camelCase
        #"^[A-Za-z_]\w*(\.[A-Za-z_]\w*)+(\(\))?$"#,                      // foo.bar or foo.bar()
        #"^[\w\-]+\.[A-Za-z]{2,5}$"#,                                    // file name like Report_2024.pdf
    ].map { try! NSRegularExpression(pattern: $0) }

    private static func looksLikeNonSecret(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return nonSecretPatterns.contains { $0.firstMatch(in: text, range: range) != nil }
    }

    private static func characterClasses(in text: String) -> Int {
        [text.contains(where: \.isUppercase),
         text.contains(where: \.isLowercase),
         text.contains(where: \.isNumber),
         text.contains(where: { !$0.isLetter && !$0.isNumber })]
            .filter { $0 }.count
    }

    /// Bits per character.
    static func shannonEntropy(_ text: String) -> Double {
        let counts = Dictionary(text.map { ($0, 1) }, uniquingKeysWith: +)
        let n = Double(text.count)
        return -counts.values.reduce(0) { sum, c in
            let p = Double(c) / n
            return sum + p * log2(p)
        }
    }
}
