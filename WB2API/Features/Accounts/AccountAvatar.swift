import SwiftUI

/// 账号头像：按域区分两种（国内版 / 国际版）+ 右下角状态点。
///
/// 账号只有国内、国际两类，用首字母头像既没信息量又容易混淆，这里直接给域图标。
struct AccountAvatar: View {
    @Environment(\.appTheme) private var theme

    let account: Account
    var size: CGFloat = 42
    /// 警告已被忽略时状态点降级为灰色（正常仍是绿 / 蓝 / 红）。
    var suppressWarning: Bool = false

    private var isGlobal: Bool { account.realm == "global" }

    private var tint: Color { isGlobal ? .teal : theme.primary }

    private var icon: String {
        isGlobal ? "globe.asia.australia.fill" : "building.2.fill"
    }

    private var dotColor: Color {
        if suppressWarning { return .gray }
        return AccountStatusStyle.tint(for: account)
    }

    var body: some View {
        Circle()
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(tint)
                    // 固定到圆内：某些符号（地球）天生比字宽，不约束会溢出圆形
                    .frame(width: size * 0.62, height: size * 0.62)
            }
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(dotColor)
                    .frame(width: size * 0.30, height: size * 0.30)
                    .overlay {
                        Circle()
                            .stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2)
                    }
                    .offset(x: 1, y: 1)
            }
            .accessibilityHidden(true)
    }
}
