import Foundation

/// 用量统计的分组维度。
enum UsageDimension: String, CaseIterable, Identifiable {
    case account
    case model
    case realm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "按账号"
        case .model: "按模型"
        case .realm: "按域"
        }
    }

    /// 图表标题里跟在度量口径后面的名词，如「积分消耗 · 模型」。
    var noun: String {
        switch self {
        case .account: "账号"
        case .model: "模型"
        case .realm: "域"
        }
    }

    var emptyDescription: String {
        switch self {
        case .account: "该区间内还没有按账号聚合的用量。"
        case .model: "该区间内还没有按模型聚合的用量。"
        case .realm: "该区间内还没有按域聚合的用量。"
        }
    }

    /// 该维度下的原始分组；排序交给 `UsageMetric.sorted(_:)`，因为口径可切换。
    func groups(in snapshot: UsageSnapshot) -> [UsageGroup] {
        switch self {
        case .account:
            return snapshot.byAccount ?? []
        case .model:
            return snapshot.byModel ?? []
        case .realm:
            return snapshot.byRealm ?? []
        }
    }
}
