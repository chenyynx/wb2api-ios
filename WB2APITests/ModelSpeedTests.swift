import XCTest
@testable import WB2API

/// 模型测速：SSE 解析与 tok/s 计算都是纯函数，单独锁住格式兼容性。
final class ModelSpeedTests: XCTestCase {
    func testParseContentChunk() {
        let line = #"data: {"choices":[{"delta":{"content":"你"}}]}"#
        XCTAssertEqual(
            ChatStreamParser.parse(line: line),
            .chunk(ChatStreamChunk(text: "你", completionTokens: nil))
        )
    }

    func testParseReasoningChunk() {
        let line = #"data: {"choices":[{"delta":{"reasoning_content":"思考"}}]}"#
        XCTAssertEqual(
            ChatStreamParser.parse(line: line),
            .chunk(ChatStreamChunk(text: "思考", completionTokens: nil))
        )
    }

    func testParseUsageChunk() {
        let line = #"data: {"choices":[],"usage":{"completion_tokens":128}}"#
        XCTAssertEqual(
            ChatStreamParser.parse(line: line),
            .chunk(ChatStreamChunk(text: nil, completionTokens: 128))
        )
    }

    func testParseDoneAndIgnoredLines() {
        XCTAssertEqual(ChatStreamParser.parse(line: "data: [DONE]"), .done)
        XCTAssertNil(ChatStreamParser.parse(line: "event: message"))
        XCTAssertNil(ChatStreamParser.parse(line: ""))
        XCTAssertNil(ChatStreamParser.parse(line: #"data: {"choices":[]}"#))
    }

    func testParseErrorEvent() {
        let line = #"data: {"error":{"message":"boom"}}"#
        XCTAssertEqual(ChatStreamParser.parse(line: line), .failure("boom"))
    }

    func testTokensPerSecondUsesOnlyGenerationWindow() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let speed = try XCTUnwrap(
            SpeedMath.tokensPerSecond(tokens: 256, from: start, to: start.addingTimeInterval(2))
        )
        XCTAssertEqual(speed, 128, accuracy: 0.0001)
    }

    func testTokensPerSecondRejectsEmptyOrZeroWindow() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(SpeedMath.tokensPerSecond(tokens: 0, from: start, to: start.addingTimeInterval(2)))
        XCTAssertNil(SpeedMath.tokensPerSecond(tokens: 10, from: start, to: start))
        XCTAssertNil(SpeedMath.tokensPerSecond(tokens: 10, from: start, to: start.addingTimeInterval(-1)))
    }

    func testResultCodableRoundTrip() throws {
        let result = ModelSpeedResult(
            modelID: "cn:test-model",
            tokensPerSecond: 123.4,
            ttfbMs: 850,
            totalMs: 3_200,
            completionTokens: 256,
            estimated: false,
            measuredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ModelSpeedResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
