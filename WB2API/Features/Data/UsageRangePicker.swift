import SwiftUI

/// 区间选择：六档等宽分段胶囊，选中态是强调色渐变滑块。
///
/// 之前是横向滚动的 chips，六个选项加起来比屏幕宽、最后一档被裁掉；
/// 现在整行铺满、等分六格，普通字号一行放得下，辅助功能字号退化成两列网格。
struct UsageRangePicker: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: UsageRange

    @Namespace private var pill

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: accessibilityColumns, spacing: 2) {
                    segments
                }
                .padding(3)
                .background(track(cornerRadius: Metrics.radiusL))
            } else {
                HStack(spacing: 2) {
                    segments
                }
                .padding(3)
                .background(track(cornerRadius: 21))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var segments: some View {
        ForEach(UsageRange.allCases) { item in
            segment(item)
        }
    }

    private var accessibilityColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 0),
        ]
    }

    /// 等分整行：`maxWidth: .infinity` 让六格平分，不再需要横向滚动。
    private func segment(_ item: UsageRange) -> some View {
        let isSelected = selection == item
        return Button {
            guard !isSelected else { return }
            withAnimation(reduceMotion ? Motion.gentle : Motion.spring) {
                selection = item
            }
        } label: {
            Text(item.title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(theme.gradient)
                            .matchedGeometryEffect(id: "range-selection", in: pill)
                            .shadow(color: theme.primary.opacity(0.28), radius: 5, y: 2)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("统计区间，\(item.title)")
        .accessibilityHint(item.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 轨道：浅到不抢内容，但比纯透明更能框住六格。
    private func track(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            }
    }
}
