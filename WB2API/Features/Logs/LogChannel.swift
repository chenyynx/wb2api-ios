import SwiftUI

/// 日志通道：`ch` 字段的强类型映射；未知通道只在「全部」里出现。
enum LogChannel: String, CaseIterable, Identifiable {
    case all
    case system = "sys"
    case chat
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .system: return "系统"
        case .chat: return "对话"
        case .task: return "任务"
        }
    }

    func matches(_ raw: String?) -> Bool {
        self == .all || raw == rawValue
    }

    /// 单条日志的通道名：未知通道原样大写，便于排查新通道。
    static func title(for raw: String?) -> String {
        switch raw ?? "" {
        case "": return "日志"
        case "sys": return "系统"
        case "chat": return "对话"
        case "task": return "任务"
        default: return (raw ?? "").uppercased()
        }
    }

    static func systemImage(for raw: String?) -> String {
        switch raw ?? "" {
        case "sys": return "gearshape.2"
        case "chat": return "bubble.left.and.bubble.right"
        case "task": return "checklist"
        default: return "text.alignleft"
        }
    }

    static func tint(for raw: String?, theme: AppTheme) -> Color {
        raw == "chat" ? theme.primary : .secondary
    }
}
