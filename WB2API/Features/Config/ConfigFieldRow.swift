import Foundation
import SwiftUI

/// 配置值的格式校验：时点数组与 Go duration 字符串。
enum ConfigValueParser {
    /// "9, 21" / "9，21" → [9, 21]；含非整数或超出 0-23 返回 nil。
    static func hours(_ raw: String) -> [Int]? {
        let normalized = raw.replacingOccurrences(of: "，", with: ",")
        let parts = normalized.split(separator: ",", omittingEmptySubsequences: false)
        var values: [Int] = []
        for part in parts {
            let token = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, let value = Int(token), (0...23).contains(value) else { return nil }
            if !values.contains(value) { values.append(value) }
        }
        return values.isEmpty ? nil : values
    }

    /// 与 Go `time.ParseDuration` 对齐的常见写法："600s"、"10m"、"2h"、"1h30m"、"0"。
    static func isValidDuration(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return durationRegex.firstMatch(in: text, range: range) != nil
    }

    private static var durationRegex: NSRegularExpression {
        // 静态 let 持 NSRegularExpression 在 Swift 6 下不够 Sendable，按需构造。
        try! NSRegularExpression(
            pattern: #"^(0|([0-9]+(\.[0-9]+)?(ns|us|µs|μs|ms|s|m|h))+)$"#
        )
    }
}

/// 一条配置字段：按类型渲染开关 / 数字 / 文本 / 时点 / 时长。
struct ConfigFieldRow: View {
    let spec: ConfigFieldSpec
    let value: JSONValue
    let onChange: (JSONValue) -> Void
    let onValidityChange: (Bool) -> Void

    @State private var text = ""
    @State private var numberText = ""
    @State private var flag = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            control

            if let hint = spec.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task { syncFromValue() }
        .onChange(of: value) { _, _ in
            guard !focused else { return }
            syncFromValue()
        }
    }

    // MARK: - 控件

    @ViewBuilder
    private var control: some View {
        switch spec.kind {
        case .toggle:
            Toggle(spec.label, isOn: $flag)
                .onChange(of: flag) { _, newValue in
                    guard value.boolValue != newValue else { return }
                    onChange(.bool(newValue))
                }

        case .integer, .decimal:
            LabeledContent(spec.label) {
                TextField(spec.placeholder ?? "0", text: $numberText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focused)
                    .onChange(of: numberText) { _, newValue in
                        commitNumber(newValue)
                    }
                    .accessibilityLabel(spec.label)
            }

        case .hours:
            LabeledContent(spec.label) {
                TextField(spec.placeholder ?? "9, 21", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        commitText(newValue)
                    }
                    .accessibilityLabel(spec.label)
            }

        case .duration:
            LabeledContent(spec.label) {
                TextField(spec.placeholder ?? "600s", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .fontDesign(.monospaced)
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        commitText(newValue)
                    }
                    .accessibilityLabel(spec.label)
            }

        case .secret:
            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(spec.label)
                    .font(.subheadline)
                SecureField(spec.placeholder ?? "未设置", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        commitText(newValue)
                    }
                    .accessibilityLabel(spec.label)
            }

        case .text:
            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(spec.label)
                    .font(.subheadline)
                TextField(spec.placeholder ?? "", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        commitText(newValue)
                    }
                    .accessibilityLabel(spec.label)
            }
        }
    }

    // MARK: - 提交与校验

    private func commitNumber(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            markInvalid("请输入数字")
            return
        }

        switch spec.kind {
        case .integer:
            guard let number = Int(trimmed) else {
                markInvalid("请输入整数")
                return
            }
            if let minimum = spec.minimum, number < minimum {
                markInvalid("不能小于 \(minimum)")
                return
            }
            if let maximum = spec.maximum, number > maximum {
                markInvalid("不能大于 \(maximum)")
                return
            }
            markValid()
            guard value.intValue != number else { return }
            onChange(.int(number))

        case .decimal:
            guard let number = Double(trimmed) else {
                markInvalid("请输入数字")
                return
            }
            markValid()
            guard value.doubleValue != number else { return }
            onChange(.double(number))

        default:
            break
        }
    }

    private func commitText(_ newValue: String) {
        switch spec.kind {
        case .hours:
            guard let hours = ConfigValueParser.hours(newValue) else {
                markInvalid("时点需为 0-23 的整点，用逗号分隔")
                return
            }
            markValid()
            let array = hours.map { JSONValue.int($0) }
            guard value.arrayValue != array else { return }
            onChange(.array(array))

        case .duration:
            guard ConfigValueParser.isValidDuration(newValue) else {
                markInvalid("格式如 600s、10m、2h")
                return
            }
            markValid()
            guard value.stringValue != newValue else { return }
            onChange(.string(newValue))

        case .text, .secret:
            markValid()
            guard value.stringValue != newValue else { return }
            onChange(.string(newValue))

        default:
            break
        }
    }

    private func markInvalid(_ message: String) {
        errorText = message
        onValidityChange(false)
    }

    private func markValid() {
        errorText = nil
        onValidityChange(true)
    }

    // MARK: - 同步

    private func syncFromValue() {
        switch spec.kind {
        case .toggle:
            flag = value.boolValue ?? false

        case .integer:
            if let number = value.intValue {
                numberText = String(number)
            } else if let number = value.doubleValue {
                numberText = String(format: "%g", number)
            } else {
                numberText = ""
            }

        case .decimal:
            numberText = value.doubleValue.map { String(format: "%g", $0) } ?? ""

        case .hours:
            let hours = value.arrayValue?.compactMap { $0.intValue } ?? []
            text = hours.map(String.init).joined(separator: ", ")

        case .text, .duration, .secret:
            text = value.stringValue ?? ""
        }
    }
}
