import XCTest
@testable import WB2API

/// 展示层字段映射：接口给 uid，界面要昵称；已领取的任务不该再出现在待办里。
final class DisplayMappingTests: XCTestCase {
    private func decode(_ raw: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
    }

    func testUsageGroupPrefersNicknameThenExtraThenRealm() throws {
        let nickname = try JSONDecoder().decode(
            UsageGroup.self,
            from: Data(#"{"key":"uid-1","nickname":"阿七","extra":"旧名","realm":"cn"}"#.utf8)
        )
        XCTAssertEqual(nickname.displayName, "阿七")

        let extra = try JSONDecoder().decode(
            UsageGroup.self,
            from: Data(#"{"key":"uid-1","extra":"账号07","realm":"cn"}"#.utf8)
        )
        XCTAssertEqual(extra.displayName, "账号07")

        let realm = try JSONDecoder().decode(
            UsageGroup.self,
            from: Data(#"{"key":"cn"}"#.utf8)
        )
        XCTAssertEqual(realm.displayName, "国内版")
    }

    func testSingleAccountTasksSkipClaimed() throws {
        let raw = """
        {"ok":true,"tasks":[
          {"task_code":"a","title":"已领取","accept_status":"claimed","claimed":true},
          {"task_code":"b","title":"可领","accept_status":"completed","has_reward":true,"credit":30},
          {"task_code":"c","title":"待做"}
        ]}
        """
        let tasks = AccountTaskParser.fromSingle(
            try decode(raw),
            uid: "u1",
            nickname: "阿七",
            realm: "cn"
        )
        XCTAssertEqual(tasks.map(\.code), ["b", "c"])
        XCTAssertTrue(tasks[0].canClaim)
        XCTAssertTrue(tasks[1].canAccept)
        XCTAssertFalse(tasks[0].canAccept)
    }

    func testClaimedTaskIsNotAcceptable() {
        let task = AccountTask(
            uid: "u1",
            nickname: "阿七",
            realm: "cn",
            code: "a",
            title: "已领取",
            description: nil,
            acceptStatus: "claimed",
            current: 1,
            target: 1,
            hasReward: true,
            credit: 10,
            claimed: true
        )
        XCTAssertFalse(task.canAccept)
        XCTAssertFalse(task.canClaim)
    }

    func testConfigSaveSummaryMentionsRestartFields() {
        let response = ConfigSaveResponse(
            ok: true,
            restartRequired: ["listen"],
            apiKeyEnvManaged: false,
            environmentManagedFields: []
        )
        XCTAssertTrue(response.summary.contains("listen"))
        let plain = ConfigSaveResponse(ok: true, restartRequired: [], apiKeyEnvManaged: false, environmentManagedFields: [])
        XCTAssertEqual(plain.summary, "配置已保存")
    }

    func testImportResultParsesCounts() throws {
        let result = ImportResult(try decode(#"{"ok":true,"total":3,"imported":2,"skipped":1,"errors":["x 重复"]}"#))
        XCTAssertEqual(result.total, 3)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.headline, "共 3 条 · 导入 2 · 跳过 1")
        XCTAssertEqual(result.lines.first, "x 重复")
    }

    func testDisabledAccountNeedsLogin() {
        let disabled = Account(
            uid: "u9", nickname: "账号09", credits: 0, creditsTotal: nil, sessionDeadFails: 0,
            creditsEarliestExpiry: nil, creditsEarliestRemaining: nil, creditsExpiryBuckets: nil,
            cooling: false, until: nil, rateLimitedModels: nil, modelOff: nil, realm: "cn",
            disabled: true, paused: nil, disabledReason: "12153 session dead",
            successCount: 0, lastSuccess: nil, lastErr: nil, checkinDone: nil,
            tokenUsage: nil, modelCosts: nil
        )
        XCTAssertTrue(disabled.needsLogin)
        XCTAssertEqual(disabled.actionHint, "12153 session dead")
    }

    func testSessionDeadAccountNeedsLoginEvenIfNotDisabled() {
        let account = Account(
            uid: "u10", nickname: "账号10", credits: 10, creditsTotal: 100, sessionDeadFails: 2,
            creditsEarliestExpiry: nil, creditsEarliestRemaining: nil, creditsExpiryBuckets: nil,
            cooling: false, until: nil, rateLimitedModels: nil, modelOff: nil, realm: "cn",
            disabled: false, paused: nil, disabledReason: nil,
            successCount: 1, lastSuccess: nil, lastErr: nil, checkinDone: nil,
            tokenUsage: nil, modelCosts: nil
        )
        XCTAssertTrue(account.needsLogin)
        XCTAssertTrue(account.actionHint?.contains("重新登录") == true)
    }

    func testPausedAccountIsNotHealthyAndDoesNotNeedLogin() {
        let paused = Account(
            uid: "u11", nickname: "账号11", credits: 100, creditsTotal: 200, sessionDeadFails: 0,
            creditsEarliestExpiry: nil, creditsEarliestRemaining: nil, creditsExpiryBuckets: nil,
            cooling: false, until: nil, rateLimitedModels: nil, modelOff: nil, realm: "cn",
            disabled: false, paused: true, disabledReason: nil,
            successCount: 10, lastSuccess: nil, lastErr: nil, checkinDone: false,
            tokenUsage: nil, modelCosts: nil
        )
        XCTAssertTrue(paused.isPaused)
        XCTAssertFalse(paused.isHealthy)
        XCTAssertFalse(paused.needsLogin)
        XCTAssertEqual(Fmt.accountState(paused), "已暂停")
        XCTAssertTrue(AccountFilter.paused.matches(paused))
        XCTAssertFalse(AccountFilter.healthy.matches(paused))
        XCTAssertTrue(paused.actionHint?.contains("暂停") == true)
    }
}
