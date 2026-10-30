import Foundation

/// 分组排行的度量口径：同时决定柱长、柱尾数值和排序。
///
/// 之前图表只按请求数排，看不出「哪个模型最烧积分」；
/// 现在可以在请求数 / 积分消耗 / Token 消耗之间切换，模型、账号、域三个维度都适用。
enum UsageMetric: String, CaseIterable, Identifiable {
    case requests
    case credits
    case tokens

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requests: "请求数"
        case .credits: "积分消耗"
        case .tokens: "Token 消耗"
        }
    }

    /// 胶囊按钮里的短标签，避免占掉标题的位置。
    var shortTitle: String {
        switch self {
        case .requests: "请求"
        case .credits: "积分"
        case .tokens: "Token"
        }
    }

    var symbol: String {
        switch self {
        case .requests: "arrow.up.right"
        case .credits: "creditcard.fill"
        case .tokens: "text.word.spacing"
        }
    }

    /// 排序与柱长用的原始值；缺字段按 0 处理，排到末尾。
    func value(of group: UsageGroup) -> Double {
        switch self {
        case .requests: Double(group.requests ?? 0)
        case .credits: group.credits ?? 0
        case .tokens: Double(group.totalTokens ?? 0)
        }
    }

    /// 柱尾的数字文案。积分带一位小数，请求数 / Token 用紧凑单位。
    func text(for value: Double) -> String {
        switch self {
        case .requests, .tokens:
            return Fmt.compact(Int(value.rounded()))
        case .credits:
            if value >= 100_000 { return String(format: "%.0fk", value / 1000) }
            return Fmt.creditsDouble(value)
        }
    }

    /// 从大到小排序；同值先按请求数、再按名称兜底，刷新后顺序不会跳。
    func sorted(_ groups: [UsageGroup]) -> [UsageGroup] {
        groups.sorted { lhs, rhs in
            let lv = value(of: lhs)
            let rv = value(of: rhs)
            if lv != rv { return lv > rv }
            let lRequests = lhs.requests ?? 0
            let rRequests = rhs.requests ?? 0
            if lRequests != rRequests { return lRequests > rRequests }
            return lhs.displayName < rhs.displayName
        }
    }
}
