import Foundation

/// 用户手动忽略的账号警告（需重新登录 / 暂停等红色提示）。
///
/// 有些账号明确不打算再登回来，但列表会一直顶着红色「需重新登录」，
/// 每次翻列表都被提醒一次。这里按 uid 记住「已忽略」，行视图只把
/// 红色状态降级成普通次要文案——状态本身照常展示，不撒谎。
enum IgnoredWarnings {
    static let storageKey = "wb2api.ignoredWarnings"

    static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(list)
    }

    static func save(_ set: Set<String>) {
        let list = Array(set).sorted()
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func ignore(_ uid: String) {
        var set = load()
        set.insert(uid)
        save(set)
    }

    static func restore(_ uid: String) {
        var set = load()
        set.remove(uid)
        save(set)
    }

    static func isIgnored(_ uid: String) -> Bool {
        load().contains(uid)
    }
}
