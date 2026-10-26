import Foundation

/// 配置表单中的一条字段定义。
///
/// 对齐网页端 `CFG_MAP` 的扁平键与嵌套路径：App 里用中文标签和原生控件，
/// 保存时仍然写回面板原本的 `config.json` 结构。
struct ConfigFieldSpec: Identifiable {
    enum Kind {
        case toggle
        case integer
        case decimal
        case text
        case duration
        case hours
        case secret
    }

    let id: String
    let label: String
    let path: [String]
    let kind: Kind
    var hint: String? = nil
    var placeholder: String? = nil
    var minimum: Int? = nil
    var maximum: Int? = nil
}

/// 一个中文分区。
struct ConfigSectionSpec: Identifiable {
    let id: String
    let title: String
    let fields: [ConfigFieldSpec]
    var footer: String? = nil
}

/// 与网页端「服务 / 定时任务 / 账号池与流量治理 / 上游与高级 / 日志」一一对应。
///
/// 只把网页端暴露的常用项做成原生控件；其余键由 `ConfigEditor.uncuratedGroups`
/// 继续以原始键值展示，保证没有任何配置被藏起来。
enum ConfigSchema {
    static let sections: [ConfigSectionSpec] = [
        ConfigSectionSpec(
            id: "service",
            title: "服务",
            fields: [
                .text("listen", "监听地址", ["listen"], hint: "修改后需重启网关生效"),
                .secret("api_key", "API 密钥", ["api_key"], hint: "留空会关闭网关鉴权，App 会阻止保存空值"),
                .integer("package_detail_limit", "单账号明细默认展示条数", ["panel", "package_detail_limit"],
                         hint: "积分构成页按最早到期展示，其余未用完包聚合")
            ],
            footer: "API 密钥由面板管理；这里修改会直接写回 config.json。"
        ),
        ConfigSectionSpec(
            id: "schedule",
            title: "定时任务",
            fields: [
                .toggle("checkin_enabled", "自动签到", ["schedule", "checkin_enabled"]),
                .hours("checkin_hours", "签到时点", ["schedule", "checkin_hours"], placeholder: "9, 21"),
                .toggle("keepalive_enabled", "Token 保活", ["schedule", "keepalive_enabled"]),
                .hours("keepalive_hours", "保活时点", ["schedule", "keepalive_hours"], placeholder: "22"),
                .toggle("travel_enabled", "猫猫旅行", ["schedule", "travel_enabled"]),
                .hours("travel_hours", "旅行时点", ["schedule", "travel_hours"], placeholder: "9, 21",
                       hint: "一趟派出 + 一趟领奖闭环"),
                .toggle("activity_enabled", "活跃上报", ["schedule", "activity_enabled"]),
                .hours("activity_hours", "上报时点", ["schedule", "activity_hours"], placeholder: "10",
                       hint: "点亮连登 + 解锁领养前置"),
                .toggle("balance_refresh_enabled", "后台刷新余额", ["schedule", "balance_refresh_enabled"]),
                .integer("balance_refresh_minutes", "刷新间隔（分钟）", ["schedule", "balance_refresh_minutes"]),
                .toggle("growth_enabled", "成长任务自动执行", ["schedule", "growth_enabled"]),
                .hours("growth_hours", "执行时点", ["schedule", "growth_hours"], placeholder: "1",
                       hint: "每日到点自动「扫描 + 执行全部待办」；任务链零点解锁后自动推进，建议零点后"),
                .toggle("include_disabled_in_tasks", "保号任务覆盖已禁用账号", ["schedule", "include_disabled_in_tasks"],
                        hint: "打开后已禁用账号仍会签到 / 活跃上报 / 保活 / 刷新余额，但依旧不参与选号")
            ],
            footer: "时点填 0-23 的整点，用逗号分隔；保存后立即生效。"
        ),
        ConfigSectionSpec(
            id: "pool",
            title: "账号池与流量治理",
            fields: [
                .integer("max_in_flight", "单账号最大在途", ["pool", "max_in_flight"], hint: "0 = 不限制"),
                .integer("max_in_flight_global", "国际版在途上限", ["pool", "max_in_flight_global"],
                         hint: "global 域风控更紧，默认 2"),
                .integer("breaker_threshold", "连续失败熔断阈值", ["pool", "breaker_threshold"]),
                .duration("soft_rate", "软限流冷却基数", ["cooldown", "soft_rate"]),
                .duration("soft_rate_max", "软冷却退避上限", ["cooldown", "soft_rate_max"]),
                .duration("breaker_cooldown", "熔断基础时长", ["pool", "breaker_cooldown"]),
                .duration("breaker_cooldown_max", "熔断退避上限", ["pool", "breaker_cooldown_max"]),
                .integer("degrade_threshold", "连败降权阈值", ["pool", "degrade_threshold"]),
                .duration("degrade_cooldown", "连败降权时长", ["pool", "degrade_cooldown"]),
                .duration("degrade_cooldown_max", "连败降权上限", ["pool", "degrade_cooldown_max"]),
                .decimal("idle_weight_per_hour", "闲置补偿 / 小时", ["pool", "idle_weight_per_hour"]),
                .integer("idle_weight_max", "闲置补偿上限", ["pool", "idle_weight_max"]),
                .duration("cost_explore_interval", "成本探索窗口", ["pool", "cost_explore_interval"]),
                .integer("credit_floor", "积分保底", ["pool", "credit_floor"]),
                .duration("expiring_soon", "快过期路由窗口", ["pool", "expiring_soon"]),
                .duration("ttl", "会话粘性 TTL", ["session_sticky", "ttl"]),
                .toggle("prefer_expiring", "快过期积分优先", ["pool", "prefer_expiring"])
            ],
            footer: "时长用 Go duration 写法：600s、10m、2h。"
        ),
        ConfigSectionSpec(
            id: "upstream",
            title: "上游与高级",
            fields: [
                .integer("timeout_seconds", "短请求超时（秒）", ["upstream", "timeout_seconds"]),
                .integer("header_timeout_seconds", "聊天首字节超时（秒）", ["upstream", "header_timeout_seconds"]),
                .integer("idle_timeout_seconds", "流空闲超时（秒）", ["upstream", "idle_timeout_seconds"]),
                .text("user_agent", "出站 User-Agent", ["upstream", "user_agent"]),
                .text("prompt_mode", "系统提示词模式", ["prompt", "mode"], placeholder: "passthrough"),
                .text("prompt_file", "提示词文件路径", ["prompt", "file"]),
                .toggle("sanitize_blacklist_fingerprints", "出站请求指纹脱敏", ["features", "sanitize_blacklist_fingerprints"]),
                .toggle("session_sticky_enabled", "会话粘性路由", ["session_sticky", "enabled"])
            ],
            footer: "User-Agent 留空会回落到内置默认。"
        ),
        ConfigSectionSpec(
            id: "logging",
            title: "日志",
            fields: [
                .toggle("request_client_info", "记录调用来源（客户端 IP / User-Agent）",
                        ["logging", "request_client_info"])
            ],
            footer: "只影响请求记录里的来源字段，不影响调用本身。"
        )
    ]

