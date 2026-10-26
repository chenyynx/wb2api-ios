import SwiftUI

/// 模型详情：头卡 + 规格卡，导航值由 `ModelsView` 的 `navigationDestination` 提供。
struct ModelDetailView: View {
    let model: ModelInfo

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.m) {
                ModelDetailHeaderCard(model: model)
                ModelDetailSpecCard(model: model)
            }
            .padding(Metrics.m)
        }
        .navigationTitle(model.displayID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ModelSpeedTestView(focus: model)
                } label: {
                    Label("测速", systemImage: "speedometer")
                }
            }
        }
    }
}
