import XCTest
@testable import Drift

final class FocusBlockerTests: XCTestCase {
    func testMatchesHostAndSubdomains() {
        for url in ["https://reddit.com", "https://www.reddit.com/r/swift", "https://OLD.REDDIT.COM:443/", "https://reddit.com./"] {
            XCTAssertTrue(BlockedDomainMatcher.matches(url: url, domain: "reddit.com"), url)
        }
    }

    func testDoesNotBlockMentionsOrLookalikeHosts() {
        for url in ["https://example.com/search?q=reddit.com", "https://example.com/reddit.com", "https://notreddit.com", "https://reddit.com.example.com", "https://reddit.com@example.com"] {
            XCTAssertFalse(BlockedDomainMatcher.matches(url: url, domain: "reddit.com"), url)
        }
    }

    func testExitAndInternalPagesNeverMatch() {
        for url in ["about:blank", "data:text/html,reddit.com", "file:///tmp/reddit.com", "chrome://newtab", "", "reddit.com"] {
            XCTAssertFalse(BlockedDomainMatcher.matches(url: url, domain: "reddit.com"), url)
        }
    }

    @MainActor
    func testBlockedPageEscapesDomainAndProvidesExit() throws {
        let url = try XCTUnwrap(FocusBlocker.blockedPageDataURL(for: "<script>alert(1)</script>"))
        let encoded = try XCTUnwrap(url.split(separator: ",", maxSplits: 1).last)
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded)))
        let html = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertTrue(html.contains("href=\"about:blank\""))
        XCTAssertTrue(html.contains("Leave this page"))
        XCTAssertTrue(html.contains("overflow-y:auto"))
    }
}