    /// 已被原生分区接管的路径（点号连接）。
    static let curatedPaths: Set<String> = Set(
        sections.flatMap { section in
            section.fields.map { $0.path.joined(separator: ".") }
        }
    )

    /// 字段 id → 中文标签，用于把校验错误点名到具体字段。
    static func label(forFieldID id: String) -> String? {
        for section in sections {
            if let field = section.fields.first(where: { $0.id == id }) {
                return field.label
            }
        }
        return nil
    }
}

// MARK: - 定义辅助

extension ConfigFieldSpec {
    static func toggle(_ id: String, _ label: String, _ path: [String], hint: String? = nil) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .toggle, hint: hint)
    }

    static func integer(
        _ id: String,
        _ label: String,
        _ path: [String],
        hint: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil
    ) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .integer,
                        hint: hint, minimum: minimum, maximum: maximum)
    }

    static func decimal(_ id: String, _ label: String, _ path: [String], hint: String? = nil) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .decimal, hint: hint)
    }

    static func text(
        _ id: String,
        _ label: String,
        _ path: [String],
        hint: String? = nil,
        placeholder: String? = nil
    ) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .text,
                        hint: hint, placeholder: placeholder)
    }

    static func secret(_ id: String, _ label: String, _ path: [String], hint: String? = nil) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .secret, hint: hint)
    }

    static func duration(_ id: String, _ label: String, _ path: [String], hint: String? = nil) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .duration,
                        hint: hint, placeholder: "600s")
    }

    static func hours(
        _ id: String,
        _ label: String,
        _ path: [String],
        placeholder: String? = nil,
        hint: String? = nil
    ) -> ConfigFieldSpec {
        ConfigFieldSpec(id: id, label: label, path: path, kind: .hours,
                        hint: hint, placeholder: placeholder)
    }
}
