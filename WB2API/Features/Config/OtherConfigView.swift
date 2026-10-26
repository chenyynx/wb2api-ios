import SwiftUI

/// 网页端没有做中文映射的原始配置键。
///
/// 单独放一页，避免把主配置页撑成几十个英文分组；字段一个不少，
/// 复杂结构仍然可以走「高级 JSON 编辑」。
struct OtherConfigView: View {
    let editor: ConfigEditor

    @State private var isJSONPresented = false

    private var groups: [ConfigGroup] {
        editor.uncuratedGroups(excluding: ConfigSchema.curatedPaths)
    }

    var body: some View {
        Form {
            Section {
                Text("这些键网页端没有中文表单，App 按原始名称展示；数组和嵌套对象请用「高级 JSON 编辑」。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.fields) { field in
                        ConfigFieldView(field: field) { newValue in
                            editor.set(newValue, for: field)
                        }
                    }
                } header: {
                    Text(group.key)
                }
            }
        }
        .navigationTitle("其他原始配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("高级 JSON", systemImage: "curlybraces") {
                    isJSONPresented = true
                }
            }
        }
        .sheet(isPresented: $isJSONPresented) {
            AdvancedJSONView(editor: editor)
        }
    }
}
