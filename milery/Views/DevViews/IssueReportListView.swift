import SwiftUI

struct IssueReportListView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var reports: [IssueReportEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReport: IssueReportEntry?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section("狀態") {
                HStack {
                    Label("回報筆數", systemImage: "number")
                    Spacer()
                    Text("\(reports.count)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await loadReports()
                    }
                } label: {
                    Label("重新整理", systemImage: "arrow.clockwise")
                }

                if isLoading {
                    HStack {
                        Spacer()
                        SwiftUI.ProgressView("讀取回報中...")
                        Spacer()
                    }
                }
            }

            if reports.isEmpty {
                Section("問題回報") {
                    Text("目前沒有可顯示的回報")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("問題回報") {
                    ForEach(reports) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            IssueReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("問題回報檢視")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReports()
        }
        .refreshable {
            await loadReports()
        }
        .alert("讀取失敗", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .sheet(item: $selectedReport) { report in
            IssueReportDetailView(report: report)
                .presentationDetents([.medium, .large])
        }
    }

    private func loadReports() async {
        isLoading = true
        defer { isLoading = false }

        do {
            reports = try await IssueReportAdminService.shared.fetchReports()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IssueReportRow: View {
    let report: IssueReportEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.titleText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(report.contactEmailDisplayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(Self.dateText(report.submittedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("iOS \(report.iOSVersion) | \(report.deviceModel) | v\(report.appVersion) (\(report.buildNumber))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private static func dateText(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()
}

private struct IssueReportDetailView: View {
    let report: IssueReportEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailBlock(title: "送出時間", value: fullDateText(report.submittedAt))
                    detailBlock(title: "Email", value: report.contactEmailDisplayText)
                    detailBlock(title: "App 版本", value: "\(report.appVersion) (\(report.buildNumber))")
                    detailBlock(title: "裝置", value: report.deviceModel)
                    detailBlock(title: "iOS", value: report.iOSVersion)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("回報內容")
                            .font(.headline)
                        Text(report.content.isEmpty ? "（無內容）" : report.content)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .navigationTitle("回報詳情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func detailBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fullDateText(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        IssueReportListView()
    }
}