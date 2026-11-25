import Foundation
import XCTest
@testable import mohipa

final class IPAChecksumTests: XCTestCase {
    func testAcceptsMatchingDigestAndRejectsMismatch() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("abc".utf8).write(to: url)
        try IPAChecksum.verify(url, expected: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertThrowsError(try IPAChecksum.verify(url, expected: String(repeating: "0", count: 64)))
    }

    func testRejectsMalformedDigestAndAllowsMissingDigest() throws {
        XCTAssertNil(try IPAChecksum.expected(" "))
        XCTAssertThrowsError(try IPAChecksum.expected(String(repeating: "z", count: 64)))
    }
}
