import XCTest
@testable import WB2API

/// 强调色选项：设置页至少要能选到粉色/蓝色/黄色/玫红。
final class AppThemeTests: XCTestCase {
    func testRequiredAccentChoicesExist() {
        let titles = Set(AccentChoice.allCases.map(\.title))
        XCTAssertTrue(titles.isSuperset(of: ["粉色", "蓝色", "黄色", "玫红"]))
    }

    func testDefaultThemeIsViolet() {
        XCTAssertEqual(AppTheme.defaultTheme.accent, .violet)
    }

    func testRawValueRoundTrip() {
        for choice in AccentChoice.allCases {
            XCTAssertEqual(AccentChoice(rawValue: choice.rawValue), choice)
        }
    }
}
