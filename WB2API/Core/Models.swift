import Foundation
import SwiftUI

// MARK: - 通用 JSON 值（配置等自由结构）

enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    var displayText: String {
        switch self {
        case .null: return "—"
        case .bool(let v): return v ? "开" : "关"
        case .int(let v): return String(v)
        case .double(let v): return String(format: "%g", v)
        case .string(let v): return v
        case .array(let v): return v.map(\.displayText).joined(separator: ", ")
        case .object: return "{…}"
        }
    }

    var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
    var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
}

// MARK: - 账号

struct ExpiryBucket: Codable, Identifiable, Sendable {
    var id: String { expiresAt ?? date ?? UUID().uuidString }
    let date: String?
    let expiresAt: String?
    let remain: Int?
}

struct RateLimitedModel: Codable, Identifiable, Sendable {
    var id: String { (model ?? "") + (until ?? "") }
    let model: String?
    let kind: String?
    let until: String?
    let resetAt: String?
    let reason: String?
}

/// 手动关闭的 (账号, 模型) 记录：`{model, since, note}`。
struct ModelOffEntry: Codable, Identifiable, Sendable {
    var id: String { model ?? UUID().uuidString }
    let model: String?
    /// 关闭时间（后端格式 "01-02 15:04"）
    let since: String?
    let note: String?
}

struct TokenUsage: Codable, Sendable {
    let requestCount: Int?
    let usageCount: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let lastLatencyMs: Int?
    let lastTokensPerSecond: Double?
    let lastUsedAt: String?
    let lastModel: String?
}

struct ModelCost: Codable, Identifiable, Sendable {
    var id: String { model ?? UUID().uuidString }
    let model: String?
    let costPer1k: Double?
    let lastSeen: String?
}

struct Account: Codable, Identifiable, Sendable {
    var id: String { uid }
    let uid: String
    let nickname: String?
    let credits: Int?
    let creditsTotal: Int?
    let sessionDeadFails: Int?
    let creditsEarliestExpiry: String?
    let creditsEarliestRemaining: Int?
    let creditsExpiryBuckets: [ExpiryBucket]?
    let cooling: Bool?
    let until: String?
    let rateLimitedModels: [RateLimitedModel]?
    /// 手动关闭的模型（后端 model_off；关闭后该账号不再被路由到这些模型）
    let modelOff: [ModelOffEntry]?
    let realm: String?
    let disabled: Bool?
    /// 暂停选号（后端 `paused`）：与 disabled 正交——退出选号候选，但签到 / 活跃上报 /
    /// 保活 / 余额刷新照常执行，点「恢复」立即回到池子。
    let paused: Bool?
    /// 禁用原因（后端 disabled_reason，通常会写明 12153 会话失效）
    let disabledReason: String?
    let successCount: Int?
    let lastSuccess: String?
    let lastErr: String?
    let checkinDone: Bool?
    let tokenUsage: TokenUsage?
    let modelCosts: [ModelCost]?

    var displayName: String {
        if let n = nickname, !n.isEmpty { return n }
        return String(uid.prefix(8))
    }

    var isCooling: Bool { cooling ?? false }

    /// 冷却剩余（"8 分"）；已到期或未冷却返回 nil。
    var coolingLeft: String? {
        guard isCooling, let until, let date = Fmt.parse(until), date > Date() else { return nil }
        let seconds = date.timeIntervalSinceNow
        if seconds < 90 { return "\(Int(seconds)) 秒" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分" }
        return "\(Int(seconds / 3600)) 小时 \(Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)) 分"
    }
    var isDisabled: Bool { disabled ?? false }
    var isPaused: Bool { paused ?? false }
    var isHealthy: Bool { !isCooling && !isDisabled && !isPaused }

    /// 需要交互式重新登录：已被禁用，或连续出现会话失效（12153）计数。
    /// 这两种情况下点「复活」是没用的（refresh token 也失效了），必须重新授权。
    var needsLogin: Bool {
        isDisabled || (sessionDeadFails ?? 0) > 0
    }

    /// 给用户看的一句话：现在是什么状态、该做什么。
    var actionHint: String? {
        if isDisabled {
            return (disabledReason ?? "").isEmpty ? "账号已禁用，通常是登录态失效，需要重新登录授权" : (disabledReason ?? "")
        }
        if let fails = sessionDeadFails, fails > 0 {
            return "登录态已失效（连续 \(fails) 次会话失效），请重新登录"
        }
        if isPaused {
            return "已暂停选号，不再接新请求；签到 / 保活照常。点「恢复」即可重新参与调度。"
        }
        if isCooling {
            if let left = coolingLeft { return "限流冷却中，\(left)后自动恢复，无需操作" }
            return "限流冷却中，稍后自动恢复"
        }
        return nil
    }

    var creditProgress: Double {
        guard let c = credits, let t = creditsTotal, t > 0 else { return 0 }
        return min(max(Double(c) / Double(t), 0), 1)
    }

    var realmLabel: String {
        switch realm {
        case "global": return "国际版"
        case "cn": return "国内版"
        default: return realm ?? "—"
        }
    }
}

struct StatusResponse: Codable, Sendable {
    let accounts: [Account]
    let healthy: Int?
    let cooling: Int?
    let disabled: Int?
    /// 后端返回整数计数（0 表示未满）
    let inFlightFull: Int?
    var isInFlightFull: Bool { (inFlightFull ?? 0) > 0 }
}

// MARK: - 概览

struct OverviewResponse: Codable, Sendable {
    let accounts: [Account]
    let healthy: Int?
    let cooling: Int?
    let disabled: Int?
    let inFlightFull: Int?
    let balanceRefreshSec: Int?
    let balanceRefreshedAt: String?
    /// JSON 键是 `model_locks`，靠 `.convertFromSnakeCase` 直接映射到这个名字。
    /// （曾经叫 modelLocksRaw 且没写 CodingKeys，导致永远解成 nil、卡片一直显示「全部可用」。）
    let modelLocks: [ModelLock]?

