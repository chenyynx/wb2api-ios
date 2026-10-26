import SwiftUI

/// 健康度主卡：健康环 + 「9/11 健康」+ 一句状态 + 只列异常项。
///
/// 正常状态不写「没有账号在冷却」这类空话——只有出问题时才出现对应行。
struct HealthCard: View {
    let digest: OverviewDigest

    /// 一行异常提示，图标与文字左对齐到同一列。
    private struct StatusLine: Identifiable {
        let id: Int
        let icon: String
        let text: String
        let tint: Color
    }

    private var lines: [StatusLine] {
        var items: [StatusLine] = []
        if digest.cooling > 0 {
            items.append(StatusLine(id: 0, icon: "hourglass", text: digest.coolingLine, tint: .orange))
        }
        if digest.disabled > 0 {
            items.append(StatusLine(id: 1, icon: "person.badge.key.fill", text: digest.disabledLine, tint: .red))
        }
        if digest.inFlightFullCount > 0 {
            // 后端 in_flight_full 是「健康账号里在途名额已占满的个数」，不是布尔量：
            // 只有全部可用账号都满载（count >= healthy）时新请求才真的要等空位；
            // 部分满载只是调度分布，其余账号照常接单，不该报成服务异常。
            let saturated = digest.inFlightFullCount >= digest.healthy
            items.append(StatusLine(
                id: 2,
                icon: saturated ? "exclamationmark.triangle.fill" : "gauge.with.dots.needle.67percent",
                text: saturated
                    ? "并发已满 · \(digest.inFlightFullCount)/\(digest.healthy) 个账号在途占满，新请求需等待"
                    : "\(digest.inFlightFullCount)/\(digest.healthy) 个账号并发已满，其余可接新请求",
                tint: saturated ? .orange : .secondary
            ))
        }
        if items.isEmpty {
            // 没有异常时不留空：换成当天用量与积分到期这类有信息量的摘要。
            if digest.avgLatencyMs != nil {
                items.append(StatusLine(
                    id: 10,
                    icon: "speedometer",
                    text: "平均延迟 \(Fmt.latency(digest.avgLatencyMs))",
                    tint: .secondary
                ))
            }
            if let expiry = digest.earliestExpiry {
                items.append(StatusLine(id: 11, icon: "hourglass", text: "最近积分到期 \(expiry)", tint: .secondary))
            }
        }
        return items
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.m) {
            RingGauge(progress: digest.healthyRatio, lineWidth: 11) {
                VStack(spacing: 0) {
                    Text(digest.healthLabel)
                        .font(.metric(.title2))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text("健康")
                        .font(.tag)
                        .foregroundStyle(.secondary)
                }
                .padding(Metrics.m)
            }
            .frame(width: 122, height: 122)

            VStack(alignment: .leading, spacing: Metrics.s) {
                Text(digest.headline)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: Metrics.xs) {
                        ForEach(lines) { line in
                            HStack(spacing: Metrics.s) {
                                Image(systemName: line.icon)
                                    .font(.footnote.weight(.semibold))
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(line.tint)
                                Text(line.text)
                                    .font(.footnote)
                                    .foregroundStyle(line.tint)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard()
        .motion(Motion.emphasized, value: digest)
    }
}
