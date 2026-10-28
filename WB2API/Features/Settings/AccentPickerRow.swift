import SwiftUI

/// 设置里的强调色选择：一排色球 + 当前颜色名称。
struct AccentPickerRow: View {
    @Binding var selection: String

    private var current: AccentChoice {
        AccentChoice(rawValue: selection) ?? .violet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Metrics.m) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            selection = choice.rawValue
                        } label: {
                            Circle()
                                .fill(choice.gradient)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if choice == current {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(choice == current ? Color.primary : .clear, lineWidth: 2)
                                        .padding(-4)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityAddTraits(choice == current ? .isSelected : [])
                    }
                }
                .padding(.vertical, Metrics.xs)
            }
            .scrollIndicators(.hidden)

            Text("当前：\(current.title)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("强调色，当前\(current.title)")
    }
}

#Preview {
    AccentPickerRow(selection: .constant(AccentChoice.violet.rawValue))
        .padding()
}