    var isInFlightFull: Bool { (inFlightFull ?? 0) > 0 }
    var total: Int { accounts.count }
    var totalCredits: Int { accounts.compactMap(\.credits).reduce(0, +) }
}

// MARK: - 模型锁池

/// 哪些模型不能用、锁了几个号、还要锁多久。
/// 后端已按「整池不可用 → 没号可用 → 部分限流」排序。
struct ModelLock: Codable, Identifiable, Sendable {
    var id: String { (model ?? "") + (realm ?? "") }
    let model: String?
    let realm: String?
    let total: Int?
    let servable: Int?
    let locked: Int?
    /// locked / starved / partial
    let state: String?
    let unlockAt: String?
    let fullyUnlockAt: String?

    var realmLabel: String {
        switch realm {
        case "global": return "国际版"
        case "cn": return "国内版"
        default: return realm ?? "—"
        }
    }

    var stateLabel: String {
        switch state {
        case "locked": return "整池不可用"
        case "starved": return "没号可用"
        case "partial": return "部分限流"
        default: return state ?? "—"
        }
    }

    var stateTint: Color {
        switch state {
        case "locked": return .red
        case "starved", "partial": return .orange
        default: return .secondary
        }
    }
}

// MARK: - 模型

struct ModelInfo: Codable, Identifiable, Sendable {
    var id: String { modelId ?? name ?? UUID().uuidString }
    let modelId: String?
    let name: String?
    let credits: String?
    let contextLength: Int?
    let description: String?
    let supportsImages: Bool?
    let supportsReasoning: Bool?
    let supportsToolCall: Bool?
    let isDefault: Bool?
    let maxOutputTokens: Int?
    let defaultEffort: String?
    let onlyReasoning: Bool?
    let busy: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "id"
        case name, credits, description, busy
        case contextLength, supportsImages, supportsReasoning, supportsToolCall
        case isDefault, maxOutputTokens, defaultEffort, onlyReasoning
    }
}

struct ModelsResponse: Codable, Sendable {
    let models: [ModelInfo]
    let globalSource: String?
}

// MARK: - 日志 / 指标

struct LogEntry: Codable, Identifiable, Sendable {
    var id: String { (ts ?? "") + (text ?? "").prefix(24) }
    let ts: String?
    let ch: String?
    let text: String?
}

struct LogsResponse: Codable, Sendable {
    let entries: [LogEntry]
    let archiveError: String?
}

struct RequestMetrics: Codable, Sendable {
    let startedAt: String?
    let completed: Int?
    let inFlight: Int?
    let succeeded: Int?
    let failed: Int?
    let successRate: Double?
    let httpSuccessRate: Double?
    let avgDurationMs: Double?
}

struct ErrorRow: Codable, Identifiable, Sendable {
    var id: String { (account ?? "") + (code ?? "") + (kind ?? "") }
    let account: String?
    let kind: String?
    let code: String?
    let count: Int?
    let last: String?
    let sev: String?
    let sample: String?
    let sampleFull: String?
    /// 冷却结束时间（限流类错误才有），如 "2026-10-24 06:21:29"
    let until: String?
}

struct ErrorSummary: Codable, Sendable {
    let rows: [ErrorRow]
    let scanned: Int?
    let updatedAt: String?
}

// MARK: - 任务队列

struct TaskQueue: Codable, Sendable {
    let conc: Int?
    let items: [JSONValue]?
    let running: Bool?
    let seq: Int?
    let started: Bool?
    let startedAt: String?
    let total: Int?
}

// MARK: - 用量

struct UsageTotals: Codable, Sendable {
    let requests: Int?
    let errors: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let cacheHitTokens: Int?
    let avgLatencyMs: Double?
    let avgTokensPerSecond: Double?
    let credits: Double?
    let creditsPer1mTokens: Double?
    let cacheHitRate: Double?
}

struct UsageGroup: Codable, Identifiable, Sendable {
    var id: String { key ?? UUID().uuidString }
    let key: String?
    /// 按账号聚合时 key 是 uid，昵称在 extra（by_account）/ nickname（credit_by_account）里
    let extra: String?
    let nickname: String?
    let realm: String?
    let requests: Int?
    let errors: Int?
    let totalTokens: Int?
    let credits: Double?
    let avgLatencyMs: Double?

