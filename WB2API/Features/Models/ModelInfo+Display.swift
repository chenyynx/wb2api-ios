import Foundation

/// 模型目录的展示派生值：倍率解析、容量紧凑记法、繁忙状态文案。
extension ModelInfo: Hashable {
    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.modelId == rhs.modelId && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(modelId)
        hasher.combine(name)
    }
}

extension ModelInfo {
    var displayID: String {
        modelId ?? name ?? "未命名模型"
    }

    /// 真正发给 `/v1/chat/completions` 的模型标识。
    var requestID: String {
        modelId ?? name ?? ""
    }

    /// `credits` 是 "x0.79" 这类倍率字符串，拆成数值用于排版与数字滚动。
    var creditMultiplier: Double? {
        guard let credits else { return nil }
        let cleaned = credits
            .lowercased()
            .replacing("×", with: "")
            .replacing("*", with: "")
            .replacing("x", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    var creditMultiplierText: String {
        guard let creditMultiplier else { return "—" }
        return "×" + creditMultiplier.formatted(.number.precision(.fractionLength(2)))
    }

    var contextText: String {
        guard let contextLength, contextLength > 0 else { return "—" }
        return Self.compactSize(contextLength)
    }

    var maxOutputText: String {
        guard let maxOutputTokens, maxOutputTokens > 0 else { return "—" }
        return Self.compactSize(maxOutputTokens)
    }

    var defaultEffortLabel: String {
        guard let defaultEffort, !defaultEffort.isEmpty else { return "—" }
        return defaultEffort
    }

    var isBusy: Bool { busy == "busy" }

    var busyLabel: String {
        guard let busy, !busy.isEmpty else { return "未知" }
        switch busy {
        case "busy": return "繁忙"
        case "normal": return "正常"
        case "idle": return "空闲"
        case "unknown": return "未知"
        default: return busy
        }
    }

    /// 容量是技术单位，固定英文紧凑记法（1M / 200K），不随语言变成「万」。
    private static func compactSize(_ value: Int) -> String {
        Double(value).formatted(
            .number
                .notation(.compactName)
                .precision(.fractionLength(0...1))
                .locale(Locale(identifier: "en_US"))
        )
    }
}
