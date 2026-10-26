import XCTest
@testable import WB2API

/// 配置编辑：路径读写、原生分区不能让其他键消失、时点/时长格式校验。
final class ConfigEditorTests: XCTestCase {
    @MainActor
    private func makeEditor(_ raw: String) throws -> ConfigEditor {
        let payload = #"{"config":\#(raw),"path":"/tmp/config.json"}"#
        let response = try JSONDecoder().decode(ConfigResponse.self, from: Data(payload.utf8))
        let editor = ConfigEditor()
        editor.load(response)
        return editor
    }

    @MainActor
    func testNestedPathReadAndWrite() throws {
        let editor = try makeEditor("""
        {
          "listen": ":8321",
          "schedule": {"checkin_enabled": true, "checkin_hours": [9, 21]},
          "pool": {"max_in_flight": 2}
        }
        """)

        XCTAssertEqual(editor.value(at: ["schedule", "checkin_hours"]),
                       .array([.int(9), .int(21)]))
        XCTAssertEqual(editor.value(at: ["missing", "key"]), .null)

        editor.setValue(.array([.int(10)]), at: ["schedule", "checkin_hours"])

        XCTAssertEqual(editor.value(at: ["schedule", "checkin_hours"]), .array([.int(10)]))
        XCTAssertEqual(editor.value(at: ["schedule", "checkin_enabled"]), .bool(true))
        XCTAssertEqual(editor.value(at: ["listen"]), .string(":8321"))
    }

    @MainActor
    func testCuratedSectionLeavesUnmappedKeysVisible() throws {
        let editor = try makeEditor("""
        {
          "schedule": {
            "checkin_enabled": true,
            "checkin_hours": [9],
            "blackcat_enabled": false,
            "task_sweep_minutes": 30
          },
          "pool": {"max_in_flight": 2, "reserve_credits": 100}
        }
        """)

        let schedule = editor.remainingFields(in: "schedule", excluding: ConfigSchema.curatedPaths)
        XCTAssertEqual(schedule.map(\.key), ["blackcat_enabled", "task_sweep_minutes"])

        let pool = editor.remainingFields(in: "pool", excluding: ConfigSchema.curatedPaths)
        XCTAssertEqual(pool.map(\.key), ["reserve_credits"])

        let groups = editor.uncuratedGroups(excluding: ConfigSchema.curatedPaths)
        XCTAssertEqual(groups.map(\.key), ["pool", "schedule"])
    }

    @MainActor
    func testFullyCuratedGroupDisappearsFromRawList() throws {
        let editor = try makeEditor("""
        {"cooldown": {"soft_rate": "600s", "soft_rate_max": "2h"}}
        """)

        XCTAssertTrue(editor.remainingFields(in: "cooldown", excluding: ConfigSchema.curatedPaths).isEmpty)
        XCTAssertTrue(editor.uncuratedGroups(excluding: ConfigSchema.curatedPaths).isEmpty)
    }

    @MainActor
    func testInvalidFieldTracking() throws {
        let editor = try makeEditor(#"{"schedule":{}}"#)
        XCTAssertFalse(editor.hasInvalidFields)

        editor.setInvalid("checkin_hours", true)
        XCTAssertTrue(editor.hasInvalidFields)

        editor.setInvalid("checkin_hours", false)
        XCTAssertFalse(editor.hasInvalidFields)
    }

    func testHoursParser() {
        XCTAssertEqual(ConfigValueParser.hours("9, 21"), [9, 21])
        XCTAssertEqual(ConfigValueParser.hours("9，21"), [9, 21])
        XCTAssertEqual(ConfigValueParser.hours(" 0 , 23 "), [0, 23])
        XCTAssertEqual(ConfigValueParser.hours("9, 9"), [9])

        XCTAssertNil(ConfigValueParser.hours(""))
        XCTAssertNil(ConfigValueParser.hours("24"))
        XCTAssertNil(ConfigValueParser.hours("9,,21"))
        XCTAssertNil(ConfigValueParser.hours("abc"))
    }

    func testDurationParser() {
        for value in ["0", "600s", "10m", "2h", "1h30m", "500ms", "1.5h"] {
            XCTAssertTrue(ConfigValueParser.isValidDuration(value), value)
        }
        for value in ["", "5", "2H", "abc", "1h 30m"] {
            XCTAssertFalse(ConfigValueParser.isValidDuration(value), value)
        }
    }
}
