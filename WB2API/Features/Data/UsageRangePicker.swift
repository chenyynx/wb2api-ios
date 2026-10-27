import SwiftUI

/// 区间选择：横向胶囊 chips，Dynamic Type 变大时可横向滚动。
struct UsageRangePicker: View {
    @Binding var selection: UsageRange

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metrics.s) {
                ForEach(UsageRange.allCases) { item in
                    Button {
                        selection = item
                    } label: {
                        Text(item.title)
                            .font(.subheadline)
                            .bold(selection == item)
                            .foregroundStyle(selection == item ? Color.white : Color.primary)
                            .padding(.horizontal, Metrics.m)
                            .frame(minHeight: Metrics.minTap)
                            .background {
                                Capsule()
                                    .fill(
                                        selection == item
                                            ? AnyShapeStyle(Accent.gradient)
                                            : AnyShapeStyle(HierarchicalShapeStyle.quaternary)
                                    )
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("统计区间，\(item.title)")
                    .accessibilityAddTraits(selection == item ? .isSelected : [])
                }
            }
            .padding(.vertical, Metrics.xs)
        }
        .scrollIndicators(.hidden)
        .motion(Motion.snappy, value: selection)
    }
}
