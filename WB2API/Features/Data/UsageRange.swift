import Foundation

/// 用量统计区间：后端 `GET usage?hours=` 支持到 1440 小时（60 天）。
enum UsageRange: Int, CaseIterable, Identifiable {
    case days3 = 72
    case days7 = 168
    case days30 = 720
    case all = 1440

    var id: Int { rawValue }
    var hours: Int { rawValue }

    var title: String {
        switch self {
        case .days3: return "3 天"
        case .days7: return "7 天"
        case .days30: return "30 天"
        case .all: return "总计"
        }
    }

    var subtitle: String {
        switch self {
        case .days3: return "最近 72 小时"
        case .days7: return "最近 7 天"
        case .days30: return "最近 30 天"
        case .all: return "有记录以来（后端最多回看 60 天）"
        }
    }

    /// 用来算日均；总计按实际覆盖天数估，至少 1 天。
    func days(coveredHours: Double) -> Double {
        switch self {
        case .days3: return 3
        case .days7: return 7
        case .days30: return 30
        case .all: return max(coveredHours / 24, 1)
        }
    }
}
