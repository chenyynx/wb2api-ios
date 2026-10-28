import SwiftUI

/// 单条实时日志：通道徽标 + 时间 + 等宽正文，可长按选中复制。
struct LogRowView: View {
    @Environment(\.appTheme) private var theme

    let entry: LogEntry

    private let isWarning: Bool

    init(entry: LogEntry) {
        self.entry = entry
        let text = entry.text ?? ""
        isWarning = text.hasPrefix("WARN") || text.hasPrefix("ERR")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            HStack(spacing: Metrics.s) {
                Label(
                    LogChannel.title(for: entry.ch),
                    systemImage: LogChannel.systemImage(for: entry.ch)
                )
                .font(.tag)
                .foregroundStyle(LogChannel.tint(for: entry.ch, theme: theme))

                if isWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.tag)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("警告")
                }

                Spacer(minLength: 0)

                Text(Fmt.clock(entry.ts))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(entry.text ?? "")
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, Metrics.xs)
    }
}

#Preview {
    List {
        LogRowView(entry: LogEntry(
            ts: "2026-10-23T19:30:06.207383914+08:00",
            ch: "sys",
            text: "WARN: [pool] fallback_earliest_expiry acct=账号J(a1b2c3d4) until=2026-10-23T19:35:38+08:00 kind=soft"
        ))
        LogRowView(entry: LogEntry(
            ts: "2026-10-23T19:30:48.766662984+08:00",
            ch: "chat",
            text: "| #001 | 19:30:48 | deepseek-v4.1-flash | stream | 503 | 账号J(a1b2c3d4) | TTFB=- | tok=- | total=1.3s"
        ))
    }
}
