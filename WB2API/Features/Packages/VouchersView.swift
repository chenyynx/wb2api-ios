import SwiftUI
import UIKit

/// 券码：按账号列出开学季抽到的兑换券，点券码可复制。
///
/// 后端 `school/vouchers` 返回 `{accounts:[{uid,nickname,realm,vouchers:[…],error}]}`，
/// 每张券有 `prize_name / code / valid_to / granted_at`；空数组占多数，之前用
/// 通用 JSON 视图会把 11 个账号的空列表全铺出来，看起来像坏了。
struct VouchersView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @State private var loader = Loader<VoucherResponse>()
    @State private var toast: Toast?

    private var accounts: [VoucherAccount] {
        loader.value?.accounts ?? []
    }

    private var nonEmpty: [VoucherAccount] {
        accounts.filter { !($0.vouchers ?? []).isEmpty }
    }

    private var totalCount: Int {
        nonEmpty.reduce(0) { $0 + ($1.vouchers ?? []).count }
    }

    var body: some View {
        List {
            if let error = loader.error {
                Section {
                    ErrorBanner(message: error, retry: retry)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if loader.isLoading && loader.value == nil {
                Section {
                    LoadingSkeleton(rows: 4)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else if nonEmpty.isEmpty {
                ContentUnavailableView {
                    Label("没有可用券码", systemImage: "ticket")
                } description: {
                    Text("开学季抽到实物券后会显示在这里；抽到的是积分，不在此列表。")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(nonEmpty) { account in
                    Section {
                        ForEach(account.vouchers ?? []) { voucher in
                            VoucherRow(voucher: voucher) {
                                UIPasteboard.general.string = voucher.code
                                toast = Toast(kind: .success, text: "券码已复制")
                            }
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack {
                            Text(account.displayName)
                            Spacer()
                            if let realm = account.realmLabel {
                                Text(realm)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Text("共 \(totalCount) 张券 · 点券码复制")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("券码")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                    .disabled(loader.isLoading)
            }
        }
        .toast($toast)
    }

    private func load() async {
        guard let client = session.client() else { return }
        await loader.load { try await client.vouchers() }
    }

    private func refresh() {
        Task { await load() }
    }

    private func retry() {
        loader.clearError()
        Task { await load() }
    }
}

// MARK: - 模型

struct VoucherResponse: Codable, Sendable {
    let accounts: [VoucherAccount]?
}

struct VoucherAccount: Codable, Identifiable, Sendable {
    var id: String { uid ?? UUID().uuidString }
    let uid: String?
    let nickname: String?
    let realm: String?
    let vouchers: [SchoolVoucher]?
    let error: String?

    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return String((uid ?? "").prefix(8))
    }

    var realmLabel: String? {
        switch realm {
        case "cn": return "国内版"
        case "global": return "国际版"
        default: return nil
        }
    }
}

struct SchoolVoucher: Codable, Identifiable, Sendable {
    var id: String { "\(grantId ?? 0)-\(code)" }
    let grantId: Int64?
    /// JSON: draw_uuid（.convertFromSnakeCase 只产出 drawUuid）
    let drawUuid: String?
    let skuCode: String?
    let prizeName: String?
    let code: String
    let validFrom: String?
    let validTo: String?
    let grantedAt: String?
}

// MARK: - 行

private struct VoucherRow: View {
    @Environment(\.appTheme) private var theme

    let voucher: SchoolVoucher
    var onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label(voucher.prizeName ?? voucher.skuCode ?? "兑换券", systemImage: "ticket.fill")
                    .font(.callout.bold())
                Spacer(minLength: Metrics.s)
                if let to = voucher.validTo, !to.isEmpty {
                    Text("至 \(to)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onCopy) {
                HStack(spacing: Metrics.s) {
                    Text(voucher.code)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .foregroundStyle(theme.primary)
                .padding(Metrics.s)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: Metrics.radiusS))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("复制券码 \(voucher.code)")
        }
        .padding(.vertical, Metrics.xs)
    }
}
