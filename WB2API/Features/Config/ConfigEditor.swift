import Foundation
import Observation

/// 配置编辑状态：保存加载时的快照与可编辑草稿，提供路径级读写。
@MainActor
@Observable
final class ConfigEditor {
    private(set) var original: JSONValue = .object([:])
    var draft: JSONValue = .object([:])
    private(set) var path: String?
    private(set) var apiKeyEnvManaged = false
    private(set) var isLoaded = false

    /// 输入框格式错误（如时点写了 25 点）：有错误时禁止保存，
    /// 避免把旧值静默提交、让用户以为改动生效了。
    private(set) var invalidFieldIDs: Set<String> = []

    var isDirty: Bool { draft != original }

    var hasContent: Bool {
        !(draft.objectValue ?? [:]).isEmpty
    }

    var hasInvalidFields: Bool { !invalidFieldIDs.isEmpty }

    func setInvalid(_ id: String, _ invalid: Bool) {
        if invalid {
            guard !invalidFieldIDs.contains(id) else { return }
            invalidFieldIDs.insert(id)
        } else {
            guard invalidFieldIDs.contains(id) else { return }
            invalidFieldIDs.remove(id)
        }
    }

    /// 按路径读草稿里的值；路径不存在时返回 `.null`。
    func value(at path: [String]) -> JSONValue {
        var current = draft
        for key in path {
            guard let object = current.objectValue, let next = object[key] else { return .null }
            current = next
        }
        return current
    }

    /// 按路径写草稿；中间层缺失时自动补对象。
    func setValue(_ value: JSONValue, at path: [String]) {
        draft = Self.replacing(in: draft, path: path, value: value)
    }

    var topLevelKeys: [String] {
        (draft.objectValue ?? [:]).keys.sorted()
    }

    func load(_ response: ConfigResponse) {
        let normalized: JSONValue = response.config.objectValue == nil
            ? .object([:])
            : response.config
        original = normalized
        draft = normalized
        path = response.path
        apiKeyEnvManaged = response.apiKeyEnvManaged ?? false
        invalidFieldIDs.removeAll()
        isLoaded = true
    }

    /// 保存成功后把草稿当作新的基线。
    func markSaved() {
        original = draft
        invalidFieldIDs.removeAll()
    }

    func revert() {
        draft = original
        invalidFieldIDs.removeAll()
    }

    func set(_ value: JSONValue, for field: ConfigField) {
        setValue(value, at: field.path)
    }

    /// 某个顶层 key 下「未被原生分区接管」的剩余字段。
    ///
    /// 原生分区只覆盖网页端暴露的常用项，其余键仍要留在页面上，
    /// 不能因为做了中文表单就把它们藏起来（否则等于功能阉割）。
    func remainingFields(in key: String, excluding curatedPaths: Set<String>) -> [ConfigField] {
        guard let object = draft.objectValue, let raw = object[key] else { return [] }

        if let nested = raw.objectValue, !nested.isEmpty {
            return nested.keys.sorted().compactMap { child in
                let path = [key, child]
                guard !curatedPaths.contains(path.joined(separator: ".")) else { return nil }
                return ConfigField(key: child, path: path, value: nested[child] ?? .null)
            }
        }

        guard !curatedPaths.contains(key) else { return [] }
        return [ConfigField(key: key, path: [key], value: raw)]
    }

    /// 按顶层 key 汇总剩余字段；没有剩余字段的组不返回。
    func uncuratedGroups(excluding curatedPaths: Set<String>) -> [ConfigGroup] {
        topLevelKeys.compactMap { key in
            let fields = remainingFields(in: key, excluding: curatedPaths)
            return fields.isEmpty ? nil : ConfigGroup(key: key, fields: fields)
        }
    }

    // MARK: - 纯函数

    private static func replacing(in root: JSONValue, path: [String], value: JSONValue) -> JSONValue {
        guard let key = path.first else { return value }
        var object = root.objectValue ?? [:]
        let child = object[key] ?? .null
        object[key] = replacing(in: child, path: Array(path.dropFirst()), value: value)
        return .object(object)
    }
}
