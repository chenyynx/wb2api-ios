import Foundation

/// 账号列表的筛选维度。
enum AccountFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case healthy
    case cooling
    case paused
    case disabled
    case unchecked

    var id: String { rawValue }

    var name: String {
        switch self {
        case .all: "全部"
        case .healthy: "可用"
        case .cooling: "冷却"
        case .paused: "已暂停"
        case .disabled: "禁用"
        case .unchecked: "未签到"
        }
    }

    var symbol: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .healthy: "checkmark.circle"
        case .cooling: "hourglass"
        case .paused: "pause.circle"
        case .disabled: "nosign"
        case .unchecked: "seal"
        }
    }

    var isActive: Bool { self != .all }

    func title(count: Int) -> String {
        "\(name)（\(count)）"
    }

    func matches(_ account: Account) -> Bool {
        switch self {
        case .all: true
        case .healthy: account.isHealthy
        case .cooling: account.isCooling
        case .paused: account.isPaused
        case .disabled: account.isDisabled
        case .unchecked: account.checkinDone == false
        }
    }
}