    /// 图表/列表里的展示名：昵称 > extra > 域中文名 > key（按账号时 key 是 uid）。
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        if let extra, !extra.isEmpty { return extra }
        switch key {
        case "cn": return "国内版"
        case "global": return "国际版"
        default: return key ?? "未知"
        }
    }

    var realmLabel: String? {
        switch realm {
        case "cn": return "国内版"
        case "global": return "国际版"
        default: return nil
        }
    }
}

struct UsagePoint: Codable, Identifiable, Sendable {
    var id: String { "\(t ?? "")-\(key ?? "")" }
    /// 小时桶标识，如 "2026-10-20T20"
    let t: String?
    let key: String?
    let requests: Int?
    let tokens: Int?
    /// JSON: total_tokens（UsagePoint.tokens 在部分响应里不存在，以本字段为准）
    let totalTokens: Int?
    let credits: Double?
}

struct UsageSnapshot: Codable, Sendable {
    let totals: UsageTotals?
    let byRealm: [UsageGroup]?
    let byAccount: [UsageGroup]?
    let byModel: [UsageGroup]?
    let series: [UsagePoint]?
    let creditByAccount: [UsageGroup]?
    let creditByModel: [UsageGroup]?
}

struct BalancePoint: Codable, Identifiable, Sendable {
    var id: Int { t ?? 0 }
    let t: Int?
    let u: String?
    let c: Int?
}

struct BalanceDaily: Codable, Identifiable, Sendable {
    var id: String { day ?? UUID().uuidString }
    let day: String?
    let first: Int?
    let last: Int?
    let change: Int?
    let consumed: Int?
    let gained: Int?
}

struct BalanceSeries: Codable, Identifiable, Sendable {
    var id: String { uid ?? UUID().uuidString }
    let uid: String?
    let name: String?
    let points: [BalancePoint]?
    let current: Int?
    let min: Int?
    let max: Int?
    let change: Int?
    let daily: [BalanceDaily]?
    let realm: String?
}

struct BalanceHistory: Codable, Sendable {
    let days: Int?
    let now: String?
    let series: [BalanceSeries]?
}

/// 积分变动记录（后端：account/after/before/delta/time/uid）
struct CreditEntry: Codable, Identifiable, Sendable {
    var id: String { "\(uid ?? "")-\(time ?? "")-\(delta ?? 0)" }
    let account: String?
    let uid: String?
    let before: Int?
    let after: Int?
    /// 变动量：正数为获得，负数为消耗
    let delta: Int?
    let time: String?
}

struct CreditHistory: Codable, Sendable {
    let entries: [CreditEntry]?
    let limit: Int?
}

// MARK: - 礼包 / 补偿

struct PackageItem: Codable, Identifiable, Sendable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let remain: Int?
    let used: Int?
    let size: Int?
    /// 到期时间（文本）与毫秒时间戳
    let endTime: String?
    let expiresAt: Int64?
}

struct PackageAccount: Codable, Identifiable, Sendable {
    var id: String { uid ?? UUID().uuidString }
    let uid: String?
    let nickname: String?
    let realm: String?
    let remain: Int?
    let size: Int?
    let packages: [PackageItem]?
}

struct PackagesResponse: Codable, Sendable {
    let accounts: [PackageAccount]
}

// MARK: - 登录

struct LoginRegion: Codable, Identifiable, Sendable {
    var id: String { code ?? UUID().uuidString }
    let code: String?
    let name: String?
}

struct LoginRegionsResponse: Codable, Sendable {
    let regions: [LoginRegion]
}

struct LoginStartResponse: Codable, Sendable {
    let ok: Bool?
    let realm: String?
    let state: String?
    let url: String?
}

struct LoginPollResponse: Codable, Sendable {
    let done: Bool?
    let uid: String?
    let nickname: String?
    let realm: String?
    let credits: Int?
    let creditsTotal: Int?
    let balanceError: String?
    let checkinMessage: String?
}

// MARK: - 配置

struct ConfigResponse: Codable, Sendable {
    let config: JSONValue
    let path: String?
    let apiKeyEnvManaged: Bool?
}

/// `POST /config` 的返回：哪些字段要重启才生效、哪些由环境变量托管。
struct ConfigSaveResponse: Codable, Sendable {
    let ok: Bool?
    let restartRequired: [String]?
    let apiKeyEnvManaged: Bool?
    let environmentManagedFields: [String]?

    var summary: String {
        if let restartRequired, !restartRequired.isEmpty {
            return "已保存；\(restartRequired.count) 个字段需重启生效：\(restartRequired.joined(separator: "、"))"
        }
        return "配置已保存"
    }
}

// MARK: - 通用消息

struct SimpleOK: Codable, Sendable {
    let ok: Bool?
    let error: String?
    let message: String?
}

// MARK: - 导航用 Hashable（只按 uid 比较，避免整结构参与哈希）

extension Account: Hashable {
    static func == (lhs: Account, rhs: Account) -> Bool { lhs.uid == rhs.uid }
    func hash(into hasher: inout Hasher) { hasher.combine(uid) }
}
