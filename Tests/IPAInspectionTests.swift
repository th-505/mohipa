import Foundation
import XCTest
@testable import mohipa

final class IPAInspectionTests: XCTestCase {
    func testReadsMetadataFromAppPayload() throws {
        let info = try IPAInspection.read(fixture("valid"))
        XCTAssertEqual(info.bundleID, "com.mohipa.sample")
        XCTAssertEqual(info.name, "Sample")
        XCTAssertEqual(info.version, "1.2")
        XCTAssertEqual(info.build, "42")
        XCTAssertEqual(info.minimumOS, "15.0")
    }

    func testRejectsZipWithoutAppPayload() throws {
        let url = try fixture("plain-zip")
        XCTAssertThrowsError(try IPAInspection.read(url))
    }

    func testRejectsAppPayloadWithoutBundleID() throws {
        let url = try fixture("missing-id")
        XCTAssertThrowsError(try IPAInspection.read(url))
    }

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "ipa"))
    }
}
