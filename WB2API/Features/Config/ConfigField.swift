import Foundation

/// 配置表单中的一行。
///
/// `path` 是从顶层 key 开始的完整路径（最多两层），`value` 是渲染时的快照。
struct ConfigField: Identifiable, Equatable {
    let key: String
    let path: [String]
    let value: JSONValue

    var id: String { path.joined(separator: ".") }

    var isInteger: Bool {
        if case .int = value { return true }
        return false
    }

    var typeLabel: String {
        switch value {
        case .bool: "布尔"
        case .int: "整数"
        case .double: "小数"
        case .string: "文本"
        case .array: "数组"
        case .object: "对象"
        case .null: "空"
        }
    }
}

/// 一组「未被原生分区接管」的原始配置。
struct ConfigGroup: Identifiable {
    let key: String
    let fields: [ConfigField]

    var id: String { key }
}
