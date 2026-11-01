import XCTest
@testable import WB2API

/// 忽略登录提醒：存取与状态判定。
final class IgnoredWarningsTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: IgnoredWarnings.storageKey)
        super.tearDown()
    }

    func testIgnoreAndRestoreRoundTrip() {
        XCTAssertFalse(IgnoredWarnings.isIgnored("uid-a"))
        IgnoredWarnings.ignore("uid-a")
        XCTAssertTrue(IgnoredWarnings.isIgnored("uid-a"))

        IgnoredWarnings.restore("uid-a")
        XCTAssertFalse(IgnoredWarnings.isIgnored("uid-a"))
    }

    func testPersistenceAcrossInstances() {
        IgnoredWarnings.ignore("uid-1")
        IgnoredWarnings.ignore("uid-2")
        // 重新从 UserDefaults 读，模拟重启
        let set = IgnoredWarnings.load()
        XCTAssertEqual(set, ["uid-1", "uid-2"])
    }

    func testRestoreUnknownUIDIsNoOp() {
        IgnoredWarnings.restore("never-added")
        XCTAssertTrue(IgnoredWarnings.load().isEmpty)
    }
}
