import XCTest
@testable import OpenAcoustic

final class WebControllerTests: XCTestCase {
    func testCSSColorParsing() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(WebController.color(fromCSS: "rgb(13, 17, 23)")!.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual([r, g, b, a].map { Int(($0 * 255).rounded()) }, [13, 17, 23, 255])
        XCTAssertNotNil(WebController.color(fromCSS: "rgba(26, 35, 48, 0.9)"))
        XCTAssertNil(WebController.color(fromCSS: "rgba(0, 0, 0, 0)"))
        XCTAssertNil(WebController.color(fromCSS: ""))
        XCTAssertNil(WebController.color(fromCSS: "transparent"))
    }
}
