import CryptoKit
import Foundation

enum IPAChecksum {
    static func expected(_ input: String) throws -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        guard value.utf8.count == 64,
              value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw ChecksumError.invalidFormat
        }
        return value
    }

    static func verify(_ url: URL, expected: String) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", Int($0)) }.joined()
        guard actual == expected else { throw ChecksumError.mismatch }
    }
}

private enum ChecksumError: LocalizedError {
    case invalidFormat, mismatch

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "أدخل بصمة SHA-256 مكونة من 64 خانة أو اترك الحقل فارغًا."
        case .mismatch: return "بصمة الملف لا تطابق البصمة المدخلة. لم يُحفظ الملف."
        }
    }
}
