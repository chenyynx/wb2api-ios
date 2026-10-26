import Foundation
import Observation

/// 单个模型的测速结果：tok/s 只算首字之后到流结束，TTFB 单独展示。
struct ModelSpeedResult: Codable, Identifiable, Equatable, Sendable {
    let modelID: String
    let tokensPerSecond: Double
    let ttfbMs: Int
    let totalMs: Int
    let completionTokens: Int
    /// 上游没回 usage 时按 SSE 帧数估算，界面会标「≈」。
    let estimated: Bool
    let measuredAt: Date

    var id: String { modelID }
}

/// 单行状态：未测 / 测试中 / 已有结果 / 失败。
enum ModelSpeedState: Equatable {
    case idle
    case running
    case success
    case failed(String)
}

/// 串行测速器：一次只打一个模型，避免并发互相拖慢、也避免把号池打满。
@MainActor
@Observable
final class ModelSpeedRunner {
    static let prompt = "请写一段约 200 字的中文科普，主题：为什么天空是蓝色的。直接输出正文，不要标题、不要列表、不要解释。"
    static let maxTokens = 256

    private(set) var results: [String: ModelSpeedResult] = [:]
    private(set) var states: [String: ModelSpeedState] = [:]
    private(set) var isRunning = false
    private(set) var currentModelID: String?
    private(set) var completed = 0
    private(set) var total = 0

    private var client: APIClient?
    private var models: [ModelInfo] = []
    private var runTask: Task<Void, Never>?

    private static let storageKey = "wb2api.modelSpeedResults.v1"

    // MARK: 配置

    func configure(client: APIClient, models: [ModelInfo]) {
        self.client = client
        self.models = models
        total = models.count
        if results.isEmpty {
            results = Self.loadResults()
        }
    }

    func state(for model: ModelInfo) -> ModelSpeedState {
        states[model.displayID] ?? .idle
    }

    func result(for model: ModelInfo) -> ModelSpeedResult? {
        results[model.displayID]
    }

    var testedCount: Int {
        models.filter { results[$0.displayID] != nil }.count
    }

    var bestResult: ModelSpeedResult? {
        results.values.max { $0.tokensPerSecond < $1.tokensPerSecond }
    }

    // MARK: 运行

    func startAll() {
        guard !isRunning, !models.isEmpty else { return }
        isRunning = true
        completed = 0
        total = models.count

        let models = self.models
        runTask = Task { [weak self] in
            guard let self else { return }
            for model in models {
                if Task.isCancelled { break }
                await self.measure(model)
                if Task.isCancelled { break }
                self.completed += 1
            }
            self.isRunning = false
            self.currentModelID = nil
            self.runTask = nil
        }
    }

    func start(_ model: ModelInfo) {
        guard !isRunning else { return }
        isRunning = true
        completed = 0
        total = 1

        runTask = Task { [weak self] in
            guard let self else { return }
            await self.measure(model)
            self.completed = 1
            self.isRunning = false
            self.currentModelID = nil
            self.runTask = nil
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        if let id = currentModelID {
            states[id] = .idle
        }
        currentModelID = nil
    }

    // MARK: 单模型测量

    private func measure(_ model: ModelInfo) async {
        guard let client else { return }
        let modelID = model.displayID
        let requestID = model.requestID
        states[modelID] = .running
        currentModelID = modelID

        let startedAt = Date()
        var firstTokenAt: Date?
        var approximateTokens = 0
        var usageTokens: Int?

        do {
            for try await chunk in client.streamChat(
                model: requestID,
                prompt: Self.prompt,
                maxTokens: Self.maxTokens
            ) {
                if let text = chunk.text, !text.isEmpty {
                    if firstTokenAt == nil { firstTokenAt = Date() }
                    approximateTokens += 1
                }
                if let tokens = chunk.completionTokens, tokens > 0 {
                    usageTokens = tokens
                }
            }

            guard let firstTokenAt else { throw SpeedTestError.noOutput }
            let endAt = Date()
            let tokens = usageTokens ?? approximateTokens
            guard tokens > 0 else { throw SpeedTestError.noOutput }
            guard let speed = SpeedMath.tokensPerSecond(tokens: tokens, from: firstTokenAt, to: endAt) else {
                throw SpeedTestError.tooShort
            }

            results[modelID] = ModelSpeedResult(
                modelID: modelID,
                tokensPerSecond: speed,
                ttfbMs: Int(firstTokenAt.timeIntervalSince(startedAt) * 1000),
                totalMs: Int(endAt.timeIntervalSince(startedAt) * 1000),
                completionTokens: tokens,
                estimated: usageTokens == nil,
                measuredAt: Date()
            )
            states[modelID] = .success
            persist()
        } catch {
            if error.isCancellation {
                states[modelID] = .idle
            } else {
                states[modelID] = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    // MARK: 本地持久化

    private func persist() {
        guard let data = try? JSONEncoder().encode(results) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadResults() -> [String: ModelSpeedResult] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ModelSpeedResult].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

enum SpeedTestError: LocalizedError {
    case noOutput
    case tooShort

    var errorDescription: String? {
        switch self {
        case .noOutput: return "没有输出内容"
        case .tooShort: return "输出太短，无法测速"
        }
    }
}
