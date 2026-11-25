import XCTest
@testable import mohipa

final class AppStoreLinkTests: XCTestCase {
    func testRecognizesCastXAndThaiStorefront() throws {
        let link = try XCTUnwrap(AppStoreLink(
            "https://apps.apple.com/th/app/chromecast-video-cast-castx/id6739633401"
        ))
        XCTAssertEqual(link.appID, "6739633401")
        XCTAssertEqual(link.country, "TH")
    }

    func testLeavesDirectDownloadsAndOtherHostsAlone() {
        XCTAssertNil(AppStoreLink("https://example.com/releases/CastX.ipa"))
        XCTAssertNil(AppStoreLink("https://apps.apple.com.example.com/th/app/castx/id6739633401"))
    }
}
