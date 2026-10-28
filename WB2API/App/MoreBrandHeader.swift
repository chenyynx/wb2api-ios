import SwiftUI

/// 「更多」页的品牌头部卡片。
struct MoreBrandHeader: View {
    var body: some View {
        HStack(spacing: Metrics.m) {
            BrandMark(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Work")
                    .font(.title3.bold())
                Text("WorkBuddy2API · 账号池运维面板")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Metrics.s)
        .accessibilityElement(children: .combine)
    }
}
