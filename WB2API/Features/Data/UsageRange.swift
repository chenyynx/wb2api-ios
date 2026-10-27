import Foundation

/// 用量统计区间：今日/昨日按东八区自然日，其余为后端滚动小时窗口。
enum UsageRange: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case days3
    case days7
    case days30
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日"
        case .yesterday: return "昨日"
        case .days3: return "3 天"
        case .days7: return "7 天"
        case .days30: return "30 天"
        case .all: return "总计"
        }
    }

    var subtitle: String {
        switch self {
        case .today: return "今天 00:00 至今"
        case .yesterday: return "昨天 00:00–24:00"
        case .days3: return "最近 72 小时"
        case .days7: return "最近 7 天"
        case .days30: return "最近 30 天"
        case .all: return "有记录以来（后端最多回看 60 天）"
        }
    }

    /// 滚动窗口小时数；今日/昨日用显式自然日区间，返回 nil。
    var hours: Int? {
        switch self {
        case .today, .yesterday: return nil
        case .days3: return 72
        case .days7: return 168
        case .days30: return 720
        case .all: return 1440
        }
    }

    var isSingleDay: Bool {
        self == .today || self == .yesterday
    }

    /// 今日/昨日的 [from, to]；后端用 unix 秒过滤所有口径（totals/分组/时序）。
    func window(now: Date = Date()) -> (from: Date, to: Date)? {
        switch self {
        case .today, .yesterday:
            break
        default:
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let todayStart = calendar.startOfDay(for: now)

        switch self {
        case .today:
            return (todayStart, now)
        case .yesterday:
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)
                ?? todayStart.addingTimeInterval(-86_400)
            // 后端区间是闭区间（桶起点 <= to），减 1 秒排除今天 00:00 的桶。
            return (yesterdayStart, todayStart.addingTimeInterval(-1))
        default:
            return nil
        }
    }

    /// 用来算日均；单日区间按 1 天，总计按实际覆盖天数估。
    func days(coveredHours: Double) -> Double {
        switch self {
        case .today, .yesterday: return 1
        case .days3: return 3
        case .days7: return 7
        case .days30: return 30
        case .all: return max(coveredHours / 24, 1)
        }
    }
}
